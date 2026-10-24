extends CanvasLayer
class_name CanvasLayerWhiteScreen
## 通关掉落物被点开后的「收尾表演」：居中 -> 发光 -> 关卡淡出
##
## 表演分三段依次进行：
##   1. 掉落物本体被 Tween 缓缓移到屏幕中央，同时**放大**（原版口径：1.01 -> 2.0）
##   2. 屏幕中央亮起辉光、光芒旋转展开 —— 也就是「发光」
##   3. 全屏矩形 alpha 0 -> 1 —— 也就是原版的**关卡淡出**
##      （`Board::DrawFadeOut`：一层全屏填充，200 帧走完；冒险 1-9 / 2-9 / 3-9 / 4-9 / 5-9
##        淡成黑色，其余淡成白色，见 PvZ-Portable src/Lawn/Board.cpp:7094-7109）
##
## 另外还管一件小事：**战利品掉出来时屏幕中央闪一下**（原版 PARTICLE_SCREEN_FLASH，
## 见 PvZ-Portable src/Lawn/Challenge.cpp:2017）—— 订阅 EventBus "level_complete_loot_spawned"。
##
## 图层怎么排（跨画布层时 z_index 不起作用，只有 layer 值和树序说了算）：
##   - 本层 layer = 100：只负责最后那张全屏白矩形，盖住所有 UI，UI 才不会被画面切走前漏出来
##   - 发光组 %PickupAwardLight 挂在 CanvasLayerDropItem（layer 6，跟掉落物同一层）里，
##     排在所有掉落容器之前：同层同级靠树序定先后，掉落物本体就画在光之上，本体才不会被光糊掉
##     （参照 present.tscn：PickUpGlow 排在 TextureButton 之前，掉落物本主体在光之上）
##   - 也因此它跟掉落物处在同一个世界坐标系（follow_viewport），位置按世界坐标摆
##   - 白的层级最高，发光在自己层里亮完整段，最后才被白吃掉
##
## 触发：EventBus "level_complete_pickup"，payload = [掉落物节点]
##   只有「本关结算线」上的掉落物才会推 —— 见 Present / SeedPacket 的 is_level_complete_drop，
##   普通金币 / 花园礼包 / 关卡解锁道具仍走各自的拾取表现
## 结束：EventBus "level_complete_pickup_finished"
##   MgmRewardManager 收到后才切场景，保证切场景那一帧画面是全白的；
##   掉落物在白屏到底时被本层释放（被光收走），调用方不要再自己 queue_free

## 掉落物移到屏幕中央的秒数（原版 350 帧 ≈ 5.8 秒，这里按本仓库的节奏压缩）
const MOVE_TIME := 1.6
## 飞到屏幕中心时放大到的倍率（原版 1.01 -> 2.0，见 PvZ-Portable Coin.cpp:661）
const MOVE_SCALE := 2.0
## 放大这一段的秒数（原版 400 帧，比移动那 350 帧长一点）
const SCALE_TIME := 2.0
## 辉光渐强、光芒展开的秒数
const GLOW_TIME := 1.6
## 辉光的最大不透明度
const GLOW_MAX_ALPHA := 0.85
## 辉光的起始 / 结束缩放（AwardGlow 只有 32x32，撑满屏幕靠倍率，参考本层 %PickupAwardLight/Glow）
const GLOW_START_SCALE := 20.0
const GLOW_END_SCALE := 120.0
## 光芒展开后的缩放倍率
const RAYS_SCALE := 3.0
## 白屏渐变到全白的秒数
## 原版：关卡淡出是 `Board::DrawFadeOut` 的一层全屏填充，alpha 从 0 走到 255 用 200 帧
## （PvZ-Portable src/Lawn/Board.cpp:7094-7109），本仓库照这个时长
const WHITE_TIME := 200.0 / 60.0
## 全白后再停留的秒数，让画面咬住白色、收到结算通知再切场景
const WHITE_HOLD_TIME := 0.2
## 战利品掉出来时全屏闪光的秒数（原版 ScreenFlash.xml：粒子寿命 50 帧）
const SPAWN_FLASH_TIME := 50.0 / 60.0
## 全屏闪光的起始不透明度（原版 ParticleAlpha .5）
const SPAWN_FLASH_ALPHA := 0.5
## 原版这几关淡出时是**黑色**、其余是白色
## （原版 `mLevel == 9 || 19 || 29 || 39 || 49`，即冒险 1-9 / 2-9 / 3-9 / 4-9 / 5-9，
##  见 PvZ-Portable src/Lawn/Board.cpp:7100）
const BLACK_FADE_ADVENTURE_LEVELS: Array[int] = [9, 19, 29, 39, 49]

## 白屏：本层自己的全屏白矩形，layer 最高，只有第三阶段会亮
@onready var color_rect_white: ColorRect = $ColorRectWhite
## 发光组：挂在掉落物同一层（CanvasLayerDropItem），本体在它之上绘制（见文件头的图层说明）
@onready var award_light: Node2D = $"%PickupAwardLight"
@onready var glow: Sprite2D = _light_child("Glow")
@onready var all_rays: Node2D = _light_child("AllRays")

