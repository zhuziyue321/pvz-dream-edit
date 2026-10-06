extends LevelScriptBase
## adventure_04_01 —— 由同目录的 adventure_04_01.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 关卡开场戴夫对话：在 run_flow() 里现场构造并传给 dave_dialog
func _build_dave_dialog() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_0 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 4-1 开场（进入浓雾场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_801~803
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 4-1 段
	## 原版冒险模式 4-1 开场（进入浓雾场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_801~803
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 4-1 段
	## 原版冒险模式 4-1 开场（进入浓雾场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_801~803
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 4-1 段
	crazy_dave_dialog_detail_resource_0.text = "你知道，他们曾叫我 “迷雾男”。"
	var crazy_dave_dialog_detail_resource_1 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 4-1 开场（进入浓雾场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_801~803
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 4-1 段
	## 原版冒险模式 4-1 开场（进入浓雾场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_801~803
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 4-1 段
	## 原版冒险模式 4-1 开场（进入浓雾场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_801~803
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 4-1 段
	crazy_dave_dialog_detail_resource_1.text = "因为我曾停留在雾中并突然跳出来，吓呆了一大群人！"
	var crazy_dave_dialog_detail_resource_2 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 4-1 开场（进入浓雾场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_801~803
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 4-1 段
	## 原版冒险模式 4-1 开场（进入浓雾场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_801~803
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 4-1 段
	## 原版冒险模式 4-1 开场（进入浓雾场景）戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_801~803
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 4-1 段
	crazy_dave_dialog_detail_resource_2.text = "噢，那都是过去的事了。"
	var crazy_dave_dialog_resource_0 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_0.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_0, crazy_dave_dialog_detail_resource_1, crazy_dave_dialog_detail_resource_2])
	return crazy_dave_dialog_resource_0


func _init() -> void:
	## 场景：泳池·浓雾 —— 槽位 / 底图 / BGM / 雾 / 昼夜 / 天降阳光全由场景脚本给出
	scene_name = SceneSettingRegistry.SCENE_FOG
	dave_dialog_only_first_playthrough = true


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z016Jackbox,
	]

	## 关卡戴夫对话
	await dave_dialog(_build_dave_dialog())
	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(10, zombie_list)


