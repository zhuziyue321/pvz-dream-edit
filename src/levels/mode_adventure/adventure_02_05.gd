extends LevelScriptBase
## adventure_02_05 —— 由同目录的 adventure_02_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 关卡开场戴夫对话：在 run_flow() 里现场构造并传给 dave_dialog
## 原版冒险模式 2-5 开场（锤僵尸关：戴夫拿「打地鼠」作比介绍本关玩法）
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Level_2-5?action=raw) 的 Dialogue 段
## 中文台词按游戏中文版语音转写(https://www.ximalaya.com/ask/a23193331)，与 wiki 英文原文逐句对应
## 待核实: 第 5 句 mallet 的转写原文作「短鎚」，这里按本仓库锤子道具的叫法取「木槌」
func _build_dave_dialog() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_0 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_0.text = "你玩过“打僵尸”的游戏吗？"
	var crazy_dave_dialog_detail_resource_1 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_1.text = "这就像是玩打地鼠。"
	var crazy_dave_dialog_detail_resource_2 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_2.text = "你看，那些毛茸茸的小老鼠是在你的草坪里打洞吗？"
	var crazy_dave_dialog_detail_resource_3 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_3.text = "耶，就像那样，但不是鼹鼠，而是僵尸。"
	var crazy_dave_dialog_detail_resource_4 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_4.text = "而且不是铁锹，是木槌。"
	var crazy_dave_dialog_detail_resource_5 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_5.text = "当然不是我，是你！"
	var crazy_dave_dialog_resource_0 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_0.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_0, crazy_dave_dialog_detail_resource_1, crazy_dave_dialog_detail_resource_2, crazy_dave_dialog_detail_resource_3, crazy_dave_dialog_detail_resource_4, crazy_dave_dialog_detail_resource_5])
	return crazy_dave_dialog_resource_0


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
	await dave_dialog(_build_dave_dialog())
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


