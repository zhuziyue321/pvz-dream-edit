extends Node
## Autopilot —— 给 AI/CI 用的「静默驾驶舱」
##
## 它自己就是入口场景：autoload 照常加载，然后按「场景脚本」模拟玩家操作，
## 全程无需人工、无需联网、结束后自动退出并产出报告。
##
## 用法:
##   godot --headless --path <项目> res://test/autopilot.tscn -- --scenario=res://test/scenarios/boot_level.gd
##   可选: --scenario-seconds=60   报告里同时保留的采样窗口
##         --windowed              不用无头模式（某些布局/输入行为更接近真实）
##
## 场景脚本是一个 GDScript，实现:
##     func run(a) -> void:        # a 就是本文件的 API 对象
##         await a.wait(2.0)
##         await a.dump("关卡就绪")
##
## 可用 API（全部是 await 友好的）:
##   a.wait(sec)                 等待 N 游戏秒
##   a.frames(n)                 等待 N 帧
##   a.log(msg)                  写一行日志
##   a.dump(label)               写一份完整状态快照
##   a.nodes(pattern)            列出名字含 pattern 的节点（类/位置/尺寸/可见）
##   a.key(action)               按一下输入动作（如 "ShortcutKeys_Card1"）
##   a.keycode(KEY_F10)          按一下物理键
##   a.click(x, y)               在屏幕坐标点击一次
##   a.click_node(node_path)     点击某个 Control 的中心
##   a.call_on(node_path, m, args)  对节点调用方法
##   a.finish()                  结束本次自动驾驶并退出
##
## ⚠️ 坐标纪律（2026-09-30 踩坑，见 docs/AI调试通道.md 第五节）：
##   Control.get_global_rect()/global_position **不含画布变换**，而鼠标命中测试走的是
##   get_global_transform_with_canvas()。本项目的关卡有 Camera2D(120,0)，两者差 150 像素，
##   直接拿 rect 中心去点会稳定点错格子。所有点击一律走 screen_center()。

const REPORT_DIR := "user://autopilot_reports"
## 注入模式下场景脚本与报告的固定位置（编辑器里运行时 res:// 可写，我能直接读到）
const INJECT_SCENARIO := "res://test/inject/scenario.gd"
const INJECT_REPORT := "res://test/inject/report.txt"
const DEFAULT_SCENARIO := INJECT_SCENARIO

var _lines: Array[String] = []
var _report_path := ""
var _scenario_path := ""
var _frames := 0
var _elapsed := 0.0
var _finished := false
var _scenario_name := "?"
## 必须用成员变量持有场景脚本：
## 场景脚本是 RefCounted，若只存在局部变量里，第一次 await 挂起后就会被回收，
## 协程再也无法恢复（表现为游戏空转、永不结束）。
var _scenario: Object = null
## 看门狗：超过这个秒数强制结束，保证自动运行绝不留下野进程
var _max_seconds := 300.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	## 无头模式下根视口尺寸是 (0,0)，Control 的命中测试会彻底失效，
	## 模拟点击就点不到任何东西。这里显式给一个跟项目一致的尺寸。
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1066, 600)
		await get_tree().process_frame
	_open_report()
	_line("================ PVZ AUTOPILOT ================")
	_line("时间: " + Time.get_datetime_string_from_system())
	_line("场景脚本: " + _scenario_path)
	_line("引擎: " + str(Engine.get_version_info().get("string", "?")))
	_line("无头模式: " + str(DisplayServer.get_name() == "headless"))
	_line("")
	_flush()
	var script: GDScript = load(_scenario_path)
	if script == null:
		_line("!! 场景脚本加载失败: " + _scenario_path)
		_finish("场景脚本加载失败", not _keep_window())
		return
	_scenario = script.new()
	if not _scenario.has_method("run"):
		_line("!! 场景脚本没有实现 run(a)")
		_finish("接口不符", not _keep_window())
		return
	## 关掉每 60 秒一次的自动存档，避免污染日志
	if Global != null:
		var ss = Global.get("save_service")
		if ss != null and ss.has_method("stop_autosave"):
			ss.stop_autosave()
			_line("已关闭自动存档（避免日志噪声）")
	_line("看门狗: " + str(int(_max_seconds)) + " 秒")
	_flush()
	print("[autopilot] 开始执行 " + _scenario_path)
	## 不 await：run() 内部自己 await，主循环继续跑
	_scenario.call("run", self)


