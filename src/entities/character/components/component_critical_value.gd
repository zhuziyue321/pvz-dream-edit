extends ComponentNormBase
class_name CriticalValueComponent
## 临界值组件
##
## 角色本体血量到达临界值时触发事件，并按配置自动掉血（残血流失）。
## - 状态（是否已进入临界值、掉血计时、"只掉一次"标记）全部由本组件自己维护，宿主不得复制一份（《项目规范.md》K-01）
## - 对外提供 is_below_critical() / is_hp_below_critical() / get_critical_value() 查询接口
## - 掉血一律走血量组件的公开接口 Hp_loss()，不绕过血量组件直接删角色（docs/参考存档/创建新角色.md（角色一节））
## - 启停复用 ComponentNormBase 的多因子机制（K-08），宿主用 E_IsEnableFactor.Death 在死亡时禁用
##
## 临界值默认取 DeathBoundary —— 跟随角色自身的死亡临界值（hp_component.death_hp）：
## 僵尸的 death_hp 由 HpStageChangeComponent 写成 boundary_value_hp 的最后一项（默认本体满血的 1/3），
## 也就是原版"掉头"的那一下。这样"低于临界值"就等于"僵尸已经掉头/倒下"，
## 与小推车规则（掉头以下的僵尸不触发小推车，见 lawn_mower.gd）口径一致。
## 改成 Ratio / Fixed 自定义临界值时**必须**高于 death_hp，否则僵尸先死、永远进不了临界值，_ready 会提示一次。
##
## 主要用于僵尸（场景根节点下挂一个 Node2D，节点名与本类同名，参照 zombie_base.tscn 的 CriticalValueComponent）；
## 植物血量组件的公开接口一致，同样可以挂载。
##
## 给新角色添加（二步，不需要改动任何管理器）：
## 1. 角色场景根节点下加一个挂本脚本的 Node2D，节点名 = CriticalValueComponent
## 2. 需要响应事件时，由宿主在 ready_norm_signal_connect() 里连接
##    signal_below_critical / signal_drain_hp / signal_leave_critical（连接位置见 K-05 第 6 条），
##    把 hp_component.signal_hp_loss 连到 on_hp_loss()，
##    并连接 hp_component.signal_hp_component_death 到 disable_component.bind(E_IsEnableFactor.Death)
## 把该节点从场景里删掉，角色仍能正常运行，只是失去该能力（K-01）。

## 临界值的取值方式
enum E_CriticalValueType{
	DeathBoundary,	## 跟随角色自身的死亡临界值（hp_component.death_hp，僵尸默认是本体满血的 1/3 = 原版"掉头"）
	Ratio,			## 按最大本体血量的比例取值
	Fixed,			## 按固定本体血量取值
}

@export_group("临界值")
## 临界值取值方式
@export var critical_value_type: E_CriticalValueType = E_CriticalValueType.DeathBoundary
## 临界值比例（占最大本体血量），critical_value_type 为 Ratio 时生效
## 必须高于死亡血量（僵尸默认是 1/3），否则僵尸先死、永远进不了临界值
@export_range(0.0, 1.0, 0.01) var critical_value_ratio: float = 0.5
## 临界值固定血量，critical_value_type 为 Fixed 时生效
@export var critical_value_fixed: int = 0

@export_group("低于临界值自动掉血")
## 是否在低于临界值时自动掉血
@export var is_drain_hp: bool = true
## 每次自动掉血值
@export var drain_hp_value: int = 1
## 自动掉血间隔（秒），进入临界值后先等一个间隔再掉第一次血
@export var drain_interval: float = 1.0
## true: 进入临界值只掉一次血；false: 按 drain_interval 持续掉血
@export var is_drain_once: bool = false

## 当前是否已经进入临界值（组件自己维护的状态，外部只读）
var is_in_critical_value: bool = false
## 掉血计时累计（秒）
var drain_time_accumulate: float = 0.0
## 本次进入临界值后是否已经掉过一次血（is_drain_once 使用）
var is_drained_once: bool = false

## "临界值不可达"只提示一次，避免每个僵尸都刷一行日志
static var _is_warned_unreachable: bool = false

## 进入临界值时发射一次（curr_hp:当前本体血量 / critical_value:当前临界值）
signal signal_below_critical(curr_hp: int, critical_value: int)
## 每次自动掉血后发射（curr_hp:掉血后的本体血量 / loss_hp:本次实际损失的本体血量）
signal signal_drain_hp(curr_hp: int, loss_hp: int)
## 血量回到临界值之上（读档、小僵尸大麻烦重置血量）时发射一次
signal signal_leave_critical(curr_hp: int)

@onready var owner_character: Character000Base = owner
@onready var hp_component: HpComponent = %HpComponent


