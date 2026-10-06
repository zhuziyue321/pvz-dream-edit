extends MainGameSubManager
class_name ZombieManager

## 僵尸行脚本：行类型/生成点由地图数据决定，行节点在运行时生成
const ZOMBIE_ROW_SCRIPT = preload("res://src/items/zombies_row.gd")

## 冰道场景：洗冰车自带一份子节点，关卡开局预铺的那份从这儿实例化
const ICE_ROAD_SCENE = preload("res://src/items/ice_road.tscn")

## 开局冰道相对本行僵尸落脚点的偏移：与 zombie_zamboni.tscn 的 $IceRoad 摆位对齐，
## 好让「预铺的冰」与「洗冰车开过去铺出来的冰」在同一条水平线上无缝接上
const PRESET_ICE_ROAD_POS_OFFSET := Vector2(80, -22)

## 最后一波僵尸每秒检测是否有僵尸离开当前视野
@onready var check_zombie_end_wave_timer: Timer = $CheckZombieEndWaveTimer
## 管理器
@onready var zombie_wave_manager: ZombieWaveManager = $ZombieWaveManager
@onready var zombie_show_in_start: ZombieShowInStart = $ZombieShowInStart
## 僵尸数量label
@onready var label_zombie_sum: Label = %LabelZombieSum
## 所有僵尸根节点
@onready var zombies_root: Node2D = %ZombiesRoot
## 僵王独立挂载，不混入会被当作僵尸行遍历的 ZombiesRoot。
@onready var zombie_boss_root: Node2D = get_node_or_null("%ZombieBossRoot") as Node2D

## 出战僵王成功入树、死亡或移除后发出，供关卡按当前存活实例选择战斗音乐与血条。
signal signal_living_bosses_changed()

## 僵王登记与生命周期管理。
## 业务本体在 zm_boss_registry.gd（含 11 个私有变量），这里只持有实例并转发，避免本文件继续膨胀。
var boss_registry: ZmBossRegistry


#region 僵尸管理器参数
## 刷怪类型
var is_bungi = false
var zombie_refresh_types = []

## 出怪模式
var monster_mode:ConstLevelData.E_MonsterMode = ConstLevelData.E_MonsterMode.Norm

## 外部出怪器：某些关卡不走默认波次表（僵尸从墓碑里冒头这类），
## 由关卡侧的玩法规则实例化后注入（见 ZombieWaveSourceBase / set_wave_source）。
## 非空时本管理器把「初始化 + 开波」交给它，本体不认识任何具体玩法
var wave_source: ZombieWaveSourceBase = null

## 注入本关的出怪器（调用时机：关卡脚本的 init_level_items()，
## 排在 ZombieManager.init_manager() 之前，见 LevelScriptBase.init_level_items）
func set_wave_source(new_wave_source: ZombieWaveSourceBase) -> void:
	wave_source = new_wave_source

## 第一波是否已经启动：整局只开一次（多轮游戏切轮时重置，见 start_next_game_zombie_mananger_update）
var is_first_wave_started := false

#endregion

#region 波次进度
## 下面这一组是**关卡进度条默认口径「战斗进度」的查询口**：
## 出怪侧（波次管理器 / 关卡注入的出怪器）各自算好自己的进度，这里统一转发一次，
## 数据源（LevelProgressBattleProvider）只认 ZombieManager，出怪器换了不用改 UI。
## 进度条节点本身由 LevelProgressBarController 写，谁都不在这里碰它。

## 当前战斗进度百分比（0~100）
func get_battle_progress() -> float:
	if wave_source != null:
		return wave_source.get_battle_progress()
	return zombie_wave_manager.get_battle_progress()

## 本关的波次是否已经开打（开打前进度条不显示）
func is_battle_started() -> bool:
	if wave_source != null:
		return wave_source.is_battle_started()
	return zombie_wave_manager.is_battle_started()

## 进度条上要画几面旗帜（<= 0 = 不画）
func get_battle_flag_num() -> int:
	if wave_source != null:
		return wave_source.get_flag_num()
	return zombie_wave_manager.get_flag_num()

## 取走「本帧要升旗」的旗帜下标（-1 = 不升）
func take_battle_flag_raise_index() -> int:
	if wave_source != null:
		return wave_source.take_flag_raise_index()
	return zombie_wave_manager.take_flag_raise_index()

## 取走「本帧要收起所有旗帜」的请求（多轮游戏切新一轮）
func take_battle_flag_reset() -> bool:
	if wave_source != null:
		return wave_source.take_flag_reset()
	return zombie_wave_manager.take_flag_reset()
