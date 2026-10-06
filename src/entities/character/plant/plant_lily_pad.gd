extends Plant000DownBase
class_name Plant017LilyPad


## 项目规范 K-04：角色子类不重写 _ready()，改在 ready_norm() 里做初始化
func ready_norm() -> void:
	super()
	tween_up_and_down()

func tween_up_and_down():
	await get_tree().physics_frame
	var tween = create_tween()
	tween.set_loops()  # 无限循环
	tween.set_trans(Tween.TRANS_SINE)  # 平滑缓动

	# 向上移动
	tween.tween_property(
		self,
		"position:y",
		position.y - 5,
		2 + randf()
	).set_ease(Tween.EASE_IN_OUT)

	# 向上移动（返回原点）
	tween.tween_property(
		self,
		"position:y",
		position.y ,
		2 + randf()
	).set_ease(Tween.EASE_IN_OUT)
