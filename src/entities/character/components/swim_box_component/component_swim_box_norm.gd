extends SwimBoxComponent
class_name SwimBoxComponentNorm
## 普通僵尸游泳组件


## 期望的游泳状态（最后一次"进入/离开"请求）
## 入场补间有 0.5s，期间僵尸可能已经离开泳池；出池分支是立即发信号的，
## 如果入场协程醒来后无条件发 true，就会出现"僵尸站在陆地上游泳"的状态错乱。
## 因此以最后一次请求为准，补间结束时再确认一次。
var _expected_swimming := false


## 检测到泳池
func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.owner is Pool:
		_expected_swimming = true
		if body_change_swim:
			for sprite_path in body_change_swim.sprite_disappear:
				var sprite = get_node(sprite_path)
				sprite.visible = false

			for sprite_path in body_change_swim.sprite_appear:
				var sprite = get_node(sprite_path)
				sprite.visible = true
		## 如果不是珊瑚僵尸
		if not owner.is_seaweed:
			## 水花
			appear_splash()
			var tween = create_tween()
			# 仅移动y轴，在1.5秒内下移200像素
			tween.tween_property(body, "position:y", body.position.y + 30, 0.5)
			await tween.finished
			## 补间期间可能已经离开泳池，只有请求仍然有效才切换状态
			if _expected_swimming:
				signal_change_is_swimming.emit(true)
		## 如果是珊瑚僵尸
		else:
			appear_splash()
			body.position.y += 30
			body.zombie_body_up_from_pool()
			signal_change_is_swimming.emit(true)

## 离开泳池
func _on_area_2d_area_exited(area: Area2D) -> void:
	if not owner_is_death:
		if area.owner is Pool:
			_expected_swimming = false
			## 水花
			appear_splash()

			if body_change_swim:
				for sprite_path in body_change_swim.sprite_disappear:
					var sprite = get_node(sprite_path)
					sprite.visible = true

				for sprite_path in body_change_swim.sprite_appear:
					var sprite = get_node(sprite_path)
					sprite.visible = false

			var tween = create_tween()
			# 仅移动y轴，在1.5秒上升30像素
			tween.tween_property(body, "position:y", body.position.y - 30, 0.5)
			signal_change_is_swimming.emit(false)