func _process(delta: float) -> void:
	_frames += 1
	_elapsed += delta
	if not _finished and _elapsed > _max_seconds:
		_line("")
		_line("!! 超过最大运行时长 " + str(int(_max_seconds)) + " 秒，强制结束（看门狗）")
		_finish("看门狗超时", not _keep_window())


## 是否处于「注入」模式（由 DebugChannel 在游戏启动时挂载）
func _is_injected() -> bool:
	return _scenario_path == INJECT_SCENARIO


## 跑完之后要不要留着窗口把控制权交还玩家。
## 只有「编辑器里按 F5 且真的有窗口」时才留；命令行/无头 CI 一律退出，绝不留野进程。
func _keep_window() -> bool:
	return _is_injected() and DisplayServer.get_name() != "headless"


func _parse_args() -> void:
	var all := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	_scenario_path = DEFAULT_SCENARIO
	for a in all:
		if a.begins_with("--scenario="):
			_scenario_path = a.split("=", true, 1)[1]
		if a.begins_with("--autopilot-max-seconds="):
			_max_seconds = maxf(5.0, a.split("=", true, 1)[1].to_float())
	_scenario_name = _scenario_path.get_file().get_basename()


#region ===== 给场景脚本用的 API =====

func wait(seconds: float) -> void:
	var t0 := _elapsed
	while _elapsed - t0 < seconds and not _finished:
		await get_tree().process_frame


func frames(n: int) -> float:
	var f0 := _frames
	var t0 := _elapsed
	while _frames - f0 < n and not _finished:
		await get_tree().process_frame
	return _elapsed - t0


func log(msg: String) -> void:
	_line(msg)
	_flush()


func dump(label: String) -> void:
	_line("")
	_line("------ 状态快照: " + label + " (frame=" + str(_frames) + ", t=%.1fs)" % _elapsed + " ------")
	_collect_state()
	_flush()


## 列出名字包含 pattern 的节点，便于发现可点击目标
func nodes(pattern: String, only_visible: bool = false) -> void:
	_line("")
	_line("------ 节点查找: " + pattern + (" (仅可见)" if only_visible else "") + " ------")
	var root := get_tree().root
	var found := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		## 按「节点名」匹配（不是完整路径）：按路径匹配会把深层子节点
		## （Sprite2D / AnimationPlayer 之类）全部卷进来，把结果淹掉。
		if pattern != "" and pattern.to_lower() in n.name.to_lower():
			if only_visible and n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
				continue
			found += 1
			if found <= 150:
				var extra := ""
				if n is Control:
					var c2 := n as Control
					## 同时给「屏幕上真正可点的中心」和「rect 中心」：两者在有关卡相机时不一样
					extra = " screen_center=" + str(screen_center(c2)) + " rect_center=" + str(c2.get_global_rect().get_center())
					extra += " size=" + str(c2.size) + " visible=" + str(c2.is_visible_in_tree()) + " disabled=" + str(c2 is BaseButton and (c2 as BaseButton).disabled)
				elif n is CanvasItem:
					extra = " global_pos=" + str((n as CanvasItem).global_position)
				_line("  " + str(n.get_path()) + "  [" + n.get_class() + "]" + extra)
	_line("  共 " + str(found) + " 个")
	_flush()


## 收集「可见且可点」的 Control，路径含 pattern
func _find_clickable(pattern: String, only_visible: bool = true) -> Array:
	var out: Array = []
	var stack: Array[Node] = [get_tree().root]
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