#endregion

#region 多轮游戏
## 多轮游戏最后一波计时器
var multi_round_end_wave_timer:Timer
## 多轮游戏最后一波时长
var multi_round_end_wave_time :float = 49

#endregion

var curr_zombie_num:int = 0:
	set(v):
		curr_zombie_num=v
		label_zombie_sum.text = "当前僵尸数量：" + str(curr_zombie_num)
		signal_curr_zombie_num_change.emit(v)

## 是否为最后一波,最后一波时，僵尸数量为0后结束游戏
var is_end_wave := false
## 被魅惑僵尸列表
var all_zombies_be_hypno:Array[Zombie000Base] = []
## 僵尸可以存在的x坐标范围,超出该范围,每波刷新时删除,最后一波时每秒删除检查删除
var zombie_range_pos_x:=Vector2(-300, 1000)
## 所有僵尸列表,用于每波清除在地图外的僵尸(矿工,魅惑等僵尸)
var all_zombies_1d:Array[Zombie000Base]

## 所有僵尸行
var all_zombie_rows:Array[ZombieRow] = []
## 冰道,按行保存每行的冰道
var all_ice_roads:Array[Array] = []
## 按行保存僵尸，用于保存僵尸列表的列表,僵尸被魅惑后从该列表中删除
var all_zombies_2d:Array[Array]

## 是否被冻结，用于管理冰消珊瑚
var is_ice:bool
var ice_timer:Timer

signal signal_curr_zombie_num_change(num:int)

func _ready():
	boss_registry = ZmBossRegistry.new(self)
	## 注册事件总线
	EventBus.subscribe("ice_all_zombie", ice_all_zombie)
	## 火爆辣椒销毁道具[冰道和梯子]
	EventBus.subscribe("jalapeno_bomb_item_lane", jalapeno_bomb_item_lane)
	EventBus.subscribe("jalapeno_bomb_lane_zombie", jalapeno_bomb_lane_zombie)
	EventBus.subscribe("blover_blow_away_in_sky_zombie", blover_blow_away_in_sky_zombie)
	## 非刷怪模式最后一波僵尸
	EventBus.subscribe("end_wave_zombie", func():is_end_wave=true)
	EventBus.subscribe("test_death_all_zombie", death_all_zombie)

	create_zombie_rows_from_map_data()

	## 初始化僵尸和行列表
	for zombie_row_i in zombies_root.get_child_count():
		var zombie_row :CanvasItem= zombies_root.get_child(zombie_row_i)
		zombie_row.z_index = zombie_row_i * 50 + 30

		all_zombie_rows.append(zombie_row)
		var row_ice_roads:Array[IceRoad] = []
		all_ice_roads.append(row_ice_roads)

		var row_zombies:Array[Zombie000Base] = []
		all_zombies_2d.append(row_zombies)

## 按地图数据生成僵尸行（数据驱动，见 docs/参考存档/地图实现.md）：
## 行类型、僵尸生成点、钉耙都在 ResourceMapData 里，不再手摆在场景中。
## 行节点放在原点，生成点用 Marker2D 的绝对坐标表示，
## 这样僵尸的局部坐标 == 全局坐标（换行 tween 用的是局部 y）。
func create_zombie_rows_from_map_data() -> void:
	if game_para == null or game_para.map_data == null:
		Log.error("没有地图数据，无法生成僵尸行")
		return
	var map_data: ResourceMapData = game_para.map_data
	if not map_data.is_valid():
		return
	for row_i in range(map_data.get_row_num()):
		var row_data: ResourceMapRowData = map_data.rows[row_i]
		var row_node: Node2D = Node2D.new()
		row_node.name = "Zombies_row%d" % (row_i + 1)
		row_node.set_script(ZOMBIE_ROW_SCRIPT)
		row_node.set("zombie_row_type", row_data.zombie_row_type)
		row_node.set("have_rake", row_data.have_rake)
		var create_pos: Marker2D = Marker2D.new()
		create_pos.name = "ZombieCreatePosition"
		create_pos.position = row_data.zombie_create_global_pos
		row_node.add_child(create_pos)
		zombies_root.add_child(row_node)


