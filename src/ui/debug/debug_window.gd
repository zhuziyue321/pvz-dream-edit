extends CanvasLayer
class_name DebugWindow
## 调试窗口：Ctrl+Q 呼出 / 隐藏，半透明贴在屏幕右侧
##
## 开它的前提是**「调试模式」开着**（控制台 → 调试 → 调试模式，持久化键 `debug_mode`）；
## 关着的时候按 Ctrl+Q 只打一条提示、不弹出来 —— 免得玩家误触把界面顶出来。
##
## **热键为什么由本窗口自己处理，而不是挂在 `Global` 上**：
## `Global` 是普通 autoload，`process_mode` 继承到 `PROCESS_MODE_PAUSABLE`，
## 菜单一开就把树暂停了，那时它收不到 `_unhandled_key_input`（`Ctrl+D` 那套快捷键同理）；
## 而调试窗口恰恰要在暂停时也能呼出来看状态。所以本窗口 `process_mode = PROCESS_MODE_ALWAYS`，
## 自己收按键；`Global` 只负责 new 出来并 add_child。
##
## 窗口内容 = 一组 `ConsoleEntry`（与控制台同一套数据 + 同一个渲染器 `ConsoleEntryControl`，
## 见 [控制台](../../../docs/参考存档/控制台.md)），按 `category` 分成四页，
## **不登记进 `ConsoleRegistry`** —— 控制台面板不会多出这些按钮。
##
## 关联：[调试窗口](../../../docs/参考存档/调试窗口.md) ｜ DebugWindowEntries ｜ ConsoleEntryControl ｜ Global


#region 常量
## 面板宽度（贴右侧，占满整条屏幕高）
const WINDOW_WIDTH := 420.0
## 渲染层级：压在所有游戏 UI 之上（控制台面板是 128）
const DEBUG_LAYER := 200
## 只读状态行的刷新间隔（秒）
const REFRESH_INTERVAL := 0.25
## 调试模式没开时，提示最多每 3 秒打一条，免得按住 Ctrl+Q 刷屏
const HINT_COOLDOWN_MSEC := 3000
## 标题 / 提示
const TITLE := "调试窗口"
const HINT := "Ctrl+Q 开 / 关"
const CLOSE_TEXT := "关闭"
## 配色：不跟画风，深色半透明底 + 亮字，底下的游戏看得见
const COLOR_WINDOW_BG := Color(0.04, 0.05, 0.07, 0.88)
const COLOR_WINDOW_BORDER := Color(0.35, 0.80, 1.00, 0.90)
const COLOR_TEXT := Color(0.92, 0.95, 1.00, 1.00)
const COLOR_TEXT_DIM := Color(0.92, 0.95, 1.00, 0.55)
const FONT_SIZE_TITLE := 18
#endregion


## 整扇窗口（隐藏它；根 CanvasLayer 一直可见 —— 不可见的节点收不到按键）
var _window: Panel = null
## 分页条
var _tab_bar: TabBar = null
## 页面容器（每页一个 VBox，一次造齐，翻页只切 visible）
var _page_root: VBoxContainer = null
var _pages: Array[Control] = []
## 「条目 → 控件」的渲染器（与控制台 / 模组页面共用同一个类，各持一个实例）
var _entry_builder := ConsoleEntryControl.new()
## 状态行的刷新定时器
var _refresh_timer: Timer = null
## 上次打「调试模式没开」提示的时间（毫秒）
var _last_hint_msec := -99999


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


#region 开 / 关
## 呼出 / 隐藏（Ctrl+Q 调它）
func toggle_window() -> void:
	if _window == null:
		return
	## 已经开着就无条件收起来 —— 哪怕这时调试模式被关了，也得让人能把它收掉
	if _window.visible:
		set_window_visible(false)
		return
	if not is_debug_mode_on():
		_hint_debug_mode_off()
		return
	set_window_visible(true)


