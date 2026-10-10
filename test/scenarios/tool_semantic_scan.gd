extends SceneTree

## 语义扫描：挖「编译门禁抓不到」的语义错误。
##
## 背景见 test/check_scripts.ps1 的 KNOWN LIMITATION 2：
## Godot --import 只编译它加载到的脚本，且不对所有脚本做方法调用解析，
## 因此「在某个基类上不存在的方法」会以 PASS 的形式溜过去
## （实证：portal_manager.gd 在 Node 上调 CanvasItem 的 get_world_2d()）。
##
## 本脚本补上这一层：
##   1. 解析所有 .gd 的 class_name / extends / 本文件定义的 func
##   2. 用 ClassDB 沿继承链拼出每个脚本真正可用的方法集合
##   3. 抽出所有「裸调用」xxx(（即 receiver 是 self 的调用）
##   4. 裸调用既不在本文件、也不在任何祖先类 / 全局作用域 → 报出来
##
## 用法：godot --headless --path . --script res://test/scenarios/tool_semantic_scan.gd
## 结果：写到 test/_semantic_scan_result.txt（已 gitignore），控制台也打印摘要。
##
## ⚠️ 已知不准：`_global_scope_names()` 里那份手写名单漏了谁，谁就会被误报。
## 实测在 sin/cos 上报过 4 条假阳性 —— 三角函数没进名单，代码本身没问题。
## 报出来的东西先自己确认一眼，别当成编译错误直接改。

## 既是关键字 / 内置构造器 / 常见误命中，统一忽略
const KEYWORDS := [
	"if", "elif", "else", "for", "while", "return", "func", "class", "extends",
	"match", "signal", "enum", "var", "const", "static", "pass", "break",
	"continue", "await", "yield", "assert", "not", "and", "or", "in", "is", "as",
	"set", "get", "tool", "super", "self", "emit", "connect", "call", "cast_to",
]


class ScriptInfo:
	var path := ""
	var cls := ""
	var base := ""
	var funcs := {}          ## func_name -> true
	var signals := {}        ## signal_name -> true
	var calls := {}          ## call_name -> line_no


func _init() -> void:
	_run()
	quit()


func _run() -> void:
	var files := _collect_files()
	var infos: Array[ScriptInfo] = []
	for p in files:
		infos.append(_parse(p))

	## class_name -> ScriptInfo
	var by_class := {}
	for i in infos:
		if i.cls != "":
			by_class[i.cls] = i

	## 全局作用域可用名
	var global_names := _global_scope_names()
	for kw in KEYWORDS:
		global_names[kw] = true
	## autoload 单例名（project.godot 里配的，脚本里可裸调用）
	for a in _autoload_names():
		global_names[a] = true
	for c in by_class.keys():
		global_names[c] = true

	var findings := []
	for i in infos:
		var chain := _resolve_chain(i, by_class)
		## 本文件 + 祖先类的所有方法
		var known := {}
		for f in i.funcs:
			known[f] = true
		for c in chain:
			if ClassDB.class_exists(c):
				for m in ClassDB.class_get_method_list(c, true):
					known[m["name"]] = true
			else:
				var si: ScriptInfo = by_class.get(c)
				if si != null:
					for f in si.funcs:
						known[f] = true

		for call in i.calls:
			if global_names.has(call):
				continue
			if known.has(call):
				continue
			findings.append("%s:%d  %s()   [class=%s base=%s]" % [i.path, i.calls[call], call, i.cls, i.base])

	_write_report(findings, infos.size(), files.size())


## ---------- 组装每种脚本的继承链 ----------
func _resolve_chain(i: ScriptInfo, by_class: Dictionary) -> Array:
	var chain := []
	var cur := i.base
	var guard := 0
	while cur != "" and guard < 32:
		guard += 1
		chain.append(cur)
		if ClassDB.class_exists(cur):
			cur = ClassDB.get_parent_class(cur)
			continue
		var si: ScriptInfo = by_class.get(cur)
		if si == null:
			break
		cur = si.base
	return chain


