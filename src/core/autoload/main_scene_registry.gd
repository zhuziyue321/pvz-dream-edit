extends Node
class_name MainSceneRegistry


## 加载场景
## 主游戏只有前院 / 泳池 / 屋顶三个通用槽位，**不要为某一关单开枚举值**：
## 要用特殊地图的关卡在自己的 map_data 上显式指定（见 adventure_01_01 / adventure_05_10）
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
## 全部主游戏关卡共用同一份场景：地图差异（格子几何、泳池、屋顶斜面、背景动画）
## 都由 ResourceMapData 在运行时装配，不再按地图分场景文件，见 docs/参考存档/地图实现.md
@export var MainScenesMap = {
	MainScenes.MainGameFront: "res://src/main/main_game_base.tscn",
	MainScenes.MainGameBack: "res://src/main/main_game_base.tscn",
	MainScenes.MainGameRoof: "res://src/main/main_game_base.tscn",

	MainScenes.StartMenu: "res://src/menus/start_menu/start_menu.tscn",
	MainScenes.ChooseLevelAdventure: "res://src/menus/choose_level/adventure_choose_level.tscn",
	MainScenes.ChooseLevelMiniGame: "res://src/menus/choose_level/mini_game_choose_level.tscn",
	MainScenes.ChooseLevelPuzzle: "res://src/menus/choose_level/puzzle_choose_level.tscn",
	MainScenes.ChooseLevelSurvival: "res://src/menus/choose_level/survival_choose_level.tscn",
	MainScenes.ChooseLevelCustom: "res://src/menus/choose_level/custom_choose_level.tscn",

	MainScenes.Garden: "res://src/garden/garden.tscn",
	MainScenes.Almanac: "res://src/almanac/almanac.tscn",
	MainScenes.Store: "res://src/store/store.tscn",
}

## 场景 → 默认地图数据路径（关卡资源没写 map_data 时按它取，见 docs/参考存档/地图实现.md）
## 用路径 + 延迟 load：map_data.gd 反过来引用了本类的 MainScenes 枚举，
## 直接 preload 会构成循环依赖
const DEFAULT_MAP_PATHS: Dictionary[MainScenes, String] = {
	MainScenes.MainGameFront: "res://data/map/map_front.tres",
	MainScenes.MainGameBack: "res://data/map/map_pool.tres",
	MainScenes.MainGameRoof: "res://data/map/map_roof.tres",
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
