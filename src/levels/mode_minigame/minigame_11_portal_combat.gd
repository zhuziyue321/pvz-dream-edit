extends LevelScriptBase
## minigame_11_portal_combat —— 原版迷你游戏**第 11 关**「斗转星移」(Portal Combat)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 传送门机制（两对门、子弹 / 僵尸穿门方向不变、定期换位）由 PortalManager 接管，
## 开关 is_portal_combat 见 docs/参考存档/斗转星移传送门.md


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0011"
	## 场景曲：本关是夜晚前院 → 夜晚曲 Moongrains
	game_BGM = ConstLevelData.GameBGM.FrontNight
	## 原版是夜晚关：蘑菇要咖啡豆叫醒、不天降阳光
	game_BG = ConstLevelData.GameBg.FrontNight
	is_day = false
	is_day_sun = false
	zombie_multy = 2
	## 斗转星移：草坪上两对传送门（一对方形一对圆形），每 15 秒随机换一次位置
	is_portal_combat = true
	portal_reshuffle_interval = 15.0


func run_flow(_mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z008Football,
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
