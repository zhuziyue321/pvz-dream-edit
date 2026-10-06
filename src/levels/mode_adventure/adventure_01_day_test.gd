extends LevelScriptBase
## adventure_01_day_test —— 由同目录的 adventure_01_day_test.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	monster_mode = ConstLevelData.E_MonsterMode.Null
	max_choosed_card_num = 15
	start_sun = 5210
	prechosen_cards = ResourceCardReference.create_plant_list([1001, 1002, 1003])


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
	await start_battle(10)
