extends RefCounted
## 探针 PROBE8c：新手教程（冒险模式 1-5 铲子教学 / 保龄球关）
## 覆盖：
##   1. 1-5 的开场顺序：戴夫第一段对话（清草坪）→ 玩家铲光豌豆射手 → 戴夫第二段对话（保龄球惊喜）
##      → 预览僵尸 → 正式开局（整段教学排在关卡开局之前）
##   2. 戴夫说两段话（开场 CRAZY_DAVE_2400~2406、铲光后 CRAZY_DAVE_2410~2415），逐句点击推进
##   3. 红线在戴夫念到「我们去玩保龄球！」的同一时刻出现（之前一直藏着）
##   4. 教学按原版顺序推进：拿起铲子 → 铲掉一株 → 铲光草坪 → 戴夫惊喜
##      （1-5 没有「干得漂亮」提示，戴夫说完就收尾进关卡）
##   5. 铲光之前传送带不启动（传送带跟着「开战」走），开局后传送带送卡、第一波僵尸出动
##   6. 箭头跟着目标走（卡槽里的铲子 / 草坪上还活着的植物）
##   7. 教学结束后提示条关掉；已通关 1-5 后再进本关不再播教學与戴夫对话、传送带照常自动启动
##
## ⚠️ 1-5 的铲子教学就是**关卡流程里的一段**（adventure_01_05.gd 的 `_shovel_tutorial_flow`），
## 没有 TutorialManager、没有步骤下标，推进判据一律用「提示文本」
## （文本在关卡提示条上，见 TutorialAdviceUI.find_level_hint）。
## 机器可读汇总：最后一行 [TUTORIAL15] result=PASS|FAIL failed=<n>

var _failed := 0
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_01_05.gd"
const SAVE_NAME_05 := "101_0_0005"
## 教程文本（data/strings/lawn_strings.txt 的 ADVICE_* 原版字符串）
const ADVICE_TAKE_SHOVEL := "点击拾取铲子！"
const ADVICE_DIG_ONE := "点击移除一颗植物！"
const ADVICE_DIG_ALL := "一直挖吧，直到你的草坪上没有植物！"
## 戴夫惊喜对话里触发红线出现的那一句
const DAVE_TALK_BOWLING := "我们去玩保龄球！"
## 原版 1-5 预置的三株豌豆射手位置 (行,列)，都在红线右侧（所以铲掉之后那几列也种不了）
const EXPECT_PRE_PLANT_POS := [Vector2i(2, 6), Vector2i(3, 8), Vector2i(4, 7)]
## 戴夫对话的点击位置（设计分辨率 800x600 的屏幕中心；戴夫的点击面板覆盖全屏，点哪都能推进）
const DAVE_CLICK_POS := Vector2(400, 300)
## 原版 1-5 教学的完整顺序（按提示出现的先后）；戴夫惊喜对话不算提示
const EXPECT_ADVICE: Array[String] = [
	ADVICE_TAKE_SHOVEL,
	ADVICE_DIG_ONE,
	ADVICE_DIG_ALL,
]
## 实际播过的提示（按顺序），由提示条的 signal_advice_changed 记录
var _advice_seq: Array[String] = []
## 本次进关是否出现过戴夫（STEP6 验证「已通关不再播戴夫对话」用）
var _dave_seen := false


