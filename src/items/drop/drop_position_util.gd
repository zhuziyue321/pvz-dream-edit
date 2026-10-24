class_name DropPositionUtil
## **掉落位置的收敛工具**：把掉落点收进「玩家看得见、点得着」的范围里
##
## 为什么单开一个文件：这个换算**两头都要用** ——
##   · `DropItemManager`（礼包 / 种子包 / 巧克力，走世界坐标换算）
##   · `DropItemComponent`（僵尸死了掉钱，以前直接拿视口尺寸夹）
## 组件不该去够管理器（硬约束 §1-2），两边共用一份静态工具最省事。
##
## ⚠️ 画布是有偏移的（相机跟随 / 关卡根节点挪过 / 开场那趟展示动画），
## 屏幕左上角**并不对应世界原点**：直接拿视口尺寸去夹，画面右侧那 150 像素里的
## 掉落物会跑到屏幕外面 —— 只能眼看它十几秒后消失。

## 掉落位置留出的边距：礼包的点击区约 80x80，夹在最边上会有一半身在画面外、点不中
const DROP_EDGE_MARGIN := 40.0
## 掉落点整体上抬的像素：僵尸死亡处偏下，抬一点才落在它脚边
const DROP_Y_LIFT := 50.0


## 当前视口能看见的那块**世界**矩形（掉落物用的是世界坐标，必须换算回去再夹）
## 没有画布偏移时它等于视口矩形，与直接按视口尺寸夹的结果一致
static func get_viewport_visible_rect(node: Node) -> Rect2:
	if node == null or not is_instance_valid(node):
		return Rect2()
	var viewport := node.get_viewport()
	if viewport == null:
		return Rect2()
	var screen_rect := viewport.get_visible_rect()
	if node is Node2D:
		var to_world: Transform2D = (node as Node2D).get_canvas_transform().affine_inverse()
		var top_left := to_world * screen_rect.position
		var bottom_right := to_world * (screen_rect.position + screen_rect.size)
		return Rect2(top_left, bottom_right - top_left)
	return screen_rect


## 把掉落位置收进看得见的范围内
## [param edge_margin] 掉落物自身半个身位（礼包约 40、巧克力 30、种子包 50），不传就用礼包的
static func clamp_drop_position(node: Node, drop_global_position: Vector2,
		edge_margin := DROP_EDGE_MARGIN) -> Vector2:
	var rect := get_viewport_visible_rect(node).grow(-edge_margin)
	var min_pos := rect.position
	var max_pos := Vector2(maxf(rect.end.x, min_pos.x), maxf(rect.end.y, min_pos.y))
	return Vector2(
		clampf(drop_global_position.x, min_pos.x, max_pos.x),
		clampf(drop_global_position.y - DROP_Y_LIFT, min_pos.y, max_pos.y)
	)
