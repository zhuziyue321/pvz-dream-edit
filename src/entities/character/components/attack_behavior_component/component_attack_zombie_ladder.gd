extends AttackComponentZombieNorm
class_name AttackComponentZombieLadder

## 是否可以搭梯子
var is_can_ladder:=true
## 发射搭梯子信号
signal signal_ladder(plant:Plant000Base)

func _physics_process(delta: float) -> void:
	if is_enabling and is_attack_res:
		## 结算周期与父类同源（`EAT_SETTLE_FRAME_INTERVAL`），别在这里另写一个数字
		frame_counter = wrapi(frame_counter + 1, 0, EAT_SETTLE_FRAME_INTERVAL)
		if not is_instance_valid(detect_component.enemy_can_be_attacked):
			return
		if frame_counter != 0:
			return
		## 如果可以搭梯子
		if is_can_ladder:
			## 如果有可以被搭梯子的植物
			var plant_ladder = get_plant_can_ladder(detect_component.enemy_can_be_attacked)
			if is_instance_valid(plant_ladder):
				is_can_ladder = false
				signal_ladder.emit(plant_ladder)
				return
		var eat_damage := settle_eat_damage(delta)
		if eat_damage > 0:
			detect_component.enemy_can_be_attacked.be_zombie_eat(eat_damage, owner)


## 判断是否可以给敌人挂梯子
func get_plant_can_ladder(enemy:Character000Base) -> Plant000Base:
	if enemy is Plant000Base:
		## 挂载梯子的植物
		var plant_ladder:Plant000Base= enemy.plant_cell.get_plant_ladder()
		if is_instance_valid(plant_ladder):
			return plant_ladder

	return null
