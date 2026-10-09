extends RefCounted
class_name ConsoleEntry
## 控制台条目：一条 = 控制台面板上的一个控件
##
## 面板（`CanvasLayerConsole`）**不认识任何具体选项** —— 它只按 `kind` 把这里的数据变成控件，
## 所有条目都从 `ConsoleRegistry` 来。加一项 = 登记一条，不改面板、不改场景。
##
## 五种形态（`E_Kind`）：
##   Toggle  —— 勾选框：`create_toggle()` + `bind()` / `bind_config()`
##   Button  —— 按钮：点一下跑一次 `action`，没有状态
##   Slider  —— 数值滑条：`create_slider()` + `bind()` / `bind_config()`
##   Text    —— 文本输入框：`create_text()` + `bind()` / `bind_config()`（回车或失焦时写回）
##   Readout —— 只读文本行：`create_readout()` + `bind(getter, setter)`（值随时在变，如联机状态）
##
## 模组里最典型的用法（写在 `ModBase.register_console_entries()` 里）：
##   registry.register_entry(ConsoleEntry.create_toggle(&"glove_free_move", "手套无视冷却")
##       .set_category("手套")
##       .set_tooltip("调试用：搬运植物不再受冷却限制")
##       .bind_config("glove.free_move", false))
##
## `bind_config()` 的值落在 `ConfigService` 的通用键值区（config.ini 的 `[console]` 段），
## 关控制台时跟其它设置一起存盘 —— **加一个持久化开关不需要改 `ConfigService`**。
##
## 关联：[控制台](../../../docs/参考存档/控制台.md) ｜ ConsoleRegistry ｜ CanvasLayerConsole ｜ ModBase


## 条目在面板上变成什么控件
enum E_Kind {
	Toggle,	## 勾选框（有开关状态）
	Button,	## 按钮（点一下执行一次 action，无状态）
	Slider,	## 数值滑条（min_value ~ max_value，步长 step）
	Text,	## 文本输入框（一行字符串，回车 / 失焦时写回）
	Readout,	## 只读文本行（一行字符串，只显示不编辑）
}


## 条目唯一 id（同 id 再登记 = 覆盖上一条）
var id: StringName
## 控件形态
var kind: int = E_Kind.Toggle
## 控件上显示的文字
var text: String = ""
## 悬停提示（tooltip）
var tooltip: String = ""
## Text 专用：输入框里的浅色提示文字（没输入时显示）
var placeholder: String = ""
## 分组名（面板按组加小标题；空 = 默认组）
var category: String = ""
## 组内排序（小的在前；同序按 id 字典序）
var order: int = 0
## 登记方（模组 id / `&"builtin"`），用于整组撤销
var source: StringName = &""
## 没有 getter 时的取值（也是 `bind_config()` 的默认值）
var default_value: Variant = false

## Slider 专用：最小值 / 最大值 / 步长
var min_value: float = 0.0
var max_value: float = 100.0
var step: float = 1.0

## Toggle / Slider 的读值回调：`func() -> Variant`
var value_getter: Callable
## Toggle / Slider 的写值回调：`func(value: Variant) -> void`
var value_setter: Callable
## Button 的回调：`func() -> void`
var action: Callable
## 可选的「该项当前是否可用」回调：`func() -> bool`，返回 false 时控件置灰
var enabled_getter: Callable


#region 工厂方法
## 勾选框条目
static func create_toggle(entry_id: StringName, entry_text: String) -> ConsoleEntry:
	var entry := ConsoleEntry.new()
	entry.id = entry_id
	entry.text = entry_text
	entry.kind = E_Kind.Toggle
	return entry


## 按钮条目（[param press_action] 被点一次跑一次）
static func create_button(entry_id: StringName, entry_text: String, press_action: Callable) -> ConsoleEntry:
	var entry := ConsoleEntry.new()
	entry.id = entry_id
	entry.text = entry_text
	entry.kind = E_Kind.Button
	entry.action = press_action
	return entry


## 数值滑条条目
static func create_slider(
	entry_id: StringName,
	entry_text: String,
	value_min: float = 0.0,
	value_max: float = 100.0,
	value_step: float = 1.0
) -> ConsoleEntry:
	var entry := ConsoleEntry.new()
	entry.id = entry_id
	entry.text = entry_text
	entry.kind = E_Kind.Slider
	entry.min_value = value_min
	entry.max_value = value_max
	entry.step = value_step
	entry.default_value = value_min
	return entry


## 文本输入框条目（[param value_default] 没绑取值回调时的文本）
static func create_text(entry_id: StringName, entry_text: String, value_default: String = "") -> ConsoleEntry:
	var entry := ConsoleEntry.new()
	entry.id = entry_id
	entry.text = entry_text
	entry.kind = E_Kind.Text
	entry.default_value = value_default
	return entry


## 只读文本行（[param getter] `func() -> String`，每刷新一次读一次）
##
## 与 Toggle / Slider 不同：它没有 setter —— 给人的就是这个值，改不了。
## 值变了调 `ConsoleRegistry.request_refresh()`，面板会把最新文本读回去。
static func create_readout(entry_id: StringName, entry_text: String, getter: Callable = Callable()) -> ConsoleEntry:
	var entry := ConsoleEntry.new()
	entry.id = entry_id
	entry.text = entry_text
	entry.kind = E_Kind.Readout
	entry.value_getter = getter
	entry.default_value = ""
	return entry
#endregion


#region 链式配置（都返回自身，方便一行写完）
func set_tooltip(value: String) -> ConsoleEntry:
	tooltip = value
	return self


## Text 专用：输入框里的浅色提示文字（如 "127.0.0.1:8912"）
func set_placeholder(value: String) -> ConsoleEntry:
	placeholder = value
	return self


func set_category(value: String) -> ConsoleEntry:
	category = value
	return self


func set_order(value: int) -> ConsoleEntry:
	order = value
	return self


func set_source(value: StringName) -> ConsoleEntry:
	source = value
	return self


## 直接绑一对读写回调（想接到自己模块的字段 / 单例上时用这个）
func bind(getter: Callable, setter: Callable) -> ConsoleEntry:
	value_getter = getter
	value_setter = setter
	return self


## 绑到 `ConfigService` 的控制台通用键值区：读写 + 持久化一条龙，不用改 `ConfigService`
## [param key] 建议带模组前缀（如 `"glove.free_move"`），避免与其它模组撞键
## [param value_default] 首次使用时的默认值
func bind_config(key: String, value_default: Variant = false) -> ConsoleEntry:
	default_value = value_default
	value_getter = func() -> Variant:
		return Global.config_service.get_console_value(key, value_default)
	value_setter = func(value: Variant) -> void:
		Global.config_service.set_console_value(key, value)
	return self


## 绑「该项当前是否可用」：返回 false 时面板上这个控件置灰
func set_enabled_getter(getter: Callable) -> ConsoleEntry:
	enabled_getter = getter
	return self
#endregion


#region 取值 / 执行
## 当前值（Toggle 返回 bool；没绑 getter 时返回 `default_value`）
func get_value() -> Variant:
	if value_getter.is_valid():
		return value_getter.call()
	return default_value


## 写入新值（面板上被改动时调用；没绑 setter 时静默忽略）
func set_value(value: Variant) -> void:
	if value_setter.is_valid():
		value_setter.call(value)


## 当前是否可用（`enabled_getter` 没绑时一律可用）
func is_enabled() -> bool:
	if enabled_getter.is_valid():
		return bool(enabled_getter.call())
	return true


## 执行一次按钮动作
func run_action() -> void:
	if action.is_valid():
		action.call()
#endregion