## 点击第一个路径含 pattern 的可见控件。返回是否点到了。
func click_first(pattern: String, index: int = 0) -> bool:
	var found := _find_clickable(pattern, true)
	_line("[查找] " + pattern + " 命中 " + str(found.size()) + " 个可点控件")
	for i in range(mini(found.size(), 6)):
		_line("    [" + str(i) + "] " + str(found[i].get_path()) + " screen=" + str(screen_center(found[i])))
	if found.size() <= index:
		_line("!! 没有可点的目标: " + pattern)
		_flush()
		return false
	var c := found[index] as Control
	var center := screen_center(c)
	_line("[操作] 点击 " + str(c.get_path()))
	await click(center.x, center.y)
	return true


## 直接触发第一个匹配控件的 pressed 信号。
## 比模拟点击可靠：不依赖命中测试，无头环境下也能用。
func press_first(pattern: String, index: int = 0) -> bool:
	var found := _find_clickable(pattern, true)
	_line("[查找] " + pattern + " 命中 " + str(found.size()) + " 个可点控件")
	for i in range(mini(found.size(), 6)):
		_line("    [" + str(i) + "] " + str(found[i].get_path()))
	if found.size() <= index:
		_line("!! 没有可触发目标: " + pattern)
		_flush()
		return false
	var b: Node = found[index]
	if not b.has_signal("pressed"):
		_line("!! 目标没有 pressed 信号: " + str(b.get_path()))
		_flush()
		return false
	_line("[操作] 触发 pressed: " + str(b.get_path()))
	b.emit_signal("pressed")
	await frames(3)
	return true


## 控件在「屏幕上真正能点到」的中心。
## Control.get_global_rect() / global_position 用不含画布变换的坐标，而鼠标命中测试走的是
## get_global_transform_with_canvas()。本关卡有 Camera2D，两者差 150 像素 —— 用错必然点偏。
func screen_center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


## 当前画布变换原点。非零就说明关卡相机在动 -> 任何"从 global_position 推断屏幕位置"的
## 做法都是错的，必须走 screen_center()。排查坐标问题的第一件事就是打这个值。
func canvas_origin() -> Vector2:
	return get_viewport().get_canvas_transform().origin


## 把鼠标挪到屏幕坐标，报告游戏认为鼠标压在哪个控件/哪个格子上。
## 比"点一下看有没有反应"快得多，也不依赖副作用。
func probe_hover(x: float, y: float) -> void:
	var pos := Vector2(x, y)
	Input.warp_mouse(pos)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)
	await frames(3)
	var vp := get_viewport()
	var h: Control = vp.gui_get_hovered_control()
	var hpath := "无"
	if h != null:
		hpath = str(h.get_path())
	var curr := "-"
	var mg = Global.main_game
	if Global != null and mg != null and mg.hand_manager != null and mg.hand_manager.curr_plant_cell != null:
		curr = str(mg.hand_manager.curr_plant_cell.get_path())
	_line("[悬停] %s -> viewport鼠标=%s hovered=%s 当前格=%s" % [
		str(pos), str(vp.get_mouse_position()), hpath, curr])
	_flush()


## 取草坪格子节点。[row] 0=最上面一行，[col] 0=最左一列，与 PlantCell.row_col 完全一致。
## 优先用 plant_cell_manager.all_plant_cells（权威），取不到再按节点名回退。
func _plant_cell_node(row: int, col: int) -> Control:
	if Global != null:
		var mg = Global.main_game
		if mg != null:
			var pcm = mg.plant_cell_manager
			if pcm != null and not pcm.all_plant_cells.is_empty():
				var cells = pcm.all_plant_cells
				if row >= 0 and row < cells.size() and col >= 0 and col < cells[row].size():
					var pc = cells[row][col]
					if is_instance_valid(pc):
						return pc
	var root := get_node_or_null("/root/MainGame/PlantCellsRoot")
	if root == null:
		return null
	var row_node := root.get_node_or_null("PlantCellsRow%d" % (row + 1))
	if row_node == null:
		return null
	## 行内子节点按从左到右命名：PlantCell1 = col 0（最左列）
	var idx: int = col + 1
	return row_node.get_node_or_null("PlantCell%d" % idx)


