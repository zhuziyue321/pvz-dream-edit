extends RefCounted
class_name PaperPlantLook
## 「我是僵尸」模式的**纸板植物外观**
##
## 原版 `Challenge::IZombieDrawPlant`（`../PvZ-Portable-main/src/Lawn/Challenge.cpp:4505`）
## 用**同一个 reanim 画 4 遍**造出纸板质感：
##   1. 白滤镜（`FILTER_EFFECT_WHITE`）+ 偏移 (+4,+4) + 深棕 (122, 86, 58)
##   2. 白滤镜 + 偏移 (+2,+2) + 中棕 (171, 135, 107)
##   3. 白滤镜 + 偏移 (-2,-2) + 中棕 (171, 135, 107)
##   4. 无滤镜 + 原位 + 淡肤色 (255, 201, 160)
## 也就是「纯色剪影 × 3 层错位描边 + 一层淡色本体」
## （原版的 `SetColorizeImages` + `SetColor` 就是「把剪影染成这个颜色」）。
##
## 仓库侧照这个思路实现：
##   · 描边层 = 把 Body 的视觉子树复制 3 份，各挂「纯色剪影」材质 + 各自偏移；
##   · 本体层 = Body 挂「淡色本体」材质（颜色写在材质参数里，不与 body.modulate 打架）。
##
## ⚠️ **副本要每帧跟着本体同步姿势**：原版 `IZombieSetupPlant` 只把 idle 的
## animRate 置 0，攻击动画照播（`Plant::Fire()` → `PlayBodyReanim` 会设回速率）；
## 且四遍绘制在 `Plant::Draw` 里**每帧**执行（`Plant.cpp:4028`）——
## 所以描边要跟着当前姿势动，不能只复制一次就完事。
## 这里用一个挂在角色下的轻量同步节点，每帧把贴图节点的变换/显隐/帧号抄给三层副本
## （idle 冻住时同步是空转，攻击动画期间描边跟着本体一起动，与原版一致）。
##
## ⚠️ 描边层画在本体**下面**（z_index 更小），层级顺序与原版的四遍绘制顺序一致：
## 深棕(+4,+4) 最底 → 中棕(+2,+2) → 中棕(-2,-2) → 本体最上。
## 三层 z_index 相同，靠**加入顺序**决定谁盖谁（先加的在下）。
##
## ⚠️ **颜色口径**：下面的常量按原版的 0~255 写（方便对着原版源码核对），
##   但 Godot 的 `Color` 构造**不归一化** —— `Color(255, 201, 160)` 的分量就是 255/201/160，
##   直接塞给 shader 会被 clamp 成纯白（画面上纸板全白，2026-10-24 实测踩过）。
##   所以传给 uniform 前一律除 255（见 `_set_paper_material`）。

const PAPER_SHADER := preload("res://shaders/my_shader/paper_plant.gdshader")

## 描边层节点名前缀（后面带序号，**不能同名** ——
## 同名节点被加进同一父节点时 Godot 会自动改名（`PaperPlantOutline2`），
## 按固定名字找层就只会找到 1 层）
const OUTLINE_NAME_PREFIX := "PaperPlantOutline"

## 原版的三层描边：偏移 + 颜色（顺序 = 绘制顺序，先画的在下）
const OUTLINE_LAYERS: Array[Dictionary] = [
	{"offset": Vector2(4, 4), "color": Color(122, 86, 58)},
	{"offset": Vector2(2, 2), "color": Color(171, 135, 107)},
	{"offset": Vector2(-2, -2), "color": Color(171, 135, 107)},
]
## 原版本体层的淡肤色（第 4 遍的颜色）
const BODY_TINT := Color(255, 201, 160)


## 给一株纸板植物套上纸板外观
##
## [param plant] 要改造的角色（僵尸模式里的纸板植物）
static func apply(plant: Character000Base) -> void:
	if plant == null or not is_instance_valid(plant):
		return
	var body: BodyCharacter = plant.body
	if body == null or not is_instance_valid(body):
		return
	## 本体层：原图 × 淡肤色
	_set_paper_material(body, BODY_TINT, false)
	## 描边层：三份错位的纯色剪影（挂在角色根节点下，与本体同一个坐标系）+
	## 每帧把本体的姿势抄给副本（原版四遍绘制每帧执行，见类头注释）
	var sync := OutlineSync.new()
	sync.name = "PaperPlantSync"
	for i in range(OUTLINE_LAYERS.size()):
		var layer: Dictionary = OUTLINE_LAYERS[i]
		var outline := _make_outline_layer(body, layer["offset"], layer["color"], i)
		if outline != null:
			plant.add_child(outline)
			sync.add_layer(body, outline, layer["offset"])
	plant.add_child(sync)


## 造一层描边：复制 Body 的视觉子树，套上纯色剪影材质并整体偏移
##
## [param index] 层序号（进名字里，避免同名节点被 Godot 自动改名）
static func _make_outline_layer(body: BodyCharacter, offset: Vector2, color: Color, index: int) -> Node2D:
	var outline := body.duplicate() as Node2D
	if outline == null:
		return null
	outline.name = "%s%d" % [OUTLINE_NAME_PREFIX, index]
	outline.position = body.position + offset
	## 描边层画在本体下面
	outline.z_index = body.z_index - 1
	## 副本不继承本体的着色（受击发白 / 冰冻染色那些 modulate）
	outline.modulate = Color(1, 1, 1, 1)
	## ⚠️ 副本的 owner 必须清掉：Body 在角色场景里是 `%Body`（unique_name_in_owner），
	##   带着原 owner 进树会跟原节点抢同一个「唯一名」，引擎刷 ERROR。
	_clear_owner(outline)
	## 纯色剪影材质（描边色写在参数里）
	_set_paper_material(outline, color, true)
	return outline


