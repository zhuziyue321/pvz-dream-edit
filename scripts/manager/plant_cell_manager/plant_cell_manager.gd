extends MainGameSubManager
class_name PlantCellManager

@onready var plant_cells_root: Node2D = %PlantCellsRoot
@onready var tomb_stone_manager: TombStoneManager = $TombStoneManager

## 格子场景，按地图数据实例化
const PLANT_CELL_SCENE = preload("res://scenes/ui/plant_cell.tscn")

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


## 按地图数据生成行与格子（数据驱动，见 docs/地图实现.md）。
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

func init_manager() -> void:
	signal_connect_plant_cell_with_hand_manager(main_game.hand_manager)
	tomb_stone_manager.init_tomb_stone_manager(game_para)
	## 没有存档直接创建植物和创建罐子
	if not Global.main_game.is_save_game_data_on_init:
		create_pre_plant()
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


## 预种植植物数据
func create_pre_plant():
	## 预种植植物数据
	var all_pre_plant_data = game_para.all_pre_plant_data
	for pre_plant_data in all_pre_plant_data:
		if pre_plant_data == null:
			Log.error("关卡数据中预种植植物有空值")
			continue
		## 行或列大于当前最大值\小于0,跳过
		if pre_plant_data.plant_cell_pos.x > row_col.x or\
		pre_plant_data.plant_cell_pos.y > row_col.y or\
		pre_plant_data.plant_cell_pos.x < 0 or pre_plant_data.plant_cell_pos.y < 0:
			continue
		## 满屏铺满
		elif pre_plant_data.plant_cell_pos.x == 0 and pre_plant_data.plant_cell_pos.y == 0:
			for plant_cell_row in all_plant_cells:
				for plant_cell:PlantCell in plant_cell_row:
					plant_cell_pre_plant(plant_cell, pre_plant_data.plant_type, pre_plant_data.is_imitater_plant, game_para.is_zombie_mode)
		## 某一列
		elif pre_plant_data.plant_cell_pos.x == 0 and pre_plant_data.plant_cell_pos.y != 0:
			for plant_cell_row in all_plant_cells:
				var plant_cell:PlantCell = plant_cell_row[pre_plant_data.plant_cell_pos.y-1]
				plant_cell_pre_plant(plant_cell, pre_plant_data.plant_type, pre_plant_data.is_imitater_plant, game_para.is_zombie_mode)
		## 某一行
		elif pre_plant_data.plant_cell_pos.x != 0 and pre_plant_data.plant_cell_pos.y == 0:
			var plant_cell_row = all_plant_cells[pre_plant_data.plant_cell_pos.x-1]
			for plant_cell:PlantCell in plant_cell_row:
				plant_cell_pre_plant(plant_cell, pre_plant_data.plant_type, pre_plant_data.is_imitater_plant, game_para.is_zombie_mode)
		## 某一个
		else:
			var plant_cell:PlantCell = all_plant_cells[pre_plant_data.plant_cell_pos.x-1][pre_plant_data.plant_cell_pos.y-1]
			plant_cell_pre_plant(plant_cell, pre_plant_data.plant_type, pre_plant_data.is_imitater_plant, game_para.is_zombie_mode)

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
			plant_cell_pre_plant(plant_cell, plant_type, false, true)
	for plant_cell:PlantCell in all_plant_cells_create_plant_on_zombie_mode_copy:
		var plant_type:CharacterRegistry.PlantType = plant_random_pool_on_zombie_mode.get_random_item()
		plant_cell_pre_plant(plant_cell, plant_type, false, true)


#region 罐子
## 是否为罐子模式
var is_pot_mode := false
## 对罐子需求的植物格子僵尸行类型分成两组，水、路两种类型 根据罐子总数需求列数计算
var plant_cell_row_on_zombie_row_type:Dictionary[CharacterRegistry.ZombieRowType, Array] = {
	CharacterRegistry.ZombieRowType.Land:[],
	CharacterRegistry.ZombieRowType.Pool:[],
}

func init_pot():
	is_pot_mode = game_para.is_pot_mode
	match game_para.pot_mode:
		ConstLevelData.E_PotMode.Weight:
			init_pot_random_pool()
			init_plant_cell_row_on_zombie_row_type()
		ConstLevelData.E_PotMode.Fixd:
			init_plant_cell_row_on_zombie_row_type()

