extends LevelScriptBase
## puzzle_zombie_10 —— 解谜模式「僵尸公敌」无尽关（原版 I, Zombie Endless）
##
## 红线列数、起始阳光、僵尸卡阵容取自原版 C++：
##   `../PvZ-Portable-main/src/Lawn/Board.cpp` → `Board::InitLevel`（起始阳光 / 僵尸卡 / 红线限制）
## 纸板植物阵型按原版 `Challenge::IZombieInitLevel` 的 ENDLESS 分支**每轮重掷**，
## 见本文件末尾的 get_zombie_mode_plant_layout()。
## 对照表见 docs/参考存档/我是僵尸原版对照.md。
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。


func _init() -> void:
	# 存档键写死：解谜模式 20 关合并成一页后按钮序号会变，写死后玩家存档不丢
	save_key = "103_1_0010"
	## -1 = 无尽关（原版 I_ZOMBIE_ENDLESS）
	game_round = -1
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.Puzzle
	is_day = false
	is_day_sun = false
	is_lawn_mover = false
	look_show_zombie = false
	can_choosed_card = false
	monster_mode = ConstLevelData.E_MonsterMode.Null
	is_shovel = false
	## 起始阳光 150（原版 `Board::InitLevel`：我是僵尸关一律 150）
	start_sun = 150
	## 本关可用僵尸 9 只（原版无尽没有巨人）：卡槽数跟随可用僵尸数
	## （不写就会退回存档的卡槽数，多余的僵尸卡会被丢弃）
	max_choosed_card_num = 9
	## 本关僵尸卡：小鬼 / 路障 / 撑杆 / 铁桶 / 蹦极 / 矿工 / 梯子 / 橄榄球 / 舞王
	## （原版 `Board::InitLevel` 的 I_ZOMBIE_ENDLESS 分支）
	prechosen_cards = ResourceCardReference.create_zombie_list([25, 3, 4, 5, 21, 18, 22, 8, 9])
	is_zombie_mode = true
	## 红线左侧 5 列（原版无尽关 aLimit = 5）：纸板植物只能占这 5 列，僵尸只能放在第 5 列起
	plant_col_on_zombie_mode = 5
	is_bowling_stripe = true
	## 红线贴在第 4 列右边缘（左区 = 第 0~4 列，正好是原版那 5 列纸板植物区）
	plant_cell_col_j = 4
	plant_cell_can_use.assign({
		"left_can_plant": false,
		"left_can_zombie": false,
		"right_can_plant": false,
		"right_can_zombie": true
	})


func run_flow(mg: MainGameManager) -> void:
	## 进关即可放僵尸：主动把阶段推到 MAIN_GAME 放出卡槽
	## （原版「我是僵尸」没有选卡 / 准备阶段，卡槽一进场就可见、玩家立刻能点卡放僵尸；
	##  原先要等「开战」事件才放卡槽，差 1~2 秒；无尽关每一轮都要重新放出来）
	await allow_operation()
	if mg.curr_game_round == 1:
		## 保龄球红线（仅第 1 轮）
		await bowling_stripe()
		## 开场提示 = 原版 IZombieStart 的 ADVICE_I_ZOMBIE_EAT_ALL_BRAINS：
		## 原版一直挂着到玩家放下第一只僵尸（Challenge.cpp 放置成功时 ClearAdvice）
		await hint("获得全部大脑，通过这一关卡！")
		await wait_zombie_appear()
		await hint("")
	## 开战（原版「我是僵尸」**没有**「准备…安放…植物」阶段：
	## 僵尸卡进关就发在手牌上，玩家直接点卡放僵尸；也没有小推车）
	await start_battle(-1, [
		ZombieIds.CONE,
		ZombieIds.POLE_VAULTER,
		ZombieIds.BUCKET,
		ZombieIds.FOOTBALL,
		ZombieIds.JACKSON,
		ZombieIds.DIGGER,
		ZombieIds.BUNGI,
		ZombieIds.LADDER,
		ZombieIds.IMP,
	])


