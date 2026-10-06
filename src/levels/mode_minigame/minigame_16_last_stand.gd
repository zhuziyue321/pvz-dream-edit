extends LevelScriptBase
## minigame_16_last_stand —— 原版迷你游戏**第 16 关**「坚不可摧」(Last Stand)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 玩法（原版）：开局给一笔阳光，玩家**先把防线种满再点「开始战斗！」**；
##   本关没有阳光收入（不能带产阳光的植物、天上也不掉阳光），靠每波补给的 250 撑下去；
##   撑过 5 面旗帜（50 波）通关。

## 开局阳光：全关的布阵本钱，花完就没有了
const SUN_START := 5000
## 每过一波补的阳光（第 1 波是开局那一波，不补）
const SUN_EVERY_WAVE := 250
## 总波数：每 10 波一面旗帜，50 波 = 5 面旗帜（原版「撑过五面旗帜」）
const MAX_WAVE := 50


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0014"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	## 场景曲：本关是泳池 → 泳池曲 Watery Graves
	game_BGM = ConstLevelData.GameBGM.Pool
	start_sun = SUN_START
	zombie_multy = 1
	## 本关没有阳光收入：天上不掉阳光（is_day_sun），阳光只有开局那笔和每波补的 250，
	## 这也是「不能带产阳光植物」的由来 —— 带了也没有后续产出可用
	is_day_sun = false
	## 布阵结束点按钮就开打，不等原版开局那 20 秒的第一波延迟
	first_wave_delay = 6.0
	## 禁选：阳光生产类（向日葵 / 阳光菇 / 双子向日葵）与免费植物（小喷菇 / 海蘑菇）
	## 模仿者是同种植物换壳（card_plant_type 不变），一并禁掉，见 ResourceLevelData.banned_plant_types_in_choose_card
	banned_plant_types_in_choose_card.assign([
		CharacterRegistry.PlantType.P002SunFlower,
		CharacterRegistry.PlantType.P010SunShroom,
		CharacterRegistry.PlantType.P042TwinSunFlower,
		CharacterRegistry.PlantType.P009PuffShroom,
		CharacterRegistry.PlantType.P025SeaShroom,
	])


func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z007ScreenDoor,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z011Duckytube,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡（本关禁掉了阳光生产类与免费植物）
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 布阵阶段：先拿开局这 5000 阳光把防线种满，点「开始战斗！」才出怪
	await wait_battle_start()

	## 每过一波补 250 阳光（信号在每波刷出时发，第 1 波那次是开局，不算「过了一波」）
	var wave_manager := mg.zombie_manager.zombie_wave_manager
	wave_manager.signal_wave_refresh.connect(func(_is_end_wave: bool) -> void:
		if wave_manager.curr_wave > 0:
			EventBus.push_event("add_sun_value", [SUN_EVERY_WAVE])
	)

	## 开战
	await start_battle(MAX_WAVE, zombie_list)