## 清掉整棵子树节点的 owner（副本是纯表现节点，不需要属于任何场景）
static func _clear_owner(node: Node) -> void:
	if node.owner != null:
		node.owner = null
	for child in node.get_children():
		_clear_owner(child)


## 给一个 Body（或它的副本）挂纸板材质，并让下面所有贴图节点都用它
##
## ⚠️ **材质必须直接挂在每个贴图节点上**，不能靠「用父节点材质」（`use_parent_material`）：
##   Godot 的父材质查找**只往上找一层**（直接父 CanvasItem 自己的 `material`），
##   夹在中间的 `BodyCorrect` 自己没材质 → 链就断了，贴图照样是原色
##   （2026-10-24 实测：只给 Body 挂材质 + 全链开 use_parent_material，渲染完全没变化）。
##   贴图节点共用**同一个** ShaderMaterial 实例（材质是资源，可以共享）。
static func _set_paper_material(node: Node2D, tint: Color, silhouette: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	var material := ShaderMaterial.new()
	material.shader = PAPER_SHADER
	## ★ **颜色要除 255**：Godot 的 `Color(255, 201, 160)` 分量就是 255/201/160（构造不归一化），
	##   直接塞进 uniform 会被 clamp 成纯白 —— 画面上纸板全是白的（2026-10-24 实测踩过）。
	material.set_shader_parameter("paper_tint", tint / 255.0)
	material.set_shader_parameter("silhouette", silhouette)
	## 节点本身也挂一份（本体层那个节点没有贴图，挂不挂都不影响画面；语义上保持一致）
	node.material = material
	for sprite: Node in _collect_sprites(node):
		var canvas_item := sprite as CanvasItem
		if canvas_item == null:
			continue
		canvas_item.material = material
		canvas_item.use_parent_material = false


## 收集 Body 下面所有贴图节点（只收会画图的两种，别的节点类型不动）
static func _collect_sprites(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			result.append(child)
		result.append_array(_collect_sprites(child))
	return result


## 描边层姿势同步：每帧把 Body 的姿势抄给三层副本
##
## ⚠️ 配对在 [method PaperPlantLook.apply] 时建立（副本是 `body.duplicate()`，
## 当时结构与本体完全一致），之后本体子树再动态加的节点不会被镜像 —— 表现上可忽略。
## ⚠️ 只抄「形状」相关的属性；**不抄 modulate / self_modulate**：
## 副本有自己的纯色剪影材质，受击闪白那些染色只属于本体。
class OutlineSync extends Node:
	## 每层一条：layer = 副本根，offset = 本层的错位偏移，pairs = [本体节点, 副本节点] 配对
	var _layers: Array[Dictionary] = []

	## 注册一层副本（建配对，之后每帧同步）
	func add_layer(body: Node2D, layer: Node2D, offset: Vector2) -> void:
		_layers.append({"body": body, "layer": layer, "offset": offset, "pairs": _build_pairs(body, layer)})

	func _process(_delta: float) -> void:
		for entry in _layers:
			var body: Node2D = entry["body"]
			var layer: Node2D = entry["layer"]
			if body == null or not is_instance_valid(body):
				continue
			if layer == null or not is_instance_valid(layer):
				continue
			## 根节点 = 本体位置 + 本层错位（副本挂在本体同一个坐标系里）
			layer.position = body.position + (entry["offset"] as Vector2)
			layer.rotation = body.rotation
			layer.scale = body.scale
			for pair: Array in entry["pairs"]:
				_sync_shape(pair[0], pair[1])

	## 建配对：副本是本体的 duplicate，子树结构当时一致，按下标平行走一遍
	func _build_pairs(body: Node2D, layer: Node2D) -> Array:
		var result: Array = []
		_collect_pairs(body, layer, result)
		return result

	func _collect_pairs(src: Node, dst: Node, result: Array) -> void:
		var src_children := src.get_children()
		var dst_children := dst.get_children()
		for i in range(mini(src_children.size(), dst_children.size())):
			result.append([src_children[i], dst_children[i]])
			_collect_pairs(src_children[i], dst_children[i], result)

	## 抄会影响剪影形状的属性（变换 / 显隐 / 贴图 / 帧号）
	func _sync_shape(src: Node, dst: Node) -> void:
		if src is Node2D and dst is Node2D:
			dst.position = (src as Node2D).position
			dst.rotation = (src as Node2D).rotation
			dst.scale = (src as Node2D).scale
		if src is CanvasItem and dst is CanvasItem:
			dst.visible = (src as CanvasItem).visible
		if src is Sprite2D and dst is Sprite2D:
			dst.texture = (src as Sprite2D).texture
			dst.offset = (src as Sprite2D).offset
			dst.centered = (src as Sprite2D).centered
			dst.flip_h = (src as Sprite2D).flip_h
			dst.flip_v = (src as Sprite2D).flip_v
		if src is AnimatedSprite2D and dst is AnimatedSprite2D:
			dst.animation = (src as AnimatedSprite2D).animation
			dst.frame = (src as AnimatedSprite2D).frame
