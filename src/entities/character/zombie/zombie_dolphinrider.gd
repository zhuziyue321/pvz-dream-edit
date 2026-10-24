extends ZombieJumpBase
class_name Zombie015Dolphinrider
## 海豚骑士僵尸：跳跃流程继承 `ZombieJumpBase`，本类只保留「骑豚状态」与「入水 / 出水」。

## 是否骑着海豚(出泳池时,骑海豚时切换动画移动本体位置\死亡时判断(没有对应死亡动画))
var is_ride := true


## 开始跳跃时不再骑着海豚
func _on_jump_start_extra():
	is_ride = false


## 跳跃后摇结束：跳完切回地面移动
func _on_jump_end_extra():
	move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)


## 改变游泳状态,
func change_is_swimming(value:bool):
	is_swimming = value
	#move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsSwimingChange)
	#shadow.visible = not value
	## 如果是跳入泳池
	if is_swimming:
		curr_be_attack_status = E_BeAttackStatusZombie.IsJumpInPool
		signal_status_update.emit()
	else:
		move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
		## 如果骑海豚到泳池边缘离开泳池
		if is_ride:
			await get_tree().process_frame
			global_position.x -= 62
			move_component._walking_start()


## 动画调用函数
## 僵尸跳入泳池动画
func zombie_jump_in_pool_end():
	curr_be_attack_status = E_BeAttackStatusZombie.IsNorm
	signal_status_update.emit()
	move_component.update_move_mode(MoveComponent.E_MoveMode.Speed)
	shadow.visible = false

	jump_component.enable_component(ComponentNormBase.E_IsEnableFactor.Default)


## 角色死亡
func character_death():
	super()
	## 如果骑着海豚死亡,没有对应死亡动画
	if is_ride:
		await get_tree().create_timer(2.0, false).timeout
		queue_free()
