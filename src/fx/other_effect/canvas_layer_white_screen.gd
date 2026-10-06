extends CanvasLayer
class_name CanvasLayerWhiteScreen
## 通关掉落物被点开后的「收尾表演」：居中 -> 发光 -> 白屏
##
## 表演分三段依次进行：
##   1. 掉落物本体被 Tween 缓缓移到屏幕中央，同时略微放大
##   2. 屏幕中央亮起辉光、光芒旋转展开 —— 也就是「发光」
##   3. 全屏白色矩形 alpha 0 -> 1 —— 也就是「屏幕逐渐变白」，完全白了才算收尾
##
## 图层怎么排（跨画布层时 z_index 不起作用，只有 layer 值和树序说了算）：
##   - 本层 layer = 100：只负责最后那张全屏白矩形，盖住所有 UI，UI 才不会被画面切走前漏出来
##   - 发光组 %PickupAwardLight 挂在 CanvasLayerDropItem（layer 6，跟掉落物同一层）里，
##     排在所有掉落容器之前：同层同级靠树序定先后，掉落物本体就画在光之上，本体才不会被光糊掉
##     （参照 trophy.tscn：PickUpGlow / AllRays 排在 TrophyButton 之前，奖杯本主体在光之上）
##   - 也因此它跟掉落物处在同一个世界坐标系（follow_viewport），位置按世界坐标摆
##   - 白的层级最高，发光在自己层里亮完整段，最后才被白吃掉
##
## 触发：EventBus "level_complete_pickup"，payload = [掉落物节点]
##   只有「本关结算线」上的掉落物才会推 —— 见 Present / SeedPacket 的 is_level_complete_drop，
##   普通金币 / 花园礼包 / 关卡解锁道具仍走各自的拾取表现
## 结束：EventBus "level_complete_pickup_finished"
##   MgmRewardManager 收到后才切场景，保证切场景那一帧画面是全白的；
##   掉落物在白屏到底时被本层释放（被光收走），调用方不要再自己 queue_free

## 掉落物移到屏幕中央的秒数
const MOVE_TIME := 1.2
## 移到屏幕中央后的放大倍率（像被光吸过去）
const MOVE_SCALE := 1.25
## 辉光渐强、光芒展开的秒数
const GLOW_TIME := 1.6
## 辉光的最大不透明度
const GLOW_MAX_ALPHA := 0.85
## 辉光的起始 / 结束缩放（AwardGlow 只有 32x32，撑满屏幕靠倍率，参考 trophy.tscn 的 Glow）
const GLOW_START_SCALE := 20.0
const GLOW_END_SCALE := 120.0
## 光芒展开后的缩放倍率
const RAYS_SCALE := 3.0
## 白屏渐变到全白的秒数
const WHITE_TIME := 1.5
## 全白后再停留的秒数，让画面咬住白色、收到结算通知再切场景
const WHITE_HOLD_TIME := 0.2

## 白屏：本层自己的全屏白矩形，layer 最高，只有第三阶段会亮
@onready var color_rect_white: ColorRect = $ColorRectWhite
## 发光组：挂在掉落物同一层（CanvasLayerDropItem），本体在它之上绘制（见文件头的图层说明）
@onready var award_light: Node2D = $"%PickupAwardLight"
@onready var glow: Sprite2D = _light_child("Glow")
@onready var all_rays: Node2D = _light_child("AllRays")

## 光芒的初始摆放（初始旋转 / 缩放写在场景里），每段表演开始前复位回它
var _all_ray_init_transform: Array[Transform2D] = []


func _ready() -> void:
	for ray in all_rays.get_children():
		_all_ray_init_transform.append(ray.transform)
	visible = false
	EventBus.subscribe("level_complete_pickup", play_pickup)


## 发光组里的子节点（不走绝对路径，从 %PickupAwardLight 往下取，免得跟别的层重名）
func _light_child(child_name: String) -> Node2D:
	var child := award_light.get_node_or_null(child_name) as Node2D
	if child == null:
		Log.error("发光组缺少子节点：" + child_name)
	return child


