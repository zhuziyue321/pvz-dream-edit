extends MainLoop
## 规范静态检查（不加载 autoload，不会触碰存档）
## 用法: godot --headless --path <项目目录> --script res://test/standard_check.gd
##
## 作用: 把《docs/项目规范.md》里**可静态判定**的红线变成会失败的检查，
##       避免规范只停留在文档里靠人记。
##
## 已验证的红线（对应项目规范 §8）:
##   S-02  禁止裸 print() / printerr()（logger.gd 与 debug_channel.gd 的 _line 为登记例外）
##   K-04  角色子类禁止重写 _ready()，初始化放 ready_norm() / ready_show() / ready_garden()
##   K-02  组件脚本必须有 XxxComponent 形式的 class_name
##
## 设计约束（重要）:
##   1. 只有 [STDCHECK] 汇总行必须纯 ASCII —— PowerShell 5.1 按 ANSI 读取无 BOM 的
##      脚本，中文正则不可靠，所以 verify.ps1 只解析这一行 ASCII 标记。
##      本文件自身的违规明细行故意用中文，方便直接定位。
##   2. 只做"能证明的判定"。放宽的检查（可能误报）单独归类为 WARN，
##      **不计入 FAIL**，避免为了绿灯而纵容误报。
##
## 扩展方式: 在 _build_checks() 里加一条 CHECKS 条目即可，无需改别处。

const SCAN_ROOT := "res://scripts"
const SCRIPT_EXTS: Array[String] = ["gd"]

## 裸 print 的登记例外（项目规范 S-02）。
## key = 脚本路径，value = 允许出现的函数名（空数组表示该文件整体豁免）。
const PRINT_EXCEPTIONS := {
	"res://scripts/autoload/util/logger.gd": [],
	"res://scripts/autoload/debug_channel.gd": ["_line"],
}

## 组件类名的登记例外（项目规范 K-02）。
## 这些是组件目录里的辅助节点脚本，本身不是组件，因此不遵循组件命名。
const CLASS_NAME_EXCEPTIONS: Array[String] = [
	"res://scripts/character/components/body_character.gd",
	"res://scripts/character/components/drop_body/zombie_drop_base.gd",
	"res://scripts/character/components/drop_body/zombie_arm1_drop.gd",
	"res://scripts/character/components/drop_body/zombie_hand_drop.gd",
	"res://scripts/character/components/drop_body/zombie_head_drop.gd",
	"res://scripts/character/components/zombie_009_jackson/zombie_jackson_manager.gd",
	"res://scripts/character/components/zombie_009_jackson/zombie_jackson_state_machine.gd",
	"res://scripts/character/components/zombie_death_bomb/zombie_death_bomb.gd",
	"res://scripts/character/components/zombie_013_zamboni/zombie_013_death_bomb.gd",
	"res://scripts/character/components/p_048_cob_cannon_target.gd",
	"res://scripts/character/components/iron_node/iron_node.gd",
	"res://scripts/character/components/iron_node/iron_node_armor.gd",
]

var _files: Array[String] = []
var _text: Dictionary[String, String] = {}
var _class_of: Dictionary[String, String] = {}
var _parent_of: Dictionary[String, String] = {}
var _path_of_class: Dictionary[String, String] = {}
var _children_of: Dictionary[String, Array] = {}

var _passed: Array[String] = []
var _failed: Array[String] = []
var _warned: Array[String] = []


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	print("[规范检查] 开始扫描 ...")
	_scan_dir(SCAN_ROOT)
	_build_class_graph()
	_classify()
	for check: Dictionary in _build_checks():
		_run_check(check)
	print("")
	print("[规范检查] 已检查脚本: %d" % _files.size())
	print("[规范检查] PASS: %d  FAIL: %d  WARN: %d" % [_passed.size(), _failed.size(), _warned.size()])
	for name: String in _passed:
		print("    [PASS] " + name)
	for name: String in _warned:
		print("    [WARN] " + name)
	for name: String in _failed:
		print("    [FAIL] " + name)
	print("[规范检查] 用时 %d ms" % (Time.get_ticks_msec() - t0))
	print("[规范检查] 结果: " + ("通过" if _failed.is_empty() else "存在违规"))
	## 机器可读汇总行，供 test/verify.ps1 解析。必须纯 ASCII。
	print("[STDCHECK] scripts=%d checks=%d failed=%d warned=%d result=%s" % [
		_files.size(), _passed.size() + _failed.size() + _warned.size(),
		_failed.size(), _warned.size(), "PASS" if _failed.is_empty() else "FAIL"
	])


func _process(_delta: float) -> bool:
	return true


#region 扫描与建图

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
			## addons/ 是第三方插件，不参与本规范
			if entry != "addons":
				_scan_dir(full)
		elif entry.get_extension() in SCRIPT_EXTS:
			_files.append(full)
			_text[full] = _strip_comments(_read(full))
		entry = dir.get_next()
	dir.list_dir_end()


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var out := f.get_as_text()
	f.close()
	return out


## 去掉注释，保留字符串（用 \u0001 占位）与换行。
## 这样后面的正则不会命中注释里的 print / _ready / class_name 示例。
func _strip_comments(src: String) -> String:
	var out := ""
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == "\"":
			var triple := src.substr(i, 3) == "\"\"\""
			var quote := "\"\"\"" if triple else "\""
			var j := i + quote.length()
			while j < n:
				if src[j] == "\\":
					j += 2
					continue
				if src.substr(j, quote.length()) == quote:
					j += quote.length()
					break
				j += 1
			out += "\u0001"
			i = j
		elif c == "#":
			while i < n and src[i] != "\n":
				i += 1
		else:
			out += c
			i += 1
	return out