## 初始僵尸管理器
func init_manager() -> void:
	## 出怪模式
	monster_mode = game_para.monster_mode
	match monster_mode:
		## 没有僵尸刷新,直接启动最后一波僵尸检查计时器
		ConstLevelData.E_MonsterMode.Null:
			check_zombie_end_wave_timer.start()

		ConstLevelData.E_MonsterMode.Norm:
			## 如果游戏是多轮游戏
			if game_para.game_round != 1:
				update_multi_round_zombie_refresh_types(main_game.curr_game_round)
			else:
				## 刷怪类型
				is_bungi = game_para.is_bungi
				zombie_refresh_types = game_para.zombie_refresh_types

			zombie_wave_manager.init_zombie_wave_manager(game_para)
			## 波次刷新时判断是否为最后一波，删除多余魅惑僵尸
			zombie_wave_manager.signal_wave_refresh.connect(wave_refresh)
			## 僵尸数量改变时，剩余僵尸为0触发提前刷新
			signal_curr_zombie_num_change.connect(zombie_wave_manager.zombie_wave_refresh_manager.judge_total_refresh)

		ConstLevelData.E_MonsterMode.HammerZombie:
			## 出怪器由关卡的玩法规则注入（见 LevelRuleHammerZombie.install）：
			## 本体只认 ZombieWaveSourceBase 这个基类，不认识任何具体管理器
			if wave_source != null:
				wave_source.init_source(game_para)
				## 波次刷新时判断是否为最后一波，删除多余魅惑僵尸
				wave_source.signal_wave_refresh.connect(wave_refresh)
			else:
				Log.error("外部出怪模式缺少出怪器：关卡脚本没有装配对应的玩法规则")

## 开战前改写本关出怪表：**关卡流程的「开战」事件带 zombie_refresh_types 时走这里**
## （见 LevelTimelineEventStartBattle._apply_battle_para）
## 随机池是按 zombie_refresh_types 建好的，改完表要顺手重建一次，否则本关还是按旧表出怪
func apply_zombie_refresh_types(types: Array[CharacterRegistry.ZombieType]) -> void:
	zombie_refresh_types = types
	zombie_wave_manager.zombie_wave_create_manager.update_zombie_refresh_types()


## 开战：起第一波僵尸 —— 整局只开一次，重复调会跳波
func start_game():
	## 僵王自动生成与自然波次分开：配置了 boss_spawn_wave == 0 的关卡在开战时出场一次
	try_auto_spawn_boss()
	if is_first_wave_started:
		return
	## 注入了外部出怪器时，入场延迟与开波时机都由出怪器自己决定（见 ZombieWaveSourceBase）
	if wave_source != null:
		is_first_wave_started = true
		wave_source.start_first_wave()
		return
	match monster_mode:
		ConstLevelData.E_MonsterMode.Null:
			return

		ConstLevelData.E_MonsterMode.Norm:
			is_first_wave_started = true
			## 关卡配置的第一波延迟秒数后开始刷新僵尸
			await get_tree().create_timer(maxf(0.0, game_para.first_wave_delay)).timeout
			zombie_wave_manager.start_next_wave()
			## 第一波落定之后才让进度条走起来、把进度条亮出来
			zombie_wave_manager.every_wave_progress_timer.start()
			zombie_wave_manager.is_wave_started = true



#region 开局冰道
## 关卡开局预铺冰道（迷你游戏「全面冻结」专用）
## 原版该关一进场四条地面路线就结着冰，玩家的植物只能种在冰面没盖住的左侧几列；
## 水路不铺 —— 洗冰车与雪橇队都是行类型 Land（见 CharacterRegistry.ZombieInfo），水路本来也上不去。
##   cover_cell_num —— 每行从最右列往左覆盖几格（其余格子留给玩家种植）
func create_preset_ice_roads(cover_cell_num:int) -> void:
	if not is_instance_valid(main_game) or main_game.plant_cell_manager == null or main_game.background_manager == null:
		Log.error("开局冰道缺少植物格子 / 背景管理器，已跳过铺冰")
		return
	var all_plant_cells:Array[Array] = main_game.plant_cell_manager.all_plant_cells
	var paved_row_num := 0
	for lane in range(all_zombie_rows.size()):
		var zombie_row:ZombieRow = all_zombie_rows[lane]
		## 只结冰能跑冰车的地面行
		if zombie_row.zombie_row_type != CharacterRegistry.ZombieRowType.Land:
			continue
		## 多轮游戏（重跑一遍关卡流程）不再铺第二层：本行还有冰就跳过
		if not all_ice_roads[lane].is_empty():
			continue
		if lane >= all_plant_cells.size() or all_plant_cells[lane].is_empty():
			Log.warn("开局冰道：第 %d 行没有植物格子，本行跳过" % lane)
			continue
		var lane_plant_cells:Array = all_plant_cells[lane]
		var cover_i:int = maxi(lane_plant_cells.size() - cover_cell_num, 0)
		var cover_left_x:float = lane_plant_cells[cover_i].global_position.x

		var ice_road:IceRoad = ICE_ROAD_SCENE.instantiate()
		main_game.background_manager.background.add_child(ice_road)
		## 先从最右侧的僵尸出生点起铺，再往左展开，和洗冰车开过留下的那条冰是一个坐标系
		ice_road.global_position = zombie_row.zombie_create_position.global_position + PRESET_ICE_ROAD_POS_OFFSET
		ice_road.init_preset_ice_road(lane, cover_left_x)
		paved_row_num += 1
	Log.debug("开局冰道：%d 条地面行，每行从最右列往左覆盖 %d 格" % [paved_row_num, cover_cell_num])
