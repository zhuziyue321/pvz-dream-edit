extends RefCounted
## 探针 PROBE3：验证「屏幕坐标 = get_global_transform_with_canvas() * 本地中心」，
## 并用它真的种下一棵植物。

const GRID := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotNorm/CardSlotCandidate/AllCardPage/GridContainerPlant"
const CARD_LIST := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotContainer/CardSlotBattle/CardUiList"


func _v2(v) -> String:
	return "(%.1f,%.1f)" % [v.x, v.y]


## 关键：屏幕上真正可点的位置
func _screen_center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


func run(a) -> void:
	a.log("PROBE3 启动")
	if not await _goto_level(a):
		a.log("PROBE3 失败: 进不了关卡")
		a.quit_game()
		return
	await a.wait(6.0)
	_dump_canvas(a)
	await _pick_card(a)
	if not await _to_battle(a):
		a.quit_game()
		return
	_dump_compare(a)
	await _hover_check(a)
	await _click_card(a)
	await _plant_test(a)
	a.quit_game()


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


func _dump_canvas(a) -> void:
	var vp: Viewport = Global.main_game.get_viewport()
	a.log("")
	a.log("--- 进关卡后的画布变换（这就是之前漏掉的东西）---")
	a.log("canvas_transform = %s" % str(vp.get_canvas_transform()))
	a.log("canvas_transform.origin = %s" % _v2(vp.get_canvas_transform().origin))
	var cam: Camera2D = vp.get_camera_2d()
	a.log("当前 Camera2D = %s" % (str(cam.get_path()) + " pos=" + _v2(cam.global_position) + " offset=" + _v2(cam.offset) if cam != null else "无"))


func _pick_card(a) -> void:
	var g: Node = a.get_node_or_null(GRID)
	var potato: Node = null
	if g != null:
		for ph in g.get_children():
			var cc := ph.get_node_or_null("CardCandidateContainer")
			if cc == null:
				continue
			for c in cc.get_children():
				if str(c.name) == "Card5":
					potato = cc
	if potato == null:
		## 植物解锁进度生效后,1-1 只解锁豌豆射手,土豆地雷(Card5)并不在候选区,
		## 关卡自带预选卡会直接进入战斗卡槽,这里跳过选卡
		a.log("-- 没找到 Card5(未解锁?),跳过选卡,直接使用关卡预选卡")
		return
	var p := _screen_center(potato as Control)
	a.log("选卡: %s 屏幕中心=%s (rect中心=%s)" % [
		str((potato as Control).get_path()), _v2(p), _v2((potato as Control).get_global_rect().get_center())])
	await _click(a, p)
	await a.wait(0.6)


func _to_battle(a) -> bool:
	## 卡槽被系统自动填满时关卡已跳过选卡并进入主游戏，不要重复触发开始流程
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.choosed_card_start_game()
	await a.wait(6.0)
	a.log("阶段=%d 阳光=%d" % [
		Global.main_game.main_game_progress,
		Global.main_game.card_manager.card_slot_battle.sun_value])
	if Global.main_game.main_game_progress != 3:
		a.log("!! 还没到 MAIN_GAME 阶段")
		return false
	return true


func _dump_compare(a) -> void:
	a.log("")
	a.log("--- rect 中心 vs 屏幕中心 ---")
	var root: Node = a.get_node_or_null("/root/MainGame/PlantCellsRoot")
	for spec in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(4, 8)]:
		var row: Node = root.get_child(spec.x)
		var cell: Control = null
		for c in row.get_children():
			if (c as Control).row_col == spec:
				cell = c
		if cell == null:
			continue
		var b: Control = cell.get_node_or_null("Button")
		a.log("  %s row_col=%s rect中心=%s 屏幕中心=%s 差=%s" % [
			str(cell.get_path()), str(spec),
			_v2(b.get_global_rect().get_center()), _v2(_screen_center(b)),
			_v2(_screen_center(b) - b.get_global_rect().get_center())])


func _hover_check(a) -> void:
	a.log("")
	a.log("--- 用屏幕中心悬停，看游戏是否认为进了这个格 ---")
	var root: Node = a.get_node_or_null("/root/MainGame/PlantCellsRoot")
	for spec in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 4), Vector2i(4, 8)]:
		var row: Node = root.get_child(spec.x)
		var cell: Control = null
		for c in row.get_children():
			if (c as Control).row_col == spec:
				cell = c
		if cell == null:
			continue
		var b: Control = cell.get_node_or_null("Button")
		await _move(a, _screen_center(b))
		var hm = Global.main_game.hand_manager
		var got := "-"
		if hm.curr_plant_cell != null:
			got = str(hm.curr_plant_cell.get_path())
		var vp: Viewport = Global.main_game.get_viewport()
		a.log("  停%s -> hovered=%s curr=%s %s" % [
			_v2(_screen_center(b)),
			str(vp.gui_get_hovered_control().get_path()) if vp.gui_get_hovered_control() != null else "无",
			got, ("OK" if got == str(cell.get_path()) else "MISS")])


