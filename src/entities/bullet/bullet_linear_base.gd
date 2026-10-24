extends Bullet000NormBase
class_name BulletLinear000Base
## 直线移动子弹基类

## 线性移动组件
@onready var movement_component: BulletMovementLinear = $MovementComponent

## 对僵尸敌人造成伤害,直线类子弹重写
func _attack_zombie(zombie:Zombie000Base):
	## 从后面攻击僵尸的子弹，正常伤害类型子弹攻击类型修改为真实
	if direction.x < 0 and bullet_mode ==ConstDamage.E_DamageMode.Norm:
		## 攻击敌人（末尾两个参数 = 伤害载体 / 发起者，见 Character000Base.be_attacked_bullet）
		zombie.be_attacked_bullet(attack_value,ConstDamage.E_DamageMode.Real, true, trigger_be_attack_sfx, self)
	else:
		## 攻击敌人
		zombie.be_attacked_bullet(attack_value, bullet_mode, true, trigger_be_attack_sfx, self)


func _physics_process(delta: float) -> void:
	## 调用移动组件控制移动
	movement_component.physics_process_bullet_move(delta)

	## 移动超过最大距离后销毁，部分子弹有限制
	if global_position.distance_to(start_pos) > max_distance:
		queue_free()

## 改变y位置(三线调用)
func change_y(target_y:float):
	var tween = create_tween()
	var start_y = global_position.y
	tween.tween_method(func(y):
		global_position.y = y,
		start_y,
		target_y,
		0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 子弹与敌人碰撞,直线子弹检测是否有斜面,判断是否与斜面碰撞
func _on_area_2d_attack_area_entered(area: Area2D) -> void:
	## 线性子弹判断是否攻击到斜坡,非穿透子弹
	if area.owner is Slope:
		var slope:Slope = area.owner
		## 如果方向与斜面法向量夹角小于90度
		if direction.dot(slope.normal_vector_slope) < 0:
			attack_once(null)
		return
	elif area.owner is Character000Base:
		super(area)

## 直线子弹先对壳类进行攻击：取植物的优先级（壳类 → 本体 → 花盆/睡莲）
##
## 与抛物线版**只差顺序**，取法共用 `Bullet000NormBase.get_plant_in_cell_by_order()`
## （2026-10-16 合并，见 docs/TODO清单.md U-36）。
const BE_HIT_PLANT_ORDER: Array[CharacterRegistry.PlacePlantInCell] = [
	CharacterRegistry.PlacePlantInCell.Shell,
	CharacterRegistry.PlacePlantInCell.Norm,
	CharacterRegistry.PlacePlantInCell.Down,
]

func get_first_be_hit_plant_in_cell(plant:Plant000Base)->Plant000Base:
	return get_plant_in_cell_by_order(plant, BE_HIT_PLANT_ORDER)