func cerate_pot():
	match game_para.pot_mode:
		ConstLevelData.E_PotMode.Weight:
			create_all_pot_on_weigth_mode()
		ConstLevelData.E_PotMode.Fixd:
			create_all_pot_on_fixed_mode()

## 将需求的植物格子按僵尸行类型分类
func init_plant_cell_row_on_zombie_row_type():
	if game_para.pot_col_range.y > row_col.y:
		game_para.pot_col_range.y = row_col.y
		Log.debug("warning:生成罐子的结束列数大于当前场景植物格子的列数，生成罐子的结束列数已修改为植物格子列数")
	## 罐子需要的列
	var need_col:int = game_para.pot_col_range.y - game_para.pot_col_range.x
	var num_pot_candidate:int = need_col * row_col.x
	Log.debug(str("设置罐子的列数：") + str(need_col) + str(" 罐子生成位置数量为：") + str(num_pot_candidate))

	if need_col == 0:
		Log.debug("warning: 罐子列数为0，取消生成罐子")
		return

	if game_para.pot_mode == ConstLevelData.E_PotMode.Fixd:
		Log.debug(str("罐子生成模式为 固定数量生成模式， 罐子生成总数为：") + str(game_para.pot_num_on_fixed_mode))
		assert(game_para.pot_num_on_fixed_mode <= num_pot_candidate, "罐子需求总数为：" + str(game_para.pot_num_on_fixed_mode) + "生成罐子候选植物格子数量为：" + str(num_pot_candidate))

	for i in range(all_plant_cells.size()):
		var plant_cell_row:Array= all_plant_cells[i]
		## 用 has() 兜底：ZombieRowType 以后新增取值（例如 Both）时不会因为字典缺键而报错
		var zombie_row_type: CharacterRegistry.ZombieRowType = Global.main_game.zombie_manager.all_zombie_rows[i].zombie_row_type
		if not plant_cell_row_on_zombie_row_type.has(zombie_row_type):
			plant_cell_row_on_zombie_row_type[zombie_row_type] = []
		plant_cell_row_on_zombie_row_type[zombie_row_type].append_array(plant_cell_row.slice(game_para.pot_col_range.x, game_para.pot_col_range.y))


#region 权重模式
## 罐子生成植物随机池
var pot_plant_random_pool:RandomPicker
## 罐子生成陆地僵尸随机池
var pot_zombie_random_pool:Dictionary[CharacterRegistry.ZombieRowType, RandomPicker] = {
	CharacterRegistry.ZombieRowType.Land : null,
	CharacterRegistry.ZombieRowType.Pool : null,
}

## 初始化罐子随机池
func init_pot_random_pool():
	Log.debug("初始化罐子随机池")
	Log.debug(str("罐子植物候选列表：") + str(game_para.candidate_plant_pot))
	Log.debug(str("罐子僵尸候选列表：") + str(game_para.candidate_zombie_pot_with_zombie_row_type))
	var pot_plant_random_pool_data = []
	for plant_type in game_para.candidate_plant_pot:
		pot_plant_random_pool_data.append([plant_type, game_para.candidate_plant_pot[plant_type]])
	pot_plant_random_pool = RandomPicker.new(pot_plant_random_pool_data)


	var pot_zombie_land_random_pool_data = []
	for zombie_type in game_para.candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Land]:
		pot_zombie_land_random_pool_data.append([zombie_type, game_para.candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Land][zombie_type]])
	pot_zombie_random_pool[CharacterRegistry.ZombieRowType.Land] = RandomPicker.new(pot_zombie_land_random_pool_data)

	var pot_zombie_pool_random_pool_data = []
	for zombie_type in game_para.candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Pool]:
		pot_zombie_pool_random_pool_data.append([zombie_type, game_para.candidate_zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Pool][zombie_type]])
	pot_zombie_random_pool[CharacterRegistry.ZombieRowType.Pool] = RandomPicker.new(pot_zombie_pool_random_pool_data)

