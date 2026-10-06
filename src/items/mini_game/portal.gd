extends Node2D
class_name Portal
## 传送门 —— 迷你游戏**第 11 关**「斗转星移」(Portal Combat)
##
## 草坪上摆两对传送门（一对方形一对圆形），僵尸 / 子弹从一扇进、配对的另一扇出，
## 行进方向不变。门的摆放、换位与传送判定都在 PortalManager，
## 本节点只负责「长什么样 + 横向判定」。
##
## 贴图直接用原版 reanim 拆出来的 PNG（assets/reanim/Portal_*.png），
## reanim 动画资源没有生成，改用 Tween 做旋转 / 呼吸动画。

## 传送门外观（方形 = 黄门，圆形 = 蓝门；两扇同型为一对）
enum E_PortalType {
	Square,
	Circle,
}

const TEX_SQUARE_CENTER := preload("res://assets/reanim/Portal_Square_center.png")
const TEX_SQUARE_GLOW := preload("res://assets/reanim/Portal_Square_glow.png")
const TEX_CIRCLE_OUTER := preload("res://assets/reanim/Portal_Circle_outer.png")
const TEX_CIRCLE_CENTER := preload("res://assets/reanim/Portal_Circle_center.png")
const TEX_CIRCLE_GLOW := preload("res://assets/reanim/Portal_Circle_glow.png")

## 门的像素高（贴图分辨率不一，统一按目标高度归一，不用逐张调 scale）
const DOOR_HEIGHT := 120.0
## 传送判定半宽：僵尸 / 子弹 x 落进 [x-half, x+half] 且行号一致就算进门
## （判定不看 y：僵尸原点 y = 行地面 y、子弹可能斜着飞，按行号匹配更稳）
const HALF_WIDTH := 36.0

## 传送门类型（PortalManager 摆门时赋值）
var portal_type: E_PortalType = E_PortalType.Square
## 所在行（从 0 开始）
var lane := -1

var _glow: Sprite2D
var _frame: Sprite2D
## 重摆换位动画（短时间内重复换位要先打断上一次，否则两段 tween 抢位置）
var _relocate_tween: Tween


## 摆门：定类型与行，并按类型组装门面（重复调用会先清掉旧门面）
func init_portal(new_type: E_PortalType, new_lane: int) -> void:
	portal_type = new_type
	lane = new_lane
	_build_visuals()


## x 是否落在门的判定范围
func contains_x(pos_x: float) -> bool:
	return absf(pos_x - global_position.x) <= HALF_WIDTH


## 淡出 → 挪到新位置 → 淡入（PortalManager 定期换位用）
func relocate(new_pos: Vector2) -> void:
	if _relocate_tween != null and _relocate_tween.is_valid():
		_relocate_tween.kill()
	_relocate_tween = create_tween()
	_relocate_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_relocate_tween.tween_callback(set_global_position.bind(new_pos))
	_relocate_tween.tween_property(self, "modulate:a", 1.0, 0.3)


## 按类型组装门面并起循环动画
func _build_visuals() -> void:
	for child in get_children():
		child.queue_free()
	match portal_type:
		E_PortalType.Square:
			_glow = _make_sprite(TEX_SQUARE_GLOW, DOOR_HEIGHT)
			_glow.modulate.a = 0.55
			_frame = _make_sprite(TEX_SQUARE_CENTER, DOOR_HEIGHT)
			## 方形门：框不转，框与底光交替闪烁
			var tween := create_tween().set_loops()
			tween.tween_property(_frame, "modulate:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(_glow, "modulate:a", 0.85, 0.8).set_trans(Tween.TRANS_SINE)
			tween.tween_property(_frame, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(_glow, "modulate:a", 0.55, 0.8).set_trans(Tween.TRANS_SINE)
		E_PortalType.Circle:
			_glow = _make_sprite(TEX_CIRCLE_GLOW, DOOR_HEIGHT)
			_glow.modulate.a = 0.6
			var core := _make_sprite(TEX_CIRCLE_CENTER, DOOR_HEIGHT * 0.9)
			_frame = _make_sprite(TEX_CIRCLE_OUTER, DOOR_HEIGHT)
			## 圆形门：中心漩涡慢转，外环 / 底光呼吸（final_val 用局部变量存，
			## 直接写 _frame.scale 会在第二步执行时取到已被放大过的值，越呼吸越大）
			var tween_spin := create_tween().set_loops()
			tween_spin.tween_property(core, "rotation", TAU, 3.0).as_relative()
			var base_scale: Vector2 = _frame.scale
			var tween := create_tween().set_loops()
			tween.tween_property(_frame, "scale", base_scale * 1.06, 0.9).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(_glow, "modulate:a", 0.85, 0.9).set_trans(Tween.TRANS_SINE)
			tween.tween_property(_frame, "scale", base_scale, 0.9).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(_glow, "modulate:a", 0.6, 0.9).set_trans(Tween.TRANS_SINE)


## 建一张按目标高度归一的贴图子节点
func _make_sprite(tex: Texture2D, target_height: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2.ONE * (target_height / tex.get_size().y)
	add_child(sprite)
	return sprite
