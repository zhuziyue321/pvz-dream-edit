extends RefCounted

## 妯＄粍鎼埌 `user://mods/` 鍚?class_name 涓嶅啀娉ㄥ唽涓哄叏灞€绫伙紝鎺㈤拡杩欓噷 preload 鎴愬父閲忓啀寮曠敤
const ChooseLevelButtonCustomize := preload("res://mods_builtin/custom_level/choose_level_button_customize.gd")
const CustomChooseLevel := preload("res://mods_builtin/custom_level/custom_choose_level.gd")
const CustomLevelEntryButton := preload("res://mods_builtin/custom_level/custom_level_entry_button.gd")
## 探针：自制关卡**模组**（`mods_builtin/custom_level/`）
##
## 自制关卡是原版没有的功能，整条链路都在模组里，默认关闭。本探针验两端：
##   关闭 → `MainSceneMap` 里没有 `ChooseLevelCustom`、主菜单没有入口按钮（本体零节点）
##   打开 → 模组注入选关场景路径、现场挂入口按钮；切进选关界面能扫到目录里的关卡包
##
## 与 `probe_custom_level_pkg` 的分工：那个只验扫描器，这个验「模组这一层」。

const PKG_DIR_NAME := "probe_mod_pkg_tmp"
const DEP_TRES := "[gd_resource type=\"Resource\" format=3]\n\n[resource]\n"
## 关卡包里的关卡脚本
const LEVEL_SOURCE := "extends LevelScriptBase\n\nfunc _init() -> void:\n\tstart_sun = 999\n"
## 关卡包里的依赖脚本（不是关卡，不能进选关列表）
const HELPER_SOURCE := "extends Resource\n\nvar tag := \"i_am_a_dependency\"\n"

var _failed := 0
var _files: Array[String] = []
var _dir := ""


func run(a) -> void:
	a.log("")
	a.log("========== 探针 自制关卡模组 ==========")
	## 等主菜单自身初始化完（按钮滑入动画）再动场景
	await a.wait(2.0)

	var mode := MainSceneRegistry.MainScenes.ChooseLevelCustom
	var map: Dictionary = Global.main_scene_registry.MainScenesMap
	var root := (Engine.get_main_loop() as SceneTree).root
	var start_menu := root.get_node_or_null("StartMenu")

	_check(a, "模组默认关闭（本体 = 原版体验）", not ModManager.is_mod_enabled(ModIds.CUSTOM_LEVEL))
	_check(a, "关闭时 MainSceneMap 里没有 ChooseLevelCustom", not map.has(mode))
	_check(a, "关闭时主菜单没有入口按钮", start_menu != null
		and start_menu.get_node_or_null("BG_Right/CustomLevelEntryButton") == null)

	## ---- 开模组 ----
	ModManager.set_mod_enabled(ModIds.CUSTOM_LEVEL, true)
	_check(a, "开启后注入了选关场景路径", str(map.get(mode, "")).ends_with("custom_choose_level.tscn"))
	var btn := start_menu.get_node_or_null("BG_Right/CustomLevelEntryButton") if start_menu != null else null
	_check(a, "开启后主菜单现场挂上了入口按钮", btn != null)

	## ---- 造一个临时关卡包，切进选关界面看有没有扫到 ----
	_make_pkg(a)
	GlobalUtils.change_scene(map[mode])
	await a.wait(2.0)
	var cl := root.get_node_or_null("CustomChooseLevel")
	_check(a, "切进了自制关卡选关界面", cl != null)
	if cl != null:
		var names: Array[String] = []
		for page in cl.all_pages_array:
			for node in (page as Node).get_children():
				if node is ChooseLevelButtonCustomize:
					names.append((node as ChooseLevelButtonCustomize).level_name)
		a.log("[CUSTMOD] 选关界面关卡=%s" % str(names))
		_check(a, "关卡包以目录名进列表", names.has(PKG_DIR_NAME))
		_check(a, "依赖脚本没有混进列表", not names.has("helper"))
	_cleanup()

	## ---- 关回去 ----
	ModManager.set_mod_enabled(ModIds.CUSTOM_LEVEL, false)
	_check(a, "关闭后场景路径被摘掉", not map.has(mode))

	a.log("")
	a.log("[CUSTMOD] result=%s failed=%d" % ["FAIL" if _failed > 0 else "PASS", _failed])
	a.quit_game()


func _check(a, desc: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	a.log("[CUSTMOD] %s %s" % ["OK  " if ok else "FAIL", desc])


## 与 custom_choose_level.gd:get_base_path() 同款口径
func _custom_level_base() -> String:
	return CustomChooseLevel.get_base_path()


func _make_pkg(a) -> void:
	_dir = _custom_level_base() + "/" + CustomChooseLevel.CUSTOM_LEVEL_DIR + "/" + PKG_DIR_NAME
	if DirAccess.make_dir_recursive_absolute(_dir) != OK and not DirAccess.dir_exists_absolute(_dir):
		a.log("[CUSTMOD] FAIL 建目录失败 " + _dir)
		_failed += 1
		return
	_write(_dir + "/level.gd", LEVEL_SOURCE)
	_write(_dir + "/helper.gd", HELPER_SOURCE)
	_write(_dir + "/dep.tres", DEP_TRES)


func _write(abs_path: String, text: String) -> void:
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		Log.warn("[CUSTMOD] 写文件失败 " + abs_path)
		return
	f.store_string(text)
	f.close()
	_files.append(abs_path)


func _cleanup() -> void:
	for f in _files:
		DirAccess.remove_absolute(f)
	_files.clear()
	if _dir != "":
		DirAccess.remove_absolute(_dir)
	_dir = ""