#endregion

#region 生成僵尸
## 生成一个正常出战僵尸，所有出战僵尸都要从这里生成
func create_norm_zombie(
	zombie_type:CharacterRegistry.ZombieType,	## 僵尸类型
	zombie_parent:Node,				## 僵尸父节点；传 null 时按 zombie_init_para 里的 Lane 自行取该行节点
	zombie_init_para:Dictionary,			## 僵尸初始化参数
	global_pos:Vector2=Vector2.ZERO,
	init_zombie_special:Callable = Callable(),		## 初始化僵尸特殊属性
	spawn_gap:float = 0.0				## 同波内陆续进场的额外 x 偏移（由波次方按序号算好传进来）
) -> Zombie000Base:
	var zombie:Zombie000Base = Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieScenes).instantiate()
	if zombie_parent == null:
		zombie_parent = all_zombie_rows[zombie_init_para[Zombie000Base.E_ZInitAttr.Lane]]
	zombie_init_para[Zombie000Base.E_ZInitAttr.IsZombieMode] = game_para.is_zombie_mode
	## 一关专属的角色设定（如「隐形战争」让僵尸本体隐形）由关卡脚本通过本钩子下发：
	## 本体只负责把这张表并进初始化参数，不认识任何具体玩法（§1-8）
	zombie_init_para.merge(game_para.get_zombie_init_para_extra(), true)

	zombie.init_zombie(zombie_init_para)
	if not init_zombie_special.is_null():
		init_zombie_special.call(zombie)
	zombie.position = global_pos - zombie_parent.global_position + Vector2(spawn_gap, 0)
	zombie_parent.add_child(zombie)

	## 关卡全场加速（「僵尸快跑」关 speed_factor_zombie = 2）：
	## 必须在 add_child 之后 —— 移动/攻击组件是在 _ready 里连上 signal_update_speed 的
	game_para.apply_speed_factor_to_zombie(zombie)

	## 只要创建僵尸，都要连接这两个信号
	zombie.signal_character_death.connect(_on_zombie_dead.bind(zombie))
	zombie.signal_character_be_hypno.connect(_on_zombie_hypno.bind(zombie))
	zombie.signal_lane_update.connect(zombie_update_lane.bind(zombie, zombie.lane))

	all_zombies_2d[zombie.lane].append(zombie)
	all_zombies_1d.append(zombie)

	curr_zombie_num += 1

	return zombie

#endregion

#region 僵尸死亡 魅惑信号 波次刷新 多轮游戏
#region 魅惑 死亡
## 僵尸被魅惑发射信号
func _on_zombie_hypno(zombie:Zombie000Base):
	## 出战僵尸保存列表删除该僵尸
	curr_zombie_num -= 1
	all_zombies_2d[zombie.lane].erase(zombie)
	## 掉血信号
	zombie.signal_zombie_hp_loss.emit(zombie.hp_component.get_all_hp(), zombie.curr_wave)
	var conns = zombie.signal_zombie_hp_loss.get_connections()
	for conn in conns:
		zombie.signal_zombie_hp_loss.disconnect(conn.callable)
	all_zombies_be_hypno.append(zombie)

	## 如果到了最后一波刷新,且最后一个僵尸被魅惑
	if is_end_wave and curr_zombie_num == 0:
		EventBus.push_event("create_trophy", [zombie.global_position])
		if is_instance_valid(multi_round_end_wave_timer):
			multi_round_end_wave_timer.stop()

