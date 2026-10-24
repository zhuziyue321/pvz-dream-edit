extends Node
## 模组「招笑版」：**烟熏状态** —— 挂在被烟熏的僵尸身上，`SMOKE_TIME`（30 秒）后自己撤干净
##
## ★ 它的两条效果（需求 4）：
##
## **① 遇到植物时站立、不啃**：
##   本体判「我这只僵尸贴到植物了」就是 `zombie.is_attack`（攻击组件收到检测信号后置位，
##   同一根信号也把移动因素 `IsAttack` 打开 —— 所以它**本来就停住了**，这里不用自己定身）。
##   要做的是把那一下的**伤害压成 0** 并把动画**从「啃」换成待机**：
##     · 伤害：本体每 8 帧按 `curr_attack_value_per_sec` 算一次啃咬伤害，把它摁成 0 即可
##       （0 走伤害管线会被直接取消，一滴血都不掉，也不播受击音效）；
##     · 动画：置 `is_idle = true` + 把动画状态机**硬跳到 `Idle`**
##       —— 本体**没有 `Walk→Idle` 转移**（Idle 只能从 `Start` 进），所以只能 `play()` 硬跳；
##       跳过去之后 `Idle→Walk` 的条件 `not is_idle` 被我们压住 ⇒ 站得住。
##       植物没了 / 被铲掉时 `is_attack` 自己落回 false ⇒ 我们放开 `is_idle`，本体自动走回 Walk。
##
## **② 被同类索敌**：
##   给宿主标上本体那个通用口子 `Character000Base.is_enemy_to_all_camps` ——
##   它**只改「能不能被打」**（对任何阵营都算敌人），归属阵营 / 朝向 / 表现 / 死亡计数全不动：
##     · 僵尸方的啃咬检测于是把它当敌人 ⇒ 同类会走过来啃它（`is_enemy(Zombie, 它)` 为真）；
##     · 植物方的植物与子弹**照旧**打得中它（`is_enemy(Plant, 它)` 也为真）。
##   ⚠️ **不要**改用 `is_hypno` 那条路：那是**换边**，换了之后玩家的植物就不打它了，
##      还会连带转身、染色、死亡时按「魅惑僵尸」登记。
##   （本模组最早是用「脚底挂一株本体隐形植物当诱饵 + 伤害转移」做同一件事的，
##     那条路也验证可行，但要多造一株植物；本体给了上面这个口子之后换成了它。
##     那株隐形植物留在本体当调试 / 工具植物，见 `plant_invisible.gd`。）
##
## ⚠️ 本类是普通 `Node`（不是 `Character000Base` / `ComponentNormBase` 的子类），
##    `_ready()` 按 Godot 常态写即可 —— 硬约束 §1-3 只管那两类角色 / 组件。

const Settings := preload("zhaoxiao_settings.gd")

## 状态节点名（入口脚本 / 探针按它判「这只僵尸被烟熏过没有」）
const NODE_NAME := &"SmokedStatus"
## 同一个名字的 NodePath 形态（`get_node_or_null()` 只收 NodePath）
const NODE_PATH := ^"SmokedStatus"
## 动画状态机里「待机」那个状态名（本体各僵尸通用：Idle / Walk / eat / Death …）
const IDLE_STATE := &"Idle"
## 动画状态机 playback 的参数路径（与 `component_anim_norm.gd` 的常量同源）
const PLAYBACK_PARAM := &"parameters/StateMachine/playback"

## 宿主（被烟熏的那只僵尸）
var _zombie: Zombie000Base
## 宿主的啃咬组件（普通僵尸版才有 `curr_attack_value_per_sec`，其余僵尸拿不到就只做动画那半）
var _eater: AttackComponentZombieNorm
## 动画树与它的状态机 playback（拿不到就不切动画，只保留「停下 + 不啃」）
var _playback: AnimationNodeStateMachinePlayback
## 倒计时
var _timer: Timer

## 烟熏前那只僵尸的啃咬值（撤离时按它还原，别把人家摁成 0 就回不来）
var _attack_value_before := -1
## 现在是不是我们把动画摁在待机上（撤离时要放开）
var _is_forcing_idle := false
## 已经撤离过了（终态：不再回摁任何东西）
var _is_stopped := false


