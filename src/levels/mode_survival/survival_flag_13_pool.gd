extends LevelScriptBase
## survival_flag_13_pool —— 由同目录的 survival_flag_13_pool.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_round = 0
	game_BG = ConstLevelData.GameBg.Pool
	game_BGM = ConstLevelData.GameBGM.Pool


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z006Paper,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z008Football,
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
	await start_battle(20, zombie_list)