## 僵尸发射死亡信号后调用函数
func _on_zombie_dead(zombie: Zombie000Base) -> void:
	all_zombies_1d.erase(zombie)
	if zombie.is_hypno:
		all_zombies_be_hypno.erase(zombie)
	else:
		curr_zombie_num -= 1
		all_zombies_2d[zombie.lane].erase(zombie)

		## 如果到了最后一波刷新,且僵尸全部死亡
		if is_end_wave and curr_zombie_num == 0:
			EventBus.push_event("create_trophy", [zombie.global_position])
			if is_instance_valid(multi_round_end_wave_timer):
				multi_round_end_wave_timer.stop()
#endregion

#region 波次刷新
func wave_refresh(curr_is_end_wave:bool):
	is_end_wave = curr_is_end_wave
	set_zombie_death_over_view()
	if is_end_wave:
		check_zombie_end_wave_timer.start()
		Log.debug("最后一波僵尸检测是否有离开当前视野的僵尸")
		## 多轮游戏计时器启动
		multi_round_end_wave_timer_start()

### 删除移动超出视野的僵尸,每次刷新僵尸调用
func set_zombie_death_over_view():
	## 遍历中 z.character_death_disappear() 会同步把僵尸从 all_zombies_1d 里删掉，
	## 边遍历边删会漏掉紧跟其后的僵尸，这里遍历副本
	for z:Zombie000Base in all_zombies_1d.duplicate():
		# 检查是否在屏幕外
		if z.global_position.x > zombie_range_pos_x.y or z.global_position.x < zombie_range_pos_x.x:
			#all_zombies_be_hypno.erase(z)
			z.character_death_disappear()
	#Log.debug(str("删除离开当前视野的僵尸，目前还剩的僵尸：") + str(all_zombies_1d))
#endregion

#region 多轮游戏
#region 触发
## 多轮游戏 非最后一轮 最后一波 计时器
func multi_round_end_wave_timer_start():
	if not is_instance_valid(multi_round_end_wave_timer):
		multi_round_end_wave_timer = Timer.new()
		multi_round_end_wave_timer.wait_time = multi_round_end_wave_time
		multi_round_end_wave_timer.one_shot = true
		multi_round_end_wave_timer.autostart = false
		multi_round_end_wave_timer.timeout.connect(_on_trigger_start_next_round_game)
		add_child(multi_round_end_wave_timer)
	multi_round_end_wave_timer.start()
	Log.debug("多轮游戏波次后一波计时器启动")

## 触发开始下一轮game
func _on_trigger_start_next_round_game():
	EventBus.push_event("start_next_round_game")
	multi_round_end_wave_timer.stop()
#endregion

#region 开始下一轮游戏
## 僵尸管理器更新
func start_next_game_zombie_mananger_update():
	is_end_wave = false
	## 新一轮可以重新开第一波
	is_first_wave_started = false
	match monster_mode:
		ConstLevelData.E_MonsterMode.Norm:
			check_zombie_end_wave_timer.stop()
			## 更新当前轮次的出怪列表
			update_multi_round_zombie_refresh_types(main_game.curr_game_round)
			zombie_wave_manager.start_next_game_zombie_wave_mananger_update()

	## 我是僵尸模式删除所有的僵尸（僵王一并清场，不产生击杀或奖杯）
	if game_para.is_zombie_mode:
		clear_bosses_for_next_round()
		for i in range(all_zombies_1d.size()-1,-1,-1):
			var zombie:Zombie000Base = all_zombies_1d[i]
			zombie.character_death_disappear()

#endregion


