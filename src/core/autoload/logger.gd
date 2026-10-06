extends Node
## 统一日志工具（自动加载名: Log）
##
## 项目里原先散落着大量 Log.debug()，发布版本无法关闭。统一走这里：
##     Log.debug("xxx")      调试信息，发布版本默认不输出
##     Log.info("xxx")       常规信息
##     Log.warn("xxx")       警告
##     Log.error("xxx")      错误（走 stderr）
##
## 与 print 一样支持多参数拼接：Log.debug("a", value) → "a" + str(value)
## 通过 Log.level 控制最低输出级别，发布版本默认 INFO，编辑器内默认 DEBUG。

enum Level {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
	OFF = 4,
}

## 低于该级别的日志不输出
var level: int = Level.DEBUG if OS.is_debug_build() else Level.INFO
## 输出是否带毫秒时间戳
var with_timestamp: bool = false
## 是否带级别前缀（[DEBUG]/[INFO]...）
var with_level_prefix: bool = false


func debug(msg: Variant, arg1: Variant = null, arg2: Variant = null, arg3: Variant = null, arg4: Variant = null) -> void:
	if level > Level.DEBUG:
		return
	_write(Level.DEBUG, "DEBUG", _join(msg, arg1, arg2, arg3, arg4))


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


func _write(msg_level: int, level_name: String, text: String) -> void:
	var prefix := ""
	if with_timestamp:
		prefix += "[%d] " % Time.get_ticks_msec()
	if with_level_prefix:
		prefix += "[%s] " % level_name
	var line := prefix + text
	## 这里必须用引擎原生的 print/printerr，不能再走 Log.*，
	## 否则 _write → debug() → _write 无限递归爆栈。
	## 本文件是《项目规范》S-02 允许的裸 print 例外之一（另一个是
	## res://src/core/autoload/debug_channel.gd 的 _line()）。
	if msg_level >= Level.ERROR:
		printerr(line)
	else:
		print(line)
