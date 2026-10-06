extends MainGameSubManager
class_name PlantCellManager

@onready var plant_cells_root: Node2D = %PlantCellsRoot
@onready var tomb_stone_manager: TombStoneManager = $TombStoneManager

## 格子场景，按地图数据实例化
const PLANT_CELL_SCENE = preload("res://src/ui/plant_cell.tscn")

## PlantCellManager初始化
## 二维数组，保存每个植物格子节点
var all_plant_cells: Array[Array] = []
## 植物格子的行和列
var row_col:Vector2i = Vector2i.ZERO
## TombStoneManager(PlantCellManager子节点)初始化
## 生成的墓碑列表(一维)
var tombstone_list :Array[TombStone] = []
## 当前植物种植的信息[植物种类:植物数量]
var curr_plant_num:Dictionary[CharacterRegistry.PlantType, int]
## 当前罐子数量
var curr_pot_num = 0

## 我是僵尸模式的随机植物生成池
var plant_random_pool_on_zombie_mode:RandomPicker
## 我是僵尸模式下所有创建植物的植物格子
var all_plant_cells_create_plant_on_zombie_mode:Array[PlantCell] = []
## 我是僵尸模式必须先生成的植物
var all_must_plants_on_zombie_mode:Dictionary[CharacterRegistry.PlantType, int] = {}


func _ready() -> void:
	## 火爆辣椒爆炸特效
	EventBus.subscribe("jalapeno_bomb_effect", jalapeno_bomb_effect)
	## 火爆辣椒销毁道具[冰道和梯子]
	EventBus.subscribe("jalapeno_bomb_item_lane", jalapeno_bomb_item_lane)

	create_plant_cells_from_map_data()
	build_all_plant_cells()


## 按地图数据生成行与格子（数据驱动，见 docs/参考存档/地图实现.md）。
## 行列位置全部来自 ResourceMapData，不再在场景里手摆；
## 行节点只是容器（位置 0,0），每个格子的位置/尺寸单独设置，
## 因此不再依赖 RTL 镜像那套隐式坐标。
func create_plant_cells_from_map_data() -> void:
	var map_data: ResourceMapData = _get_map_data()
	if map_data == null or not map_data.is_valid():
		return
	for row_i in range(map_data.get_row_num()):
		var row_data: ResourceMapRowData = map_data.rows[row_i]
		var row_node := Node2D.new()
		row_node.name = "PlantCellsRow%d" % (row_i + 1)
		row_node.z_index = row_i * 50 + 10
		plant_cells_root.add_child(row_node)
		for col_j in range(map_data.get_col_num()):
			var plant_cell: PlantCell = PLANT_CELL_SCENE.instantiate()
			plant_cell.name = "PlantCell%d" % (col_j + 1)
			plant_cell.plant_cell_type = row_data.plant_cell_type
			var cell_rect: Rect2 = map_data.get_cell_rect(row_i, col_j)
			## 必须在 add_child 之前设好位置和尺寸：PlantCell._ready 会按自己的尺寸
			## 记录各容器节点的初始位置
			plant_cell.position = cell_rect.position
			## 阶梯偏移 = 该列的额外 y（非屋顶地图为 0），供检测层面反向补偿使用
			plant_cell.slope_step_y = row_data.get_col_dy(col_j)
			plant_cell.size = cell_rect.size
			row_node.add_child(plant_cell)


