extends CanvasLayer
class_name ModPage
## 模组页面：**左边一列模组，选中哪个就在右边显示它的详情**
##
## 本页面**不认识任何一个具体模组**（与控制台面板同一个道理）：
##   左列的列表 = `ModManager.all_mods`（注册表登记了哪些模组，页面上就有哪些）；
##   右侧的详情 = 名称 / 开关 / 说明这三样（页面自己造）
##              + 模组自己给的那一块（`ModBase.create_detail_control()`）。
##
## 模组**没启用**时，它自己那一块**整块禁用**（见 `_set_controls_enabled()`）：
## 关着的模组下一局根本不装载，那块里的设置改了也不生效，索性让它点不动。
##
## 所以新增一个模组不用碰本页面：登记进 `ModManager.MOD_SCRIPT_PATHS` 就自动出现在列表里；
## 想让详情有内容，就在自己的 `ModBase` 子类里重写 `create_detail_control()`。
##
## 翻页结构（与控制台一致：场景里只有几个空容器，控件全是运行时造的）：
##   标题（顶部）  —— 「模组」
##   左列          —— 每个模组一个按钮，点了就选中它
##   右侧          —— 当前选中模组的详情（可滚动）
##   关闭（右下）  —— 藏起本页面，回到控制台（入口在 主菜单 → 选项 → 控制台 →「模组」）
##
## 关联：[模组机制](../../../docs/参考存档/模组机制.md) ｜ [控制台](../../../docs/参考存档/控制台.md) ｜ ModManager ｜ ModBase ｜ ConsoleEntryControl


## 列表里没有模组时写的一句话
const EMPTY_LIST_TEXT := "（还没有登记任何模组）"
## 模组没给详情控件时写的一句话
const EMPTY_DETAIL_TEXT := "（这个模组没有要显示的东西）"
## 列表按钮上的开关状态
const ENABLED_TAG := "已启用"
const DISABLED_TAG := "未启用"
## 详情里那个开关按钮的两种文字
const TURN_ON_TEXT := "启用这个模组"
const TURN_OFF_TEXT := "停用这个模组"
## 选中的那一项前面加的箭头
const SELECTED_MARK := "▶ "
## 模组没启用时，它那一块设置上面写的一句提示
const DISABLED_HINT_TEXT := "（这个模组现在是关的：先按上面的开关启用它，下面这些设置才能改）"
## 禁用时整块压暗一点，让人一眼看出「现在改不了」
const DISABLED_MODULATE := Color(1, 1, 1, 0.6)

## 「模组自己那一块」挂刷新回调用的 meta 键 —— 与 `mods_builtin/mod_base.gd` 的
## `DETAIL_REFRESH_META` 必须一致。这里不能写 `DETAIL_REFRESH_META`：
## 模组（含 `ModBase`）不写 `class_name`（它可能在 `user://mods/` 下加载，那里
## `class_name` 不注册为全局类，内置源那一份照同一口径写），本体（本文件在 `res://`）
## 引用不到 —— 见 [模组机制](../../../docs/参考存档/模组机制.md) §二。
const DETAIL_REFRESH_META := &"mod_detail_refresh"


## 左列（场景里是个空 VBoxContainer，列表运行时往里塞按钮）
@onready var list_box: VBoxContainer = $OptionBG/ListScroll/List
## 右侧详情（同样是空 VBoxContainer，内容随选中的模组重建）
@onready var detail_box: VBoxContainer = $OptionBG/DetailScroll/Detail

## 当前选中的模组 id（空 = 还没选）
var _selected_mod_id: StringName = &""
## 当前详情控件挂的刷新回调（`DETAIL_REFRESH_META`）：值在外面变了就调它一次
var _detail_refresh: Callable = Callable()
## 当前详情里「模组自己那一块」的根节点（刷新之后要照着它再禁用一遍）
var _detail_control: Control = null


func _ready() -> void:
	visible = false
	## 两列都是运行时填的容器：行距在这里定一次，模组自己那一块各自再定自己的
	list_box.add_theme_constant_override("separation", 8)
	detail_box.add_theme_constant_override("separation", 10)
	var registry := _registry()
	if registry != null:
		registry.values_changed.connect(_on_values_changed)


#region 打开 / 关闭
## 打开页面：每次都整体重建一遍（运行期开 / 关了模组，列表与详情都跟着变）
func appear_mod_page() -> void:
	build_mod_page()
	visible = true


## 关闭页面（右下角按钮）
func _on_close_button_pressed() -> void:
	visible = false
#endregion


#region 构建
## 重建列表 + 详情（选中项还在就保留，没了就回到第一个）
func build_mod_page() -> void:
	_build_list()
	if not ModManager.all_mods.has(_selected_mod_id):
		_selected_mod_id = _first_mod_id()
	_build_detail()


## 左列：每个登记过的模组一个按钮，按钮上带开关状态，选中的那个前面加箭头
func _build_list() -> void:
	_clear_children(list_box)
	if ModManager.all_mods.is_empty():
		list_box.add_child(_create_label(EMPTY_LIST_TEXT))
		return
	for mod_id in ModManager.all_mods:
		var mod = ModManager.all_mods[mod_id]
		if mod == null:
			continue
		list_box.add_child(_create_list_button(mod_id, mod))


