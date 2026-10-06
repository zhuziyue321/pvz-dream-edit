extends Node
## 僵尸波次生成管理器
class_name ZombieWaveCreateManager

#region 波次生成僵尸管理器参数
## 出怪倍率
var zombie_multy := 1
## 蹦极僵尸数量范围
var range_num_bungi:Vector2i = Vector2i(3,5)
#endregion
@onready var zombie_manager: ZombieManager = %ZombieManager

## 僵尸选行系统
@onready var zombie_choose_row_system: ZombieChooseRowSystem = %ZombieChooseRowSystem

## 定义每个僵尸的战力值
const zombie_power = {
	CharacterRegistry.ZombieType.Z001Norm: 1,		# 普僵战力
	CharacterRegistry.ZombieType.Z002Flag: 1,		# 旗帜战力
	CharacterRegistry.ZombieType.Z003Cone: 2,		# 路障战力
	CharacterRegistry.ZombieType.Z004PoleVaulter: 2,	# 撑杆战力
	CharacterRegistry.ZombieType.Z005Bucket: 4,		# 铁桶战力

	CharacterRegistry.ZombieType.Z006Paper: 2,		# 读报战力
	CharacterRegistry.ZombieType.Z007ScreenDoor: 4,	# 铁门战力
	CharacterRegistry.ZombieType.Z008Football: 7,	# 橄榄球战力
	CharacterRegistry.ZombieType.Z009Jackson: 5,		# 舞王战力
	CharacterRegistry.ZombieType.Z010Dancer: 1,		# 伴舞权重

	CharacterRegistry.ZombieType.Z012Snorkle: 3,		# 潜水
	CharacterRegistry.ZombieType.Z013Zamboni: 7,		# 冰车
	CharacterRegistry.ZombieType.Z014Bobsled: 3,		# 滑雪四兄弟
	CharacterRegistry.ZombieType.Z015Dolphinrider: 3,# 海豚僵尸

	CharacterRegistry.ZombieType.Z016Jackbox: 3,		# 小丑
	CharacterRegistry.ZombieType.Z017Balloon: 2,		# 气球
	CharacterRegistry.ZombieType.Z018Digger: 4,		# 矿工
	CharacterRegistry.ZombieType.Z019Pogo: 4,			# 跳跳
	CharacterRegistry.ZombieType.Z020Yeti: 4,			# 雪人

	CharacterRegistry.ZombieType.Z022Ladder: 4,		# 扶梯
	CharacterRegistry.ZombieType.Z023Catapult: 5,		# 投篮
	CharacterRegistry.ZombieType.Z024Gargantuar: 10,	# 伽刚特尔
	CharacterRegistry.ZombieType.Z025Imp: 1,			# 小鬼
}

## 创建 zombie_weights 字典，存储初始权重,普僵权重会修改，
var zombie_weights:Dictionary = zombie_weights_ori.duplicate_deep()
const zombie_weights_ori = {
	CharacterRegistry.ZombieType.Z001Norm: 4000,			# 普僵权重
	#CharacterRegistry.ZombieType.Z002Flag: 0,			# 旗帜权重
	CharacterRegistry.ZombieType.Z003Cone: 4000,			# 路障权重
	CharacterRegistry.ZombieType.Z004PoleVaulter: 2000,	# 撑杆权重
	CharacterRegistry.ZombieType.Z005Bucket: 3000,		# 铁桶权重

	CharacterRegistry.ZombieType.Z006Paper: 1000,		# 读报权重
	CharacterRegistry.ZombieType.Z007ScreenDoor: 3500,	# 铁门权重
	CharacterRegistry.ZombieType.Z008Football: 2000,		# 橄榄球权重
	CharacterRegistry.ZombieType.Z009Jackson: 1000,		# 舞王权重
	CharacterRegistry.ZombieType.Z010Dancer: 4000,		# 舞王权重

	CharacterRegistry.ZombieType.Z012Snorkle: 2000,		# 潜水
	CharacterRegistry.ZombieType.Z013Zamboni: 2000,		# 冰车
	CharacterRegistry.ZombieType.Z014Bobsled: 2000,		# 滑雪四兄弟
	CharacterRegistry.ZombieType.Z015Dolphinrider: 1500,	# 海豚僵尸

	CharacterRegistry.ZombieType.Z016Jackbox: 1000,		# 小丑
	CharacterRegistry.ZombieType.Z017Balloon: 2000,		# 气球
	CharacterRegistry.ZombieType.Z018Digger: 1000,		# 矿工
	CharacterRegistry.ZombieType.Z019Pogo: 1000,			# 跳跳
	CharacterRegistry.ZombieType.Z020Yeti: 1,			# 雪人

	CharacterRegistry.ZombieType.Z022Ladder: 1000,		# 扶梯
	CharacterRegistry.ZombieType.Z023Catapult: 1500,	# 投篮
	CharacterRegistry.ZombieType.Z024Gargantuar: 1500,	# 伽刚特尔
	#CharacterRegistry.ZombieType.Z025Imp: 0,		# 小鬼
}