func set_window_visible(value: bool) -> void:
	if _window == null:
		return
	_window.visible = value
	## 窗口期间用系统鼠标（与控制台面板一个待遇），不然在自定义光标模式下没法点按钮
	EventBus.push_event(ConstEventName.SET_KEEP_SYSTEM_CURSOR_VISIBLE, value)
	if value:
		_entry_builder.refresh()


## 「调试模式」开关是否开着（控制台 → 调试 → 调试模式）
func is_debug_mode_on() -> bool:
	return bool(Global.config_service.get_console_value(
		ConsoleBuiltinEntries.DEBUG_MODE_KEY, false))


func _hint_debug_mode_off() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hint_msec < HINT_COOLDOWN_MSEC:
		return
	_last_hint_msec = now
	Log.warn("调试窗口：Ctrl+Q 需要先打开「调试模式」（控制台 → 调试 → 调试模式）")


## 配置有变化（在控制台里改了开关）：值刷一遍；调试模式被关掉就把窗口收起来
func _on_config_update() -> void:
	if _window == null:
		return
	if _window.visible and not is_debug_mode_on():
		set_window_visible(false)
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


func _on_refresh_timeout() -> void:
	if _window != null and _window.visible:
		_entry_builder.refresh()
#endregion


#region 造界面
func _build_window() -> void:
	_window = Panel.new()
	_window.name = &"Window"
	_window.custom_minimum_size = Vector2(WINDOW_WIDTH, 0.0)
	## 挡住点击，免得点窗口的时候顺便在游戏里种了棵植物
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.add_theme_stylebox_override("panel", _create_window_stylebox())
	add_child(_window)
	## ⚠️ 贴右边 + 固定宽**只能**把 anchors 与四个 offset 全写死，不要指望任何 preset：
	##   · `set_anchors_preset(PRESET_RIGHT_WIDE)` 会按控件**当前矩形**（运行时新建的 Control 是 0×0）
	##     反算 offsets —— 它会把 `offset_bottom` 写成 `-视口高`，高度于是算成 0；宽度也会算成 0，
	##     再被 `custom_minimum_size` 按 `GROW_DIRECTION_END` **向右**撑开，整块面板就跑到视口右边界之外。
	##   · `set_anchors_and_offsets_preset()` 同样不行：它的左边距取自 `get_minimum_size()`，
	##     而宽度写在 `custom_minimum_size` 里，那个值不参与该计算 —— 结果与上面一样。
	## 显式写死之后：宽 = (1×视口宽 + 0) - (1×视口宽 - 420) = 420，高 = (1×视口高 + 0) - (0 + 0) = 视口高。
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
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(_create_title_row())

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

	_refresh_timer = Timer.new()
	_refresh_timer.name = &"RefreshTimer"
	_refresh_timer.wait_time = REFRESH_INTERVAL
	## 倍速拉到 0 冻结游戏时，状态行也该继续刷
	_refresh_timer.ignore_time_scale = true
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_on_refresh_timeout)
	add_child(_refresh_timer)


func _create_title_row() -> Control:
	var row := HBoxContainer.new()
	row.name = &"TitleRow"

	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var hint := Label.new()
	hint.text = HINT
	hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	row.add_child(hint)

	var close := Button.new()
	close.text = CLOSE_TEXT
	close.pressed.connect(set_window_visible.bind(false))
	row.add_child(close)
	return row


## 造齐四页（顺序 = DebugWindowEntries.get_categories()）
## 每条条目由渲染器造出控件后直接加进对应那一页
func _build_pages() -> void:
	_entry_builder.clear()
	for page in _pages:
		if is_instance_valid(page):
			page.queue_free()
	_pages.clear()
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
		_tab_bar.add_tab(category)
		DebugWindowEntries.register_all(_entry_builder, category, page)

	if _pages.is_empty():
		return
	_show_page(0)
#endregion


#region 翻页
func _on_tab_changed(tab: int) -> void:
	_show_page(tab)


func _show_page(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = (i == index)
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
