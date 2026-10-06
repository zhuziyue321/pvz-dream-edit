extends RefCounted
## 探针 PROBE8b：新手教程（原版冒险模式 1-2）
## 覆盖：
##   1. 首次游玩 1-2 会播教程（拥有豌豆射手 + 向日葵）：教玩家种向日葵
##   2. 教程严格按原版顺序推进：捡向日葵种子包 → 种下第一棵 → 种满三棵向日葵 → 干得漂亮
##   3. 第一波僵尸由开战统一启动：教学整段（含种下第一株向日葵）期间不出怪
##   4. 教学结束后提示条与箭头都收起
##   5. 已通关 1-2 后再进本关不再播教程（原版教程只在冒险模式第一轮出现）
##
## ⚠️ 1-2 的教学就是**关卡流程里的一段**（adventure_01_02.gd 的 `_tutorial_flow`），
## 没有 TutorialManager、没有步骤下标，推进判据一律用「提示文本」
## （文本在关卡提示条上，见 TutorialAdviceUI.find_level_hint）。
## 机器可读汇总：最后一行 [TUTORIAL12] result=PASS|FAIL failed=<n>

var _failed := 0
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_01_02.gd"
const SAVE_NAME_02 := "101_0_0002"
## 原版教程文本（data/strings/lawn_strings.txt 的 ADVICE_* 条目）
const ADVICE_SUNFLOWER_INTRO := "向日葵是非常重要的植物！"
const ADVICE_CLICK_GRASS := "点击草地种下你的种子！"
const ADVICE_PLANT_THREE := "至少要种下三棵向日葵！"
const ADVICE_NICELY_DONE := "干得漂亮！"
## 原版 1-2 教学的完整顺序（按提示出现的先后）
const EXPECT_ADVICE: Array[String] = [
	ADVICE_SUNFLOWER_INTRO,
	ADVICE_CLICK_GRASS,
	ADVICE_PLANT_THREE,
	ADVICE_NICELY_DONE,
]
## 实际播过的提示（按顺序），由提示条的 signal_advice_changed 记录
var _advice_seq: Array[String] = []