## 僵尸随机选择池
var zombie_choose_random_pool:RandomPicker

## 每波最大僵尸数量
@export var max_zombies_per_wave = 50
## 同一波僵尸在入场方向上的间隔（像素）：原版一波僵尸是陆续进场，不是同时从同一点涌入
@export var spawn_gap_x := 25.0
## 单波入场错开的总跨度上限（像素）：防止波末僵尸离场太远，把清场时间拖得过长
@export var spawn_gap_x_max := 400.0
## 刷新类型最小战力
var min_power:=100
## 当前所有可能出怪僵尸权重上限和,每波修改
var curr_zombie_weight_upper_limit :int
## 当前波次生成的僵尸
var wave_all_zombies:Array[Zombie000Base]

## 初始化创建波次僵尸管理器
func init_zombie_wave_create_manager(game_para:ResourceLevelData):
	zombie_multy = game_para.zombie_multy
	range_num_bungi = game_para.range_num_bungi
	zombie_choose_row_system.init_zombie_choose_row_system()
	update_zombie_refresh_types()

## 更新可以刷新的僵尸列表
func update_zombie_refresh_types():
	## 初始化僵尸生成随机池数据
	var zombie_choose_random_pool_data:Array[Array] = []
	min_power = 100
	for zombie_type in zombie_manager.zombie_refresh_types:
		## 两张表并不覆盖所有僵尸类型，裸索引遇到表外类型会直接报错
		var curr_power: int = get_zombie_power(zombie_type)
		if curr_power <= 0:
			Log.warn("僵尸类型 " + str(zombie_type) + " 没有配置 power，已从刷新池中跳过")
			continue
		if min_power > curr_power:
			min_power = curr_power
		zombie_choose_random_pool_data.append([zombie_type, get_zombie_weight(zombie_type)])
	Log.debug("更新僵尸随机选择池")
	zombie_choose_random_pool = RandomPicker.new(zombie_choose_random_pool_data)


## 僵尸战力：植物僵尸那 13 只的战力不在本文件的 zombie_power 表里，统一在 ZomBotanyConfig 配
## （13 只各写一份会让两张表翻倍，且和 zom_botany_config.gd 各演化各的）
func get_zombie_power(zombie_type:CharacterRegistry.ZombieType) -> int:
	var zom_botany_info := ZomBotanyConfig.get_info(zombie_type)
	if zom_botany_info != null:
		return zom_botany_info.power
	return zombie_power.get(zombie_type, -1)


## 僵尸初始权重：植物僵尸走 ZomBotanyConfig，其余走 zombie_weights
func get_zombie_weight(zombie_type:CharacterRegistry.ZombieType) -> int:
	var zom_botany_info := ZomBotanyConfig.get_info(zombie_type)
	if zom_botany_info != null:
		return zom_botany_info.weight
	return zombie_weights.get(zombie_type, 9999)


#region 创建当前波次僵尸
## 创建当前波僵尸
func create_curr_wave_all_zombies(wave:int, is_big_wave:bool):
	## 获取当前波僵尸生成列表
	var wave_spawn :Array[CharacterRegistry.ZombieType] = create_curr_wave_zombie_list(wave, is_big_wave)
	## 本波僵尸「怎么进场」交给关卡脚本：默认是走进来，一关专属的进场方式（空投这类）
	## 由脚本自己覆写 create_wave_zombies 换掉 —— 本文件不认识任何具体玩法
	## （见 LevelScriptBase.create_wave_zombies；老 .tres 关卡不是脚本，走通用进场）
	var level_script := zombie_manager.game_para as LevelScriptBase
	if level_script != null:
		return level_script.create_wave_zombies(self, wave_spawn, wave)
	return create_norm_wave_zombies(wave_spawn, wave)


