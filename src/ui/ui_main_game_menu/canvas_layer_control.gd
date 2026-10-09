extends CanvasLayer
class_name CanvasLayerConsole
## 控制台面板：入口页 + 每个分组一页，把 `ConsoleRegistry` 里的条目渲染成控件
##
## 本面板**不认识任何具体选项**（没有 `check_box_7` 这种节点、也没有 `_on_check_box_7_toggled`）：
## 条目是数据（`ConsoleEntry`），面板只做三件事 ——
##   1. 打开时先造「入口页」，再给每个分组造一页，同一时刻只显示一页（**没有滚动条**）
##   2. 控件被改动时把值写回条目（`entry.set_value()`）
##   3. `ON_CONFIG_UPDATE` / `entries_changed` 时把值从条目读回控件
##
## 翻页结构：
##   标题（顶部）      —— 跟着当前页变：「控制台」→ 分组名
##   入口页            —— 每个分组一个按钮，点了进那一页
##   分组页            —— 该组的控件网格 + 底部「返回」回到入口页
##   关闭（右下）      —— 永远可见，点了存盘退出
##
## 所有权怎么区分（**面板自己造的翻页按钮** vs **条目渲染出来的控件**）：
##   入口页的分组按钮与分组页的「返回」都带 meta `NAV_META`，表示它们不属于任何条目；
##   探针数「条目带来的控件」时会跳过它们。
##
## 所以**加一个开关不用碰这个文件**：本体加条目去 `ConsoleBuiltinEntries`，
## 模组加条目去 `ModBase.register_console_entries()` —— 新分组会自己多一个入口按钮、多一页。
##
## 关联：[控制台](../../../docs/参考存档/控制台.md) ｜ ConsoleRegistry ｜ ConsoleEntry ｜ ConsoleBuiltinEntries


## 每排放几个控件
const GRID_COLUMNS := 2
## 勾选框 / 按钮的最小宽度（与原场景里手写的一致）
const ITEM_WIDTH := 200.0
## 翻页导航按钮（入口页分组按钮 / 「返回」）的最小宽度
const NAV_BUTTON_WIDTH := 260.0
## 入口页标题
const PAGE_TITLE := "控制台"
## 分组页底部「返回」按钮的文字
const BACK_BUTTON_TEXT := "返回"
## 翻页导航按钮的 meta 标记：把「面板自己造的按钮」与「条目带来的 Button 控件」区分开
const NAV_META := &"console_page_nav"
## 滑条那一行：名字 / 滑条 / 数值三段的最小宽度
const SLIDER_NAME_WIDTH := 150.0
const SLIDER_WIDTH := 120.0
const SLIDER_VALUE_WIDTH := 45.0

## 控制台按钮背景：灰色背景图片
const BUTTON_BG_TEXTURE := preload("res://assets/image/ui/ui_main_game_menu/UI_BG/button_BG.png")
## 控制台按钮文字颜色：绿色
const BUTTON_FONT_COLOR := Color(0, 1, 0, 1)
const BUTTON_DISABLED_FONT_COLOR := Color(0, 0.5, 0, 1)

## 输入框样式：与「输入玩家名称」输入框一致（棕底 + 黄边 + 绿字）
const INPUT_FONT := preload("res://assets/fonts/方正少儿_GBK.ttf")
const INPUT_FONT_COLOR := Color(0, 1, 0.1882353, 1)


## 标题（进哪一页就显示哪一页的名字）
@onready var title_label: Label = $OptionBG/Label
## 页面容器（场景里只有一个空 Control，每一页都是运行时加进去的）
@onready var page_root: Control = $OptionBG/PageRoot

## 已生成的勾选框：{entry=ConsoleEntry, control=CheckBox}
var _toggle_bindings: Array[Dictionary] = []
## 已生成的滑条：{entry=ConsoleEntry, slider=HSlider, label=Label}
var _slider_bindings: Array[Dictionary] = []
## 已生成的输入框：{entry=ConsoleEntry, control=LineEdit}
var _text_bindings: Array[Dictionary] = []
## 已生成的只读文本行：{entry=ConsoleEntry, label=Label}
var _readout_bindings: Array[Dictionary] = []
## 入口页
var _index_page: Control = null
## 全部页面：{root=Control, title=String}（构建时就一次造齐，翻页只切 visible）
var _pages: Array[Dictionary] = []
## 分组名 → 该分组的那一页
var _category_pages: Dictionary[String, Control] = {}


