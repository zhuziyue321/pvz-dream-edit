extends Control
class_name PVZButtonBG
## 三段式按钮背景：左帽 + 中段（横向拉伸）+ 右帽；按下时整套换成按下态贴图
##
## 为什么不直接给 Button 挂 StyleBoxTexture：一张贴图只能整张缩放，
## 两端的帽檐会被拉变形；原版按钮本来就是三段素材
## （`pak/images/button_left|middle|right.png`，按下态 `button_down_*.png`），
## 帽檐定宽、中段拉伸，才能适配任意宽度的按钮。
##
## 用法（挂在 Button 下；`show_behind_parent` 画在按钮文字后面，且不吃鼠标）：
##   var bg := PVZButtonBG.new()
##   button.add_child(bg)
##   button.button_down.connect(func() -> void: bg.set_pressed(true))
##   button.button_up.connect(func() -> void: bg.set_pressed(false))

## 左帽 / 右帽的定宽（pak 贴图的实际像素宽；中段在两者之间拉伸）
const CAP_LEFT_WIDTH := 36.0
const CAP_RIGHT_WIDTH := 35.0

## 常驻三件套
const TEX_LEFT := preload("res://pak/images/button_left.png")
const TEX_MIDDLE := preload("res://pak/images/button_middle.png")
const TEX_RIGHT := preload("res://pak/images/button_right.png")
## 按下态三件套
const TEX_DOWN_LEFT := preload("res://pak/images/button_down_left.png")
const TEX_DOWN_MIDDLE := preload("res://pak/images/button_down_middle.png")
const TEX_DOWN_RIGHT := preload("res://pak/images/button_down_right.png")

var _pressed: bool = false


func _init() -> void:
	## 纯背景：不吃鼠标事件，画在宿主（按钮及其文字）后面
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true


## 切按下态（抬起传 `false`）；状态没变就什么都不做
func set_pressed(pressed: bool) -> void:
	if _pressed == pressed:
		return
	_pressed = pressed
	queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < CAP_LEFT_WIDTH + CAP_RIGHT_WIDTH:
		## 按钮比两帽加起来还窄：没有中段可拉，整张中段拉伸兜底
		draw_texture_rect(_middle_texture(), Rect2(0.0, 0.0, width, height), false)
		return
	draw_texture_rect(_middle_texture(), Rect2(CAP_LEFT_WIDTH, 0.0, width - CAP_LEFT_WIDTH - CAP_RIGHT_WIDTH, height), false)
	draw_texture_rect(_left_texture(), Rect2(0.0, 0.0, CAP_LEFT_WIDTH, height), false)
	draw_texture_rect(_right_texture(), Rect2(width - CAP_RIGHT_WIDTH, 0.0, CAP_RIGHT_WIDTH, height), false)


func _left_texture() -> Texture2D:
	return TEX_DOWN_LEFT if _pressed else TEX_LEFT


func _middle_texture() -> Texture2D:
	return TEX_DOWN_MIDDLE if _pressed else TEX_MIDDLE


func _right_texture() -> Texture2D:
	return TEX_DOWN_RIGHT if _pressed else TEX_RIGHT
