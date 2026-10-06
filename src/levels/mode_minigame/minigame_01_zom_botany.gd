extends LevelScriptBase
## minigame_01_zom_botany —— 原版迷你游戏**第 1 关**「植物僵尸」(ZomBotany)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ 存档键沿用改名之前写死的值（102_1_0022），**不跟着序号改**：改了会让玩家已通关的记录错位。
##
## 原版 ZomBotany 是**白天**前院、2 面旗帜（= 20 波），只出豌豆僵尸与坚果僵尸
## （数据来源: PVZ Wiki https://plantsvszombies.wiki.gg/wiki/ZomBotany）。
## 本关出怪表已对齐原版：只有 Z031 豌豆僵尸 + Z032 坚果僵尸两只
## （此前保留过仓库自己加的那一批扩展植物僵尸 —— 寒冰 / 火炬 / 磁力菇 / 南瓜 / 投手系 … —— 比原版难，
##  需要加料时把类型加回下面的 zombie_list 即可，数据都在 ZomBotanyConfig）。


func _init() -> void:
	save_key = "102_1_0022"
	## 原版是白天前院 5 行草地：地图必须选 MainGameFront（→ map_front.tres）。
	## 此前写成 MainGameBack（→ map_pool.tres 泳池图）配 FrontDay 底图，
	## 表现为「前院底图上凭空出现两条水道 + 水路小推车」，底图与地图对不上
	game_sences = MainSceneRegistry.MainScenes.MainGameFront
	## 原版是白天（此前写成 FrontNight + 强开天降阳光，背景与玩法对不上）
	game_BG = ConstLevelData.GameBg.FrontDay
	## 原版本关播白天曲「Grasswalk」，不是通用小游戏曲（用户实机确认）
	## ⚠️ wiki 音乐页写的 "Most of the Mini-games … feature the track Loonboon" 与实机不符，以实机为准
	game_BGM = ConstLevelData.GameBGM.FrontDay
	zombie_multy = 10
	## 原版是自由选卡，卡槽模式保持默认 Norm：
	## 写成 Null 会被 _apply_card_mode_constraints() 压成 can_choosed_card = false，
	## 而关卡又没有预选卡 —— 结果是一张植物都带不进去，这关直接没法打


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	## 原版口径：只出豌豆僵尸 + 坚果僵尸两只植物僵尸，不出普僵
	## （旗帜波仍会由波次管理器补旗子僵尸 + 普僵，那是本体波次逻辑，不是本关出怪表）
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z031PeaShooterZombie,
		CharacterRegistry.ZombieType.Z032WallNutZombie,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(20, zombie_list)
