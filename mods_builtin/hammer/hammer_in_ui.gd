extends TextureRect
## 卡槽里的锤子（「锤子」模组专属界面，由 `HeadHammerMod` 运行时插进卡槽，本体场景里没有这个节点）
## 本体是卡槽背景（与铲子同款底板），$Icon 才是可以被「拿走」的锤子图标（锤头 + 锤柄两块贴图拼的）。
## 显隐规则统一由 HandComponentHammerMod 决定，本节点只负责按规则刷新，不自己改状态。

## 点击锤子：由 `HeadHammerMod` 接到手持物组件上
## ★ 不走 EventBus：事件名常量表（`ConstEventName`）属于本体，模组不该往里塞自己的事件名
signal hammer_clicked

@onready var hammer_icon: Control = $Icon
## 冷却遮罩（与卡片那块同款：盖住 = 还不能点，随剩余时间往回收）
@onready var cool_mask: ProgressBar = $CoolMask


## 鼠标点击锤子：交给手持物组件处理（拿到手上）
func _on_button_pressed() -> void:
	hammer_clicked.emit()


## 快捷键 H：与铲子的 F / 手套的 G 同一套路 —— 本体不认识模组锤子，所以由模组自己收
## （原版没有这个键位，它跟着锤子模组一起存在）
func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ShortcutKeys_Hammer") and visible:
		_on_button_pressed()


## 刷新锤子界面
## is_slot_visible：整个锤子卡槽（背景 + 按钮）是否显示
## is_icon_visible：锤子图标是否显示（锤子被拿到手上时只留背景）
func refresh_hammer_ui(is_slot_visible: bool, is_icon_visible: bool) -> void:
	visible = is_slot_visible
	hammer_icon.visible = is_icon_visible


## 刷冷却遮罩（与显隐分开：显隐由 `HandComponentHammerMod.refresh_ui()` 决定，
## 遮罩剩多少由它的 `_refresh_cool_ui()` 每帧推）
## cool_ratio：还剩几分之几（0 = 没在冷却 → 收起遮罩）
func refresh_hammer_cool(cool_ratio: float) -> void:
	cool_mask.visible = cool_ratio > 0.0
	if cool_mask.visible:
		cool_mask.ratio = clampf(cool_ratio, 0.0, 1.0)
