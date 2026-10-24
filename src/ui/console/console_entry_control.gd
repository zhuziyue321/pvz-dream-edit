extends RefCounted
class_name ConsoleEntryControl
## 把一条 `ConsoleEntry` 变成控件：控制台面板与模组页面共用这一段
##
## 为什么要抽出来：控制台先有了「条目 → 控件」的渲染（`CanvasLayerConsole`），
## 之后模组页面也要显示模组自己的设置（联机的目标地址 / 开启房间 / 状态…）——
## 没必要抄第二遍，两边共用同一个渲染器；将来条目多一种形态也只改这一处。
##
## 用法（面板 / 页面各自持有一个实例，销毁控件时记得 `clear()`）：
##   var builder := ConsoleEntryControl.new()
##   box.add_child(builder.create_control(entry))   # 造控件
##   builder.refresh()                              # 值在外面被改了，把控件刷一遍
##   builder.clear()                                # 清掉绑定（控件被 free 之后别再刷它）
##
## 关联：[控制台](../../../docs/参考存档/控制台.md) ｜ ConsoleEntry ｜ CanvasLayerConsole ｜ ModPage


## 勾选框 / 按钮的最小宽度（与原场景里手写的一致）
const ITEM_WIDTH := 200.0
## 滑条那一行：名字 / 滑条 / 数值三段的最小宽度
const SLIDER_NAME_WIDTH := 150.0
const SLIDER_WIDTH := 120.0
const SLIDER_VALUE_WIDTH := 45.0

## 按钮文字颜色：绿色
const BUTTON_FONT_COLOR := Color(0, 1, 0, 1)
const BUTTON_DISABLED_FONT_COLOR := Color(0, 0.5, 0, 1)

## 输入框样式：与「输入玩家名称」输入框一致（棕底 + 黄边 + 绿字）
## 字体走 AssetRegistry（缓存，不会每次开控制台重新读盘）
## ★ 是 `static var`：`_apply_input_style()` 是 static 函数，取不到实例成员
static var INPUT_FONT: Font = AssetRegistry.get_font("res://assets_custom/fonts/方正少儿_GBK.ttf")
const INPUT_FONT_COLOR := Color(0, 1, 0.1882353, 1)


## 已生成的勾选框：{entry=ConsoleEntry, control=CheckBox}
var _toggle_bindings: Array[Dictionary] = []
## 已生成的滑条：{entry=ConsoleEntry, slider=HSlider, label=Label}
var _slider_bindings: Array[Dictionary] = []
## 已生成的输入框：{entry=ConsoleEntry, control=LineEdit}
var _text_bindings: Array[Dictionary] = []
## 已生成的只读文本行：{entry=ConsoleEntry, label=Label}
var _readout_bindings: Array[Dictionary] = []


#region 造控件
## 按条目的 `kind` 造一个控件（Toggle → 勾选框 / Button → 按钮 / Slider → 滑条 /
## Text → 输入框 / Readout → 只读文本行）
func create_control(entry: ConsoleEntry) -> Control:
	match entry.kind:
		ConsoleEntry.E_Kind.Button:
			return _create_button(entry)
		ConsoleEntry.E_Kind.Slider:
			return _create_slider(entry)
		ConsoleEntry.E_Kind.Text:
			return _create_text(entry)
		ConsoleEntry.E_Kind.Readout:
			return _create_readout(entry)
		_:
			return _create_toggle(entry)


func _create_toggle(entry: ConsoleEntry) -> CheckBox:
	var check_box := CheckBox.new()
	check_box.text = entry.text
	check_box.tooltip_text = entry.tooltip
	check_box.custom_minimum_size = Vector2(ITEM_WIDTH, 0)
	check_box.mouse_filter = Control.MOUSE_FILTER_PASS
	check_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	check_box.toggled.connect(func(toggled_on: bool) -> void:
		entry.set_value(toggled_on)
	)
	_toggle_bindings.append({"entry": entry, "control": check_box})
	return check_box


