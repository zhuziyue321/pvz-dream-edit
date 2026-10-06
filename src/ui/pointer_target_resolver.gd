extends RefCounted
class_name PointerTargetResolver
## 箭头目标的解析：把「要指哪一类东西」翻译成**画布坐标**
##
## 关卡的「箭头快捷工具」（LevelTimelineEventArrow）与提示条（TutorialAdviceUI）共用这一份 ——
## 箭头跑在关卡流程里（没有教程管理器），解析不能挂在某个管理器上。
## 本类只回答「目标现在在屏幕上的哪个点」，画箭头是 TutorialAdviceUI / TutorialPointer 的事。
##
## 地图是数据驱动的（1-1 只有一行铺了草皮、1-5 保龄球关红线右边种不了），
## 所以「指向草坪」不能取几何中心，要按种植条件找一个真能种下的格子。

## 箭头可以指向的目标种类
enum E_PointerTarget {
	None,	## 不显示箭头
	Card,	## 指向卡槽 / 传送带上 plant_type 对应的卡（plant_type 为 Null 时指向第一张卡）
	Lawn,	## 指向草坪中央能种下 plant_type 的格子
	Sun,	## 指向场上的一颗还没收的阳光
	Shovel,	## 指向卡槽里的铲子
	Plant,	## 指向草坪上一株还活着的植物
}


## 解析箭头落点；目标还没出现（场上还没有阳光 / 没有那张卡）时返回 null
## caller 拿不到坐标就该收起箭头，下一帧再问一次（目标可能是稍后才出现的东西）
static func resolve(main_game: MainGameManager,
		target: E_PointerTarget,
		plant_type: CharacterRegistry.PlantType,
		advice_ui: TutorialAdviceUI) -> Variant:
	if target == E_PointerTarget.None or not is_instance_valid(main_game):
		return null
	match target:
		E_PointerTarget.Card:
			var card := get_battle_card(main_game, plant_type)
			if card == null:
				return null
			return get_card_pointer_position(card, advice_ui)
		E_PointerTarget.Lawn:
			var plant_cell := get_lawn_center_plant_cell(main_game, plant_type)
			if plant_cell == null:
				return null
			return get_canvas_center(plant_cell)
		E_PointerTarget.Sun:
			var sun := get_first_sun(main_game)
			if sun == null:
				return null
			return sun.get_global_transform_with_canvas().origin
		E_PointerTarget.Shovel:
			var ui_shovel := get_ui_shovel(main_game)
			if ui_shovel == null:
				return null
			return get_canvas_center(ui_shovel)
		E_PointerTarget.Plant:
			var plant_cell := get_first_plant_cell_with_plant(main_game)
			if plant_cell == null:
				return null
			return get_canvas_center(plant_cell)
	return null


## 当前可点的卡里指定植物的那张（plant_type 为 Null 时取第一张）
## 传送带关（1-5 / x-10）没有出战卡槽，卡片在传送带上，所以统一走 get_curr_card_list()
static func get_battle_card(main_game: MainGameManager,
		plant_type: CharacterRegistry.PlantType) -> Card:
	for card: Card in get_curr_card_list(main_game):
		if plant_type == CharacterRegistry.PlantType.Null or card.card_plant_type == plant_type:
			return card
	return null


## 当前卡槽里的卡片：普通关取出战卡槽，传送带关取传送带上的卡片
static func get_curr_card_list(main_game: MainGameManager) -> Array:
	if main_game.card_manager == null:
		return []
	if main_game.card_manager.card_slot_battle != null:
		return main_game.card_manager.card_slot_battle.curr_cards
	if main_game.card_manager.card_slot_conveyor_belt != null:
		return main_game.card_manager.card_slot_conveyor_belt.curr_cards
	return []


## 草坪上「最适合种下当前卡片」的植物格子：从草坪中心向外找第一个能种下的格子
## 1-5 保龄球关红线右边一律不可种植，靠 can_plant_in_cell() 过滤掉红线外的格子
static func get_lawn_center_plant_cell(main_game: MainGameManager,
		plant_type: CharacterRegistry.PlantType) -> PlantCell:
	if main_game.plant_cell_manager == null:
		return null
	var cell_rows: Array[Array] = main_game.plant_cell_manager.all_plant_cells
	if cell_rows.is_empty():
		return null
	var want_type := plant_type
	if want_type == CharacterRegistry.PlantType.Null:
		want_type = get_pointer_plant_type(main_game, plant_type)
	for row_index: int in center_out_order(cell_rows.size()):
		var cells: Array = cell_rows[row_index]
		for col_index: int in center_out_order(cells.size()):
			var plant_cell := cells[col_index] as PlantCell
			if plant_cell == null:
				continue
			if want_type == CharacterRegistry.PlantType.Null:
				return plant_cell
			if can_plant_in_cell(plant_cell, want_type):
				return plant_cell
	return null


## 当前指向的植物类型：优先取调用方给的，其次取卡槽第一张卡
static func get_pointer_plant_type(main_game: MainGameManager,
		plant_type: CharacterRegistry.PlantType) -> CharacterRegistry.PlantType:
	if plant_type != CharacterRegistry.PlantType.Null:
		return plant_type
	var card := get_battle_card(main_game, CharacterRegistry.PlantType.Null)
	if card != null:
		return card.card_plant_type
	return CharacterRegistry.PlantType.Null


static func can_plant_in_cell(plant_cell: PlantCell, plant_type: CharacterRegistry.PlantType) -> bool:
	var plant_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	if plant_condition == null:
		return false
	return plant_condition.judge_is_can_plant(plant_cell, plant_type)


## 从中间向两端扩散的下标顺序：8 -> [4, 5, 3, 6, 2, ...]
static func center_out_order(size: int) -> Array[int]:
	var order: Array[int] = []
	if size <= 0:
		return order
	@warning_ignore("integer_division")
	var mid := size / 2
	order.append(mid)
	for step in range(1, size):
		if mid + step < size:
			order.append(mid + step)
		if mid - step >= 0:
			order.append(mid - step)
	return order


## 场上第一颗还没被收集的阳光
static func get_first_sun(main_game: MainGameManager) -> Sun:
	if main_game.suns == null:
		return null
	for child in main_game.suns.get_children():
		var sun := child as Sun
		if sun != null and not sun.collected:
			return sun
	return null


## 卡槽里的铲子（铲子教学要指它）
static func get_ui_shovel(main_game: MainGameManager) -> UIShovel:
	if main_game.card_slot_root == null:
		return null
	return main_game.card_slot_root.ui_shovel


## 草坪上第一株还活着的植物所在格子（铲子教学要指它）
static func get_first_plant_cell_with_plant(main_game: MainGameManager) -> PlantCell:
	if main_game.plant_cell_manager == null:
		return null
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell != null and plant_cell.get_curr_plant_num() > 0:
				return plant_cell
	return null


## 控件在屏幕（画布）上的中心点
static func get_canvas_center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)


## 指向卡片的落点：从卡片中心朝提示条方向挪出卡片外沿
## （箭尖落在卡面中心会压住卡图，原版的提示箭头也是指着卡片外侧）
static func get_card_pointer_position(card: Control, advice_ui: TutorialAdviceUI) -> Vector2:
	var card_center := get_canvas_center(card)
	if advice_ui == null:
		return card_center
	var to_box := advice_ui.get_advice_box_center() - card_center
	if to_box == Vector2.ZERO:
		return card_center
	return card_center + to_box.normalized() * (maxf(card.size.x, card.size.y) * 0.5 + 8.0)
