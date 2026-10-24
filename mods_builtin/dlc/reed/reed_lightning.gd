extends Node2D
## 闪电芦苇的链状电弧特效：在给定的一串「相对父节点」本地坐标点之间画一道抖动的电弧，
## 短暂高亮后自动销毁。
##
## 用法（植物脚本里）：把一串世界点减去父节点 global_position 后塞进 `points`，add_child 即可。
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：不写 class_name。

@export var points: PackedVector2Array = []
@export var bolt_color := Color(0.85, 0.95, 1.0)
@export var lifetime := 0.18

func _ready() -> void:
	z_index = 100
	if points.size() < 2:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, lifetime)
	tw.tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		_draw_segment(points[i], points[i + 1])


## 两段之间画一条带中间抖动的折线：外层柔光 + 内层亮芯
func _draw_segment(a: Vector2, b: Vector2) -> void:
	var seg_len := b.distance_to(a)
	if seg_len < 0.001:
		return
	var steps := int(ceil(seg_len / 18.0)) + 2
	var perp := (b - a).normalized().orthogonal()
	var prev := a
	for s in range(1, steps + 1):
		var t := float(s) / float(steps)
		var base := a.lerp(b, t)
		## 端点不抖，中间按 sin 衰减做出「放电抖动」
		var jitter := sin(t * PI) * 8.0 * (randf() - 0.5) * 2.0
		var p := base + perp * jitter
		draw_line(prev, p, bolt_color * 0.4, 6.0, true)
		draw_line(prev, p, bolt_color, 2.0, true)
		prev = p
