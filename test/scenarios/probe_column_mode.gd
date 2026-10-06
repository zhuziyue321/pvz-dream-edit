extends RefCounted
## 探针：迷你游戏第 12 关「排山倒海」整列种植（Column Like You See 'Em）
## 覆盖：
##   ① 静态：手持组件源码里搜不到 is_mode_column；关卡数据上也不再有这个字段
##   ② 持卡：整列虚影一行一个（行数个），由关卡脚本自己创建
##   ③ 悬停：同列能种的行出虚影、种不进去的行不出（悬停那一格仍由手持组件出）
##   ④ 种植：点一格 → 同列所有可种的行都种上同一种植物
##   ⑤ 越界：点在种不进去的格子上不丢卡
##   ⑥ 收摊：放下卡片后虚影清空，关卡脚本的清理可重复调用（幂等）
## 机器可读汇总：最后一行 [COLUMN] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_minigame/minigame_12_column.gd"
## 手持组件：改造后这里不该再出现任何柱子模式分支
const HAND_COMPONENT := "res://src/managers/hand_manager/component/hand_component_character.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 排山倒海（整列种植） ==========")

	# ------------------------------------------------ STEP1 静态：玩法不进本体
	a.log("STEP1 静态：柱子模式分支不进手持组件")
	_check(a, "手持组件源码里搜不到 is_mode_column", not _source_contains(HAND_COMPONENT, "is_mode_column"))

	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	_check(a, "关卡数据上不再有 is_mode_column 字段", not _has_property(para, "is_mode_column"))

	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)

	var mg := Global.main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "Global.main_game 为空")
		_finish(a)
		return
	var level_script := mg.game_para as LevelScriptBase
	if level_script == null:
		_check(a, "拿到关卡脚本实例", false, str(mg.game_para))
		_finish(a)
		return

	# ------------------------------------------------ STEP2 进关接线
	a.log("STEP2 进关：等开战 + 传送带发牌")
	if not await _wait_progress(a, mg, MainGameManager.E_MainGameProgress.MAIN_GAME, 90.0):
		_finish(a)
		return
	var row_num: int = mg.plant_cell_manager.row_col.x
	a.log("  草坪 %d 行 x %d 列" % [row_num, mg.plant_cell_manager.row_col.y])

	var card := await _wait_conveyor_card(a, mg, 30.0)
	if card == null:
		_check(a, "传送带发出了一张卡片", false, "超时 30s")
		_finish(a)
		return
	var plant_type: int = card.card_plant_type
	a.log("  拿到卡片：%s（植物类型 %d）" % [str(card.get_path()), plant_type])

	var target := _pick_column(mg, plant_type)
	if target == Vector2i(-1, -1):
		_check(a, "找到一列「至少两行能种」的格子", false, "植物类型 %d" % plant_type)
		_finish(a)
		return
	a.log("  目标列 = %d（这一列能种 %d 行），点在第 %d 行" % [
		target.y, _plantable_rows(mg, plant_type, target.y).size(), target.x])

	# ------------------------------------------------ STEP3 持卡：整列虚影
	a.log("STEP3 持卡：整列虚影一行一个")
	await a.click_node(str(card.get_path()))
	await a.wait(0.4)
	_check(a, "卡片拿在手上", mg.hand_manager.is_holding_hand())
	_check(a, "整列虚影个数 = 行数 %d" % row_num,
		level_script.column_shadows.size() == row_num, str(level_script.column_shadows.size()))

	# ------------------------------------------------ STEP4 悬停：只给能种的行出虚影
	a.log("STEP4 悬停：同列能种的行才出虚影")
	var hover_cell: PlantCell = mg.plant_cell_manager.all_plant_cells[target.x][target.y]
	hover_cell.cell_mouse_enter.emit(hover_cell)
	await a.frames(3)
	var visible_rows := _visible_shadow_rows(level_script)
	var plantable_rows := _plantable_rows(mg, plant_type, target.y)
	## 悬停那一格的虚影由手持组件出，关卡脚本跳过它，所以可见虚影 = 能种的行数 - 1
	var want_visible: int = plantable_rows.size() - plantable_rows.count(target.x)
	a.log("  可见虚影行 = %s ；这一列能种的行 = %s" % [str(visible_rows), str(plantable_rows)])
	_check(a, "能种的行都出了虚影（悬停那一行除外）",
		visible_rows.size() == want_visible, "%d vs %d" % [visible_rows.size(), want_visible])
	_check(a, "种不进去的行没有虚影", _all_rows_plantable(visible_rows, mg, plant_type, target.y))

	# ------------------------------------------------ STEP5 种植：一整列
	a.log("STEP5 种植：点一格种一整列")
	await a.click_plant_cell(target.x, target.y)
	await a.wait(0.8)
	var planted_rows := _planted_rows(mg, plant_type, target.y)
	a.log("  种完这一列有植物的行 = %s" % str(planted_rows))
	_check(a, "同列能种的行全种上了", planted_rows == plantable_rows,
		"%s vs %s" % [str(planted_rows), str(plantable_rows)])
	_check(a, "种植后回到空手",
		mg.hand_manager.get_curr_hand_type() == HandComponentBase.E_HandComponentType.Null)
	_check(a, "放下卡片后整列虚影已清空", level_script.column_shadows.is_empty(),
		str(level_script.column_shadows.size()))

	# ------------------------------------------------ STEP6 越界：点不能种的格子不丢卡
	a.log("STEP6 越界：点种不进去的格子不丢卡")
	var card_2 := await _wait_conveyor_card(a, mg, 30.0)
	if card_2 == null:
		_check(a, "传送带又发出一张卡片", false, "超时 30s")
		_finish(a)
		return
	await a.click_node(str(card_2.get_path()))
	await a.wait(0.4)
	if not mg.hand_manager.is_holding_hand():
		_check(a, "（前置）重新拿卡成功", false, "type=%d" % mg.hand_manager.get_curr_hand_type())
		_finish(a)
		return
	await a.click_plant_cell(target.x, target.y)
	await a.wait(0.5)
	_check(a, "点在已占满的格子上仍然手持",
		mg.hand_manager.is_holding_hand()
		and mg.hand_manager.get_curr_hand_type() == HandComponentBase.E_HandComponentType.Character)
	mg.hand_manager.drop_hand()
	await a.wait(0.3)

	# ------------------------------------------------ STEP7 通关：跑到结算，关卡脚本自己收摊
	a.log("STEP7 通关：跳到最后一波并清空僵尸")
	var wave_manager = mg.zombie_manager.zombie_wave_manager
	var max_wave: int = mg.game_para.max_wave
	wave_manager.curr_wave = max(int(max_wave) - 2, 0)
	## 最后一波内部有「一大波僵尸正在接近」的 await，必须等它跑完，僵尸才会真的刷出来
	await wave_manager.start_next_wave()
	await a.wait(2.0)
	a.log("  波次 %d/%d，最后一波=%s，场上僵尸=%d" % [
		wave_manager.curr_wave, max_wave, str(mg.zombie_manager.is_end_wave),
		mg.zombie_manager.curr_zombie_num])
	EventBus.push_event("test_death_all_zombie")
	await a.wait(2.0)
	EventBus.push_event("test_death_all_zombie")
	await a.wait(5.0)
	a.log("  主游戏阶段 = %d（GAME_OVER = %d），已种槽位 = %d" % [
		mg.main_game_progress, MainGameManager.E_MainGameProgress.GAME_OVER,
		_get_planted_num(mg)])
	_check(a, "关卡走到结算（GAME_OVER = 通关）",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER,
		str(mg.main_game_progress))
	_check(a, "关卡结束时脚本自己收了摊（虚影清空、断开接线）",
		level_script.main_game == null and level_script.column_shadows.is_empty(),
		"main_game=%s shadows=%d" % [str(level_script.main_game), level_script.column_shadows.size()])

	# ------------------------------------------------ STEP8 收摊：幂等
	a.log("STEP8 收摊：清理可重复调用")
	level_script._free_column_items()
	level_script._free_column_items()
	_check(a, "重复清理后仍保持已收摊状态",
		level_script.main_game == null and level_script.column_shadows.is_empty(),
		"main_game=%s shadows=%d" % [str(level_script.main_game), level_script.column_shadows.size()])
	_check(a, "收摊后主游戏仍在（没有因为改造崩溃）", is_instance_valid(mg))

	_finish(a)


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[COLUMN] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion


