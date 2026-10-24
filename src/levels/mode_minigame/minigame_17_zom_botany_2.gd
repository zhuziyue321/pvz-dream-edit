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
## 出怪表 2026-10-23 起已裁成原版口径（只有 6 只植物僵尸，见 run_flow 里的注释）。
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
	## 原版这两关旗帜波不补「旗子僵尸 + 一批普僵」（Board.cpp 对 WAR_AND_PEAS / _2 特判），
	## 整关只有出怪表里的植物僵尸；点数残差也不再补普僵
	spawn_plain_zombie_extra = false


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	## 原版口径（PVZ Wiki ZomBotany zombies + `Board::InitZombieWaves`）：本关 = 关 1 的豌豆 / 坚果
	## + 窝瓜 / 火爆辣椒 / 机枪 / 高坚果，共 **6 只植物僵尸，没有普僵**。
	## 原版对这两关特判（旗帜波那段 `!= WAR_AND_PEAS && != WAR_AND_PEAS_2`）：
	## 既不补普通僵尸、也不补旗子僵尸 —— 本关用 `spawn_plain_zombie_extra = false` 表达。
	## 那 8 只仓库扩展植物僵尸（寒冰 / 火炬 / 磁力菇 / 南瓜 / 卷心菜 / 玉米炮 / 西瓜 / 冰瓜）已按原版移除，
	## 想加料再把类型加回本数组即可，数据都还在 ZomBotanyConfig 里。
	var zombie_list: Array[StringName] = [
		ZombieIds.PEA_SHOOTER_ZOMBIE,
		ZombieIds.WALL_NUT_ZOMBIE,
		ZombieIds.SQUASH_ZOMBIE,
		ZombieIds.JALAPENO_ZOMBIE,
		ZombieIds.GATLING_ZOMBIE,
		ZombieIds.TALL_NUT_ZOMBIE,
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
