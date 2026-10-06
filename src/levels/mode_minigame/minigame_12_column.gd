extends LevelScriptBase
## minigame_12_column —— 原版迷你游戏**第 12 关**「排山倒海」(Column Like You See 'Em)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ 存档键沿用改名之前写死的值（102_0_0005），**不跟着序号改**：改了会让玩家已通关的记录错位。
##
## **整列种植是本关专属机制，全部写在本文件**（硬约束 §1-8）：
##   原版规则（PVZ Wiki https://plantsvszombies.wiki.gg/wiki/Column_Like_You_See_'Em）：
##   传送带送植物，往任意一格种下去，**同一列的每一行都种上同一种**。
## 用到的通用设施（都不含本关规则，改玩法不用去动它们）：
##   · `PlantCell.signal_plant_create` / `cell_mouse_enter` / `cell_mouse_exit` —— 格子侧的通用信号
##   · `ResourcePlantCondition.judge_is_can_plant()` —— 「这一格能不能种」的唯一判据
##   · `EventBus` 的 `hand_card_take` / `hand_card_release` —— 手持卡片状态的通用广播
##   · `LevelScriptBase.init_level_items()` —— 进关接线的时机：格子已建好、玩家还动手不了
## 手持组件（`HandComponentCharacter`）只做通用校验，**不认识本关玩法**，也不再有 is_mode_column 分支。


## 整列虚影的透明度：与手持组件那一格虚影一致（0.5 = 「能种」）
const SHADOW_ALPHA := 0.5


func _init() -> void:
	save_key = "102_0_0005"
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_BG = ConstLevelData.GameBg.Roof
	## 原版本关播「Ultimate Battle」（与冒险 1-10 / 2-10 / 3-10 同源），**不是**僵王曲
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Music_(PvZ))
	## ——「Levels 1-10, 2-10, 3-10, the Mini-games Column Like You See 'Em and Air Raid,
	##    and Brain Busters feature the track 'Ultimate Battle'」
	game_BGM = ConstLevelData.GameBGM.UltimateBattle
	is_day_sun = false
	zombie_multy = 10
	is_bungi = true
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	start_sun = 50000
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	3: 1,
	7: 1,
	18: 1,
	21: 1,
	33: 1,
	34: 1,
	35: 1,
	40: 1
	})
	conveyor_order = ResourceCardReference.create_plant_order({
	0: 5,
	1: 24,
	2: 40,
	3: 32,
	4: 36,
	9: 45
	})
	create_new_card_speed = 1.5


#region 整列种植：进关接线 / 运行期状态
## 运行期：主游戏管理器（init_level_items 时存一份，取格子与画布层都用它）
var main_game: MainGameManager = null
## 运行期：当前手持的卡片（跟着 EventBus 的 hand_card_take / hand_card_release 走）
## 只在「手上拿着植物卡」的这段时间里，整列虚影与整列补齐才生效
var curr_card: Card = null
## 整列虚影：一行一个，与 `all_plant_cells` 的行同序
var column_shadows: Array[Node2D] = []
## 补齐整列时自己调 `create_plant` 会再触发 signal_plant_create，用这个标记挡掉递归
var is_filling_column := false


## 进关接线：格子已建好、玩家还动手不了（时机说明见 LevelScriptBase.init_level_items）
## **接线必须在这里做**：留到 run_flow() 就晚了 —— 那时玩家已经选完卡了
## [item_root] 背景物品层：虚影不挂这里（背景层在草坪之下，会被草坪与植物盖住），
## 挂 `MainGameManager.canvas_layer_temp` —— 与手持组件的格子虚影同层，观感与改造前一致
func init_level_items(mg: MainGameManager, _item_root: Node2D) -> void:
	## 重进关可能已经接过一次线：先原样收一遍（幂等）再重接，不留两叠虚影
	_free_column_items()
	main_game = mg
	for plant_cells_row in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in plant_cells_row:
			_connect_cell(plant_cell)
	EventBus.subscribe("hand_card_take", _on_hand_card_take)
	EventBus.subscribe("hand_card_release", _on_hand_card_release)


