extends RefCounted
class_name AnimationFrameUtil
## 取「一个动画的某一帧」当图片用的通用工具
##
## 最常见的两种调用：
##   ## 一步拿到图片(内部要离屏渲染,必须 await)
##   var tex := await AnimationFrameUtil.create_frame_texture(
##       preload("res://src/items/lawn_mower/pool_cleaner.tscn"),
##       &"PoolCleaner_land_static", 0, Vector2(67, 68), 2.0)
##   $Icon.texture = tex
##
##   ## 只想拿到"定格的形象节点"(不渲染,同步返回)
##   var node := AnimationFrameUtil.create_frame_node(
##       preload("res://src/items/lawn_mower/roof_cleaner.tscn"), &"RoofCleaner", 0)
##   add_child(node)
##
## 实现要点(改这里前先看)：
##   1. 实例化场景后**先剥离脚本** —— 否则角色自带的 _ready / _process 会在离屏容器里跑起来
##      (小推车的 _process 会自己往前开、_ready 会去取视口尺寸)
##   2. AnimationPlayer 只有**入树**才能 seek，所以临时挂一个 SubViewport 当容器
##   3. 定格用 play + seek(time, true) + stop(true)：stop(true) 是保留当前姿态，
##      写成 stop() 会退回第 0 帧(coin.gd / 僵王博士（zombie_boss_001_doctor）里是同一套写法)
##   4. AnimationTree 每帧会覆盖 AnimationPlayer 的姿态，必须在 seek 之前摘掉
##   5. 定格后摘掉播放器 / 碰撞体等非显示节点，剩下一棵纯 Sprite2D 的静态节点树
##   6. 要图片就把这棵树按包围盒等比缩放居中，再离屏渲染成 Texture2D

## 动画没写 step 时的兜底帧率(原版 reanim 是 12fps)
const FALLBACK_STEP := 1.0 / 12.0
## 离屏渲染的默认图片尺寸
const DEFAULT_TEXTURE_SIZE := Vector2(64.0, 64.0)


#region 一步到位
## 取 scene 里 anim_name 动画的第 frame 帧，渲染成一张透明背景的图片
## 内容按包围盒等比缩放并居中到 size 里；margin 是四周留白(像素)
## ⚠️ 内部要等两帧离屏渲染，调用方必须 await(不 await 拿到的会是 null)
## 失败(场景为空 / 找不到动画 / 内容为空)返回 null，不抛错
static func create_frame_texture(scene: PackedScene, anim_name: StringName, frame: int = 0,
		size: Vector2 = DEFAULT_TEXTURE_SIZE, margin: float = 0.0) -> Texture2D:
	var node := create_frame_node(scene, anim_name, frame)
	if node == null:
		return null
	var rect := get_content_rect(node)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		Log.warn("取动画帧失败：内容为空 ", scene.resource_path, " / ", anim_name)
		node.free()
		return null
	var viewport := SubViewport.new()
	viewport.name = "AnimationFrameViewport"
	viewport.size = Vector2i(maxi(1, ceili(size.x)), maxi(1, ceili(size.y)))
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var holder := Node2D.new()
	viewport.add_child(holder)
	holder.add_child(node)
	apply_fit(holder, rect, size, margin)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		Log.error("取动画帧失败：取不到 SceneTree")
		viewport.free()
		return null
	tree.root.add_child(viewport)
	## 等两个整帧再取图：第一帧 viewport 才排进渲染队列，第二帧拿到的才是画好的图
	## 用 process_frame 而不是 RenderingServer.frame_post_draw —— 后者在无头(dummy 渲染)
	## 下根本不触发，会把调用方永久挂住
	await tree.process_frame
	await tree.process_frame
	## 无头(dummy 渲染)下 get_texture() 拿不到东西，这里先判空，别把调用方的日志打脏
	var viewport_texture := viewport.get_texture()
	var image: Image = viewport_texture.get_image() if viewport_texture != null else null
	viewport.queue_free()
	if image == null or image.is_empty():
		Log.warn("取动画帧失败：离屏渲染没画出东西 ", scene.resource_path, " / ", anim_name)
		return null
	return ImageTexture.create_from_image(image)


## 取 scene 里 anim_name 动画的第 frame 帧，返回一个「冻结在该帧」的静态形象节点
## 已剥离脚本与 AnimationPlayer / AnimationTree / 碰撞体等纯逻辑节点，
## 可以直接 add_child 到任意 2D / UI 场景里当装饰用(它不再有任何行为)
## ⚠️ 返回的节点没有父节点，调用方要么挂进场景树、要么自己 free() 掉
static func create_frame_node(scene: PackedScene, anim_name: StringName, frame: int = 0) -> Node2D:
	if scene == null:
		Log.warn("取动画帧失败：场景为空")
		return null
	var inst := scene.instantiate()
	if not (inst is Node2D):
		Log.warn("取动画帧失败：场景根节点不是 Node2D ", scene.resource_path)
		if inst != null:
			inst.free()
		return null
	detach_scripts(inst)
	var viewport := SubViewport.new()
	viewport.name = "AnimationFrameHolder"
	viewport.size = Vector2i(2, 2)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		Log.error("取动画帧失败：取不到 SceneTree")
		inst.free()
		return null
	tree.root.add_child(viewport)
	viewport.add_child(inst)
	## AnimationTree 会每帧覆盖姿态，定格前先摘掉；碰撞体留着也没用，一起摘
	strip_nodes(inst, _is_pose_blocker)
	if not seek_frame(inst, anim_name, frame):
		Log.warn("取动画帧失败：找不到动画 ", anim_name, " @ ", scene.resource_path)
	## 定格完成，播放器与其余看不见的杂节点一起摘掉，只留能画出来的部分
	strip_nodes(inst, _is_not_drawable)
	viewport.remove_child(inst)
	viewport.queue_free()
	return inst


