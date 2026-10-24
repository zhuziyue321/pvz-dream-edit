extends Node2D
class_name Portal
## 传送门 —— 迷你游戏**第 11 关**「斗转星移」(Portal Combat)
##
## 原版口径（../PvZ-Portable-main/src/Lawn/Challenge.cpp 与 GridItem.cpp，
## 交叉验证 ../re-plants-vs-zombies-main/Lawn/ 同名函数）：
##   · 全场 4 扇门，两对：方形一对、圆形一对；**配对 = 同类型的另一扇**（不是按位置配对）
##   · 门站在格子坐标上（列 grid_x / 行 lane）；换位 = 一扇门淡出消失 + 另一扇在新格淡入出现
##   · 传送判定有三套 x 基准（僵尸 / 子弹 / 推车各一套），**别统一成一套**（见 PortalManager）
##   · 绘制锚点（GridItem::OpenPortal）：圆门 (格中心-46, 行地面-65)、方门 (格中心-50, 行地面-40)
##
## 本节点只管「长什么样 + 自己站在哪」；摆门、换位、传送判定都在 PortalManager。

## 传送门外观（方形 = 黄门，圆形 = 蓝门；两扇同型为一对）
enum E_PortalType {
	Square,	## 方形门
	Circle,	## 圆形门
}

## 传送门类型（PortalManager 摆门时赋值）
var portal_type: E_PortalType = E_PortalType.Square
## 所在列（原版 gridX，0 起；本仓地图 9 列，第 10 列 = 草坪右缘的「虚拟列」）
var grid_x := -1
## 所在行（原版 gridY，0 起 = 最上面一行）
var lane := -1
## 门是否处于「打开」状态（原版 IsOpenPortal：关着的门不参与判定、也不占候选格）
var is_open := false

## 门的像素高（贴图分辨率不一，统一按目标高度归一，不用逐张调 scale）
const DOOR_HEIGHT := 120.0
## 绘制锚点相对「格中心 / 行地面」的偏移
## （原版 GridItem::OpenPortal：圆门 x = gridX*80-6、y = 行地面-65；方门再 -4 / +25）
const CIRCLE_DRAW_OFFSET := Vector2(-46.0, -65.0)
const SQUARE_DRAW_OFFSET := Vector2(-50.0, -40.0)

var TEX_SQUARE_CENTER: Texture2D = AssetRegistry.get_texture("res://pak/reanim/Portal_Square_center.png")
var TEX_SQUARE_GLOW: Texture2D = AssetRegistry.get_texture("res://pak/reanim/Portal_Square_glow.png")
var TEX_CIRCLE_OUTER: Texture2D = AssetRegistry.get_texture("res://pak/reanim/Portal_Circle_outer.png")
var TEX_CIRCLE_CENTER: Texture2D = AssetRegistry.get_texture("res://pak/reanim/Portal_Circle_center.png")
var TEX_CIRCLE_GLOW: Texture2D = AssetRegistry.get_texture("res://pak/reanim/Portal_Circle_glow.png")

var _glow: Sprite2D
var _frame: Sprite2D
## 淡入淡出 tween（重复调用要先打断上一次，否则两段 tween 抢透明度）
var _fade_tween: Tween


## 摆门：定类型、列、行，并按类型组装门面（重复调用会先清掉旧门面）
func init_portal(new_type: E_PortalType, new_grid_x: int, new_lane: int) -> void:
	portal_type = new_type
	grid_x = new_grid_x
	lane = new_lane
	_build_visuals()


## 绘制锚点相对「格中心 / 行地面」的偏移
func get_draw_offset() -> Vector2:
	return CIRCLE_DRAW_OFFSET if portal_type == E_PortalType.Circle else SQUARE_DRAW_OFFSET


## 打开门：淡入（原版 OpenPortal：播 anim_appear + 放传送门音效）
func open_portal() -> void:
	is_open = true
	modulate.a = 0.0
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.3)


## 关门：淡出后销毁自己（原版 ClosePortal：播 anim_disappear，动画播完 GridItemDie）
func close_portal() -> void:
	is_open = false
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_fade_tween.tween_callback(queue_free)


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()


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