func run(a) -> void:
	a.log("")
	a.log("========== 探针：新手教程（1-2）==========")

	var state = Global.global_game_state
	## 已通关 1-1：拥有豌豆射手 + 向日葵；没有任何通关记录
	state.curr_plant.assign([
		CharacterRegistry.PlantType.P001PeaShooterSingle,
		CharacterRegistry.PlantType.P002SunFlower,
	])
	state.curr_all_level_state_data = {}

	if not await _enter_level(a, true):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	await a.wait(1.0)

	var mg = Global.main_game
	var wave_manager = mg.zombie_manager.zombie_wave_manager

	# ------------------------------------------------ STEP1 教学启动
	a.log("STEP1 教学启动与开局参数")
	var hint := _hint()
	_check(a, "本关挂出了提示条", hint != null, str(hint))
	if hint == null:
		_finish(a)
		return
	## 第 1 句在探针接进来之前就播过了，这里补记
	hint.signal_advice_changed.connect(_on_advice_changed)
	if _hint_text() != "" and not _advice_seq.has(_hint_text()):
		_advice_seq.append(_hint_text())
	_check(a, "第 1 句提示=向日葵是非常重要的植物", _hint_text() == ADVICE_SUNFLOWER_INTRO,
		_hint_text())
	_check(a, "提示条可见", hint.is_advice_visible(), str(hint.is_advice_visible()))
	_check(a, "箭头指向向日葵卡", hint.is_pointer_visible(), str(hint.is_pointer_visible()))
	_check(a, "教学期间第一波未开始", wave_manager.curr_wave == -1, str(wave_manager.curr_wave))
	var battle = mg.card_manager.card_slot_battle
	var card: Card = _get_sunflower_card(battle)
	_check(a, "战斗卡槽有向日葵卡", card != null,
		"null" if card == null else str(card.card_plant_type))
	if card == null:
		_finish(a)
		return

	# ------------------------------------------------ STEP2 点击向日葵种子包
	a.log("STEP2 点击向日葵种子包，卡片拿在手上")
	var card_center: Vector2 = a.screen_center(card)
	await a.click(card_center.x, card_center.y)
	if not await _wait_advice(a, ADVICE_CLICK_GRASS, 8.0):
		_check(a, "点卡后走到「点击草地」", false, "advice=" + _hint_text())
		_finish(a)
		return
	_check(a, "点卡后走到「点击草地」", true, _hint_text())
	_check(a, "卡片已拿在手上", mg.hand_manager.is_holding_hand(), str(mg.hand_manager.is_holding_hand()))

	# ------------------------------------------------ STEP3 种下第一株向日葵
	a.log("STEP3 种下第一株向日葵（此时还没开战，不出怪）")
	var plant_row := _find_plant_row(mg)
	a.log("  可种植的行 = %d" % plant_row)
	_check(a, "1-2 有可种植的草坪行", plant_row >= 0, str(plant_row))
	if plant_row < 0:
		_finish(a)
		return
	await a.click_plant_cell(plant_row, 1)
	if not await _wait_advice(a, ADVICE_PLANT_THREE, 12.0):
		_check(a, "种下第一株后走到「种满三棵」", false, "advice=" + _hint_text())
		_finish(a)
		return
	_check(a, "种下第一株后走到「种满三棵」", true, _hint_text())
	_check(a, "种下第一株时还没开战（第一波由开战启动）", wave_manager.curr_wave == -1,
		str(wave_manager.curr_wave))

	# ------------------------------------------------ STEP4 集齐三棵向日葵
	a.log("STEP4 收集阳光，种满三棵向日葵（教学收尾）")
	if not await _grow_sunflowers_to_end(a, 120.0):
		_check(a, "种满三棵向日葵后教学收尾", false,
			"advice=" + _hint_text() + " 向日葵=" + str(_count_plant(mg, CharacterRegistry.PlantType.P002SunFlower)))
		_finish(a)
		return
	_check(a, "教学收尾后提示条已关掉", not _hint().is_advice_visible(),
		str(_hint().is_advice_visible()))
	_check(a, "教学收尾后箭头已收起", not _hint().is_pointer_visible(),
		str(_hint().is_pointer_visible()))
	_check(a, "场上已种下 3 株向日葵", _count_plant(mg, CharacterRegistry.PlantType.P002SunFlower) >= 3,
		str(_count_plant(mg, CharacterRegistry.PlantType.P002SunFlower)))
	## 教学收尾即开战：第一波由开战（ZombieManager.start_game()）统一开。
	## 开战那一步自己还要先播 BGM / 推进阶段，所以这里等第一波真的落下来再断言
	if await _wait_wave_started(a, 40.0):
		_check(a, "教学结束后开战，第一波僵尸启动", wave_manager.curr_wave >= 0,
			str(wave_manager.curr_wave))
	else:
		_check(a, "教学结束后开战，第一波僵尸启动", false, "超时未开波")
	_check(a, "第一波由开战排上（is_first_wave_started）",
		Global.main_game.zombie_manager.is_first_wave_started,
		str(Global.main_game.zombie_manager.is_first_wave_started))
	_check(a, "教学提示顺序与原版一致", _advice_seq == EXPECT_ADVICE, str(_advice_seq))

	# ------------------------------------------------ STEP5 已通关后不再播教程
	a.log("STEP5 已通关 1-2 后再进本关（不播教程）")
	state.curr_all_level_state_data[SAVE_NAME_02] = {"IsSuccess": true}
	_check(a, "1-2 已有通关记录", state.curr_all_level_state_data.has(SAVE_NAME_02))
	if not await _enter_level(a, false):
		_check(a, "重进 1-2 到 MAIN_GAME", false, "超时")
		_finish(a)
		return
	await a.wait(1.5)
	_check(a, "已通关时不再播教学（没有提示条）",
		_hint() == null or not _hint().is_advice_visible(),
		str(_hint() != null and _hint().is_advice_visible()))

	_finish(a)


#region 断言与工具
## 本关的提示条（「提示快捷工具」挂的那一条，见 TutorialAdviceUI.find_level_hint）
func _hint() -> TutorialAdviceUI:
	if Global.main_game == null:
		return null
	return TutorialAdviceUI.find_level_hint(Global.main_game)


## 当前提示文本；没有提示条时返回空串
func _hint_text() -> String:
	var hint := _hint()
	return "" if hint == null else hint.get_advice_text()


## 提示文本变化：按顺序记录（收起提示的空串不记）
func _on_advice_changed(text: String) -> void:
	if text == "":
		return
	_advice_seq.append(text)


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[TUTORIAL12] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 直接用关卡数据进 1-2 主游戏（1-2 不是选关界面里第一个按钮，走菜单到不了）
func _enter_level(a, wait_tutorial: bool) -> bool:
	if wait_tutorial:
		## 先等引擎把真实主场景（开始菜单）稳定下来
		await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 10.0)
	var para = (load(LEVEL_PATH) as GDScript).new()
	para.set_choose_level(ADV, 0, "0002")
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[para.game_sences])
	if not await _wait_main_game(a, 40.0):
		return false
	if wait_tutorial:
		return await _wait_hint_visible(a, 40.0)
	return true


