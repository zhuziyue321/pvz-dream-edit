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
	E_LawnMoverType.LawnMover : preload("res://src/items/lawn_mower/lawn_mower.tscn"),
	E_LawnMoverType.PoolCleaner : preload("res://src/items/lawn_mower/pool_cleaner.tscn"),
	E_LawnMoverType.RoofCleaner : preload("res://src/items/lawn_mower/roof_cleaner.tscn")
}

@onready var lawn_movers: Node2D = %LawnMovers
## 小推车生成的全局x位置
@export var GlobalXLawnMover:float = 20
## 入场出生点：站位再往左这么多像素（保证整辆推车都在屏幕左边缘之外，看不见）
@export var appear_offscreen_offset:float = 200.0
## 单辆推车从出生点开到站位用的秒数
@export var appear_duration:float = 0.2
## 相邻两辆推车**发车**的间隔秒数（不是「前一辆到位」：路上可以同时有几辆在开）
@export var appear_interval:float = 0.05
var all_lawn_movers_type:Array = []
var all_lawn_movers_global_pos:Array[Vector2] = []
var all_lawn_movers:Array[LawnMover] = []
## 每行是否配备小推车（来自地图数据 row_data.have_lawn_mover，原版没铺草皮的行没有）
var all_lane_have_lawn_mover:Array[bool] = []
## 每行的小推车类型是否已在商店购买（水路/屋顶清洁车要买过后才配发）
var all_lane_mover_bought:Array[bool] = []
## 出生在屏幕外、等着被送入场的推车（由「初始化小推车」事件统一播入场）
var pending_appear_lawn_movers:Array[LawnMover] = []
## 本关是否已经初始化过推车（多轮关卡每轮都重跑一遍流程，第 2 轮起只补车、不再重建）
var is_lawn_movers_inited:bool = false


func _ready() -> void:
	## 补充小推车
	EventBus.subscribe("replenish_lawn_mover", replenish_lawn_mover)

## 初始化小推车（首次布场 / 从存档恢复）
##
## 推车出生在屏幕外左侧，入场动画不由这里播 ——
## 由关卡流程的「初始化小推车」事件（排在「准备…安放…植物」之前）调 play_appear_animation()
func init_lawn_movers() -> void:
	if game_item_manager.game_para.save_game_data_main_game != null :
		var lawn_mover_data: Dictionary = game_item_manager.game_para.save_game_data_main_game.lawn_mover_manager_data
		create_all_lawn_movers(lawn_mover_data.get("is_has_all_lawn_mover", []), true)
	else:
		create_all_lawn_movers([], true)
	is_lawn_movers_inited = true

## 「初始化小推车」流程事件走这里：第一次把关上的推车全部布出来，之后再跑到就只补缺的车
func init_or_replenish_lawn_movers() -> void:
	if is_lawn_movers_inited:
		_replenish_lawn_movers(true)
	else:
		init_lawn_movers()

## 指定行当前是否允许配备小推车:地图给了 + (水路/屋顶清洁车需在商店买过)
func is_lane_can_have_mover(lane: int) -> bool:
	if lane < 0 or lane >= all_lane_have_lawn_mover.size():
		return false
	if not all_lane_have_lawn_mover[lane]:
		return false
	if lane >= all_lane_mover_bought.size():
		return false
	return all_lane_mover_bought[lane]


## 生成所有的小推车
## 每行的小推车类型来自地图数据（不再按场景查表）
## is_defer_appear: true = 出生在屏幕外左侧，等 play_appear_animation() 按从下到上把它们送到位
func create_all_lawn_movers(is_has_all_lawn_mover:Array=[], is_defer_appear:bool=false):
	var map_data: ResourceMapData = game_item_manager.game_para.map_data
	if map_data == null or not map_data.is_valid():
		Log.error("缺少地图数据，无法创建小推车")
		return

	all_lawn_movers_type.clear()
	all_lawn_movers_global_pos.clear()
	all_lawn_movers.clear()
	all_lane_have_lawn_mover.clear()
	all_lane_mover_bought.clear()
	pending_appear_lawn_movers.clear()
	for lane in range(map_data.get_row_num()):
		var row_data: ResourceMapRowData = map_data.rows[lane]
		var mover_type:E_LawnMoverType = clampi(row_data.lawn_mover_type, 0, E_LawnMoverType.size() - 1) as E_LawnMoverType
		all_lawn_movers_type.append(mover_type)
		all_lane_have_lawn_mover.append(row_data.have_lawn_mover)
		all_lane_mover_bought.append(Global.global_game_state.is_lawn_mover_bought(mover_type))

	Log.debug(str("创建小推车, 小推车类型") + str(all_lawn_movers_type) + str(" 各行是否有小推车") + str(all_lane_have_lawn_mover))
	assert(game_item_manager.main_game.zombie_manager.all_zombie_rows.size() == all_lawn_movers_type.size(), "小推车数量与僵尸行数量不一致")
	for lane in range(all_lawn_movers_type.size()):
		var zombie_row:ZombieRow = game_item_manager.main_game.zombie_manager.all_zombie_rows[lane]
		var global_pos_lawn_mover:Vector2 = Vector2(GlobalXLawnMover, zombie_row.zombie_create_position.global_position.y)
		all_lawn_movers_global_pos.append(global_pos_lawn_mover)
		var new_lawn_mover:LawnMover
		## 该行没有小推车（原版没铺草皮的行 / 水路·屋顶清洁车还没在商店买）：存档里就算写了 true 也不生成
		if not is_lane_can_have_mover(lane):
			new_lawn_mover = null
		elif is_has_all_lawn_mover.is_empty() or (is_has_all_lawn_mover.size() > lane and is_has_all_lawn_mover[lane]):
			new_lawn_mover = create_lawn_mover(lane, all_lawn_movers_type[lane], all_lawn_movers_global_pos[lane], is_defer_appear)
		else:
			new_lawn_mover = null
		all_lawn_movers.append(new_lawn_mover)

