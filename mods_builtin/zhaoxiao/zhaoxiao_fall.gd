extends Node
## 模组「招笑版」：**摔倒状态** —— 挂在僵尸身上：像被绊倒一样**趴在地上**，
## `FALL_TIME` 秒后自己**站起来继续走**（招笑版的「摔倒机制」本体）。
##
## ★ 三件事：
##   1. **停下**：把移动因素 `IsCharacter` 置位（本体留给「特殊角色自己定」的那个因素），
##      僵尸停在事故原地；走路动画照播（腿还在原地倒腾，图一乐）。
##   2. **趴下**：`Body` 绕脚根倒 90°（头朝摔倒时的走路方向：朝左走倒向左、
##      朝右走倒向右），同时把身体往上抬 `FALL_SINK_Y`，看着才是趴在地上；
##      倒下去 / 站起来都走 Tween（不是瞬变），摔那一下带一点回弹。
##   3. **起来**：到点先把身体转回 0°，再放开移动因素 —— 僵尸站起来继续走
##      （原先在啃的植物，起来接着啃）。
##
## ★ 为什么不改动画状态机：本体的僵尸状态机里没有「趴下」这个状态，硬跳 `Idle`
##   还会连带两个坑（`Idle` 没有出向 `Death` 的转移 —— 趴着被打死就不播死亡动画；
##   起来还得还 `is_idle`）。所以动画一行不动，只转 `Body` 自己：
##   `Body` 的 `rotation / position` 没有任何动画轨道写它（轨道写的都是
##   `BodyCorrect` 底下的部件，见 `component_anim_norm.gd` 顶部的结构说明）。
##
## ★ 死亡：僵尸死了要**立刻**把身体转回来（死亡动画是按站姿画的），本状态当场撤掉
##   （移动因素保留置位 —— 死了正好别动，死亡流程自己会收尾）。
##
## ★ 谁挂它：路障僵尸变种走到第 4 列时挂一次；后来走到「掉在草坪上的路障」
##   （`zhaoxiao_cone_drop.gd`）身上的僵尸也被挂一次。挂之前都会先查
##   `NODE_PATH`，不会重复挂。
##
## ⚠️ 本类是普通 `Node`（不是 `Character000Base` / `ComponentNormBase` 的子类），
##    `_ready()` 按 Godot 常态写即可 —— 硬约束 §1-3 只管那两类角色 / 组件。

const Settings := preload("zhaoxiao_settings.gd")

## 状态节点名（路障掉落节点 / 探针按它判「这只僵尸已经摔着了」）
const NODE_NAME := &"FallStatus"
## 同一个名字的 NodePath 形态（`get_node_or_null()` 只收 NodePath）
const NODE_PATH := ^"FallStatus"
## 倒计时的节点名
const TIMER_NAME := &"FallTimer"

## 宿主（摔倒的那只僵尸）
var _zombie: Zombie000Base
## 宿主的 Body（倒下去 / 爬起来转的就是它）
var _body: BodyCharacter
## 宿主的移动组件（停 / 放都走它）
var _move: MoveComponent
## 趴多久的倒计时
var _timer: Timer
## 倒下去 / 爬起来那个 Tween
var _tween: Tween
## 摔倒前 Body 的 y（爬起来要还回去，别把人家摁沉了）
var _body_pos_y_before := 0.0
## 正在「爬起来」那一下（转完了才放开移动因素）
var _is_getting_up := false
## 已经撤离过了（终态：不再回摁任何东西）
var _is_stopped := false


#region 生命周期
func _ready() -> void:
	_zombie = get_parent() as Zombie000Base
	if _zombie == null:
		Log.error("招笑版模组：摔倒状态的父节点不是僵尸，本状态不生效")
		return
	_body = _zombie.body
	_move = _zombie.move_component
	if _body == null:
		Log.error("招笑版模组：僵尸 %s 身上没有 Body，摔不下去" % _zombie.name)
		return
	_body_pos_y_before = _body.position.y
	## 死了要把身体转回来（死亡动画是按站姿画的）
	if is_instance_valid(_zombie.hp_component):
		_zombie.hp_component.signal_hp_component_death.connect(_on_death)
	_fall_down()
	_start_timer()
	set_process(true)


