extends LevelScriptBase
## minigame_02_bowling —— 原版迷你游戏**第 2 关**「坚果保龄球」(Wall-Nut Bowling)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ 存档键沿用改名之前写死的值（102_0_0001），**不跟着序号改**：改了会让玩家已通关的记录错位。


func _init() -> void:
	save_key = "102_0_0001"
	## 例外：本关是白天场地，原版却播通用小游戏曲 Loonboon（用户实机确认）
	game_BGM = ConstLevelData.GameBGM.MiniGame
	is_day_sun = false
	look_show_zombie = false
	can_choosed_card = false
	## 进关就停在相机归位位（保龄球关没有预览僵尸 / 选卡，不该先拍房子）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x
	zombie_multy = 3
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
	if mg.curr_game_round == 1:
		## 保龄球红线（仅第 1 轮）
		await bowling_stripe()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(20)
