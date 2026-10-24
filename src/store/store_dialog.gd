extends Control
class_name StoreDialog
## 商店的通用弹窗（原版 LawnDialog 的两个用途）：
##   · 单按钮消息：金币不足（NOT_ENOUGH_MONEY / CANNOT_AFFORD_ITEM）、更多卡片槽（MORE_SLOTS）
##   · 是 / 否确认：拜访智慧树？（VISIT_TREE_HEADER / VISIT_TREE_BODY）
##
## 为什么在代码里搭 UI：商店只有这一个弹窗，节点少（遮罩 + 面板 + 两行文字 + 两个按钮），
## 手写 .tscn 反而更容易踩「注释 / 缩进」那类静默丢节点的坑（见 M-05）。
## 外观沿用 ConfirmGoods 那套：PanelDialogBG 面板 + PanelButtonBG 按钮。

signal confirmed
signal cancelled

const PVZ_THEME := preload("res://data/ui/themes/pvz_theme.tres")
const PANEL_SIZE := Vector2(380, 220)
const BUTTON_SIZE := Vector2(110, 40)

var title_label: Label
var body_label: Label
var ok_button: BaseButton
var cancel_button: BaseButton


func _ready() -> void:
	theme = PVZ_THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 2000
	visible = false
	_build_ui()


func _build_ui() -> void:
	## 遮罩：挡住后面货架的点击（原版对话框是模态的）
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.35)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var panel := Panel.new()
	panel.theme_type_variation = &"PanelDialogBG"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x / 2.0
	panel.offset_top = -PANEL_SIZE.y / 2.0
	panel.offset_right = PANEL_SIZE.x / 2.0
	panel.offset_bottom = PANEL_SIZE.y / 2.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(hbox)

	ok_button = _create_button("确定")
	ok_button.pressed.connect(_on_ok_pressed)
	hbox.add_child(ok_button)
	cancel_button = _create_button("取消")
	cancel_button.pressed.connect(_on_cancel_pressed)
	hbox.add_child(cancel_button)


## 一个 PVZ 风格的按钮：底板用 PanelButtonBG，文字叠在上面
func _create_button(text: String) -> BaseButton:
	var button := BaseButton.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var panel := Panel.new()
	panel.theme_type_variation = &"PanelButtonBG"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(panel)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(label)
	return button


## 单按钮消息（只有「确定」）
func appear_message(title: String, body: String, ok_text: String = "确定") -> void:
	cancel_button.visible = false
	_set_button_text(ok_button, ok_text)
	_show(title, body)


## 是 / 否确认
func appear_confirm(title: String, body: String,
		yes_text: String = "是", no_text: String = "否") -> void:
	cancel_button.visible = true
	_set_button_text(ok_button, yes_text)
	_set_button_text(cancel_button, no_text)
	_show(title, body)


func is_open() -> bool:
	return visible


func hide_dialog() -> void:
	visible = false


func _show(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	visible = true


func _set_button_text(button: BaseButton, text: String) -> void:
	for child in button.get_children():
		if child is Label:
			(child as Label).text = text
			return


func _on_ok_pressed() -> void:
	hide_dialog()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	hide_dialog()
	cancelled.emit()
