extends TextureRect
class_name UIGlove
## 卡槽里的手套（「手套」模组专属界面，由 `GloveMod` 运行时插进卡槽，本体场景里没有这个节点）
## 本体是卡槽背景（与铲子同款底板），$Glove 才是可以被「拿走」的手套图标。
## 显隐规则统一由 HandComponentGlove 决定，本节点只负责按规则刷新，不自己改状态。

## 点击手套：由 `GloveMod` 接到手持物组件上
## ★ 不走 EventBus：事件名常量表（`ConstEventName`）属于本体，模组不该往里塞自己的事件名
signal glove_clicked

@onready var glove_icon: TextureRect = $Glove
## 冷却遮罩（与卡片那块同款：盖住 = 还不能点，随剩余时间往回收）
@onready var cool_mask: ProgressBar = $CoolMask


## 鼠标点击手套：交给手持物组件处理（拿到手上）
func _on_button_pressed() -> void:
	glove_clicked.emit()


## 快捷键 G：与铲子的 F 同一套路 —— 本体不认识手套，所以由模组自己收
## （原版没有这个键位，它跟着手套模组一起存在）
func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ShortcutKeys_Glove") and visible:
		_on_button_pressed()


## 刷新增手套界面
## is_slot_visible：整个手套卡槽（背景 + 按钮）是否显示
## is_icon_visible：手套图标是否显示（手套被拿到手上时只留背景）
func refresh_glove_ui(is_slot_visible: bool, is_icon_visible: bool) -> void:
	visible = is_slot_visible
	glove_icon.visible = is_icon_visible


## 刷冷却遮罩（与显隐分开：显隐由 `HandComponentGlove.refresh_ui()` 决定，
## 遮罩剩多少由它的 `_refresh_cool_ui()` 每帧推）
## cool_ratio：还剩几分之几（0 = 没在冷却 → 收起遮罩）
func refresh_glove_cool(cool_ratio: float) -> void:
	cool_mask.visible = cool_ratio > 0.0
	if cool_mask.visible:
		cool_mask.ratio = clampf(cool_ratio, 0.0, 1.0)
