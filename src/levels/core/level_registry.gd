extends RefCounted
class_name LevelRegistry
## 关卡注册表：关卡 id ↔ 关卡资源路径
##
## **id = 关卡 .tres 的文件名 basename**（`adventure_01_01` / `puzzle_pot_10` / `survival_flag_06_day` …）
## 选这个规则是因为它跟**自制关卡的现有约定已经一致**：
## `src/menus/choose_level/custom_choose_level.gd` 扫目录时用的 level_id 就是文件名 basename，
## 内置关与自制关因此共用一套 id 规则，不用为自制关再发明一套。
##
## 为什么要有注册表：
##   以前关卡是**硬挂在 4 个选关 .tscn 的节点 @export 上**的 —— 一个关卡「存在」与否取决于
##   有没有被某个场景引用，业务代码拿不到「一共有哪几关」，只能去遍历场景节点。
##   注册表把这件事收成一处，业务代码不再散落 `res://` 关卡路径（硬约束 §1-4）。
##
## 内置关卡**扫目录自动登记**（约定 > 配置，不维护一张 95 行的大表，加一个脚本就自动进表）；
## 玩家自制关卡走 register_custom() 动态登记。
##
## ⚠️ **「是不是关卡」只认继承链**（白名单，见 LEVEL_BASE_CLASS_NAMES / is_level_script）：
## 模式目录里除了关卡脚本，还混着「只服务某一关的场景脚本 / UI / 进度条数据源」
## （如 mode_minigame/minigame_07_seeing_stars_cell_star_overlay.gd、mode_adventure/adventure_05_05_bungi_blitz.gd），
## 它们按硬约束 §1-8 必须与关卡脚本同目录 —— **不能靠文件名前缀区分**（前缀只是命名约定，
## 辅助脚本按约定也带关卡名前缀，照样会被误登记成假关卡）。
##
## ⚠️ 关卡资源是**有状态**的：init_para() / set_choose_level() 会在运行时改它的字段。
## get_level() 对**脚本关卡**是 new() 出一个实例（关卡数据有状态：init_para() 会改字段，
## 每次 new 一份反而更安全），对老 .tres 关卡仍是 load() 拿引擎缓存的共享实例。

## 内置关卡根目录
const LEVEL_DIR := "res://src/levels"

## 关卡目录 -> 游戏模式（目录名即模式，约定 > 配置）
const MODE_BY_DIR: Dictionary = {
	"mode_adventure": MainSceneRegistry.MainScenes.ChooseLevelAdventure,
	"mode_minigame": MainSceneRegistry.MainScenes.ChooseLevelMiniGame,
	"mode_puzzle": MainSceneRegistry.MainScenes.ChooseLevelPuzzle,
	"mode_survival": MainSceneRegistry.MainScenes.ChooseLevelSurvival,
}

## 关卡识别白名单：**只在继承链上认这两个 class_name**（`LevelScriptBase` 本身也 extends `ResourceLevelData`）
## 其余一切 .gd（Node2D 的场景脚本、进度条数据源、UI…）**文件名长得再像关卡也不是关卡**
const LEVEL_BASE_CLASS_NAMES: Array[String] = ["LevelScriptBase", "ResourceLevelData"]

static var _path_by_id: Dictionary = {}
static var _mode_by_id: Dictionary = {}
static var _is_scanned := false


#region 扫描与登记
## 重新扫描内置关卡目录（加了 / 删了关卡脚本之后调用）
static func rescan() -> void:
	_path_by_id.clear()
	_mode_by_id.clear()
	_scan_dir(LEVEL_DIR, MainSceneRegistry.MainScenes.Null)
	_is_scanned = true
	Log.debug("LevelRegistry: 扫到 %d 个内置关卡" % _path_by_id.size())