#region 生命周期
func _ready() -> void:
	_zombie = get_parent() as Zombie000Base
	if _zombie == null:
		Log.error("招笑版模组：烟熏状态的父节点不是僵尸，本状态不生效")
		return
	_eater = _zombie.attack_component as AttackComponentZombieNorm
	if _eater != null:
		_attack_value_before = _eater.curr_attack_value_per_sec
	var anim_tree := _zombie.get_node_or_null(^"AnimationTree") as AnimationTree
	if anim_tree != null:
		_playback = anim_tree.get(PLAYBACK_PARAM) as AnimationNodeStateMachinePlayback
	## 让同类也来索敌它（见文件头 ②）：只标「谁都能打它」，不动它的归属阵营
	_zombie.is_enemy_to_all_camps = true
	_start_timer()
	set_process(true)


## 续时（同一只僵尸又被烟熏了一次：只把 30 秒重新数起，不重复挂状态）
func refresh() -> void:
	if is_instance_valid(_timer):
		_timer.start(Settings.SMOKE_TIME)


func _start_timer() -> void:
	if not is_instance_valid(_timer):
		_timer = Timer.new()
		_timer.name = &"SmokeTimer"
		_timer.one_shot = true
		_timer.wait_time = Settings.SMOKE_TIME
		add_child(_timer)
		_timer.timeout.connect(_on_smoke_timer_timeout)
	_timer.start(Settings.SMOKE_TIME)


func _on_smoke_timer_timeout() -> void:
	## 到点：撤干净然后自己消失
	stop_smoke()
	queue_free()
#endregion


#region 每帧：摁住啃咬伤害 + 按「贴没贴到植物」切待机
func _process(_delta: float) -> void:
	if _is_stopped or not is_instance_valid(_zombie):
		return
	_keep_bite_damage_zero()
	var should_idle := _zombie.is_attack
	if should_idle == _is_forcing_idle:
		return
	if should_idle:
		_force_idle()
	else:
		_release_idle()


## 把啃咬伤害摁在 0
##
## 每帧摁而不是只摁一次：本体在速度变化（冰冻 / 黄油 / 报纸破防…）时会**重算**这个值，
## 只摁一次会被它盖回去。
func _keep_bite_damage_zero() -> void:
	if _eater != null and _eater.curr_attack_value_per_sec != 0:
		_eater.curr_attack_value_per_sec = 0


## 切到「站着待机」（贴到植物了）
##
## ⚠️ 入口是 `start()` 不是 `play()`：Godot 4 把 Godot 3 的 `play()` 改名成了 `start()`，
## 写 `play()` 会在运行期报 `Nonexistent function 'play' in base 'AnimationNodeStateMachinePlayback'`。
func _force_idle() -> void:
	_is_forcing_idle = true
	_zombie.is_idle = true
	if _playback != null:
		_playback.start(IDLE_STATE)


## 放开待机（植物没了 / 被铲了）：本体自己会从 Idle 走回 Walk
func _release_idle() -> void:
	_is_forcing_idle = false
	_zombie.is_idle = false
#endregion


#region 撤离
## 把烟熏做的事全部还回去（探针也会直接调它，不必等 30 秒）
##
## ⚠️ 第一件事就是**关掉每帧逻辑**：`_process()` 每帧都在按「有没有贴到植物」回摁 `is_idle`，
## 只撤一次会被它下一帧又摁回去 —— 探针直接调本方法时尤其明显（它不会像计时器那条路
## 一样紧接着 `queue_free()`）。所以本方法是**终态**：调过一次就再也不回摁任何东西。
func stop_smoke() -> void:
	_is_stopped = true
	set_process(false)
	if is_instance_valid(_zombie):
		if _is_forcing_idle:
			_release_idle()
		if _eater != null and _attack_value_before >= 0:
			_eater.curr_attack_value_per_sec = _attack_value_before
		## 撤掉「谁都能打它」：它回到原样（只有敌对方打得中）
		_zombie.is_enemy_to_all_camps = false


#endregion
