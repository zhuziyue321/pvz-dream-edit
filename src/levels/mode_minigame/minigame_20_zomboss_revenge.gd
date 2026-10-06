extends LevelScriptBase
## minigame_20_zomboss_revenge —— 原版迷你游戏**第 20 关**「僵尸博士的复仇」(Dr. Zomboss's Revenge)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 打法与冒险 5-10 一致：僵王自己投放僵尸（monster_mode = Null，不自然出怪），
## 胜利条件从「打完最后一波」变成「打死僵王」。
##
## ⚠️ 空实现：骨架照抄 adventure_05_10，僵王的「复仇版」参数还没接：
##   TODO(僵尸博士的复仇) 原版僵王血量是 5-10 的**两倍**，且放僵尸更频繁；
##                     血量在僵王场景的 HpComponent 上；要调就改 CharacterRegistry.ZombieBossInfo / 僵王场景


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0018"
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	## 僵王关是夜屋顶：与 map_roof 逐格相同，换的是夜色底图（见 docs/参考存档/特殊关卡.md）
	map_data = preload("res://data/map/map_boss.tres") as ResourceMapData
	game_BG = ConstLevelData.GameBg.Boss
	game_BGM = ConstLevelData.GameBGM.Boss
	is_day_sun = false
	zombie_multy = 3
	is_bungi = true
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	monster_mode = ConstLevelData.E_MonsterMode.Null
	## 僵王博士：与冒险 5-10 同口径，开战时自动出场，胜利条件为「打死僵王」
	boss_type = CharacterRegistry.ZombieBossType.ZB001Doctor
	boss_spawn_wave = 0
	## 原版「僵尸博士的复仇」僵王血量 60000；破损阈值按上限比例缩放为 30000 / 15000
	boss_hp = 60000
	## 出生点固定：由 ZB000Base.FIXED_SPAWN_POSITION 硬编码，关卡不再配置。
	win_on_boss_death = true
	## 出怪预览为空：与冒险 5-10 同口径，本关不自然出怪（僵尸全由僵王投放），
	## 原版开局那段「看僵尸」一只不出，连「镜头右移看僵尸」也不跑
	look_show_zombie = false
	## 没有预览这段镜头，进关就停在归位位（否则整段登场都在拍左侧房子）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	33: 2,
	34: 2,
	35: 2,
	40: 2,
	21: 2,
	15: 2
	})


func run_flow(_mg: MainGameManager) -> void:
	## 夜屋顶要花盆才能种：先给左侧 4 列铺上（与 adventure_05_10 同一套写法）
	await plant_flower_pot_columns(4)
	## 出怪表：本关的僵尸全部由僵王投放，这里列出的是它手里的牌
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z006Paper,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z009Jackson,
		CharacterRegistry.ZombieType.Z016Jackbox,
		CharacterRegistry.ZombieType.Z022Ladder,
		CharacterRegistry.ZombieType.Z023Catapult,
		CharacterRegistry.ZombieType.Z024Gargantuar,
	]

	## 没有僵尸预览：本关不自然出怪，出怪预览为空（look_show_zombie = false），
	## 连「镜头右移看僵尸 / 移回相机」这两步一起不跑，直接进僵王登场
	## 僵王由 ZombieManager 在开战那一刻出场（boss_spawn_wave = 0），关卡脚本不放它进场
	## 准备-安放-植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 僵王战：传送带出卡间隔减半（出卡速度翻倍），与冒险 5-10 同一套 boss 战口径
	_mg.card_manager.set_conveyor_card_interval_scale(0.5)
	## 僵王战传送带权重：场上空花盆少了就少给花盆，带上花盆堆到 4 个就把位置让给寒冰菇 / 辣椒
	_mg.card_manager.add_conveyor_weight_rule(ZombossConveyorWeightRule.new())
	## 开战
	await start_battle(-1, zombie_list)