## 权重模式 生成所有罐子
func create_all_pot_on_weigth_mode():
	var plant_cell_row_on_zombie_row_type_copy = plant_cell_row_on_zombie_row_type.duplicate(true)
	## 先对僵尸陆地和水路罐子划分
	for zombie_row_type in [CharacterRegistry.ZombieRowType.Land,CharacterRegistry.ZombieRowType.Pool]:
		for plant_cell:PlantCell in plant_cell_row_on_zombie_row_type_copy[zombie_row_type]:
			plant_cell_create_pot_on_weigth_mode(plant_cell)

## 权重模式 植物格子创建罐子
func plant_cell_create_pot_on_weigth_mode(plant_cell:PlantCell, ):
	var pot_para:Dictionary = get_pot_para_on_weight_mode(plant_cell)
	plant_cell_creat_pot(plant_cell, pot_para)

## 权重模式 获取罐子参数
func get_pot_para_on_weight_mode(plant_cell:PlantCell) -> Dictionary:
	var pot_para:Dictionary = {}
	pot_para[ScaryPot.E_PotInitParaAttr.PlantCell] = plant_cell
	## 罐子类型：随机、植物、僵尸
	pot_para[ScaryPot.E_PotInitParaAttr.PotType] = get_weighted_result(game_para.weight_pot_type, game_para.weight_pot_type_sum) as ScaryPot.E_PotType
	## 是否为固定结果罐子
	var p_res_fixed := randf()
	## 固定结果罐子
	if p_res_fixed < game_para.weight_res_fiexd:
		pot_para[ScaryPot.E_PotInitParaAttr.IsFixedRes] = true
		match pot_para[ScaryPot.E_PotInitParaAttr.PotType]:
			ScaryPot.E_PotType.Random:
				var p_is_plant_or_zombie := randf()
				if p_is_plant_or_zombie <= 0.5:
					pot_para[ScaryPot.E_PotInitParaAttr.PlantType] = pot_plant_random_pool.get_random_item()
				else:
					var curr_zomebi_row_type:CharacterRegistry.ZombieRowType = Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_row_type
					pot_para[ScaryPot.E_PotInitParaAttr.ZombieType] = pot_zombie_random_pool[curr_zomebi_row_type].get_random_item()
			ScaryPot.E_PotType.Plant:
				pot_para[ScaryPot.E_PotInitParaAttr.PlantType] =pot_plant_random_pool.get_random_item()
			ScaryPot.E_PotType.Zombie:
				var curr_zomebi_row_type:CharacterRegistry.ZombieRowType = Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_row_type
				pot_para[ScaryPot.E_PotInitParaAttr.ZombieType] = pot_zombie_random_pool[curr_zomebi_row_type].get_random_item()
	else:
		pot_para[ScaryPot.E_PotInitParaAttr.IsFixedRes] = false

	return pot_para

func get_weighted_result(weight: Vector3i, weight_sum:int) -> int:
	var r = randi_range(1, weight_sum)
	if r <= weight.x:
		return 0
	elif r <= weight.x + weight.y:
		return 1
	else:
		return 2
#endregion

