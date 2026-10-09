extends Node
class_name LevelTimelineManager
## 关卡流程驱动器：把关卡流程跑起来
##
## **关卡只有一种形态：关卡脚本（LevelScriptBase）** —— await 它的 run_flow()，
## 流程是一段顺序结构的程序，用 await 串起基类上的流程方法（见 LevelScriptBase）。
## （老的 `.tres` 关卡走的是时间轴事件数组那条路，2026-10-08 已随 .tres 关卡一起删除。）
##
## 谁在用它：
##   MainGameManager._ready()            —— 第一轮开场
##   MainGameManager.start_curr_round_game() —— 多轮关卡的每一轮
## 两种跑法：
##   · 每轮重跑一遍（默认）：一轮 = 这段流程，轮与轮之间靠 MainGameManager 摆场
##   · 整关只跑一遍（关卡脚本 is_one_shot_flow）：
##     一段流程把整关（比如砸罐子的三批）都写进去，跨轮继续往下跑
## 关卡脚本不重写 run_flow() 时跑的是基类的默认流程。
##
## **胜利条件 = 关卡流程跑完**：流程跑完（run_flow）由本驱动器调
## `reward_manager.force_win_on_flow_finished()` 强制胜利并给奖杯 —— 战斗打完只推
## EventBus "battle_finished"（切下一轮用），不再判胜（见 mgm_reward_manager.gd）。

## 流程开始 / 结束、当前事件下标变化（调试通道 / 自动测试取用）
signal signal_timeline_started
signal signal_timeline_finished
signal signal_event_changed(event_index: int)

var main_game: MainGameManager
## 流程是否正在执行
var is_running := false
## 当前事件下标，-1 表示还没进入任何事件（关卡脚本没有事件下标，跑流程期间恒为 0）
var curr_event_index := -1
## 本次执行的代号：每跑一次流程自增，旧的那次在下一个 await 点自己退出
## （多轮关卡：上一轮的流程可能还卡在「等清场」，新一轮开始时把它顶掉）
var _run_id := 0
## 整关只跑一遍的流程是否已经启动过：启动后跨轮继续，不再从头重跑
var _is_one_shot_started := false


func _ready() -> void:
	if Global.main_game != null:
		main_game = Global.main_game


#region 执行关卡流程
## 本关的流程是不是「整关只跑一遍」的（MainGameManager 切轮时据此跳过摆场 / 重跑）
## 看关卡脚本的 is_one_shot_flow
func is_one_shot_timeline() -> bool:
	if main_game == null or main_game.game_para == null:
		return false
	var level_script := main_game.game_para as LevelScriptBase
	if level_script == null:
		return false
	return level_script.is_one_shot_flow


## 跑一遍关卡流程：注入主游戏后 await 关卡脚本的 run_flow()，流程由脚本自己写
## 中途若又被调用（多轮关卡进入下一轮），旧的这次执行会在下一个 await 点退出
func run_timeline() -> void:
	if main_game == null:
		main_game = Global.main_game
	if main_game == null or main_game.game_para == null:
		Log.error("LevelTimelineManager: 主游戏 / 关卡数据不存在，无法执行关卡流程")
		return
	var level_script := main_game.game_para as LevelScriptBase
	if level_script == null:
		## 关卡一律是 LevelScriptBase 的子类；走到这里说明拿到的不是关卡脚本
		Log.error("LevelTimelineManager: 关卡不是 LevelScriptBase，无法执行关卡流程: "
			+ str(main_game.game_para))
		return
	await _run_level_script(level_script)


## 跑关卡脚本：注入主游戏后 await 它的 run_flow()
func _run_level_script(level_script: LevelScriptBase) -> void:
	if level_script.is_one_shot_flow:
		## 整关只跑一遍：第一轮启动后跨轮继续往下跑，后续轮的调用直接跳过
		if _is_one_shot_started:
			Log.debug("关卡流程是整关跑一遍的，本已在执行 / 已跑完，跳过本次调用")
			return
		_is_one_shot_started = true

	_run_id += 1
	var my_run := _run_id
	main_game.is_timeline_waiting_choose_card = false
	is_running = true
	signal_timeline_started.emit()

	## 主游戏在这里注入：关卡脚本的流程方法（await show_zombie() …）靠它拿主游戏
	level_script._mg = main_game
	curr_event_index = 0
	signal_event_changed.emit(0)
	await level_script.run_flow(main_game)
	if _is_stale(my_run):
		return

	curr_event_index = -1
	is_running = false
	signal_timeline_finished.emit()
	## 流程跑完 = 胜利条件达成：强制胜利并给奖杯
	_force_win_on_flow_finished()


## 关卡流程跑完：强制胜利并给奖杯
## 流程内已经判过胜 / 已经结算 / 已经失败 / 还有下一轮时，结算子管理器自己会跳过（见它内部的判据）
##
## **不 await**：胜利线里要等玩家点开奖励 / 点开奖杯，最后还会切场景 —— 挂在关卡流程的协程上
## 会让 MainGameManager 一直卡在 _ready() 且切场景时协程正好醒在已释放的对象上。
## 与原来「清场推事件、结算子管理器自己跑」一致：这里只负责把它起起来
func _force_win_on_flow_finished() -> void:
	if not is_instance_valid(main_game) or main_game.reward_manager == null:
		return
	main_game.reward_manager.force_win_on_flow_finished()


## 本次执行是否已被新一轮的 run_timeline() 顶掉
func _is_stale(my_run: int) -> bool:
	if my_run == _run_id:
		return false
	Log.debug("关卡流程被新一轮顶掉，本次执行退出")
	return true
#endregion