func _ready() -> void:
	super._ready()
	if is_drain_hp and drain_interval <= 0.0:
		Log.error(str(owner.name) + str(" 临界值组件的 drain_interval 必须大于 0，已停止自动掉血"))
	## 自定义临界值不高于死亡血量时，僵尸会先死、永远进不了临界值（默认的 DeathBoundary 不受影响）
	if is_drain_hp and critical_value_type != E_CriticalValueType.DeathBoundary \
			and not _is_warned_unreachable and get_critical_value() <= hp_component.death_hp:
		_is_warned_unreachable = true
		Log.warn(str(owner.name) + str(" 临界值组件的临界值(") + str(get_critical_value())
			+ str(") 不大于死亡血量(") + str(hp_component.death_hp)
			+ str(")，低于临界值自动掉血不会触发，请调大 critical_value_ratio / critical_value_fixed"))
	## 初始血量可能已经低于临界值（读档、初始化时直接赋值），需要同步一次状态。
	## 用 call_deferred 等血量组件自己的 _ready（curr_hp = max_hp）跑完再判定，
	## 否则会拿血量组件的默认值 0 误判成"已进临界值"。
	call_deferred("update_critical_value_state")
	set_physics_process(is_enabling)


func _physics_process(delta: float) -> void:
	## 被禁用（死亡 / 睡眠 / 魅惑…）时不参与判定与掉血
	if not is_enabling:
		return
	update_critical_value_state()
	if not is_in_critical_value or not is_drain_hp or drain_interval <= 0.0:
		return
	if is_drain_once and is_drained_once:
		return

	drain_time_accumulate += delta
	if drain_time_accumulate < drain_interval:
		return
	drain_time_accumulate = 0.0
	drain_hp()


## 启用组件：同时恢复判定与掉血（K-08，必须幂等）
func enable_component(is_enable_factor: E_IsEnableFactor) -> void:
	super(is_enable_factor)
	set_physics_process(is_enabling)


## 禁用组件：同时停止判定与掉血（K-08，必须幂等）
func disable_component(is_enable_factor: E_IsEnableFactor) -> void:
	super(is_enable_factor)
	set_physics_process(is_enabling)


#region 对外接口
## 当前本体血量是否到达临界值（低于或等于，与血量阶段变化组件的判定口径一致）
## 纯数值判定：不依赖组件是否启用，任何时刻都可查询
func is_below_critical() -> bool:
	if not is_instance_valid(hp_component):
		return false
	return is_hp_below_critical(hp_component.curr_hp)


## 用指定血量判断是否到达临界值（供外部预测"再掉 X 血会不会进临界值"）
func is_hp_below_critical(hp: int) -> bool:
	return hp <= get_critical_value()


## 当前临界值：按配置实时计算，max_hp / death_hp 被修改时（小僵尸大麻烦血量减半）自动跟随
## 按比例计算后四舍五入，避免 270 * 0.3 因浮点误差截断成 80
func get_critical_value() -> int:
	if not is_instance_valid(hp_component):
		return 0
	match critical_value_type:
		E_CriticalValueType.DeathBoundary:
			return hp_component.death_hp
		E_CriticalValueType.Ratio:
			return roundi(hp_component.max_hp * critical_value_ratio)
		E_CriticalValueType.Fixed:
			return critical_value_fixed
	return 0
#endregion


#region 内部逻辑
## 血量变化时同步临界值状态（宿主把 hp_component.signal_hp_loss 连到这里，见 K-05 第 6 条）
## 用信号而不是只靠物理帧轮询：僵尸血量掉到死亡临界值而倒下的同一帧里，
## "进入临界值" 的事件仍要在宿主用 Death 因子禁用组件之前发出去
## （血量组件的死亡信号先于 signal_hp_loss 发出，所以这里不能判 is_enabling）
func on_hp_loss(_curr_hp: int, _is_drop: bool) -> void:
	update_critical_value_state()


## 同步临界值状态并发事件（进入 / 离开各只发一次）
## 幂等，可重复调用：读档 / 小僵尸大麻烦重置血量 / 魅惑重启后需要手动再同步一次时由宿主调用
func update_critical_value_state() -> void:
	var curr_is_in_critical := is_below_critical()
	if curr_is_in_critical == is_in_critical_value:
		return
	is_in_critical_value = curr_is_in_critical
	if is_in_critical_value:
		## 进入临界值：重置掉血计时与"只掉一次"标记
		drain_time_accumulate = 0.0
		is_drained_once = false
		signal_below_critical.emit(hp_component.curr_hp, get_critical_value())
	else:
		signal_leave_critical.emit(hp_component.curr_hp)


## 自动掉血：走血量组件公开接口，死亡仍由血量组件处理（signal_hp_component_death）
## 伤害类型用 Real：无视二类防具，与项目其他非子弹伤害（雪橇僵尸、冰道）一致；
## 不播放受击音效（残血流失不是受击），掉手 / 掉头仍按正常流程走
func drain_hp() -> void:
	var hp_before := hp_component.curr_hp
	hp_component.Hp_loss(drain_hp_value, BulletRegistry.AttackMode.Real, true, false)
	is_drained_once = true
	signal_drain_hp.emit(hp_component.curr_hp, hp_before - hp_component.curr_hp)
#endregion
