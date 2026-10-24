extends RefCounted
## 探针：解谜模式「僵尸公敌」（原版 I, Zombie）10 关的原版口径。
##
## 断言的是**数据层**（关卡脚本的属性与逐关纸板植物布局表），期望值照抄原版 C++：
##   `../PvZ-Portable-main/src/Lawn/Challenge.cpp` → `Challenge::IZombieInitLevel`
##   `../PvZ-Portable-main/src/Lawn/Board.cpp` → `Board::InitLevel`（起始阳光 / 僵尸卡 / 红线限制）
## 逐项对照表见 docs/参考存档/我是僵尸原版对照.md。
##
## 无需进入主游戏：只实例化关卡脚本读字段，探针几秒就能跑完。

## 每关的期望值：
##   "col_limit" —— 红线左侧列数（原版 aLimit）
##   "stripe_col" —— 红线贴在第几列的右边缘（= col_limit - 1）
##   "cards"     —— 僵尸卡槽数（原版每关 3~9 张）
##   "fixed"     —— 固定格位条目 [行, 列, 植物]（原版 IZombiePlacePlantInSquare）
##   "random"    —— 随机落位条目 [行, 数量, 植物]（原版 IZombiePlacePlants，-1 = 不限行）
const EXPECTED := {
	"puzzle_zombie_01": {
		"col_limit": 4, "stripe_col": 3, "cards": 3,
		"fixed": [[2, 3, PlantIds.SUN_FLOWER], [3, 3, PlantIds.SUN_FLOWER]],
		"random": [[-1, 7, PlantIds.SUN_FLOWER], [-1, 3, PlantIds.SQUASH],
			[-1, 6, PlantIds.PEA_SHOOTER_SINGLE], [-1, 2, PlantIds.SNOW_PEA]],
	},
	"puzzle_zombie_02": {
		"col_limit": 4, "stripe_col": 3, "cards": 3,
		"fixed": [[0, 3, PlantIds.CALTROP], [0, 2, PlantIds.SUN_FLOWER], [3, 3, PlantIds.SUN_FLOWER]],
		"random": [[0, 1, PlantIds.CALTROP], [0, 1, PlantIds.PEA_SHOOTER_SINGLE],
			[3, 2, PlantIds.SNOW_PEA], [3, 1, PlantIds.SUN_FLOWER],
			[-1, 4, PlantIds.SUN_FLOWER], [-1, 2, PlantIds.CALTROP],
			[-1, 2, PlantIds.SNOW_PEA], [-1, 4, PlantIds.PEA_SHOOTER_SINGLE]],
	},
	"puzzle_zombie_03": {
		"col_limit": 4, "stripe_col": 3, "cards": 3,
		"fixed": [[0, 3, PlantIds.POTATO_MINE], [0, 2, PlantIds.SUN_FLOWER],
			[2, 2, PlantIds.POTATO_MINE], [4, 2, PlantIds.SUN_FLOWER], [3, 3, PlantIds.TORCH_WOOD]],
		"random": [[-1, 2, PlantIds.TORCH_WOOD], [-1, 5, PlantIds.SUN_FLOWER],
			[-1, 7, PlantIds.PEA_SHOOTER_SINGLE], [-1, 1, PlantIds.SPLIT_PEA]],
	},
	"puzzle_zombie_04": {
		"col_limit": 4, "stripe_col": 3, "cards": 3,
		"fixed": [[0, 3, PlantIds.WALL_NUT], [0, 2, PlantIds.SUN_FLOWER],
			[1, 3, PlantIds.WALL_NUT], [2, 3, PlantIds.WALL_NUT], [2, 2, PlantIds.SUN_FLOWER],
			[3, 3, PlantIds.WALL_NUT], [4, 3, PlantIds.WALL_NUT], [4, 2, PlantIds.SUN_FLOWER]],
		"random": [[0, 1, PlantIds.PEA_SHOOTER_SINGLE], [1, 1, PlantIds.SNOW_PEA],
			[2, 2, PlantIds.FUME_SHROOM], [3, 1, PlantIds.SNOW_PEA],
			[4, 1, PlantIds.PEA_SHOOTER_SINGLE], [-1, 2, PlantIds.PEA_SHOOTER_SINGLE],
			[-1, 4, PlantIds.SUN_FLOWER]],
	},
	"puzzle_zombie_05": {
		"col_limit": 4, "stripe_col": 3, "cards": 4,
		"fixed": [[2, 3, PlantIds.SUN_FLOWER], [3, 3, PlantIds.SUN_FLOWER]],
		"random": [[1, 1, PlantIds.CACTUS], [4, 1, PlantIds.CACTUS], [-1, 1, PlantIds.MAGNET_SHROOM],
			[-1, 5, PlantIds.SUN_FLOWER], [-1, 8, PlantIds.PEA_SHOOTER_SINGLE],
			[-1, 2, PlantIds.SNOW_PEA]],
	},
	"puzzle_zombie_06": {
		"col_limit": 5, "stripe_col": 4, "cards": 4,
		"fixed": [[1, 4, PlantIds.GARLIC], [3, 4, PlantIds.GARLIC]],
		"random": [[1, 3, PlantIds.SUN_FLOWER], [3, 3, PlantIds.SUN_FLOWER],
			[-1, 2, PlantIds.TORCH_WOOD], [-1, 2, PlantIds.SUN_FLOWER], [-1, 3, PlantIds.CALTROP],
			[-1, 1, PlantIds.SNOW_PEA], [-1, 5, PlantIds.PEA_SHOOTER_SINGLE],
			[-1, 2, PlantIds.SQUASH], [-1, 2, PlantIds.CORN_PULT]],
	},
	"puzzle_zombie_07": {
		"col_limit": 5, "stripe_col": 4, "cards": 4,
		"fixed": [[2, 4, PlantIds.SUN_FLOWER], [4, 4, PlantIds.SUN_FLOWER]],
		"random": [[-1, 6, PlantIds.SUN_FLOWER], [-1, 9, PlantIds.POTATO_MINE],
			[-1, 8, PlantIds.CHOMPER]],
	},
	"puzzle_zombie_08": {
		"col_limit": 5, "stripe_col": 4, "cards": 6,
		"fixed": [],
		"random": [[-1, 3, PlantIds.WALL_NUT], [-1, 2, PlantIds.MAGNET_SHROOM],
			[-1, 8, PlantIds.PEA_SHOOTER_SINGLE], [-1, 2, PlantIds.SQUASH],
			[-1, 2, PlantIds.POTATO_MINE], [-1, 8, PlantIds.SUN_FLOWER]],
	},
	"puzzle_zombie_09": {
		"col_limit": 6, "stripe_col": 5, "cards": 8,
		"fixed": [[1, 5, PlantIds.TALL_NUT], [3, 5, PlantIds.TORCH_WOOD]],
		"random": [[0, 4, PlantIds.POTATO_MINE], [0, 2, PlantIds.SUN_FLOWER],
			[1, 2, PlantIds.SUN_FLOWER], [1, 1, PlantIds.THREE_PEATER], [1, 1, PlantIds.SNOW_PEA],
			[1, 1, PlantIds.SPLIT_PEA], [2, 3, PlantIds.CHOMPER], [2, 2, PlantIds.SUN_FLOWER],
			[2, 1, PlantIds.SQUASH], [3, 3, PlantIds.PEA_SHOOTER_SINGLE], [3, 2, PlantIds.SUN_FLOWER],
			[4, 1, PlantIds.SUN_FLOWER], [4, 1, PlantIds.FUME_SHROOM], [4, 1, PlantIds.SCAREDY_SHROOM],
			[4, 1, PlantIds.STAR_FRUIT], [4, 1, PlantIds.SPLIT_PEA], [4, 1, PlantIds.MAGNET_SHROOM]],
	},
}