## 右侧详情：名称 → 开关 → 说明 → 模组自己给的那一块
func _build_detail() -> void:
	_clear_children(detail_box)
	_detail_refresh = Callable()
	_detail_control = null
	var mod = ModManager.get_mod(_selected_mod_id)
	if mod == null:
		detail_box.add_child(_create_label(EMPTY_LIST_TEXT))
		return

	var title := _create_label(mod.get_mod_name())
	title.add_theme_font_size_override("font_size", 28)
	detail_box.add_child(title)
	detail_box.add_child(_create_toggle_button(mod))
	detail_box.add_child(_create_label(mod.get_mod_description()))

	## `mod` 只能是 Variant（模组脚本的类本体引用不到，见上面的 meta 注释），
	## 所以这里要显式标类型，`:=` 推不出来
	var detail: Control = mod.create_detail_control()
	if detail == null:
		detail_box.add_child(_create_label(EMPTY_DETAIL_TEXT))
		return
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## 模组关着的时候它那块设置改了也不生效：先写一句提示，整块再置禁用
	if not ModManager.is_mod_enabled(mod.get_mod_id()):
		detail_box.add_child(_create_label(DISABLED_HINT_TEXT))
		detail.modulate = DISABLED_MODULATE
		_set_controls_enabled(detail, false)
	detail_box.add_child(detail)
	_detail_control = detail
	## 模组想让自己那块能刷新，就在控件上挂一个回调（见 `DETAIL_REFRESH_META`）
	if detail.has_meta(DETAIL_REFRESH_META):
		_detail_refresh = detail.get_meta(DETAIL_REFRESH_META)
#endregion


#region 造控件
## 左列的一个按钮：点了就选中这个模组
func _create_list_button(mod_id: StringName, mod) -> Button:
	var button := Button.new()
	var state_tag := ENABLED_TAG if ModManager.is_mod_enabled(mod_id) else DISABLED_TAG
	button.text = (SELECTED_MARK if mod_id == _selected_mod_id else "") \
		+ mod.get_mod_name() + "（" + state_tag + "）"
	button.tooltip_text = mod.get_mod_description()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ConsoleEntryControl.apply_button_style(button)
	button.pressed.connect(func() -> void:
		_selected_mod_id = mod_id
		build_mod_page()
	)
	return button


## 详情里的开关按钮：点了就开 / 关这个模组，然后整体重建（模组自己那块也会跟着换）
func _create_toggle_button(mod) -> Button:
	var mod_id: StringName = mod.get_mod_id()
	var enabled := ModManager.is_mod_enabled(mod_id)
	var button := Button.new()
	button.text = TURN_OFF_TEXT if enabled else TURN_ON_TEXT
	button.tooltip_text = "开 = 立刻装载它（下一局主游戏里就有它）；关 = 下一局不再装载。\n" \
		+ "这个开关会存进存档文件（user://<用户名>/mod_config.ini），下次启动照旧"
	button.custom_minimum_size = Vector2(ConsoleEntryControl.ITEM_WIDTH, 0)
	## 不跟着详情区拉满整行：按钮就按自己的最小宽度（200）靠左放
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ConsoleEntryControl.apply_button_style(button)
	button.pressed.connect(func() -> void:
		ModManager.set_mod_enabled(mod_id, not ModManager.is_mod_enabled(mod_id))
		build_mod_page()
	)
	return button


## 递归开 / 关一棵控件树里**所有能交互的控件**（模组没启用时用它整块禁用）
## 页面不认识模组给了什么控件，只能按类型一个个关：按钮 / 勾选框 → `disabled`，
## 输入框 → `editable`，滑条 / 数字框（`Range` 系）→ `editable`；纯文字不用管。
static func _set_controls_enabled(root: Node, enabled: bool) -> void:
	if root is Button:
		root.disabled = not enabled
	elif root is LineEdit or root is TextEdit:
		root.editable = enabled
	elif root is Range:
		root.editable = enabled
	for child in root.get_children():
		_set_controls_enabled(child, enabled)


func _create_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
#endregion


#region 小工具
## 清空一个容器（连同里面的节点一起销毁：详情控件每次都是重新造的）
func _clear_children(box: Node) -> void:
	if box == null:
		return
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


## 列表里第一个模组的 id（没有就返回空）
func _first_mod_id() -> StringName:
	for mod_id in ModManager.all_mods:
		return mod_id
	return &""


## 控制台条目里的值被改了（如联机状态那一栏）：顺手把当前详情刷一遍
func _on_values_changed() -> void:
	if not visible or not _detail_refresh.is_valid():
		return
	_detail_refresh.call()
	## 刷新是照**条目自己**的 enabled 刷的，可能把刚才禁用的控件又开回来：补一次
	if is_instance_valid(_detail_control) and not ModManager.is_mod_enabled(_selected_mod_id):
		_set_controls_enabled(_detail_control, false)


func _registry() -> ConsoleRegistry:
	if Global == null:
		return null
	return Global.console_registry
#endregion
