extends LevelScriptBase
## adventure_03_05 —— 由同目录的 adventure_03_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	## 特殊关(小僵尸大麻烦)用 Loonboon,来源: https://plantsvszombies.wiki.gg/wiki/Music_(PvZ)
	game_BG = ConstLevelData.GameBg.Pool
	game_BGM = ConstLevelData.GameBGM.MiniGame
	is_day_sun = false
	## 小僵尸大麻烦:僵尸体型/血量减半、速度翻倍(见 Zombie000Base.update_mini_zombie)
	can_choosed_card = false
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	1: 2,
	3: 1,
	4: 2,
	17: 2
	})


## 本关专属：所有正常出战僵尸启用迷你规则
func get_zombie_init_para_extra() -> Dictionary:
	return {
		Zombie000Base.E_ZInitAttr.IsMiniZombie: true,
	}


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z012Snorkle,
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
