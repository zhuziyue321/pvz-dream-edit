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
	## 冒险模式**没有选关界面**（按进度只能打下一关，见 GlobalGameState.build_curr_adventure_level_para）：
	## 这个枚举值在 MainScenesMap 里**故意没有登记场景**，它只作为冒险模式的 id 用
	## —— 存档键（"101_x_xxxx"）与 ResourceLevelData.game_mode 都是按数值存的，
	## 一旦改了数值，所有人的通关进度与关卡数据都会对不上号。
	ChooseLevelAdventure,
	ChooseLevelMiniGame,
	ChooseLevelPuzzle,
	ChooseLevelSurvival,
	## 槽位留给自制关卡模组：场景路径由该模组在 install() 时注入 MainScenesMap
	## （本体不许出现模组里的路径，见 docs/参考存档/模组机制.md）
	ChooseLevelCustom,
	## 槽位留给多人游戏(PVP)模组：同上，场景路径由该模组在 install() 时注入
	## （主菜单木牌上的「MULTIPLAYER」牌按下就进这一槽位登记的选关界面）
	## ⚠️ 数值只许往后加：存档键（"106_x_xxxx"）与 ResourceLevelData.game_mode 都按数值存
	ChooseLevelPvp,

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
	MainScenes.ChooseLevelMiniGame: "res://src/menus/choose_level/mini_game_choose_level.tscn",
	MainScenes.ChooseLevelPuzzle: "res://src/menus/choose_level/puzzle_choose_level.tscn",
	MainScenes.ChooseLevelSurvival: "res://src/menus/choose_level/survival_choose_level.tscn",

	MainScenes.Garden: "res://src/garden/garden.tscn",
	MainScenes.Almanac: "res://src/almanac/almanac.tscn",
	MainScenes.Store: "res://src/store/store.tscn",
}

## **取场景路径一律走这里**，不要自己写 `get_scene_path(...)`（U-08）。
##
## 为什么：以前全仓 100+ 处直接索引这张表，其中有的写 `get_scene_path(k)`、
## 有的写 `MainScenesMap.get(k, 兜底)` —— 槽位没登记时一个直接崩、一个静默兜底，
## 两种口径混在一起，排查时很难判断「到底崩没崩」。
## 现在统一：没登记就 Log.error 并返回 ""，调用方判空即可；需要兜底就传 `fallback`。
##
## [param fallback] 主槽位没登记时改用它；不传表示不要兜底。
func get_scene_path(main_scenes: MainScenes, fallback: MainScenes = MainScenes.Null) -> String:
	var path: String = MainScenesMap.get(main_scenes, "")
	if path == "" and fallback != MainScenes.Null:
		path = MainScenesMap.get(fallback, "")
	if path == "":
		Log.error("MainSceneRegistry：未登记的场景槽位 %s" % str(main_scenes))
	return path


## **写入场景槽位**（供模组在 install() 时注入，如自制关卡的选关界面）。
## 走方法而不是让外部直接改 `MainScenesMap`：那张表是 `@export` 的，直接改等于绕开一切校验。
func set_scene_path(main_scenes: MainScenes, path: String) -> void:
	if path == "":
		Log.error("MainSceneRegistry：注入的场景路径为空 %s" % str(main_scenes))
		return
	MainScenesMap[main_scenes] = path


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