## 收摊：断格子信号、退订事件、释放虚影 —— **可重复调用**
## 关卡结束（通关 / 判负 / 僵尸进家）与重进关都会走这里
func _free_column_items() -> void:
	_free_column_shadows()
	curr_card = null
	if is_instance_valid(main_game):
		for plant_cells_row in main_game.plant_cell_manager.all_plant_cells:
			for plant_cell: PlantCell in plant_cells_row:
				_disconnect_cell(plant_cell)
		main_game = null
	EventBus.unsubscribe("hand_card_take", _on_hand_card_take)
	EventBus.unsubscribe("hand_card_release", _on_hand_card_release)


func _connect_cell(plant_cell: PlantCell) -> void:
	if not plant_cell.signal_plant_create.is_connected(_on_plant_create):
		plant_cell.signal_plant_create.connect(_on_plant_create)
	if not plant_cell.cell_mouse_enter.is_connected(_on_cell_mouse_enter):
		plant_cell.cell_mouse_enter.connect(_on_cell_mouse_enter)
	if not plant_cell.cell_mouse_exit.is_connected(_on_cell_mouse_exit):
		plant_cell.cell_mouse_exit.connect(_on_cell_mouse_exit)


func _disconnect_cell(plant_cell: PlantCell) -> void:
	if plant_cell.signal_plant_create.is_connected(_on_plant_create):
		plant_cell.signal_plant_create.disconnect(_on_plant_create)
	if plant_cell.cell_mouse_enter.is_connected(_on_cell_mouse_enter):
		plant_cell.cell_mouse_enter.disconnect(_on_cell_mouse_enter)
	if plant_cell.cell_mouse_exit.is_connected(_on_cell_mouse_exit):
		plant_cell.cell_mouse_exit.disconnect(_on_cell_mouse_exit)
#endregion


#region 整列种植：三个入口（持卡 / 悬停 / 种下）
## 拿到卡片：手上是植物卡时为每一行造一份虚影（形象直接取卡片自己的静态角色）
func _on_hand_card_take(card: Card) -> void:
	curr_card = card
	_create_column_shadows()


## 放下卡片：虚影立刻收掉（幂等）
func _on_hand_card_release(_card: Card) -> void:
	curr_card = null
	_free_column_shadows()


## 鼠标进入格子：把同列能种的行都摆上虚影
## 悬停那一格的手持虚影由手持组件自己出，这里跳过，免得同一格叠两层
func _on_cell_mouse_enter(plant_cell: PlantCell) -> void:
	if not _is_holding_plant_card():
		return
	var place_plant_in_cell := _get_place_plant_in_cell()
	var col: int = plant_cell.row_col.y
	for row in column_shadows.size():
		var shadow: Node2D = column_shadows[row]
		if not is_instance_valid(shadow):
			continue
		if row == plant_cell.row_col.x:
			shadow.modulate.a = 0
			continue
		var cell_in_column := _get_cell(row, col)
		if cell_in_column == null or not _can_plant_in(cell_in_column):
			shadow.modulate.a = 0
			continue
		shadow.global_position = cell_in_column.get_new_plant_static_shadow_global_position(place_plant_in_cell)
		shadow.modulate.a = SHADOW_ALPHA


## 鼠标移出格子：整列虚影全藏起来
func _on_cell_mouse_exit(_plant_cell: PlantCell) -> void:
	_hide_column_shadows()


## 种下一株 → 同列其它行补上同一株（本关的「排山倒海」就这一条规则）
## 补的行能不能种仍由格子自己判（`judge_is_can_plant`），种不进去的行直接跳过
func _on_plant_create(plant_cell: PlantCell, _plant_type: CharacterRegistry.PlantType) -> void:
	if is_filling_column or not _is_holding_plant_card():
		## 没持卡时的种植物（开局预置的花盆这类）不算玩家的整列种植
		return
	is_filling_column = true
	var col: int = plant_cell.row_col.y
	for row in _get_row_num():
		if row == plant_cell.row_col.x:
			continue
		var cell_in_column := _get_cell(row, col)
		if cell_in_column == null:
			continue
		## 坚果包扎术：整列补种时同样优先修复可修复的坚果
		var first_aid_plant := cell_in_column.get_first_aid_plant(curr_card.card_plant_type)
		if first_aid_plant != null:
			first_aid_plant.be_first_aid_heal()
			continue
		if _can_plant_in(cell_in_column):
			cell_in_column.create_plant(curr_card.card_plant_type, curr_card.is_imitater)
	is_filling_column = false
	_hide_column_shadows()
