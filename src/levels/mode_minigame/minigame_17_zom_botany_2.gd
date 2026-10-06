extends LevelScriptBase
## minigame_17_zom_botany_2 —— 原版迷你游戏**第 17 关**「植物僵尸 2」(ZomBotany 2)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 玩法与「植物僵尸」(minigame_01_zom_botany) 同源：僵尸头顶插着一棵植物，
## 耐久与能力都来自那棵植物（配置表见 src/entities/character/components/zombie_plant_component/zom_botany_config.gd）。
## 相对第 1 关，原版换成了泳池场景，并新加了火爆辣椒僵尸 / 窝瓜僵尸 / 机枪僵尸 / 高坚果僵尸
## （数据来源: PVZ Wiki https://plantsvszombies.wiki.gg/wiki/ZomBotany_2）。
##
## 已逐个核对的 4 只新僵尸（2026-10-04）：
##   Z033Squash 窝瓜僵尸 —— zombie_squash.gd：碰到植物 1800 穿透伤害后自毁；原版它没有鸭子圈版本，
##                          所以 ZombieInfo 里行类型写成 Land，不会出现在水面行
##   Z034Jalapeno 火爆辣椒僵尸 —— zombie_jalapeno.gd：碰到植物烧掉整行后自毁
##   Z035Gatling 机枪僵尸 —— component_attack_zom_botany.gd + 场景里 burst_num = 4
##   Z044TallNut 高坚果僵尸 —— 本次新增（原版的第 4 只新增，此前仓库用南瓜僵尸顶替这个位置），耐久 2200
##
## 原版本关是 3 面旗帜 = 30 波（关 1 是 2 面旗帜 = 20 波），见 docs/参考存档/僵尸波次.md。
##
## 水面行不出「鸭子圈僵尸」：Z011Duckytube 不在本场景的自然刷怪白名单里（会被 init_para 过滤掉），
## 泳池关的水面行由**两栖**（ZombieRowType.Both）僵尸顶上，它们入水会自己套上鸭子圈。


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0015"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	## 场景曲：本关是泳池 → 泳池曲 Watery Graves
	game_BGM = ConstLevelData.GameBGM.Pool
	zombie_multy = 10


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z031PeaShooterZombie,
		CharacterRegistry.ZombieType.Z032WallNutZombie,
		CharacterRegistry.ZombieType.Z033SquashZombie,
		CharacterRegistry.ZombieType.Z034JalapenoZombie,
		CharacterRegistry.ZombieType.Z035GatlingZombie,
		CharacterRegistry.ZombieType.Z036SnowPeaZombie,
		CharacterRegistry.ZombieType.Z037TorchwoodZombie,
		CharacterRegistry.ZombieType.Z038MagnetShroomZombie,
		CharacterRegistry.ZombieType.Z039PumpkinZombie,
		CharacterRegistry.ZombieType.Z040CabbagePultZombie,
		CharacterRegistry.ZombieType.Z042MelonPultZombie,
		CharacterRegistry.ZombieType.Z043WinterMelonZombie,
		## 原版 ZomBotany 2 的 4 只新增里唯一此前缺的一只
		CharacterRegistry.ZombieType.Z044TallNutZombie,
		CharacterRegistry.ZombieType.Z001Norm,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战（原版 3 面旗帜 = 30 波）
	await start_battle(30, zombie_list)