## 光芒的初始摆放（初始旋转 / 缩放写在场景里），每段表演开始前复位回它
var _all_ray_init_transform: Array[Transform2D] = []
## 掉出来那一下的全屏闪光 tween（跟白屏共用同一张白矩形，别让两条 tween 抢 alpha）
var _spawn_flash_tween: Tween = null


func _ready() -> void:
	for ray in all_rays.get_children():
		_all_ray_init_transform.append(ray.transform)
	visible = false
	EventBus.subscribe(ConstEventName.LEVEL_COMPLETE_PICKUP, play_pickup)
	## 战利品掉出来时的屏幕闪光（原版 PARTICLE_SCREEN_FLASH）
	EventBus.subscribe(ConstEventName.LEVEL_COMPLETE_LOOT_SPAWNED, play_spawn_flash)


## 发光组里的子节点（不走绝对路径，从 %PickupAwardLight 往下取，免得跟别的层重名）
func _light_child(child_name: String) -> Node2D:
	var child := award_light.get_node_or_null(child_name) as Node2D
	if child == null:
		Log.error("发光组缺少子节点：" + child_name)
	return child


## **战利品掉出来时屏幕中央闪一下**（原版 PARTICLE_SCREEN_FLASH）
## 全屏白矩形从 0.5 透明度淡到 0，0.83 秒（原版 50 帧）
func play_spawn_flash() -> void:
	TweenUtil.kill_tween(_spawn_flash_tween)
	visible = true
	color_rect_white.modulate.a = SPAWN_FLASH_ALPHA
	_spawn_flash_tween = create_tween()
	_spawn_flash_tween.tween_property(color_rect_white, "modulate:a", 0.0, SPAWN_FLASH_TIME) \
		.set_trans(Tween.TRANS_LINEAR)
	_spawn_flash_tween.tween_callback(_hide_after_flash)


## 闪光结束：把本层藏回去（白屏那一段会重新点亮它）
func _hide_after_flash() -> void:
	_spawn_flash_tween = null
	visible = false


## 播一次「居中 -> 发光 -> 白屏」，pickup 是被点开的掉落物，播完由本层释放它
func play_pickup(pickup: Node2D) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return
	## 原版：点开关卡奖励 → `Board::FadeOutLevel()` 里先停背景音乐、再播通关音
	## （PvZ-Portable src/Lawn/Board.cpp：冒险 5-10 与金盏花奖播 FOLEY_FINAL_FANFARE，
	##   其余播 FOLEY_WINMUSIC）。本层就是对应原版那一段的「关卡淡出」层。
	_play_level_complete_sfx()
	reset_perform()

	var move_tween := create_tween()
	move_tween.set_parallel()
	## 位置：飞向屏幕中央（原版那条曲线是 EASE_OUT，见 Coin.cpp:662）
	move_tween.tween_property(pickup, "position", get_local_screen_center(pickup), MOVE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	## 缩放：放大到 2.0（原版 1.01 -> 2.0，EASE_IN_OUT，见 Coin.cpp:661）
	move_tween.tween_property(pickup, "scale", pickup.scale * MOVE_SCALE, SCALE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
	EventBus.push_event(ConstEventName.LEVEL_COMPLETE_PICKUP_FINISHED)


## 复位到「还没播」的状态，重打关卡时不会残留上一次的白屏 / 辉光
func reset_perform() -> void:
	## 掉出来那一下的闪光可能还在跑（它跟白屏共用同一张白矩形），先打断
	TweenUtil.kill_tween(_spawn_flash_tween)
	_spawn_flash_tween = null
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
	## 关卡淡出的颜色：原版 9/19/29/39/49 那几关淡成黑色，其余白色
	color_rect_white.color = _get_fade_color()


## 本关淡出该用黑色还是白色（原版：冒险 1-9 / 2-9 / 3-9 / 4-9 / 5-9 淡成黑色）
func _get_fade_color() -> Color:
	var mg := GameContext.curr_main_game
	if mg == null or mg.reward_manager == null:
		return Color(1, 1, 1, 1)
	if BLACK_FADE_ADVENTURE_LEVELS.has(mg.reward_manager.get_curr_adventure_level()):
		return Color(0, 0, 0, 1)
	return Color(1, 1, 1, 1)


## **通关音效**（原版 `Board::FadeOutLevel` 的那一段）
##
## 原版：先 `StopAllMusic()`（把背景音乐停掉，通关音才听得清），再播通关音 ——
## 冒险 5-10 与金盏花奖播 `FOLEY_FINAL_FANFARE`（终章音），其余播 `FOLEY_WINMUSIC`。
## 本仓库没有「金盏花奖」那种奖杯，所以只有 5-10 这一支走终章音。
func _play_level_complete_sfx() -> void:
	## play_bgm(null) 的语义就是「只停掉当前 BGM」（见 SoundManager.play_bgm 的注释）
	SoundManager.play_bgm(null)
	var mg := GameContext.curr_main_game
	var is_final_adventure_level := mg != null and mg.reward_manager != null \
		and mg.reward_manager.get_curr_adventure_level() \
		== ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL
	SoundManager.play_other_SFX("finalfanfare" if is_final_adventure_level else "winmusic")


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
