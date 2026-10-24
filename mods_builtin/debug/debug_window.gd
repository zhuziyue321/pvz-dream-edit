extends CanvasLayer
## 调试窗口（调试模组）：Ctrl+Q 呼出 / 隐藏，半透明贴在屏幕右侧
##
## **只在调试模组启用时才存在**：模组 `install()` 里 new 出来挂到 `Global` 下，
## `uninstall()` 里整个释放 —— 原版没有这个窗口，所以它归模组，本体一行都不留。
##
## **热键为什么由本窗口自己处理，而不是挂在 `Global` 上**：
## `Global` 是普通 autoload，`process_mode` 继承到 `PROCESS_MODE_PAUSABLE`，
## 菜单一开就把树暂停了，那时它收不到 `_unhandled_key_input`（`Ctrl+D` 那套快捷键同理）；
## 而调试窗口恰恰要在暂停时也能呼出来看状态。所以本窗口 `process_mode = PROCESS_MODE_ALWAYS`，
## 自己收按键。输入动作 `ShortcutKeys_DebugWindow` 是本体 `project.godot` 里的通用输入映射。
##
## 窗口内容 = 一组 `ConsoleEntry`（与控制台同一套数据 + 同一个渲染器 `ConsoleEntryControl`，
## 见 [控制台](../../../docs/参考存档/控制台.md)），按 `category` 分成七页，
## **不登记进 `ConsoleRegistry`** —— 控制台面板不会多出这些按钮。
##
## 七页 = 常用 / 战斗 / 资源 / 开关 / 运行 / 状态 / 日志（前六页是条目，日志页是只读文本框）。
##
## 本文件只负责「容器 + 翻页 + 搜索 + 拖动调宽 + 定时刷新」，
## 具体有哪些条目、每个条目干什么，全在 `debug_window_entries.gd`；
## 加一项调试功能**不要**动这里（见 [调试窗口](../../../docs/参考存档/调试窗口.md) §三）。
##
## 键盘：Ctrl+Q 开关；窗口打开时 **Ctrl+1 ~ Ctrl+9** 直接跳页（走的 `_input`，
## 在 `_unhandled_input` 之前吃掉，所以不会顺带触发卡槽的 1-9 选卡）。
##
## 关联：[调试窗口](../../../docs/参考存档/调试窗口.md) ｜ debug_window_entries.gd ｜ ConsoleEntryControl

## 同目录的条目表（模组脚本不写 `class_name`，一律 preload 引用）
const DebugWindowEntries := preload("debug_window_entries.gd")


#region 常量
## 面板默认宽度（贴右侧；拖左边缘可改）
const WINDOW_WIDTH := 460.0
## 允许拖到的最窄 / 最宽
const MIN_WINDOW_WIDTH := 340.0
const MAX_WINDOW_WIDTH := 1000.0
## 拖标题栏时至少要留在屏幕里的高度（免得整块拖出去找不回来）
const MIN_VISIBLE_HEIGHT := 80.0
## 左边缘那根「拖宽」把手的宽度
const RESIZE_HANDLE_WIDTH := 8.0
## 渲染层级：压在所有游戏 UI 之上（控制台面板是 128）
const DEBUG_LAYER := 200
## 只读状态行的刷新间隔（秒）
const REFRESH_INTERVAL := 0.25
## 日志页文本框的最小高度（它在一个 ScrollContainer 里，不给最小尺寸会被压成 0）
const LOG_VIEW_MIN_HEIGHT := 260.0
## 标题 / 提示
const TITLE := "调试窗口"
const HINT := "Ctrl+Q 开关 ｜ Ctrl+1-9 切页"
const RESET_TEXT := "复位"
const CLOSE_TEXT := "关闭"
## 配色：不跟画风，深色半透明底 + 亮字，底下的游戏看得见
const COLOR_WINDOW_BG := Color(0.04, 0.05, 0.07, 0.88)
const COLOR_WINDOW_BORDER := Color(0.35, 0.80, 1.00, 0.90)
const COLOR_TEXT := Color(0.92, 0.95, 1.00, 1.00)
const COLOR_TEXT_DIM := Color(0.92, 0.95, 1.00, 0.55)
const COLOR_ERROR := Color(1.00, 0.55, 0.50, 1.00)
const FONT_SIZE_TITLE := 18
#endregion


