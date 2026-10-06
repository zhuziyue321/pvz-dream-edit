extends RefCounted
class_name SceneSettingRegistry
## 场景设置注册表 —— 「场景的名字」→ 场景脚本（SceneSettingBase 子类）。
##
## 静态类（不做 autoload，避免第 10 个 autoload 的初始化顺序风险，与 LevelRegistry 同风格）。
## 关卡数据只存场景名，运行时按它来这里取场景脚本、再取具体信息
## （见 ResourceLevelData.apply_scene_setting）。

## 场景名（ResourceLevelData.scene_name 的取值）
const SCENE_FRONT_DAY := &"front_day"
const SCENE_FRONT_NIGHT := &"front_night"
const SCENE_POOL := &"pool"
const SCENE_FOG := &"fog"
const SCENE_ROOF := &"roof"
const SCENE_BOSS := &"boss"

## 场景名 → 场景脚本路径
## 用路径 + 延迟 load：场景脚本引用了本类的常量，直接 preload 会构成循环依赖
const SCENE_SCRIPT_PATHS: Dictionary = {
	SCENE_FRONT_DAY: "res://src/world/scene/scene_front_day.gd",
	SCENE_FRONT_NIGHT: "res://src/world/scene/scene_front_night.gd",
	SCENE_POOL: "res://src/world/scene/scene_pool.gd",
	SCENE_FOG: "res://src/world/scene/scene_fog.gd",
	SCENE_ROOF: "res://src/world/scene/scene_roof.gd",
	SCENE_BOSS: "res://src/world/scene/scene_boss.gd",
}

## 场景名 → 场景设置实例（一份场景数据全关共用，只读取不改）
static var _cache: Dictionary = {}


## 按场景名取场景设置；没登记 / 加载失败返回 null（已打日志）
static func get_scene(scene_name: StringName) -> SceneSettingBase:
	if _cache.has(scene_name):
		return _cache[scene_name] as SceneSettingBase
	var path: String = SCENE_SCRIPT_PATHS.get(scene_name, "")
	if path.is_empty():
		Log.error("场景 %s 没有登记场景设置脚本" % scene_name)
		_cache[scene_name] = null
		return null
	var scene_script: GDScript = load(path)
	if scene_script == null:
		Log.error("场景设置脚本加载失败：%s" % path)
		_cache[scene_name] = null
		return null
	var setting: SceneSettingBase = scene_script.new() as SceneSettingBase
	if setting == null:
		Log.error("场景脚本 %s 不是 SceneSettingBase 子类" % path)
	_cache[scene_name] = setting
	return setting


## 本场景名有没有登记过
static func has_scene(scene_name: StringName) -> bool:
	return SCENE_SCRIPT_PATHS.has(scene_name)
