extends Panel
class_name ConveyorBeltGear

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


## 开始齿轮运动
func start_gear():
	animated_sprite_2d.play(&"default")
