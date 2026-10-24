extends LevelScriptBase
## minigame_18_bowling_2 —— 原版迷你游戏**第 18 关**「坚果保龄球 2」(Wall-Nut Bowling 2)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 玩法与「坚果保龄球」(minigame_02_bowling) 同源：传送带送坚果，砸过去打僵尸。
##
## 相对第 2 关的加强点（原版 wiki 原文：「The zombies added in this more challenging version are
## Dancing Zombie, Backup Dancers, and Screen Door Zombie」+ 新增植物 Giant Wall-nut）：
##   · 新增三种僵尸：舞王 (Z009Jackson) / 伴舞 (Z010Dancer) / 纱门 (Z007ScreenDoor)
##   · 传送带新增巨型坚果墙 (P1003WallNutBowlingBig)：种下瞬间清掉整行僵尸
## 出怪表按 wiki 的 9 种逐条对齐（见 run_flow 的 zombie_list）。
## 雪人僵尸 (Z020Yeti) 是原版「玩家此前已遇见过才会随机出现」的彩蛋，走独立机制，不在出怪表里。
##
## 数据来源: Plants vs. Zombies Wiki(https://plantsvszombies.wiki.gg/wiki/Wall-nut_Bowling_2)（一代原版口径）


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
	## 出怪倍率 = 4：原版 Wall-Nut Bowling 2 同在 ×4 分支里（Board.cpp:671-674）
	zombie_multy = 4
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	## 传送带送的三种「保龄球」：坚果 / 爆炸坚果 / 巨型坚果墙
	## 出卡概率照原版 wiki 的百分比直接当权重（create_plant_weights 内部归一化）：
	## 坚果 74% / 爆炸坚果 13% / 巨型坚果墙 13%
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	&"wall_nut_bowling": 74,
	&"wall_nut_bowling_bomb": 13,
	&"wall_nut_bowling_big": 13
	})
	conveyor_order = ResourceCardReference.create_plant_order({
	0: &"wall_nut_bowling",
	1: &"wall_nut_bowling_bomb",
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
	## 顺序照原版 wiki「Zombies」一节：普通 / 摇旗 / 路障 / 撑杆 / 铁桶 / 读报 / 纱门 / 舞王 / 伴舞
	## （伴舞由舞王自己召唤出场，原版仍把它列进名单，这里跟着登记）
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.FLAG,
		ZombieIds.CONE,
		ZombieIds.POLE_VAULTER,
		ZombieIds.BUCKET,
		ZombieIds.PAPER,
		ZombieIds.SCREEN_DOOR,
		ZombieIds.JACKSON,
		ZombieIds.DANCER,
	]

	if mg.curr_game_round == 1:
		## 保龄球红线（仅第 1 轮）
		await bowling_stripe()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	## 开战（原版 WALLNUT_BOWLING_2 = 30 波，Board.cpp 双仓一致；此前误写 20）
	## 首波 2 秒：原版坚果保龄球 2 `mZombieCountDown = 200` tick
	await start_battle(30, zombie_list, 0.0, 2.0)
