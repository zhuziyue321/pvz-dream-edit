extends Node2D
class_name MainGameHome

@onready var area_2d_home: Area2D = $Area2DHome

## 房门内景叠加图与房门遮罩：下标与 ConstLevelData.GameBg 一一对应，
## 新增背景（GameBg 加成员）必须同步扩这两个数组，否则 init_home 取越界。
## 屋顶 / 夜屋顶进门就是室内，没有内景叠加图，记 null；遮罩每份背景子场景只带自己那张，
## 所以非本背景的下标用 get_node_or_null 取，取到 null 时 init_home 会跳过。
@onready var door_downs: Array[Sprite2D] = [
	$Door/DoorDown/Background1GameoverInteriorOverlay,
	$Door/DoorDown/Background2GameoverInteriorOverlay,
	$Door/DoorDown/Background3GameoverInteriorOverlay,
	$Door/DoorDown/Background4GameoverInteriorOverlay,
	null, ## Roof：没有内景叠加图
	null, ## Boss（夜屋顶）：没有内景叠加图
]

@onready var door_masks: Array[Sprite2D] = [
	$Door/DoorMask/Background1GameoverMask,
	$Door/DoorMask/Background2GameoverMask,
	$Door/DoorMask/Background3GameoverMask,
	$Door/DoorMask/Background4GameoverMask,
	$Door/DoorMask/Background5GameoverMask,
	get_node_or_null("Door/DoorMask/Background6GameoverMask") as Sprite2D, ## 只有夜屋顶背景带它
]

## 根据当前背景初始化房门
func init_home(game_BG: ConstLevelData.GameBg):
	if game_BG < 0 or game_BG >= door_masks.size():
		Log.error("背景 %d 没有对应的房门数据（door_masks 未同步扩数组）" % game_BG)
		return
	if is_instance_valid(door_downs[game_BG]):
		## 打开房门
		door_downs[game_BG].visible = true
	if is_instance_valid(door_masks[game_BG]):
		door_masks[game_BG].visible = true

## 僵尸进房
func _on_area_2d_home_area_entered(area: Area2D) -> void:
	Log.debug("僵尸进家")
	var zombie :Zombie000Base = area.owner
	EventBus.push_event("zombie_go_home", [zombie])

## 僵尸无法进房，禁用房子
func disable_home():
	area_2d_home.monitoring = false