## 播一次「居中 -> 发光 -> 白屏」，pickup 是被点开的掉落物，播完由本层释放它
func play_pickup(pickup: Node2D) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return
	reset_perform()
	Log.debug("通关掉落物收尾表演开始：" + pickup.name)

	var move_tween := create_tween()
	move_tween.set_parallel()
	move_tween.tween_property(pickup, "position", get_local_screen_center(pickup), MOVE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_property(pickup, "scale", pickup.scale * MOVE_SCALE, MOVE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	## 不要用 await finished：表演被掐掉时 Tween.kill() 不发 finished，协程会永久挂起
	## （同样的坑见 CanvasLayerEffect 的注释）
	move_tween.chain().tween_callback(start_glow.bind(pickup))


## 第二段：屏幕中央亮起辉光，光芒一边旋转一边展开
## 光停在屏幕中心（掉落物正好停在这儿），并在掉落物本体之下 —— 见文件头的图层说明
func start_glow(pickup: Node2D) -> void:
	award_light.position = get_local_screen_center(award_light)
	award_light.visible = true
	all_rays.visible = true
	var glow_tween := create_tween()
	glow_tween.set_parallel()
	glow_tween.tween_property(glow, "modulate:a", GLOW_MAX_ALPHA, GLOW_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	glow_tween.tween_property(glow, "scale", Vector2(GLOW_END_SCALE, GLOW_END_SCALE), GLOW_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for ray in all_rays.get_children():
		glow_tween.tween_property(ray, "rotation", ray.rotation + PI, GLOW_TIME) \
			.set_trans(Tween.TRANS_LINEAR)
		glow_tween.tween_property(ray, "scale", ray.scale * RAYS_SCALE, GLOW_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	glow_tween.chain().tween_callback(start_white.bind(pickup))


## 第三段：屏幕逐渐变白，完全白了才算收尾
## 白屏在本层（layer 100）最上面，UI 也会被一起吃掉
func start_white(pickup: Node2D) -> void:
	visible = true
	var white_tween := create_tween()
	white_tween.tween_property(color_rect_white, "modulate:a", 1.0, WHITE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	white_tween.tween_interval(WHITE_HOLD_TIME)
	white_tween.tween_callback(finish_perform.bind(pickup))


## 收尾：掉落物被光收走，通知通关结算（MgmRewardManager 收到后才切场景）
func finish_perform(pickup: Node2D) -> void:
	if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
		pickup.queue_free()
	award_light.visible = false
	Log.debug("通关掉落物收尾表演结束，屏幕已全白")
	EventBus.push_event("level_complete_pickup_finished")


## 复位到「还没播」的状态，重打关卡时不会残留上一次的白屏 / 辉光
func reset_perform() -> void:
	visible = false
	award_light.visible = false
	glow.modulate = Color(1, 1, 1, 0)
	glow.scale = Vector2(GLOW_START_SCALE, GLOW_START_SCALE)
	all_rays.visible = false
	var index := 0
	for ray in all_rays.get_children():
		ray.transform = _all_ray_init_transform[index]
		index += 1
	color_rect_white.modulate = Color(1, 1, 1, 0)


## 屏幕中心换算成目标节点自己的局部坐标
## 掉落物与发光组都挂在 follow_viewport 的 CanvasLayerDropItem 下，坐标是「相机变换之前的世界坐标」，
## 要把屏幕中心反算回去：先用画布变换的逆变换换到世界坐标，再去掉父节点自身的位移
## （与 DropItemManager.get_viewport_visible_rect / get_clamp_drop_position 同一套换算）
func get_local_screen_center(target_node: Node2D) -> Vector2:
	var viewport := target_node.get_viewport()
	var center_world := viewport.get_canvas_transform().affine_inverse() \
		* (viewport.get_visible_rect().size / 2.0)
	var parent_canvas_item := target_node.get_parent() as CanvasItem
	if parent_canvas_item == null:
		return center_world
	return parent_canvas_item.get_global_transform().affine_inverse() * center_world