## 点击草坪格子。[row] 0=最上面一行，[col] 0=最左一列（= row_col.y）
func click_plant_cell(row: int, col: int) -> bool:
	var cell: Control = _plant_cell_node(row, col)
	if cell == null:
		_line("!! 没有格子 row=%d col=%d（不在关卡内？）" % [row, col])
		_flush()
		return false
	var btn: Control = cell.get_node_or_null("Button")
	if btn == null:
		_line("!! 格子没有 Button: " + str(cell.get_path()))
		_flush()
		return false
	var c := screen_center(btn)
	_line("[种植] 点击 row=%d col=%d -> %s 屏幕中心 %s (rect 中心 %s)" % [
		row, col, str(cell.get_path()), str(c), str(btn.get_global_rect().get_center())])
	await click(c.x, c.y)
	return true


## 一行紧凑观测：僵尸位置/血量、指定格子里的植物、节点数。
## 用来盯着"某个事件什么时候发生、发生时周围是什么状态"。
func observe(label: String, cell_path: String = "") -> void:
	var parts: Array[String] = ["t=%.1fs" % _elapsed]
	var mg = Global.main_game
	if mg == null:
		_line("[观察] " + label + "  不在关卡内  " + " ".join(parts))
		return
	var zs: Array[String] = []
	var zm = mg.zombie_manager
	if zm != null:
		for lane in range(zm.all_zombies_2d.size()):
			for z in zm.all_zombies_2d[lane]:
				if not is_instance_valid(z):
					continue
				var hp := "?"
				var hpc = z.get("hp_component")
				if hpc != null and hpc.get("curr_hp") != null:
					hp = str(hpc.curr_hp)
				## 带行号：不带行号时"僵尸 x=73"到底在哪一行完全看不出来
				zs.append("行%d x%d/hp%s" % [lane, int(z.global_position.x), hp])
	parts.append("僵尸%d[%s]" % [zs.size(), ",".join(zs)])
	if cell_path != "":
		var cell := get_node_or_null(cell_path)
		if cell != null:
			var names: Array[String] = []
			for k in cell.plant_in_cell:
				var p = cell.plant_in_cell[k]
				if is_instance_valid(p):
					names.append(str(p.plant_type))
			parts.append("目标格植物=[" + ",".join(names) + "]")
	parts.append("节点=%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_line("[观察] " + label + "  " + "  ".join(parts))
	_flush()


## 等当前场景路径包含 substr
func wait_scene(substr: String, timeout: float = 12.0) -> bool:
	var t0 := _elapsed
	while _elapsed - t0 < timeout and not _finished:
		if substr in _scene_path():
			return true
		await get_tree().process_frame
	_line("!! 等待场景超时: " + substr + "  当前=" + _scene_path())
	_flush()
	return false


func key(action: String) -> void:
	if not InputMap.has_action(action):
		_line("!! 输入动作不存在: " + action)
		_flush()
		return
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(2)
	_line("[操作] 按键动作 " + action)


func keycode(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await frames(2)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)
	_line("[操作] 按键 " + str(code))


func click(x: float, y: float) -> void:
	var pos := Vector2(x, y)
	## 种植走格子的 Button（GUI 命中测试），但手持物（虚影、能否种、点空白取消）
	## 读的是真实鼠标位置，所以合成事件之前必须真的把光标挪过去（warp + motion）。
	Input.warp_mouse(pos)
	await frames(1)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)
	await frames(2)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	await frames(2)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)
	await frames(2)
	_line("[操作] 点击 (%d, %d)" % [int(x), int(y)])


func click_node(path: String) -> void:
	var n := get_node_or_null(path)
	if n == null:
		_line("!! 找不到节点: " + path)
		_flush()
		return
	if not (n is Control):
		_line("!! 节点不是 Control，无法取中心点: " + path)
		_flush()
		return
	var c := n as Control
	var center := screen_center(c)
	_line("[操作] 点击节点 " + path + " 屏幕中心 " + str(center))
	await click(center.x, center.y)


