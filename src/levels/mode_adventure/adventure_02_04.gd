extends LevelScriptBase
## adventure_02_04 —— 由同目录的 adventure_02_04.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.FrontNight
	is_day = false
	is_day_sun = false
	is_have_tombston = true
	init_tombstone_num = 7


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
	]

	## 戴夫推销卡槽扩充（2-2 ~ 3-4 这几关都有；钱不够时戴夫不来，见 LevelScriptBase.dave_sell_card_slot）
	await dave_sell_card_slot()
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