#region 多轮(无尽)出怪
## 多轮出怪获取出怪列表
func update_multi_round_zombie_refresh_types(curr_round:int) -> void:
	## 清空数据
	is_bungi = false
	zombie_refresh_types.clear()
	# 第一次选卡 (curr_round == 1) 的 “固定三种”：普僵 + 路障 + 铁桶
	if curr_round == 1:
		zombie_refresh_types.append(CharacterRegistry.ZombieType.Z001Norm)
		zombie_refresh_types.append(CharacterRegistry.ZombieType.Z003Cone)
		zombie_refresh_types.append(CharacterRegistry.ZombieType.Z005Bucket)
	else:
		## 出怪白名单按地图数据的默认僵尸行类型取（旧实现读的是已删除的
		## MainSceneRegistry.ZombieRowTypewithMainScenesMap 场景表）
		var map_data: ResourceMapData = game_para.map_data
		if map_data == null:
			Log.error("多轮出怪缺少地图数据，无法取得出怪白名单")
			return
		var whitelist_refresh_zombie_types_copy = Global.global_read_data.whitelist_refresh_zombie_types_with_zombie_row_type[map_data.get_default_zombie_row_type()].duplicate(true)
		zombie_refresh_types.append(CharacterRegistry.ZombieType.Z001Norm)
		whitelist_refresh_zombie_types_copy.erase(CharacterRegistry.ZombieType.Z001Norm)
		# 第二种：80% 路障 (Cone)，20% 报纸 (Paper)
		var prob = randf()
		if prob < 0.8:
			zombie_refresh_types.append(CharacterRegistry.ZombieType.Z003Cone)
			whitelist_refresh_zombie_types_copy.erase(CharacterRegistry.ZombieType.Z003Cone)
		else:
			zombie_refresh_types.append(CharacterRegistry.ZombieType.Z006Paper)
			whitelist_refresh_zombie_types_copy.erase(CharacterRegistry.ZombieType.Z006Paper)
		## 第二轮之后可能刷新僵尸(min(轮次*2,8)+2)个
		for i in range(min(curr_round * 2, 8)):
			var zombie_type_choose = whitelist_refresh_zombie_types_copy.pick_random()
			zombie_refresh_types.append(zombie_type_choose)
			whitelist_refresh_zombie_types_copy.erase(zombie_type_choose)

			if zombie_type_choose == CharacterRegistry.ZombieType.Z021Bungi:
				Log.debug("warning: 出怪刷新列表禁止使用 Z021Bungi ,已修改为选择 is_bungi 参数")
				is_bungi = true
				zombie_refresh_types.erase(zombie_type_choose)

			if whitelist_refresh_zombie_types_copy.is_empty():
				break

	Log.debug(str("当前轮次") + str(curr_round) + str("可能刷新的僵尸类型有:"))
	for zombie_type in zombie_refresh_types:
		Log.debug(Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName))
	if is_bungi:
		Log.debug(Global.character_registry.get_zombie_info(CharacterRegistry.ZombieType.Z021Bungi, CharacterRegistry.ZombieInfoAttribute.ZombieName))


#endregion


#endregion
#endregion

#region 僵王
## 返回本管理器是否仍在树中、未排队删除且所属有效关卡处于正式战斗阶段。
func is_game_running() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() \
		and is_instance_valid(main_game) and not main_game.is_queued_for_deletion() \
		and main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME


#region 僵王转发（业务见 zm_boss_registry.gd）
## 开战时按关卡配置自动生成一次僵王；卡牌召唤不占用该记录。
func try_auto_spawn_boss() -> ZB000Base:
	return boss_registry.try_auto_spawn_boss()

## 自动入口按关卡配置只生成一次；失败返回 null。
func create_boss() -> ZB000Base:
	return boss_registry.create_boss()

## 正式战斗、有效根节点及注册表允许时返回 true。
func can_summon_boss(boss_type: CharacterRegistry.ZombieBossType) -> bool:
	return boss_registry.can_summon_boss(boss_type)

## 卡牌召唤入口；每次成功返回新实例，失败返回 null。
func try_create_boss_from_card(boss_type: CharacterRegistry.ZombieBossType) -> ZB000Base:
	return boss_registry.try_create_boss_from_card(boss_type)

## 登记僵王实例并接入敌方计数；同一实例重复登记只返回 true。
func register_boss(boss: ZB000Base, boss_type: CharacterRegistry.ZombieBossType, count_as_new: bool = true) -> bool:
	return boss_registry.register_boss(boss, boss_type, count_as_new)

## 返回按登记顺序排列的存活实例快照。
func get_living_bosses() -> Array[ZB000Base]:
	return boss_registry.get_living_bosses()

## 返回存活僵王及累计结算数据，供关卡存档保存。
func get_save_game_data_bosses() -> Dictionary:
	return boss_registry.get_save_game_data_bosses()

## 仅暂存僵王存档数据，正式战斗开始时再恢复。
func load_game_data_bosses(data: Dictionary) -> void:
	boss_registry.load_game_data_bosses(data)

## 正式战斗开始后一次性恢复存活实例及累计记录，不重复计数。
func restore_saved_bosses() -> void:
	boss_registry.restore_saved_bosses()

## 我是僵尸模式轮间清场时一并移除僵王；清场不产生击杀或奖杯。
func clear_bosses_for_next_round() -> void:
	boss_registry.clear_bosses_for_next_round()
#endregion
## 僵王死亡后沿用普通清场判定：最后一波且场上已无敌人时才生成奖杯。
func _try_finish_wave(global_pos: Vector2) -> void:
	if not is_end_wave or curr_zombie_num != 0:
		return
	EventBus.push_event("create_trophy", [global_pos])
	if is_instance_valid(multi_round_end_wave_timer):
		multi_round_end_wave_timer.stop()
