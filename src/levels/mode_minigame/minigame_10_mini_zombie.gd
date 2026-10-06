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
	1: 2,
	3: 1,
	4: 2,
	6: 2,
	8: 2,
	17: 5,
	18: 1,
	19: 2,
	21: 1,
	23: 2,
	44: 1
	})
	conveyor_order = ResourceCardReference.create_plant_order({
	1: 17,
	5: 44
	})


## 本关专属：所有正常出战僵尸启用迷你规则
func get_zombie_init_para_extra() -> Dictionary:
	return {
		Zombie000Base.E_ZInitAttr.IsMiniZombie: true,
	}


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z009Jackson,
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z016Jackbox,
		CharacterRegistry.ZombieType.Z015Dolphinrider,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
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
