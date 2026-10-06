extends RefCounted
class_name LevelWaitCondition
## 「等玩家做点什么」的判据：关卡流程里 wait_* 那一组事件共用的**查询**
##
## 判定逻辑放在这里而不是散在各个事件脚本里，是为了让「种下几株怎么数」「手上拿的是不是这张卡」
## 这类口径只有一份（改了不用挨个事件改）。事件脚本只管「等多久 / 超时了怎么办」。
##
## 全部是静态查询：**不持有状态、不订阅信号**，一问一答 ——
## 计数类判据（种了几株 / 铲了几株）由事件自己先记一个基准数再问差值。


## 草坪上现在的植物数量；plant_type 给 Null = 数所有植物
static func count_lawn_plants(main_game: MainGameManager,
		plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> int:
	if not _is_valid(main_game) or main_game.plant_cell_manager == null:
		return 0
	var num := 0
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell == null:
				continue
			if plant_type == CharacterRegistry.PlantType.Null:
				num += plant_cell.get_curr_plant_num()
				continue
			for place in plant_cell.plant_in_cell:
				var plant = plant_cell.get_plant(place)
				if is_instance_valid(plant) and plant.plant_type == plant_type:
					num += 1
	return num


## 手上是不是拿着一张卡；plant_type 给 Null = 拿着任意卡都算
static func is_holding_card(main_game: MainGameManager,
		plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> bool:
	if not _is_valid(main_game) or main_game.hand_manager == null:
		return false
	var hand_manager := main_game.hand_manager
	if not hand_manager.is_holding_hand():
		return false
	if plant_type == CharacterRegistry.PlantType.Null:
		return true
	var hand := hand_manager.curr_hand_component as HandComponentCharacter
	if hand == null:
		return false
	return is_instance_valid(hand.curr_card) and hand.curr_card.card_plant_type == plant_type


## 手上是不是拿着铲子（铲子没有「拿起」事件，只能按帧问手持物类型）
static func is_holding_shovel(main_game: MainGameManager) -> bool:
	if not _is_valid(main_game) or main_game.hand_manager == null:
		return false
	return main_game.hand_manager.get_curr_hand_type() \
		== HandComponentBase.E_HandComponentType.Shovel


## 玩家现在的阳光数（传送带关没有出战卡槽，返回 0）
static func get_sun_value(main_game: MainGameManager) -> int:
	if not _is_valid(main_game) or main_game.card_manager == null:
		return 0
	var card_slot_battle: CardSlotBattle = main_game.card_manager.card_slot_battle
	if card_slot_battle == null:
		return 0
	return card_slot_battle.sun_value


static func _is_valid(main_game: MainGameManager) -> bool:
	return main_game != null and is_instance_valid(main_game)
