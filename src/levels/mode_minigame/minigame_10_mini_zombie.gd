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
	zombie_multy = 10
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	&"pea_shooter_single": 2,
	&"cherry_bomb": 1,
	&"wall_nut": 2,
	&"snow_pea": 2,
	&"pea_shooter_double": 2,
	&"lily_pad": 5,
	&"squash": 1,
	&"three_peater": 2,
	&"jalapeno": 1,
	&"torch_wood": 2,
	&"cattail": 1
	})
	conveyor_order = ResourceCardReference.create_plant_order({
	1: &"lily_pad",
	5: 44
	})


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
	var zombie_list: Array[StringName] = [
		ZombieIds.JACKSON,
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.POLE_VAULTER,
		ZombieIds.BUCKET,
		ZombieIds.SCREEN_DOOR,
		ZombieIds.FOOTBALL,
		ZombieIds.JACKBOX,
		ZombieIds.DOLPHINRIDER,
		ZombieIds.POLE_VAULTER,
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
	await start_battle(20, zombie_list)
