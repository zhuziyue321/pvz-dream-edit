extends Sprite2D
class_name RealGlove
## 跟随鼠标的真手套（进入搬运状态时显示，拿到植物后收起）

var is_using := false


func _process(_delta: float) -> void:
	if is_using:
		global_position = get_global_mouse_position()


func change_is_using(value: bool) -> void:
	is_using = value
	visible = value
