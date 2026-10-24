extends LevelScriptBase
## moon_roof_demo —— 月夜屋顶（DLC 版第 6 章 Moon）演示关
##
## 演示「一张新地图怎么接进关卡」：地图 + 场景两行就够 ——
##   map_data   = res://data/map/map_moonroof.tres（月夜屋顶的几何 + 背景子场景 + 房门遮罩）
##   scene_name = SceneSettingRegistry.SCENE_MOON_ROOF（月夜底图 / Harvest Moon 曲 / 夜晚不掉阳光 / 血月）
## ⚠️ 这两张 DLC 新图都**不**在 `MainSceneRegistry.DEFAULT_MAP_PATHS` 里（它们与屋顶 / 前院同几何，
## 只换底图与背景子场景），所以必须由关卡自己指定 `map_data` —— 只写 scene_name 会落到默认图上
## （见 docs/参考存档/地图实现.md §2.3）。
##
## 本关按 Moon 章的口径摆场：屋顶是裸地先铺花盆、夜晚没有天降阳光（开局一次给足）、
## 20 波里第 10 / 20 波是旗帜波 —— 血月**每 5 波**起一次（第 5 / 10 / 15 / 20 波：
## 两旗正中间 + 旗帜波本身交替，全场僵尸 ×2 加速 + 红屏，15 秒后自己退，
## 见 docs/参考存档/血月.md）。
##
## 由「自制关卡」模组扫描（各模组目录下的 `levels/`，一个子目录 = 一关，关卡 id = 目录名）：
## 主菜单 → 自制关卡 → `moon_roof_demo`。关卡目录不论本模组启用与否都会被扫，
## 但选关页本身要开「自制关卡」模组才进得去（见 mods_builtin/custom_level/README 那条口径）。
##
## 出怪表只点名本体僵尸：本关不依赖任何模组开关，关掉 DLC 模组照样能打。

## 本关波数：第 10 / 20 波是旗帜波（= 血月触发点），留两波好看清两次
const WAVE_NUM := 20
## 开局阳光：月夜屋顶没有天降阳光（Moon 章五项难点之一），一次给足免得开局干等
const START_SUN := 1000
## 屋顶种植位：屋顶是裸地，没有花盆什么都种不下（铺第 1~4 列）
const FLOWER_POT_COLUMNS := 4


func _init() -> void:
	## 地图：月夜屋顶（几何与 map_boss 逐格一致，差异在背景子场景与底图）
	map_data = preload("res://data/map/map_moonroof.tres")
	## 场景：月夜屋顶 —— 赋值即套用，要覆盖的字段写在它之后
	scene_name = SceneSettingRegistry.SCENE_MOON_ROOF

	## 蹦极投人：Moon 章五项难点之一，与本体屋顶关同款开关
	is_bungi = true
	## 开局阳光
	start_sun = START_SUN
	## 本关波数：与 run_flow 里 start_battle(WAVE_NUM) 用同一个常量
	max_wave = WAVE_NUM
	## 出怪表
	zombie_refresh_types.assign([
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.BUCKET,
		ZombieIds.SCREEN_DOOR,
	])


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 屋顶铺花盆：要写在玩家能动手之前，否则「先有盆再种」的顺序就反了
	await plant_flower_pot_columns(FLOWER_POT_COLUMNS)
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.BUCKET,
		ZombieIds.SCREEN_DOOR,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 初始化小推车：屋顶清洁车从屏幕外左侧开到位
	await init_lawn_mover()
	## 「准备…安放…植物」
	await ready_set_plant()
	## 演示提示：血月的触发时机（提示条留到打完，想提前收就 hide_hint()）
	await hint("每 5 波（第 5 / 10 / 15 / 20 波）会升起血月：全场僵尸加速、画面泛红，15 秒后自己退去")
	## 开战：打到最后一波清完为止
	await start_battle(WAVE_NUM, zombie_list)
	await hide_hint()
