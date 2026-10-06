extends RefCounted
## 探针 PROBE8：新手教程（原版冒险模式 1-1）
## 覆盖：
##   1. 首次游玩 1-1（新档）会播教程，开局 150 阳光
##   2. 教程严格按关卡流程（adventure_01_01.run_flow）的那串 await 推进：
##      箭头指种子包 → 捡卡 → 指草地 → 种下 → 夸一句 → 掉阳光 → 收阳光 → 再种一棵 → 僵尸来袭
##   3. 「点击豌豆射手，再种一棵！」是**超时补提示**：说完「阳光够了」先让玩家自己动手，
##      4 秒内没种才补这句（本探针故意先等 5 秒，专门走超时那条分支）
##   4. 教程排在**开战之前**：allow_operation 先放开玩家的手，教程期间不出怪、不自动开波
##   5. 教程结束后提示条与箭头都收起，随后进入开战
##   6. 已通关 1-1 后再进本关不再播教程（原版教程只在冒险模式第一轮出现），改播「准备安放植物」
##
## ⚠️ 1-1 的教程就是**关卡流程里的一段**（adventure_01_01.gd 的 `_tutorial_flow`），
## 没有 TutorialManager、没有步骤下标，所以推进判据一律用「提示文本」
## （提示文本在关卡提示条上，见 `TutorialAdviceUI.find_level_hint`）。
## ⚠️ 关卡文件是 .gd 不是 .tres，要用 load(...).new() 取实例
## 机器可读汇总：最后一行 [TUTORIAL] result=PASS|FAIL failed=<n>

var _failed := 0
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_01_01.gd"
const SAVE_NAME_01 := "101_0_0001"
## 原版教程文本（data/strings/lawn_strings.txt 的 ADVICE_* 条目）
const ADVICE_PICK_PACKET := "点击种子包，把它捡起来！"
const ADVICE_CLICK_GRASS := "点击草地种下你的种子！"
const ADVICE_NICELY_DONE := "干得漂亮！"
const ADVICE_CLICK_SUN := "点击收集掉落的阳光！"
const ADVICE_KEEP_SUN := "继续收集阳光！\n你需要他们来种下更多植物！"
const ADVICE_ENOUGH_SUN := "太好了！你已经收集到了足够\n进行下一次种植的阳光！"
const ADVICE_PLANT_AGAIN := "点击豌豆射手，再种一棵！"
const ADVICE_ZOMBIE := "别让僵尸靠近你的房子！"
## 原版 1-1 教程的完整顺序（按提示出现的先后）
const EXPECT_ADVICE: Array[String] = [
	ADVICE_PICK_PACKET,
	ADVICE_CLICK_GRASS,
	ADVICE_NICELY_DONE,
	ADVICE_CLICK_SUN,
	ADVICE_KEEP_SUN,
	ADVICE_ENOUGH_SUN,
	ADVICE_PLANT_AGAIN,
	ADVICE_ZOMBIE,
]
## 实际播过的提示（按顺序），由提示条的 signal_advice_changed 记录
var _advice_seq: Array[String] = []


