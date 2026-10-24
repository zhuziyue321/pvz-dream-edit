extends AttackComponentBulletBase
class_name AttackComponentBulletCactus

var is_rise:= false

func component_ready() -> void:
	super()
	## 仙人掌使用自身的掩码组件独立于检测组件动态修改子弹掩码
	if not is_instance_valid(can_attack_status_component):
		can_attack_status_component = CanAttackStatusComponent.new()
		can_attack_status_component.name = "CanAttackStatusComponent"
		can_attack_status_component.can_attack_plant_status = 1
		add_child(can_attack_status_component)
	can_attack_status_component.can_attack_zombie_status = 1

## 攻击间隔后触发执行攻击（仙人掌起 / 落两套 OneShot，都走组件的统一入口）
func _on_bullet_attack_cd_timer_timeout() -> void:
	if is_rise:
		request_one_shot(&"parameters/StateMachine/BlendTree 2/OneShot/request")
	else:
		request_one_shot(&"parameters/StateMachine/BlendTree/OneShot/request")

func set_cancel_attack():
	cancel_one_shot(&"parameters/StateMachine/BlendTree/OneShot/request")
	cancel_one_shot(&"parameters/StateMachine/BlendTree 2/OneShot/request")

## 当仙人掌起落时
func on_cactus_update_is_rise(value:bool):
	is_rise = value

func update_bullet_can_attack_zombie_status(value:bool):
	if value:
		can_attack_status_component.can_attack_zombie_status = 8
	else:
		can_attack_status_component.can_attack_zombie_status = ~8