## 无尽关（第 10 关）的期望：原版每轮重掷阵型，不写死布局表
const ENDLESS_LEVEL := "puzzle_zombie_10"
const ENDLESS_COL_LIMIT := 5
const ENDLESS_STRIPE_COL := 4
const ENDLESS_CARDS := 9
## 原版无尽关第 1 轮（stage = 0）：向日葵 8 株、小喷菇 0 株 + 一个普通阵
## （混合阵 15 条 / 控制阵 9 条 / 秒杀阵 5 条，加前面 2 条 = 17 / 11 / 7 条）
const ENDLESS_ENTRY_COUNTS := [17, 11, 7]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 我是僵尸（逐关原版布局表） ==========")
	for level_id: String in EXPECTED.keys():
		await _check_level(a, level_id, EXPECTED[level_id])
	await _check_endless_level(a)
	_finish(a)


## 普通关（1~9）：逐项对照原版布局表
func _check_level(a, level_id: String, expect: Dictionary) -> void:
	a.log("---- %s" % level_id)
	var para: ResourceLevelData = (load("res://src/levels/mode_puzzle/%s.gd" % level_id) as GDScript).new()
	if para == null:
		_check(a, level_id + ": 关卡脚本可实例化", false)
		return
	_check(a, level_id + ": 我是僵尸模式", para.is_zombie_mode)
	## 原版 `Board::InitLevel`：我是僵尸关一律 150 起始阳光
	_check(a, level_id + ": 起始阳光 150", para.start_sun == 150, "start_sun=%d" % para.start_sun)
	_check(a, level_id + ": 红线左侧列数 = %d" % expect["col_limit"],
		para.plant_col_on_zombie_mode == expect["col_limit"],
		"plant_col_on_zombie_mode=%d" % para.plant_col_on_zombie_mode)
	_check(a, level_id + ": 红线贴在第 %d 列右边缘" % expect["stripe_col"],
		para.plant_cell_col_j == expect["stripe_col"],
		"plant_cell_col_j=%d" % para.plant_cell_col_j)
	_check(a, level_id + ": 僵尸卡槽数 = %d" % expect["cards"],
		para.max_choosed_card_num == expect["cards"],
		"max_choosed_card_num=%d" % para.max_choosed_card_num)
	_check(a, level_id + ": 有僵尸预选卡", not para.prechosen_cards.is_empty())
	## 原版我是僵尸关没有小推车（`Board::CreateLawnMowers` 对我是僵尸关直接 return）
	_check(a, level_id + ": 没有小推车", not para.is_lawn_mover, "is_lawn_mover=%s" % para.is_lawn_mover)
	## 原版我是僵尸关**没有**「准备…安放…植物」阶段：进关就能点僵尸卡放僵尸
	_check(a, level_id + ": 没有「准备…安放…植物」阶段", not _script_has_ready_set_plant(level_id),
		"关卡脚本里还留着 ready_set_plant()")
	## 进度条口径：**已吃脑子数 / 5**（原版 `I_ZOMBIE_WINNING_SCORE` = 5，原版就在进度条位置显示这个计数）
	_check(a, level_id + ": 进度条口径 = 已吃脑子数 / 5",
		para.create_progress_provider() is PuzzleZombieProgressProvider)

	## 布局表：拆成固定格位与随机落位两类，逐项对照
	var fixed: Array = []
	var random_items: Array = []
	for item: Dictionary in para.zombie_mode_plant_layout:
		var col: int = item.get("col", -1)
		if col >= 0:
			fixed.append([item.get("row", -1), col, item.get("plant", PlantIds.NULL)])
		else:
			random_items.append([item.get("row", -1), item.get("count", 0), item.get("plant", PlantIds.NULL)])
	_check(a, level_id + ": 固定格位条目与原版一致", _same_items(fixed, expect["fixed"]),
		"实际=%s" % str(fixed))
	_check(a, level_id + ": 随机落位条目与原版一致", _same_items(random_items, expect["random"]),
		"实际=%s" % str(random_items))
	## 原版：坚果与火炬只能落在红线左侧最右 3 列
	_check(a, level_id + ": 坚果 / 火炬都在最右 3 列",
		_fixed_in_rightmost_three(fixed, expect["col_limit"]),
		"实际=%s" % str(fixed))


