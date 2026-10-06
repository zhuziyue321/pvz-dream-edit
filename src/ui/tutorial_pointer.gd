extends Control
class_name TutorialPointer
## 新手教程的指向箭头（提示条 → 目标）
##
## 直接画一个五边形箭头，不依赖美术素材：箭尖永远落在目标点上，箭尾朝向提示条。
## 本节点铺满整个屏幕，所以它画图用的局部坐标 == 提示条所在的画布坐标。

## 箭头总长（箭尖到箭尾）
const ARROW_LENGTH := 42.0
## 箭头最大半宽
const ARROW_HALF_WIDTH := 14.0
## 箭尖到两侧倒钩的距离
const NECK_LENGTH := 24.0
## 箭头填充色（亮黄，压在草地/卡槽上都看得清）
const ARROW_COLOR := Color(1.0, 0.85, 0.1, 1.0)
## 描边色
const OUTLINE_COLOR := Color(0.15, 0.1, 0.0, 1.0)
## 呼吸闪烁速度
const BLINK_SPEED := 6.0

var _target_pos := Vector2.ZERO
var _from_pos := Vector2.ZERO
var _blink_time := 0.0
## 有没有接过目标（见 _ready：箭头初始隐藏不能一刀切）
var _has_target := false


func _ready() -> void:
	## 只画图，绝不能吃掉鼠标事件（卡片 / 草坪还要靠玩家点）
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## **不能在这里无条件 visible = false**：本节点是 add_child 之后当帧就被 point_to 的
	## （教程流水线：先建提示条再指箭头），而 _ready() 比那句 point_to 还晚跑一步，
	## 会把刚点亮的箭头按回去 —— 表现出来的症状就是「第一句提示没有箭头」。
	if not _has_target:
		visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	## 呼吸闪烁，提示玩家看这里
	_blink_time += delta
	modulate.a = 0.65 + 0.35 * (sin(_blink_time * BLINK_SPEED) * 0.5 + 0.5)


## 让箭尖指到 target_pos，箭尾朝向 from_pos（都是画布坐标）
func point_to(target_pos: Vector2, from_pos: Vector2) -> void:
	_target_pos = target_pos
	_from_pos = from_pos
	_has_target = true
	visible = true
	queue_redraw()


func _draw() -> void:
	var direction := (_target_pos - _from_pos).normalized()
	if direction == Vector2.ZERO:
		return
	## 先画一个略大的深色箭头当描边，再叠上正式的箭头
	draw_colored_polygon(
		_arrow_points(direction, ARROW_HALF_WIDTH + 2.0, ARROW_LENGTH + 3.0, NECK_LENGTH + 2.0),
		OUTLINE_COLOR
	)
	draw_colored_polygon(
		_arrow_points(direction, ARROW_HALF_WIDTH, ARROW_LENGTH, NECK_LENGTH),
		ARROW_COLOR
	)


## 以 _target_pos 为箭尖、沿 direction 的反方向生成箭头多边形
func _arrow_points(direction: Vector2, half_width: float, length: float, neck_length: float) -> PackedVector2Array:
	var back := -direction
	var side := Vector2(-direction.y, direction.x)
	return PackedVector2Array([
		_target_pos,
		_target_pos + back * neck_length + side * half_width,
		_target_pos + back * length + side * half_width * 0.4,
		_target_pos + back * length - side * half_width * 0.4,
		_target_pos + back * neck_length - side * half_width,
	])
