extends LevelScriptBase
## adventure_02_05 —— 由同目录的 adventure_02_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 本关开场戴夫对话（锤僵尸关：戴夫拿「打地鼠」作比介绍本关玩法）
## 台词在数据层，见 res://data/dave/dialog/adventure_02_05_opening.tres
## 待核实: 第 5 句 mallet 的转写原文作「短鎚」，这里按本仓库锤子道具的叫法取「木槌」
const DAVE_OPENING := preload("res://data/dave/dialog/adventure_02_05_opening.tres")


func _init() -> void:
	## 特殊关(锤僵尸)用 Loonboon,来源: https://plantsvszombies.wiki.gg/wiki/Music_(PvZ)
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.MiniGame
	is_day = false
	is_day_sun = false
	look_show_zombie = false
	can_choosed_card = false
	## 进关就停在相机归位位（锤僵尸关没有预览僵尸 / 选卡，不该先拍房子）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x
	monster_mode = ConstLevelData.E_MonsterMode.HammerZombie
	is_have_tombston = true
	init_tombstone_num = 9
	max_choosed_card_num = 3
	start_sun = 0
	prechosen_cards = ResourceCardReference.create_plant_list([5, 12, 3])


## 进关时装上「锤僵尸」玩法（与迷你游戏 15 共用同一条规则，见 LevelRuleHammerZombie）
func init_level_items(mg: MainGameManager, _item_root: Node2D) -> void:
	LevelRuleHammerZombie.install(mg)


func run_flow(_mg: MainGameManager) -> void:
	## 关卡戴夫对话
	await dave_dialog(DAVE_OPENING)
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(10, [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
	])
