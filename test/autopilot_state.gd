extends RefCounted
class_name AutopilotState
## 状态采集：把「游戏此刻到底在干什么」变成一组可打印的文本行。
##
## autopilot 与 DebugChannel 共用 —— 以前两边各写一份格子 / 僵尸统计，
## 改一处必然漏另一处。本文件只负责「看」，不写报告也不点鼠标：
## 落盘交给 AutopilotReport，操作交给 AutopilotInput。

var _tree: SceneTree = null


func setup(scene_tree: SceneTree) -> void:
	_tree = scene_tree


#region 场景与引擎指标

## 当前场景路径
func scene_path() -> String:
	return AutopilotState.scene_path_of(_tree)


## 静态版：给没持有本对象的地方用（如 AutopilotClock.wait_scene）
static func scene_path_of(tree: SceneTree) -> String:
	var cs := tree.current_scene
	if cs == null:
		return "(未设置)"
	return cs.scene_file_path if cs.scene_file_path != "" else str(cs.name)


## 引擎侧指标：节点数 / 孤儿节点 / 静态内存 / fps
func perf_lines() -> Array[String]:
	return ["节点总数: %d  孤儿节点: %d  静态内存: %.1fMB  fps: %d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		Engine.get_frames_per_second(),
	]]


## 一行采样，供周期性打点（DebugChannel 每 120 帧打一次）
func sample_line(frame: int) -> String:
	return "采样 frame=%d fps=%d 节点=%d 孤儿节点=%d 静态内存=%.1fMB 场景=%s 场上僵尸=%d" % [
		frame,
		Engine.get_frames_per_second(),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		scene_path().get_file(),
		zombie_count(),
	]

#endregion


#region 运行期快照

## 完整快照：场景 + 引擎指标 + 关卡内状态（阶段 / 格子 / 僵尸 / UI）
func runtime_lines() -> Array[String]:
	var out: Array[String] = ["当前场景: " + scene_path()]
	out.append_array(perf_lines())
	if Global == null:
		out.append("Global 不存在")
		return out
	var mg = Global.main_game
	if mg == null:
		out.append("Global.main_game = null（不在关卡内）")
		return out
	out.append("主游戏阶段 main_game_progress = " + str(mg.main_game_progress))
	out.append_array(plant_cell_lines())
	out.append_array(zombie_lines())
	out.append_array(ui_lines())
	return out


## 草坪格子摘要（含每个已种格子的 row_col 与屏幕中心）。
## 单独对外：场景脚本用 a.describe_plant_cells() 拿它做断言。
func plant_cells_summary() -> String:
	return "\n".join(plant_cell_lines())


func plant_cell_lines() -> Array[String]:
	if Global == null or Global.main_game == null:
		return ["植物格子: 不在关卡内"]
	var pcm = Global.main_game.plant_cell_manager
	if pcm == null:
		return ["!! plant_cell_manager 为空"]
	var cells = pcm.all_plant_cells
	if cells == null or cells.is_empty():
		return ["!! all_plant_cells 为空"]
	var rows: int = cells.size()
	var cols: int = cells[0].size()
	var occupied := 0
	var invalid := 0
	var detail: Array[String] = []
	for r in range(rows):
		for c in range(cols):
			var pc = cells[r][c]
			if not is_instance_valid(pc):
				invalid += 1
				continue
			var here: Array[String] = []
			if pc.plant_in_cell != null:
				## 键来自字典自身，必然存在（规范 S-06 允许这种遍历）
				for k in pc.plant_in_cell:
					var p = pc.plant_in_cell[k]
					if is_instance_valid(p):
						occupied += 1
						here.append(str(p.plant_type))
			if not here.is_empty():
				## 打印「屏幕上真正可点」的中心并标注 row_col。
				## ⚠️ 不要拿 global_position 当屏幕位置：它不含关卡相机变换（规范 S-03）。
				var sc: Vector2 = pc.global_position
				var btn: Control = pc.get_node_or_null("Button")
				if btn != null:
					sc = AutopilotProbe.screen_center_of(btn)
				detail.append("数组[%d][%d] row_col=%s 植物%s 屏幕中心(%d,%d)" % [
					r, c, str(pc.row_col), ",".join(here), int(sc.x), int(sc.y)])
	var out: Array[String] = ["植物格子: %d行x%d列 已种槽位=%d 失效格子=%d" % [rows, cols, occupied, invalid]]
	if not detail.is_empty():
		out.append("  已种位置: " + ", ".join(detail))
	return out


func zombie_lines() -> Array[String]:
	if Global == null or Global.main_game == null:
		return ["僵尸管理器: 不在关卡内"]
	var zm = Global.main_game.zombie_manager
	if zm == null:
		return ["!! zombie_manager 为空"]
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
				detail.append("行%d:%s(x=%.0f hp=%s)" % [r, str(z.get("zombie_type")), z.global_position.x, _hp_of(z)])
	var out: Array[String] = ["场上僵尸: %d 失效引用=%d" % [total, invalid]]
	if not detail.is_empty():
		out.append("  明细: " + " | ".join(detail))
	return out


## 场上僵尸数（不在关卡内返回 -1）
func zombie_count() -> int:
	if Global == null or Global.main_game == null:
		return -1
	var zm = Global.main_game.zombie_manager
	if zm == null:
		return -1
	var n := 0
	for row in zm.all_zombies_2d:
		n += row.size()
	return n


func ui_lines() -> Array[String]:
	if Global == null or Global.main_game == null:
		return []
	var cm = Global.main_game.card_manager
	if cm == null:
		return []
	var sun := -1
	var cards := 0
	var slot = cm.get("card_slot_battle")
	if slot != null:
		sun = int(slot.get("sun_value"))
		if slot.get("curr_cards") != null:
			cards = slot.curr_cards.size()
	return ["阳光=%d 战斗卡槽卡片数=%d" % [sun, cards]]

#endregion


#region 观测

## 一行紧凑观测：僵尸（带行号 / x / 血量）+ 目标格植物 + 节点数。
## 用来盯「某个事件什么时候发生、发生时周围是什么状态」。
func observe_line(label: String, elapsed: float, cell_path: String = "") -> String:
	var parts: Array[String] = ["t=%.1fs" % elapsed]
	if Global == null or Global.main_game == null:
		return "[观察] " + label + "  不在关卡内  " + " ".join(parts)
	var zm = Global.main_game.zombie_manager
	var zs: Array[String] = []
	if zm != null:
		for lane in range(zm.all_zombies_2d.size()):
			for z in zm.all_zombies_2d[lane]:
				if not is_instance_valid(z):
					continue
				## 带行号：不带行号时「僵尸 x=73」到底在哪一行完全看不出来
				zs.append("行%d x%d/hp%s" % [lane, int(z.global_position.x), _hp_of(z)])
	parts.append("僵尸%d[%s]" % [zs.size(), ",".join(zs)])
	if cell_path != "":
		var cell := _tree.root.get_node_or_null(cell_path)
		if cell != null:
			var names: Array[String] = []
			for k in cell.plant_in_cell:
				var p = cell.plant_in_cell[k]
				if is_instance_valid(p):
					names.append(str(p.plant_type))
			parts.append("目标格植物=[" + ",".join(names) + "]")
	parts.append("节点=%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	return "[观察] " + label + "  " + "  ".join(parts)

#endregion


## 僵尸当前血量；取不到给 "?"
func _hp_of(z: Node) -> String:
	var hpc = z.get("hp_component")
	if hpc != null and hpc.get("curr_hp") != null:
		return str(hpc.curr_hp)
	return "?"
