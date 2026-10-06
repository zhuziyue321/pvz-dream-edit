extends LevelScriptBase
## minigame_18_bowling_2 —— 原版迷你游戏**第 18 关**「坚果保龄球 2」(Wall-Nut Bowling 2)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 玩法与「坚果保龄球」(minigame_02_bowling) 同源：传送带送坚果，砸过去打僵尸。
## 相对第 2 关，原版加了纱门僵尸 / 舞王僵尸 / 伴舞僵尸，以及会压扁一路僵尸的**巨型坚果墙**
## （P1003WallNutBowlingBig，已登记在 CharacterRegistry）。
##
## ⚠️ 空实现：骨架与出怪表按原版摆好了，但加强版特有的部分还没验：
##   TODO(坚果保龄球 2) 巨型坚果墙压扁整行僵尸的行为确认已实现，并把它接进传送带权重
##   TODO(坚果保龄球 2) 原版第 2 关只有普通 / 摇旗 / 路障 / 铁桶 / 撑杆，本关换成下面这批，逐个验一遍


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0016"
	game_BG = ConstLevelData.GameBg.FrontDay
	## 例外：本关是白天场地，原版却播通用小游戏曲 Loonboon（与坚果保龄球同源；用户实机确认）
	game_BGM = ConstLevelData.GameBGM.MiniGame
	is_day_sun = false
	look_show_zombie = false
	can_choosed_card = false
	## 进关就停在相机归位位（保龄球关没有预览僵尸 / 选卡，不该先拍房子）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x
	zombie_multy = 3
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	## 传送带送的三种「保龄球」：坚果 / 爆炸坚果 / 巨型坚果墙
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
		CharacterRegistry.ZombieType.Z002Flag,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z009Jackson,
		CharacterRegistry.ZombieType.Z010Dancer,
	]

	if mg.curr_game_round == 1:
		## 保龄球红线（仅第 1 轮）
		await bowling_stripe()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(20, zombie_list)
