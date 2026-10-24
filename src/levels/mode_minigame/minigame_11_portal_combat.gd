extends LevelScriptBase
## minigame_11_portal_combat —— 原版迷你游戏**第 11 关**「斗转星移」(Portal Combat)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 本关的传送门机制（两对门、僵尸 / 子弹 / 小推车穿门、隔门索敌、出怪行权重受门影响、
## 每 60 秒换一次门）由 PortalManager 接管，开关 is_portal_combat 见
## docs/参考存档/斗转星移传送门.md。
##
## 原版口径（../PvZ-Portable-main/src/Lawn/Challenge.cpp，交叉验证 re-plants-vs-zombies）：
##   · 这关是**传送带关**（HasConveyorBeltSeedBank），不是选卡关
##   · 传送带只给 6 种植物，权重 25/20/10/15/15/15
##   · 传送带出卡间隔是普通传送带的 1.5 倍（更慢）
##   · 起始阳光 50、不天降阳光、夜晚场地


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0011"
	## 场景曲：本关是夜晚前院 → 夜晚曲 Moongrains
	game_BGM = ConstLevelData.GameBGM.FrontNight
	## 原版是夜晚关：仓库的 is_day = false 即「夜晚」（蘑菇不睡觉），
	## 且传送带关由 _apply_card_mode_constraints 自动关掉天降阳光
	game_BG = ConstLevelData.GameBg.FrontNight
	is_day = false
	is_day_sun = false
	## 出怪倍率 = 2：原版本关在 ×2 分支里（Board.cpp:683-685）
	zombie_multy = 2
	## 原版本关是传送带关：卡池固定，不选卡
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	can_choosed_card = false
	## 传送带卡池与权重照原版（Challenge.cpp:1564-1579）：
	## 豌豆射手 25 / 双发 20 / 火炬树桩 10 / 仙人掌 15 / 坚果 15 / 樱桃炸弹 15
	conveyor_weights = ResourceCardWeight.create_plant_weights({
		PlantIds.PEA_SHOOTER_SINGLE: 25,
		PlantIds.PEA_SHOOTER_DOUBLE: 20,
		PlantIds.TORCH_WOOD: 10,
		PlantIds.CACTUS: 15,
		PlantIds.WALL_NUT: 15,
		PlantIds.CHERRY_BOMB: 15,
	})
	## 原版这一关没有固定出卡顺序（只有随机池）
	conveyor_order = ResourceCardReference.create_plant_order({})
	## 传送带出卡间隔：原版本关是普通传送带的 **1.5 倍**（更慢）
	## （Challenge.cpp:1393-1396 的 aConveyorSpeedMultiplier = 1.5，那是「间隔倍数」；
	##  仓库的 create_new_card_speed 是「速度倍率」，方向相反 → 取倒数 1/1.5）
	create_new_card_speed = 1.0 / 1.5
	## 斗转星移：草坪上两对传送门（一对方形一对圆形）
	is_portal_combat = true


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	## 出怪表：对齐原版 PORTAL_COMBAT 白名单（Challenge.cpp:2338-2344：普/铁桶/橄榄球/气球）
	var zombie_list: Array[StringName] = [
		ZombieIds.NORM,
		ZombieIds.BUCKET,
		ZombieIds.FOOTBALL,
		ZombieIds.BALLOON,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 传送带关不选卡：相机在预览位停一会儿再归位
	await wait(3.0)
	## 相机归位
	await camera_back()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	## 首波 2 秒：原版传送门之战 `mZombieCountDown = 200` tick（Challenge::PortalStart 同款）
	await start_battle(20, zombie_list, 0.0, 2.0)