## 整扇窗口（隐藏它；根 CanvasLayer 一直可见 —— 不可见的节点收不到按键）
var _window: Panel = null
## 标题栏（拖动它上下移动窗口）
var _title_row: HBoxContainer = null
## 左边缘拖宽把手
var _resize_handle: ColorRect = null
## 分页条
var _tab_bar: TabBar = null
## 搜索框（按条目文字 / id 过滤所有页里的行）
var _search_edit: LineEdit = null
## 动作反馈条（底部一行，`DebugWindowEntries.notify()` 写它）
var _status_label: Label = null
## 页面容器（每页一个 VBox，一次造齐，翻页只切 visible）
var _page_root: VBoxContainer = null
var _pages: Array[Control] = []
## 与 `_pages` 一一对应的分组名（判断当前是不是日志页）
var _page_categories: Array[String] = []
## 「条目 → 控件」的渲染器（与控制台 / 模组页面共用同一个类，各持一个实例）
var _entry_builder := ConsoleEntryControl.new()
## 状态行的刷新定时器
var _refresh_timer: Timer = null
## 日志页的只读文本框（只有日志页存在）
var _log_view: TextEdit = null
## 上次铺日志时的 `Log.recent_version`
var _log_version := -1
## 拖动 / 拖宽过程中的起点
var _drag_start_mouse_y := 0.0
var _drag_start_offset_top := 0.0
var _drag_start_offset_bottom := 0.0
var _is_dragging := false
var _resize_start_mouse_x := 0.0
var _resize_start_width := 0.0
var _is_resizing := false


func _ready() -> void:
	name = &"DebugWindow"
	layer = DEBUG_LAYER
	## 游戏被菜单暂停时窗口也要能呼出来 / 收回去
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.subscribe(ConstEventName.ON_CONFIG_UPDATE, _on_config_update)
	_build_window()
	_build_pages()
	set_window_visible(false)


func _exit_tree() -> void:
	EventBus.unsubscribe(ConstEventName.ON_CONFIG_UPDATE, _on_config_update)
	_entry_builder.clear()
	## 本窗口打开过的副作用（植物无敌 / 无限阳光）一并撤掉
	DebugWindowEntries.shutdown()


#region 开 / 关
## 呼出 / 隐藏（Ctrl+Q 调它）
func toggle_window() -> void:
	if _window == null:
		return
	set_window_visible(not _window.visible)


func set_window_visible(value: bool) -> void:
	if _window == null:
		return
	_is_dragging = false
	_is_resizing = false
	_window.visible = value
	## 窗口期间用系统鼠标（与控制台面板一个待遇），不然在自定义光标模式下没法点按钮
	EventBus.push_event(ConstEventName.SET_KEEP_SYSTEM_CURSOR_VISIBLE, value)
	if value:
		_entry_builder.refresh()
		_refresh_log()


## 配置有变化（在控制台里改了开关）：值刷一遍
func _on_config_update() -> void:
	if _window == null:
		return
	_entry_builder.refresh()
#endregion


#region 热键
## Ctrl+Q 归本窗口独吞：走到这里说明没被输入框 / 按钮吃掉
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if not Input.is_action_just_pressed("ShortcutKeys_DebugWindow"):
		return
	get_viewport().set_input_as_handled()
	toggle_window()


## 数字键切页：**只能写在 `_input`**，不能用 `_unhandled_key_input` ——
## 卡槽的 1-9 选卡在 `_unhandled_key_input` 里响应且不标记 handled，
## 放到 unhandled 阶段会和选卡同时发生。`_input` 早于 unhandled，吃掉事件就不会再传给卡槽。
func _input(event: InputEvent) -> void:
	if _window == null or not _window.visible:
		return
	var key_event := event as InputEventKey
	if key_event == null or key_event.echo or not key_event.pressed:
		return
	if not key_event.ctrl_pressed or key_event.alt_pressed or key_event.shift_pressed:
		return
	var key := key_event.keycode
	if key == KEY_NONE:
		key = key_event.physical_keycode
	var index := int(key) - int(KEY_1)
	if index < 0 or index >= _pages.size():
		return
	get_viewport().set_input_as_handled()
	_show_page(index)