## 把生成好的行/格子收集成二维表（列 0 = 最左列），并给每个格子写 row_col。
## row_col 只在这里赋值一次：列号 = all_plant_cells[row] 的下标，别处不要再赋值。
func build_all_plant_cells() -> void:
	all_plant_cells.clear()
	var row_num := plant_cells_root.get_child_count()
	if row_num == 0:
		Log.error("地图缺少植物格子：PlantCellsRoot 下没有任何行节点")
		return
	## 列数取第一行，其余行必须一致（地图必须是矩形）
	var col_num := -1
	for plant_cells_row_i in row_num:
		var plant_cells_row: Node2D = plant_cells_root.get_child(plant_cells_row_i)
		var plant_cells_row_node := []
		for plant_cells_col_j in range(plant_cells_row.get_child_count()):
			var plant_cell: PlantCell = plant_cells_row.get_child(plant_cells_col_j)
			plant_cell.row_col = Vector2i(plant_cells_row_i, plant_cells_row_node.size())
			plant_cells_row_node.append(plant_cell)
			plant_cell.signal_plant_create.connect(update_plant_info_create)
			plant_cell.signal_plant_free.connect(update_plant_info_free)

		if col_num < 0:
			col_num = plant_cells_row_node.size()
		elif plant_cells_row_node.size() != col_num:
			Log.error(
				"地图第 %d 行的格子数(%d)与第 1 行(%d)不一致，地图行列必须构成矩形"
				% [plant_cells_row_i, plant_cells_row_node.size(), col_num]
			)

		all_plant_cells.append(plant_cells_row_node)

	row_col = Vector2i(all_plant_cells.size(), col_num)


## 本关卡的地图数据
func _get_map_data() -> ResourceMapData:
	if game_para == null:
		return null
	return game_para.map_data


#region 植物信息
## 更新植物信息(创建新植物)
func update_plant_info_create(_plant_cell:PlantCell, plant_type:CharacterRegistry.PlantType):
	curr_plant_num[plant_type] = curr_plant_num.get(plant_type, 0) + 1
	EventBus.push_event("update_card_purple_sun_cost")

## 更新植物信息(植物死亡)
func update_plant_info_free(_plant_cell:PlantCell, plant_type:CharacterRegistry.PlantType):
	## 用 get() 兜底：植物可能在记录创建前就被销毁（例如读档先删后建），
	## 直接 curr_plant_num[plant_type] -= 1 在键不存在时会报错
	curr_plant_num[plant_type] = curr_plant_num.get(plant_type, 0) - 1
	EventBus.push_event("update_card_purple_sun_cost")
	if curr_plant_num[plant_type] < 0:
		Log.error(str(plant_type) + str(":该植物类型数量小于0"))
		curr_plant_num.erase(plant_type)
#endregion

#region 邻居查询
## 网格查询归格子管理器：all_plant_cells / row_col 都是这里的数据，
## PlantCell 只按 row_col 转发（见 PlantCell.get_plant_surrounding / get_plant_cell_surrounding）