func _create_button(entry: ConsoleEntry) -> Button:
	var button := Button.new()
	button.text = entry.text
	button.tooltip_text = entry.tooltip
	button.custom_minimum_size = Vector2(ITEM_WIDTH, 0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_button_style(button)
	button.pressed.connect(func() -> void:
		entry.run_action()
	)
	return button


## 滑条做成一行：名字 + 滑条 + 当前值
func _create_slider(entry: ConsoleEntry) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_FILL
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = entry.text
	name_label.tooltip_text = entry.tooltip
	name_label.custom_minimum_size = Vector2(SLIDER_NAME_WIDTH, 0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = entry.min_value
	slider.max_value = entry.max_value
	slider.step = entry.step
	slider.tooltip_text = entry.tooltip
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(SLIDER_VALUE_WIDTH, 0)
	row.add_child(value_label)

	slider.value_changed.connect(func(value: float) -> void:
		entry.set_value(value)
		value_label.text = format_value(entry, value)
	)
	_slider_bindings.append({"entry": entry, "slider": slider, "label": value_label})
	return row


## 输入框做成一行：名字 + LineEdit（回车 / 失焦时把文本写回条目）
func _create_text(entry: ConsoleEntry) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_FILL
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = entry.text
	name_label.tooltip_text = entry.tooltip
	name_label.custom_minimum_size = Vector2(SLIDER_NAME_WIDTH, 0)
	row.add_child(name_label)

	var line_edit := LineEdit.new()
	line_edit.custom_minimum_size = Vector2(SLIDER_WIDTH, 0)
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.placeholder_text = entry.placeholder
	line_edit.tooltip_text = entry.tooltip
	_apply_input_style(line_edit)
	line_edit.text_submitted.connect(func(_new_text: String) -> void:
		entry.set_value(line_edit.text)
	)
	line_edit.focus_exited.connect(func() -> void:
		entry.set_value(line_edit.text)
	)
	row.add_child(line_edit)

	_text_bindings.append({"entry": entry, "control": line_edit})
	return row


## 只读文本行做成一行：名字 + 值（值不可编辑，由 `refresh()` 刷新）
func _create_readout(entry: ConsoleEntry) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_FILL
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = entry.text
	name_label.tooltip_text = entry.tooltip
	name_label.custom_minimum_size = Vector2(SLIDER_NAME_WIDTH, 0)
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.tooltip_text = entry.tooltip
	value_label.custom_minimum_size = Vector2(SLIDER_WIDTH, 0)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## 值可能很长（一行流水），超出就截断成省略号，不去挤同行控件
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value_label)

	_readout_bindings.append({"entry": entry, "label": value_label})
	return row
#endregion


#region 刷新 / 清理
## 把控件上的显示值刷成条目里的当前值（不重建控件，焦点不会丢）
func refresh() -> void:
	for binding in _toggle_bindings:
		var toggle_entry: ConsoleEntry = binding["entry"]
		var check_box: CheckBox = binding["control"]
		if not is_instance_valid(check_box):
			continue
		check_box.set_pressed_no_signal(bool(toggle_entry.get_value()))
		check_box.disabled = not toggle_entry.is_enabled()
	for binding in _slider_bindings:
		var slider_entry: ConsoleEntry = binding["entry"]
		var slider: HSlider = binding["slider"]
		var value_label: Label = binding["label"]
		if not is_instance_valid(slider):
			continue
		var value := float(slider_entry.get_value())
		slider.set_value_no_signal(value)
		slider.editable = slider_entry.is_enabled()
		value_label.text = format_value(slider_entry, value)
	for binding in _text_bindings:
		var text_entry: ConsoleEntry = binding["entry"]
		var line_edit: LineEdit = binding["control"]
		if not is_instance_valid(line_edit):
			continue
		line_edit.editable = text_entry.is_enabled()
		## 正在输入时别回写：把用户打到一半的文本顶掉、光标也会被带走
		if not line_edit.has_focus():
			line_edit.text = str(text_entry.get_value())
	for binding in _readout_bindings:
		var readout_entry: ConsoleEntry = binding["entry"]
		var readout_label: Label = binding["label"]
		if not is_instance_valid(readout_label):
			continue
		readout_label.text = str(readout_entry.get_value())


## 清掉全部绑定（控件被销毁 / 面板重建时调它，免得再刷到已经 free 的节点上）
func clear() -> void:
	_toggle_bindings.clear()
	_slider_bindings.clear()
	_text_bindings.clear()
	_readout_bindings.clear()
#endregion


#region 样式
## 给按钮套上「三段式灰底 + 绿色字」的样式
## （控制台的翻页按钮、模组页面的列表按钮也用它 —— 全仓按钮长相一致）
## 背景不是一张拉满的贴图，而是挂一个 `PVZButtonBG` 画三段式贴图
## （左帽 + 中段 + 右帽，按下整套换按下态）—— 单张拉伸会把两端帽檐拉变形
static func apply_button_style(button: Button) -> void:
	var bg := PVZButtonBG.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(bg)
	button.button_down.connect(func() -> void:
		bg.set_pressed(true)
	)
	button.button_up.connect(func() -> void:
		bg.set_pressed(false)
	)
	## Button 自身的样式框全置空（背景交给 bg 画）；
	## 文字内边距沿用原来 StyleBoxTexture 的 texture_margin（16/16/16/20），别让文字移位
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 16.0
	empty.content_margin_top = 16.0
	empty.content_margin_right = 16.0
	empty.content_margin_bottom = 20.0
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_color_override("font_color", BUTTON_FONT_COLOR)
	button.add_theme_color_override("font_hover_color", BUTTON_FONT_COLOR)
	button.add_theme_color_override("font_pressed_color", BUTTON_FONT_COLOR)
	button.add_theme_color_override("font_disabled_color", BUTTON_DISABLED_FONT_COLOR)
	button.add_theme_color_override("font_focus_color", BUTTON_FONT_COLOR)


## 输入框：棕底 + 黄边 + 绿字
static func _apply_input_style(line_edit: LineEdit) -> void:
	var bg := _create_input_stylebox()
	line_edit.add_theme_stylebox_override("normal", bg)
	line_edit.add_theme_stylebox_override("focus", bg)
	line_edit.add_theme_font_override("font", INPUT_FONT)
	line_edit.add_theme_color_override("font_color", INPUT_FONT_COLOR)


static func _create_input_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3882353, 0.25490198, 0.0627451, 1)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.87058824, 0.79607844, 0.41960785, 1)
	sb.set_corner_radius_all(2)
	## 内容留白：别让输入的字贴到边框上
	sb.content_margin_left = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 8.0
	sb.content_margin_bottom = 4.0
	return sb


## 滑条数值的显示文本：整数步长就显示整数，小数步长按步长取整
static func format_value(entry: ConsoleEntry, value: float) -> String:
	if entry.step >= 1.0:
		return str(int(round(value)))
	return str(snappedf(value, maxf(entry.step, 0.0001)))
#endregion
