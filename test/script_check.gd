extends Node
## 脚本编译检查（作为场景运行，因此 autoload 存在，Global/AllCards 等能正确解析）
## 用法: godot --headless --path <项目> res://test/script_check.tscn
##
## 为什么必须有它：无头编辑器扫描（--editor --quit）只加载被场景引用的脚本，
## 像 test/autopilot.gd 这种只被 load("...") 字符串引用的脚本不会被编译，
## 里面的语法错误会静默漏过。这里显式 reload() 每一个 .gd。

const SCAN_DIRS: Array[String] = ["res://scripts", "res://scenes", "res://resources", "res://test"]

var _checked := 0
var _failed: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	for d in SCAN_DIRS:
		_scan(d)
	print("")
	print("[脚本检查] 已编译: %d  失败: %d" % [_checked, _failed.size()])
	for f in _failed:
		print("    BUILD-FAIL " + f)
	var ok := _failed.is_empty()
	print("[SCRIPTCHECK] checked=%d failed=%d result=%s" % [_checked, _failed.size(), "PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)


func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan(full)
		elif full.get_extension() == "gd":
			_check(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _check(path: String) -> void:
	if path == "res://test/script_check.gd":
		return
	var s: GDScript = load(path)
	if s == null:
		_checked += 1
		_failed.append(path + "  (load 返回 null)")
		return
	## 用 can_instantiate()：编译失败的脚本为 false。
	## 注意不要用 reload()，它对已被实例化的脚本会直接拒绝重载，产生大量假阳性。
	_checked += 1
	if not s.can_instantiate():
		_failed.append(path)
