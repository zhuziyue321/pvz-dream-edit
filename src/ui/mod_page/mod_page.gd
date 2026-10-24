extends CanvasLayer
class_name ModPage
## 模组页面：**左边一列模组，选中哪个就在右边显示它的详情**
##
## 本页面**不认识任何一个具体模组**（与控制台面板同一个道理）：
##   左列的列表 = `ModManager.all_mods`（注册表登记了哪些模组，页面上就有哪些）；
##   右侧的详情 = 名称 / 开关 / 说明这三样（页面自己造）
##              + 模组自己给的那一块（`ModBase.create_detail_control()`）
##              + 末尾一块「依赖的模组」（页面自己造，见 `_create_dependency_box()`）。
##
## 模组**没启用**时，它自己那一块**整块禁用**（见 `_set_controls_enabled()`）：
## 关着的模组下一局根本不装载，那块里的设置改了也不生效，索性让它点不动。
##
## 所以新增一个模组不用碰本页面：登记进 `ModManager.MOD_SCRIPT_PATHS` 就自动出现在列表里；
## 想让详情有内容，就在自己的 `ModBase` 子类里重写 `create_detail_control()`。
##
## 翻页结构（与控制台一致：场景里只有几个空容器，控件全是运行时造的）：
##   标题（顶部）  —— 「模组」
##   分类过滤栏    —— 左列底部一排按钮（全部 + 维度 C 四类），多选 OR 语义，点了就重排左列
##   左列          —— 每个模组一个按钮，点了就选中它（分类只在悬停提示与详情里显示）
##   右侧          —— 当前选中模组的详情（可滚动，含分类一行、末尾一块「依赖的模组」）
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
## 分类过滤栏里「全部」按钮的文字（点了 = 清掉所有分类过滤）
const FILTER_ALL_TEXT := "全部"
## 模组没启用时，它那一块设置上面写的一句提示
const DISABLED_HINT_TEXT := "（这个模组现在是关的：先按上面的开关启用它，下面这些设置才能改）"
## 禁用时整块压暗一点，让人一眼看出「现在改不了」
const DISABLED_MODULATE := Color(1, 1, 1, 0.6)
## 详情末尾「依赖的模组」那一块的标题
const DEPENDENCY_TITLE_TEXT := "依赖的模组"
## 依赖按钮前面的箭头（点了跳过去看那个模组）
const DEPENDENCY_JUMP_MARK := "→ "
## 没有依赖时，依赖块里写的一句话
const NO_DEPENDENCY_TEXT := "（这个模组不依赖其它模组）"
## 依赖块的名字：详情区里靠名字找它（不靠下标 —— 它前面有几行随模组而变）
const DEPENDENCY_BOX_NAME := "DependencyBox"

## 左右两个滚动区的垂直滚动条宽度（默认太窄不好拖）
const SCROLLBAR_WIDTH := 18.0
## 「模组自己那一块」挂刷新回调用的 meta 键 —— 与 `src/mods/mod_base.gd` 的
## `DETAIL_REFRESH_META` 必须一致。这里不能写 `DETAIL_REFRESH_META`：
## 模组（含 `ModBase`）不写 `class_name`（模组脚本可能在 `user://mods/` 下加载，那里
## `class_name` 不注册为全局类，`mod_base.gd` 照同一口径也不写），本体（本文件在 `res://`）
## 引用不到 —— 见 [模组机制](../../../docs/参考存档/模组机制.md) §二。
const DETAIL_REFRESH_META := &"mod_detail_refresh"


## 左列（场景里是个空 VBoxContainer，列表运行时往里塞按钮）
@onready var list_box: VBoxContainer = $OptionBG/ListScroll/List
## 右侧详情（同样是空 VBoxContainer，内容随选中的模组重建）
@onready var detail_box: VBoxContainer = $OptionBG/DetailScroll/Detail
## 左列底部分类过滤栏（场景里的空 HBoxContainer，按钮运行时生成）
@onready var filter_box: HBoxContainer = $OptionBG/FilterBox

## 当前选中的模组 id（空 = 还没选）
var _selected_mod_id: StringName = &""
## 当前激活的分类过滤（空 = 全部）；多选按 OR 语义（命中任意一个分类即显示）
var _active_categories: Array[StringName] = []
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
	## 分类过滤栏是固定结构（维度 C 的四类），打开页面时建一次即可
	_build_filter_bar()
	## 滚动条加宽（默认太窄不好拖）
	for scroll: ScrollContainer in [$OptionBG/ListScroll, $OptionBG/DetailScroll]:
		scroll.get_v_scroll_bar().custom_minimum_size.x = SCROLLBAR_WIDTH


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
## 列表按当前激活的分类过滤（OR 语义；没选任何分类 = 全显）
func _build_list() -> void:
	_clear_children(list_box)
	if ModManager.all_mods.is_empty():
		list_box.add_child(_create_label(EMPTY_LIST_TEXT))
		return
	for mod_id in ModManager.all_mods:
		var mod = ModManager.all_mods[mod_id]
		if mod == null:
			continue
		if not _match_filter(mod):
			continue
		list_box.add_child(_create_list_button(mod_id, mod))


