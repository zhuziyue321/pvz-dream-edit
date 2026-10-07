extends LevelScriptBase
## adventure_01_05 —— 由同目录的 adventure_01_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。
##
## 本关的铲子教学是「**开场演出**」：整段排在预览僵尸之前（原版：戴夫让你先清草坪，
## 清完才介绍保龄球、才预览僵尸），所以它写在 run_flow() 的前半段。


## 本关两段戴夫对话：台词都在数据层，见 res://data/dave/dialog/adventure_01_05_*.tres
## surprise 那段的「我们去玩保龄球！」一句带 on_talk_event，念到时触发保龄球红线
const DAVE_OPENING := preload("res://data/dave/dialog/adventure_01_05_opening.tres")
const DAVE_SURPRISE := preload("res://data/dave/dialog/adventure_01_05_surprise.tres")


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


func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
	]

	## 开场演出（戴夫让你清草坪 → 铲子教学 → 戴夫介绍保龄球）只在首次进本关时播：
	## 已通关过就直接摆红线、预览僵尸（原版：教程只在冒险模式第一轮出现）
	if mg.curr_game_round == 1 and not is_curr_level_success():
		await dave_dialog(DAVE_OPENING)
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
		await dave_dialog(DAVE_SURPRISE)
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