func call_on(path: String, method: String, args: Array = []) -> void:
	var n := get_node_or_null(path)
	if n == null:
		_line("!! 找不到节点: " + path)
		_flush()
		return
	if not n.has_method(method):
		_line("!! 节点没有方法 " + method + ": " + path)
		_flush()
		return
	n.callv(method, args)
	_line("[操作] 调用 " + path + "." + method + str(args))
	await frames(2)


## 结束驾驶。
## 注入模式 + 有窗口（编辑器 F5）-> 只停止驾驶，控制权交还玩家；
## 命令行 / 无头（CI）           -> 直接退出（否则进程会一直挂着）。
## [quit_game] = true 可强制退出。
func finish(quit_game: bool = false) -> void:
	_finish("场景脚本主动结束", quit_game or not _keep_window())


## 明确要求退出游戏
func quit_game() -> void:
	_finish("场景脚本要求退出", true)

#endregion


#region ===== 状态采集与报告 =====

func _collect_state() -> void:
	_line("当前场景: " + _scene_path())
	_line("节点总数: %d  孤儿节点: %d  静态内存: %.1fMB  fps: %d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		Engine.get_frames_per_second(),
	])
	if Global == null:
		_line("Global 不存在")
		return
	var mg = Global.main_game
	if mg == null:
		_line("Global.main_game = null（不在关卡内）")
		return
	_line("主游戏阶段 main_game_progress = " + str(mg.main_game_progress))
	_collect_plant_cells(mg)
	_collect_zombies(mg)
	_collect_ui(mg)


func _collect_plant_cells(mg) -> void:
	for l in plant_cells_summary(mg).split("\n"):
		_line(l)


## 草坪格子摘要，单独抽出来给场景脚本断言用（a.describe_plant_cells()）
func describe_plant_cells() -> String:
	if Global == null:
		return "Global 不存在"
	var mg = Global.main_game
	if mg == null:
		return "不在关卡内（Global.main_game = null）"
	return plant_cells_summary(mg)


func plant_cells_summary(mg) -> String:
	var pcm = mg.plant_cell_manager
	if pcm == null or pcm.all_plant_cells == null or pcm.all_plant_cells.is_empty():
		return "植物格子: 取不到"
	var rows: int = pcm.all_plant_cells.size()
	var cols: int = pcm.all_plant_cells[0].size()
	var occupied := 0
	var invalid := 0
	var detail: Array[String] = []
	for r in range(rows):
		for c in range(cols):
			var pc = pcm.all_plant_cells[r][c]
			if not is_instance_valid(pc):
				invalid += 1
				continue
			var here: Array[String] = []
			if pc.plant_in_cell != null:
				for k in pc.plant_in_cell:
					var p = pc.plant_in_cell[k]
					if is_instance_valid(p):
						occupied += 1
						here.append(str(p.plant_type))
			if not here.is_empty():
				## 打印「屏幕上真正可点」的中心（screen_center），并标注 row_col。
				## 注意：不要用 global_position 当屏幕位置，它不含关卡相机变换。
				var btn: Control = pc.get_node_or_null("Button")
				var sc: Vector2 = pc.global_position
				if btn != null:
					sc = screen_center(btn)
				detail.append("数组[%d][%d] row_col=%s 植物%s 屏幕中心(%d,%d)" % [
					r, c, str(pc.row_col), ",".join(here), int(sc.x), int(sc.y),
				])
	var out := "植物格子: %d行x%d列 已种槽位=%d 失效格子=%d" % [rows, cols, occupied, invalid]
	if not detail.is_empty():
		out += "\n  已种位置: " + ", ".join(detail)
	return out