## 无尽关的纸板植物阵型（原版 `Challenge::IZombieInitLevel` 的 ENDLESS 分支）
##
## 原版每轮换一套：先按轮次算小喷菇数量，再随机挑一个阵型；
## 仓库按同样的规则现算（第 1 轮对应原版的 stage = 0）。
func get_zombie_mode_plant_layout() -> Array[Dictionary]:
	var layout: Array[Dictionary] = []
	var stage: int = _get_endless_stage()
	## 小喷菇数量：原版按轮次递增（第 1 轮 0 个、第 2 轮 1 个，第 10 轮起上限再放宽）
	var puff_shroom_count: int = randi_range(
		clampi(2 + stage / 3, 2, 4), clampi(3 + stage / 2, 2, 6))
	if stage == 0:
		puff_shroom_count = 0
	elif stage == 1:
		puff_shroom_count = 1
	elif stage >= 10:
		puff_shroom_count = randi_range(
			clampi(2 + stage / 3, 2, 5), clampi(3 + stage / 2, 2, 7))
	## 向日葵 + 小喷菇合计 8 株（原版 aSunflowerCount = 8 - aPuffshroomCount）
	layout.append(_endless_random_plant(PlantIds.SUN_FLOWER, 8 - puff_shroom_count))
	layout.append(_endless_random_plant(PlantIds.PUFF_SHROOM, puff_shroom_count))
	## 阵型：原版先掷「是否走伤害阵」，再掷一次挑具体阵型
	var is_damage_formation: bool = randi_range(0, 4) == 0 and stage >= 1
	if is_damage_formation:
		## 伤害阵：四种之一
		match randi_range(0, 4):
			0:
				layout.append(_endless_random_plant(PlantIds.SNOW_PEA, 9))
				layout.append(_endless_random_plant(PlantIds.SPLIT_PEA, 4))
				layout.append(_endless_random_plant(PlantIds.PEA_SHOOTER_DOUBLE, 4))
			1:
				layout.append(_endless_random_plant(PlantIds.POTATO_MINE, 9))
				layout.append(_endless_random_plant(PlantIds.CHOMPER, 8))
			2:
				layout.append(_endless_random_plant(PlantIds.CALTROP, 9))
				layout.append(_endless_random_plant(PlantIds.STAR_FRUIT, 8))
			3:
				layout.append(_endless_random_plant(PlantIds.FUME_SHROOM, 9))
				layout.append(_endless_random_plant(PlantIds.MAGNET_SHROOM, 8))
			_:
				layout.append(_endless_random_plant(PlantIds.SCAREDY_SHROOM, 12))
				layout.append(_endless_random_plant(PlantIds.SUN_FLOWER, 5))
	else:
		## 普通阵：三种之一
		match randi_range(0, 5):
			0, 1, 2:
				## 混合阵
				layout.append(_endless_random_plant(PlantIds.WALL_NUT, 1))
				layout.append(_endless_random_plant(PlantIds.TORCH_WOOD, 1))
				layout.append(_endless_random_plant(PlantIds.POTATO_MINE, 1))
				layout.append(_endless_random_plant(PlantIds.CHOMPER, 2))
				layout.append(_endless_random_plant(PlantIds.PEA_SHOOTER_SINGLE, 1))
				layout.append(_endless_random_plant(PlantIds.SPLIT_PEA, 1))
				layout.append(_endless_random_plant(PlantIds.CORN_PULT, 1))
				layout.append(_endless_random_plant(PlantIds.THREE_PEATER, 1))
				layout.append(_endless_random_plant(PlantIds.SNOW_PEA, 1))
				layout.append(_endless_random_plant(PlantIds.SQUASH, 1))
				layout.append(_endless_random_plant(PlantIds.FUME_SHROOM, 1))
				layout.append(_endless_random_plant(PlantIds.UMBRELLA_LEAF, 1))
				layout.append(_endless_random_plant(PlantIds.STAR_FRUIT, 1))
				layout.append(_endless_random_plant(PlantIds.MAGNET_SHROOM, 1))
				layout.append(_endless_random_plant(PlantIds.CALTROP, 2))
			3, 4:
				## 控制阵
				layout.append(_endless_random_plant(PlantIds.TORCH_WOOD, 1))
				layout.append(_endless_random_plant(PlantIds.SPLIT_PEA, 3))
				layout.append(_endless_random_plant(PlantIds.PEA_SHOOTER_DOUBLE, 1))
				layout.append(_endless_random_plant(PlantIds.CORN_PULT, 3))
				layout.append(_endless_random_plant(PlantIds.THREE_PEATER, 1))
				layout.append(_endless_random_plant(PlantIds.SNOW_PEA, 3))
				layout.append(_endless_random_plant(PlantIds.UMBRELLA_LEAF, 1))
				layout.append(_endless_random_plant(PlantIds.MAGNET_SHROOM, 1))
				layout.append(_endless_random_plant(PlantIds.CALTROP, 3))
			_:
				## 秒杀阵
				layout.append(_endless_random_plant(PlantIds.POTATO_MINE, 4))
				layout.append(_endless_random_plant(PlantIds.CHOMPER, 3))
				layout.append(_endless_random_plant(PlantIds.SQUASH, 3))
				layout.append(_endless_random_plant(PlantIds.FUME_SHROOM, 4))
				layout.append(_endless_random_plant(PlantIds.CALTROP, 3))
	return layout


## 当前轮次换算成原版的 stage（原版第 1 轮 = stage 0）
func _get_endless_stage() -> int:
	var main_game: MainGameManager = GameContext.curr_main_game
	if main_game == null:
		return 0
	return maxi(main_game.curr_game_round - 1, 0)


## 无尽关的一条随机摆放条目（不限行）
func _endless_random_plant(plant_type: StringName, count: int) -> Dictionary:
	return {"plant": plant_type, "row": -1, "col": -1, "count": count}


## 进度条口径：**已吃脑子数 / 5**（原版 `I_ZOMBIE_WINNING_SCORE` = 5，原版就在进度条位置显示这个计数；
## 无尽每轮脑子重建时计数清零，进度条跟着回 0 重走）
func create_progress_provider() -> LevelProgressProvider:
	return PuzzleZombieProgressProvider.new()
