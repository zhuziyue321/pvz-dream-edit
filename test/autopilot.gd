extends Node
## Autopilot —— 给 AI/CI 用的「静默驾驶舱」（门面）
##
## 它自己不实现任何能力，只做三件事：
##   1. 装载并驱动场景脚本（含看门狗，绝不留下野进程）
##   2. 持有五个协作对象并注入它们的依赖
##   3. 把 a.xxx() 转发给对应协作对象 —— **场景脚本的调用签名与拆分前完全一致**
##
## 协作对象（同目录，各管一件事）：
##   autopilot_report.gd  报告落盘 + 原样打屏（res:// / user:// 两种策略）
##   autopilot_clock.gd   游戏时间计时与所有等待
##   autopilot_probe.gd   节点查询、屏幕坐标、悬停探测
##   autopilot_input.gd   合成鼠标 / 键盘事件、直接触发 pressed
##   autopilot_state.gd   状态采集（快照 / 观测 / 草坪 / 僵尸 / UI），DebugChannel 也用
##
## 拆分的理由：原来这 600 多行同时管报告落盘、输入合成、坐标推算、状态采集、
## 看门狗和场景脚本生命周期，改一处要在整份文件里找上下文；拆开后每个文件只回答一个问题。
##
## 用法:
##   godot --headless --path <项目> -- --scenario=res://test/scenarios/probe_plant.gd
##   可选: --autopilot-max-seconds=60   看门狗（默认 300 秒）
##
## ⚠️ 不要把 res://test/autopilot.tscn 当启动场景传进去：那样启动的是 autopilot 场景本身，
## 主菜单 / 选关根本不存在，所有走菜单的场景脚本第一步就超时。正确做法是启动真实主场景，
## 由 DebugChannel 注入本节点。
##
## 场景脚本是一个 GDScript（RefCounted），实现:
##     func run(a) -> void:
##         await a.wait(2.0)
##         await a.dump("关卡就绪")

const REPORT_DIR := "user://autopilot_reports"
## 注入模式下场景脚本与报告的固定位置（编辑器里运行时 res:// 可写，我能直接读到）
const INJECT_SCENARIO := "res://test/inject/scenario.gd"
const INJECT_REPORT := "res://test/inject/report.txt"
const DEFAULT_SCENARIO := INJECT_SCENARIO
## 无头模式下根视口尺寸是 (0,0)，Control 命中测试会彻底失效、模拟点击点不到任何东西。
## 这里显式给一个跟项目一致的尺寸。
const HEADLESS_VIEWPORT := Vector2i(800, 600)
## 看门狗默认上限：到点强制结束，保证自动运行绝不留下野进程
const DEFAULT_MAX_SECONDS := 300.0

var _report: AutopilotReport = null
var _clock: AutopilotClock = null
var _state: AutopilotState = null
var _probe: AutopilotProbe = null
var _input: AutopilotInput = null

var _scenario_path := ""
var _scenario_name := "?"
var _max_seconds := DEFAULT_MAX_SECONDS
var _finished := false
## 必须用成员变量持有场景脚本：
## 场景脚本是 RefCounted，若只存在局部变量里，第一次 await 挂起后就会被回收，
## 协程再也无法恢复（表现为游戏空转、永不结束 —— 曾空转 9 分钟）。
var _scenario: Object = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = HEADLESS_VIEWPORT
		await get_tree().process_frame
	_wire()
	_open_report()
	_write_header()
	_run_scenario()


func _process(delta: float) -> void:
	if _finished:
		return
	_clock.tick(delta)
	if _clock.elapsed > _max_seconds:
		_report.line("")
		_report.line("!! 超过最大运行时长 " + str(int(_max_seconds)) + " 秒，强制结束（看门狗）")
		_finish("看门狗超时", not _keep_window())


#region 装载与生命周期

