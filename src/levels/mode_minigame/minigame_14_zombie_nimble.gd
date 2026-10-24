extends LevelScriptBase
## minigame_14_zombie_nimble —— 原版迷你游戏**第 14 关**「僵尸快跑」(Zombie Nimble Zombie Quick)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 玩法：**全场提速** —— 僵尸跑两倍快，植物也射两倍快（两边一起提，只快一方难度会失衡）。
## 走的是 `ResourceLevelData.speed_factor_zombie / speed_factor_plant` 两个恒定倍率，
## 不是锤僵尸模式那套每波递增的 `speed_zombie_*`。
## 倍率在角色进场时下发（ZombieManager.create_norm_zombie / PlantCell.create_plant），
## 与冰冻减速、黄油定身共用同一套速度因子乘法，互不覆盖。


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0013"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	## 场景曲：本关是泳池 → 泳池曲 Watery Graves
	game_BGM = ConstLevelData.GameBGM.Pool
	## 出怪倍率 = 1：原版点数倍率分支（Board.cpp:666-686）不含 SPEED。
	## 此前是 2（无原版依据）；本关的难度在设计上是「全场提速」，不是「僵尸更多」
	zombie_multy = 1
	## 全场加速（1.0 = 原速，2.0 = 两倍快）
	speed_factor_zombie = 2.0
	speed_factor_plant = 2.0


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	## 出怪表：对齐原版 SPEED 白名单（Challenge.cpp：普/路障/海豚/撑杆）
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.DOLPHINRIDER,
		ZombieIds.POLE_VAULTER,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战（原版 SPEED 无专属波数，落默认 else 分支 = 40 波 / 4 旗；此前误写 20）
	await start_battle(40, zombie_list)
