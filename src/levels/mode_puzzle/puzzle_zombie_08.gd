extends LevelScriptBase
## puzzle_zombie_08 —— 解谜模式「僵尸公敌」第 8 关（原版 Three Hit Wonder）
##
## 纸板植物布局、红线列数、起始阳光、僵尸卡阵容逐项取自原版 C++：
##   `../PvZ-Portable-main/src/Lawn/Challenge.cpp` → `Challenge::IZombieInitLevel`（I_ZOMBIE_8 分支）
##   `../PvZ-Portable-main/src/Lawn/Board.cpp` → `Board::InitLevel`（起始阳光 / 僵尸卡 / 红线限制）
## 对照表见 docs/参考存档/我是僵尸原版对照.md。
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。


func _init() -> void:
	# 存档键写死：解谜模式 20 关合并成一页后按钮序号会变，写死后玩家存档不丢
	save_key = "103_1_0008"
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
	max_choosed_card_num = 6
	## 本关僵尸卡：小鬼 / 路障 / 铁桶 / 蹦极 / 矿工 / 梯子（原版 `Board::InitLevel` 的 I_ZOMBIE_8 分支）
	prechosen_cards = ResourceCardReference.create_zombie_list([25, 3, 5, 21, 18, 22])
	is_zombie_mode = true
	## 红线左侧 5 列（原版 aLimit = 5）：纸板植物只能占这 5 列，僵尸只能放在第 5 列起
	plant_col_on_zombie_mode = 5
	## 原版纸板植物布局（本关没有固定格位，全是随机落位）：
	##   坚果墙 ×3 / 磁力菇 ×2 / 豌豆射手 ×8 / 窝瓜 ×2 / 土豆雷 ×2 / 向日葵 ×8
	zombie_mode_plant_layout = [
		{"plant": PlantIds.WALL_NUT, "row": -1, "col": -1, "count": 3},
		{"plant": PlantIds.MAGNET_SHROOM, "row": -1, "col": -1, "count": 2},
		{"plant": PlantIds.PEA_SHOOTER_SINGLE, "row": -1, "col": -1, "count": 8},
		{"plant": PlantIds.SQUASH, "row": -1, "col": -1, "count": 2},
		{"plant": PlantIds.POTATO_MINE, "row": -1, "col": -1, "count": 2},
		{"plant": PlantIds.SUN_FLOWER, "row": -1, "col": -1, "count": 8},
	]
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
	if mg.curr_game_round == 1:
		## 保龄球红线（仅第 1 轮）
		await bowling_stripe()
	## 开战（原版「我是僵尸」**没有**「准备…安放…植物」阶段：
	## 僵尸卡进关就发在手牌上，玩家直接点卡放僵尸；也没有小推车）
	await start_battle(-1, [
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.BUCKET,
		ZombieIds.DIGGER,
		ZombieIds.BUNGI,
		ZombieIds.LADDER,
		ZombieIds.IMP,
	])


## 进度条口径：**已吃脑子数 / 5**（原版 `I_ZOMBIE_WINNING_SCORE` = 5，原版就在进度条位置显示这个计数）
func create_progress_provider() -> LevelProgressProvider:
	return PuzzleZombieProgressProvider.new()
