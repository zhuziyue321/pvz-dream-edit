extends RefCounted
## 探针 PROBE4：手持物组件机制
## 覆盖：
##   1. 组件注册与「手持 ⇄ 空手」状态流转（组件类型、is_holding_hand）
##   2. 反复点同一张卡不会在 TemporaryCharacter 下堆积节点（柱子模式虚影泄漏回归）
##   3. 种植成功会放下手持物并扣阳光；点到不能种的格子会继续手持（不再丢卡）
##   4. 铲子：拿到手上时卡槽只留背景（不再出现两把铲子）、铲完自动放回、右键取消
## 机器可读汇总：最后一行 [HAND] result=PASS|FAIL failed=<n>

const CARD_LIST := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotContainer/CardSlotBattle/CardUiList"
const SHOVEL := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotContainer/ShovelContainer/UIShovel"
const GRID := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotNorm/CardSlotCandidate/AllCardPage/GridContainerPlant"
## 手持美术挂载节点（手持物组件把卡片美术挂在这里）
const TEMP_CHARACTER := "/root/MainGame/CanvasLayerTemp/TemporaryCharacter"
const TARGET_CELL := Vector2i(1, 1)
## 反复点卡次数（泄漏回归用）
const REPEAT_TIMES := 6

var _failed := 0
var _card_path := ""


