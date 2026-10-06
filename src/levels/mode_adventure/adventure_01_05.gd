extends LevelScriptBase
## adventure_01_05 —— 由同目录的 adventure_01_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。
##
## 本关的铲子教学是「**开场演出**」：整段排在预览僵尸之前（原版：戴夫让你先清草坪，
## 清完才介绍保龄球、才预览僵尸），所以它写在 run_flow() 的前半段。


func _init() -> void:
	## 场景：前院·白天（槽位 / 底图 / 昼夜由场景脚本给出）
	scene_name = SceneSettingRegistry.SCENE_FRONT_DAY
	## 覆盖场景默认：原版 1-5 播小游戏曲 Loonboon，且没有天降阳光
	game_BGM = ConstLevelData.GameBGM.MiniGame
	is_day_sun = false
	## 进关就停在相机归位位（保龄球关没有选卡，不该先拍房子）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x
	can_choosed_card = false
	first_wave_delay = 6.0
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	1001: 2,
	1002: 1,
	1003: 1
	})
	conveyor_order = ResourceCardReference.create_plant_order({
	0: 1001,
	1: 1002,
	2: 1003
	})
	is_bowling_stripe = true
	plant_cell_can_use.assign({
	"left_can_plant": true,
	"left_can_zombie": true,
	"right_can_plant": false,
	"right_can_zombie": true
	})


## 开场戴夫对话：在 run_flow() 里现场构造并传给 dave_dialog（只在首次进本关时播）
func _build_opening_dave_dialog() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_0 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_0.text = "你好，我的邻居！"
	var crazy_dave_dialog_detail_resource_1 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_1.text = "我的名字叫疯狂的戴夫。"
	var crazy_dave_dialog_detail_resource_2 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_2.text = "但你叫我疯狂的戴夫就行了。"
	var crazy_dave_dialog_detail_resource_3 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_3.text = "听好，我有个惊喜要给你。"
	var crazy_dave_dialog_detail_resource_4 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_4.text = "但是首先，你必须清理下你的草坪。"
	var crazy_dave_dialog_detail_resource_5 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_5.text = "用你的铲子挖出那些植物！"
	var crazy_dave_dialog_detail_resource_6 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_6.text = "开始挖吧！"
	crazy_dave_dialog_detail_resource_6.is_crazy = true
	var crazy_dave_dialog_resource_0 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_0.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_0, crazy_dave_dialog_detail_resource_1, crazy_dave_dialog_detail_resource_2, crazy_dave_dialog_detail_resource_3, crazy_dave_dialog_detail_resource_4, crazy_dave_dialog_detail_resource_5, crazy_dave_dialog_detail_resource_6])
	return crazy_dave_dialog_resource_0


## 铲光草坪后戴夫的「保龄球惊喜」对话：说到「我们去玩保龄球！」的那一句同时把红线画出来
## （红线由那一句的 on_talk_event 触发，见 CrazyDaveDialogDetailResource）
func _build_bowling_dave_dialog() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_7 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_7.text = "好的，干得不错，现在给你个惊喜……"
	var crazy_dave_dialog_detail_resource_8 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_8.text = "我们去玩保龄球！"
	crazy_dave_dialog_detail_resource_8.on_talk_event = &"show_bowling_stripe"
	var crazy_dave_dialog_detail_resource_9 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_9.text = "嘿，拿好这个坚果！"
	var crazy_dave_dialog_detail_resource_10 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_10.text = "为什么我要给你坚果？"
	var crazy_dave_dialog_detail_resource_11 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_11.text = "因为我疯了！！！！！"
	var crazy_dave_dialog_detail_resource_12 := CrazyDaveDialogDetailResource.new()
	crazy_dave_dialog_detail_resource_12.text = "现在出发！快给我赢个冠军回来！！！"
	crazy_dave_dialog_detail_resource_12.is_crazy = true
	var crazy_dave_dialog_resource_1 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_1.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_7, crazy_dave_dialog_detail_resource_8, crazy_dave_dialog_detail_resource_9, crazy_dave_dialog_detail_resource_10, crazy_dave_dialog_detail_resource_11, crazy_dave_dialog_detail_resource_12])
	return crazy_dave_dialog_resource_1


func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
	]

	## 开场演出（戴夫让你清草坪 → 铲子教学 → 戴夫介绍保龄球）只在首次进本关时播：
	## 已通关过就直接摆红线、预览僵尸（原版：教程只在冒险模式第一轮出现）
	if mg.curr_game_round == 1 and not is_curr_level_success():
		await dave_dialog(_build_opening_dave_dialog())
		## 开局草坪上的 3 株豌豆射手（原版摆在 (2,6) / (3,8) / (4,7)，都在红线右侧）：
		## 只为铲子教学服务（要玩家把它们挖光），**必须种在教学之前**
		var peashooter_cells: Array[Vector2i] = [Vector2i(2, 6), Vector2i(3, 8), Vector2i(4, 7)]
		var peashooters: Array[SystemPlantResource] = []
		for cell_pos in peashooter_cells:
			var peashooter := SystemPlantResource.new()
			peashooter.plant_type = CharacterRegistry.PlantType.P001PeaShooterSingle
			peashooter.plant_cell_pos = cell_pos
			peashooters.append(peashooter)
		await system_plant(peashooters)
		await _shovel_tutorial_flow()
		## 铲光之后戴夫才介绍保龄球（红线在这一段对话里出现）
		await dave_dialog(_build_bowling_dave_dialog())
	if mg.curr_game_round == 1:
		## 保龄球红线（仅第 1 轮）
		await bowling_stripe()
	## 展示僵尸
	await show_zombie(zombie_list)
	## 不选卡时相机停留
	await wait(3.0)
	## 相机归位
	await camera_back()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(10, zombie_list)


## 铲子教学：拿起铲子 → 铲掉一株 → 铲光草坪
## **教学期间传送带不启动**：传送带跟着「开战」走（见 MainGameManager.main_game_start），
## 所以这里敢先放玩家的手 —— 卡片不会提前从传送带上掉下来
func _shovel_tutorial_flow() -> void:
	## 允许操作：铲子教学发生在关卡开局之前，先放玩家的手（能拿铲子、能铲草坪）
	await allow_operation()
	## 箭头指到卡槽里的铲子上
	await arrow_shovel()
	await hint("点击拾取铲子！")
	await wait_take_shovel()
	## 教玩家铲掉一株
	await arrow_plant()
	await hint("点击移除一颗植物！")
	await wait_dig_plant(1)
	## 铲光为止（铲一株就用掉一把铲子，铲下一株要玩家自己再去拿）
	await hint("一直挖吧，直到你的草坪上没有植物！")
	await wait_dig_all_plants()
	## 收尾：关掉提示条与箭头
	await hint("")
	await hide_arrow()