## ---------- 单个文件解析 ----------
func _parse(path: String) -> ScriptInfo:
	var i := ScriptInfo.new()
	i.path = path
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return i

	## 去掉字符串字面量（否则 "调用 xxx() 让波次开始" 这种文案会被当成调用）
	var re_str := RegEx.create_from_string('"(?:\\\\.|[^"\\\\])*"' + "|" + "'(?:\\\\.|[^'\\\\])*'")
	text = re_str.sub(text, "\"\"", true)
	## 去掉三引号 docstring 与行注释（粗糙但够用）
	var re_doc := RegEx.create_from_string('"""(?s).*?"""')
	text = re_doc.sub(text, "", true)

	var lines := text.split("\n")
	for idx in lines.size():
		var line: String = lines[idx]
		var code := line
		var h := code.find("#")
		if h >= 0:
			code = code.substr(0, h)
		if code.strip_edges() == "":
			continue

		var s := code.strip_edges()
		## class_name / extends
		if i.cls == "" and _match_one_ci("^class_name\\s+([A-Za-z_]\\w*)\\s*$", s) != "":
			i.cls = _match_one_ci("^class_name\\s+([A-Za-z_]\\w*)\\s*$", s)
		if i.base == "":
			var b := _match_one_ci("^extends\\s+([^\\s]+)", s)
			if b != "":
				i.base = _strip_class_suffix(b)

		## func 定义（含 static / private 等修饰）
		var f := _match_one_ci("(?:^|\\s)(?:static\\s+)?(?:@\\w+\\s+)*func\\s+([A-Za-z_]\\w*)\\s*\\(", code)
		if f != "":
			i.funcs[f] = true
		## signal 定义
		var sg := _match_one_ci("^signal\\s+([A-Za-z_]\\w*)", s)
		if sg != "":
			i.signals[sg] = true

		## 裸调用：标识符后面紧跟 (，且前面不是 . 也不是标识符/数字字符
		for m in RegEx.create_from_string("(^|[^\\w.])([a-zA-Z_]\\w*)\\s*\\(").search_all(code):
			var name: String = m.get_string(2)
			var offset: int = m.get_start(2)
			## 注解（@export_group / @warning_ignore ...）不是调用
			if code.substr(maxi(0, offset - 16), mini(16, offset)).contains("@"):
				continue
			## 跳过本行里被 `func` / `class` / `extends` 等前缀吃掉的
			var prefix := code.substr(0, offset).strip_edges().to_lower()
			if prefix.ends_with("func") or prefix.ends_with("class") or prefix.ends_with("extends") \
				or prefix.ends_with("static func") or prefix.ends_with("signal") or prefix.ends_with("enum"):
				continue
			if not i.calls.has(name):
				i.calls[name] = idx + 1
	return i


## extends Base.Class / extends SomeScript.gd → 归一化成纯类名
func _strip_class_suffix(b: String) -> String:
	b = b.trim_suffix("\"")
	if b.begins_with("\""):
		b = b.trim_prefix("\"").trim_suffix("\"")
		b = b.get_file().trim_suffix(".gd")
		return b
	if b.contains("."):
		return b.split(".")[0]
	return b


func _match_one_ci(pattern: String, target: String) -> String:
	var re := RegEx.create_from_string(pattern)
	var m := re.search(target)
	if m == null:
		return ""
	if m.get_group_count() < 1:
		return ""
	return m.get_string(1)