#endregion


#region 整列虚影：创建 / 显示 / 清理
## 造整列虚影：一行一个，先全透明（哪一行能种由鼠标进格子时判）
func _create_column_shadows() -> void:
	_free_column_shadows()
	if not _is_holding_plant_card() or not is_instance_valid(main_game):
		return
	if not is_instance_valid(curr_card.character_static) or curr_card.character_static.get_child_count() == 0:
		Log.warn("排山倒海：卡片没有静态角色，本次不显示整列虚影")
		return
	for _row in _get_row_num():
		var shadow := curr_card.character_static.duplicate()
		## 卡片里的角色是按卡片尺寸缩过的，摆到格子上要还原成实际大小
		shadow.get_child(0).scale = Vector2.ONE
		shadow.modulate.a = 0
		main_game.canvas_layer_temp.add_child(shadow)
		column_shadows.append(shadow)


func _hide_column_shadows() -> void:
	for shadow in column_shadows:
		if is_instance_valid(shadow):
			shadow.modulate.a = 0


## 释放整列虚影（可重复调用）
func _free_column_shadows() -> void:
	for shadow in column_shadows:
		if is_instance_valid(shadow):
			shadow.queue_free()
	column_shadows.clear()
#endregion


#region 小工具
## 手上是不是一张植物卡（僵尸卡不参与整列种植：本关传送带只发植物）
func _is_holding_plant_card() -> bool:
	if not is_instance_valid(curr_card):
		return false
	return curr_card.card_plant_type != CharacterRegistry.PlantType.Null


## 这一格能不能种下当前手上的植物 —— 与手持组件用的是同一条判据
func _can_plant_in(plant_cell: PlantCell) -> bool:
	var plant_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		curr_card.card_plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if plant_condition == null:
		return false
	return plant_condition.judge_is_can_plant(plant_cell, curr_card.card_plant_type)


## 当前卡片种下去落在格子的哪个槽位（决定虚影摆哪儿）
func _get_place_plant_in_cell() -> CharacterRegistry.PlacePlantInCell:
	var plant_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		curr_card.card_plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if plant_condition == null:
		return CharacterRegistry.PlacePlantInCell.Norm
	return plant_condition.place_plant_in_cell


## 草坪行数（all_plant_cells 是 [行][列]）
func _get_row_num() -> int:
	if not is_instance_valid(main_game):
		return 0
	return main_game.plant_cell_manager.row_col.x


## 取 [row][col] 的格子；越界或已失效返回 null
func _get_cell(row: int, col: int) -> PlantCell:
	if not is_instance_valid(main_game):
		return null
	var all_cells: Array = main_game.plant_cell_manager.all_plant_cells
	if row < 0 or row >= all_cells.size():
		return null
	var row_cells: Array = all_cells[row]
	if col < 0 or col >= row_cells.size():
		return null
	return row_cells[col] as PlantCell
#endregion


func run_flow(_mg: MainGameManager) -> void:
	## 屋顶是裸地：先沿整列铺出左侧 8 列的种植位（原版本关 9 列里只有最右一列没有花盆）
	await plant_flower_pot_columns(8)
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z006Paper,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z024Gargantuar,
		CharacterRegistry.ZombieType.Z022Ladder,
		CharacterRegistry.ZombieType.Z009Jackson,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(-1, zombie_list)
	## 关卡结束（赢 / 输 / 僵尸进家都从这里往下走）：整列虚影与格子接线由本关自己收掉
	_free_column_items()