func run(a) -> void:
	a.log("")
	a.log("========== 探针：新手教程（1-5 铲子教学 / 保龄球关）==========")

	var state = Global.global_game_state
	## 已通关 1-1 ~ 1-4：拿到铲子（1-5 铲子教学的前提）；1-5 自己还没通关
	state.curr_all_level_state_data = {
		"101_0_0001": {"IsSuccess": true},
		"101_0_0002": {"IsSuccess": true},
		"101_0_0003": {"IsSuccess": true},
		"101_0_0004": {"IsSuccess": true},
	}

	## 第一次进关：开场教学在关卡开局之前跑，进关后先停在「清草坪」这一步
	if not await _enter_level(a, true):
		a.log("!! 进不了关卡（教学没起来）")
		_finish(a)
		return
	await a.wait(1.0)

	var mg = Global.main_game

	# ------------------------------------------------ STEP1 教学启动与预置植物
	a.log("STEP1 教学启动、预置豌豆射手、传送带未启动")
	var hint := _hint()
	_check(a, "本关挂出了提示条", hint != null, str(hint))
	if hint == null:
		_finish(a)
		return
	## 第 1 句在探针接进来之前就播过了，这里补记
	hint.signal_advice_changed.connect(_on_advice_changed)
	if _hint_text() != "" and not _advice_seq.has(_hint_text()):
		_advice_seq.append(_hint_text())
	_check(a, "玩家已拿到铲子（已通关 1-4）", Global.global_game_state.is_shovel_unlocked(),
		str(Global.global_game_state.get_max_success_adventure_level()))
	_check(a, "开局草坪上有 3 株豌豆射手",
		_count_plant(mg, CharacterRegistry.PlantType.P001PeaShooterSingle) == 3,
		str(_count_plant(mg, CharacterRegistry.PlantType.P001PeaShooterSingle)))
	var pre_pos := _pre_plant_positions(mg)
	_check(a, "三株豌豆射手落在原版位置 (2,6)(3,8)(4,7)", pre_pos == EXPECT_PRE_PLANT_POS,
		str(pre_pos))
	_check(a, "第 1 句提示=点击拾取铲子", _hint_text() == ADVICE_TAKE_SHOVEL, _hint_text())
	_check(a, "提示条可见", hint.is_advice_visible(), str(hint.is_advice_visible()))
	_check(a, "箭头指向铲子", hint.is_pointer_visible(), str(hint.is_pointer_visible()))
	var conveyor = mg.card_manager.card_slot_conveyor_belt
	_check(a, "1-5 是传送带卡槽", conveyor != null, str(conveyor))
	_check(a, "教学期间传送带未启动", not mg.card_manager.is_conveyor_belt_started,
		str(mg.card_manager.is_conveyor_belt_started))
	var wave_manager = mg.zombie_manager.zombie_wave_manager
	_check(a, "教学期间第一波未开始", wave_manager.curr_wave == -1, str(wave_manager.curr_wave))
	_check(a, "戴夫说保龄球之前红线藏着", not _is_stripe_visible(mg), str(_is_stripe_visible(mg)))

	# ------------------------------------------------ STEP2 拿起铲子
	a.log("STEP2 点击卡槽里的铲子")
	var ui_shovel: UIShovel = mg.card_slot_root.ui_shovel
	_check(a, "卡槽铲子存在且可见", ui_shovel != null and ui_shovel.visible, str(ui_shovel))
	if ui_shovel == null:
		_finish(a)
		return
	var shovel_pos: Vector2 = a.screen_center(ui_shovel)
	await a.click(shovel_pos.x, shovel_pos.y)
	if not await _wait_advice(a, ADVICE_DIG_ONE, 10.0):
		_check(a, "拿铲子后走到「点击移除一颗植物」", false, "advice=" + _hint_text())
		_finish(a)
		return
	_check(a, "拿铲子后走到「点击移除一颗植物」", true, _hint_text())
	_check(a, "手上拿着铲子",
		mg.hand_manager.get_curr_hand_type() == HandComponentBase.E_HandComponentType.Shovel,
		str(mg.hand_manager.get_curr_hand_type()))
	_check(a, "箭头指向草坪上的植物", _hint().is_pointer_visible(), str(_hint().is_pointer_visible()))

	# ------------------------------------------------ STEP3 铲掉一株
	a.log("STEP3 铲掉第一株豌豆射手")
	if not await _dig_one_plant(a, mg):
		_check(a, "铲掉第一株", false, "剩余=" + str(_count_lawn_plants(mg)))
		_finish(a)
		return
	if not await _wait_advice(a, ADVICE_DIG_ALL, 10.0):
		_check(a, "铲掉一株后走到「一直挖吧」", false, "advice=" + _hint_text())
		_finish(a)
		return
	_check(a, "草坪上还剩 2 株", _count_lawn_plants(mg) == 2, str(_count_lawn_plants(mg)))
	_check(a, "铲掉一株后铲子已放回（用完）", not mg.hand_manager.is_holding_hand(),
		str(mg.hand_manager.is_holding_hand()))
	_check(a, "铲光之前传送带仍未启动", not mg.card_manager.is_conveyor_belt_started,
		str(mg.card_manager.is_conveyor_belt_started))
	_check(a, "铲光之前红线仍藏着", not _is_stripe_visible(mg), str(_is_stripe_visible(mg)))

	# ------------------------------------------------ STEP4 铲光草坪 + 戴夫惊喜 + 红线
	a.log("STEP4 铲光剩下的植物（戴夫介绍保龄球，说到「我们去玩保龄球！」时红线出现）")
	if not await _dig_all_plants(a, mg, 40.0):
		_check(a, "铲光草坪", false, "剩余=" + str(_count_lawn_plants(mg)))
		_finish(a)
		return
	if not await _wait_hint_hidden(a, 10.0):
		_check(a, "铲光后教学收尾", false, "advice=" + _hint_text())
		_finish(a)
		return
	if not await _wait_dave_appear(a, 10.0):
		_check(a, "铲光后戴夫出场说保龄球惊喜", false, "戴夫没出现")
		_finish(a)
		return
	_check(a, "戴夫第一句说完时红线还藏着", not _is_stripe_visible(mg), str(_is_stripe_visible(mg)))
	## 推进一句：念到「我们去玩保龄球！」的同时红线出现
	await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
	await a.wait(0.6)
	_check(a, "戴夫念到「我们去玩保龄球！」", _get_dave_text() == DAVE_TALK_BOWLING, _get_dave_text())
	_check(a, "念到保龄球的同时红线出现", _is_stripe_visible(mg), str(_is_stripe_visible(mg)))
	if not await _skip_dave_dialog(a):
		_check(a, "铲光后播完戴夫惊喜对话", false, "戴夫仍在场")
		_finish(a)
		return
	_check(a, "草坪已铲光", _count_lawn_plants(mg) == 0, str(_count_lawn_plants(mg)))
	_check(a, "教学收尾后提示条已关掉", not _hint().is_advice_visible(),
		str(_hint().is_advice_visible()))
	_check(a, "教学收尾后箭头已收起", not _hint().is_pointer_visible(),
		str(_hint().is_pointer_visible()))
	_check(a, "教学提示共 3 句（没有「干得漂亮」）", _advice_seq == EXPECT_ADVICE, str(_advice_seq))

	# ------------------------------------------------ STEP5 教学收尾 → 预览僵尸 → 开局
	a.log("STEP5 教学收尾（预览僵尸 → 正式开局：传送带与第一波僵尸由关卡流程启动）")
	if not await _wait_battle_started(a, 60.0):
		_check(a, "教学结束后关卡正常开局", false, "传送带未启动")
		_finish(a)
		return
	await a.wait(1.0)
	_check(a, "开局后传送带已启动", mg.card_manager.is_conveyor_belt_started,
		str(mg.card_manager.is_conveyor_belt_started))
	## 第一波由关卡流程按 first_wave_delay 开波（1-5 配了 6 秒），超时要大于该值
	if not await _wait_wave_start(a, wave_manager, 40.0):
		_check(a, "开局后第一波僵尸已启动", false, str(wave_manager.curr_wave))
	else:
		_check(a, "开局后第一波僵尸已启动", true, str(wave_manager.curr_wave))
	_check(a, "传送带已送来卡片", conveyor != null and not conveyor.curr_cards.is_empty(),
		"null" if conveyor == null else str(conveyor.curr_cards.size()))
	_check(a, "开局后红线可见", _is_stripe_visible(mg), str(_is_stripe_visible(mg)))

	# ------------------------------------------------ STEP6 已通关后不再播教学
	a.log("STEP6 已通关 1-5 后再进本关（不播教学与戴夫对话，传送带自动启动）")
	state.curr_all_level_state_data[SAVE_NAME_05] = {"IsSuccess": true}
	_dave_seen = false
	if not await _enter_level(a, false):
		_check(a, "重进 1-5 到 MAIN_GAME", false, "超时")
		_finish(a)
		return
	await a.wait(1.5)
	_check(a, "已通关时不再播戴夫对话", not _dave_seen, str(_dave_seen))
	_check(a, "已通关时不再播教学（没有提示条）",
		_hint() == null or not _hint().is_advice_visible(),
		str(_hint() != null and _hint().is_advice_visible()))
	_check(a, "没有教学时传送带照常自动启动", Global.main_game.card_manager.is_conveyor_belt_started,
		str(Global.main_game.card_manager.is_conveyor_belt_started))
	_check(a, "没有教学时红线照样出现", _is_stripe_visible(Global.main_game),
		str(_is_stripe_visible(Global.main_game)))

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
	a.log("[TUTORIAL15] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 直接用关卡数据进 1-5 主游戏（选关界面进传送带关要走很长的菜单路径）
## wait_tutorial=true：等开场教学跑起来（教学在关卡开局之前）；
## false：等关卡进入 MAIN_GAME（已通关时不播教学）
func _enter_level(a, wait_tutorial: bool) -> bool:
	if wait_tutorial:
		## 先等引擎把真实主场景（开始菜单）稳定下来
		await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 10.0)
	var para = (load(LEVEL_PATH) as GDScript).new()
	para.set_choose_level(ADV, 0, "0005")
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[para.game_sences])
	if not await _wait_main_game_created(a, 40.0):
		return false
	## 开场戴夫对话（在教学之前）：逐句点完
	if not await _wait_opening_dave(a, 40.0):
		return false
	if wait_tutorial:
		return await _wait_hint_visible(a, 20.0)
	return await _wait_main_game(a, 40.0)