## 通用进场：僵尸按清单从场地边缘走进来
## 关卡脚本覆写 create_wave_zombies 时想退化成普通进场就调这里
func create_norm_wave_zombies(wave_spawn:Array[CharacterRegistry.ZombieType], wave:int) -> Array[Zombie000Base]:
	wave_all_zombies.clear()

	for i in range(wave_spawn.size()):
		var zombie_type : CharacterRegistry.ZombieType = wave_spawn[i]
		var lane :int = -1
		## 雪橇队
		if zombie_type == CharacterRegistry.ZombieType.Z014Bobsled:
			## 挑一条「冰面还在」的行：没有冰的小队一落地就开始掉血（见 Zombie014Bobsled.judge_is_in_ice_road），
			## 这样的班级不算有效出怪 —— 一条冰道都没有时本波改出洗冰车，由它把冰铺回来
			## （对应原版「玩家把冰面融掉后，冰面恢复前只出洗冰车」）
			lane = select_bobsled_spawn_row()
			if lane < 0:
				zombie_type = CharacterRegistry.ZombieType.Z013Zamboni
		if lane < 0:
			lane = zombie_choose_row_system.select_spawn_row(Global.character_registry.ZombieInfo[zombie_type][CharacterRegistry.ZombieInfoAttribute.ZombieRowType])
		wave_all_zombies.append(
			wave_create_zombie(zombie_type, lane, wave, Callable(), i)
		)

	return wave_all_zombies


## 雪橇队的出怪行：只在「冰面还在」的行里挑
## 返回 -1 = 整张图一条冰道都没有（冰被融掉了，还没被洗冰车铺回来）
func select_bobsled_spawn_row() -> int:
	var ice_row_weight:Array[float] = []
	for row_ice_road:Array[IceRoad] in zombie_manager.all_ice_roads:
		ice_row_weight.append(0.0 if row_ice_road.is_empty() else 1.0)
	if GlobalUtils.sum_arr(ice_row_weight) == 0:
		Log.debug("全图没有冰道，本波雪橇队改成洗冰车")
		return -1
	return zombie_choose_row_system.select_spawn_row(
		Global.character_registry.ZombieInfo[CharacterRegistry.ZombieType.Z014Bobsled][CharacterRegistry.ZombieInfoAttribute.ZombieRowType],
		ice_row_weight)


## 生成波次僵尸
func wave_create_zombie(
	zombie_type:CharacterRegistry.ZombieType,
	lane:int, 	## 僵尸行
	curr_wave:int,		## 僵尸波次
	init_zombie_special:Callable = Callable(),		## 初始化僵尸特殊属性
	spawn_index:int = -1		## 本波内第几只（>=0 时按序号在入场方向上错开，模拟原版陆续进场）
):
	var zombie_init_para:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane:lane,
		Zombie000Base.E_ZInitAttr.CurrWave:curr_wave,
	}
	## 同一波僵尸按序号往场外错开，变成原版的「陆续进场」；spawn_index < 0 表示不错开（珊瑚 / 蹦极等）
	var spawn_gap := 0.0
	if spawn_index > 0:
		spawn_gap = min(spawn_index * spawn_gap_x, spawn_gap_x_max)
	var zombie_glo_pos = zombie_manager.all_zombie_rows[lane].zombie_create_position.global_position + Vector2(randf_range(-10, 10), 0)

	## 父节点不传：由 create_norm_zombie 按 para 里的 Lane 取该行节点
	return zombie_manager.create_norm_zombie(zombie_type, null, zombie_init_para, zombie_glo_pos, init_zombie_special, spawn_gap)

#region 创建当前波僵尸生成列表
## 创建当前波僵尸生成列表
func create_curr_wave_zombie_list(wave:int, is_big_wave:bool):
	## 计算当前波僵尸战力上限
	var curr_wave_power_limit = calculate_wave_power_limit(wave, is_big_wave)
	## 更新僵尸权重上限
	update_curr_zombie_weight_upper_limit(wave)
	## 获取当前波的生成僵尸列表
	var wave_spawn :Array[CharacterRegistry.ZombieType] = get_curr_wave_zombie_list(wave, is_big_wave, curr_wave_power_limit)

	return wave_spawn