## 等主游戏进入 MAIN_GAME 阶段（教学里第一步就是「允许操作」，阶段由此推进）
func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null and Global.main_game.main_game_progress == 3:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 等提示条出现（第一句教学出来的那一刻）
func _wait_hint_visible(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var hint := _hint()
		if hint != null and hint.is_advice_visible():
			return true
		await a.wait(0.25)
		waited += 0.25
	return false


## 等第一波真的落下来（开战后还要等关卡数据的 first_wave_delay 秒）
func _wait_wave_started(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var mg = Global.main_game
		if mg != null and mg.zombie_manager != null and mg.zombie_manager.zombie_wave_manager.curr_wave >= 0:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 等教学说到指定那一句（流程里没有步骤下标，只能看提示文本）
func _wait_advice(a, expect_text: String, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if _hint_text() == expect_text:
			return true
		await a.wait(0.25)
		waited += 0.25
	return false


## 反复收阳光 + 补种向日葵，直到教学收尾（提示条收起）
func _grow_sunflowers_to_end(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var mg = Global.main_game
		var hint := _hint()
		if hint != null and not hint.is_advice_visible():
			return true
		await _click_all_suns(a, mg)
		await _try_plant_sunflower(a, mg)
		await a.wait(0.5)
		waited += 0.5
	return false


## 点掉场上所有可点的阳光（阳光掉下来不点不会进账）
func _click_all_suns(a, mg) -> void:
	var suns: Node = mg.suns
	if suns == null:
		return
	for child in suns.get_children():
		var sun := child as Sun
		if sun == null or sun.collected:
			continue
		## 阳光从屏幕上方掉下来，出屏之前点不到
		if sun.get_global_transform_with_canvas().origin.y < 120.0:
			continue
		var btn: Control = sun.get_node_or_null("Button") as Control
		if btn == null or not btn.is_visible_in_tree():
			continue
		var p: Vector2 = a.screen_center(btn)
		await a.click(p.x, p.y)


## 阳光足够且卡片冷却结束时，补种一棵向日葵
func _try_plant_sunflower(a, mg) -> void:
	if mg.hand_manager.is_holding_hand():
		return
	var battle = mg.card_manager.card_slot_battle
	var card: Card = _get_sunflower_card(battle)
	if card == null or not card.is_can_click:
		return
	if battle.sun_value < card.sun_cost:
		return
	var cell: PlantCell = _find_free_cell_in_row(mg, _find_plant_row(mg))
	if cell == null:
		return
	var card_center: Vector2 = a.screen_center(card)
	await a.click(card_center.x, card_center.y)
	await a.wait(0.3)
	var rc: Vector2i = cell.row_col
	await a.click_plant_cell(rc.x, rc.y)
	await a.wait(0.3)


## 出战卡槽里的向日葵卡
func _get_sunflower_card(battle) -> Card:
	if battle == null:
		return null
	for card: Card in battle.curr_cards:
		if card.card_plant_type == CharacterRegistry.PlantType.P002SunFlower:
			return card
	return null


## 找一行真的能种下向日葵的草坪（1-2 只有中间 3 行铺了草皮）
func _find_plant_row(mg) -> int:
	var cond: ResourcePlantCondition = Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P002SunFlower,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	var cell_rows: Array[Array] = mg.plant_cell_manager.all_plant_cells
	for row_index in range(cell_rows.size()):
		var cells: Array = cell_rows[row_index]
		if cells.is_empty():
			continue
		if cond.judge_is_can_plant(cells[1], CharacterRegistry.PlantType.P002SunFlower):
			return row_index
	return -1


## 指定行里第一个「能种且空着」的格子
func _find_free_cell_in_row(mg, row_index: int) -> PlantCell:
	if row_index < 0:
		return null
	var cond: ResourcePlantCondition = Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P002SunFlower,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	var cells: Array = mg.plant_cell_manager.all_plant_cells[row_index]
	for cell in cells:
		var plant_cell := cell as PlantCell
		if plant_cell == null:
			continue
		if not cond.judge_is_can_plant(plant_cell, CharacterRegistry.PlantType.P002SunFlower):
			continue
		if plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm) == null:
			return plant_cell
	return null


## 场上某种植物的数量
func _count_plant(mg, plant_type: CharacterRegistry.PlantType) -> int:
	var num := 0
	for row_cells: Array in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for place in plant_cell.plant_in_cell:
				var plant = plant_cell.get_plant(place)
				if is_instance_valid(plant) and plant.plant_type == plant_type:
					num += 1
	return num
#endregion