func _ready() -> void:
	EventBus.subscribe(ConstEventName.ON_CONFIG_UPDATE, on_config_update)
	var registry := _registry()
	if registry != null:
		registry.entries_changed.connect(_on_entries_changed)
		registry.values_changed.connect(_update_console_panel)
	build_console_panel()


## 初始化 / 重建控制台（条目有增有减时整体重来一遍，比增量维护好懂）
## 造齐入口页与全部分组页后回到入口页
func build_console_panel() -> void:
	_clear_pages()

	var registry := _registry()
	if registry == null:
		Log.error("CanvasLayerConsole: 控制台注册表不可用，面板为空")
		return

	var categories := registry.get_categories()
	_index_page = _build_index_page(categories)
	_add_page(_index_page, PAGE_TITLE)
	for category in categories:
		var category_name := str(category)
		var page := _build_category_page(category_name, registry.get_entries(category_name))
		if page == null:
			continue
		_category_pages[category_name] = page
		_add_page(page, category_name)

	_update_console_panel()
	show_page(_index_page)


func on_config_update() -> void:
	_update_console_panel()


## 注册表里的条目变了（模组装载 / 卸载）：开着就重建，关着就等下次打开时重建
func _on_entries_changed() -> void:
	if visible:
		build_console_panel()


## 把控件上的显示值刷成条目里的当前值（隐藏的页也会被刷到，值始终是新的）
func _update_console_panel() -> void:
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
		value_label.text = _format_value(slider_entry, value)
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


#region 翻页
## 清掉所有页面（连同它们的绑定一起，下次构建从头来）
func _clear_pages() -> void:
	_toggle_bindings.clear()
	_slider_bindings.clear()
	_text_bindings.clear()
	_readout_bindings.clear()
	_pages.clear()
	_category_pages.clear()
	_index_page = null
	for child in page_root.get_children():
		page_root.remove_child(child)
		child.queue_free()


## 挂一页进 `PageRoot`（页面本身就已经排布好，这里只负责入树 + 先藏起来，
## 再由 `show_page()` 决定显示哪一页）
func _add_page(page: Control, page_title: String) -> void:
	if page == null:
		return
	_configure_page(page)
	page_root.add_child(page)
	page.visible = false
	_pages.append({"root": page, "title": page_title})


## 切到某一页：其余页藏起来，标题跟着换
func show_page(page: Control) -> void:
	if page == null:
		return
	for item in _pages:
		var item_root := item["root"] as Control
		if item_root == null:
			continue
		item_root.visible = item_root == page
		if item_root == page:
			title_label.text = str(item["title"])


## 入口页：每个分组一个按钮，点了进那一页
func _build_index_page(categories: Array) -> Control:
	var page := VBoxContainer.new()
	_configure_page(page)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 12)
	for category in categories:
		var category_name := str(category)
		var nav_button := _create_nav_button(
			category_name,
			"打开「%s」设置页" % category_name)
		_connect_nav_to_category(nav_button, category_name)
		page.add_child(nav_button)
	return page


## 入口页的按钮 → 跳到对应分组页。
## 刻意把分组名当**参数**传进来（而不是直接在循环里捕获循环变量），
## 免得所有按钮的回调共用同一个变量、最后全都跳到同一页。
func _connect_nav_to_category(button: Button, category_name: String) -> void:
	button.pressed.connect(func() -> void:
		show_page(_category_pages.get(category_name, _index_page))
	)