## 计算每波的战力上限（原版「本波总级别」）
## 原版公式: n÷3 向上取整(n 为当前波数)；大波再乘 2.5 向下取整；出怪倍率最后整体相乘
## 数据来源: 新PVZ通关技术理论1.1 第二章 2.3 级别与权重(https://www.bilibili.com/read/cv40586093)
func calculate_wave_power_limit(wave:int, is_big_wave: bool) -> int:
	## x从0开始
	## 计算战力上限 = y=int(x/3)+1
	@warning_ignore("integer_division")
	var base_power_limit:int = wave / 3 + 1
	## 如果是大波，战力上限是原战力上限的2.5倍
	var power_limit:int = base_power_limit * zombie_multy
	if is_big_wave:
		power_limit = int(base_power_limit * 2.5) * zombie_multy
	## 至少保留1点战力，避免某一波一只都不出
	return max(1, power_limit)

## 计算当前波僵尸权重上限
func update_curr_zombie_weight_upper_limit(wave:int):
	## 如果是第0波
	if wave == 0:
		# 计算所有可能僵尸的权重总和
		curr_zombie_weight_upper_limit = calculate_all_zombie_weight()
	elif wave < 4:
		pass
	elif wave < 26:
		_update_weights(wave)
		# 计算所有可能僵尸的权重总和
		curr_zombie_weight_upper_limit = calculate_all_zombie_weight()
	else:
		pass

## 当前出怪表里所有僵尸的权重总和
## 口径必须和 update_zombie_refresh_types 一致：
##   · 植物僵尸（Z031+）的权重在 ZomBotanyConfig 里，裸读 zombie_weights[type] 会直接报
##     「Invalid access to property or key」——两张表加起来才覆盖全部可出怪类型；
##   · power <= 0 的类型建池时就被跳过，不会自然出怪，权重也不该计进来
func calculate_all_zombie_weight() -> int:
	var total_weight := 0
	for zombie_type in zombie_manager.zombie_refresh_types:
		if get_zombie_power(zombie_type) <= 0:
			continue
		total_weight += get_zombie_weight(zombie_type)
	return total_weight

## 更新权重到达上限后最后一次已经更新
var is_update_weight_on_limit:=false

## 更新僵尸权重
func _update_weights(wave: int):
	if wave >= 5:
		if wave >= 25:
			if is_update_weight_on_limit:
				return
			is_update_weight_on_limit = true
			Log.debug("更新权重")
			wave = 25

		var norm_weight = 4000 - (wave - 5) * 180
		zombie_weights[CharacterRegistry.ZombieType.Z001Norm] = norm_weight
		if CharacterRegistry.ZombieType.Z001Norm in zombie_manager.zombie_refresh_types:
			zombie_choose_random_pool.update_item_weight(CharacterRegistry.ZombieType.Z001Norm, norm_weight, false)
		var cone_weight = 4000 - (wave - 5) * 150
		zombie_weights[CharacterRegistry.ZombieType.Z003Cone] = cone_weight
		if CharacterRegistry.ZombieType.Z003Cone in zombie_manager.zombie_refresh_types:
			zombie_choose_random_pool.update_item_weight(CharacterRegistry.ZombieType.Z003Cone, cone_weight, false)

		zombie_choose_random_pool.rebuild_alias_table()

## 获取当前波僵尸列表
func get_curr_wave_zombie_list(wave:int, is_big_wave: bool, curr_wave_power_limit:int) ->Array[CharacterRegistry.ZombieType]:
	## 当前波的僵尸列表
	var wave_spawn :Array[CharacterRegistry.ZombieType]= []
	## 目前总战力
	var total_power = 0
	## 当前空隙位置
	var curr_spare_slot = max_zombies_per_wave

	## 如果是大波，先刷新特殊僵尸
	if is_big_wave:
		## 第一个旗帜僵尸
		wave_spawn.append(CharacterRegistry.ZombieType.Z002Flag)
		total_power += zombie_power[CharacterRegistry.ZombieType.Z002Flag]
		curr_spare_slot -= 1

		# 第一次大波（第10波），刷新4个普通僵尸
		if wave == 9:
			for i in range(4):
				wave_spawn.append(CharacterRegistry.ZombieType.Z001Norm)
				total_power += zombie_power[CharacterRegistry.ZombieType.Z001Norm]
				curr_spare_slot -= 1
		# 之后的大波（第20波、30波...），刷新8个普通僵尸
		else:
			for i in range(8):
				wave_spawn.append(CharacterRegistry.ZombieType.Z001Norm)
				total_power += zombie_power[CharacterRegistry.ZombieType.Z001Norm]
				curr_spare_slot -= 1

	# 生成剩余僵尸，直到总战力符合当前战力上限
	while curr_spare_slot > 0 and total_power < curr_wave_power_limit:

		var selected_zombie:CharacterRegistry.ZombieType = zombie_choose_random_pool.get_random_item()
		var zombie_power_value = get_zombie_power(selected_zombie)

		#prints("当前剩余僵尸", curr_spare_slot, "当前战力:", total_power, "当前所选僵尸:", selected_zombie, "当前所选僵尸战力:", zombie_power_value)

		# 检查如果加上该僵尸的战力后超过当前波的战力上限，重新选择
		if total_power + zombie_power_value <= curr_wave_power_limit:
			wave_spawn.append(selected_zombie)
			total_power += zombie_power_value
			curr_spare_slot -= 1
		elif curr_wave_power_limit - total_power < min_power:
			for i in range(curr_wave_power_limit - total_power):
				wave_spawn.append(CharacterRegistry.ZombieType.Z001Norm)
				total_power += zombie_power[CharacterRegistry.ZombieType.Z001Norm]
				curr_spare_slot -= 1
			continue
		else:
			continue

	return wave_spawn