## 建立 class_name / extends 关系图（ext_resource 的路径形式不参与解析）
func _build_class_graph() -> void:
	for path: String in _files:
		var text := _text[path]
		for line: String in text.split("\n"):
			var s := line.strip_edges()
			if s.begins_with("@") or s.begins_with("class_name ") or s.begins_with("extends "):
				var class_name_value := _match_one(s, "^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
				var parent := _match_one(s, "^extends\\s+([A-Za-z_][A-Za-z0-9_]*)")
				if class_name_value != "":
					_class_of[path] = class_name_value
					_path_of_class[class_name_value] = path
				if parent != "":
					_parent_of[path] = parent
	for path: String in _parent_of:
		var parent := _parent_of[path]
		var parent_path: String = _path_of_class.get(parent, "")
		if parent_path != "":
			if not _children_of.has(parent_path):
				_children_of[parent_path] = []
			_children_of[parent_path].append(path)


func _classify() -> void:
	pass


func _run_check(check: Dictionary) -> void:
	var name: String = check["name"]
	var severity: String = check["severity"]
	var fn: Callable = check["fn"]
	var rows: Array = fn.call()
	if rows.is_empty():
		_passed.append("%s: 0 violation" % name)
		return
	var target := _failed if severity == "FAIL" else _warned
	target.append("%s: %d violation" % [name, rows.size()])
	for row: String in rows:
		print("    [%s] %s -> %s" % [severity, name, row])


func _build_checks() -> Array[Dictionary]:
	return [
		{"name": "S-02 no-raw-print", "severity": "FAIL", "fn": _check_raw_print},
		{"name": "K-04 no-_ready-override", "severity": "FAIL", "fn": _check_ready_override},
		{"name": "K-02 component-class-name", "severity": "FAIL", "fn": _check_component_class_name},
		{"name": "K-03 get_parent-in-component", "severity": "WARN", "fn": _check_get_parent},
	]

#endregion


#region 检查项

## S-02：除 logger.gd 与 debug_channel.gd::_line() 外，脚本里不得出现裸 print/printerr
func _check_raw_print() -> Array[String]:
	var rows: Array[String] = []
	for path: String in _files:
		if _is_exempt_file(path, PRINT_EXCEPTIONS):
			continue
		var lines := _text[path].split("\n")
		var func_name := ""
		for idx in lines.size():
			var line := lines[idx]
			var fn := _match_one(line, "^func\\s+([A-Za-z_][A-Za-z0-9_]*)")
			if fn != "":
				func_name = fn
			var printed := _match_one(line, "\\b(print|printerr)\\s*\\(")
			if printed == "":
				continue
			var allowed: Array = PRINT_EXCEPTIONS.get(path, [])
			if allowed.has(func_name):
				continue
			rows.append("%s:%d %s()%s" % [path, idx + 1, printed, _in_func(func_name)])
	return rows


## K-04：继承角色基类的脚本不得定义 _ready()
func _check_ready_override() -> Array[String]:
	var rows: Array[String] = []
	var character_bases := ["Character000Base", "Plant000Base", "Plant000DownBase", "Zombie000Base"]
	for path: String in _files:
		if not _descends_from_any(path, character_bases):
			continue
		var lines := _text[path].split("\n")
		for idx in lines.size():
			if _match_one(lines[idx], "^\\s*(static\\s+)?func\\s+_ready\\s*\\(") != "":
				rows.append("%s:%d %s" % [path, idx + 1, _class_of.get(path, "?")])
	return rows


## K-02：组件脚本必须有 class_name，且包含 Component。
## 两种合法形式（项目规范 K-02）:
##   后缀式 SleepComponent / HpComponentPlant
##   前缀式 AttackComponentBulletSplitPea / BombComponentJalapeno
func _check_component_class_name() -> Array[String]:
	var rows: Array[String] = []
	for path: String in _files:
		if not path.contains("/components/"):
			continue
		if path in CLASS_NAME_EXCEPTIONS:
			continue
		var class_name_value: String = _class_of.get(path, "")
		if class_name_value == "":
			rows.append("%s (no class_name)" % path)
		elif not class_name_value.contains("Component"):
			rows.append("%s class_name=%s" % [path, class_name_value])
	return rows


## K-03：组件里的 get_parent() 只应出现在 reparent / remove_child 这类"真的脱离宿主"场景。
## 本条可能误报，因此归类为 WARN。
func _check_get_parent() -> Array[String]:
	var rows: Array[String] = []
	for path: String in _files:
		if not path.contains("/components/"):
			continue
		var lines := _text[path].split("\n")
		for idx in lines.size():
			var line := lines[idx]
			if not line.contains("get_parent()"):
				continue
			if line.contains("reparent(") or line.contains("remove_child"):
				continue
			rows.append("%s:%d %s" % [path, idx + 1, line.strip_edges()])
	return rows

#endregion


#region 工具

func _is_exempt_file(path: String, table: Dictionary) -> bool:
	return table.has(path) and (table[path] as Array).is_empty()


func _in_func(func_name: String) -> String:
	return "" if func_name == "" else " in %s()" % func_name


func _match_one(text: String, pattern: String) -> String:
	var re := RegEx.create_from_string(pattern)
	var m := re.search(text)
	return "" if m == null else m.get_string(1)


func _descends_from_any(path: String, bases: Array) -> bool:
	var seen: Dictionary[String, bool] = {}
	var curr := path
	while curr != "" and not seen.has(curr):
		seen[curr] = true
		for base: String in bases:
			if _class_of.get(curr, "") == base:
				return true
		var parent: String = _parent_of.get(curr, "")
		curr = _path_of_class.get(parent, "")
	return false

#endregion