## 无尽关（第 10 关）：按原版规则现算阵型，不写死布局表
func _check_endless_level(a) -> void:
	a.log("---- %s" % ENDLESS_LEVEL)
	var para: ResourceLevelData = (load("res://src/levels/mode_puzzle/%s.gd" % ENDLESS_LEVEL) as GDScript).new()
	if para == null:
		_check(a, ENDLESS_LEVEL + ": 关卡脚本可实例化", false)
		return
	_check(a, ENDLESS_LEVEL + ": 我是僵尸模式", para.is_zombie_mode)
	_check(a, ENDLESS_LEVEL + ": 起始阳光 150", para.start_sun == 150, "start_sun=%d" % para.start_sun)
	_check(a, ENDLESS_LEVEL + ": 红线左侧列数 = %d" % ENDLESS_COL_LIMIT,
		para.plant_col_on_zombie_mode == ENDLESS_COL_LIMIT,
		"plant_col_on_zombie_mode=%d" % para.plant_col_on_zombie_mode)
	_check(a, ENDLESS_LEVEL + ": 红线贴在第 %d 列右边缘" % ENDLESS_STRIPE_COL,
		para.plant_cell_col_j == ENDLESS_STRIPE_COL,
		"plant_cell_col_j=%d" % para.plant_cell_col_j)
	_check(a, ENDLESS_LEVEL + ": 僵尸卡槽数 = %d" % ENDLESS_CARDS,
		para.max_choosed_card_num == ENDLESS_CARDS,
		"max_choosed_card_num=%d" % para.max_choosed_card_num)
	_check(a, ENDLESS_LEVEL + ": 无尽关", para.game_round == -1, "game_round=%d" % para.game_round)
	_check(a, ENDLESS_LEVEL + ": 没有小推车", not para.is_lawn_mover, "is_lawn_mover=%s" % para.is_lawn_mover)
	_check(a, ENDLESS_LEVEL + ": 没有「准备…安放…植物」阶段", not _script_has_ready_set_plant(ENDLESS_LEVEL),
		"关卡脚本里还留着 ready_set_plant()")
	_check(a, ENDLESS_LEVEL + ": 进度条口径 = 已吃脑子数 / 5",
		para.create_progress_provider() is PuzzleZombieProgressProvider)
	## 布局表不写死，由关卡脚本按轮次现算
	_check(a, ENDLESS_LEVEL + ": 布局表不写死", para.zombie_mode_plant_layout.is_empty())
	var layout: Array[Dictionary] = para.get_zombie_mode_plant_layout()
	_check(a, ENDLESS_LEVEL + ": 现算出的阵型条目数符合原版",
		ENDLESS_ENTRY_COUNTS.has(layout.size()),
		"条目数=%d" % layout.size())
	## 第 1 轮（stage 0）：向日葵 8 株、小喷菇 0 株
	var sunflower_count: int = 0
	var puff_shroom_count: int = 0
	for item: Dictionary in layout:
		if item.get("plant", PlantIds.NULL) == PlantIds.SUN_FLOWER:
			sunflower_count += item.get("count", 0)
		if item.get("plant", PlantIds.NULL) == PlantIds.PUFF_SHROOM:
			puff_shroom_count += item.get("count", 0)
	_check(a, ENDLESS_LEVEL + ": 第 1 轮向日葵 8 株", sunflower_count == 8, "向日葵=%d" % sunflower_count)
	_check(a, ENDLESS_LEVEL + ": 第 1 轮小喷菇 0 株", puff_shroom_count == 0, "小喷菇=%d" % puff_shroom_count)


