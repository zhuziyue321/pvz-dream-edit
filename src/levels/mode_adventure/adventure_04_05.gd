extends LevelScriptBase
## adventure_04_05 —— 由同目录的 adventure_04_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 第 1 批：戴夫介绍玩法（在 run_flow() 里现场构造并传给 dave_dialog）
func _build_dave_dialog_1() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_0 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_0.text = "我和我的哥们，弗莱科斯卡斯特-哈维，以前在无聊的时候就打花瓶。"
	var crazy_dave_dialog_detail_resource_1 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_1.text = "那么哈维不在镇上，正好你来和我一起吧，哈维二号！"
	var crazy_dave_dialog_detail_resource_2 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 4-5 开场（砸罐子关）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_2500~2502
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Level_4-5?action=raw) 的 Speech Transcript 段
	crazy_dave_dialog_detail_resource_2.text = "就按照你的意愿去打破它吧，哈维！"
	var crazy_dave_dialog_resource_0 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_0.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_0, crazy_dave_dialog_detail_resource_1, crazy_dave_dialog_detail_resource_2])
	return crazy_dave_dialog_resource_0


## 第 2 批：砸完第 1 批罐子后戴夫再摆一批
func _build_dave_dialog_2() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_3 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_3.text = "哥们儿，你把这些花瓶都打破了，干得漂亮！"
	var crazy_dave_dialog_detail_resource_4 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_4.text = "就象我打碎所有垃圾桶时那样漂亮！"
	var crazy_dave_dialog_detail_resource_5 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_5.text = "来，我给你更多的花瓶。"
	var crazy_dave_dialog_detail_resource_6 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_6.text = "小心点，别砸的太快了。"
	var crazy_dave_dialog_detail_resource_7 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 4-5 砸完第 1 批罐子后戴夫台词（戴夫再摆一批罐子）
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_2700~2704
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Level_4-5?action=raw) 的 Speech Transcript 段
	crazy_dave_dialog_detail_resource_7.text = "你不想冒出一大堆僵尸，让你手忙脚乱吧，哈哈。"
	var crazy_dave_dialog_resource_1 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_1.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_3, crazy_dave_dialog_detail_resource_4, crazy_dave_dialog_detail_resource_5, crazy_dave_dialog_detail_resource_6, crazy_dave_dialog_detail_resource_7])
	return crazy_dave_dialog_resource_1


## 第 3 批：砸完第 2 批罐子后戴夫摆最后一批
func _build_dave_dialog_3() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_8 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_8.text = "好极了！"
	var crazy_dave_dialog_detail_resource_9 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_9.text = "这应该是最后一批了。"
	var crazy_dave_dialog_detail_resource_10 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 4-5 砸完第 2 批罐子后戴夫台词（戴夫摆最后一批罐子）
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_2800~2802
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Level_4-5?action=raw) 的 Speech Transcript 段
	crazy_dave_dialog_detail_resource_10.text = "打败他们，之后你的工作就完成了！"
	var crazy_dave_dialog_resource_2 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_2.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_8, crazy_dave_dialog_detail_resource_9, crazy_dave_dialog_detail_resource_10])
	return crazy_dave_dialog_resource_2


func _init() -> void:
	is_one_shot_flow = true
	## 砸罐子关不按批次存档：罐子不进存档，续玩恢复不出任何进度，只会导致一进关就跳到第 3 批
	game_round = 3
	is_save_multi_round_data = false
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.Puzzle
	is_day = false
	is_day_sun = false
	look_show_zombie = false
	can_choosed_card = false
	is_show_ready_set_plant = false
	## 进关就停在相机归位位（砸罐子没有预览僵尸 / 选卡，不该先拍房子）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x
	monster_mode = ConstLevelData.E_MonsterMode.Null
	card_mode = ConstLevelData.E_CardMode.Null
	is_pot_mode = true
	pot_mode = ConstLevelData.E_PotMode.Fixd
	pot_col_range = Vector2i(6, 9)
	random_pot_plant.assign({
	1: 9,
	18: 2
	})
	random_pot_zombie.assign({
	1: 3,
	16: 1
	})
	pot_config_on_round.assign([{
	"pot_col_range": Vector2i(6, 9),
	"pot_hint_num": 0,
	"random_pot_plant": {
	1: 9,
	18: 2
	},
	"random_pot_zombie": {
	1: 3,
	16: 1
	}
	}, {
	"pot_col_range": Vector2i(5, 9),
	"pot_hint_num": 2,
	"random_pot_plant": {
	1: 7,
	6: 5,
	18: 1
	},
	"random_pot_zombie": {
	1: 4,
	5: 2,
	8: 1
	}
	}, {
	"pot_col_range": Vector2i(4, 9),
	"pot_hint_num": 3,
	"random_pot_plant": {
	1: 6,
	6: 6,
	13: 4
	},
	"random_pot_zombie": {
	1: 4,
	5: 2,
	9: 1,
	16: 2
	}
	}])


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z009Jackson,
		CharacterRegistry.ZombieType.Z016Jackbox,
	]

	## 第 1 批：戴夫介绍玩法
	await dave_dialog(_build_dave_dialog_1())
	## 初始化小推车：砸罐子关不播「准备安放植物」，这里是本关唯一能上推车的地方
	await init_lawn_mover()
	## 第 1 批开战：罐子在进关时就摆好了。等到本批罐子全砸开 + 场上僵尸清空
	await start_battle(10, zombie_list)
	## 第 2 批：戴夫说话（戴夫再摆一批罐子）
	await dave_dialog(_build_dave_dialog_2())
	## 第 2 批清场：清掉上批残留的植物 / 没砸开的罐子，再按第 2 轮配置摆出新一批（4 列）
	await clear_field()
	## 第 2 批开战：等到本批罐子全砸开 + 场上僵尸清空
	await start_battle(10, zombie_list)
	## 第 3 批：戴夫说话（戴夫摆最后一批罐子）
	await dave_dialog(_build_dave_dialog_3())
	## 第 3 批清场：清掉上批残留，再按第 3 轮配置摆出新一批（5 列）
	await clear_field()
	## 第 3 批开战：最后一轮，打完由砸罐子玩法自己推 create_trophy 结算
	await start_battle(10, zombie_list)


