extends Plant000Base
class_name Plant016DoomShroom

@onready var bomb_component: BombComponentBase = %BombComponent

func ready_norm_signal_connect():
	super()
	bomb_component.signal_bomb_once.connect(plant_cell.create_crater)


## 睡醒之后立刻炸
##
## ⚠️ 原逻辑靠 `not is_idle` 表达式在"醒来 → idle"之后自动触发爆炸；
##    现在 `idle → explode` 已改成手动 travel，这里必须自己点名，否则白天被唤醒后不炸。
func _after_anim_wake() -> void:
	if is_show:
		super()
		return
	request_anim_state(&"DoomShroom_explode")



