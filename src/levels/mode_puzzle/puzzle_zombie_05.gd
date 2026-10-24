extends LevelScriptBase
## puzzle_zombie_05 —— 解谜模式「僵尸公敌」第 5 关（原版 Dead Zeppelin）
##
## 纸板植物布局、红线列数、起始阳光、僵尸卡阵容逐项取自原版 C++：
##   `../PvZ-Portable-main/src/Lawn/Challenge.cpp` → `Challenge::IZombieInitLevel`（I_ZOMBIE_5 分支）
##   `../PvZ-Portable-main/src/Lawn/Board.cpp` → `Board::InitLevel`（起始阳光 / 僵尸卡 / 红线限制）
## 对照表见 docs/参考存档/我是僵尸原版对照.md。
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。


func _init() -> void:
	# 存档键写死：解谜模式 20 关合并成一页后按钮序号会变，写死后玩家存档不丢
	save_key = "103_1_0005"
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
	## 僵尸卡槽数 = 本关僵尸卡数（原版每关 3~9 张）
	max_choosed_card_num = 4
	## 本关僵尸卡：普僵 / 铁桶 / 蹦极 / 气球（原版 `Board::InitLevel` 的 I_ZOMBIE_5 分支）
	prechosen_cards = ResourceCardReference.create_zombie_list([1, 5, 21, 17])
	is_zombie_mode = true
	## 红线左侧 4 列（原版 aLimit = 4）：纸板植物只能占这 4 列，僵尸只能放在第 4 列起
	plant_col_on_zombie_mode = 4
	## 原版纸板植物布局：
	##   固定格位 —— 向日葵(第 3 列第 3 行) / 向日葵(第 3 列第 4 行)
	##   随机落位 —— 仙人掌 ×1(第 2 行) / 仙人掌 ×1(第 5 行) / 磁力菇 ×1 /
	##               向日葵 ×5 / 豌豆射手 ×8 / 寒冰射手 ×2
	zombie_mode_plant_layout = [
		{"plant": PlantIds.SUN_FLOWER, "row": 2, "col": 3},
		{"plant": PlantIds.SUN_FLOWER, "row": 3, "col": 3},
		{"plant": PlantIds.CACTUS, "row": 1, "col": -1, "count": 1},
		{"plant": PlantIds.CACTUS, "row": 4, "col": -1, "count": 1},
		{"plant": PlantIds.MAGNET_SHROOM, "row": -1, "col": -1, "count": 1},
		{"plant": PlantIds.SUN_FLOWER, "row": -1, "col": -1, "count": 5},
		{"plant": PlantIds.PEA_SHOOTER_SINGLE, "row": -1, "col": -1, "count": 8},
		{"plant": PlantIds.SNOW_PEA, "row": -1, "col": -1, "count": 2},
	]
	is_bowling_stripe = true
	## 红线贴在第 3 列右边缘（左区 = 第 0~3 列，正好是原版那 4 列纸板植物区）
	plant_cell_col_j = 3
	plant_cell_can_use.assign({
		"left_can_plant": false,
		"left_can_zombie": false,
		"right_can_plant": false,
		"right_can_zombie": true
	})


func run_flow(mg: MainGameManager) -> void:
	## 进关即可放僵尸：主动把阶段推到 MAIN_GAME 放出卡槽
	## （原版「我是僵尸」没有选卡 / 准备阶段，卡槽一进场就可见、玩家立刻能点卡放僵尸；
	##  原先要等「开战」事件才放卡槽，差 1~2 秒）
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
		ZombieIds.NORM,
		ZombieIds.BUCKET,
		ZombieIds.BALLOON,
		ZombieIds.BUNGI,
	])


## 进度条口径：**已吃脑子数 / 5**（原版 `I_ZOMBIE_WINNING_SCORE` = 5，原版就在进度条位置显示这个计数）
func create_progress_provider() -> LevelProgressProvider:
	return PuzzleZombieProgressProvider.new()