#endregion

#endregion

#region 大波僵尸时生成特殊僵尸
## 大波僵尸时创建特殊僵尸
## [is_final:bool] 是否为最后一波
func spawn_special_zombie_in_big_wave(is_final:=false):
	## 珊瑚僵尸,若有水路自动创建,没有则不创建
	if is_final:
		if not zombie_manager.is_ice:
			Log.debug("生成珊瑚僵尸")
			spawn_sea_weed_zombies()
		else:
			Log.debug("被冰冻无法生成珊瑚僵尸")
	## 如果有蹦极僵尸
	if zombie_manager.is_bungi:
		spawn_bungi_zombies()

#region 珊瑚僵尸
## 最后一大波珊瑚僵尸
func spawn_sea_weed_zombies():
	var zombie_row_pool_i :Array[int]
	for i in range(zombie_manager.all_zombie_rows.size()):
		if zombie_manager.all_zombie_rows[i].zombie_row_type == CharacterRegistry.ZombieRowType.Pool:
			zombie_row_pool_i.append(i)
	if zombie_row_pool_i.is_empty():
		Log.debug("无水路,无法生成珊瑚僵尸")
		return

	var zombie_type_sea_weed_list :Array= [CharacterRegistry.ZombieType.Z001Norm, CharacterRegistry.ZombieType.Z003Cone, CharacterRegistry.ZombieType.Z005Bucket]

	for i in range(3):
		var zombie_type:CharacterRegistry.ZombieType = zombie_type_sea_weed_list.pick_random()
		var lane:int= zombie_row_pool_i.pick_random()
		var zombie_sea_weed:Zombie000Base = wave_create_zombie(zombie_type, lane, -1, _zombie_seaweed)

		zombie_sea_weed.global_position.x = randf_range(500, 750)

## 珊瑚僵尸
func _zombie_seaweed(z:Zombie001Norm):
	z.is_seaweed = true
#endregion

#region 蹦极僵尸
## 大波空投一批偷植物的蹦极僵尸（蹦极闪电战的大波也走这里）
func spawn_bungi_zombies():
	## 选择plant_cell
	var num_bungi_rand:int = randi_range(range_num_bungi.x, range_num_bungi.y)
	var all_cell_have_plant:Array[PlantCell] = zombie_manager.main_game.plant_cell_manager.get_cell_have_plant()
	var num_bungi_res:int = min(num_bungi_rand, all_cell_have_plant.size())
	## 打乱顺序
	all_cell_have_plant.shuffle()
	## 蹦极僵尸选中的plant_cell
	var all_cell_be_bungi = all_cell_have_plant.slice(0, num_bungi_res)
	## 生成蹦极僵尸
	for plant_cell:PlantCell in all_cell_be_bungi:
		var zombie_init_para:Dictionary = {
			Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane:plant_cell.row_col.x
		}

		zombie_manager.create_norm_zombie(
			CharacterRegistry.ZombieType.Z021Bungi,
			zombie_manager.all_zombie_rows[plant_cell.row_col.x],
			zombie_init_para,
			Vector2(plant_cell.global_position.x + plant_cell.size.x/2,
				zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_create_position.global_position.y
			),
			GlobalUtils.create_bungi.bind(plant_cell)
		)

#endregion

#endregion
