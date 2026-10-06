extends LevelScriptBase
## survival_flag_10_roof —— 由同目录的 survival_flag_10_roof.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_round = 10
	game_BG = ConstLevelData.GameBg.Roof
	game_BGM = ConstLevelData.GameBGM.Roof
	is_bungi = true


func run_flow(_mg: MainGameManager) -> void:
	await plant_flower_pot_columns(4)
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z019Pogo,
		CharacterRegistry.ZombieType.Z016Jackbox,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z022Ladder,
		CharacterRegistry.ZombieType.Z023Catapult,
		CharacterRegistry.ZombieType.Z024Gargantuar,
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