## 等主游戏场景就绪
func _wait_main_game_created(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null and Global.main_game.game_para != null:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 等关卡开战（传送带与第一波僵尸都由「开战」启动）
## ⚠️ 不能拿 main_game_progress == MAIN_GAME 当开战判据：
## 教学里的「允许操作」事件也把阶段推进到 MAIN_GAME（那时还没开战）
func _wait_battle_started(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var mg = Global.main_game
		if mg != null and mg.card_manager.is_conveyor_belt_started:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 等主游戏进入 MAIN_GAME 阶段：关卡开场的戴夫对话要逐句点完才进得去
## （已通关不播教学的分支没有「允许操作」，阶段推进只发生在开战）
func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null:
			if _find_dave() != null and not await _skip_dave_dialog(a):
				return false
			if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
				return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 等开场戴夫出现并点完（教学在戴夫说完之后才开始）
## 本关不播开场对话时（已通关重进），等到关卡离开选卡阶段就返回
func _wait_opening_dave(a, timeout: float) -> bool:
	var waited := 0.0
	var is_dave_appeared := false
	while waited < timeout:
		var mg = Global.main_game
		if mg != null:
			if _find_dave() != null:
				is_dave_appeared = true
				_dave_seen = true
				await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
				await a.wait(0.4)
				continue
			if is_dave_appeared:
				return true
			## 已通关时不播开场对话：等到关卡离开选卡阶段（或教学已经放开玩家的手）就返回
			if mg.is_lawn_operation_allowed \
					or mg.main_game_progress != MainGameManager.E_MainGameProgress.CHOOSE_CARD:
				return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 等第一波僵尸开始（超时需大于关卡的 first_wave_delay）
func _wait_wave_start(a, wave_manager, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if wave_manager.curr_wave >= 0:
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


## 等提示条收起（教学收尾）
func _wait_hint_hidden(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var hint := _hint()
		if hint != null and not hint.is_advice_visible():
			return true
		await a.wait(0.25)
		waited += 0.25
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


## 等戴夫出场（教学收尾后的惊喜对话）
func _wait_dave_appear(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if _find_dave() != null:
			return true
		await a.wait(0.25)
		waited += 0.25
	return false


## 界面上正在说话的戴夫（挂在 canvas_layer_ui 下），没有则返回 null
func _find_dave() -> CrazyDave:
	var mg = Global.main_game
	if mg == null:
		return null
	for child in mg.canvas_layer_ui.get_children():
		if child is CrazyDave:
			return child as CrazyDave
	return null


## 戴夫当前这句台词
func _get_dave_text() -> String:
	var dave := _find_dave()
	if dave == null:
		return ""
	return dave.speech_text_label.text


## 保龄球红线当前是否画出来了
func _is_stripe_visible(mg) -> bool:
	if mg == null or mg.game_item_manager == null:
		return false
	var stripe = mg.game_item_manager.gim_other.wallnut_bowling_stripe
	return stripe != null and stripe.visible


## 点掉戴夫对话：戴夫的点击面板覆盖全屏，每点一次推进一句，说到最后一句后自动离场
func _skip_dave_dialog(a, timeout: float = 40.0) -> bool:
	var waited := 0.0
	while waited < timeout:
		if _find_dave() == null:
			return true
		_dave_seen = true
		await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
		await a.wait(0.5)
		waited += 0.5
	return _find_dave() == null


## 铲掉一株：手上没铲子就去卡槽拿（铲一下就用掉一把铲子，这是原版规则）
func _dig_one_plant(a, mg) -> bool:
	if not mg.hand_manager.is_holding_hand():
		var ui_shovel: UIShovel = mg.card_slot_root.ui_shovel
		if ui_shovel == null:
			return false
		var p: Vector2 = a.screen_center(ui_shovel)
		await a.click(p.x, p.y)
		await a.wait(0.4)
	var cell: PlantCell = _find_plant_cell_with_plant(mg)
	if cell == null:
		return false
	var rc: Vector2i = cell.row_col
	var before := _count_lawn_plants(mg)
	await a.click_plant_cell(rc.x, rc.y)
	await a.wait(0.6)
	return _count_lawn_plants(mg) < before


## 反复拿铲子 + 铲，直到草坪上没有植物
func _dig_all_plants(a, mg, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if _count_lawn_plants(mg) <= 0:
			return true
		await _dig_one_plant(a, mg)
		await a.wait(0.3)
		waited += 1.0
	return _count_lawn_plants(mg) <= 0


## 草坪上还种着植物的格子位置 (行,列) 列表，按行、列扫描顺序
## PlantCell.row_col 是 0 开始的下标，这里 +1 换成关卡数据里 plant_cell_pos 的 1 开始口径
func _pre_plant_positions(mg) -> Array:
	var pos_list: Array = []
	for row_cells: Array in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell != null and plant_cell.get_curr_plant_num() > 0:
				pos_list.append(plant_cell.row_col + Vector2i(1, 1))
	return pos_list


## 草坪上第一个还种着植物的格子
func _find_plant_cell_with_plant(mg) -> PlantCell:
	for row_cells: Array in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell != null and plant_cell.get_curr_plant_num() > 0:
				return plant_cell
	return null


## 草坪上还活着的植物总数
func _count_lawn_plants(mg) -> int:
	var num := 0
	for row_cells: Array in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			if plant_cell != null:
				num += plant_cell.get_curr_plant_num()
	return num


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