#region 工具
## 源码里是否含某字符串（静态检查：玩法不进本体）
func _source_contains(path: String, needle: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	return needle in text


func _has_property(res: Resource, name_value: String) -> bool:
	for p in res.get_property_list():
		if str(p["name"]) == name_value:
			return true
	return false


func _wait_progress(a, mg, progress, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if mg.main_game_progress == progress:
			return true
		await a.wait(0.5)
		waited += 0.5
	_check(a, "等到游戏阶段 %d" % progress, false, "超时 %.0fs，当前 %d" % [timeout, mg.main_game_progress])
	return false


## 等传送带发出第一张卡（传送带每 create_new_card_speed 秒补一张）
func _wait_conveyor_card(a, mg, timeout: float) -> Card:
	var slot = mg.card_manager.card_slot_conveyor_belt
	if slot == null:
		return null
	var waited := 0.0
	while waited < timeout:
		for c in slot.curr_cards:
			if is_instance_valid(c) and c.card_plant_type != CharacterRegistry.PlantType.Null:
				return c
		await a.wait(0.5)
		waited += 0.5
	return null


## 挑一列「至少两行能种」的格子：返回 (点哪一行, 哪一列)
func _pick_column(mg, plant_type: int) -> Vector2i:
	var col_num: int = mg.plant_cell_manager.row_col.y
	for col in col_num:
		var rows := _plantable_rows(mg, plant_type, col)
		if rows.size() >= 2:
			return Vector2i(rows[0], col)
	return Vector2i(-1, -1)


## 某一列里能种 plant_type 的行号（升序）
func _plantable_rows(mg, plant_type: int, col: int) -> Array[int]:
	var out: Array[int] = []
	var cond: ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if cond == null:
		return out
	for row in mg.plant_cell_manager.row_col.x:
		var cell: PlantCell = mg.plant_cell_manager.all_plant_cells[row][col]
		if cond.judge_is_can_plant(cell, plant_type):
			out.append(row)
	return out


## 某一列里已经种了 plant_type 的行号（升序）
func _planted_rows(mg, plant_type: int, col: int) -> Array[int]:
	var out: Array[int] = []
	for row in mg.plant_cell_manager.row_col.x:
		var cell: PlantCell = mg.plant_cell_manager.all_plant_cells[row][col]
		if _cell_has_plant(cell, plant_type):
			out.append(row)
	return out


func _cell_has_plant(cell: PlantCell, plant_type: int) -> bool:
	for place in cell.plant_in_cell:
		var p = cell.get_plant(place)
		if is_instance_valid(p) and p.plant_type == plant_type:
			return true
	return false


## 当前可见的整列虚影行号
func _visible_shadow_rows(level_script) -> Array[int]:
	var out: Array[int] = []
	for i in level_script.column_shadows.size():
		var shadow: Node2D = level_script.column_shadows[i]
		if is_instance_valid(shadow) and shadow.modulate.a > 0.0:
			out.append(i)
	return out


## 场上已种下的植物槽位总数（通关那一步用来确认关卡真的跑到了结算）
func _get_planted_num(mg) -> int:
	var num := 0
	for row_cells in mg.plant_cell_manager.all_plant_cells:
		for cell in row_cells:
			for place in cell.plant_in_cell:
				if is_instance_valid(cell.get_plant(place)):
					num += 1
	return num


## 可见虚影的每一行都是真的能种（反例：种不进去的行也出了虚影）
func _all_rows_plantable(rows: Array[int], mg, plant_type: int, col: int) -> bool:
	var plantable := _plantable_rows(mg, plant_type, col)
	for row in rows:
		if not plantable.has(row):
			return false
	return true
#endregion