func _on_refresh_timeout() -> void:
	## 需要持续生效的开关（植物无敌 / 无限阳光）由条目表自己落实 ——
	## **不看窗口显隐**：面板收起来之后这两个开关也该继续生效（切关会清修饰器，要靠这里补）
	DebugWindowEntries.tick()
	if _window == null or not _window.visible:
		return
	_entry_builder.refresh()
	_refresh_feedback()
	var index := _get_visible_page_index()
	if index >= 0 and _page_categories[index] == DebugWindowEntries.CATEGORY_LOG:
		_refresh_log()
#endregion


#region 拖动 / 调宽
## 标题栏拖动：上下移动整块面板（高度不变；至少留 `MIN_VISIBLE_HEIGHT` 在屏幕里）
func _on_title_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_is_dragging = button.pressed
		if button.pressed:
			_drag_start_mouse_y = get_viewport().get_mouse_position().y
			_drag_start_offset_top = _window.offset_top
			_drag_start_offset_bottom = _window.offset_bottom
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _is_dragging:
		var dy := get_viewport().get_mouse_position().y - _drag_start_mouse_y
		var height := _window.size.y
		var viewport_height := get_viewport().get_visible_rect().size.y
		var new_top := clampf(_drag_start_offset_top + dy,
			-height + MIN_VISIBLE_HEIGHT, viewport_height - MIN_VISIBLE_HEIGHT)
		var actual_dy := new_top - _drag_start_offset_top
		_window.offset_top = _drag_start_offset_top + actual_dy
		_window.offset_bottom = _drag_start_offset_bottom + actual_dy
		get_viewport().set_input_as_handled()


## 左边缘拖动：改面板宽度（只改 `offset_left`，四个 offset 仍然显式写死）
func _on_resize_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_is_resizing = button.pressed
		if button.pressed:
			_resize_start_mouse_x = get_viewport().get_mouse_position().x
			_resize_start_width = _window.size.x
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _is_resizing:
		var dx := get_viewport().get_mouse_position().x - _resize_start_mouse_x
		_set_panel_width(_resize_start_width - dx)
		get_viewport().set_input_as_handled()


func _set_panel_width(width: float) -> void:
	var clamped := clampf(width, MIN_WINDOW_WIDTH, MAX_WINDOW_WIDTH)
	_window.offset_left = -clamped


## 「复位」：恢复默认宽度 + 贴回顶部
func _reset_layout() -> void:
	if _window == null:
		return
	_window.offset_left = -WINDOW_WIDTH
	_window.offset_top = 0.0
	_window.offset_right = 0.0
	_window.offset_bottom = 0.0
#endregion


