extends TextureButton
class_name CustomLevelEntryButton
## 主菜单上的「自制关卡」入口按钮 —— **属于自制关卡模组，本体场景里没有它**
##
## 由 `CustomLevelMod` 在每次进主菜单时现场挂上去（见 `custom_level_mod.gd`）。
## 外观沿用本体主菜单的 Present 图标，悬停换图：与本体其它模式按钮同款做法
## （`default` / `mouse` 两张贴图切显隐，`texture_normal` 置空）。

@onready var mouse: TextureRect = $mouse
@onready var default: TextureRect = $default


func _ready() -> void:
	texture_normal = null
	_on_mouse_exited()


func _on_mouse_entered() -> void:
	mouse.visible = true
	default.visible = false


func _on_mouse_exited() -> void:
	mouse.visible = false
	default.visible = true