## 趴下：停住 + 把身体倒下去
func _fall_down() -> void:
	_stop_move()
	_kill_tween()
	_tween = create_tween()
	## 回弹一下再趴平（摔地上的那一下）
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(true)
	_tween.tween_property(_body, "rotation", _lie_rotation(), Settings.FALL_TIPPING_TIME)
	_tween.tween_property(_body, "position:y",
		_body_pos_y_before - _sink_y(), Settings.FALL_TIPPING_TIME)


## 倒计时的节点只用一次（起来就撤）
func _start_timer() -> void:
	if not is_instance_valid(_timer):
		_timer = Timer.new()
		_timer.name = TIMER_NAME
		_timer.one_shot = true
		_timer.wait_time = Settings.FALL_TIME
		add_child(_timer)
		_timer.timeout.connect(_on_fall_timer_timeout)
	_timer.start(Settings.FALL_TIME)


func _on_fall_timer_timeout() -> void:
	_get_up()
#endregion


#region 每帧：摁住移动因素 + 等爬起来那一下转完
func _process(_delta: float) -> void:
	if _is_stopped or not is_instance_valid(_zombie):
		return
	## 摔倒期间每帧摁住移动因素（别被别人的释放顶掉 —— 与烟熏每帧摁啃咬伤害同一个路子）
	if not _is_getting_up and not _zombie.is_death:
		_stop_move()
	## 爬起来那一下转完了：放开移动因素，继续走
	if _is_getting_up and (not is_instance_valid(_tween) or not _tween.is_running()):
		_stand_up_done()


## 把移动因素摁在「不移动」上
func _stop_move() -> void:
	if _move != null:
		_move.update_move_factor(true, MoveComponent.E_MoveFactor.IsCharacter)


## 趴姿的旋转角：朝左走倒向左、朝右走倒向右。
## Body 的旋转在角色**本地**坐标系里，根节点的 `scale.x` 翻转会把它镜像过去，
## 所以乘上方向就是「往前栽」。
func _lie_rotation() -> float:
	return -Settings.FALL_LIE_ANGLE * float(_zombie.direction_x_root)


## 身体要抬多少（小僵尸按体型缩，大僵尸不缩 —— 招笑版主要摔的是普通体型）
func _sink_y() -> float:
	return Settings.FALL_SINK_Y * clampf(absf(_zombie.scale.y), 0.5, 1.0)
#endregion


#region 爬起来 / 撤离
## 到点了：先把身体转回站姿，转完再放开移动因素
func _get_up() -> void:
	if _is_stopped or not is_instance_valid(_zombie) or _body == null:
		queue_free()
		return
	_is_getting_up = true
	_kill_tween()
	_tween = create_tween()
	## 起来那一下不往回弹（弹过头会像躺回去），匀速转起来
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.set_parallel(true)
	_tween.tween_property(_body, "rotation", 0.0, Settings.FALL_TIPPING_TIME)
	_tween.tween_property(_body, "position:y", _body_pos_y_before, Settings.FALL_TIPPING_TIME)


## 站好了：放开移动因素，本状态到此为止
func _stand_up_done() -> void:
	if _is_stopped:
		return
	_is_stopped = true
	set_process(false)
	if _move != null:
		_move.update_move_factor(false, MoveComponent.E_MoveFactor.IsCharacter)
	queue_free()


## 僵尸死了（死亡信号）：身体立刻转回来，本状态当场撤掉
func _on_death() -> void:
	_is_stopped = true
	set_process(false)
	_kill_tween()
	if is_instance_valid(_timer):
		_timer.stop()
	if _body != null and is_instance_valid(_body):
		_body.rotation = 0.0
		_body.position.y = _body_pos_y_before
	## 移动因素**不**放开：死了正好别动（死亡流程自己会收尾）
	queue_free()


func _kill_tween() -> void:
	if is_instance_valid(_tween) and _tween.is_running():
		_tween.kill()
	_tween = null
#endregion
