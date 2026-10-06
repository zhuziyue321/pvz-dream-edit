extends Node
class_name ZombieChooseRowSystem

## 每行的基础权重
var base_weight: Array[float] = []
var base_weigth_all_type :Dictionary[CharacterRegistry.ZombieRowType, Array]

var last_picked: Array[int] = []
var second_last_picked: Array[int] = []

## 丢车保护：小推车触发后该行在这段时间内不出怪（原版机制），单位秒，<=0 关闭保护
@export var mower_protect_time: float = 15.0
## 每行剩余的丢车保护时间（秒），下标 = 行号，由 _process 递减
var lane_protect_time_left: Array[float] = []

var curr_type: CharacterRegistry.ZombieRowType = CharacterRegistry.ZombieRowType.Land
## 是否完成行配置初始化；僵王的私有选行系统据此避免每次技能都重置历史。
var is_initialized: bool = false
## 基础权重之和
var total_base_weight :float= 0
var total_base_weight_all_type :Dictionary[CharacterRegistry.ZombieRowType, float]


## 当前关卡的僵尸行数（前院/屋顶 5 行，泳池 6 行），行数由场景决定，不要写死
func get_row_num() -> int:
	if Global.main_game == null or Global.main_game.zombie_manager == null:
		return 0
	return Global.main_game.zombie_manager.all_zombie_rows.size()


## 行历史数组与当前行数对齐（换场景/关卡时行数可能不同）
func _ensure_row_history_size(row_num: int) -> void:
	if last_picked.size() == row_num and second_last_picked.size() == row_num:
		return
	## 定长数组 resize 会用类型默认值（int → 0）填充
	last_picked.resize(row_num)
	second_last_picked.resize(row_num)


## 初始化系统；[param zombie_rows] 为空时回退到当前关卡的僵尸行（僵王技能会显式传入）。
func init_zombie_choose_row_system(zombie_rows: Array = []):
	var all_rows: Array = zombie_rows
	if all_rows.is_empty():
		all_rows = Global.main_game.zombie_manager.all_zombie_rows if (
			Global.main_game != null and Global.main_game.zombie_manager != null
		) else []
	var row_num := all_rows.size()
	if row_num <= 0:
		Log.error("初始化僵尸选行系统失败：当前关卡没有僵尸行")
		is_initialized = false
		return
	var ori_weight_land:Array[float] = []
	var ori_weight_pool:Array[float] = []
	var ori_weight_both:Array[float] = []
	for zombie_row_node: ZombieRow in all_rows:
		var weight_land := 0.0
		var weight_pool := 0.0
		## 两栖僵尸（自身行类型 Both）在所有「能出怪」的行上一视同仁，
		## 只有不出怪的行才是 0 —— 之前写成每行都按行类型算会让两栖僵尸权重全 0 走兜底
		var weight_both := 1.0
		match zombie_row_node.zombie_row_type:
			CharacterRegistry.ZombieRowType.Land:
				weight_land = 1.0
			CharacterRegistry.ZombieRowType.Pool:
				weight_pool = 1.0
			CharacterRegistry.ZombieRowType.Both:
				weight_land = 1.0
				weight_pool = 1.0
			CharacterRegistry.ZombieRowType.None:
				## 不出怪的行（原版没铺草皮的行）：三种权重都是 0，永远选不到
				weight_both = 0.0
		ori_weight_land.append(weight_land)
		ori_weight_pool.append(weight_pool)
		ori_weight_both.append(weight_both)

	base_weigth_all_type = {
		CharacterRegistry.ZombieRowType.Land:ori_weight_land,
		CharacterRegistry.ZombieRowType.Pool:ori_weight_pool,
		CharacterRegistry.ZombieRowType.Both:ori_weight_both
	}

	last_picked.clear()
	second_last_picked.clear()
	lane_protect_time_left.clear()
	for i in range(row_num):
		last_picked.append(0)
		second_last_picked.append(0)
		lane_protect_time_left.append(0.0)
	for i in base_weigth_all_type.keys():
		total_base_weight_all_type[i] = GlobalUtils.sum_arr(base_weigth_all_type[i])

	is_initialized = true
	## 丢车保护：小推车触发时由 LawnMover 推送
	EventBus.subscribe("lawn_mover_triggered", on_lawn_mover_triggered)
	set_process(true)


func _process(delta: float) -> void:
	if lane_protect_time_left.is_empty():
		return
	for i in range(lane_protect_time_left.size()):
		if lane_protect_time_left[i] > 0.0:
			lane_protect_time_left[i] = maxf(lane_protect_time_left[i] - delta, 0.0)


#region 丢车保护
## 丢车保护：小推车被触发，该行在 mower_protect_time 内不出怪，给玩家补防的窗口
func on_lawn_mover_triggered(mower_lane: int) -> void:
	if mower_protect_time <= 0.0:
		return
	var row_num := get_row_num()
	if row_num <= 0 or mower_lane < 0 or mower_lane >= row_num:
		Log.warn("丢车保护行号越界：%d（当前关卡共 %d 行），已忽略" % [mower_lane, row_num])
		return
	_ensure_lane_protect_size(row_num)
	lane_protect_time_left[mower_lane] = mower_protect_time
	Log.debug("丢车保护：第 %d 行 %.1f 秒内不出怪" % [mower_lane, mower_protect_time])


## 保护计时数组与当前行数对齐（换场景/关卡时行数可能不同）
func _ensure_lane_protect_size(row_num: int) -> void:
	if lane_protect_time_left.size() == row_num:
		return
	lane_protect_time_left.resize(row_num)


