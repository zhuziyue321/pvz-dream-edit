extends Camera2D
class_name MainGameCamera
## 主游戏镜头：横移使用全局位置，落地震动使用独立偏移，两者可以同时进行。

## 主游戏短促震动事件；参数依次为二维幅度、持续游戏秒数和每秒振动次数。
const SHAKE_EVENT: String = "main_game_camera_shake"
## 当前震动开始前的相机偏移；重复触发期间不重新取值，避免偏移累积。
var _shake_base_offset: Vector2 = Vector2.ZERO
## 当前震动的横向和纵向最大幅度，单位为相机坐标像素。
var _shake_amplitude: Vector2 = Vector2.ZERO
## 本次震动的持续时间，单位为游戏秒，不额外乘角色动画速度。
var _shake_duration: float = 0.0
## 本次震动已消耗的游戏秒数；场景暂停时不推进。
var _shake_elapsed: float = 0.0
## 当前震动的振动频率，单位为每秒次数。
var _shake_frequency: float = 20.0


## 当前正在播放的位移 Tween，用于互斥
var curr_move_tween: Tween


#region 震动
## 触发一次当前镜头的震动；非当前镜头或无效参数不处理。
## [param amplitude] 横纵最大偏移，单位为像素；负数按绝对值处理，零向量不触发。
## [param duration] 持续游戏秒数，必须为有限正数；暂停与全局时间倍率自然生效。
## [param frequency] 每秒振动次数，必须为有限正数；重复请求取较大幅度和频率并刷新衰减。
func shake_once(amplitude: Vector2, duration: float, frequency: float = 20.0) -> void:
	if not is_current() or not amplitude.is_finite() or amplitude.is_zero_approx() \
		or not is_finite(duration) or duration <= 0.0 or not is_finite(frequency) or frequency <= 0.0:
		return
	if _shake_duration <= 0.0:
		_shake_base_offset = offset
		_shake_amplitude = amplitude.abs()
		_shake_frequency = frequency
	else:
		## 合并当前剩余震动，不新建并行补间，也不把当前抖动后的偏移当作原点。
		_shake_amplitude = Vector2(maxf(_shake_amplitude.x, absf(amplitude.x)), maxf(_shake_amplitude.y, absf(amplitude.y)))
		_shake_frequency = maxf(_shake_frequency, frequency)
	_shake_duration = maxf(_shake_duration - _shake_elapsed, duration)
	_shake_elapsed = 0.0
	## 事件当帧先给出纵向冲击；暂停期间到达的请求留到恢复后推进，不立即改变画面。
	if not get_tree().paused:
		offset = _shake_base_offset + Vector2(0.0, _shake_amplitude.y)
	set_process(true)


## 更新震动；[param delta] 为引擎传入的游戏秒，避免与角色速度重复换算。
func _process(delta: float) -> void:
	if not is_current():
		stop_shake()
		return
	## 重新选卡和失败演出会让相机在暂停时仍能横移，震动需要独立遵循战斗暂停。
	if get_tree().paused:
		return
	_shake_elapsed += delta
	if _shake_elapsed >= _shake_duration:
		stop_shake()
		return
	## 线性衰减至零，使最后一帧平稳回到原相机偏移。
	var decay: float = 1.0 - _shake_elapsed / _shake_duration
	## 纵向振动为主要冲击，横向使用不同频率，避免画面沿固定斜线移动。
	var phase: float = TAU * _shake_frequency * _shake_elapsed
	offset = _shake_base_offset + Vector2(sin(phase * 0.75) * _shake_amplitude.x, cos(phase) * _shake_amplitude.y) * decay


## 停止当前震动并准确恢复起始偏移；未触发震动时不覆盖外部配置。
func stop_shake() -> void:
	if _shake_duration > 0.0:
		offset = _shake_base_offset
	_shake_duration = 0.0
	_shake_elapsed = 0.0
	_shake_amplitude = Vector2.ZERO
	set_process(false)
#endregion