## 分类过滤栏：一个「全部」按钮 + 维度 C 的四个分类开关（多选），点一下就重排列表
func _build_filter_bar() -> void:
	_clear_children(filter_box)
	var all_btn := Button.new()
	all_btn.text = FILTER_ALL_TEXT
	all_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	all_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ConsoleEntryControl.apply_button_style(all_btn)
	all_btn.pressed.connect(func() -> void:
		_active_categories.clear()
		_build_filter_bar()
		_build_list()
	)
	filter_box.add_child(all_btn)
	for category in ModCategory.ALL:
		var btn := Button.new()
		btn.text = ModCategory.name_of(category)
		btn.toggle_mode = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ConsoleEntryControl.apply_button_style(btn)
		btn.set_pressed_no_signal(_active_categories.has(category))
		btn.pressed.connect(func() -> void:
			if _active_categories.has(category):
				_active_categories.erase(category)
			else:
				_active_categories.append(category)
			_build_filter_bar()
			_build_list()
		)
		filter_box.add_child(btn)


## 命中当前过滤：没选分类 = 全过；否则模组分类与激活集合有交集即过
func _match_filter(mod) -> bool:
	if _active_categories.is_empty():
		return true
	var cats: Array = mod.get_mod_categories()
	for c in cats:
		if _active_categories.has(StringName(c)):
			return true
	return false


## 右侧详情：名称 → 开关 → 说明 → 模组自己给的那一块 → 依赖列表（恒在末尾）
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
	## 分类（维度 C）：多标签，用英文逗号隔开显示在详情里
	var cat_label := _category_label_text(mod)
	if not cat_label.is_empty():
		detail_box.add_child(_create_label("分类：" + cat_label))

	## `mod` 只能是 Variant（模组脚本的类本体引用不到，见上面的 meta 注释），
	## 所以这里要显式标类型，`:=` 推不出来
	var detail: Control = mod.create_detail_control()
	if detail == null:
		detail_box.add_child(_create_label(EMPTY_DETAIL_TEXT))
	else:
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

	## 依赖列表：页面自己造的一块，恒在详情末尾（本模组关着时它也照样能点 —— 那是导航）
	detail_box.add_child(_create_dependency_box(mod))
#endregion


#region 造控件
## 左列的一个按钮：点了就选中这个模组
func _create_list_button(mod_id: StringName, mod) -> Button:
	var button := Button.new()
	var state_tag := ENABLED_TAG if ModManager.is_mod_enabled(mod_id) else DISABLED_TAG
	button.text = (SELECTED_MARK if mod_id == _selected_mod_id else "") \
		+ mod.get_mod_name() + "（" + state_tag + "）"
	button.tooltip_text = mod.get_mod_description() + _category_tooltip(mod)
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


## 详情末尾那块「依赖的模组」：标题 + 每个依赖一个按钮（点了跳过去看那个模组）
##
## 依赖来自 `ModManager.get_mod_dependencies()`（管理器已剔掉未登记的 id）；
## **不**跟着「模组没启用」一起禁用 —— 它是页面自己的导航，与模组开不开无关。
func _create_dependency_box(mod) -> VBoxContainer:
	var box := VBoxContainer.new()
	## 起个名：探针（以及将来说不定别的代码）靠名字找它，不靠下标
	box.name = DEPENDENCY_BOX_NAME
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _create_label(DEPENDENCY_TITLE_TEXT + "：")
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var deps := ModManager.get_mod_dependencies(mod.get_mod_id())
	if deps.is_empty():
		box.add_child(_create_label(NO_DEPENDENCY_TEXT))
		return box
	for dep_id in deps:
		box.add_child(_create_dependency_button(dep_id))
	return box


## 一个依赖的按钮：名字 + 开关状态；点了选中那个模组（分类过滤一并清掉，
## 不然依赖正被过滤挡着时跳过去、列表里却看不见它）
func _create_dependency_button(dep_id: StringName) -> Button:
	var dep_mod = ModManager.get_mod(dep_id)
	var button := Button.new()
	if dep_mod == null:
		## `get_mod_dependencies()` 已经剔掉未登记的 id，正常走不到这里；兜底别炸
		button.text = DEPENDENCY_JUMP_MARK + str(dep_id) + "（模组不存在）"
		button.disabled = true
		return button
	var state_tag := ENABLED_TAG if ModManager.is_mod_enabled(dep_id) else DISABLED_TAG
	button.text = DEPENDENCY_JUMP_MARK + dep_mod.get_mod_name() + "（" + state_tag + "）"
	button.tooltip_text = dep_mod.get_mod_description()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	## 不拉满整行：跟详情里那个开关按钮一样靠左放
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ConsoleEntryControl.apply_button_style(button)
	button.pressed.connect(func() -> void:
		_selected_mod_id = dep_id
		_active_categories.clear()
		_build_filter_bar()
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


## 模组分类的中文显示名列表（多标签，按 ModCategory 顺序）
func _category_names(mod) -> Array[String]:
	var out: Array[String] = []
	var cats: Array = mod.get_mod_categories()
	for c in cats:
		out.append(ModCategory.name_of(StringName(c)))
	return out


## 详情里用的分类长文本（「新增工具」这种，逗号隔开；没有分类返回空串）
func _category_label_text(mod) -> String:
	return "，".join(_category_names(mod))


## 列表按钮 tooltip 用的分类一行（没有分类返回空串）
func _category_tooltip(mod) -> String:
	var names := _category_names(mod)
	if names.is_empty():
		return ""
	return "\n分类：" + "，".join(names)
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