## 获取某个格子周围一圈(包括本身格子)的某种植物
func get_plant_surrounding(plant_cell:PlantCell, p_t:CharacterRegistry.PlantType) -> Array[Plant000Base]:
	var all_plant:Array[Plant000Base] = []
	## 植物种植条件
	var plant_condition:ResourcePlantCondition = Global.character_registry.get_plant_info(p_t, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	for i in range(max(0, plant_cell.row_col.x-1), min(row_col.x, plant_cell.row_col.x+2)):
		for j in range(max(0, plant_cell.row_col.y-1), min(row_col.y, plant_cell.row_col.y+2)):
			var p_c:PlantCell = all_plant_cells[i][j]
			var p_c_plant := p_c.get_plant(plant_condition.place_plant_in_cell)
			if is_instance_valid(p_c_plant) and p_c_plant.plant_type == p_t:
				all_plant.append(p_c_plant)
	return all_plant

## 获取某个格子周围一圈的植物格子，包括本身
func get_plant_cell_surrounding(plant_cell:PlantCell) -> Array[PlantCell]:
	var all_plant_cells_surrounding:Array[PlantCell]
	for i in range(max(0, plant_cell.row_col.x-1), min(row_col.x, plant_cell.row_col.x+2)):
		for j in range(max(0, plant_cell.row_col.y-1), min(row_col.y, plant_cell.row_col.y+2)):
			all_plant_cells_surrounding.append(all_plant_cells[i][j])
	return all_plant_cells_surrounding
#endregion

func init_manager() -> void:
	signal_connect_plant_cell_with_hand_manager(main_game.hand_manager)
	tomb_stone_manager.init_tomb_stone_manager(game_para)
	## 没有存档直接创建植物和创建罐子
	if not Global.main_game.is_save_game_data_on_init:
		init_pot()
		cerate_pot()
		if game_para.is_zombie_mode:
			init_plant_on_zombie_mode()
			create_plant_on_zombie_mode()

	## 有存档初始化罐子数据 我是僵尸数据
	else:
		init_pot()
		if game_para.is_zombie_mode:
			init_plant_on_zombie_mode()

## plant_cell与hand_manager信号连接
func signal_connect_plant_cell_with_hand_manager(hand_manager:HandManager):
	## 植物种植区域信号
	for plant_cells_row in all_plant_cells:
		for plant_cell in plant_cells_row:
			plant_cell = plant_cell as PlantCell
			plant_cell.click_cell.connect(hand_manager._on_click_cell)
			plant_cell.cell_mouse_enter.connect(hand_manager._on_cell_mouse_enter)
			plant_cell.cell_mouse_exit.connect(hand_manager._on_cell_mouse_exit)


## 按一条「系统种植」数据种下植物
## 关卡脚本 run_flow() 里的 `system_plant()` 和「系统种植」时间轴事件共用这一种法。
## plant_cell_pos 语义（从 1 开始，0 表示整行 / 整列）：
##   (0,0) 满屏 / (0,y) 第 y 列 / (x,0) 第 x 行 / (x,y) 第 x 行第 y 列
func system_plant_one(plant_data: SystemPlantResource) -> void:
	if plant_data == null:
		Log.error("系统种植数据有空值")
		return
	## 行或列大于当前最大值\小于0,跳过
	if plant_data.plant_cell_pos.x > row_col.x or\
	plant_data.plant_cell_pos.y > row_col.y or\
	plant_data.plant_cell_pos.x < 0 or plant_data.plant_cell_pos.y < 0:
		return
	## 满屏铺满
	elif plant_data.plant_cell_pos.x == 0 and plant_data.plant_cell_pos.y == 0:
		for plant_cell_row in all_plant_cells:
			for plant_cell:PlantCell in plant_cell_row:
				plant_cell.create_plant(plant_data.plant_type, false, false, plant_data.is_imitater_plant, game_para.is_zombie_mode)
	## 某一列
	elif plant_data.plant_cell_pos.x == 0 and plant_data.plant_cell_pos.y != 0:
		for plant_cell_row in all_plant_cells:
			var plant_cell:PlantCell = plant_cell_row[plant_data.plant_cell_pos.y-1]
			plant_cell.create_plant(plant_data.plant_type, false, false, plant_data.is_imitater_plant, game_para.is_zombie_mode)
	## 某一行
	elif plant_data.plant_cell_pos.x != 0 and plant_data.plant_cell_pos.y == 0:
		var plant_cell_row = all_plant_cells[plant_data.plant_cell_pos.x-1]
		for plant_cell:PlantCell in plant_cell_row:
			plant_cell.create_plant(plant_data.plant_type, false, false, plant_data.is_imitater_plant, game_para.is_zombie_mode)
	## 某一个
	else:
		var plant_cell:PlantCell = all_plant_cells[plant_data.plant_cell_pos.x-1][plant_data.plant_cell_pos.y-1]
		plant_cell.create_plant(plant_data.plant_type, false, false, plant_data.is_imitater_plant, game_para.is_zombie_mode)

## 始化我是僵尸模式的植物数据
func init_plant_on_zombie_mode():
	all_must_plants_on_zombie_mode = game_para.all_must_plants_on_zombie_mode
	var plant_random_pool_on_zombie_mode_data := []
	for plant_type in game_para.all_plants_weight_on_zombie_mode.keys():
		plant_random_pool_on_zombie_mode_data.append([plant_type, game_para.all_plants_weight_on_zombie_mode[plant_type]])
	plant_random_pool_on_zombie_mode = RandomPicker.new(plant_random_pool_on_zombie_mode_data)
	all_plant_cells_create_plant_on_zombie_mode.clear()

	for i in range(row_col.x):
		all_plant_cells_create_plant_on_zombie_mode.append_array(all_plant_cells[i].slice(0, game_para.plant_col_on_zombie_mode))

## 创建我是僵尸模式的植物
func create_plant_on_zombie_mode():
	var all_plant_cells_create_plant_on_zombie_mode_copy = all_plant_cells_create_plant_on_zombie_mode.duplicate(true)
	all_plant_cells_create_plant_on_zombie_mode_copy.shuffle()
	for plant_type in all_must_plants_on_zombie_mode.keys():
		## 当前种类植物的个数
		for i in range(all_must_plants_on_zombie_mode[plant_type]):
			## 如果已经全都种植过了
			if all_plant_cells_create_plant_on_zombie_mode_copy.is_empty():
				Log.debug("warning: 我是僵尸模式当前选择列数已被必种植植物种植满")
				continue
			var plant_cell:PlantCell = all_plant_cells_create_plant_on_zombie_mode_copy.pop_back()
			## 我是僵尸模式种的全是普通植物，模仿者材质那一档（第 4 个参数）不参与
			plant_cell.create_plant(plant_type, false, false, false, true)
	for plant_cell:PlantCell in all_plant_cells_create_plant_on_zombie_mode_copy:
		var plant_type:CharacterRegistry.PlantType = plant_random_pool_on_zombie_mode.get_random_item()
		plant_cell.create_plant(plant_type, false, false, false, true)


#region 罐子
## 是否为罐子模式
var is_pot_mode := false
## 本批刚创建出来的罐子（挑「戴夫提示罐」用，见 create_pot_hint()）
var curr_round_pots:Array[ScaryPot] = []
## 对罐子需求的植物格子僵尸行类型分成两组，水、路两种类型 根据罐子总数需求列数计算
var plant_cell_row_on_zombie_row_type:Dictionary[CharacterRegistry.ZombieRowType, Array] = {
	CharacterRegistry.ZombieRowType.Land:[],
	CharacterRegistry.ZombieRowType.Pool:[],
}

func init_pot():
	PcmPotUtil.init_pot(self)

func cerate_pot():
	PcmPotUtil.cerate_pot(self)

## 清除场上所有还没砸开的罐子（切换批次时兜底：正常流程罐子已经被砸光了）
func clear_all_pot():
	PcmPotUtil.clear_all_pot(self)

## 植物格子创建罐子
func plant_cell_creat_pot(plant_cell:PlantCell, pot_para:Dictionary):
	PcmPotUtil.plant_cell_creat_pot(self, plant_cell, pot_para)

## 若为罐子模式 罐子打开后更新是否结束，连接信号
## [is_zombie:bool] 是否为僵尸
## [glo_pos:bool] 最后一个罐子创建奖杯的位置
func pot_open_update(is_zombie:bool, glo_pos:Vector2):
	curr_pot_num -= 1
	if curr_pot_num == 0:
		## 如果最后一个罐子是僵尸，并且场上有僵尸,让僵尸管理器管理最终胜利
		if is_zombie or Global.main_game.zombie_manager.curr_zombie_num != 0:
			EventBus.push_event("end_wave_zombie")
		else:
			EventBus.push_event("create_trophy", glo_pos)

#endregion

func create_tombstone(new_num:int):
	tomb_stone_manager.create_tombstone(new_num)

## 火爆辣椒爆炸特效
## [lane:int]:行
func jalapeno_bomb_effect(lane:int):
	for plant_cell:PlantCell in all_plant_cells[lane]:
		var fire_new:BombEffectFire = SceneRegistry.FIRE.instantiate()
		## 修改其图层
		fire_new.z_index = lane * 50 + 40
		fire_new.z_as_relative = false

		plant_cell.add_child(fire_new)
		fire_new.global_position = plant_cell.global_position + Vector2(plant_cell.size.x / 2, plant_cell.size.y)
		fire_new.activate_bomb_effect()

func jalapeno_bomb_item_lane(lane:int):
	## 梯子
	for p_c :PlantCell in all_plant_cells[lane]:
		if is_instance_valid(p_c.ladder):
			p_c.ladder.queue_free()


## 获取有植物的植物格子 (蹦极)
func get_cell_have_plant()->Array[PlantCell]:
	var all_cell_have_plant:Array[PlantCell]
	for plant_cell_lane in all_plant_cells:
		for plant_cell:PlantCell in plant_cell_lane:
			if plant_cell.get_curr_plant_num()>0:
				all_cell_have_plant.append(plant_cell)
	return all_cell_have_plant

#region 多轮游戏
func start_next_game_plant_cell_manager_update():
	## 是否已经清除植物
	var is_clear_plant:=false
	## 如果是罐子模式：每批都从空草坪重新开始（原版冒险 4-5：3 / 4 / 5 列一批比一批宽）
	if game_para.is_pot_mode:
		Log.debug("开始清除植物")
		clear_all_plant_cell_data()
		## 上一批没砸开的罐子一起清掉，保证每批都能摆满本批的列
		clear_all_pot()
		## 等待两帧更新数据
		await get_tree().process_frame
		await get_tree().process_frame
		is_clear_plant = true
	## 我是僵尸模式
	if game_para.is_zombie_mode:
		if not is_clear_plant:
			Log.debug("开始清除植物")
			clear_all_plant_cell_data()
			## 等待两帧更新数据
			await get_tree().process_frame
			await get_tree().process_frame
			is_clear_plant = true
		if plant_random_pool_on_zombie_mode.get_item_weight(CharacterRegistry.PlantType.P002SunFlower) > 1:
			Log.debug(str("我是僵尸多轮游戏模式，更新向日葵随机权重为:") + str(max(9-Global.main_game.curr_game_round, 1)))
			plant_random_pool_on_zombie_mode.update_item_weight(CharacterRegistry.PlantType.P002SunFlower, max(9-Global.main_game.curr_game_round, 1))
		Log.debug("我是僵尸模式创建植物")
		create_plant_on_zombie_mode()

	## 多轮砸罐子关每批罐子的配置不一样（原版冒险 4-5：3 列 → 4 列 → 5 列，一批比一批难），
	## 先切到本轮的配置，再按本轮的列数重算候选格子，最后创建罐子
	if game_para.is_pot_mode:
		game_para.apply_pot_config_on_round(Global.main_game.curr_game_round)
		PcmPotUtil.init_plant_cell_row_on_zombie_row_type(self)
	## 创建罐子
	cerate_pot()



#endregion
#region 存档
## 植物格子管理器存档
func get_save_game_data_plant_cell_manager() -> ResourceSaveGamePlantCellManager:
	var save_game_data_plant_cell_manager:ResourceSaveGamePlantCellManager = ResourceSaveGamePlantCellManager.new()

	for plant_cell_lane in all_plant_cells:
		for plant_cell:PlantCell in plant_cell_lane:
			save_game_data_plant_cell_manager.all_plant_cells_datas.append(plant_cell.get_save_game_data_plant_cell())

	save_game_data_plant_cell_manager.tomb_stone_manager_data = tomb_stone_manager.get_save_game_data_tomb_stone_manager()

	return save_game_data_plant_cell_manager

## 清除所有植物数据
func clear_all_plant_cell_data():
	for plant_cell_lane in all_plant_cells:
		for plant_cell:PlantCell in plant_cell_lane:
			plant_cell.clear_data_plant_cell()

## 植物格子管理器读档
func load_game_data_plant_cell_manager(save_game_data_plant_cell_manager:ResourceSaveGamePlantCellManager):
	#clear_all_plant_cell_data()
	### INFO: 等待两帧,queue_free()删除后
	### 若是等待一帧,一局游戏多次读档测试时稳定触发某次植物未删除,不知道为什么
	#await get_tree().process_frame
	#await get_tree().process_frame

	for save_game_data_plant_cell:ResourceSaveGamePlantCell in save_game_data_plant_cell_manager.all_plant_cells_datas:
		var plant_cell:PlantCell = all_plant_cells[save_game_data_plant_cell.row_col.x][save_game_data_plant_cell.row_col.y]
		plant_cell.load_game_data_plant_cell(save_game_data_plant_cell)

	tomb_stone_manager.load_game_data_tomb_stone_manager(save_game_data_plant_cell_manager.tomb_stone_manager_data )

#endregion