# 返回 Tween 对象，供外部 await
func move_to(target_pos: Vector2, duration: float) -> Signal:
	## 已经在目标位置：不再播一次空位移，直接给一个立刻完成的信号。
	## 关卡流程自己排的 CameraBack 事件常会叠在「选卡」内部的相机归位之后
	## （choose_card_finish 已经 await 过 move_back_ori），重复跑会让玩家白等一轮 duration
	if duration <= 0.0 or global_position.is_equal_approx(target_pos):
		return get_tree().create_timer(0.0).timeout
	## 不 kill 上一个 Tween 会让两个 Tween 同时写 global_position（相机抖动/停在中途）
	if curr_move_tween != null and curr_move_tween.is_valid():
		curr_move_tween.kill()
	var tween = create_tween()
	curr_move_tween = tween

	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	return tween.finished


## 相机三个停靠点全部按「背景图」算，不写死魔数：
## 背景贴图 1400x600（res://assets/image/background/*.jpg），背景 Sprite2D 是
## centered = false、position = (-210, 0)（见 src/world/background/*.tscn），
## 所以背景占的世界区间是 x ∈ [-210, 1190]、y ∈ [0, 600]。
## 视口 800x600（project.godot），anchor_mode = FixedTopLeft →
## camera.position.x 就是「可见区左上角」的世界 x（screen_x = world_x - position.x）。
##
## 改分辨率 / 换背景尺寸时只动这三个常量，别去改各调用点。
const BG_LEFT_X := -210.0      ## 背景左上角（= 背景 Sprite2D 的 position.x）
const BG_WIDTH := 1400.0       ## 背景贴图宽
const VIEW_WIDTH := 800.0      ## 视口宽（与 project.godot 的 viewport 宽一致）

## 进关时：可见区左上角 == 背景左上角 → 拍到最左侧的房子（world -181..-32）
const CAM_POS_INIT := Vector2(BG_LEFT_X, 0)
## 开战前看僵尸：可见区右上角 == 背景右上角 → 拍到最右侧的僵尸入场马路
const CAM_POS_LOOK_ZOMBIE := Vector2(BG_LEFT_X + BG_WIDTH - VIEW_WIDTH, 0)
## 相机归位点（选卡结束 / 看僵尸结束回到这里）：背景左上角往右 220px
## → 可见区 = world 10..810，草坪（col_x 45..764）+ 左侧小推车（x = 20 + 小推车宽）正好装下，
## 房子留在屏幕外，由失败流程（mgm_lose_manager）平移去拍 CAM_POS_INIT
const CAM_POS_BACK_OFFSET := 220.0
const CAM_POS_ORI := Vector2(BG_LEFT_X + CAM_POS_BACK_OFFSET, 0)


func _ready() -> void:
	## 场景里摆的 Camera2D.position 与常量不同步时以常量为准
	## （两处不同步的坑见 docs/工作记录/2026-10-03_分辨率改成800x600.md）
	global_position = get_init_position()
	## 没有震动时关闭逐帧更新，镜头横移 Tween 不受影响。
	set_process(false)
	EventBus.subscribe(SHAKE_EVENT, shake_once)


## 离开关卡时解除事件监听并恢复原偏移，避免重新入树后残留震动位置。
func _exit_tree() -> void:
	EventBus.unsubscribe(SHAKE_EVENT, shake_once)
	stop_shake()


## 进关停靠点：关卡数据上配了 camera_init_x 就以关卡为准（见 ResourceLevelData.camera_init_x），
## 没配就是背景最左侧（拍到房子）。
## 能在这里读到关卡数据：MainGameManager._enter_tree() 先设好 Global.main_game / game_para，
## 子节点（本相机）的 _ready 才跑。
func get_init_position() -> Vector2:
	var x := CAM_POS_INIT.x
	if Global.main_game != null and Global.main_game.game_para != null \
			and Global.main_game.game_para.has_camera_init_x():
		x = Global.main_game.game_para.camera_init_x
	return Vector2(x, CAM_POS_INIT.y)


## 瞬移（不播位移）：给「不走选卡就开战」的入口兜底用，见 MainGameManager.main_game_start
func snap_to(target_pos: Vector2) -> void:
	if curr_move_tween != null and curr_move_tween.is_valid():
		curr_move_tween.kill()
	global_position = target_pos


## 开始游戏查看僵尸
func move_look_zombie():
	return move_to(CAM_POS_LOOK_ZOMBIE, 2)

## 返回原点
func move_back_ori():
	return move_to(CAM_POS_ORI, 2)
