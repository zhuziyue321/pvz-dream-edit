extends Node2D
class_name MainGameHome

@onready var area_2d_home: Area2D = $Area2DHome

## 房门内景叠加图与房门遮罩：下标与 ConstLevelData.GameBg 一一对应，
## 新增背景（GameBg 加成员）必须同步扩这两个数组，否则 init_home 取越界。
## 屋顶 / 夜屋顶进门就是室内，没有内景叠加图，记 null；遮罩每份背景子场景只带自己那张，
## 所以非本背景的下标用 get_node_or_null 取，取到 null 时 init_home 会跳过。
## ⚠️ 前四项也必须走 get_node_or_null：每份背景子场景只挂**自己会被用到**的那几张图，
## 用 `$` 硬路径时，挂在别的背景场景下（比如郊外营地只带自己的露营车遮罩）会刷
## "Node not found: Door/DoorDown/Background1GameoverInteriorOverlay"。
## 取不到就当 null，init_home 会跳过。
@onready var door_downs: Array[Sprite2D] = [
	get_node_or_null("Door/DoorDown/Background1GameoverInteriorOverlay") as Sprite2D,
	get_node_or_null("Door/DoorDown/Background2GameoverInteriorOverlay") as Sprite2D,
	get_node_or_null("Door/DoorDown/Background3GameoverInteriorOverlay") as Sprite2D,
	get_node_or_null("Door/DoorDown/Background4GameoverInteriorOverlay") as Sprite2D,
	null, ## Roof：没有内景叠加图
	null, ## Boss（夜屋顶）：没有内景叠加图
	null, ## MoonRoof（月夜屋顶）：没有内景叠加图
	null, ## Woods（郊外营地）：营地里没有房门，没有内景叠加图
]

@onready var door_masks: Array[Sprite2D] = [
	get_node_or_null("Door/DoorMask/Background1GameoverMask") as Sprite2D,
	get_node_or_null("Door/DoorMask/Background2GameoverMask") as Sprite2D,
	get_node_or_null("Door/DoorMask/Background3GameoverMask") as Sprite2D,
	get_node_or_null("Door/DoorMask/Background4GameoverMask") as Sprite2D,
	get_node_or_null("Door/DoorMask/Background5GameoverMask") as Sprite2D,
	get_node_or_null("Door/DoorMask/Background6GameoverMask") as Sprite2D, ## 只有夜屋顶背景带它
	get_node_or_null("Door/DoorMask/Background6MoonGameoverMask") as Sprite2D, ## 只有月夜屋顶背景带它
	get_node_or_null("Door/DoorMask/Background7WoodsGameoverMask") as Sprite2D, ## 只有郊外营地背景带它
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
	Log.info("僵尸进家")
	var zombie :Zombie000Base = area.owner
	EventBus.push_event(ConstEventName.ZOMBIE_GO_HOME, [zombie])

## 僵尸无法进房，禁用房子
func disable_home():
	area_2d_home.monitoring = false
