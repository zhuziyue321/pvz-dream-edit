extends RefCounted

## 妯＄粍鎼埌 `user://mods/` 鍚?class_name 涓嶅啀娉ㄥ唽涓哄叏灞€绫伙紝鎺㈤拡杩欓噷 preload 鎴愬父閲忓啀寮曠敤
const CustomChooseLevel := preload("res://mods_builtin/custom_level/custom_choose_level.gd")
## 探针：验证「自制关卡 = 一个目录」的加载方式。
##
## 玩家自制关卡目录 = Godot 的 user:// 目录下的 custom_level
## （编辑器与导出后同址，见 CustomChooseLevel.get_base_path()）
## 里现在认两种摆法：
##   1）关卡包：`custom_level/<关卡名>/` 一个子目录 = 一个关卡，目录里的关卡脚本当关卡，
##      目录里其余的文件全是这个脚本的依赖（只加载，不进选关列表）
##   2）散装文件：直接放在 custom_level/ 下的 .gd / .tres
##
## 本探针临时造一个关卡包（level.gd + helper.gd + dep.tres）再调
## CustomChooseLevel.scan_custom_levels()，确认：
##   - 外部目录里 `extends LevelScriptBase` 的 .gd 能被认成关卡（继承链判据）
##   - 包里的依赖被加载、且不进选关列表
## 跑完自动清理临时文件。
##
## 注：随仓库发布的两个样例脚本还在 `data/levels/params/`（已不在扫描目录里），
## 想让它们出现在选关列表，需复制到本探针用的 user://custom_level 下。

const PKG_DIR_NAME := "probe_custom_pkg_tmp"
const DEP_TRES := "[gd_resource type=\"Resource\" format=3]\n\n[resource]\n"
## 关卡包里的关卡脚本
const LEVEL_SOURCE := "extends LevelScriptBase\n\nfunc _init() -> void:\n\tstart_sun = 999\n"
## 关卡包里的依赖脚本（不是关卡，不能进选关列表）
const HELPER_SOURCE := "extends Resource\n\nvar tag := \"i_am_a_dependency\"\n"

var _dir := ""
var _files: Array[String] = []


func run(a) -> void:
	a.log("[CUSTLVL] editor=%s" % str(OS.has_feature("editor")))
	var base := _custom_level_base()
	_dir = base + "/" + CustomChooseLevel.CUSTOM_LEVEL_DIR + "/" + PKG_DIR_NAME
	a.log("[CUSTLVL] 关卡包目录=%s" % _dir)
	if DirAccess.make_dir_recursive_absolute(_dir) != OK and not DirAccess.dir_exists_absolute(_dir):
		a.log("[CUSTLVL] 建目录失败，放弃")
		a.quit_game()
		return
	_write(_dir + "/level.gd", LEVEL_SOURCE)
	_write(_dir + "/helper.gd", HELPER_SOURCE)
	_write(_dir + "/dep.tres", DEP_TRES)

	var scanner := CustomChooseLevel.new()
	var found: Array = scanner.scan_custom_levels(CustomChooseLevel.CUSTOM_LEVEL_DIR)
	scanner.free()

	a.log("[CUSTLVL] 扫到 %d 个关卡" % found.size())
	var hit_pkg := false
	for one in found:
		var para = one[0]
		var lv_id: String = str(one[1])
		a.log("[CUSTLVL]   id=%s  type=%s  is_script=%s" % [
			lv_id, str((para as Object).get_class()), str(para is LevelScriptBase)])
		if lv_id == PKG_DIR_NAME:
			hit_pkg = true
			a.log("[CUSTLVL]     关卡包命中: start_sun=%s" % str(para.start_sun))
		## 两个随仓库发布的样例关卡：核对 .tres → .gd 迁移后的关键字段还在
		if lv_id == "not_zombie":
			a.log("[CUSTLVL]     not_zombie: 传送带权重=%d 顺序=%d 波数=%d" % [
				para.conveyor_weights.size(), para.conveyor_order.size(), para.max_wave])
		if lv_id == "vase_zombie":
			a.log("[CUSTLVL]     vase_zombie: 预选卡=%d 阳光=%d 罐子模式=%s" % [
				para.prechosen_cards.size(), para.start_sun, str(para.pot_mode)])
	a.log("[CUSTLVL] 关卡包进列表=%s（期望 true）；依赖 helper/dep 不在列表里=%s（期望 true）" % [
		str(hit_pkg), str(found.size() >= 2 and hit_pkg)])

	_cleanup()
	a.log("[CUSTLVL] result=DONE")
	a.quit_game()


## 与 custom_choose_level.gd:get_base_path() 同款口径
func _custom_level_base() -> String:
	return CustomChooseLevel.get_base_path()


func _write(abs_path: String, text: String) -> void:
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		Log.warn("[CUSTLVL] 写文件失败 " + abs_path)
		return
	f.store_string(text)
	f.close()
	_files.append(abs_path)


func _cleanup() -> void:
	for f in _files:
		DirAccess.remove_absolute(f)
	_files.clear()
	DirAccess.remove_absolute(_dir)
