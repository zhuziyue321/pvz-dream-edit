extends LevelScriptBase
## adventure_05_roof_test —— 由同目录的 adventure_05_roof_test.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_BG = ConstLevelData.GameBg.Roof
	game_BGM = ConstLevelData.GameBGM.Roof
	is_bungi = true
	start_sun = 50000
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	&"cherry_bomb": 1,
	&"chomper": 1,
	&"squash": 1,
	&"jalapeno": 1,
	&"cabbage_pult": 1,
	&"flower_pot": 1,
	&"corn_pult": 1,
	&"melon_pult": 1
	})
	conveyor_order = ResourceCardReference.create_plant_order({
	0: &"potato_mine",
	1: &"tall_nut",
	2: &"melon_pult",
	3: &"magnet_shroom",
	4: &"coffee_bean",
	9: 45
	})
	create_new_card_speed = 1.5


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 本关是屋顶测试关：第 1 列走模仿者材质（灰花盆），顺手验「系统种植」的模仿者分支
	var pots := SystemPlantResource.create_flower_pot_columns(2)
	pots[0].is_imitater_plant = true
	await system_plant(pots)
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.SCREEN_DOOR,
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.BUCKET,
		ZombieIds.PAPER,
		ZombieIds.FOOTBALL,
		ZombieIds.GARGANTUAR,
		ZombieIds.LADDER,
		ZombieIds.JACKSON,
		ZombieIds.DOLPHINRIDER,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(-1, zombie_list)
	## 通关掉落：测试关没有奖励，掉奖杯兜底
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(LootRegistry.TROPHY)
