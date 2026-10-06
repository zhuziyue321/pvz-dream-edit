extends LevelScriptBase
## puzzle_zombie_06 —— 由同目录的 puzzle_zombie_06.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	# 存档键写死：解谜模式 20 关合并成一页后按钮序号会变，写死后玩家存档不丢
	save_key = "103_1_0006"
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.Puzzle
	is_day = false
	is_day_sun = false
	is_lawn_mover = false
	look_show_zombie = false
	can_choosed_card = false
	monster_mode = ConstLevelData.E_MonsterMode.Null
	start_sun = 50
	max_choosed_card_num = 4
	prechosen_cards = ResourceCardReference.create_zombie_list([1, 4, 5, 24])
	is_zombie_mode = true
	## 原版本关的纸板植物: 豌豆射手(1) / 向日葵(2) / 寒冰射手(6) / 窝瓜(18) / 地刺(22)
	##                    火炬树桩(23) / 玉米投手(35) / 大蒜(37)
	plant_col_on_zombie_mode = 4
	all_plants_weight_on_zombie_mode.assign({
	1: 2,
	2: 6,
	6: 2,
	18: 2,
	22: 2,
	23: 1,
	35: 2,
	37: 1
	})
	all_must_plants_on_zombie_mode.assign({
	2: 5
	})
	is_bowling_stripe = true
	plant_cell_col_j = 4
	plant_cell_can_use.assign({
	"left_can_plant": false,
	"left_can_zombie": false,
	"right_can_plant": false,
	"right_can_zombie": true
	})


func run_flow(mg: MainGameManager) -> void:
	if mg.curr_game_round == 1:
		## 保龄球红线（仅第 1 轮）
		await bowling_stripe()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(-1, [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z024Gargantuar,
	])