#region 造界面
func _build_window() -> void:
	_window = Panel.new()
	_window.name = &"Window"
	_window.custom_minimum_size = Vector2(WINDOW_WIDTH, 0.0)
	## 挡住点击，免得点窗口的时候顺便在游戏里种了棵植物
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.clip_contents = true
	_window.add_theme_stylebox_override("panel", _create_window_stylebox())
	add_child(_window)
	## ⚠️ 贴右边 + 固定宽**只能**把 anchors 与四个 offset 全写死，不要指望任何 preset：
	##   · `set_anchors_preset(PRESET_RIGHT_WIDE)` 会按控件**当前矩形**（运行时新建的 Control 是 0×0）
	##     反算 offsets —— 它会把 `offset_bottom` 写成 `-视口高`，高度于是算成 0；宽度也会算成 0，
	##     再被 `custom_minimum_size` 按 `GROW_DIRECTION_END` **向右**撑开，整块面板就跑到视口右边界之外。
	##   · `set_anchors_and_offsets_preset()` 同样不行：它的左边距取自 `get_minimum_size()`，
	##     而宽度写在 `custom_minimum_size` 里，那个值不参与该计算 —— 结果与上面一样。
	## 显式写死之后：宽 = (1×视口宽 + 0) - (1×视口宽 - 420) = 420，高 = (1×视口高 + 0) - (0 + 0) = 视口高。
	## （拖宽只会改 `offset_left`，四个 offset 仍然一个不落；height 仍由 top/bottom 决定。
	##   删掉 `custom_minimum_size` 的宽度也不行 —— 面板可能在拖宽时反向收缩。）
	_window.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_window.offset_left = -WINDOW_WIDTH
	_window.offset_top = 0.0
	_window.offset_right = 0.0
	_window.offset_bottom = 0.0

	var margin := MarginContainer.new()
	margin.name = &"Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_window.add_child(margin)

	var root := VBoxContainer.new()
	root.name = &"Root"
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	_title_row = _create_title_row()
	root.add_child(_title_row)

	_search_edit = LineEdit.new()
	_search_edit.name = &"Search"
	_search_edit.placeholder_text = "搜索条目（名字 / id）…"
	_search_edit.clear_button_enabled = true
	_search_edit.tooltip_text = "只切行的显示 / 隐藏，不重建控件；清空即恢复"
	_search_edit.text_changed.connect(_on_search_text_changed)
	root.add_child(_search_edit)

	_tab_bar = TabBar.new()
	_tab_bar.name = &"Tabs"
	_tab_bar.tab_changed.connect(_on_tab_changed)
	root.add_child(_tab_bar)

	var scroll := ScrollContainer.new()
	scroll.name = &"Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_page_root = VBoxContainer.new()
	_page_root.name = &"PageRoot"
	_page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_root.add_theme_constant_override("separation", 6)
	scroll.add_child(_page_root)

	_status_label = Label.new()
	_status_label.name = &"Status"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	root.add_child(_status_label)

	_refresh_timer = Timer.new()
	_refresh_timer.name = &"RefreshTimer"
	_refresh_timer.wait_time = REFRESH_INTERVAL
	## 倍速拉到 0 冻结游戏时，状态行也该继续刷
	_refresh_timer.ignore_time_scale = true
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_on_refresh_timeout)
	add_child(_refresh_timer)

	## 拖宽把手放在最后（后加的子节点先收输入），保证左边缘 8px 永远归它
	_resize_handle = ColorRect.new()
	_resize_handle.name = &"ResizeHandle"
	_resize_handle.color = Color(COLOR_WINDOW_BORDER, 0.22)
	_resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_resize_handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_resize_handle.tooltip_text = "拖动改变窗口宽度"
	_resize_handle.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_resize_handle.offset_left = 0.0
	_resize_handle.offset_right = RESIZE_HANDLE_WIDTH
	_resize_handle.offset_top = 0.0
	_resize_handle.offset_bottom = 0.0
	_resize_handle.gui_input.connect(_on_resize_gui_input)
	_window.add_child(_resize_handle)


func _create_title_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = &"TitleRow"
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_MOVE
	row.tooltip_text = "拖动标题栏上下移动窗口"
	row.gui_input.connect(_on_title_gui_input)

	var title := Label.new()
	title.text = TITLE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var hint := Label.new()
	hint.text = HINT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	row.add_child(hint)

	var reset := Button.new()
	reset.text = RESET_TEXT
	reset.tooltip_text = "恢复默认宽度并贴回顶部"
	reset.pressed.connect(_reset_layout)
	row.add_child(reset)

	var close := Button.new()
	close.text = CLOSE_TEXT
	close.pressed.connect(set_window_visible.bind(false))
	row.add_child(close)
	return row


