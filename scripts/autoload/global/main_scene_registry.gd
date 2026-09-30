extends Node
class_name MainSceneRegistry


## 加载场景
enum MainScenes{
	MainGameFront,
	MainGameBack,
	MainGameRoof,

	StartMenu = 100,
	ChooseLevelAdventure,
	ChooseLevelMiniGame,
	ChooseLevelPuzzle,
	ChooseLevelSurvival,
	ChooseLevelCustom,

	Garden = 200,
	Almanac,
	Store,

	Null = 999,
}
@export var MainScenesMap = {
	MainScenes.MainGameFront: "res://scenes/main/main_game_01_front.tscn",
	MainScenes.MainGameBack: "res://scenes/main/main_game_02_back.tscn",
	MainScenes.MainGameRoof: "res://scenes/main/main_game_03_roof.tscn",

	MainScenes.StartMenu: "res://scenes/main/01_start_menu.tscn",
	MainScenes.ChooseLevelAdventure: "res://scenes/main/02_adventure_choose_level.tscn",
	MainScenes.ChooseLevelMiniGame: "res://scenes/main/03_mini_game_choose_level.tscn",
	MainScenes.ChooseLevelPuzzle: "res://scenes/main/04_puzzle_choose_level.tscn",
	MainScenes.ChooseLevelSurvival: "res://scenes/main/05_survival_choose_level.tscn",
	MainScenes.ChooseLevelCustom: "res://scenes/main/06_custom_choose_level.tscn",

	MainScenes.Garden: "res://scenes/main/10_garden.tscn",
	MainScenes.Almanac: "res://scenes/main/11_almanac.tscn",
	MainScenes.Store: "res://scenes/main/12_store.tscn",
}

## 场景 → 默认地图数据路径（关卡资源没写 map_data 时按它取，见 docs/地图实现.md）
## 用路径 + 延迟 load：map_data.gd 反过来引用了本类的 MainScenes 枚举，
## 直接 preload 会构成循环依赖
const DEFAULT_MAP_PATHS: Dictionary[MainScenes, String] = {
	MainScenes.MainGameFront: "res://resources/map_resource/map_front.tres",
	MainScenes.MainGameBack: "res://resources/map_resource/map_pool.tres",
	MainScenes.MainGameRoof: "res://resources/map_resource/map_roof.tres",
}

var _default_map_cache: Dictionary = {}


## 取场景对应的默认地图数据；没登记或加载失败返回 null
## 返回值是 ResourceMapData，这里不写类型注解以避免与地图脚本循环引用
func get_default_map_data(main_scenes: MainScenes):
	if _default_map_cache.has(main_scenes):
		return _default_map_cache[main_scenes]
	var map_data = null
	var path: String = DEFAULT_MAP_PATHS.get(main_scenes, "")
	if path != "":
		map_data = load(path)
	if map_data == null:
		Log.error("场景 %s 没有登记默认地图数据" % str(main_scenes))
	_default_map_cache[main_scenes] = map_data
	return map_data
