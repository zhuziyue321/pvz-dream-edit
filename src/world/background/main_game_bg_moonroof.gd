extends Sprite2D
## 月夜屋顶（Moon）背景：血月期间把底图 / 房门遮罩换成 DLC 的「血月」那套。
##
## DLC 原版这两套图是分开的（id 见 `_unpacked/properties/resources.xml`）：
## |        | 底图                                  | 房门遮罩                                        |
## | ------ | ------------------------------------- | ----------------------------------------------- |
## | 常驻   | `BACKGROUND6BOSS` = background6boss   | `BACKGROUND6_GAMEOVER_MASK`                     |
## | 血月   | `BACKGROUND_BLOODMOON` = background6  | `BACKGROUND_BLOODMOON_GAMEOVER_MASK`            |
##
## 移植时曾把血月那张（`background6.png`，紫红夜空）直接当成常驻底图 —— 结果玩家一进关
## 就是满屏紫红，视觉上像是血月已经开了，其实血月要等旗帜波才起。现在平时是月夜，
## 血月事件起落时才换图，血月这才真的「有来有去」。

var TEX_BG_NIGHT: Texture2D = AssetRegistry.get_texture("res://pak/images/background6boss.jpg")
var TEX_BG_BLOOD: Texture2D = AssetRegistry.get_texture("res://pak/images/background6moon.png")
var TEX_MASK_NIGHT: Texture2D = AssetRegistry.get_texture("res://pak/images/background6_gameover_mask.png")
var TEX_MASK_BLOOD: Texture2D = AssetRegistry.get_texture("res://pak/images/background6moon_gameover_mask.png")

## 房门遮罩是 Home 的子节点，取不到就只换底图（Moon 章不带遮罩时也不该炸）
@onready var _mask: Sprite2D = get_node_or_null(
	"Home/Door/DoorMask/Background6MoonGameoverMask") as Sprite2D


func _ready() -> void:
	## 进关一律先落回月夜态：上一局在血月里退了，也不该让下一局开局就是红的
	_set_blood_moon_visual(false)
	EventBus.subscribe(ConstEventName.BLOOD_MOON_VISUAL, _set_blood_moon_visual)


## 血月事件起 / 落的视觉切换（由 BloodMoonManager 推 BLOOD_MOON_VISUAL）
func _set_blood_moon_visual(is_active: bool) -> void:
	texture = TEX_BG_BLOOD if is_active else TEX_BG_NIGHT
	if _mask != null:
		_mask.texture = TEX_MASK_BLOOD if is_active else TEX_MASK_NIGHT
