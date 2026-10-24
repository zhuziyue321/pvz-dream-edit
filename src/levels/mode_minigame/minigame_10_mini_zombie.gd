extends LevelScriptBase
## minigame_10_mini_zombie —— 原版迷你游戏**第 10 关**「小小大僵尸」(Big Trouble Little Zombie)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ 存档键沿用改名之前写死的值（102_0_0003），**不跟着序号改**：改了会让玩家已通关的记录错位。


func _init() -> void:
	save_key = "102_0_0003"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	## 例外：本关是泳池场地，原版却播通用小游戏曲 Loonboon（与冒险 3-5 小僵尸大麻烦同源；用户实机确认）
	game_BGM = ConstLevelData.GameBGM.MiniGame
	is_day_sun = false
	can_choosed_card = false
	## 出怪倍率 = 4：原版 Little Trouble 在 ×4 分支里（Board.cpp:671-674）。
	## 此前是 10（无原版依据，每波出怪数是原版的 2.5 倍）
	zombie_multy = 4
	## 波长：原版本关写死 `mZombieCountDown = 750` tick = 7.5 秒（不是通用的 25~31 秒）
	wave_norm_time_range = Vector2(7.5, 7.5)
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	## 原版本关传送带只给这 4 种（Challenge.cpp Little Trouble：荷叶 / 坚果 / 豌豆 / 樱桃），
	## 权重照原版 LilyPad25 / Wallnut15 / Peashooter25 / CherryBomb35
	conveyor_weights = ResourceCardWeight.create_plant_weights({
		&"lily_pad": 25,
		&"wall_nut": 15,
		&"pea_shooter_single": 25,
		&"cherry_bomb": 35,
	})
	## 原版无固定出卡顺序：去掉这里曾写的固定序号（其中 44=猫尾，不在上面的 4 种池里）
	conveyor_order = ResourceCardReference.create_plant_order({})


## 本关专属：所有正常出战僵尸启用迷你规则
func get_zombie_init_para_extra() -> Dictionary:
	return {
		Zombie000Base.E_ZInitAttr.IsMiniZombie: true,
	}


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	## 出怪表：对齐原版 Little Trouble 白名单（Challenge.cpp：普/路障/橄榄球/潜水）
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.FOOTBALL,
		ZombieIds.SNORKLE,
	]

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
	## 开战：30 波（原版 LITTLE_TROUBLE 在 30 波那一档，Board.cpp:603-606；此前写 20）
	## 首波 2 秒：原版小僵尸大麻烦 `mZombieCountDown = 200` tick
	await start_battle(30, zombie_list, 0.0, 2.0)
