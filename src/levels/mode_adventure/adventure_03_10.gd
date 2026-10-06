extends LevelScriptBase
## adventure_03_10 —— 由同目录的 adventure_03_10.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	## 传送带关用 Ultimate Battle,来源: https://plantsvszombies.wiki.gg/wiki/Music_(PvZ)
	game_BG = ConstLevelData.GameBg.Pool
	game_BGM = ConstLevelData.GameBGM.UltimateBattle
	is_day_sun = false
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	## 传送带卡池(原版 3-10): 莲叶17 / 三线19 / 水草20 / 辣椒21 / 地刺22 / 火炬树桩23 / 高坚果24
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	17: 2,
	19: 2,
	20: 2,
	21: 2,
	22: 2,
	23: 2,
	24: 2
	})


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z012Snorkle,
		CharacterRegistry.ZombieType.Z013Zamboni,
		CharacterRegistry.ZombieType.Z014Bobsled,
		CharacterRegistry.ZombieType.Z015Dolphinrider,
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
