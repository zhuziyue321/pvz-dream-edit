extends RefCounted
class_name AutopilotReport
## 报告读写：正文缓冲在内存，每次 flush 整体落盘，并原样打到 stdout。
##
## 抽出来的理由：autopilot 与 DebugChannel 都要写报告，以前两边各写一份
## _line / _flush / _open_report，落盘策略也各写一遍（一个写 res://、一个写 user://），
## 改一处必然漏另一处。现在「报告写哪、怎么写」只有本文件知道。
##
## ⚠️ 裸 print 的登记例外（项目规范 S-02）：
##   报告正文要原样落进 stdout 供人工/脚本粘贴，不能带 Log 的级别前缀，
##   也不能被 Log.level 截断。除本文件的 line() 与 logger.gd 外，
##   项目内不得再出现裸 print —— autopilot 系列的控制台消息一律走 Log.info。

## 注入模式报告写不动时的回退目录（导出后 res:// 只读）
var _fallback_dir := "user://autopilot_reports"
## 报告路径；为空表示还没定
var _path := ""
var _lines: Array[String] = []


## 注入模式：报告写到 res:// 固定路径（我能直接读到），写不动时回退 user://
func setup_inject(res_path: String, fallback_dir: String) -> void:
	_path = res_path
	_fallback_dir = fallback_dir
	_ensure_dir(fallback_dir)


## 命令行 / 无头模式：报告写到 user://<dir>/<file_name>
func setup_user(dir: String, file_name: String) -> void:
	_fallback_dir = dir
	_path = dir.path_join(file_name)
	_ensure_dir(dir)


func path() -> String:
	return _path


## 报告的操作系统绝对路径（给用户看 / 给脚本解析）
func abs_path() -> String:
	if _path == "":
		return "(未生成)"
	return ProjectSettings.globalize_path(_path)


## 写一行：进缓冲，同时原样打到 stdout
func line(text: String) -> void:
	_lines.append(text)
	print(text)


## 一次写多行（配合 AutopilotState 这类「一次返回一组行」的采集器）
func write_lines(items: Array[String]) -> void:
	for l in items:
		line(l)


## 整体重写一次报告文件。
## 全量重写而不是追加：报告中途可能被看门狗截断，全量写能保证文件永远是一份完整快照。
func flush() -> void:
	if _path == "":
		return
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null and _path.begins_with("res://"):
		## 导出后的游戏 res:// 只读，退回 user://
		_ensure_dir(_fallback_dir)
		_path = _fallback_dir.path_join("inject_report.txt")
		f = FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		return
	for l in _lines:
		f.store_line(l)
	f.close()


func _ensure_dir(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