func run(a) -> void:
	a.log("")
	a.log("========== PROBE8 新手教程（1-1）==========")

	var state = Global.global_game_state
	## 新档：只有豌豆射手，没有任何通关记录
	state.curr_plant.assign([CharacterRegistry.PlantType.P001PeaShooterSingle])
	state.curr_all_level_state_data = {}

	if not await _goto_level(a):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	if not await _wait_main_game(a, 40.0):
		a.log("!! 没进到 MAIN_GAME 阶段")
		_finish(a)
		return
	## 教程排在开战之前：先等「允许操作」放开了手、出战卡槽到位
	if not await _wait_operation_allowed(a, 20.0):
		a.log("!! 迟迟没有进入可操作阶段")
		_finish(a)
		return
	if not await _wait_hint_visible(a, 20.0):
		a.log("!! 教程没有起来（提示条没出现）")
		_finish(a)
		return

	var mg = Global.main_game
	var battle = mg.card_manager.card_slot_battle
	var wave_manager = mg.zombie_manager.zombie_wave_manager

	# ------------------------------------------------ STEP1 教程启动
	a.log("STEP1 教程启动与开局参数")
	var hint = _hint()
	_check(a, "本关挂出了提示条", hint != null, str(hint))
	if hint == null:
		_finish(a)
		return
	## 记录每一句实际播出的提示，最后与「关卡流程里的顺序」整体比对
	## （接进来之前可能已经播过几句，这里补记当前的）
	hint.signal_advice_changed.connect(_on_advice_changed)
	if _hint_text() != "" and not _advice_seq.has(_hint_text()):
		_advice_seq.append(_hint_text())
	_check(a, "玩家已被允许操作", mg.is_lawn_operation_allowed, str(mg.is_lawn_operation_allowed))
	_check(a, "卡槽阳光=150", battle.sun_value == 150, str(battle.sun_value))
	_check(a, "第 1 句提示=捡起种子包", _hint_text() == ADVICE_PICK_PACKET, _hint_text())
	_check(a, "提示条可见", hint.is_advice_visible(), str(hint.is_advice_visible()))
	_check(a, "箭头可见", hint.is_pointer_visible(), str(hint.is_pointer_visible()))
	## 提示条高度是算出来的（多行长提示要撑开）：算错会撑成几百高，从底部抬起来盖住草坪
	_check(a, "提示条高度没撑爆", hint.get_advice_panel_size().y <= 200.0,
		str(hint.get_advice_panel_size()))
	_check(a, "教程期间第一波未开始", wave_manager.curr_wave == -1, str(wave_manager.curr_wave))

	# ------------------------------------------------ STEP2 点击种子包
	a.log("STEP2 点击种子包，卡片拿在手上")
	if battle.curr_cards.is_empty():
		_check(a, "战斗卡槽有卡", false, "空")
		_finish(a)
		return
	var card: Control = battle.curr_cards[0]
	var card_center: Vector2 = a.screen_center(card)
	await a.click(card_center.x, card_center.y)
	if not await _wait_advice(a, ADVICE_CLICK_GRASS, 8.0):
		_check(a, "点卡后走到「点击草地」", false, "advice=" + _hint_text())
		_finish(a)
		return
	_check(a, "点卡后走到「点击草地」", true, _hint_text())
	_check(a, "卡片已拿在手上", mg.hand_manager.is_holding_hand(), str(mg.hand_manager.is_holding_hand()))

	# ------------------------------------------------ STEP3 种下第一株豌豆射手
	a.log("STEP3 种下第一株豌豆射手")
	var plant_row := _find_plant_row(mg)
	a.log("  可种植的行 = %d" % plant_row)
	_check(a, "1-1 有可种植的草坪行", plant_row >= 0, str(plant_row))
	if plant_row < 0:
		_finish(a)
		return
	await a.click_plant_cell(plant_row, 1)
	if not await _wait_advice(a, ADVICE_NICELY_DONE, 12.0):
		_check(a, "种下后走到「干得漂亮」", false, "advice=" + _hint_text())
		_finish(a)
		return
	_check(a, "种下后走到「干得漂亮」", true, _hint_text())
	_check(a, "种下后卡槽阳光=50", battle.sun_value == 50, str(battle.sun_value))
	_check(a, "教程排在开战之前：此时仍没开波", wave_manager.curr_wave == -1, str(wave_manager.curr_wave))

	# ------------------------------------------------ STEP4 收阳光
	a.log("STEP4 点击收集阳光（教程固定掉落 + 凑够 100）")
	if not await _collect_sun_until_advice(a, ADVICE_ENOUGH_SUN, 60.0):
		_check(a, "收够阳光后走到「足够阳光」", false,
			"advice=" + _hint_text() + " 阳光=" + str(battle.sun_value))
		_finish(a)
		return
	_check(a, "收够阳光后走到「足够阳光」", true, _hint_text())
	_check(a, "阳光达到 100", battle.sun_value >= 100, str(battle.sun_value))
	## 带 \n 的长提示：提示条要撑到够放（不够会裁字），又不能撑成几百高盖住草坪
	## 具体的行数 / 高度估算在 TutorialAdviceUI._measure_advice_height 里
	## 提示条贴屏幕底部、宽度接近整屏，长句在 26 号字下最多两行：够放即可（下限 = 最小条高 64）
	var long_height: float = _hint().get_advice_panel_size().y if _hint() != null else 0.0
	_check(a, "多行提示时提示条高度合理", long_height >= 64.0 and long_height <= 200.0, str(long_height))

	# ------------------------------------------------ STEP5 没动手才补「再种一棵」
	a.log("STEP5 说完「阳光够了」先等玩家自己动手")
	## 「再种一棵」这句是**超时补提示**：这里故意先不动手，限定的 4 秒过去才该出现
	await a.wait(5.0)
	_check(a, "玩家没动手时才补「再种一棵」", _hint_text() == ADVICE_PLANT_AGAIN,
		_hint_text())

	# ------------------------------------------------ STEP6 种下第二株
	a.log("STEP6 种下第二株豌豆射手")
	var card2: Card = battle.curr_cards[0]
	var card_wait := await _wait_card_ready(a, card2, 20.0)
	a.log("  等卡片冷却完: %s is_can_click=%s 阳光=%d" % [
		str(card_wait), str(card2.is_can_click), battle.sun_value])
	await a.click(card_center.x, card_center.y)
	await a.wait(0.8)
	_check(a, "第二次点卡后拿在手上", mg.hand_manager.is_holding_hand(),
		str(mg.hand_manager.is_holding_hand()))
	await a.click_plant_cell(plant_row, 2)
	if not await _wait_hint_hidden(a, 20.0):
		_check(a, "种下第二株后教学收尾", false, "advice=" + _hint_text())
		_finish(a)
		return
	_check(a, "教学收尾后提示条已关掉", not _hint().is_advice_visible(),
		str(_hint().is_advice_visible()))
	_check(a, "教学收尾后箭头已收起", not _hint().is_pointer_visible(),
		str(_hint().is_pointer_visible()))
	_check(a, "场上已种下 2 株豌豆射手", _count_plant(mg, CharacterRegistry.PlantType.P001PeaShooterSingle) >= 2,
		str(_count_plant(mg, CharacterRegistry.PlantType.P001PeaShooterSingle)))
	_check(a, "教程提示顺序与关卡流程一致", _advice_seq == EXPECT_ADVICE, str(_advice_seq))

	# ------------------------------------------------ STEP7 教学跑完接着开战
	a.log("STEP7 教学跑完接着开战")
	if not await _wait_wave_started(a, wave_manager, 40.0):
		_check(a, "教学结束后关卡正常开战", false, "curr_wave=" + str(wave_manager.curr_wave))
		_finish(a)
		return
	_check(a, "教学结束后关卡正常开战", true, "curr_wave=" + str(wave_manager.curr_wave))

	# ------------------------------------------------ STEP8 已通关后不再播教程
	a.log("STEP8 已通关 1-1 后再进本关（不播教程）")
	state.curr_all_level_state_data[SAVE_NAME_01] = {"IsSuccess": true}
	_check(a, "1-1 已有通关记录", state.curr_all_level_state_data.has(SAVE_NAME_01))
	## 关卡是脚本（.gd）：load 出来的是 GDScript，new() 才是关卡实例
	var para2_res = load(LEVEL_PATH)
	var para2: ResourceLevelData = para2_res.new() if para2_res is Script else para2_res
	para2.set_choose_level(ADV, 0, "0001")
	Global.game_para = para2
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront])
	if not await _wait_main_game(a, 30.0):
		_check(a, "重进 1-1 到 MAIN_GAME", false, "超时")
		_finish(a)
		return
	await a.wait(3.0)
	_check(a, "已通关时场上没有教程提示条", _hint() == null or not _hint().is_advice_visible(),
		str(_hint() != null and _hint().is_advice_visible()))
	## 已通关分支跳过了教程，走的是「允许操作 → 准备安放植物 → 开战」
	var mg2 = Global.main_game
	var wave2 = mg2.zombie_manager.zombie_wave_manager
	if not await _wait_wave_started(a, wave2, 40.0):
		_check(a, "已通关分支跳过教程后正常开战", false, "curr_wave=" + str(wave2.curr_wave))
		_finish(a)
		return
	_check(a, "已通关分支跳过教程后正常开战", true, "curr_wave=" + str(wave2.curr_wave))

	# ------------------------------------------------ STEP9 教程中途退回主菜单
	a.log("STEP9 教程卡在「等玩家捡卡」时退回主菜单")
	## 流程协程还挂在 wait_take_card 上时玩家退回主菜单：MainGameManager 一被释放，
	## 等待事件必须自己退出，不能再去访问已释放的对象（见 LevelScriptBase._run_event 的保护）
	## 先回主菜单（_goto_level 从那里起步），再清掉通关记录让教程重播
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])
	await a.wait(2.0)
	state.curr_all_level_state_data = {}
	state.curr_plant.assign([CharacterRegistry.PlantType.P001PeaShooterSingle])
	if not await _goto_level(a):
		_check(a, "重进 1-1（准备中途退场）", false, "进不了关卡")
		_finish(a)
		return
	if not await _wait_hint_visible(a, 20.0):
		_check(a, "教程重新起来", false, "提示条没出现")
		_finish(a)
		return
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])
	await a.wait(3.0)
	_check(a, "已退回主菜单", a.get_node_or_null("/root/StartMenu") != null,
		str(a.get_node_or_null("/root/StartMenu")))
	_check(a, "退回主菜单后主游戏已释放", not is_instance_valid(Global.main_game),
		str(is_instance_valid(Global.main_game)))

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
	a.log("[TUTORIAL] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 等主游戏进入 MAIN_GAME 阶段
func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null and Global.main_game.main_game_progress == 3:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 等「允许操作」：出战卡槽进场、卡片可以点了（教程要玩家先动手）
func _wait_operation_allowed(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var mg = Global.main_game
		if mg != null and mg.is_lawn_operation_allowed:
			var battle = mg.card_manager.card_slot_battle
			if battle != null and not battle.curr_cards.is_empty() \
					and (battle.curr_cards[0] as Card).is_can_click:
				return true
		await a.wait(0.25)
		waited += 0.25
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


## 反复点掉场上的阳光，直到教学说到指定那一句（阳光掉下来不点不会进账）
func _collect_sun_until_advice(a, expect_text: String, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var mg = Global.main_game
		if _hint_text() == expect_text:
			return true
		var suns: Node = mg.suns
		if suns != null:
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
		await a.wait(0.5)
		waited += 0.5
	return false


## 等第一波僵尸开出来（教学跑完之后关卡才开战）
func _wait_wave_started(a, wave_manager, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if wave_manager.curr_wave >= 0:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 等卡片冷却结束（种下第一株后卡片要等冷却，真实玩家也是等它亮起来再点）
func _wait_card_ready(a, card: Card, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if card.is_can_click:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 找一行真的能种下豌豆射手的草坪（1-1 只有部分行铺了草皮）
func _find_plant_row(mg) -> int:
	var cond: ResourcePlantCondition = Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P001PeaShooterSingle,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	var cell_rows: Array[Array] = mg.plant_cell_manager.all_plant_cells
	for row_index in range(cell_rows.size()):
		var cells: Array = cell_rows[row_index]
		if cells.is_empty():
			continue
		if cond.judge_is_can_plant(cells[1], CharacterRegistry.PlantType.P001PeaShooterSingle):
			return row_index
	return -1


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


## 启动 -> 冒险模式 -> 第 1 关
func _goto_level(a) -> bool:
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)
	await a.click_first("Menu/Button1")
	if not await a.wait_scene("choose_level", 12.0):
		return false
	var gcl: Node = a.get_node_or_null("/root/ChooseLevel/AllPage/GridContainer")
	if gcl == null:
		return false
	await a.press_first("ChooseLevelButton/TextureButton")
	return await a.wait_scene("main_game", 10.0)
#endregion