## 取一帧并包一层「已按 target 缩放居中」的 Node2D，直接 add_child 到 UI 里即可
## 挂上去之后，内容会落在父节点原点开始的 target 这块矩形里
static func create_frame_icon(scene: PackedScene, anim_name: StringName, frame: int = 0,
		target: Vector2 = DEFAULT_TEXTURE_SIZE, margin: float = 0.0) -> Node2D:
	var node := create_frame_node(scene, anim_name, frame)
	if node == null:
		return null
	var holder := Node2D.new()
	holder.name = "AnimationFrameIcon"
	holder.add_child(node)
	apply_fit(holder, get_content_rect(node), target, margin)
	return holder
#endregion


#region 拆开用的零件
## 帧号换算成秒(按动画自己的 step，step 没写就按 12fps 兜底)
static func frame_to_time(anim: Animation, frame: int) -> float:
	var step: float = anim.step if anim.step > 0.0 else FALLBACK_STEP
	return maxf(0.0, float(frame) * step)


## 把**已经入树**的 inst 定格到 anim_name 动画的第 frame 帧
static func seek_frame(inst: Node, anim_name: StringName, frame: int = 0) -> bool:
	var player := find_animation_player(inst)
	if player == null:
		return false
	if not player.has_animation(anim_name):
		return false
	var anim := player.get_animation(anim_name)
	player.play(anim_name)
	player.seek(frame_to_time(anim, frame), true)
	player.stop(true)
	return true


## 找场景里的 AnimationPlayer：先直属子节点，再往深里找
static func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		if child is AnimationPlayer:
			return child
	for child in root.get_children():
		var found := find_animation_player(child)
		if found != null:
			return found
	return null


## 递归摘掉脚本，避免离屏容器里跑起角色自带逻辑
static func detach_scripts(root: Node) -> void:
	if root.get_script() != null:
		root.set_script(null)
	for child in root.get_children():
		detach_scripts(child)


## 删掉 root 下所有满足 predicate 的后代节点(整棵子树一起删，root 自身不删)
static func strip_nodes(root: Node, predicate: Callable) -> void:
	var doomed: Array[Node] = []
	_collect_strip(root, predicate, doomed)
	for n in doomed:
		if is_instance_valid(n) and n.get_parent() != null:
			n.get_parent().remove_child(n)
			n.free()


## 求 root 这棵节点树里所有可见贴图的包围盒(局部坐标，相对 root 原点)
static func get_content_rect(root: Node2D) -> Rect2:
	return _collect_rect(root, Transform2D.IDENTITY)


## 把内容 rect 等比缩放居中到 target 这块区域里，写进 holder 的 scale / position
## holder 必须是内容的直接父节点，且自身变换是单位变换
static func apply_fit(holder: Node2D, rect: Rect2, target: Vector2, margin: float = 0.0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var inner: Vector2 = target - Vector2(margin, margin) * 2.0
	if inner.x <= 0.0 or inner.y <= 0.0:
		return
	var scale_rate: float = minf(inner.x / rect.size.x, inner.y / rect.size.y)
	holder.scale = Vector2(scale_rate, scale_rate)
	holder.position = -rect.position * scale_rate + (target - rect.size * scale_rate) * 0.5
#endregion


#region 内部
## 定格前要摘掉的：会覆盖姿态的 AnimationTree + 用不上的碰撞体 / 计时器
static func _is_pose_blocker(n: Node) -> bool:
	return n is AnimationTree or n is CollisionObject2D or n is Timer


## 定格后要摘掉的：上面那些 + 播放器 + 任何画不出来的节点(只剩能显示的 CanvasItem)
static func _is_not_drawable(n: Node) -> bool:
	return n is AnimationPlayer or _is_pose_blocker(n) or not (n is CanvasItem)


static func _collect_strip(node: Node, predicate: Callable, out: Array[Node]) -> void:
	for child in node.get_children():
		if predicate.call(child):
			out.append(child)
		else:
			_collect_strip(child, predicate, out)


## 递归累加包围盒：不可见的整棵子树都跳过，Sprite2D 按自身矩形贡献面积
static func _collect_rect(node: Node2D, parent_transform: Transform2D) -> Rect2:
	if not node.visible:
		return Rect2()
	var transform: Transform2D = parent_transform * node.transform
	var result := Rect2()
	for child in node.get_children():
		if child is Node2D:
			result = result.merge(_collect_rect(child, transform))
	if node is Sprite2D and node.texture != null:
		result = result.merge(_transform_rect(node.get_rect(), transform))
	return result


## 矩形四角过一遍变换再取轴对齐包围盒(有 rotation 的部件也算得进去)
static func _transform_rect(rect: Rect2, transform: Transform2D) -> Rect2:
	var result := Rect2(transform * rect.position, Vector2.ZERO)
	result = result.expand(transform * (rect.position + Vector2(rect.size.x, 0.0)))
	result = result.expand(transform * (rect.position + Vector2(0.0, rect.size.y)))
	result = result.expand(transform * rect.end)
	return result
#endregion
