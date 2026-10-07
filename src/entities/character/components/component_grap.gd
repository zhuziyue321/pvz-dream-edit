extends Node2D
class_name GrapComponent

@onready var anim_tanglekelp_grab: AnimationPlayer = $Anim_Tanglekelp_grab

func activate_it_to_grap_zombie(zombie:Zombie000Base):
	## 把自己从当前宿主摘下、挂到目标僵尸身上。
	## 用 reparent(..., false) 而不是 get_parent().remove_child(self)：
	## 组件不该知道「自己挂在谁下面」（硬约束 §1-2），且 Godot 的 reparent 自带「摘+挂」两步。
	## 第二参数传 false = 保持本地 transform（等价于旧的 remove_child + add_child）。
	reparent(zombie.body, false)
	visible = true
	## 如果在潜水
	if zombie.curr_be_attack_status == Zombie000Base.E_BeAttackStatusZombie.IsDownPool:
		global_position = zombie.shadow.global_position + Vector2(0, 30)
	else:
		global_position = zombie.shadow.global_position + Vector2(0, 0)

	zombie.be_grap_in_pool()
	anim_tanglekelp_grab.play("Tanglekelp_grab")
	await anim_tanglekelp_grab.animation_finished
	zombie.character_death_not_disappear()
	## 水花
	var splash:Splash = SceneRegistry.SPLASH.instantiate()
	zombie.add_child(splash)
	splash.global_position = global_position
	splash.z_index += 5

	var tween:Tween = create_tween()
	tween.tween_property(zombie.body, "position", zombie.body.position + Vector2(0, 100), 1)
	## 第二段的终点在创建 Tween 时就已经求值，与第一段完全相同（等于原地等待 0.5s），
	## 用 as_relative() 才能真正再往下拖 100 像素
	tween.tween_property(zombie.body, "position:y", 100.0, 0.5).as_relative()
	await tween.finished

	zombie.queue_free()

