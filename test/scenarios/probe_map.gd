extends RefCounted
## 探针 PROBE2：为什么鼠标停在格子几何中心却进不了那个格子。
## PROBE1 只打印了节点名，行内重名导致结论不可判定（PlantCell8 每行都有）。
## 这次一律打印【完整路径】，并用扫描线找出真实的映射关系。

const ROWS := "/root/MainGame/PlantCellsRoot"


func _v2(v) -> String:
	return "(%.1f,%.1f)" % [v.x, v.y]


func run(a) -> void:
	a.log("PROBE2 启动")
	if not await _goto_level(a):
		a.log("PROBE2 失败: 进不了关卡")
		a.quit_game()
		return
	await a.wait(6.0)
	_dump_transform(a)
	_dump_overlaps(a, Vector2(404, 130))
	await _spot_checks(a)
	await _scan(a, true)
	await _scan(a, false)
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


func _hovered() -> String:
	var h: Control = Global.main_game.get_viewport().gui_get_hovered_control()
	if h == null:
		return "无"
	return str(h.get_path())


func _curr() -> String:
	var hm = Global.main_game.hand_manager
	if hm == null or hm.curr_plant_cell == null:
		return "-"
	return "%s row_col=%s" % [str(hm.curr_plant_cell.get_path()), str(hm.curr_plant_cell.row_col)]


func _move(a, p: Vector2) -> void:
	Input.warp_mouse(p)
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await a.frames(3)


func _dump_transform(a) -> void:
	a.log("")
	a.log("--- 变换链 ---")
	var root: Node = a.get_node_or_null(ROWS)
	if root == null:
		a.log("!! 没有 PlantCellsRoot")
		return
	var chain: Node = root
	while chain != null:
		if chain is CanvasItem:
			var ci := chain as CanvasItem
			var t := ci.get_global_transform()
			a.log("  %s [%s] origin=%s scale=%s rot=%.4f" % [
				str(ci.get_path()), ci.get_class(), _v2(t.origin), str(t.get_scale()), t.get_rotation()])
		chain = chain.get_parent()
	var cell: Control = root.get_node_or_null("PlantCellsRow1/PlantCell1")
	if cell != null:
		a.log("  样本 Cell: local=%s global=%s" % [
			str(cell.get_transform()), str(cell.get_global_transform())])
		var b: Control = cell.get_node_or_null("Button")
		if b != null:
			a.log("  样本 Button: global_rect=%s global_xform=%s" % [
				str(b.get_global_rect()), str(b.get_global_transform())])


func _dump_overlaps(a, p: Vector2) -> void:
	a.log("")
	a.log("--- 点 %s 上覆盖的所有可见 Control（树序，后面的在上面）---" % _v2(p))
	var hits: Array[Node] = []
	_collect_controls(a.get_tree().root, p, hits)
	a.log("  共 %d 个" % hits.size())
	var i := 0
	for h in hits:
		var c := h as Control
		a.log("  [%d] %s [%s] mouse_filter=%d rect=%s" % [
			i, str(c.get_path()), c.get_class(), int(c.mouse_filter), str(c.get_global_rect())])
		i += 1
		if i >= 30:
			break


func _collect_controls(n: Node, p: Vector2, out: Array[Node]) -> void:
	for c in n.get_children():
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(p):
			out.append(c)
		_collect_controls(c, p, out)


func _spot_checks(a) -> void:
	a.log("")
	a.log("--- 选点核查 ---")
	for p in [Vector2(20, 230), Vector2(84, 130), Vector2(163, 230), Vector2(404, 130), Vector2(404, 330)]:
		await _move(a, p)
		var vp: Viewport = Global.main_game.get_viewport()
		a.log("  发到%s -> viewport鼠标=%s hovered=%s curr=%s" % [
			_v2(p), _v2(vp.get_mouse_position()), _hovered(), _curr()])


func _scan(a, horizontal: bool) -> void:
	a.log("")
	var hi: int = 1064 if horizontal else 596
	if horizontal:
		a.log("--- 扫描线：y=130，x 0->1064 步长 4（只打印变化点）---")
	else:
		a.log("--- 扫描线：x=404，y 0->596 步长 4（只打印变化点）---")
	var last := "@开始"
	for v in range(0, hi + 1, 4):
		var p: Vector2 = Vector2(v, 130) if horizontal else Vector2(404, v)
		await _move(a, p)
		var key := _hovered() + " || curr=" + _curr()
		if key != last:
			a.log("  v=%d %s" % [v, key])
			last = key