#region 固定模式
## 固定模式创建所有的罐子
func create_all_pot_on_fixed_mode():
	var plant_cell_row_on_zombie_row_type_copy = plant_cell_row_on_zombie_row_type.duplicate(true)
	## 先对僵尸陆地和水路罐子划分创建僵尸罐子，先创建对僵尸行类型有要求的罐子
	for zombie_row_type in [CharacterRegistry.ZombieRowType.Land,CharacterRegistry.ZombieRowType.Pool]:
		## 先打乱植物格子顺序
		plant_cell_row_on_zombie_row_type_copy[zombie_row_type].shuffle()
		plant_cell_row_on_zombie_row_type_copy[zombie_row_type] = create_multi_zombie_pot(game_para.random_pot_zombie_with_zombie_row_type[zombie_row_type], plant_cell_row_on_zombie_row_type_copy[zombie_row_type], ScaryPot.E_PotType.Random)
		plant_cell_row_on_zombie_row_type_copy[zombie_row_type] = create_multi_zombie_pot(game_para.zombie_pot_with_zombie_row_type[zombie_row_type], plant_cell_row_on_zombie_row_type_copy[zombie_row_type], ScaryPot.E_PotType.Zombie)
	## 将剩余的植物格子放到一起
	var plant_cell_remaining:Array = []
	plant_cell_remaining.append_array(plant_cell_row_on_zombie_row_type_copy[CharacterRegistry.ZombieRowType.Land])
	plant_cell_remaining.append_array(plant_cell_row_on_zombie_row_type_copy[CharacterRegistry.ZombieRowType.Pool])
	## 打乱植物格子顺序
	plant_cell_remaining.shuffle()
	## 创建 both僵尸行类型的僵尸罐子
	plant_cell_remaining = create_multi_zombie_pot(game_para.random_pot_zombie_with_zombie_row_type[CharacterRegistry.ZombieRowType.Both], plant_cell_remaining, ScaryPot.E_PotType.Random)
	plant_cell_remaining = create_multi_zombie_pot(game_para.zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Both], plant_cell_remaining, ScaryPot.E_PotType.Zombie)

	plant_cell_remaining = create_multi_plant_pot(game_para.random_pot_plant, plant_cell_remaining, ScaryPot.E_PotType.Random)
	plant_cell_remaining = create_multi_plant_pot(game_para.plant_pot, plant_cell_remaining, ScaryPot.E_PotType.Plant)

	Log.debug(str("当前已经生成的罐子数量:") + str(curr_pot_num))
	Log.debug(str("结果固定罐子生成完成后剩余植物格子数量：") + str(plant_cell_remaining.size()))

	## 随机罐子数量和
	var random_pot_num_sum = game_para.random_pot_num_on_fixed_mode.x + game_para.random_pot_num_on_fixed_mode.y + game_para.random_pot_num_on_fixed_mode.z
	Log.debug(str("还需生成结果随机罐子数量(随机、植物、僵尸)：") + str(random_pot_num_sum))
	## 打乱顺序
	plant_cell_remaining.shuffle()

	if plant_cell_remaining.size() < random_pot_num_sum:
		Log.warn(
			"随机罐子数量(" + str(random_pot_num_sum) + ")超过剩余植物格子数("
			+ str(plant_cell_remaining.size()) + ")，多余的随机罐子将被跳过"
		)

	for i in range(game_para.random_pot_num_on_fixed_mode.x):
		if plant_cell_remaining.is_empty():
			break
		create_random_res_pot(plant_cell_remaining.pop_back(), ScaryPot.E_PotType.Random)

	for i in range(game_para.random_pot_num_on_fixed_mode.y):
		if plant_cell_remaining.is_empty():
			break
		create_random_res_pot(plant_cell_remaining.pop_back(), ScaryPot.E_PotType.Plant)

	for i in range(game_para.random_pot_num_on_fixed_mode.z):
		if plant_cell_remaining.is_empty():
			break
		create_random_res_pot(plant_cell_remaining.pop_back(), ScaryPot.E_PotType.Zombie)

	Log.debug(str("剩余罐子数量：") + str(plant_cell_remaining.size()) + str(" 使用 随机类型 结果随机罐子填充"))
	for plant_cell in plant_cell_remaining:
		create_random_res_pot(plant_cell)

	Log.debug(str("生成的所有罐子数量:") + str(curr_pot_num))

	#if ceil(curr_pot_num / float(row_col.x)) > 1:
		#shuffle_pot_on_row()


### TODO:按行打乱植物格子罐子  可以不用，生成时已经打乱顺序，
#func shuffle_pot_on_row():
	### 当前的罐子列数
	#var curr_pot_col = ceil(curr_pot_num / float(row_col.x))
	#for i in range(row_col.x):
		### 当前行有罐子的植物格子
		#var plant_cells_have_pot_on_row:Array = all_plant_cells[i].slice(-curr_pot_col)
		### 当前行的所有罐子
		#var all_pots_on_row:Array[ScaryPot] = []
		#for plant_cell in plant_cells_have_pot_on_row:
			#all_pots_on_row.append(plant_cell.pot)