func _collect_zombies(mg) -> void:
	var zm = mg.zombie_manager
	if zm == null:
		_line("僵尸管理器: 取不到")
		return
	var total := 0
	var invalid := 0
	var detail: Array[String] = []
	for r in range(zm.all_zombies_2d.size()):
		for z in zm.all_zombies_2d[r]:
			if not is_instance_valid(z):
				invalid += 1
				continue
			total += 1
			if detail.size() < 12:
				var hp := "?"
				var hpc = z.get("hp_component")
				if hpc != null and hpc.get("curr_hp") != null:
					hp = str(hpc.curr_hp)
				detail.append("行%d:%s(x=%.0f hp=%s)" % [r, str(z.get("zombie_type")), z.global_position.x, hp])
	_line("场上僵尸: %d 失效引用=%d" % [total, invalid])
	if not detail.is_empty():
		_line("  明细: " + " | ".join(detail))


func _collect_ui(mg) -> void:
	var cm = mg.card_manager
	if cm == null:
		return
	var sun := -1
	var slot = cm.get("card_slot_battle")
	if slot != null:
		sun = int(slot.get("sun_value"))
	var cards := 0
	if slot != null and slot.get("curr_cards") != null:
		cards = slot.curr_cards.size()
	_line("阳光=%d 战斗卡槽卡片数=%d" % [sun, cards])


func _scene_path() -> String:
	var cs := get_tree().current_scene
	if cs == null:
		return "(未设置)"
	return cs.scene_file_path if cs.scene_file_path != "" else str(cs.name)


func _open_report() -> void:
	## 注入模式写进项目目录（我能直接读），命令行模式写 user://
	if _scenario_path == INJECT_SCENARIO:
		DirAccess.make_dir_recursive_absolute("res://test/inject")
		_report_path = INJECT_REPORT
		return
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("autopilot_reports"):
		dir.make_dir("autopilot_reports")
	_report_path = REPORT_DIR.path_join("run_%s_%s.txt" % [
		_scenario_name,
		Time.get_datetime_string_from_system().replace(":", "-"),
	])


func _line(text: String) -> void:
	_lines.append(text)
	print(text)


func _flush() -> void:
	if _report_path == "":
		return
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f == null and _report_path.begins_with("res://"):
		## 导出后的游戏 res:// 只读，退回 user://
		DirAccess.make_dir_recursive_absolute(REPORT_DIR)
		_report_path = REPORT_DIR.path_join("inject_report.txt")
		f = FileAccess.open(_report_path, FileAccess.WRITE)
	if f == null:
		return
	for l in _lines:
		f.store_line(l)
	f.close()


func _finish(reason: String, quit_game: bool = true) -> void:
	if _finished:
		return
	_finished = true
	_line("")
	_line("================ 结束: " + reason + " ================")
	_line("总帧数=%d 总时长=%.1fs" % [_frames, _elapsed])
	_collect_state()
	_flush()
	print("[autopilot] 报告: " + ProjectSettings.globalize_path(_report_path))
	if quit_game:
		get_tree().quit()
	else:
		_line("!! 已停止驾驶，游戏保持运行，控制权交还给你")
		_flush()
		print("[autopilot] 已停止驾驶，游戏继续运行")

#endregion


## 等某个控件停止移动（动画播完）再返回。
## 开场菜单的按钮是从右侧滑入的，动画未结束时点击会落空或点错位置。
func wait_stable(path: String, timeout: float = 8.0) -> bool:
	var n := get_node_or_null(path)
	if n == null or not (n is Control):
		_line("!! wait_stable 找不到控件: " + path)
		_flush()
		return false
	var c := n as Control
	var last := Vector2(1e9, 1e9)
	var stable := 0
	var t0 := _elapsed
	while _elapsed - t0 < timeout and not _finished:
		var now := c.global_position
		if now.distance_to(last) < 0.5:
			stable += 1
			if stable >= 3:
				_line("[等待] 控件已静止: " + path)
				_flush()
				return true
		else:
			stable = 0
		last = now
		await get_tree().process_frame
	_line("!! wait_stable 超时: " + path)
	_flush()
	return false