func run(a) -> void:
	a.log("")
	a.log("========== PROBE4 手持物组件 ==========")
	if not await _goto_level(a):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	await a.wait(6.0)
	await _pick_card(a)
	if not await _to_battle(a):
		_finish(a)
		return

	var card := _first_battle_card(a)
	if card == null:
		a.log("!! 战斗卡槽没有卡")
		_finish(a)
		return
	_card_path = str(card.get_path())
	## 关卡起手只有 50 阳光,而 1-1 解锁的豌豆射手要 100,
	## 用测试事件把阳光补到 500,保证手持物流程不被"买不起"卡住
	EventBus.push_event("test_change_sun_value", [500])
	a.log("  测试补充阳光 -> %d" % _sun())

	_check_registry(a)
	await _check_take_card(a)
	await _check_no_leak(a)
	await _check_plant(a)
	await _check_invalid_cell_keeps_hand(a)
	await _check_right_click_cancel(a)
	await _check_shovel(a)
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
	a.log("[HAND] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion


#region 状态读取
func _hm() -> HandManager:
	return Global.main_game.hand_manager


func _hand_type() -> int:
	return _hm().get_curr_hand_type()


func _holding() -> bool:
	return _hm().is_holding_hand()


func _hand_node_count() -> int:
	var tc: Node = Global.main_game.get_node_or_null("CanvasLayerTemp/TemporaryCharacter")
	if tc == null:
		return -1
	return tc.get_child_count()


func _sun() -> int:
	return Global.main_game.card_manager.card_slot_battle.sun_value


func _cell_plants(spec: Vector2i) -> Array:
	var res: Array = []
	var pc = Global.main_game.plant_cell_manager.all_plant_cells[spec.x][spec.y]
	for key in pc.plant_in_cell:
		if is_instance_valid(pc.plant_in_cell[key]):
			res.append(str(pc.plant_in_cell[key].plant_type))
	return res
#endregion


#region 检查项
## 组件注册 + 空手初始状态 + 铲子界面初始状态
func _check_registry(a) -> void:
	a.log("")
	a.log("--- 1. 组件注册与初始状态 ---")
	var hm = _hm()
	a.log("  已注册组件类型: %s" % str(hm.all_hand_components.keys()))
	_check(a, "空手组件已注册", hm.get_hand_component(HandComponentBase.E_HandComponentType.Null) != null)
	_check(a, "角色组件已注册", hm.get_hand_component(HandComponentBase.E_HandComponentType.Character) != null)
	var shovel_comp = hm.get_hand_component(HandComponentBase.E_HandComponentType.Shovel)
	_check(a, "铲子组件已注册", shovel_comp != null)
	_check(a, "初始为空手", _hand_type() == HandComponentBase.E_HandComponentType.Null, "type=%d" % _hand_type())
	_check(a, "初始未手持", not _holding())
	if shovel_comp != null:
		_check(a, "铲子组件按关卡参数启用", shovel_comp.is_enabling, "is_enabling=%s" % str(shovel_comp.is_enabling))
	var ui_shovel: Control = a.get_node_or_null(SHOVEL)
	if ui_shovel != null:
		_check(a, "游玩阶段显示铲子卡槽", (ui_shovel as CanvasItem).visible)
		var icon: Control = a.get_node_or_null(SHOVEL + "/Shovel")
		_check(a, "空手时显示铲子图标", icon != null and (icon as CanvasItem).visible)


## 点卡 → 拿在手上
func _check_take_card(a) -> void:
	a.log("")
	a.log("--- 2. 点卡拿到手上 ---")
	await a.click_node(_card_path)
	await a.wait(0.3)
	_check(a, "手持类型=角色", _hand_type() == HandComponentBase.E_HandComponentType.Character, "type=%d" % _hand_type())
	_check(a, "处于手持中", _holding())
	_check(a, "手持美术=2 个节点", _hand_node_count() == 2, "count=%d" % _hand_node_count())


## 反复点同一张卡：手持美术应当只有 2 个节点，不允许堆积（回归：柱子模式虚影泄漏）
func _check_no_leak(a) -> void:
	a.log("")
	a.log("--- 3. 反复点卡不堆积节点（共 %d 次）---" % REPEAT_TIMES)
	var base_hand := _hand_node_count()
	var base_all: int = a.get_tree().get_node_count()
	for i in range(REPEAT_TIMES):
		await a.click_node(_card_path)
		await a.wait(0.15)
	await a.frames(5)
	var now_hand := _hand_node_count()
	var now_all: int = a.get_tree().get_node_count()
	## TemporaryCharacter 是手持美术与柱子虚影唯一的挂载点，所以它的子节点数就是
	## 手持物是否泄漏的精确信号；全场景节点数会被同时进行的刷怪/阳光干扰，只做参考。
	a.log("  手持美术节点: %d -> %d ; 全场景节点: %d -> %d（参考值，含同时进行的刷怪）" % [
		base_hand, now_hand, base_all, now_all])
	_check(a, "手持美术节点数恰好为 2", now_hand == 2, "%d -> %d" % [base_hand, now_hand])
	_check(a, "组件节点数不变", _hm().get_child_count() == 3, "count=%d" % _hm().get_child_count())
	_check(a, "反复点卡后仍在手持", _holding())


## 种植成功：放下手持物 + 扣阳光
func _check_plant(a) -> void:
	a.log("")
	a.log("--- 4. 种植成功 ---")
	var sun_before := _sun()
	var before := _cell_plants(TARGET_CELL)
	await a.click_plant_cell(TARGET_CELL.x, TARGET_CELL.y)
	await a.wait(0.6)
	var after := _cell_plants(TARGET_CELL)
	a.log("  格子%s 植物 %s -> %s ; 阳光 %d -> %d" % [str(TARGET_CELL), str(before), str(after), sun_before, _sun()])
	_check(a, "植物已种下", after.size() > before.size())
	_check(a, "阳光已扣除", _sun() < sun_before, "%d -> %d" % [sun_before, _sun()])
	_check(a, "种植后回到空手", _hand_type() == HandComponentBase.E_HandComponentType.Null, "type=%d" % _hand_type())
	_check(a, "手持美术已释放", _hand_node_count() == 0, "count=%d" % _hand_node_count())


## 点到已占用的格子：不能种，但卡片必须留在手上
func _check_invalid_cell_keeps_hand(a) -> void:
	a.log("")
	a.log("--- 5. 点到不能种的格子仍然手持 ---")
	await _reset_card_cooldown(a)
	await a.click_node(_card_path)
	await a.wait(0.3)
	if not _holding():
		_check(a, "（前置）重新拿卡成功", false, "type=%d" % _hand_type())
		return
	await a.click_plant_cell(TARGET_CELL.x, TARGET_CELL.y)
	await a.wait(0.5)
	a.log("  点击已占用格子后 手持类型=%d 手持中=%s" % [_hand_type(), str(_holding())])
	_check(a, "不能种时不丢卡", _holding() and _hand_type() == HandComponentBase.E_HandComponentType.Character)


## 右键取消手持
func _check_right_click_cancel(a) -> void:
	a.log("")
	a.log("--- 6. 右键取消手持 ---")
	## 右键点卡槽空白（保证当前不在格子上）
	await _right_click(a, Vector2(300, 30))
	await a.wait(0.3)
	_check(a, "右键后回到空手", _hand_type() == HandComponentBase.E_HandComponentType.Null, "type=%d" % _hand_type())
	_check(a, "右键后未手持", not _holding())
	_check(a, "右键后手持美术已释放", _hand_node_count() == 0, "count=%d" % _hand_node_count())


## 铲子：界面收敛 + 铲除 + 第二次点击不产生双铲子
func _check_shovel(a) -> void:
	a.log("")
	a.log("--- 7. 铲子组件 ---")
	var shovel_comp = _hm().get_hand_component(HandComponentBase.E_HandComponentType.Shovel)
	if shovel_comp == null:
		_check(a, "（前置）铲子组件存在", false)
		return
	var ui_shovel: CanvasItem = a.get_node_or_null(SHOVEL)
	var icon: CanvasItem = a.get_node_or_null(SHOVEL + "/Shovel")
	var real_shovel: CanvasItem = a.get_node_or_null("/root/MainGame/CanvasLayerTemp/RealShovel")
	if ui_shovel == null or icon == null or real_shovel == null:
		_check(a, "（前置）铲子界面节点齐全", false)
		return

	await a.click_node(SHOVEL + "/Button")
	await a.wait(0.3)
	_check(a, "手持类型=铲子", _hand_type() == HandComponentBase.E_HandComponentType.Shovel, "type=%d" % _hand_type())
	_check(a, "处于手持中", _holding())
	_check(a, "真铲子显示", real_shovel.visible)
	_check(a, "铲子卡槽仍显示(留背景)", ui_shovel.visible)
	_check(a, "卡槽铲子图标已隐藏", not icon.visible)

	## 再点一次卡槽铲子：不允许出现「手上一把 + 卡槽一把」
	await a.click_node(SHOVEL + "/Button")
	await a.wait(0.3)
	_check(a, "重复点铲子不产生双铲子", _hand_type() == HandComponentBase.E_HandComponentType.Shovel \
		and (not icon.visible) and ui_shovel.visible)

	## 铲掉刚才种的植物
	var before := _cell_plants(TARGET_CELL)
	await a.click_plant_cell(TARGET_CELL.x, TARGET_CELL.y)
	await a.wait(0.8)
	var after := _cell_plants(TARGET_CELL)
	a.log("  格子%s 植物 %s -> %s" % [str(TARGET_CELL), str(before), str(after)])
	_check(a, "植物已被铲除", after.size() < before.size())
	_check(a, "铲除后回到空手", _hand_type() == HandComponentBase.E_HandComponentType.Null, "type=%d" % _hand_type())
	_check(a, "真铲子已收起", not real_shovel.visible)
	_check(a, "空手后卡槽铲子图标恢复", icon.visible)
#endregion


#region 操作封装
## 清掉卡片冷却，便于探针反复用同一张卡（探针专用）
func _reset_card_cooldown(a) -> void:
	await a.call_on(_card_path, "set_card_cool_end")
	await a.call_on(_card_path, "card_ready")


func _first_battle_card(a) -> Control:
	var cl: Node = a.get_node_or_null(CARD_LIST)
	if cl == null:
		return null
	for slot in cl.get_children():
		for c in slot.get_children():
			if c is Control and (c as Control).is_visible_in_tree() and c.get("sun_cost") != null:
				return c as Control
	return null


func _screen_center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


func _move(a, p: Vector2) -> void:
	Input.warp_mouse(p)
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await a.frames(3)


func _click(a, p: Vector2) -> void:
	await _move(a, p)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	down.global_position = p
	Input.parse_input_event(down)
	await a.frames(2)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p
	up.global_position = p
	Input.parse_input_event(up)
	await a.frames(2)


func _right_click(a, p: Vector2) -> void:
	await _move(a, p)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = p
	down.global_position = p
	Input.parse_input_event(down)
	await a.frames(2)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = p
	up.global_position = p
	Input.parse_input_event(up)
	await a.frames(2)


## 启动 → 选关 → 进主游戏场景
func _goto_level(a) -> bool:
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)
	await a.click_first("Menu/Button1")
	if not await a.wait_scene("choose_level", 12.0):
		return false
	var gcl: Node = a.get_node_or_null("/root/ChooseLevel/AllPage/GridContainer")
	if gcl == null:
		return false
	var chosen := ""
	for ch in gcl.get_children():
		var nm := str(ch.name)
		if not nm.begins_with("ChooseLevelButton"):
			continue
		var btn := ch.get_node_or_null("TextureButton")
		if btn == null or (btn as BaseButton).disabled:
			continue
		if nm == "ChooseLevelButton":
			chosen = nm
			break
		if chosen == "":
			chosen = nm
	if chosen == "":
		return false
	await a.press_first(chosen + "/TextureButton")
	return await a.wait_scene("main_game", 10.0)


## 选卡阶段选一张卡（和 probe_plant 一致，选 Card5）
func _pick_card(a) -> void:
	var g: Node = a.get_node_or_null(GRID)
	if g == null:
		a.log("!! 找不到选卡面板")
		return
	var target: Control = null
	for ph in g.get_children():
		var cc := ph.get_node_or_null("CardCandidateContainer")
		if cc == null or not (cc as Control).is_visible_in_tree():
			continue
		for c in cc.get_children():
			if str(c.name) == "Card5":
				target = cc
	if target == null:
		## 植物解锁进度生效后,1-1 只解锁豌豆射手,Card5 不可见,直接用关卡预选卡
		a.log("-- 没找到可选的 Card5(未解锁?),跳过选卡")
		return
	await _click(a, _screen_center(target))
	await a.wait(0.6)


func _to_battle(a) -> bool:
	Global.main_game.choosed_card_start_game()
	await a.wait(6.0)
	a.log("  阶段=%d 阳光=%d" % [Global.main_game.main_game_progress, _sun()])
	if Global.main_game.main_game_progress != 3:
		a.log("!! 还没到 MAIN_GAME 阶段")
		return false
	return true
#endregion
