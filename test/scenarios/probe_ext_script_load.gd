extends RefCounted
## 探针：验证「从游戏外部目录加载 .gd 脚本」是否可行。
##
## 关卡格式 V2 的 `level_script`（关卡脚本钩子）依赖这件事：
## 玩家自制关卡是把 `.tres` 丢进「自制关卡目录」（编辑器下 = 项目根 /data/levels/params，
## 导出后 = exe 同级 /data/levels/params，见 src/menus/choose_level/custom_choose_level.gd）。
## 若自制关卡还能带一个 `.gd`，就必须确认这个目录里的 `.gd` 能被加载。
##
## 测三种方式 × 两个目录：
##   ResourceLoader.load(绝对路径)          —— 最常用
##   load(绝对路径)                          —— GDScript 内建
##   GDScript.new()+source_code+reload()     —— 读文本后动态编译（不依赖 ResourceLoader）
## 目录 1 = user://（导出后的用户数据目录）
## 目录 2 = 自制关卡同款绝对路径
##
## ⚠️ 编辑器 / headless 下通过 ≠ 导出模板下通过：本探针会打印 OS.has_feature 的实际值，
## 导出模板的结论必须在 export 之后跑 exe 再验一次。

const TMP_DIR_NAME := "probe_ext_script_tmp"
const FILE_NAME := "probe_ext_script_sample.gd"
## 样本源码：一个带 hello() 的 Resource 脚本
const SAMPLE_SOURCE := "extends Resource\nvar tag := \"ext\"\nfunc hello() -> String:\n\treturn \"hello_from_ext\"\n"

enum E_Mode { Loader, Load, Compile }

var _made_dirs: Array[String] = []


func run(a) -> void:
	a.log("[EXTSCRIPT] 引擎=%s" % str(Engine.get_version_info().get("string", "?")))
	a.log("[EXTSCRIPT] editor=%s template=%s debug=%s" % [
		str(OS.has_feature("editor")), str(OS.has_feature("template")), str(OS.is_debug_build())])
	a.log("[EXTSCRIPT] user://=%s" % ProjectSettings.globalize_path("user://"))
	a.log("[EXTSCRIPT] exe=%s" % OS.get_executable_path())
	a.log("")

	var cases := [
		["user目录", _abs_dir(ProjectSettings.globalize_path("user://"))],
		["自制关卡目录", _abs_dir(_custom_level_base())],
	]
	for c in cases:
		var label: String = c[0]
		var dir_path: String = c[1]
		a.log("[EXTSCRIPT] === %s: %s" % [label, dir_path])
		if dir_path == "":
			a.log("[EXTSCRIPT]   目录不可用，跳过")
			continue
		var file_path := dir_path.path_join(FILE_NAME)
		if not _write_file(file_path, SAMPLE_SOURCE):
			a.log("[EXTSCRIPT]   写文件失败，跳过")
			continue
		_try(a, "ResourceLoader.load", file_path, E_Mode.Loader)
		_try(a, "load()", file_path, E_Mode.Load)
		_try(a, "source_code+reload", file_path, E_Mode.Compile)
		a.log("")

	_cleanup()
	a.log("[EXTSCRIPT] result=DONE")
	a.quit_game()


## 自制关卡目录的基路径：与 custom_choose_level.gd:get_base_path() 同款口径
func _custom_level_base() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://")
	return OS.get_executable_path().get_base_dir()


## 建临时目录并返回它的真实绝对路径；建不出来返回 ""
func _abs_dir(base: String) -> String:
	if base == "":
		return ""
	var dir_path := base.path_join(TMP_DIR_NAME)
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK and err != ERR_ALREADY_EXISTS:
		a_log_miss(dir_path, err)
		return ""
	_made_dirs.append(dir_path)
	return dir_path


func a_log_miss(path: String, err: int) -> void:
	Log.warn("[EXTSCRIPT] 建目录失败 %s err=%d" % [path, err])


func _write_file(abs_path: String, text: String) -> bool:
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		Log.warn("[EXTSCRIPT] 写文件失败 %s err=%d" % [abs_path, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	return true


func _try(a, method_label: String, abs_path: String, mode: E_Mode) -> void:
	var res = null
	match mode:
		E_Mode.Loader:
			res = ResourceLoader.load(abs_path)
		E_Mode.Load:
			res = load(abs_path)
		E_Mode.Compile:
			res = _compile_from_text(abs_path)
	if res == null:
		a.log("[EXTSCRIPT]   %-22s FAIL 返回 null" % method_label)
		return
	if not (res is Script):
		a.log("[EXTSCRIPT]   %-22s FAIL 不是 Script: %s" % [method_label, str(res)])
		return
	var inst = res.new()
	if inst == null or not inst.has_method("hello"):
		a.log("[EXTSCRIPT]   %-22s FAIL 实例化失败或 hello() 缺失" % method_label)
		return
	var got = inst.hello()
	a.log("[EXTSCRIPT]   %-22s OK   hello()=%s tag=%s" % [method_label, str(got), str(inst.tag)])


## 读源码文本 -> GDScript 动态编译（不经过 ResourceLoader）
func _compile_from_text(abs_path: String):
	var text := FileAccess.get_file_as_string(abs_path)
	if text == "":
		return null
	var s := GDScript.new()
	s.source_code = text
	var err := s.reload()
	if err != OK:
		Log.warn("[EXTSCRIPT] 动态编译失败 err=%d" % err)
		return null
	## GDScript 没有 is_valid()；编译是否成功看 can_instantiate()
	if not s.can_instantiate():
		Log.warn("[EXTSCRIPT] 动态编译后仍不可实例化")
		return null
	return s


func _cleanup() -> void:
	for d in _made_dirs:
		DirAccess.remove_absolute(d.path_join(FILE_NAME))
		DirAccess.remove_absolute(d)
	_made_dirs.clear()