## 该行是否处于丢车保护中
func is_lane_in_mower_protect(lane: int) -> bool:
	if lane < 0 or lane >= lane_protect_time_left.size():
		return false
	return lane_protect_time_left[lane] > 0.0
#endregion


## 更新行历史
func on_zombie_spawned(row_index: int):
	var row_num := get_row_num()
	if row_index < 0 or row_index >= row_num:
		Log.error("出怪行号越界：%d（当前关卡共 %d 行），行历史未更新" % [row_index, row_num])
		return
	_ensure_row_history_size(row_num)

	for i in range(row_num):
		last_picked[i] += 1
		second_last_picked[i] += 1

	second_last_picked[row_index] = last_picked[row_index]
	last_picked[row_index] = 0


## 计算平滑权重
func calculate_smooth_weights(zombie_row_type: CharacterRegistry.ZombieRowType, special_base_weight: Array = []) -> Array:
	var smooth_weights: Array[float] = []
	var row_num := get_row_num()
	if row_num <= 0:
		return smooth_weights

	if not special_base_weight.is_empty():
		Log.debug("使用临时特殊基础权重")
		base_weight = special_base_weight
		total_base_weight = GlobalUtils.sum_arr(base_weight)
	else:
		base_weight = base_weigth_all_type.get(zombie_row_type, [])
		total_base_weight = total_base_weight_all_type.get(zombie_row_type, 0.0)

	## 权重数组长度必须与行数一致，否则按「没权重」处理（不写死 6 行）
	if base_weight.size() != row_num:
		Log.error(
			"出怪基础权重数组长度(%d)与僵尸行数(%d)不一致，本轮权重将全部按 0 处理"
			% [base_weight.size(), row_num]
		)
		total_base_weight = 0.0

	for i in range(row_num):
		if i >= base_weight.size() or base_weight[i] <= 0 or total_base_weight <= 0:
			smooth_weights.append(0.0)
			continue
		## 丢车保护中的行权重直接归零，本波不出怪
		if is_lane_in_mower_protect(i):
			smooth_weights.append(0.0)
			continue

		var weight_p = base_weight[i] / total_base_weight

		var p_last = (6.0 * last_picked[i] * weight_p + 6.0 * weight_p - 3.0) / 4.0
		var p_second_last = (second_last_picked[i] * weight_p + weight_p - 1.0) / 4.0

		var combined = p_last + p_second_last
		combined = clamp(combined, 0.01, 100.0)
		var smooth_weight = weight_p * combined

		smooth_weights.append(smooth_weight)

	return smooth_weights


## 选择下一个出怪行
func select_spawn_row(zombie_row_type: CharacterRegistry.ZombieRowType, special_base_weight: Array = []) -> int:
	var row_num := get_row_num()
	if row_num <= 0:
		Log.error("当前关卡没有僵尸行，出怪行号兜底为 0")
		return 0
	_ensure_row_history_size(row_num)

	var smooth_weights = calculate_smooth_weights(zombie_row_type, special_base_weight)
	var total_smooth_weight = 0.0
	for w in smooth_weights:
		total_smooth_weight += w

	## 兜底：平滑权重整体为 0 时，按基础权重（或全部合法行）随机，绝不返回越界行号
	if total_smooth_weight <= 0:
		Log.warn("整体平滑权重小于等于0，改用基础权重兜底选行")
		var fallback_rows: Array[int] = []
		for i in range(row_num):
			if i < base_weight.size() and base_weight[i] > 0 and not is_lane_in_mower_protect(i):
				fallback_rows.append(i)
		if fallback_rows.is_empty():
			## 能出怪的行全在丢车保护里：保护只负责让行「少出怪」，不能让整波停刷，忽略保护再兜一次
			Log.warn("所有可出怪行都处于丢车保护中，本次选行忽略保护")
			for i in range(row_num):
				if i < base_weight.size() and base_weight[i] > 0:
					fallback_rows.append(i)
		if fallback_rows.is_empty():
			## 兜底的兜底：至少不要选到「不自然出怪」的行
			var rows = Global.main_game.zombie_manager.all_zombie_rows
			for i in range(row_num):
				if i < rows.size() and rows[i].zombie_row_type != CharacterRegistry.ZombieRowType.None:
					fallback_rows.append(i)
			if fallback_rows.is_empty():
				for i in range(row_num):
					fallback_rows.append(i)
		var fallback_row: int = fallback_rows.pick_random()
		on_zombie_spawned(fallback_row)
		return fallback_row

	var rand_num = randf_range(0.0, total_smooth_weight)
	var cumulative_weight = 0.0

	for i in range(smooth_weights.size()):
		cumulative_weight += smooth_weights[i]
		if cumulative_weight >= rand_num:
			on_zombie_spawned(i)
			return i

	## 浮点误差导致没命中：取最后一个有权重的行
	var last_valid_row := 0
	for i in range(smooth_weights.size()):
		if smooth_weights[i] > 0:
			last_valid_row = i
	Log.warn("出怪权重累加未命中，兜底为最后一行有效行 %d" % last_valid_row)
	on_zombie_spawned(last_valid_row)
	return last_valid_row


### 获取概率
#func get_row_probabilities() -> Array:
	#var smooth_weights = calculate_smooth_weights(0 as CharacterRegistry.ZombieRowType)
	#var total = 0.0
	#for w in smooth_weights:
		#total += w
#
	#var probabilities = []
	#for w in smooth_weights:
		#probabilities.append(w / total if total > 0 else 0.0)
#
	#return probabilities
