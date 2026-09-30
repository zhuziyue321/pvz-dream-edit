extends MainLoop
## 项目自检工具（不加载 autoload，不会触碰存档）
## 用法: godot --headless --path <项目目录> --script res://test/project_checker.gd
## 作用: 扫描 .gd / .tscn / .tres / .gdshader，逐个加载并报告：
##       资源加载失败、.gd 缺少同名 .uid。
##       注意：--script 模式不加载 autoload，因此这里不校验 .gd 的编译；
##       脚本级错误请用编辑器扫描: godot --headless --editor --quit

const SCAN_DIRS: Array[String] = [
	"res://scripts",
	"res://scenes",
	"res://resources",
	"res://animation",
	"res://data",
	"res://shaders",
	"res://shader_material",
	"res://test",
	"res://level_game_para",
]

const SCAN_EXTS: Array[String] = ["gd", "tscn", "tres", "gdshader", "gdshaderinc"]

## 跳过自身，避免递归加载
const SELF := "res://test/project_checker.gd"

var _checked := 0
var _failed_load: Array[String] = []
var _missing_uid: Array[String] = []


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	print("[项目自检] 开始扫描 ...")
	for dir in SCAN_DIRS:
		_scan_dir(dir)
	print("")
	print("[项目自检] 已检查文件: %d" % _checked)
	print("[项目自检] 资源加载失败: %d" % _failed_load.size())
	for p in _failed_load:
		print("    [加载失败] " + p)
	print("[项目自检] 缺少 .uid: %d" % _missing_uid.size())
	for p in _missing_uid:
		print("    [缺少 .uid] " + p)
	print("[项目自检] 用时 %d ms" % (Time.get_ticks_msec() - t0))
	var ok := _failed_load.is_empty() and _missing_uid.is_empty()
	print("[项目自检] 结果: " + ("通过" if ok else "存在问题"))
	## 机器可读汇总行，供 test/verify.ps1 解析。
	## 必须保持纯 ASCII：PowerShell 5.1 按 ANSI 读取脚本，脚本里的中文正则不可靠。
	print("[SELFCHECK] checked=%d loadFailures=%d missingUid=%d result=%s" % [
		_checked, _failed_load.size(), _missing_uid.size(), "PASS" if ok else "FAIL"
	])


func _process(_delta: float) -> bool:
	return true


func _scan_dir(path: String) -> void:
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
			if entry != "addons":
				_scan_dir(full)
		else:
			_check_file(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _check_file(path: String) -> void:
	var ext := path.get_extension()
	if ext not in SCAN_EXTS or path == SELF:
		return
	_checked += 1
	if ext == "gd":
		if not FileAccess.file_exists(path + ".uid"):
			_missing_uid.append(path)
		return
	var res := ResourceLoader.load(path)
	if res == null:
		_failed_load.append(path)
