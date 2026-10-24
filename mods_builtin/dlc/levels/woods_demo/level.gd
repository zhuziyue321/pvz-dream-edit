extends LevelScriptBase
## woods_demo —— 郊外营地（DLC 版第 7 章 Woods）演示关
##
## 演示「一张新地图怎么接进关卡」：地图 + 场景两行就够 ——
##   map_data   = res://data/map/map_woods.tres（郊外营地的几何 + 背景子场景 + 露营车车门遮罩）
##   scene_name = SceneSettingRegistry.SCENE_WOODS（森林营地底图 / Woody Tombstones 曲 / 白天掉阳光）
## ⚠️ 这两张 DLC 新图都**不**在 `MainSceneRegistry.DEFAULT_MAP_PATHS` 里（它们与前院 / 屋顶同几何，
## 只换底图与背景子场景），所以必须由关卡自己指定 `map_data` —— 只写 scene_name 会落到默认图上
## （见 docs/参考存档/地图实现.md §2.3）。
##
## 本关顺带演示这一章的特色玩法**灌木丛**：占一格种不下植物、走进灌木的僵尸大多数植物打不到
## （蜂射手 / 爆杀植物是官方指定的反制）、爆杀与推车能摧毁灌木、最终波每丛灌木各冒出一只僵尸
## （见 docs/参考存档/灌木丛.md）。所以波数压到 10 波 —— 第 10 波就是最终波，很快能看到灌木伏击。
##
## 由「自制关卡」模组扫描（各模组目录下的 `levels/`，一个子目录 = 一关，关卡 id = 目录名）：
## 主菜单 → 自制关卡 → `woods_demo`。关卡目录不论本模组启用与否都会被扫，
## 但选关页本身要开「自制关卡」模组才进得去。
##
## 出怪表只点名本体僵尸：本关不依赖任何模组开关，关掉 DLC 模组照样能打。

## 本关波数：第 10 波就是最终波（旗帜波），灌木伏击在最终波触发
const WAVE_NUM := 10
## 开局灌木数量（先长草坪右侧三分之二，与墓碑同款规则）
const BUSH_NUM := 8
## 开局阳光：白天有天降阳光，给 300 起手够摆一排射手
const START_SUN := 300


func _init() -> void:
	## 地图：郊外营地（几何与 map_front 逐格一致，差异在背景子场景与底图）
	map_data = preload("res://data/map/map_woods.tres")
	## 场景：郊外营地 —— 赋值即套用，要覆盖的字段写在它之后
	scene_name = SceneSettingRegistry.SCENE_WOODS

	## 灌木丛：本关的演示重点（开关与墓碑同款）
	is_have_bush = true
	init_bush_num = BUSH_NUM
	## 开局阳光
	start_sun = START_SUN
	## 本关波数：与 run_flow 里 start_battle(WAVE_NUM) 用同一个常量
	max_wave = WAVE_NUM
	## 出怪表
	zombie_refresh_types.assign([
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.BUCKET,
		ZombieIds.POLE_VAULTER,
	])


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.BUCKET,
		ZombieIds.POLE_VAULTER,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 初始化小推车
	await init_lawn_mover()
	## 「准备…安放…植物」
	await ready_set_plant()
	## 演示提示：灌木的四条口径（提示条留到打完，想提前收就 hide_hint()）
	await hint("灌木占一格种不下植物，还会挡住大多数植物的视线；爆杀植物 / 小推车能摧毁它，最终波每丛灌木各冒出一只")
	## 开战：打到最后一波清完为止
	await start_battle(WAVE_NUM, zombie_list)
	await hide_hint()
