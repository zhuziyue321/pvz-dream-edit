extends LevelScriptBase
## ★ 二周目版（adventure_05_10_round2）—— 二周目及以后进这一关时加载的就是本文件：
##   进关方按周目取脚本（LevelRegistry.get_adventure_level_id(关卡序号, 周目)），
##   正本 adventure_05_10.gd 与它是**同一关的两套脚本**，存档键仍是同一份（二周目的进度靠记录里的 Round 区分）。
##   本文件与正本的差异（见 docs/参考存档/二周目.md）：
##     · 波数：-1 波，与一周目相同（本关按要求不加波）
##     · 开局锁定前 3 个随机卡槽：从本关能用的植物里随机挑 3 株占住前 3 槽，玩家只能改后面的槽
## adventure_05_10 —— 由同目录的 adventure_05_10.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	save_key = "101_4_0050"
	## 二周目差异：开局锁定前 3 个随机卡槽 —— 从本关能用的植物里随机挑 3 株占住前 3 槽，
	## 玩家只能编辑第 4 个槽起的部分（机制与边界见 docs/参考存档/二周目.md）
	locked_random_card_num = 3
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	## 僵王关是夜屋顶：几何与 map_roof 逐格相同，换的是夜色底图与背景子场景
	## （见 docs/参考存档/特殊关卡.md），地图由本关显式指定，不再靠场景槽位区分
	map_data = preload("res://data/map/map_boss.tres") as ResourceMapData
	game_BG = ConstLevelData.GameBg.Boss
	game_BGM = ConstLevelData.GameBGM.Boss
	is_day = false
	is_day_sun = false
	## 出怪倍率：本关不自然出怪（僵尸全由僵王投放），此值不生效；
	## 写 1 与原版一致（僵王关不在任何点数倍率分支里，Board.cpp:666-686）。此前是 3（无依据）
	zombie_multy = 1
	is_bungi = true
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	monster_mode = ConstLevelData.E_MonsterMode.Null
	## 僵王博士：开战（boss_spawn_wave = 0）由 ZombieManager 自动出场，胜利条件为「打死僵王」
	boss_type = ZombieBossIds.DOCTOR
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
	&"cabbage_pult": 2,
	&"flower_pot": 2,
	&"corn_pult": 2,
	&"melon_pult": 2,
	&"jalapeno": 2,
	&"ice_shroom": 2
	})


func run_flow(mg: MainGameManager) -> void:
	await plant_flower_pot_columns(4)
	## 出怪表：本关的僵尸全部由僵王投放，开战时要带上这一份
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.POLE_VAULTER,
		ZombieIds.BUCKET,
		ZombieIds.PAPER,
		ZombieIds.SCREEN_DOOR,
		ZombieIds.FOOTBALL,
		ZombieIds.JACKSON,
		ZombieIds.JACKBOX,
		ZombieIds.LADDER,
		ZombieIds.CATAPULT,
		ZombieIds.GARGANTUAR,
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
	mg.card_manager.set_conveyor_card_interval_scale(0.5)
	## 僵王战传送带权重：场上空花盆少了就少给花盆，带上花盆堆到 4 个就把位置让给寒冰菇 / 辣椒
	mg.card_manager.add_conveyor_weight_rule(ZombossConveyorWeightRule.new())
	## 开战
	await start_battle(-1, zombie_list)
	## 本关没有通关奖励（全 50 关里就这 6 关没有：x-9 / 5-10，原版也不给东西），
	## 所以本关没写 level_complete_loot —— 掉奖杯兜底
	if is_curr_level_success():
		win_with_trophy_only()
	else:
		await gain(LootRegistry.TROPHY)