## 造齐各页（顺序 = DebugWindowEntries.get_categories()）
## 普通页：每条条目由渲染器造出控件后直接加进对应那一页
## 日志页：铺一个只读 `TextEdit`（读 `Log` 的最近日志缓冲）
func _build_pages() -> void:
	_entry_builder.clear()
	DebugWindowEntries.begin_register()
	for page in _pages:
		if is_instance_valid(page):
			page.queue_free()
	_pages.clear()
	_page_categories.clear()
	_log_view = null
	if _tab_bar != null:
		_tab_bar.clear_tabs()

	for category in DebugWindowEntries.get_categories():
		var page := VBoxContainer.new()
		page.name = category
		page.visible = false
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 6)
		_page_root.add_child(page)
		_pages.append(page)
		_page_categories.append(category)
		_tab_bar.add_tab(category)
		if category == DebugWindowEntries.CATEGORY_LOG:
			_build_log_page(page)
		else:
			DebugWindowEntries.register_all(_entry_builder, category, page)

	if _pages.is_empty():
		return
	_show_page(0)


## 日志页：一行说明 + 「清空」按钮 + 只读文本框
func _build_log_page(page: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = &"LogHeader"

	var hint := Label.new()
	hint.text = "最近 %d 条 Log.* 输出（新的在最后）" % Log.MAX_RECENT_LINES
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)

	var clear := Button.new()
	clear.text = "清空"
	clear.tooltip_text = "只清面板里的缓冲，不影响引擎写出的日志文件"
	clear.pressed.connect(_on_clear_log_pressed)
	row.add_child(clear)
	page.add_child(row)

	var view := TextEdit.new()
	view.name = &"LogView"
	view.custom_minimum_size = Vector2(0.0, LOG_VIEW_MIN_HEIGHT)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.editable = false
	view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	view.add_theme_color_override("font_color", COLOR_TEXT)
	view.text = Log.get_recent_text()
	page.add_child(view)
	_log_view = view
	_log_version = Log.recent_version


## 搜索框：只切行的 visible，不重建控件（不丢焦点、不打断正在输入的文本框）
func _on_search_text_changed(keyword: String) -> void:
	DebugWindowEntries.apply_filter(keyword)


func _on_clear_log_pressed() -> void:
	Log.clear_recent()
	_refresh_log()
#endregion


#region 翻页
func _on_tab_changed(tab: int) -> void:
	_show_page(tab)


func _show_page(index: int) -> void:
	if _pages.is_empty():
		return
	var target := clampi(index, 0, _pages.size() - 1)
	for i in _pages.size():
		_pages[i].visible = (i == target)
	if _tab_bar != null and _tab_bar.current_tab != target:
		_tab_bar.current_tab = target
	if _page_categories[target] == DebugWindowEntries.CATEGORY_LOG:
		_refresh_log()


func _get_visible_page_index() -> int:
	for i in _pages.size():
		if _pages[i].visible:
			return i
	return -1
#endregion


#region 刷新反馈 / 日志
## 底部反馈条：`DebugWindowEntries.notify()` 写，超过 `FEEDBACK_KEEP_MSEC` 自动清空
func _refresh_feedback() -> void:
	if _status_label == null:
		return
	var feedback := DebugWindowEntries.get_feedback()
	var text := String(feedback.get("text", ""))
	if int(feedback.get("age", 0)) > DebugWindowEntries.FEEDBACK_KEEP_MSEC:
		text = ""
	if _status_label.text == text:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color",
		COLOR_ERROR if bool(feedback.get("is_error", false)) else COLOR_TEXT_DIM)


## 日志页文本框：只在 `Log.recent_version` 变了才重铺
func _refresh_log() -> void:
	if _log_view == null or not is_instance_valid(_log_view):
		return
	if _log_version == Log.recent_version:
		return
	_log_version = Log.recent_version
	_log_view.text = Log.get_recent_text()
	if _log_view.get_line_count() > 0:
		_log_view.set_caret_line(_log_view.get_line_count() - 1, true)
#endregion


#region 样式
static func _create_window_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_WINDOW_BG
	sb.set_border_width_all(2)
	sb.border_color = COLOR_WINDOW_BORDER
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 10.0
	sb.content_margin_bottom = 8.0
	return sb
#endregion