#endregion


#region 技能生成僵尸
## 判断技能能否将指定类型放入目标行，不依赖普通波次选行器，也不改变计数。
func can_spawn_skill_zombie(zombie_type: CharacterRegistry.ZombieType, lane: int) -> bool:
	if lane < 0 or lane >= all_zombie_rows.size() or lane >= all_zombies_2d.size():
		return false
	var row: ZombieRow = all_zombie_rows[lane]
	if not is_instance_valid(row) or not row.is_inside_tree() or row.is_queued_for_deletion() \
		or not is_instance_valid(row.zombie_create_position):
		return false
	if zombie_type == 0 or not Global.character_registry.ZombieInfo.has(zombie_type):
		return false
	var scene: PackedScene = Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieScenes) as PackedScene
	if scene == null or not scene.can_instantiate():
		return false
	var row_type: CharacterRegistry.ZombieRowType = Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
	return row_type == CharacterRegistry.ZombieRowType.Both \
		or row.zombie_row_type == CharacterRegistry.ZombieRowType.Both or row_type == row.zombie_row_type


## 技能生成入口：使用释放点 X 和目标行基准 Y，登记与计数复用普通创建流程。
func create_skill_zombie(zombie_type: CharacterRegistry.ZombieType, lane: int, spawn_x: float) -> Zombie000Base:
	if not is_game_running() or not is_finite(spawn_x) or not can_spawn_skill_zombie(zombie_type, lane):
		return null
	var row: ZombieRow = all_zombie_rows[lane]
	var spawn_position := Vector2(spawn_x, row.zombie_create_position.global_position.y)
	if not spawn_position.is_finite():
		return null
	var init_parameters: Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrWave: -1,
		Zombie000Base.E_ZInitAttr.ParticipatesNaturalRefresh: false,
	}
	return create_norm_zombie(zombie_type, row, init_parameters, spawn_position)


## 创建技能召唤的蹦极僵尸，目标在入树前注入；失败返回 null。
func create_skill_bungi(target_cell: PlantCell, anchor: Marker2D, on_created: Callable = Callable()) -> Zombie021Bungi:
	if not is_game_running() or not is_instance_valid(target_cell) \
		or target_cell.is_queued_for_deletion() or not target_cell.is_inside_tree() \
		or not main_game.is_ancestor_of(target_cell) or target_cell.get_bungi_target() == null:
		return null
	var lane: int = target_cell.row_col.x
	if not can_spawn_skill_zombie(CharacterRegistry.ZombieType.Z021Bungi, lane):
		return null
	var row: ZombieRow = all_zombie_rows[lane]
	var spawn_position := Vector2(target_cell.global_position.x + target_cell.size.x / 2.0,
		row.zombie_create_position.global_position.y)
	if not spawn_position.is_finite():
		return null
	var init_parameters: Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrWave: -1,
		Zombie000Base.E_ZInitAttr.ParticipatesNaturalRefresh: false,
	}
	return create_norm_zombie(CharacterRegistry.ZombieType.Z021Bungi, row, init_parameters,
		spawn_position, _initialize_skill_bungi.bind(target_cell, anchor, on_created)) as Zombie021Bungi


## [param zombie] 刚实例化且尚未入树的蹦极僵尸；先注入出战参数，再交给调用方登记。[br]
## 博士已经用进入动画表现召唤，因此这里跳过靶子预警、入树后立即下降。
## [param anchor] 博士手部绳子挂点；本仓库的蹦极绳子挂在自身节点下，暂时只作预留。
func _initialize_skill_bungi(zombie: Zombie021Bungi, target_cell: PlantCell, anchor: Marker2D, on_created: Callable) -> void:
	zombie.plant_cell = target_cell
	zombie.drop_start_delay = 0.0
	if is_instance_valid(zombie.bungee_target):
		zombie.bungee_target.visible = false
	if is_instance_valid(anchor) and zombie.has_method("set_bungee_anchor"):
		zombie.set_bungee_anchor(anchor)
	if on_created.is_valid():
		on_created.call(zombie)
#endregion


#region 生成关卡前展示僵尸
func create_prepare_show_zombies():
	zombie_show_in_start.create_prepare_show_zombies()

func delete_prepare_show_zombies():
	zombie_show_in_start.delete_prepare_show_zombies()
#endregion

