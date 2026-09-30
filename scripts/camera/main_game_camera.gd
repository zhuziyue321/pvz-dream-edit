extends Camera2D
class_name MainGameCamera


## 当前正在播放的位移 Tween，用于互斥
var curr_move_tween: Tween


# 返回 Tween 对象，供外部 await
func move_to(target_pos: Vector2, duration: float) -> Signal:
	## 不 kill 上一个 Tween 会让两个 Tween 同时写 global_position（相机抖动/停在中途）
	if curr_move_tween != null and curr_move_tween.is_valid():
		curr_move_tween.kill()
	var tween = create_tween()
	curr_move_tween = tween

	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	return tween.finished


## 开始游戏查看僵尸
func move_look_zombie():
	return move_to(Vector2(120, 0), 2)

## 返回原点
func move_back_ori():
	return move_to(Vector2(-150, 0), 2)
