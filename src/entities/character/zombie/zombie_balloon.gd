extends Zombie000Base
class_name Zombie017Balloon

## 我是僵尸模式气球破裂的位置
@export var balloon_pop_glo_pos_x_in_zombie_mode:float = 50
@export_group("动画状态")
## 气球是否已经破了（破防表现由 `ArmorComponentBalloon` 置位）
@export var is_pop:=false

func ready_norm():
	super()
	hurt_box_component.position.y -= 20
	## 我是僵尸模式：飘到门框位置就挤破气球（位置判定下沉到移动组件，不再自己写 `_process`）
	if is_zombie_mode:
		move_component.watch_position_x(balloon_pop_glo_pos_x_in_zombie_mode, _on_reach_balloon_pop)


## 到达气球破裂位置
func _on_reach_balloon_pop():
	if is_pop:
		return
	## 气球（防具）被门框挤破：走伤害管线把这一层防具打掉，
	## 否则「防具破了」的信号不发，落地表现与攻击解禁都不会触发
	break_armor(get_armor(ConstArmor.E_ArmorType.Balloon), true, true, true)

## 气球破裂落地结束，可以移动（动画调用）
func balloon_pop_end():
	move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsAnimGap)
	attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.Balloon)

## 被三叶草吹走
func be_blow_away():
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsBlover)

	var tween:Tween = create_tween()
	tween.tween_property(self, ^"position:x", position.x+1000, 1)
	tween.tween_callback(character_death_disappear)


## 被冰冻控制（气球僵尸不吃冰冻伤害，只转减速；第三个参数是寒冰菇的伤害，这里忽略）
func be_ice_freeze(time:float, new_time_ice_end_decelerate:float, _damage:int = 0):
	be_ice_decelerate(time + new_time_ice_end_decelerate)
