extends RefCounted
## 探针：玩家对战「保龄球红线」左右分区
## （`mods_builtin/player_battle/levels/player_battle_day.gd` 的 `init_level_items`）
##
## 覆盖：
##   1. 红线节点建出来、挂在 `CanvasLayerBG/GameItemsInBg` 下、可见
##   2. 红线贴在第 6 列（下标 5）的**右边缘**
##   3. 格子标记：左半区（列 0~5）能种植物、不能放僵尸；右半区（列 6~）反过来
##   4. 判据走**真正的判定口径**（不是直接读字段）：
##      · 普通植物（向日葵）—— 左能种 / 右不能种（`can_common_plant`）
##      · 产脑光墓碑（2026-10-25 起是**僵尸单位**）—— 左不能放 / 右能放
##        （走 `can_common_zombie`，与 `hand_component_character.gd` 的僵尸分支同一资格线）
##
## 机器可读汇总（最后一行）：[SIDESPLIT] result=PASS|FAIL failed=<n>

## 红线所在的列（0 起算：5 = 第 6 列，红线贴它的右边缘）
const STRIPE_COL := 5
## 关卡脚本的两个加载根（内置源 / 玩家那份，`user://mods/` 优先）
const LEVEL_PATHS := [
	"res://mods_builtin/player_battle/levels/player_battle_day.gd",
	"user://mods/player_battle/levels/player_battle_day.gd",
]
## 红线贴到格子右边缘时的内缩量（`WallnutBowlingStripe.init_item` 里的 -11）
const STRIPE_INSET := 11.0

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：玩家对战红线左右分区 ==========")

	var level_gd: GDScript = null
	for path in LEVEL_PATHS:
		if ResourceLoader.exists(path):
			level_gd = load(path) as GDScript
			break
	if level_gd == null:
		a.log("!! 关卡脚本加载失败（两个加载根都没有）")
		_finish(a)
		return

	var para = level_gd.new()
	para.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle, 0, "0001")
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	if not await _wait_level_ready(a, 40.0):
		a.log("!! 进不了关卡（格子没建出来）")
		_finish(a)
		return
	await a.wait(0.5)

	var mg: MainGameManager = GameContext.curr_main_game
	var rows: Array = mg.plant_cell_manager.all_plant_cells
	if rows.is_empty() or (rows[0] as Array).size() <= STRIPE_COL:
		a.log("!! 草坪格子不对")
		_finish(a)
		return

	# ------------------------------------------------ STEP1 红线节点
	a.log("STEP1 红线节点")
	var items: Node2D = mg.get_node_or_null("CanvasLayerBG/GameItemsInBg")
	_check(a, "取到 GameItemsInBg", items != null)
	var stripe: WallnutBowlingStripe = null
	if items != null:
		for c in items.get_children():
			if c is WallnutBowlingStripe:
				stripe = c as WallnutBowlingStripe
	_check(a, "红线节点已创建并挂在 GameItemsInBg 下", stripe != null)
	_check(a, "红线可见（对战没有戴夫台词，建好就画）", stripe != null and stripe.visible)
	if stripe == null:
		_finish(a)
		return

	# ------------------------------------------------ STEP2 位置
	a.log("STEP2 红线贴在第 6 列右边缘")
	var cell: PlantCell = (rows[0] as Array)[STRIPE_COL]
	var expect_x: float = cell.global_position.x + cell.size.x - STRIPE_INSET
	_check(a, "红线 x = 第 6 列右边缘（内缩 %.0f）" % STRIPE_INSET,
		absf(stripe.global_position.x - expect_x) <= 1.0,
		"红线x=%.1f 期望=%.1f" % [stripe.global_position.x, expect_x])

	# ------------------------------------------------ STEP3 格子标记
	a.log("STEP3 格子标记（左：能植物 / 不能僵尸；右：反之）")
	var bad_plant_left := 0
	var bad_zombie_left := 0
	var bad_plant_right := 0
	var bad_zombie_right := 0
	for row_cells in rows:
		for j in (row_cells as Array).size():
			var pc: PlantCell = (row_cells as Array)[j]
			if j <= STRIPE_COL:
				if not pc.can_common_plant:
					bad_plant_left += 1
				if pc.can_common_zombie:
					bad_zombie_left += 1
			else:
				if pc.can_common_plant:
					bad_plant_right += 1
				if not pc.can_common_zombie:
					bad_zombie_right += 1
	_check(a, "左半区每格都能种植物（can_common_plant）", bad_plant_left == 0,
		"不合格 %d 格" % bad_plant_left)
	_check(a, "左半区每格都不能放僵尸（can_common_zombie=false）", bad_zombie_left == 0,
		"不合格 %d 格" % bad_zombie_left)
	_check(a, "右半区每格都不能种植物（can_common_plant=false）", bad_plant_right == 0,
		"不合格 %d 格" % bad_plant_right)
	_check(a, "右半区每格都能放僵尸（can_common_zombie）", bad_zombie_right == 0,
		"不合格 %d 格" % bad_zombie_right)

	# ------------------------------------------------ STEP4 走真正的种植条件
	a.log("STEP4 种植条件判定（左 / 右各取一格）")
	var left_cell: PlantCell = (rows[0] as Array)[0]
	var right_cell: PlantCell = (rows[0] as Array)[STRIPE_COL + 1]
	var flower: ResourcePlantCondition = Global.character_registry.get_plant_info(
		PlantIds.SUN_FLOWER, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	_check(a, "取到向日葵的种植条件", flower != null)
	if flower != null:
		_check(a, "向日葵：左半区能种", flower.judge_is_can_plant(left_cell, PlantIds.SUN_FLOWER))
		_check(a, "向日葵：右半区不能种", not flower.judge_is_can_plant(right_cell, PlantIds.SUN_FLOWER))
	## 产脑光墓碑是**僵尸单位**（2026-10-25 从植物改过来）：放置走僵尸分支，
	## 判据就是 `can_common_zombie` —— 左半区红线挡住、右半区放得下
	_check(a, "产脑光墓碑（僵尸单位）：左半区不能放", not left_cell.can_common_zombie)
	_check(a, "产脑光墓碑（僵尸单位）：右半区能放", right_cell.can_common_zombie)

	_finish(a)


#region 断言与工具
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[SIDESPLIT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)


## 等关卡初始化到「格子已建好」（`init_level_items` 就跑在这一步之后）
func _wait_level_ready(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var mg: MainGameManager = GameContext.curr_main_game
		if mg != null and mg.plant_cell_manager != null:
			var rows: Array = mg.plant_cell_manager.all_plant_cells
			if not rows.is_empty() and not (rows[0] as Array).is_empty():
				return true
		await a.wait(0.5)
		waited += 0.5
	return false
#endregion