## 建好协作对象并注入依赖。依赖是单向的，不存在环：
##   report ← clock ← probe ← input，state 独立
func _wire() -> void:
	var tree := get_tree()
	_report = AutopilotReport.new()
	_clock = AutopilotClock.new()
	_state = AutopilotState.new()
	_probe = AutopilotProbe.new()
	_input = AutopilotInput.new()
	_clock.setup(tree, _report)
	_state.setup(tree)
	_probe.setup(tree, _clock)
	_input.setup(tree, _clock, _report, _probe)


func _parse_args() -> void:
	var all := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	_scenario_path = DEFAULT_SCENARIO
	for a in all:
		if a.begins_with("--scenario="):
			_scenario_path = a.split("=", true, 1)[1]
		if a.begins_with("--autopilot-max-seconds="):
			_max_seconds = maxf(5.0, a.split("=", true, 1)[1].to_float())
	_scenario_name = _scenario_path.get_file().get_basename()


func _open_report() -> void:
	## 注入模式写进项目目录（我能直接读），命令行模式写 user://
	if _scenario_path == INJECT_SCENARIO:
		_report.setup_inject(INJECT_REPORT, REPORT_DIR)
		return
	_report.setup_user(REPORT_DIR, "run_%s_%s.txt" % [
		_scenario_name,
		Time.get_datetime_string_from_system().replace(":", "-"),
	])


func _write_header() -> void:
	_report.line("================ PVZ AUTOPILOT ================")
	_report.line("时间: " + Time.get_datetime_string_from_system())
	_report.line("场景脚本: " + _scenario_path)
	_report.line("引擎: " + str(Engine.get_version_info().get("string", "?")))
	_report.line("无头模式: " + str(DisplayServer.get_name() == "headless"))
	_report.line("")
	_flush()


func _run_scenario() -> void:
	var script: GDScript = load(_scenario_path)
	if script == null:
		_report.line("!! 场景脚本加载失败: " + _scenario_path)
		_finish("场景脚本加载失败", not _keep_window())
		return
	_scenario = script.new()
	if not _scenario.has_method("run"):
		_report.line("!! 场景脚本没有实现 run(a)")
		_finish("接口不符", not _keep_window())
		return
	## 关掉每 60 秒一次的自动存档，避免污染日志
	if Global != null:
		var ss = Global.get("save_service")
		if ss != null and ss.has_method("stop_autosave"):
			ss.stop_autosave()
			_report.line("已关闭自动存档（避免日志噪声）")
	_report.line("看门狗: " + str(int(_max_seconds)) + " 秒")
	_flush()
	_report.line("[autopilot] 开始执行 " + _scenario_path)
	_flush()
	## 不 await：run() 内部自己 await，主循环继续跑
	_scenario.call("run", self)


## 是否处于「注入」模式（由 DebugChannel 在游戏启动时挂载）
func _is_injected() -> bool:
	return _scenario_path == INJECT_SCENARIO


## 跑完之后要不要留着窗口把控制权交还玩家。
## 只有「编辑器里按 F5 且真的有窗口」时才留；命令行 / 无头 CI 一律退出，绝不留野进程。
func _keep_window() -> bool:
	return _is_injected() and DisplayServer.get_name() != "headless"


## [do_quit] 参数名不能叫 quit_game：本类有个同名方法 quit_game()，会被判定为遮蔽（SHADOWED_VARIABLE）
func _finish(reason: String, do_quit: bool = true) -> void:
	if _finished:
		return
	_finished = true
	_clock.finished = true
	_report.line("")
	_report.line("================ 结束: " + reason + " ================")
	_report.line("总帧数=%d 总时长=%.1fs" % [_clock.frame_count, _clock.elapsed])
	_report.write_lines(_state.runtime_lines())
	_flush()
	Log.info("[autopilot] 报告: " + _report.abs_path())
	if do_quit:
		get_tree().quit()
		return
	_report.line("!! 已停止驾驶，游戏保持运行，控制权交还给你")
	_flush()
	Log.info("[autopilot] 已停止驾驶，游戏继续运行")


func _flush() -> void:
	_report.flush()

#endregion


#region ===== 给场景脚本用的 API =====
#
# 签名与拆分前完全一致，test/scenarios/*.gd 与 test/inject/scenario.gd 无需改动。
# 每个 API 结束都会 flush 一次 —— 报告文件在任何时刻都是一份完整快照，
# 看门狗 / 崩溃截断时不会丢内容。

