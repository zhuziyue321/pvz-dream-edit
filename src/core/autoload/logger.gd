extends Node
## 统一日志工具（自动加载名: Log）
##
## 2026-10-12 起：**不再有调试输出**，只报告大事件 —— 原来散落各处的
## `Log.debug()` 已全部删除，debug 级别一并撤掉。现在只剩三级：
##     Log.info("xxx")       大事件（关卡开始 / 结束、波次、判胜判负、通关解锁…）
##     Log.warn("xxx")       警告
##     Log.error("xxx")      错误（走 stderr）
##
## 与 print 一样支持多参数拼接：Log.info("a", value) → "a" + str(value)
## 通过 Log.level 控制最低输出级别，默认 INFO（静音设 Level.OFF）。
##
## 另外保留**最近若干行**的内存副本（`get_recent_lines()`），供调试模组的「日志」页读取 ——
## 引擎的文件日志在 `user://logs/` 下、运行中不方便翻，面板里能直接看到最近发生了什么。

## 内存里最多留多少行（超出从最旧的开始丢）
const MAX_RECENT_LINES := 200

enum Level {
	INFO = 0,
	WARN = 1,
	ERROR = 2,
	OFF = 3,
}

## 低于该级别的日志不输出
var level: int = Level.INFO
## 输出是否带毫秒时间戳
var with_timestamp: bool = false
## 是否带级别前缀（[INFO]/[WARN]...）
var with_level_prefix: bool = false
## 是否把最近日志留在内存里（调试窗口的「日志」页读它；关掉可以省这点内存）
var store_recent: bool = true
## 每追加一行 +1：外部靠它判断「有没有新日志」，避免每帧重新拼整段文本
var recent_version: int = 0

## 最近日志行（最旧在前，最多 `MAX_RECENT_LINES` 行）
var _recent_lines: Array[String] = []


func info(msg: Variant, arg1: Variant = null, arg2: Variant = null, arg3: Variant = null, arg4: Variant = null) -> void:
	if level > Level.INFO:
		return
	_write(Level.INFO, "INFO", _join(msg, arg1, arg2, arg3, arg4))


func warn(msg: Variant, arg1: Variant = null, arg2: Variant = null, arg3: Variant = null, arg4: Variant = null) -> void:
	if level > Level.WARN:
		return
	_write(Level.WARN, "WARN", _join(msg, arg1, arg2, arg3, arg4))


func error(msg: Variant, arg1: Variant = null, arg2: Variant = null, arg3: Variant = null, arg4: Variant = null) -> void:
	if level > Level.ERROR:
		return
	_write(Level.ERROR, "ERROR", _join(msg, arg1, arg2, arg3, arg4))


## 与 print 一致：参数之间不加分隔符，直接拼接
static func _join(msg: Variant, arg1: Variant, arg2: Variant, arg3: Variant, arg4: Variant) -> String:
	var text := str(msg)
	if arg1 != null:
		text += str(arg1)
	if arg2 != null:
		text += str(arg2)
	if arg3 != null:
		text += str(arg3)
	if arg4 != null:
		text += str(arg4)
	return text


#region 最近日志（调试窗口用）
## 最近 [param count] 行（最旧在前；`count` 超过上限时按上限给）
func get_recent_lines(count: int = MAX_RECENT_LINES) -> Array[String]:
	if count <= 0 or _recent_lines.is_empty():
		return []
	var start := maxi(_recent_lines.size() - count, 0)
	var result: Array[String] = []
	for i in range(start, _recent_lines.size()):
		result.append(_recent_lines[i])
	return result


## 最近日志拼成一段文本（调试窗口「日志」页直接用）
func get_recent_text() -> String:
	return "\n".join(PackedStringArray(_recent_lines))


## 清空内存副本（不影响已经 print 出去的内容与引擎的日志文件）
func clear_recent() -> void:
	_recent_lines.clear()
	recent_version += 1


## 追加一行到内存副本；`WARN` / `ERROR` 行带上级别前缀，方便在面板里一眼区分
func _store_recent(msg_level: int, level_name: String, text: String) -> void:
	if not store_recent:
		return
	var line := text
	if msg_level >= Level.WARN:
		line = "[%s] %s" % [level_name, text]
	_recent_lines.append(line)
	if _recent_lines.size() > MAX_RECENT_LINES:
		_recent_lines.remove_at(0)
	recent_version += 1
#endregion


func _write(msg_level: int, level_name: String, text: String) -> void:
	_store_recent(msg_level, level_name, text)
	var prefix := ""
	if with_timestamp:
		prefix += "[%d] " % Time.get_ticks_msec()
	if with_level_prefix:
		prefix += "[%s] " % level_name
	var line := prefix + text
	## 这里必须用引擎原生的 print/printerr，不能再走 Log.*，
	## 否则 _write → info() → _write 无限递归爆栈。
	## 本文件是《项目规范》S-02 允许的裸 print 例外之一（另一个是
	## res://src/core/autoload/debug_channel.gd 的 _line()）。
	if msg_level >= Level.ERROR:
		printerr(line)
	else:
		print(line)