static func _scan_dir(dir_path: String, mode: MainSceneRegistry.MainScenes) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		Log.warn("LevelRegistry: 打不开目录 " + dir_path)
		return
	## 进入子目录时按目录名认模式（根目录下的散装 .tres 保持 Null）
	var child_mode: MainSceneRegistry.MainScenes = MODE_BY_DIR.get(dir_path.get_file(), mode)
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			## core/ 放的是关卡脚本基类 / 事件脚本 / 关卡侧专属资源，不是关卡（目录原名叫 script/）
			if name == "core" or name == "script":
				name = dir.get_next()
				continue
			_scan_dir(dir_path.path_join(name), child_mode)
		elif name.ends_with(".gd"):
			## 白名单判据：继承链上出现 LevelScriptBase / ResourceLevelData 才是关卡。
			## 关卡专属的场景脚本 / UI / 进度条数据源一律不登记，免得选关列表里冒出假关卡
			if not is_level_script(dir_path.path_join(name)):
				name = dir.get_next()
				continue
			var id := name.get_basename()
			if _path_by_id.has(id):
				Log.warn("LevelRegistry: 关卡 id 重复 %s（后者覆盖前者）" % id)
			_path_by_id[id] = dir_path.path_join(name)
			_mode_by_id[id] = child_mode
		name = dir.get_next()
	dir.list_dir_end()


## [res_path] 待判定的 .gd 的 res:// 绝对路径
##
## 白名单判据：沿 `get_base_script()` 往上走，继承链上出现 LEVEL_BASE_CLASS_NAMES 里的
## class_name 才算关卡；走到底都没命中就不是（load 失败 / 不是脚本同样返回 false）。
##
## ⚠️ 别用 `get_instance_base_type()` 判：它返回的是**原生**基类（关卡脚本一律是 "Resource"），
## 分不出 LevelScriptBase 与别的 Resource 子类 —— 要认的是脚本链上的 class_name。
static func is_level_script(res_path: String) -> bool:
	var res := load(res_path)
	if not (res is Script):
		return false
	var s := (res as Script).get_base_script()
	while s != null:
		if LEVEL_BASE_CLASS_NAMES.has(s.get_global_name()):
			return true
		s = s.get_base_script()
	return false


## 登记一个玩家自制关卡（id 由调用方给，通常是文件名 basename）
static func register_custom(level_id: String, res_path: String) -> void:
	if level_id == "" or res_path == "":
		return
	_path_by_id[level_id] = res_path
	_mode_by_id[level_id] = MainSceneRegistry.MainScenes.ChooseLevelCustom
	Log.debug("LevelRegistry: 登记自制关卡 %s -> %s" % [level_id, res_path])


static func _ensure_scanned() -> void:
	if not _is_scanned:
		rescan()
#endregion


#region 查询
static func has_level(level_id: String) -> bool:
	_ensure_scanned()
	return _path_by_id.has(level_id)


## 全部关卡 id（内置 + 已登记的自制关），已排序
static func all_ids() -> Array[String]:
	_ensure_scanned()
	var ids: Array[String] = []
	for k in _path_by_id.keys():
		ids.append(k)
	ids.sort()
	return ids


## 某模式下的关卡 id（内置关按目录认模式，自制关是 ChooseLevelCustom）
static func ids_by_mode(mode: MainSceneRegistry.MainScenes) -> Array[String]:
	_ensure_scanned()
	var ids: Array[String] = []
	for k in _mode_by_id.keys():
		if _mode_by_id[k] == mode:
			ids.append(k)
	ids.sort()
	return ids


## ⚠️ 不叫 get_path：Resource/Script 有内建 get_path()，同名的 static func 会被解析成内建方法
## （运行时报 "Invalid call to function 'get_path' in base 'GDScript'. Expected 0 argument(s)"）
static func get_level_path(level_id: String) -> String:
	_ensure_scanned()
	return _path_by_id.get(level_id, "")


static func get_mode(level_id: String) -> MainSceneRegistry.MainScenes:
	_ensure_scanned()
	return _mode_by_id.get(level_id, MainSceneRegistry.MainScenes.Null)


## 加载关卡资源；未登记 / 加载失败 / 类型不对都返回 null
## 返回的是引擎缓存里的共享实例（同一路径 = 同一实例），不额外拷贝
static func get_level(level_id: String) -> ResourceLevelData:
	var res_path := get_level_path(level_id)
	if res_path == "":
		Log.error("LevelRegistry: 未登记的关卡 id = " + level_id)
		return null
	var res = load(res_path)
	if res == null:
		Log.error("LevelRegistry: 关卡加载失败 " + res_path)
		return null
	## 脚本关卡：load 出来的是 GDScript，new() 才是关卡实例
	if res is Script:
		res = (res as Script).new()
	if not (res is ResourceLevelData):
		Log.error("LevelRegistry: 不是 ResourceLevelData " + res_path)
		return null
	return res
#endregion
