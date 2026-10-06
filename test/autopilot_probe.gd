extends RefCounted
class_name AutopilotProbe
## 侦察：按名字 / 路径找节点、算屏幕坐标、问「游戏认为鼠标压在哪」。
##
## 只负责「看」，不写报告也不点鼠标：落盘交给 AutopilotReport，点击交给 AutopilotInput。
## 坐标纪律是这一块的核心，踩坑史见 docs/AI调试通道.md 第六节。

var _tree: SceneTree = null
var _clock: AutopilotClock = null


func setup(scene_tree: SceneTree, clock: AutopilotClock) -> void:
	_tree = scene_tree
	_clock = clock


#region 坐标

## 控件在「屏幕上真正能点到」的中心。所有点击都必须用它。
##
## 规范 S-03：Control.get_global_rect() / global_position 用**不含画布变换**的坐标，
## 而鼠标命中测试走 get_global_transform_with_canvas()。本关卡有 Camera2D
## （进关 -210 → 看僵尸 390 → 归位 10，见 src/world/camera/main_game_camera.gd）
## 且入场时还会移动，草坪实测两者差 150 像素 —— 用错必然稳定点偏。
static func screen_center_of(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


## 当前画布变换原点。
## 非 (0,0) 就说明相机在动，此时任何「从 rect / global_position 推断屏幕位置」
## 的做法都是错的。排查坐标问题的第一件事就是打这个值。
func canvas_origin() -> Vector2:
	return _tree.root.get_canvas_transform().origin

#endregion


#region 节点查询

## 列出名字包含 pattern 的节点。
## 按【节点名】匹配（不是完整路径）：按路径匹配会把深层 Sprite2D / AnimationPlayer
## 全部卷进来，把结果淹掉。
func node_lines(pattern: String, only_visible: bool = false) -> Array[String]:
	var out: Array[String] = []
	var found := 0
	var stack: Array[Node] = [_tree.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if pattern == "" or not pattern.to_lower() in n.name.to_lower():
			continue
		if only_visible and n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		found += 1
		if found > 150:
			continue
		var extra := ""
		if n is Control:
			var c2 := n as Control
			## 同时给「屏幕上真正可点的中心」和「rect 中心」：有关卡相机时两者不一样
			extra = " screen_center=" + str(screen_center_of(c2)) + " rect_center=" + str(c2.get_global_rect().get_center())
			extra += " size=" + str(c2.size) + " visible=" + str(c2.is_visible_in_tree())
			extra += " disabled=" + str(c2 is BaseButton and (c2 as BaseButton).disabled)
		elif n is CanvasItem:
			extra = " global_pos=" + str((n as CanvasItem).global_position)
		out.append("  " + str(n.get_path()) + "  [" + n.get_class() + "]" + extra)
	out.append("  共 " + str(found) + " 个")
	return out


## 收集「可见且可点」的 Control，【完整路径】含 pattern。
## 用完整路径而不是节点名：每行都有 PlantCell8 这种重名，按名字根本无法判定。
func find_clickable(pattern: String, only_visible: bool = true) -> Array:
	var out: Array = []
	var stack: Array[Node] = [_tree.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not pattern.to_lower() in str(n.get_path()).to_lower():
			continue
		if not (n is Control):
			continue
		var ctl := n as Control
		if ctl.size.x <= 1.0 or ctl.size.y <= 1.0:
			continue
		if only_visible and not ctl.is_visible_in_tree():
			continue
		if ctl is BaseButton and (ctl as BaseButton).disabled:
			continue
		out.append(ctl)
	return out


## 取草坪格子节点。[row] 0 = 最上面一行，[col] 0 = 最左一列，与 PlantCell.row_col 一致。
## 优先用 plant_cell_manager.all_plant_cells（权威），取不到再按节点名回退。
func plant_cell_node(row: int, col: int) -> Control:
	if Global != null and Global.main_game != null:
		var pcm = Global.main_game.plant_cell_manager
		if pcm != null and pcm.all_plant_cells != null and not pcm.all_plant_cells.is_empty():
			var cells = pcm.all_plant_cells
			if row >= 0 and row < cells.size() and col >= 0 and col < cells[row].size():
				var pc = cells[row][col]
				if is_instance_valid(pc):
					return pc
	var root := _tree.root.get_node_or_null("/root/MainGame/PlantCellsRoot")
	if root == null:
		return null
	var row_node := root.get_node_or_null("PlantCellsRow%d" % (row + 1))
	if row_node == null:
		return null
	## 行内子节点按从左到右命名：PlantCell1 = col 0（最左列）
	return row_node.get_node_or_null("PlantCell%d" % (col + 1))

#endregion


#region 悬停探测

## 把鼠标挪过去，返回「游戏认为鼠标压在哪个控件 / 哪个格子上」的一行事实。
## 比「点一下看有没有反应」快得多，也没有副作用。
func probe_hover_line(x: float, y: float) -> String:
	var pos := Vector2(x, y)
	Input.warp_mouse(pos)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)
	await _clock.frames(3)
	var hovered: Control = _tree.root.gui_get_hovered_control()
	var hpath := "无"
	if hovered != null:
		hpath = str(hovered.get_path())
	var curr := "-"
	if Global != null and Global.main_game != null:
		var mg = Global.main_game
		if mg.hand_manager != null and mg.hand_manager.curr_plant_cell != null:
			curr = str(mg.hand_manager.curr_plant_cell.get_path())
	return "[悬停] %s -> viewport鼠标=%s hovered=%s 当前格=%s" % [
		str(pos), str(_tree.root.get_mouse_position()), hpath, curr]

#endregion
