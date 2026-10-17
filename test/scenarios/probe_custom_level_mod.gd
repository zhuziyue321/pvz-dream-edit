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
##   关卡来源 → 玩家目录 + **所有模组各自目录下的 levels/**（别的模组 / 未登记模组都认），
##             同 id 时玩家目录优先
##
## 与 `probe_custom_level_pkg` 的分工：那个只验扫描器，这个验「模组这一层」。

const PKG_DIR_NAME := "probe_mod_pkg_tmp"
const DEP_TRES := "[gd_resource type=\"Resource\" format=3]\n\n[resource]\n"
## 关卡包里的关卡脚本
const LEVEL_SOURCE := "extends LevelScriptBase\n\nfunc _init() -> void:\n\tstart_sun = 999\n"
## 关卡包里的依赖脚本（不是关卡，不能进选关列表）
const HELPER_SOURCE := "extends Resource\n\nvar tag := \"i_am_a_dependency\"\n"

## 造在**别的模组** levels/ 目录里的关卡包（验证「加载所有模组的特定目录」）
const OTHER_MOD_PKG_DIR_NAME := "probe_other_mod_pkg_tmp"
## 造在 `user://mods/` 下**未登记**模组的 levels/ 里的关卡包（兜底也认）
const UNREG_MOD_PKG_DIR_NAME := "probe_unreg_mod_pkg_tmp"
## 同 id 冲突包：玩家目录与模组 levels/ 各放一个，验证「同 id 玩家优先」
const CONFLICT_PKG_DIR_NAME := "probe_conflict_pkg_tmp"
## 玩家目录那份的关卡脚本（阳光 111）
const LEVEL_SOURCE_PLAYER := "extends LevelScriptBase\n\nfunc _init() -> void:\n\tstart_sun = 111\n"
## 模组 levels/ 那份的关卡脚本（阳光 222，应被玩家那份盖住）
const LEVEL_SOURCE_BUILTIN := "extends LevelScriptBase\n\nfunc _init() -> void:\n\tstart_sun = 222\n"

var _failed := 0
var _files: Array[String] = []
var _dirs: Array[String] = []


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

	## ---- 造临时关卡：玩家目录 + 别的模组 levels/ + 未登记模组 levels/ + 同 id 冲突 ----
	_make_pkg(a)
	_make_mod_level_pkgs(a)
	_check_scan_result(a)
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
		_check(a, "别的模组 levels/ 的关卡也进了选关界面", names.has(OTHER_MOD_PKG_DIR_NAME))
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


## 造模组 levels/ 目录里的临时关卡（验证「加载所有模组的特定目录」）：
##   - **别的模组**（glove，当前加载根下）的 levels/ 里放一个独立关卡包
##   - 同 id 冲突包：玩家目录放 111、glove 的 levels/ 放 222
##   - `user://mods/` 下**未登记**模组的 levels/ 里再放一个（兜底也认）
func _make_mod_level_pkgs(a) -> void:
	var glove_dir := CustomChooseLevel.get_mod_level_dir(ModIds.GLOVE)
	var other_dir := glove_dir + "/" + OTHER_MOD_PKG_DIR_NAME
	if _ensure_dir(a, other_dir):
		_write(other_dir + "/level.gd", LEVEL_SOURCE_BUILTIN)
		_write(other_dir + "/helper.gd", HELPER_SOURCE)
	## 同 id 冲突：模组那份 222
	var mod_conflict_dir := glove_dir + "/" + CONFLICT_PKG_DIR_NAME
	if _ensure_dir(a, mod_conflict_dir):
		_write(mod_conflict_dir + "/level.gd", LEVEL_SOURCE_BUILTIN)
	## 同 id 冲突：玩家那份 111（应盖住模组那份）
	var player_conflict_dir := _custom_level_base() + "/" + CustomChooseLevel.CUSTOM_LEVEL_DIR + "/" + CONFLICT_PKG_DIR_NAME
	if _ensure_dir(a, player_conflict_dir):
		_write(player_conflict_dir + "/level.gd", LEVEL_SOURCE_PLAYER)
	## 未登记模组兜底：`user://mods/probe_unreg_mod_tmp/levels/`（没有入口脚本，ModManager 不管它）
	var unreg_root := ModManager.MODS_ROOT + "/probe_unreg_mod_tmp"
	var unreg_dir := unreg_root + "/" + CustomChooseLevel.MOD_LEVEL_DIR + "/" + UNREG_MOD_PKG_DIR_NAME
	if _ensure_dir(a, unreg_dir):
		_write(unreg_dir + "/level.gd", LEVEL_SOURCE_BUILTIN)
		## 父目录也登记进清理列表（先删叶子再删父级）
		_dirs.append(unreg_root + "/" + CustomChooseLevel.MOD_LEVEL_DIR)
		_dirs.append(unreg_root)


## 建目录并登记到待清理列表；建失败记一条失败
func _ensure_dir(a, dir_path: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(dir_path) == OK or DirAccess.dir_exists_absolute(dir_path):
		_dirs.append(dir_path)
		return true
	a.log("[CUSTMOD] FAIL 建目录失败 " + dir_path)
	_failed += 1
	return false


## 直接调扫描器（不切场景）验「所有模组的特定目录都被加载」：
##   - 别的模组 levels/ 里的关卡进列表；未登记模组 levels/ 里的关卡也进列表
##   - 同 id 时玩家目录优先（只出现一次，且是玩家那份的阳光 111）
func _check_scan_result(a) -> void:
	var dirs: Array[String] = CustomChooseLevel.get_mod_level_dirs()
	_check(a, "模组关卡目录清单包含 glove 的 levels/",
		dirs.has(CustomChooseLevel.get_mod_level_dir(ModIds.GLOVE)))
	var scanner := CustomChooseLevel.new()
	var found: Array = scanner.scan_custom_levels()
	scanner.free()
	var ids: Array[String] = []
	var other_hit := false
	var unreg_hit := false
	var conflict_count := 0
	var conflict_sun := -1
	for one in found:
		var lv_id := str(one[1])
		ids.append(lv_id)
		if lv_id == OTHER_MOD_PKG_DIR_NAME:
			other_hit = true
		if lv_id == UNREG_MOD_PKG_DIR_NAME:
			unreg_hit = true
		if lv_id == CONFLICT_PKG_DIR_NAME:
			conflict_count += 1
			conflict_sun = (one[0] as LevelScriptBase).start_sun
	a.log("[CUSTMOD] 扫到 %d 个关卡：%s" % [found.size(), ", ".join(ids)])
	_check(a, "别的模组 levels/ 里的关卡进了列表", other_hit)
	_check(a, "未登记模组 levels/ 里的关卡也进了列表", unreg_hit)
	_check(a, "同 id 玩家目录优先（只一个且阳光=111）", conflict_count == 1 and conflict_sun == 111)


func _make_pkg(a) -> void:
	var dir := _custom_level_base() + "/" + CustomChooseLevel.CUSTOM_LEVEL_DIR + "/" + PKG_DIR_NAME
	if not _ensure_dir(a, dir):
		return
	_write(dir + "/level.gd", LEVEL_SOURCE)
	_write(dir + "/helper.gd", HELPER_SOURCE)
	_write(dir + "/dep.tres", DEP_TRES)


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
	for d in _dirs:
		DirAccess.remove_absolute(d)
	_dirs.clear()