func _click_card(a) -> void:
	var cl: Node = a.get_node_or_null(CARD_LIST)
	var card: Control = null
	if cl != null:
		for slot in cl.get_children():
			for c in slot.get_children():
				if c is Control and (c as Control).is_visible_in_tree() and c.get("sun_cost") != null:
					card = c
					break
			if card != null:
				break
	if card == null:
		a.log("!! 战斗卡槽没有卡")
		return
	var p := _screen_center(card)
	var cost: int = int(card.get("sun_cost"))
	a.log("点卡: %s 价格=%d 屏幕中心=%s" % [str(card.get_path()), cost, _v2(p)])
	## 开局阳光可能不够(1-1 起手 50,豌豆射手 100),先收集天降阳光攒够再点
	await _wait_sun(a, cost)
	await _click(a, p)


## 收集天降阳光直到够钱: 阳光掉下来要点一下才会进账,光等是不会涨的
func _wait_sun(a, need: int) -> void:
	var waited := 0.0
	var picked := 0
	while Global.main_game.card_manager.card_slot_battle.sun_value < need and waited < 60.0:
		var suns: Node = Global.main_game.suns
		if suns != null:
			for s in suns.get_children():
				if not (s is Sun) or (s as Sun).collected:
					continue
				var btn: Control = s.get_node_or_null("Button") as Control
				if btn == null or not btn.is_visible_in_tree():
					continue
				await _click(a, _screen_center(btn))
				picked += 1
		await a.wait(1.0)
		waited += 1.0
	a.log("收集阳光: 等 %.1fs 点了 %d 个,当前阳光=%d" % [
		waited, picked, Global.main_game.card_manager.card_slot_battle.sun_value])
	await a.wait(0.8)
	var hm = Global.main_game.hand_manager
	a.log("点卡后 手持类型=%d 手持中=%s 阳光=%d" % [
		hm.get_curr_hand_type(), str(hm.is_holding_hand()),
		Global.main_game.card_manager.card_slot_battle.sun_value])


func _plant_test(a) -> void:
	var spec := Vector2i(1, 1)
	var root: Node = a.get_node_or_null("/root/MainGame/PlantCellsRoot")
	var row: Node = root.get_child(spec.x)
	var cell: Control = null
	for c in row.get_children():
		if (c as Control).row_col == spec:
			cell = c
	if cell == null:
		a.log("!! 找不到目标格")
		return
	var b: Control = cell.get_node_or_null("Button")
	var p := _screen_center(b)
	var sun0: int = Global.main_game.card_manager.card_slot_battle.sun_value
	a.log("")
	a.log("--- 种植：目标 %s row_col=%s 屏幕中心=%s 阳光前=%d ---" % [
		str(cell.get_path()), str(spec), _v2(p), sun0])
	await _click(a, p)
	await a.wait(0.5)
	var hm = Global.main_game.hand_manager
	a.log("点击后 阳光=%d 手持类型=%d 手持中=%s" % [
		Global.main_game.card_manager.card_slot_battle.sun_value,
		hm.get_curr_hand_type(), str(hm.is_holding_hand())])
	await a.wait(2.0)
	var pcm = Global.main_game.plant_cell_manager
	var planted: Array[String] = []
	for r in range(pcm.all_plant_cells.size()):
		for c in range(pcm.all_plant_cells[r].size()):
			var pc = pcm.all_plant_cells[r][c]
			if not is_instance_valid(pc):
				continue
			for k in pc.plant_in_cell:
				var pl = pc.plant_in_cell[k]
				if is_instance_valid(pl):
					planted.append("数组[%d][%d]=row_col%s 类型%s" % [r, c, str(pc.row_col), str(pl.plant_type)])
	a.log("已种槽位=%d  %s" % [planted.size(), ", ".join(planted)])
	a.log("阳光最终=%d" % Global.main_game.card_manager.card_slot_battle.sun_value)
	a.log("[PLANT] result=%s" % ("PASS" if planted.size() > 0 else "FAIL"))
	await a.dump("种植之后")


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
	a.log("[操作] 点击 %s" % _v2(p))
