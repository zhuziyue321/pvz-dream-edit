extends Node
class_name ConsoleRegistry
## 控制台条目注册表（`Global.console_registry`）：控制台面板上有什么，全由这里决定
##
## 为什么要这一层：面板原本把 11 个开关**硬编码**在场景里（11 个 CheckBox 节点 + 11 个
## `_on_check_box_N_toggled`），加一个开关要同时改场景、改脚本、改 ConfigService 三处，
## 模组更是完全没有地方挂自己的调试开关。
## 现在：**条目是数据**，谁都能登记 —— 本体的在 `ConsoleBuiltinEntries`，
## 模组的在 `ModBase.register_console_entries()`，面板只负责把它们变成控件。
##
## 生命周期：
##   `_ready()`                 —— 登记本体内置条目（模组条目由 ModManager 在它自己的 _ready 里登记）
##   `register_entry()`         —— 谁都能调；同 id 再登记 = 覆盖
##   `unregister_source()`      —— 按登记方整组撤销（模组被关掉时走这个）
##
## 面板的刷新：注册表变了会发 `entries_changed`；面板打开时也会整体重建一次，
## 所以「运行期才登记的条目」不用关心时序。
##
## 关联：[控制台](../../../docs/参考存档/控制台.md) ｜ ConsoleEntry ｜ ConsoleBuiltinEntries ｜ CanvasLayerConsole


## 条目变化时发出（面板会整体重建）
signal entries_changed()
## 条目里的值在外面被改了（面板会把值重读一遍，不重建控件）
##
## 谁用：`Readout` 这种「值随时在变」的条目，以及 Toggle / Slider 被代码改了值要同步。
signal values_changed()


## 没写分组的条目落到这一组
const CATEGORY_DEFAULT := "通用"
## ModManager 给每个模组登记的开关放在这一组
const CATEGORY_MOD := "模组"
## 本体内置条目的登记方标记
const SOURCE_BUILTIN := &"builtin"


## id → 条目（字典保持插入顺序，分组顺序 = 第一次出现的顺序）
var _entries: Dictionary[StringName, ConsoleEntry] = {}


func _ready() -> void:
	ConsoleBuiltinEntries.register_all(self)


#region 登记 / 撤销
## 登记一条（同 id 再登记 = 覆盖上一条，日志里能看到）
## [param default_source] 条目自己没写 `source` 时用这个当登记方（ModManager 传模组 id）
func register_entry(entry: ConsoleEntry, default_source: StringName = &"") -> void:
	if entry == null or entry.id == &"":
		Log.error("ConsoleRegistry: 登记了一条没有 id 的控制台条目，已忽略")
		return
	if entry.source == &"":
		entry.source = default_source
	if entry.category.is_empty():
		entry.category = CATEGORY_DEFAULT
	if _entries.has(entry.id):
		Log.debug("ConsoleRegistry: 控制台条目 %s 被覆盖" % str(entry.id))
	_entries[entry.id] = entry
	entries_changed.emit()


## 批量登记
func register_entries(entries: Array, default_source: StringName = &"") -> void:
	for item in entries:
		if item is ConsoleEntry:
			register_entry(item as ConsoleEntry, default_source)


## 按 id 撤销一条
func unregister_entry(entry_id: StringName) -> void:
	if not _entries.erase(entry_id):
		return
	entries_changed.emit()


## 按登记方整组撤销（模组被关掉时用它把自己加的条目一次清干净）
func unregister_source(entry_source: StringName) -> void:
	var removed := 0
	for entry_id in _entries.keys():
		if _entries[entry_id].source == entry_source:
			_entries.erase(entry_id)
			removed += 1
	if removed > 0:
		entries_changed.emit()


## 条目里的值变了（勾选项被代码改了 / `Readout` 的文本刷新了）：让面板重读一遍
##
## 谁调：本体或模组在自己内部状态变了的那个时刻调一下（如联机会话状态变化时）。
## 面板不一定开着 —— 关着就什么都不做，下次打开本来就会重建。
func request_refresh() -> void:
	values_changed.emit()


## 清空（仅供测试 / 调试）
func clear() -> void:
	if _entries.is_empty():
		return
	_entries.clear()
	entries_changed.emit()
#endregion


#region 查询
## 全部分组名（按第一次出现的顺序）
func get_categories() -> Array[String]:
	var result: Array[String] = []
	for entry in _entries.values():
		if not result.has(entry.category):
			result.append(entry.category)
	return result


## 某一组的条目（同组按 order → id 排序）；不传 = 全部条目
func get_entries(category: String = "") -> Array[ConsoleEntry]:
	var result: Array[ConsoleEntry] = []
	for entry in _entries.values():
		if not category.is_empty() and entry.category != category:
			continue
		result.append(entry)
	result.sort_custom(_sort_by_order)
	return result


## 按 id 取一条（没有返回 null）
func get_entry(entry_id: StringName) -> ConsoleEntry:
	return _entries.get(entry_id)


## 已登记的条目数（日志 / 探针用）
func get_entry_count() -> int:
	return _entries.size()
#endregion


## 排序：order 小的在前，同序按 id 字典序（保证每次打开面板顺序一致）
func _sort_by_order(a: ConsoleEntry, b: ConsoleEntry) -> bool:
	if a.order != b.order:
		return a.order < b.order
	return str(a.id) < str(b.id)