#
		#assert(all_pots_on_row.size() == curr_pot_col, "当前行的罐子数量：" + str(all_pots_on_row.size()) + "罐子的列数: " + str(curr_pot_col))
		### 罐子打乱顺序
		#all_pots_on_row.shuffle()
		### 每个格子都有罐子，罐子与植物格子无信号连接，只修改引用，修改罐子父节点即可,
		#for j in range(curr_pot_col):
			#var plant_cell:PlantCell = plant_cells_have_pot_on_row[j]
			#var pot:ScaryPot = all_pots_on_row[j]
			#plant_cell.pot = pot
			#pot.reparent(plant_cell)
			#pot.position = Vector2(plant_cell.size.x / 2, plant_cell.size.y)
			#pot.plant_cell = plant_cell

## 创建一个结果随机罐子
func create_random_res_pot(plant_cell:PlantCell, pot_type:=ScaryPot.E_PotType.Random):
	var pot_para:Dictionary = {
		ScaryPot.E_PotInitParaAttr.PotType:pot_type,
		ScaryPot.E_PotInitParaAttr.IsFixedRes:false,
		ScaryPot.E_PotInitParaAttr.PlantCell:plant_cell,
		ScaryPot.E_PotInitParaAttr.IsCanLookRandom:Global.main_game.game_para.is_can_look_random_res_pot
	}
	plant_cell_creat_pot(plant_cell, pot_para)


## 创建多个僵尸罐子
func create_multi_zombie_pot(pot_num_zombie_types:Dictionary, plant_cells_candidate:Array, pot_type:ScaryPot.E_PotType)->Array:
	for zombie_type in pot_num_zombie_types:
		## 循环数量
		for i in range(pot_num_zombie_types[zombie_type]):
			if plant_cells_candidate.is_empty():
				Log.debug(str("warning: 僵尸类型") + str(Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName)) + str("没有对应的空闲植物格子"))
				return plant_cells_candidate
			var plant_cell:PlantCell = plant_cells_candidate.pick_random()
			var pot_para:Dictionary = {
				ScaryPot.E_PotInitParaAttr.PotType:pot_type,
				ScaryPot.E_PotInitParaAttr.IsFixedRes:true,
				ScaryPot.E_PotInitParaAttr.ZombieType:zombie_type,
				ScaryPot.E_PotInitParaAttr.PlantCell:plant_cell
			}
			plant_cell_creat_pot(plant_cell, pot_para)
			plant_cells_candidate.erase(plant_cell)
	return plant_cells_candidate

## 创建多个植物罐子
func create_multi_plant_pot(pot_num_plant_types:Dictionary, plant_cells_candidate:Array, pot_type:ScaryPot.E_PotType)->Array:
	for plant_type in pot_num_plant_types:
		## 循环数量
		for i in range(pot_num_plant_types[plant_type]):
			if plant_cells_candidate.is_empty():
				Log.warn("植物罐子候选格子已用尽，剩余的固定植物罐子将被跳过")
				return plant_cells_candidate
			var plant_cell:PlantCell = plant_cells_candidate.pick_random()
			var pot_para:Dictionary = {
				ScaryPot.E_PotInitParaAttr.PotType:pot_type,
				ScaryPot.E_PotInitParaAttr.IsFixedRes:true,
				ScaryPot.E_PotInitParaAttr.PlantType:plant_type,
				ScaryPot.E_PotInitParaAttr.PlantCell:plant_cell
			}
			plant_cell_creat_pot(plant_cell, pot_para)
			plant_cells_candidate.erase(plant_cell)
	return plant_cells_candidate


#endregion
## 植物格子创建罐子
func plant_cell_creat_pot(plant_cell:PlantCell, pot_para:Dictionary):
	var pot:ScaryPot = plant_cell.create_pot(pot_para)
	if is_pot_mode:
		pot.signal_open_pot.connect(pot_open_update)
	curr_pot_num += 1
	#Log.debug("创建一个罐子")

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

func plant_cell_pre_plant(plant_cell:PlantCell, plant_type:CharacterRegistry.PlantType, is_imitater:bool, is_zombie_mode:=false):
	plant_cell.create_plant(plant_type, false, false, is_imitater, is_zombie_mode)

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
	## 如果是罐子模式
	if game_para.is_pot_mode:
		## 如果不保留植物数据
		if not game_para.is_save_plant_on_pot_mode:
			Log.debug("开始清除植物")
			clear_all_plant_cell_data()
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
		## 创建植物
		create_pre_plant()
		create_plant_on_zombie_mode()

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
