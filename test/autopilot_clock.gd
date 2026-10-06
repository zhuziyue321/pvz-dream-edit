extends RefCounted
class_name AutopilotClock
## 计时与等待。
##
## 时间基准是「游戏时间」：elapsed / frame_count 由宿主每帧 tick() 推进
## （宿主 process_mode = ALWAYS，游戏暂停时驾驶照样走），不用墙钟。
## finished 置位后所有等待立即返回 —— 不会把协程挂在已经结束的驾驶上。

## 已过的游戏秒
var elapsed := 0.0
## 已过的帧数（字段名避开与 frames() 撞名）
var frame_count := 0
## 驾驶是否已结束
var finished := false

var _tree: SceneTree = null
var _report: AutopilotReport = null


func setup(scene_tree: SceneTree, report: AutopilotReport) -> void:
	_tree = scene_tree
	_report = report


## 每帧由宿主调用一次
func tick(delta: float) -> void:
	frame_count += 1
	elapsed += delta


## 等 N 游戏秒
func wait(seconds: float) -> void:
	var t0 := elapsed
	while elapsed - t0 < seconds and not finished:
		await _tree.process_frame


## 等 N 帧，返回实际耗时（游戏秒）
func frames(n: int) -> float:
	var f0 := frame_count
	var t0 := elapsed
	while frame_count - f0 < n and not finished:
		await _tree.process_frame
	return elapsed - t0


## 等当前场景路径包含 substr
func wait_scene(substr: String, timeout: float) -> bool:
	var t0 := elapsed
	while elapsed - t0 < timeout and not finished:
		if substr in AutopilotState.scene_path_of(_tree):
			return true
		await _tree.process_frame
	_report.line("!! 等待场景超时: " + substr + "  当前=" + AutopilotState.scene_path_of(_tree))
	return false


## 等某个控件停止移动（动画播完）再返回。
## 开场菜单的按钮是从右侧滑入的，动画未结束时点击会落空或点错位置。
func wait_stable(path: String, timeout: float) -> bool:
	var n := _tree.root.get_node_or_null(path)
	if n == null or not (n is Control):
		_report.line("!! wait_stable 找不到控件: " + path)
		return false
	var c := n as Control
	var last := Vector2(1e9, 1e9)
	var stable := 0
	var t0 := elapsed
	while elapsed - t0 < timeout and not finished:
		var now := c.global_position
		if now.distance_to(last) < 0.5:
			stable += 1
			if stable >= 3:
				_report.line("[等待] 控件已静止: " + path)
				return true
		else:
			stable = 0
		last = now
		await _tree.process_frame
	_report.line("!! wait_stable 超时: " + path)
	return false
