extends Node
class_name ZombieChooseRowSystem

## 每行的基础权重
var base_weight: Array[float] = []
var base_weigth_all_type :Dictionary[CharacterRegistry.ZombieRowType, Array]

var last_picked: Array[int] = []
var second_last_picked: Array[int] = []

var curr_type: CharacterRegistry.ZombieRowType = CharacterRegistry.ZombieRowType.Land
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


## 初始化系统
func init_zombie_choose_row_system():
	var row_num := get_row_num()
	if row_num <= 0:
		Log.error("初始化僵尸选行系统失败：当前关卡没有僵尸行")
		return
	var ori_weight_land:Array[float] = []
	var ori_weight_pool:Array[float] = []
	var ori_weight_both:Array[float] = []
	for zombie_row_node: ZombieRow in Global.main_game.zombie_manager.all_zombie_rows:
		match zombie_row_node.zombie_row_type:
			CharacterRegistry.ZombieRowType.Land:
				ori_weight_land.append(1)
				ori_weight_pool.append(0)
			CharacterRegistry.ZombieRowType.Pool:
				ori_weight_land.append(0)
				ori_weight_pool.append(1)
			CharacterRegistry.ZombieRowType.Both:
				ori_weight_land.append(1)
				ori_weight_pool.append(1)
		ori_weight_both.append(1.0)

	base_weigth_all_type = {
		CharacterRegistry.ZombieRowType.Land:ori_weight_land,
		CharacterRegistry.ZombieRowType.Pool:ori_weight_pool,
		CharacterRegistry.ZombieRowType.Both:ori_weight_both
	}

	last_picked.clear()
	second_last_picked.clear()
	for i in range(row_num):
		last_picked.append(0)
		second_last_picked.append(0)
	for i in base_weigth_all_type.keys():
		total_base_weight_all_type[i] = GlobalUtils.sum_arr(base_weigth_all_type[i])


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
			if i < base_weight.size() and base_weight[i] > 0:
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
