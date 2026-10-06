extends LevelScriptBase
## adventure_02_01 —— 由同目录的 adventure_02_01.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


## 关卡开场戴夫对话：在 run_flow() 里现场构造并传给 dave_dialog
func _build_dave_dialog() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_0 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_0.text = "晚上好，{PLAYER_NAME}。"
	var crazy_dave_dialog_detail_resource_1 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_1.text = "那些僵尸不会那么容易就放弃吧？"
	var crazy_dave_dialog_detail_resource_2 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_2.text = "你会注意到夜间和僵尸作战不同于白天。"
	var crazy_dave_dialog_detail_resource_3 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_3.text = "首先，不能从天上得到阳光。"
	var crazy_dave_dialog_detail_resource_4 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_4.text = "但你仍可以通过向日葵来获得阳光。"
	var crazy_dave_dialog_detail_resource_5 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_5.text = "而且你很幸运，你得到了小喷菇。"
	var crazy_dave_dialog_detail_resource_6 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_6.text = "尽可能多地种植这些蘑菇吧，你会挺过去的。"
	var crazy_dave_dialog_resource_0 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_0.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_0, crazy_dave_dialog_detail_resource_1, crazy_dave_dialog_detail_resource_2, crazy_dave_dialog_detail_resource_3, crazy_dave_dialog_detail_resource_4, crazy_dave_dialog_detail_resource_5, crazy_dave_dialog_detail_resource_6])
	return crazy_dave_dialog_resource_0


func _init() -> void:
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.FrontNight
	is_day = false
	is_day_sun = false
	dave_dialog_only_first_playthrough = true
	is_have_tombston = true
	init_tombstone_num = 4


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z006Paper,
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


