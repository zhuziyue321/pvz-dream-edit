@abstract
extends ComponentNormBase
## 基础攻击组件，攻击组件都有攻击射线检测组件（detect_component）
## 列外:全局攻击组件同时使用全局检测组件
class_name AttackComponentBase

@onready var detect_component: DetectComponent = $DetectComponent

## 影响是否可以攻击的因素
enum E_IsAttackFactors{
	Enbale,			## 组件是否禁用
	RayEnemy,		## 射线检测到敌人
	Anim,			## 动画是否可以攻击(仙人掌动画切换\气球在空中\扶梯僵尸搭梯子动画)
	Character,		## 特殊角色本身(使用该因素不能有冲突)
}
## 默认攻击射线检测敌人为false
var is_attack_factors:Dictionary[E_IsAttackFactors, bool] = {
	E_IsAttackFactors.RayEnemy:false,
}
## 是否可以攻击的结果
var is_attack_res := false

## 更新是否可以攻击的影响因素,true表示可以攻击
func update_is_attack_factors(value:bool, factor:E_IsAttackFactors):
	is_attack_factors[factor] = value
	is_attack_res = is_attack_factors.values().all(func(v): return v)
	if is_attack_res:
		attack_start()
	else:
		attack_end()

signal signal_change_is_attack(value:bool)

## 动画事件名：开火（动画资源里写 `on_anim_event("shoot")`）
const ANIM_EVENT_SHOOT := &"shoot"
## 动画事件名：第二个头开火（分裂豌豆）
const ANIM_EVENT_SHOOT_2 := &"shoot_2"
## 谁接管了这个角色的动画事件（同一角色可能挂多个攻击组件，见 `_connect_anim_events`）
const ANIM_EVENT_OWNER_META := &"anim_event_owner"

func component_ready() -> void:
	detect_component_init()
	_connect_anim_events()


## 接上「表现层 → 攻击组件」这条线：动画只报"第几帧发生了开火"，发不发、怎么发由组件决定
##
## ⚠️ 同一角色可能挂多个攻击组件（投石车有 `AttackComponent` / `AttackComponent2`）：
##    只让**第一个**接管的组件处理事件，否则一次动画会打出两份子弹。
## ⚠️ 用 `host_node_of` 取组件：`component_ready()` 跑在宿主 `_ready()` 之前，
##    此时宿主的 `@onready anim_component` 还是 null。
func _connect_anim_events() -> void:
	var anim := Character000Base.host_node_of(owner, ^"AnimComponent") as AnimComponentBase
	if anim == null:
		return
	if anim.has_meta(ANIM_EVENT_OWNER_META):
		return
	anim.set_meta(ANIM_EVENT_OWNER_META, self)
	anim.anim_event.connect(_on_anim_event)


## 动画事件分发：子类有同名方法才转调，没有就忽略
##
## ⚠️ 一律走 `call()`：基类没有 `_shoot_bullet`，直接写会编译不过
func _on_anim_event(event: StringName) -> void:
	match event:
		ANIM_EVENT_SHOOT:
			if has_method(&"_shoot_bullet"):
				call(&"_shoot_bullet")
		ANIM_EVENT_SHOOT_2:
			if has_method(&"_shoot_bullet_2"):
				call(&"_shoot_bullet_2")

func detect_component_init():
	if is_instance_valid(detect_component):
		detect_component.signal_can_attack.connect(update_is_attack_factors.bind(true, E_IsAttackFactors.RayEnemy))
		detect_component.signal_not_can_attack.connect(update_is_attack_factors.bind(false, E_IsAttackFactors.RayEnemy))


## 启用组件
func enable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)
	if is_instance_valid(detect_component):
		detect_component.enable_component(is_enable_factor)
	update_is_attack_factors(true, E_IsAttackFactors.Enbale)

## 禁用组件
func disable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)
	if is_instance_valid(detect_component):
		detect_component.disable_component(is_enable_factor)
	update_is_attack_factors(false, E_IsAttackFactors.Enbale)

## 开始攻击
func attack_start():
	signal_change_is_attack.emit(true)

## 结束攻击
func attack_end():
	signal_change_is_attack.emit(false)

## 被魅惑
func owner_be_hypno():
	detect_component.owner_be_hypno()

@abstract
func owner_update_speed(speed_product:float)
