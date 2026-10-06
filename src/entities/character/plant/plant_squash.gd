extends Plant000Base
class_name Plant018Squash

@onready var area_2d_squash_attack: Area2D = $Area2DSquashAttack
@onready var detect_component: DetectComponentSquash = $DetectComponent

## 可以攻击的敌人状态掩码组件（未在场景中配置时按窝瓜默认值创建）
@onready var can_attack_status_component: CanAttackStatusComponent = get_node_or_null(^"CanAttackStatusComponent")

@export_group("动画状态")
@export var is_attack: bool = false
@export var is_right:bool = true
var target_x

## 项目规范 K-04：角色子类不重写 _ready()，初始化放 ready_norm()
func ready_norm() -> void:
	super()
	_ensure_can_attack_status_component()


## 确保存在可攻击状态掩码组件（未在场景中配置时按窝瓜默认掩码创建）
func _ensure_can_attack_status_component() -> void:
	if is_instance_valid(can_attack_status_component):
		return
	can_attack_status_component = CanAttackStatusComponent.new()
	can_attack_status_component.name = "CanAttackStatusComponent"
	can_attack_status_component.can_attack_plant_status = 13
	can_attack_status_component.can_attack_zombie_status = 1
	add_child(can_attack_status_component)


func ready_norm_signal_connect():
	super()
	detect_component.signal_can_attack.connect(attack_start)

## 开始攻击
func attack_start():
	if not is_attack:
		SoundManager.play_character_SFX("SquashHmm")
		is_attack = true
		target_x = detect_component.enemy_can_be_attacked.shadow.global_position.x
		is_right = target_x > global_position.x
		hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)

## 开始跳跃
func jump_up_start():
	z_index += 50
	## 如果地形为睡莲或者水
	if plant_cell.curr_condition & 8 or  plant_cell.curr_condition & 16:
		shadow.visible = false

	var tween:Tween = create_tween()
	if is_instance_valid(detect_component.enemy_can_be_attacked):
		tween.tween_property(self, "global_position:x", detect_component.enemy_can_be_attacked.shadow.global_position.x, 0.3).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(self, "global_position:x", target_x, 0.3).set_ease(Tween.EASE_IN)

## 压扁所有范围内可攻击僵尸
func squash_all_area_zombie():
	var areas = area_2d_squash_attack.get_overlapping_areas()
	for area in areas:
		var zombie:Zombie000Base = area.owner
		## 敌我不再由碰撞层区分：魅惑僵尸归属植物方，窝瓜不压它（与原行为一致）
		if not BulletCampConfig.is_enemy(BulletCampConfig.get_owner_camp(self), zombie):
			continue
		## 如果为同一行僵尸
		if zombie.lane == row_col.x:
			if can_attack_status_component.can_attack(zombie):
				zombie.be_squash()

## 跳入水中判断
func judge_jump_pool():
	## 如果地形为睡莲或者水
	if plant_cell.curr_condition & 8 or  plant_cell.curr_condition & 16:
		## 水花
		var splash:Splash = SceneRegistry.SPLASH.instantiate()
		plant_cell.add_child(splash)
		splash.global_position = Vector2(global_position.x,plant_cell.global_position.y + plant_cell.size.y)
		splash.z_as_relative = z_as_relative
		splash.z_index = z_index
		character_death()
	else:
		SoundManager.play_character_SFX(&"gargantuar_thump")