## ---------- 全局作用域 ----------
func _global_scope_names() -> Dictionary:
	var d := {}
	## ClassDB 的全局作用域分三处：@GlobalScope（print/typeof...）、
	## @GDScript（max/min/clamp/lerp/range/abs...）、@Variant
	for m in ClassDB.class_get_method_list("@GlobalScope", true):
		d[m["name"]] = true
	for m in ClassDB.class_get_method_list("@GDScript", true):
		d[m["name"]] = true
	## ClassDB 里没列出的一些 GDScript 内置
	## ⚠️ 这份手写名单是本工具最大的误报来源：漏了谁，谁就会被当成「方法不存在」报出来。
	## 例：三角函数曾漏掉 ⇒ sin/cos 报了 4 条假阳性（见本文件头注释）。
	for n in ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
		"Color", "Rect2", "Rect2i", "Transform2D", "Transform3D", "Plane", "AABB",
		"String", "StringName", "NodePath", "Dictionary", "Array", "PackedByteArray",
		"PackedInt32Array", "PackedInt64Array", "PackedFloat32Array", "PackedFloat64Array",
		"PackedStringArray", "PackedVector2Array", "PackedVector3Array", "PackedColorArray",
		"Callable", "Signal", "Resource", "Node", "Node2D", "Control", "RefCounted",
		"str", "len", "range", "int", "float", "bool", "abs", "min", "max", "print",
		"type", "instance_from_id", "is_instance_valid", "preload", "load", "weakref",
		## Godot 4 的 @GlodScope / @GDScript 在 ClassDB 里取不到完整方法表，手动补齐常用项
		"absf", "absi", "sign", "signf", "signi", "floor", "floorf", "floori",
		"ceil", "ceilf", "ceili", "round", "roundf", "roundi", "trunc", "truncf",
		"trunci", "fract", "fractf", "fracti",
		## 三角函数 / 反三角函数：这几个一旦漏掉，代码里的 sin() cos() 会全部被误报
		"sin", "cos", "tan", "sinh", "cosh", "tanh",
		"asin", "acos", "atan", "atan2", "asinh", "acosh", "atanh",
		"sqrt", "sqrtf", "inv_sqrt", "exp",
		"log", "pow", "lerp", "lerpf", "lerp_angle", "inverse_lerp", "smoothstep",
		"smootherstep", "posmod", "wrap", "wrapf", "wrapi", "pingpong", "snapped",
		"snappedf", "snappedi", "cubic_interpolate", "bezier_interpolate", "randomize",
		"move_toward", "rotate_toward", "remap", "deg_to_rad", "rad_to_deg",
		"linear_to_db", "db_to_linear", "ease", "nearest_po2", "step_decimals",
		"is_nan", "is_inf", "is_finite", "is_equal_approx", "is_zero_approx", "is_same",
		"randi", "randf", "randfn", "randf_range", "randi_range", "rand_seed",
		"randi_from_seed", "randf_from_seed", "seed", "clamp", "clampi", "clampf",
		"minf", "maxf", "mini", "maxi", "typeof", "printerr", "printraw", "prints",
		"printt", "print_rich", "push_error", "push_warning", "push_warning", "hash",
		"error_string", "inst_to_dict", "dict_to_inst", "is_instance_of", "to_json",
		"str_to_var", "var_to_str", "Callable", "assert"]:
		d[n] = true
	return d


func _autoload_names() -> Array:
	var names := []
	var cfg := ConfigFile.new()
	if cfg.load("res://project.godot") != OK:
		return names
	for section in cfg.get_sections():
		if section == "autoload":
			for k in cfg.get_section_keys(section):
				names.append(k)
	return names


func _collect_files() -> Array:
	var out := []
	var stack := ["res://src"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		var da := DirAccess.open(dir)
		if da == null:
			continue
		da.list_dir_begin()
		var name := da.get_next()
		while name != "":
			if name.begins_with("."):
				name = da.get_next()
				continue
			var full := dir.path_join(name)
			if da.current_is_dir():
				stack.append(full)
			elif name.ends_with(".gd"):
				out.append(full)
			name = da.get_next()
		da.list_dir_end()
	out.sort()
	return out


func _write_report(findings: Array, info_count: int, file_count: int) -> void:
	var lines := PackedStringArray()
	lines.append("=== 语义扫描：裸调用未在继承链 / 全局作用域中找到 ===")
	lines.append("扫描 .gd 文件数 = %d，成功解析 = %d，候选 = %d" % [file_count, info_count, findings.size()])
	lines.append("")
	for f in findings:
		lines.append(f)
	var body := "\n".join(lines)
	var f := FileAccess.open("res://test/_semantic_scan_result.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(body)
		f.close()
	print(body.substr(0, mini(body.length(), 4000)))
