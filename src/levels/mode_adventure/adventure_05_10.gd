extends LevelScriptBase
## adventure_05_10 —— 由同目录的 adventure_05_10.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	## 僵王关是夜屋顶：几何与 map_roof 逐格相同，换的是夜色底图与背景子场景
	## （见 docs/参考存档/特殊关卡.md），地图由本关显式指定，不再靠场景槽位区分
	map_data = preload("res://data/map/map_boss.tres") as ResourceMapData
	game_BG = ConstLevelData.GameBg.Boss
	game_BGM = ConstLevelData.GameBGM.Boss
	is_day = false
	is_day_sun = false
	zombie_multy = 3
	is_bungi = true
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	monster_mode = ConstLevelData.E_MonsterMode.Null
	## 僵王博士：开战（boss_spawn_wave = 0）由 ZombieManager 自动出场，胜利条件为「打死僵王」
	boss_type = CharacterRegistry.ZombieBossType.ZB001Doctor
	boss_spawn_wave = 0
	## 原版僵王血量 40000（机甲破损阈值 20000 / 10000，即 50% / 25%）
	boss_hp = 40000
	## 出生点固定：由 ZB000Base.FIXED_SPAWN_POSITION 硬编码，关卡不再配置。
	win_on_boss_death = true
	## 出怪预览为空：本关不自然出怪（僵尸全由僵王投放），出怪池在僵王脚本里，
	## 原版开局那段「看僵尸」也是一只不出 —— 连带着「镜头右移看僵尸」也不跑
	## （见 docs/参考存档/特殊关卡.md「僵王关」）
	look_show_zombie = false
	## 没有预览这段镜头，进关就停在归位位（否则整个登场过程都在拍左侧的房子）
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
	await plant_flower_pot_columns(4)
	## 出怪表：本关的僵尸全部由僵王投放，开战时要带上这一份
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
	## 僵王不需要关卡流程放进场：boss_spawn_wave = 0 时由 ZombieManager 在开战那一刻出场，
	## 关卡脚本不认识任何僵王关的玩法分支（硬约束 §1-8）
	## 准备-安放-植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 僵王战：传送带出卡间隔减半（出卡速度翻倍），植物按 boss 战的密度供给
	_mg.card_manager.set_conveyor_card_interval_scale(0.5)
	## 僵王战传送带权重：场上空花盆少了就少给花盆，带上花盆堆到 4 个就把位置让给寒冰菇 / 辣椒
	_mg.card_manager.add_conveyor_weight_rule(ZombossConveyorWeightRule.new())
	## 开战
	await start_battle(-1, zombie_list)