## 补充小推车（EventBus 回调）
func replenish_lawn_mover():
	_replenish_lawn_movers(false)

## 补充小推车
## is_defer_appear: true = 补出来的车也等入场事件一起送到（多轮关卡的第 2 轮起）
func _replenish_lawn_movers(is_defer_appear:bool):
	if all_lawn_movers.is_empty():
		create_all_lawn_movers([], is_defer_appear)
	else:
		for i in range(all_lawn_movers.size()):
			## 该行本来就没有小推车（没铺草皮的行 / 水路·屋顶清洁车还没在商店买），不要补
			if not is_lane_can_have_mover(i):
				continue

			if is_instance_valid(all_lawn_movers[i]) and not all_lawn_movers[i].is_moving:
				continue
			else:
				var new_lawn_mover = create_lawn_mover(i, all_lawn_movers_type[i], all_lawn_movers_global_pos[i], is_defer_appear)
				all_lawn_movers[i] = new_lawn_mover

## 生成一个小推车
## is_defer_appear: true = 出生在屏幕外左侧（登记到 pending_appear_lawn_movers），
## 不自己播入场动画；false = 照旧自己从左侧滑到位
func create_lawn_mover(lane:int, lawn_mover_type:E_LawnMoverType, global_pos:Vector2, is_defer_appear:bool=false)->LawnMover:
	var new_lawn_mover:LawnMover = LawnMoverSecneMap[lawn_mover_type].instantiate()
	new_lawn_mover.lane = lane
	new_lawn_mover.z_index = lane * 50 + 40
	## 由于在ready中会检测屋顶，使用全局位置，因此在add_child之前修改其局部位置
	new_lawn_mover.position = global_pos - lawn_movers.global_position
	lawn_movers.add_child(new_lawn_mover)
	## 屋顶清洁车在 _ready 里按站位算了斜面修正，add_child 之后再往左挪，y 不会跟着变
	if is_defer_appear:
		new_lawn_mover.position.x -= appear_offscreen_offset
		pending_appear_lawn_movers.append(new_lawn_mover)
	else:
		lawn_mover_appear(new_lawn_mover)
	return new_lawn_mover

## 入场：把出生在屏幕外左侧的推车按**从下到上**的顺序依次发车开到站位
## **不阻塞关卡流程** —— 流程只要「让车进场」，车自己开进来，后面的步骤照常往下走
func play_appear_animation() -> void:
	var pending:Array[LawnMover] = []
	for lawn_mower in pending_appear_lawn_movers:
		pending.append(lawn_mower)
	pending_appear_lawn_movers.clear()
	## lane 越大越靠下：排完序从下标 0 开始就是最下面那行
	pending.sort_custom(func(a:LawnMover, b:LawnMover): return a.lane > b.lane)
	var running:Array = []
	var is_first := true
	for lawn_mower in pending:
		if not is_inside_tree():
			return
		if not is_instance_valid(lawn_mower):
			continue
		## 只错开一小会儿就发下一辆，不等它到位 —— 五辆车整体上只比一辆多一点点
		if not is_first:
			await get_tree().create_timer(appear_interval).timeout
			if not is_inside_tree():
				return
		is_first = false
		running.append(_appear_tween(lawn_mower))
	for tween in running:
		if tween != null and is_instance_valid(tween):
			await tween.finished

## 一辆推车从出生点开到站位：返回它自己的补间，要不要等由调用方决定
func _appear_tween(lawn_mower:LawnMover) -> Tween:
	if not is_instance_valid(lawn_mower):
		return null
	var tween:Tween = create_tween()
	tween.tween_property(lawn_mower, "position:x", _stand_position_x(lawn_mower), appear_duration)
	return tween

## 推车站位的局部 x —— 车出生时被挪到了屏幕外，所以目标不是它当前的 x，而是地图给的那个站位
func _stand_position_x(lawn_mover:LawnMover) -> float:
	if lawn_mover.lane >= 0 and lawn_mover.lane < all_lawn_movers_global_pos.size():
		return all_lawn_movers_global_pos[lawn_mover.lane].x - lawn_movers.global_position.x
	return lawn_mover.position.x + appear_offscreen_offset

## 小推车出现动画（单辆：从左到右滑一小段）
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
