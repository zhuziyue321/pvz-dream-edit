extends LevelScriptBase
## adventure_01_10 —— 由同目录的 adventure_01_10.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	game_BGM = ConstLevelData.GameBGM.UltimateBattle
	is_day_sun = false
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	1: 2,
	3: 2,
	4: 2,
	5: 2,
	6: 2,
	7: 2,
	8: 2
	})


func run_flow(_mg: MainGameManager) -> void:
	## 展示僵尸
	await show_zombie()
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(20)
