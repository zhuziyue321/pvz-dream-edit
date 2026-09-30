extends AttackComponentBulletBase
class_name AttackComponentBulletCactus

var is_rise:= false

func _ready() -> void:
	super()
	## 仙人掌使用自身的掩码组件独立于检测组件动态修改子弹掩码
	if not is_instance_valid(can_attack_status_component):
		can_attack_status_component = CanAttackStatusComponent.new()
		can_attack_status_component.name = "CanAttackStatusComponent"
		can_attack_status_component.can_attack_plant_status = 1
		add_child(can_attack_status_component)
	can_attack_status_component.can_attack_zombie_status = 1

## 攻击间隔后触发执行攻击
func _on_bullet_attack_cd_timer_timeout() -> void:
	if is_rise:
		animation_tree.set("parameters/StateMachine/BlendTree 2/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		animation_tree.set("parameters/StateMachine/BlendTree/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func set_cancel_attack():
	animation_tree.set("parameters/StateMachine/BlendTree/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	animation_tree.set("parameters/StateMachine/BlendTree 2/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)

## 当仙人掌起落时
func on_cactus_update_is_rise(value:bool):
	is_rise = value

func update_bullet_can_attack_zombie_status(value:bool):
	if value:
		can_attack_status_component.can_attack_zombie_status = 8
	else:
		can_attack_status_component.can_attack_zombie_status = ~8
	Log.debug(can_attack_status_component.can_attack_zombie_status)
