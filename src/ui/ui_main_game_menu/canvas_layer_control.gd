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
## 入口页最后还会多一个「模组」按钮（2026-10-11 起模组的入口就在这里）：
## 场景里挂了 `mod_page` 那份控制台才有（主菜单那份），游戏内那份没挂就没有这个按钮。
##
## 所有权怎么区分（**面板自己造的翻页按钮** vs **条目渲染出来的控件**）：
##   入口页的分组按钮与分组页的「返回」都带 meta `NAV_META`，表示它们不属于任何条目；
##   探针数「条目带来的控件」时会跳过它们。
##
## 所以**加一个开关不用碰这个文件**：本体的开关全部登记在 `ConsoleBuiltinEntries`，
## 新分组会自己多一个入口按钮、多一页（模组的界面不在这里 —— 那在「模组页面」）。
##
## 关联：[控制台](../../../docs/参考存档/控制台.md) ｜ ConsoleRegistry ｜ ConsoleEntry ｜ ConsoleBuiltinEntries ｜ ConsoleEntryControl（条目 → 控件的渲染器，与模组页面共用）


## 每排放几个控件
const GRID_COLUMNS := 2
## 翻页导航按钮（入口页分组按钮 / 「返回」）的最小宽度
const NAV_BUTTON_WIDTH := 260.0
## 入口页标题
const PAGE_TITLE := "控制台"
## 分组页底部「返回」按钮的文字
const BACK_BUTTON_TEXT := "返回"
## 翻页导航按钮的 meta 标记：把「面板自己造的按钮」与「条目带来的 Button 控件」区分开
const NAV_META := &"console_page_nav"
## 入口页上「模组」按钮的文字
const MOD_PAGE_TEXT := "模组"
## 入口页上「模组」按钮的悬停说明
const MOD_PAGE_TOOLTIP := "打开模组页面：开 / 关模组、改模组自己的设置"


## 标题（进哪一页就显示哪一页的名字）
@onready var title_label: Label = $OptionBG/Label
## 页面容器（场景里只有一个空 Control，每一页都是运行时加进去的）
@onready var page_root: Control = $OptionBG/PageRoot

## 模组页面的节点路径（只有主菜单那份控制台在场景里填了它；空 = 入口页不出现「模组」按钮）
@export var mod_page_path: NodePath = ^""

## 模组页面：按 `mod_page_path` 在 `_ready()` 里取一次（没挂就是 null）
var mod_page: ModPage = null

## 「条目 → 控件」的渲染器（与模组页面共用，见 `ConsoleEntryControl`）
var _entry_builder := ConsoleEntryControl.new()
## 入口页
var _index_page: Control = null
## 全部页面：{root=Control, title=String}（构建时就一次造齐，翻页只切 visible）
var _pages: Array[Dictionary] = []
## 分组名 → 该分组的那一页
var _category_pages: Dictionary[String, Control] = {}


func _ready() -> void:
	EventBus.subscribe(ConstEventName.ON_CONFIG_UPDATE, on_config_update)
	if not mod_page_path.is_empty():
		mod_page = get_node_or_null(mod_page_path) as ModPage
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
	_entry_builder.refresh()


#region 翻页
## 清掉所有页面（连同它们的绑定一起，下次构建从头来）
func _clear_pages() -> void:
	_entry_builder.clear()
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
	_add_mod_page_nav(page)
	return page


## 入口页最后那个「模组」按钮：点了打开模组页面（盖在本面板上，关掉它就能回到控制台）
## 没挂 `mod_page` 的那份控制台（游戏内那份）就不加这个按钮
func _add_mod_page_nav(page: Control) -> void:
	if not is_instance_valid(mod_page):
		return
	var nav_button := _create_nav_button(MOD_PAGE_TEXT, MOD_PAGE_TOOLTIP)
	nav_button.pressed.connect(func() -> void:
		mod_page.appear_mod_page()
	)
	page.add_child(nav_button)


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
		grid.add_child(_entry_builder.create_control(entry))
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
	ConsoleEntryControl.apply_button_style(button)
	return button
#endregion


func _registry() -> ConsoleRegistry:
	if Global == null:
		return null
	return Global.console_registry


#region 打开 / 关闭
## 关闭控制台（顺带把设置存盘）。模组页面还开着就一起收掉，免得留在本面板上面
func _on_texture_button_pressed() -> void:
	visible = false
	if is_instance_valid(mod_page):
		mod_page.visible = false
	EventBus.push_event(ConstEventName.SET_KEEP_SYSTEM_CURSOR_VISIBLE, false)
	Global.config_service.save_config()


## 打开控制台：每次都整体重建一次（回到入口页），保证运行期新登记的条目也能出现
func appear_canvas_layer_control() -> void:
	build_console_panel()
	## 上一次可能停在模组页面上就关掉了：这次打开先把它收起来，从入口页重新开始
	if is_instance_valid(mod_page):
		mod_page.visible = false
	visible = true
	EventBus.push_event(ConstEventName.SET_KEEP_SYSTEM_CURSOR_VISIBLE, true)
#endregion