#region 植物调用相关，寒冰菇\火爆辣椒\三叶草
## 冰冻所有僵尸和所有存活僵王；各僵王自行检查受击窗口。[br]
## [param time_ice] 完全冻结时长，单位为游戏秒。[br]
## [param time_decelerate] 解冻后的减速时长，单位为游戏秒。
func ice_all_zombie(time_ice:float, time_decelerate: float):
	## 冰消珊瑚
	is_ice = true
	start_ice_timer(time_ice)
	for zombie_row:Array in all_zombies_2d:
		if zombie_row.is_empty():
			continue
		for zombie:Zombie000Base in zombie_row:
			if not is_instance_valid(zombie):
				continue
			zombie.be_ice_freeze(time_ice, time_decelerate)
	# 僵王不加入普通僵尸列表，单独遍历登记集合，每只存活僵王只接收一次本次全场冻结。
	for boss: ZB000Base in get_living_bosses():
		boss.be_ice_freeze(time_ice, time_decelerate)

func start_ice_timer(wait_time:float):
	if not is_instance_valid(ice_timer):
		ice_timer = Timer.new()
		ice_timer.one_shot = true
		ice_timer.timeout.connect(_on_ice_timer_timeout)
		add_child(ice_timer)
	ice_timer.start(wait_time)

func _on_ice_timer_timeout():
	if not is_ice:
		Log.error("冰消珊瑚计时器有误，is_ice应该为true")
	is_ice = false




func jalapeno_bomb_item_lane(lane:int):
	## 冰道
	for i in range(all_ice_roads[lane].size()-1, -1, -1):
		var ice_road:IceRoad = all_ice_roads[lane][i]
		ice_road.ice_road_disappear()

## 火爆辣椒处理整行普通僵尸，并攻击所有存活僵王；僵王检查受击窗口，不限制行号。[br]
## [param lane] 辣椒所在的零起始行号，仅用于选择受影响的普通僵尸。
func jalapeno_bomb_lane_zombie(lane:int):
	# 倒序遍历当前行，普通僵尸被炸死时可能立即从列表移除。
	for i in range(all_zombies_2d[lane].size()-1,-1,-1) :
		if is_instance_valid(all_zombies_2d[lane][i]):
			## 当前接受爆炸伤害的普通僵尸，继续沿用其原有灰烬与删除规则。
			var zombie:Zombie000Base = all_zombies_2d[lane][i]
			zombie.be_bomb(1800, true)
	# 任意行的辣椒都可命中僵王，使用专用入口检查受击窗口并保留完整死亡演出。
	# 使用快照，某只僵王死亡不会影响其余实例遍历。
	for boss: ZB000Base in get_living_bosses():
		if is_instance_valid(boss):
			boss.be_jalapeno(1800)

## 三叶草吹走空中僵尸
func blover_blow_away_in_sky_zombie():
	for zombie_row:Array in all_zombies_2d:
		if zombie_row.is_empty():
			continue
		for i in range(zombie_row.size()-1, -1, -1):
			var zombie:Zombie000Base = zombie_row[i]
			if zombie.curr_be_attack_status == Zombie000Base.E_BeAttackStatusZombie.IsSky:
				zombie.be_blow_away()

#endregion

## 最后一波时每秒检查是否有僵尸离开当前视野
func _on_check_zombie_end_wave_timer_timeout() -> void:
	set_zombie_death_over_view()

## 僵尸换行,更新数据
func zombie_update_lane(zombie:Zombie000Base, ori_lane:int):
	if all_zombies_2d[ori_lane].has(zombie):
		all_zombies_2d[ori_lane].erase(zombie)
		all_zombies_2d[zombie.lane].append(zombie)
		## 先判断再断开：对未连接的 Callable 调 disconnect 会报错
		var ori_callback := zombie_update_lane.bind(zombie, ori_lane)
		if zombie.signal_lane_update.is_connected(ori_callback):
			zombie.signal_lane_update.disconnect(ori_callback)
		var new_callback := zombie_update_lane.bind(zombie, zombie.lane)
		if not zombie.signal_lane_update.is_connected(new_callback):
			zombie.signal_lane_update.connect(new_callback)
		#Log.debug("僵尸换行")


#region 控制台 所有僵尸死亡
## 所有僵尸死亡
func death_all_zombie():
	for zombie_row:Array in all_zombies_2d:
		if zombie_row.is_empty():
			continue
		for i in range(zombie_row.size()-1, -1, -1):
			var zombie:Zombie000Base = zombie_row[i]
			zombie.character_death_disappear()
#endregion