## 关卡脚本里还有没有「准备…安放…植物」这一步
##
## 原版我是僵尸关**没有**这一步：玩家扮演僵尸，进关就能点僵尸卡放僵尸，
## 没有选卡界面、没有「准备…安放…植物」红字，也没有小推车。
## 这里直接读关卡脚本的源码来判（流程步骤就写在 run_flow 里）。
func _script_has_ready_set_plant(level_id: String) -> bool:
	var path := "res://src/levels/mode_puzzle/%s.gd" % level_id
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return true
	var text := file.get_as_text()
	file.close()
	return text.contains("ready_set_plant")


## 两组条目逐项相等
func _same_items(actual: Array, expect: Array) -> bool:

	if actual.size() != expect.size():
		return false
	for i in range(actual.size()):
		var a_item: Array = actual[i]
		var e_item: Array = expect[i]
		if a_item.size() != e_item.size():
			return false
		for j in range(a_item.size()):
			if a_item[j] != e_item[j]:
				return false
	return true


## 固定格位里的坚果 / 火炬是否都落在红线左侧最右 3 列
func _fixed_in_rightmost_three(fixed: Array, col_limit: int) -> bool:
	for item: Array in fixed:
		var plant_type: StringName = item[2]
		var col: int = item[1]
		if plant_type != PlantIds.WALL_NUT and plant_type != PlantIds.TORCH_WOOD:
			continue
		if col_limit - col > 3:
			return false
	return true


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if not detail.is_empty() else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[IZOMBIE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