func wait(seconds: float) -> void:
	await _clock.wait(seconds)


func frames(n: int) -> float:
	return await _clock.frames(n)


func log(msg: String) -> void:
	_report.line(msg)
	_flush()


func dump(label: String) -> void:
	_report.line("")
	_report.line("------ 状态快照: %s (frame=%d, t=%.1fs) ------" % [label, _clock.frame_count, _clock.elapsed])
	_report.write_lines(_state.runtime_lines())
	_flush()


func nodes(pattern: String, only_visible: bool = false) -> void:
	_report.line("")
	_report.line("------ 节点查找: " + pattern + (" (仅可见)" if only_visible else "") + " ------")
	_report.write_lines(_probe.node_lines(pattern, only_visible))
	_flush()


## 一行紧凑观测：僵尸行号 / x / 血量、目标格植物、节点数
func observe(label: String, cell_path: String = "") -> void:
	_report.line(_state.observe_line(label, _clock.elapsed, cell_path))
	_flush()


func wait_scene(substr: String, timeout: float = 12.0) -> bool:
	var ok := await _clock.wait_scene(substr, timeout)
	_flush()
	return ok


func wait_stable(path: String, timeout: float = 8.0) -> bool:
	var ok := await _clock.wait_stable(path, timeout)
	_flush()
	return ok


## 控件在「屏幕上真正能点到」的中心 —— 所有点击都必须用它
func screen_center(c: Control) -> Vector2:
	return AutopilotProbe.screen_center_of(c)


## 当前画布变换原点；非 (0,0) 就说明有相机在动，rect 坐标靠不住
func canvas_origin() -> Vector2:
	return _probe.canvas_origin()


func probe_hover(x: float, y: float) -> void:
	_report.line(await _probe.probe_hover_line(x, y))
	_flush()


## 草坪格子的权威摘要（已种槽位 + 每个已种格子的 row_col 与屏幕中心）
func describe_plant_cells() -> String:
	return _state.plant_cells_summary()


func click(x: float, y: float) -> void:
	await _input.click(x, y)
	_flush()


func click_node(path: String) -> void:
	await _input.click_node(path)
	_flush()


func click_first(pattern: String, index: int = 0) -> bool:
	var ok := await _input.click_first(pattern, index)
	_flush()
	return ok


func press_first(pattern: String, index: int = 0) -> bool:
	var ok := await _input.press_first(pattern, index)
	_flush()
	return ok


func click_plant_cell(row: int, col: int) -> bool:
	var ok := await _input.click_plant_cell(row, col)
	_flush()
	return ok


## 按住 (x1,y1) 拖到 (x2,y2) 再松手（合成真实事件，见 AutopilotInput.drag）
func drag(x1: float, y1: float, x2: float, y2: float) -> void:
	await _input.drag(x1, y1, x2, y2)
	_flush()


## 从草坪格子 (row1,col1) 拖到 (row2,col2)：拖动类玩法（僵尸迷阵交换相邻两株）用这个
func drag_plant_cell(row1: int, col1: int, row2: int, col2: int) -> bool:
	var ok := await _input.drag_plant_cell(row1, col1, row2, col2)
	_flush()
	return ok


func key(action: String) -> void:
	await _input.key(action)
	_flush()


func keycode(code: Key) -> void:
	await _input.keycode(code)
	_flush()


func call_on(path: String, method: String, args: Array = []) -> void:
	await _input.call_on(path, method, args)
	_flush()


## 结束驾驶。
## 注入模式 + 有窗口（编辑器 F5）-> 只停止驾驶，控制权交还玩家；
## 命令行 / 无头（CI）           -> 直接退出（否则进程会一直挂着）。
## [do_quit] = true 可强制退出。
func finish(do_quit: bool = false) -> void:
	_finish("场景脚本主动结束", do_quit or not _keep_window())


## 明确要求退出游戏
func quit_game() -> void:
	_finish("场景脚本要求退出", true)

#endregion
