extends Node
class_name GIM_LawnMover

@onready var game_item_manager: GameItemManager = %GameItemManager

## 小推车类型
enum E_LawnMoverType{
	LawnMover,
	PoolCleaner,
	RoofCleaner,
}

## 小推车场景
const LawnMoverSecneMap = {
	E_LawnMoverType.LawnMover : preload("res://scenes/item/game_scenes_item/lawn_mover/lawn_mower.tscn"),
	E_LawnMoverType.PoolCleaner : preload("res://scenes/item/game_scenes_item/lawn_mover/pool_cleaner.tscn"),
	E_LawnMoverType.RoofCleaner : preload("res://scenes/item/game_scenes_item/lawn_mover/roof_cleaner.tscn")
}

@onready var lawn_movers: Node2D = %LawnMovers
## 小推车生成的全局x位置
@export var GlobalXLawnMover:float = 20
var all_lawn_movers_type:Array = []
var all_lawn_movers_global_pos:Array[Vector2] = []
var all_lawn_movers:Array[LawnMover] = []


func _ready() -> void:
	## 补充小推车
	EventBus.subscribe("replenish_lawn_mover", replenish_lawn_mover)

## 初始化小推车
func init_lawn_movers() -> void:
	if game_item_manager.game_para.save_game_data_main_game != null :
		var lawn_mover_data: Dictionary = game_item_manager.game_para.save_game_data_main_game.lawn_mover_manager_data
		create_all_lawn_movers(lawn_mover_data.get("is_has_all_lawn_mover", []))
	else:
		create_all_lawn_movers()

## 生成所有的小推车
## 每行的小推车类型来自地图数据（不再按场景查表）
func create_all_lawn_movers(is_has_all_lawn_mover:Array=[]):
	var map_data: ResourceMapData = game_item_manager.game_para.map_data
	if map_data == null or not map_data.is_valid():
		Log.error("缺少地图数据，无法创建小推车")
		return

	all_lawn_movers_type.clear()
	all_lawn_movers_global_pos.clear()
	all_lawn_movers.clear()
	for lane in range(map_data.get_row_num()):
		var row_data: ResourceMapRowData = map_data.rows[lane]
		all_lawn_movers_type.append(clampi(row_data.lawn_mover_type, 0, E_LawnMoverType.size() - 1))

	Log.debug(str("创建小推车, 小推车类型") + str(all_lawn_movers_type))
	assert(game_item_manager.main_game.zombie_manager.all_zombie_rows.size() == all_lawn_movers_type.size(), "小推车数量与僵尸行数量不一致")
	for lane in range(all_lawn_movers_type.size()):
		var zombie_row:ZombieRow = game_item_manager.main_game.zombie_manager.all_zombie_rows[lane]
		var global_pos_lawn_mover:Vector2 = Vector2(GlobalXLawnMover, zombie_row.zombie_create_position.global_position.y)
		all_lawn_movers_global_pos.append(global_pos_lawn_mover)
		var new_lawn_mover:LawnMover
		if is_has_all_lawn_mover.is_empty() or (is_has_all_lawn_mover.size() > lane and is_has_all_lawn_mover[lane]):
			new_lawn_mover = create_lawn_mover(lane, all_lawn_movers_type[lane], all_lawn_movers_global_pos[lane])
		else:
			new_lawn_mover = null
		all_lawn_movers.append(new_lawn_mover)

## 补充小推车
func replenish_lawn_mover():
	if all_lawn_movers.is_empty():
		create_all_lawn_movers()
	else:
		for i in range(all_lawn_movers.size()):
			if is_instance_valid(all_lawn_movers[i]) and not all_lawn_movers[i].is_moving:
				continue
			else:
				var new_lawn_mover = create_lawn_mover(i, all_lawn_movers_type[i], all_lawn_movers_global_pos[i])
				all_lawn_movers[i] = new_lawn_mover

## 生成一个小推车
func create_lawn_mover(lane:int, lawn_mover_type:E_LawnMoverType, global_pos:Vector2)->LawnMover:
	var new_lawn_mover:LawnMover = LawnMoverSecneMap[lawn_mover_type].instantiate()
	new_lawn_mover.lane = lane
	new_lawn_mover.z_index = lane * 50 + 40
	## 由于在ready中会检测屋顶，使用全局位置，因此在add_child之前修改其局部位置
	new_lawn_mover.position = global_pos - lawn_movers.global_position
	lawn_movers.add_child(new_lawn_mover)
	lawn_mover_appear(new_lawn_mover)
	return new_lawn_mover

## 小推车出现动画
func lawn_mover_appear(lawn_mover:Node2D):
	var pos_x = lawn_mover.position.x
	lawn_mover.position.x -= 100
	var tween:Tween = create_tween()
	tween.tween_property(lawn_mover, "position:x", pos_x, 0.5)

func get_save_game_data_lawn_mover_manager()->Dictionary:
	var save_game_data_lawn_mover:Dictionary = {}
	var is_has_all_lawn_mover:Array[bool] = []
	for i in range(all_lawn_movers.size()):
		if is_instance_valid(all_lawn_movers[i]) and not all_lawn_movers[i].is_moving:
			is_has_all_lawn_mover.append(true)
		else:
			is_has_all_lawn_mover.append(false)
	save_game_data_lawn_mover["is_has_all_lawn_mover"] = is_has_all_lawn_mover
	return save_game_data_lawn_mover