## 分组页：该组控件铺成一个网格 + 底部「返回」回入口页
func _build_category_page(category: String, entries: Array) -> Control:
	if entries.is_empty():
		return null
	var page := VBoxContainer.new()
	_configure_page(page)
	page.alignment = BoxContainer.ALIGNMENT_BEGIN
	page.add_theme_constant_override("separation", 24)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	## SHRINK_CENTER：不横向拉满，网格整体居中；只用 FILL 不带 EXPAND 是为了不让行距被拉散
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	for item in entries:
		var entry := item as ConsoleEntry
		if entry == null:
			continue
		grid.add_child(_create_control(entry))
	page.add_child(grid)

	var back_button := _create_nav_button(BACK_BUTTON_TEXT, "回到控制台入口页")
	back_button.pressed.connect(func() -> void:
		show_page(_index_page)
	)
	page.add_child(back_button)
	return page


## 每一页都铺满 `PageRoot`：内容一次性排开，不用滚动条
func _configure_page(page: Control) -> void:
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL


## 翻页导航按钮：样式与条目按钮一致，但带 `NAV_META` 标记，表示它是面板自己造的
func _create_nav_button(button_text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(NAV_BUTTON_WIDTH, 0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta(NAV_META, true)
	_apply_button_style(button)
	return button
#endregion


#region 造控件
func _create_control(entry: ConsoleEntry) -> Control:
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
	_apply_button_style(button)
	button.pressed.connect(func() -> void:
		entry.run_action()
	)
	return button


## 给控制台按钮套上「灰色背景图片 + 绿色字」的样式
func _apply_button_style(button: Button) -> void:
	var bg := _create_button_stylebox()
	button.add_theme_stylebox_override("normal", bg)
	button.add_theme_stylebox_override("hover", bg)
	button.add_theme_stylebox_override("pressed", bg)
	button.add_theme_stylebox_override("disabled", bg)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", BUTTON_FONT_COLOR)
	button.add_theme_color_override("font_hover_color", BUTTON_FONT_COLOR)
	button.add_theme_color_override("font_pressed_color", BUTTON_FONT_COLOR)
	button.add_theme_color_override("font_disabled_color", BUTTON_DISABLED_FONT_COLOR)
	button.add_theme_color_override("font_focus_color", BUTTON_FONT_COLOR)


func _create_button_stylebox() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = BUTTON_BG_TEXTURE
	sb.texture_margin_left = 16.0
	sb.texture_margin_top = 16.0
	sb.texture_margin_right = 16.0
	sb.texture_margin_bottom = 20.0
	return sb


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
		value_label.text = _format_value(entry, value)
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


## 给输入框套上「输入玩家名称」输入框的样式：棕底 + 黄边 + 绿字
func _apply_input_style(line_edit: LineEdit) -> void:
	var bg := _create_input_stylebox()
	line_edit.add_theme_stylebox_override("normal", bg)
	line_edit.add_theme_stylebox_override("focus", bg)
	line_edit.add_theme_font_override("font", INPUT_FONT)
	line_edit.add_theme_color_override("font_color", INPUT_FONT_COLOR)


func _create_input_stylebox() -> StyleBoxFlat:
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


## 只读文本行做成一行：名字 + 值（值不可编辑，由 `request_refresh()` 触发刷新）
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


## 滑条数值的显示文本：整数步长就显示整数，小数步长按步长取整
static func _format_value(entry: ConsoleEntry, value: float) -> String:
	if entry.step >= 1.0:
		return str(int(round(value)))
	return str(snappedf(value, maxf(entry.step, 0.0001)))


func _registry() -> ConsoleRegistry:
	if Global == null:
		return null
	return Global.console_registry


#region 打开 / 关闭
## 关闭控制台（顺带把设置存盘）
func _on_texture_button_pressed() -> void:
	visible = false
	EventBus.push_event(ConstEventName.SET_KEEP_SYSTEM_CURSOR_VISIBLE, false)
	Global.config_service.save_config()


## 打开控制台：每次都整体重建一次（回到入口页），保证运行期新登记的条目也能出现
func appear_canvas_layer_control() -> void:
	build_console_panel()
	visible = true
	EventBus.push_event(ConstEventName.SET_KEEP_SYSTEM_CURSOR_VISIBLE, true)
#endregion
