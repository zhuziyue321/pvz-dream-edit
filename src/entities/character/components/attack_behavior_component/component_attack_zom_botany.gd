extends AttackComponentBulletPultBase
class_name AttackComponentZomBotany
## 植物僵尸的发射类攻击组件（豌豆 / 寒冰 / 机枪 / 卷心菜 / 西瓜 / 冰瓜 僵尸通用）
##
## 与植物的同名组件唯一的区别：**不靠动画调用 `_shoot_bullet()`**。
## 僵尸的攻击动画是「啃咬」，动画里没有 `_shoot_bullet` 的方法调用轨道，
## 直接套用植物的发射组件会导致冷却走完却一颗子弹都发不出来。
## 这里改成冷却到点就直接发射，再用 Tween 让头顶植物做一个「发射」的小动作代替动画表现。
##
## 子弹阵营由 AttackComponentBulletBase.get_bullet_camp() 决定（owner 是僵尸 → 僵尸方子弹，打玩家的植物），
## 所以这些僵尸和玩家的植物**共用同一份子弹场景**（豌豆 / 卷心菜 / 西瓜 …），不用复制一套僵尸版。

## 一次攻击连发几颗（原版机枪僵尸一次 4 发，其余 1 发）
@export var burst_num: int = 1
## 连发间隔（秒）
@export var burst_interval: float = 0.12
## 子弹方向：僵尸朝房子走，子弹朝**左**飞。
## 不能沿用 detect_component.ray_area_direction —— 那是按检测区 rotation 算的，
## 僵尸的啃咬检测区 rotation 是 0（等于朝右），直接拿来用子弹会往僵尸身后飞
@export var bullet_direction: Vector2 = Vector2.LEFT


func get_bullet_paras(marker_2d_bullet_glo_pos:Vector2, ray_direction:Vector2) -> Dictionary[Bullet000NormBase.E_InitParasAttr,Variant]:
	var paras := super(marker_2d_bullet_glo_pos, ray_direction)
	paras[Bullet000NormBase.E_InitParasAttr.Direction] = bullet_direction
	return paras


## 攻击间隔到点：不走动画，直接发射
func _on_bullet_attack_cd_timer_timeout() -> void:
	if not is_attack_res:
		return
	## 投手类需要目标位置（直线子弹不读这两个键，写了也不影响）
	last_target_enemy = detect_component.update_first_enemy()
	if is_instance_valid(last_target_enemy):
		last_target_enemy_global_pos = last_target_enemy.global_position
	await _shoot_burst()


## 连发
func _shoot_burst() -> void:
	for i in range(maxi(burst_num, 1)):
		if not is_instance_valid(self) or not is_attack_res:
			return
		_shoot_bullet()
		_play_head_shoot_anim()
		if i < burst_num - 1:
			await get_tree().create_timer(burst_interval).timeout


## 头顶植物的「发射」表现：向后一顿再弹回，代替没有的发射动画
func _play_head_shoot_anim() -> void:
	var head := _get_plant_head()
	if not is_instance_valid(head):
		return
	var base_pos: Vector2 = head.position
	var tween := head.create_tween()
	tween.tween_property(head, "position", base_pos + Vector2(4, 0), 0.06)
	tween.tween_property(head, "position", base_pos, 0.1)


## 取头顶植物节点（没有头顶植物组件时返回 null，只是少了表现，不影响发射）
func _get_plant_head() -> Node2D:
	var plant_component := owner.get_node_or_null(^"ZombiePlantComponent") as ZombiePlantComponent
	if plant_component == null:
		return null
	return plant_component.plant_head
