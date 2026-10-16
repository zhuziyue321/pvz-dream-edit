extends Node
## 模组「招笑版」：挂在**每一株朝阳葵（原向日葵）**身上的观察者 —— 由入口脚本
## `zhaoxiao_mod.gd` 在**每一局主游戏**里现挂（本体场景里没有这个节点）。
##
## 它管两件事：
##   1. **自己产阳光时张嘴**：盯着宿主的 `CreateSunComponent/CreateSunTimer`，
##      一到时间就喊一嗓子（`on_sun_produced()`），让场上**其它**朝阳葵转头看过来，
##      自己则开始流汗（就是在花心上挂一颗汗滴贴图，**不做动画**）；
##   2. **被别的朝阳葵叫到时转头**：见 `look_at_point()`。
##
## ★ 只转头（花茎和叶子不动）：
##   向日葵场景里的「花头」是花瓣（`SunFlower_*`）+ 脸（`Anim_*`）那几张贴图，
##   「花茎」是 `Backleaf*` / `Stalk_*` / `Frontleaf*`。**只有前者转**。
##   为什么不是直接转某个节点：那几张贴图的 `position / rotation / scale / skew`
##   全被 `AnimationTree` 的待机动画**逐帧写回**，插一个父节点又会让动画的轨道路径断掉。
##   所以这里是**逐帧**把姿态改在动画结果之上：`_process()` 排在 `AnimationTree` 之后跑
##   （`process_priority` 抬高 + 后挂的节点本来就在树序后面），每帧拿动画刚写好的原始姿态
##   再绕花心转一次。
##
## ★ 转头口径（照需求原文）：目标在**左边**就把花头**镜像**过去，再旋转到「右侧对准目标」
##   —— 镜像让「右侧」成了朝向目标的那一侧，旋转量就是目标角度（镜像时取目标角度 + π，
##   归一化后仍是个小角，不会把花转成倒栽葱）。
##   **所有朝阳葵转一次头花的时间都一样**（`Settings.TURN_TIME`）：这一段是按时长插值的，
##   不是按角速度 —— 角速度下「要转的角度大」的（离得远的）那株会转得更久。
##   镜像也是在这段时长里翻过去的（`_head_mirror` 从 +1 插到 -1，中间花头被压扁一下），
##   所以「只翻不转」的那株也不会一帧就闪过去。
##
## ★ 转头与流汗都是**持续**的：转到目标方向就停在那儿，汗滴贴上就一直挂着 ——
##   直到**下一株**朝阳葵产阳光时，全体改看新的那株（旧的停止流汗）。
##
## ★ 只管战斗里的向日葵：禅境花园 / 图鉴那份虽然也是同一只植物，但它们不是主游戏，
##   本模组的入口只在 `install_to_main_game()` 里挂观察者，所以那边一株都不会挂上。
##
## ⚠️ 本类是普通 `Node`（不是 `Character000Base` / `ComponentNormBase` 的子类），
##    `_ready()` 按 Godot 常态写即可 —— 硬约束 §1-3 只管那两类角色 / 组件。

const Settings := preload("zhaoxiao_settings.gd")

## 场上所有观察者共用一个组名：谁产了阳光就遍历这个组广播一次
const GROUP := &"zhaoxiao_sunflower"
## 观察者节点的名字（入口脚本按它判「这株挂过没有」）
const NODE_NAME := &"ChaoyangWatcher"
## 同一个名字的 NodePath 形态（`get_node_or_null()` 只收 NodePath，写清楚少一层转换）
const NODE_PATH := ^"ChaoyangWatcher"
## 汗滴 sprite 的名字（探针按它找那颗汗）
const SWEAT_NAME := &"ChaoyangSweat"
## 汗滴贴图：**直接借用本体禅境花园那颗「缺水」水珠**（原版素材，不是本模组新增的）
const SWEAT_TEXTURE := preload("res://assets/image/garden/waterdrop.png")

## 花头贴图的名字前缀：花瓣 `SunFlower_leftpetal8` / `SunFlower_toppetals` …、脸 `Anim_idle` / `Anim_blink`
const HEAD_PREFIX_PETAL := "SunFlower_"
const HEAD_PREFIX_FACE := "Anim_"

## 宿主（那株朝阳葵）
var _plant: Plant000Base
## 宿主的身体节点（整株，本模组**不转**它；只用来做「整株没被碰过」的参照）
var _body: BodyCharacter
## 花头贴图的父节点：花茎与叶子也挂在它下面，所以按贴图名字挑出花头那几张贴图
var _head_parent: Node2D
## 花头贴图（花瓣 + 脸）
var _head_sprites: Array[Sprite2D] = []
## 上一帧**我们写进去**的姿态：拿它判「动画这一帧有没有重写这块贴图」
var _applied: Array[Transform2D] = []
## 花心（花瓣围出来的那个圆心）在 `BodyCorrect` 坐标里的位置 —— 转轴与汗滴落点都以它为准
var _pivot := Vector2.ZERO

## 花头当前转了多少（弧度，目标方向为正）
var _head_angle := 0.0
## 花头这次要转到多少
var _head_target_angle := 0.0
## 花头当前的镜像系数：+1 = 没镜像、-1 = 镜像过去了，中间值是翻转途中（花头横向被压扁）
var _head_mirror := 1.0
## 花头这次要镜像到多少（目标在左边 = -1）
var _head_target_mirror := 1.0
## 这一段转头从哪开始的（用它插值到 `_head_target_*`，**固定花 `Settings.TURN_TIME`**）
var _turn_from_angle := 0.0
var _turn_from_mirror := 1.0
## 这一段转头已经走了多久 / 正在不在转
var _turn_elapsed := 0.0
var _is_turning := false
## 当前挂着的那颗汗滴
var _sweat: Sprite2D


func _ready() -> void:
	_plant = get_parent() as Plant000Base
	if _plant == null:
		Log.error("招笑版模组：观察者的父节点不是植物，本株不参与")
		return
	_body = _plant.body
	_head_parent = _plant.get_node_or_null(^"Body/BodyCorrect") as Node2D
	_collect_head_sprites()
	_connect_create_sun_timer()
	add_to_group(GROUP)
	## 本节点要**逐帧**在动画结果之上改姿态：必须排在 `AnimationTree` 之后跑。
	## 同一优先级下按树序（观察者是后挂的，本来就在后面），这里再抬一档保险。
	process_priority = 100
	set_process(true)


#region 自己产阳光
## 盯着产光计时器：一到时间就广播
##
## 为什么不接 `CreateSunComponent.create_sun()`：那是组件自己的方法，本体不给模组插钩子；
## `CreateSunTimer.timeout` 是现成的信号，且场景里的 `_on_create_sun_timer_timeout` 先连、
## 本观察者后连 —— 本回调跑到时组件已经重新排好了下一次的间隔，互不干扰。
func _connect_create_sun_timer() -> void:
	var create_sun: Node = _plant.get_node_or_null(^"CreateSunComponent")
	if create_sun == null:
		return
	var timer: Timer = create_sun.get_node_or_null(^"CreateSunTimer") as Timer
	if timer == null:
		return
	if not timer.timeout.is_connected(on_sun_produced):
		timer.timeout.connect(on_sun_produced)


## 「我产阳光了」：其余朝阳葵一直转头看我，我自己一直流汗
##
## 公开方法（供计时器连、也供探针直接调）。
func on_sun_produced() -> void:
	if not is_inside_tree() or not is_instance_valid(_plant):
		return
	var face_point := face_global_position()
	for other in get_tree().get_nodes_in_group(GROUP):
		if other == self or not is_instance_valid(other):
			continue
		other.look_at_point(face_point)
		## 焦点换人了：上一株别再挂着那颗汗
		other.stop_sweat()
	## 焦点是我自己：花头摆正（刚才可能在盯着别的产光者），开始持续流汗
	_head_target_angle = 0.0
	_head_target_mirror = 1.0
	_start_turn()
	_start_sweat()


## 花心那个点（没找到花头就退回宿主的位置）—— 转头方向与汗滴落点都以它为准
func face_global_position() -> Vector2:
	if is_instance_valid(_head_parent):
		return _head_parent.to_global(_pivot)
	if is_instance_valid(_plant):
		return _plant.global_position
	return Vector2.ZERO
#endregion


#region 转头
## 花头当前的方向（给探针读）
func get_head_angle() -> float:
	return _head_angle


## 这一段转头走到几成了（0~1；给探针读 —— 所有朝阳葵的时长一样，同一批花进度应当一致）
func get_turn_progress() -> float:
	if not _is_turning:
		return 1.0
	return clampf(_turn_elapsed / Settings.TURN_TIME, 0.0, 1.0)


## 转头看向 [param target_global]：在左边就镜像，然后转到「右侧对准目标」；转到就停住
func look_at_point(target_global: Vector2) -> void:
	if not is_instance_valid(_head_parent) or _head_sprites.is_empty():
		return
	var dir := target_global - face_global_position()
	if dir.length_squared() < 1.0:
		## 目标几乎就贴在脸上，没什么可转的
		return
	var mirrored := dir.x < 0.0
	_head_target_mirror = -1.0 if mirrored else 1.0
	## 镜像后本地 +X 的世界朝向 = -X 转过 rotation（Godot 的变换是先缩放后旋转），
	## 令它等于目标方向 → 镜像时是「目标角度 + π」；归一化到 (-π, π] 后仍是个小角
	var target_angle := dir.angle() + (PI if mirrored else 0.0)
	_head_target_angle = wrapf(target_angle, -PI, PI)
	_start_turn()


## 起一段转头：**所有朝阳葵都用同一个固定时长**（`Settings.TURN_TIME`）从当前姿态走到目标姿态
##
## 为什么不用角速度：角速度下「要转的角度大」的那株（离得远的）会转得更久，
## 同一批被叫到的花就不再是一起转完的。固定时长则必然同时到位。
func _start_turn() -> void:
	if is_equal_approx(_head_angle, _head_target_angle) \
			and is_equal_approx(_head_mirror, _head_target_mirror):
		## 已经在目标姿态上（例如它本来就是产光的那株），不用白跑一段
		return
	_turn_from_angle = _head_angle
	_turn_from_mirror = _head_mirror
	_turn_elapsed = 0.0
	_is_turning = true


## 每帧把花头姿态改在动画结果之上（姿态在中性、也没在转时直接跳过，常态零开销）
func _process(delta: float) -> void:
	if not is_instance_valid(_head_parent) or _head_sprites.is_empty():
		return
	if _is_turning:
		_turn_elapsed += delta
		var progress := clampf(_turn_elapsed / Settings.TURN_TIME, 0.0, 1.0)
		var eased := smoothstep(0.0, 1.0, progress)
		_head_angle = lerpf(_turn_from_angle, _head_target_angle, eased)
		_head_mirror = lerpf(_turn_from_mirror, _head_target_mirror, eased)
		if progress >= 1.0:
			_is_turning = false
	## 转到定了也**不能停手**：动画每帧都会把姿态写回去，只要还没回到中性就得逐帧顶住
	if not _is_turning and is_zero_approx(_head_angle) and is_equal_approx(_head_mirror, 1.0):
		return
	_apply_head_turn()


## 把这一帧动画刚写好的姿态，绕花心转 `_head_angle`（镜像时就先镜像再转）
##
## ⚠️ 动画是**逐帧写回**这些贴图的姿态的，所以这里每帧都要重新算一遍；一旦动画停了
##   （植物睡着了 / 动画被关掉），当前值就等于我们上一帧写进去的值 —— 这时必须**跳过**，
##   否则会在自己刚写的结果上再叠一次，越转越快。
func _apply_head_turn() -> void:
	for i in _head_sprites.size():
		var sprite := _head_sprites[i]
		if not is_instance_valid(sprite):
			continue
		if Transform2D(sprite.rotation, sprite.scale, sprite.skew,
				sprite.position).is_equal_approx(_applied[i]):
			continue
		var raw_position := sprite.position
		var raw_rotation := sprite.rotation
		var raw_scale := sprite.scale
		var raw_skew := sprite.skew
		## `mirror` 是镜像系数：+1 = 不镜像、-1 = 镜像过去、中间值 = 正在翻过去
		## （位置按「花心竖线」翻、旋转与斜切按它缩放、横向缩放按它缩放；过 0 时花头被压扁）
		var mirror := _head_mirror
		var mirrored_position := Vector2(
			_pivot.x + (raw_position.x - _pivot.x) * mirror, raw_position.y)
		sprite.position = _pivot + (mirrored_position - _pivot).rotated(_head_angle)
		sprite.rotation = _head_angle + raw_rotation * mirror
		sprite.scale = Vector2(raw_scale.x * mirror, raw_scale.y)
		sprite.skew = raw_skew * mirror
		_applied[i] = Transform2D(sprite.rotation, sprite.scale, sprite.skew, sprite.position)


## 挑出花头那几张贴图（花瓣 + 脸），顺便算出花心
func _collect_head_sprites() -> void:
	_head_sprites.clear()
	if not is_instance_valid(_head_parent):
		return
	for child in _head_parent.get_children():
		var sprite := child as Sprite2D
		if sprite == null:
			continue
		if _is_head_sprite_name(String(sprite.name)):
			_head_sprites.append(sprite)
	_applied.resize(_head_sprites.size())
	_pivot = _compute_pivot()


## 这张贴图属不属于「花头」——按名字分，别去改场景
## （花茎与叶子是 `Backleaf*` / `Stalk_*` / `Frontleaf*`，一个都不匹配）
func _is_head_sprite_name(node_name: String) -> bool:
	return node_name.begins_with(HEAD_PREFIX_PETAL) or node_name.begins_with(HEAD_PREFIX_FACE)


## 花心 = 各花头贴图**视觉中心**的平均（花瓣是围成一圈排的，平均值就是圈的圆心）
##
## ⚠️ 贴图 `centered = false`，`position` 落在左上角，所以视觉中心要再走半个贴图。
func _compute_pivot() -> Vector2:
	var center := Vector2.ZERO
	var count := 0
	for sprite in _head_sprites:
		if not is_instance_valid(sprite):
			continue
		var size := Vector2.ZERO
		if sprite.texture != null:
			size = Vector2(sprite.texture.get_width(), sprite.texture.get_height())
		center += sprite.position + size * 0.5 * sprite.scale.abs()
		count += 1
	if count == 0:
		return Vector2.ZERO
	return center / float(count)
#endregion


#region 流汗
## 开始**持续**流汗：就是在花心上挂一颗汗滴贴图，**不做任何动画** ——
## 它一直挂在那儿，直到焦点换人（`stop_sweat()`）
func _start_sweat() -> void:
	stop_sweat()
	if not is_instance_valid(_plant):
		return
	var drop := Sprite2D.new()
	drop.name = SWEAT_NAME
	drop.texture = SWEAT_TEXTURE
	drop.scale = Vector2(Settings.SWEAT_SCALE, Settings.SWEAT_SCALE)
	## 挂在宿主根下（不挂 `Body`）：那株自己万一同时在盯着别人、身体被转过，汗也不会跟着歪
	drop.z_index = 1
	_plant.add_child(drop)
	drop.global_position = face_global_position() + Settings.SWEAT_OFFSET
	_sweat = drop


## 别再流汗了（焦点换人时由新的那株调）
##
## ⚠️ 必须**先摘下来再删**：`queue_free()` 要等帧末才真从父节点上移除，而摘掉后同一帧里
## 往往就会挂上新的那颗 —— 名字撞上，引擎会把新的那颗改名（`@ChaoyangSweat@2`），
## 之后按名字就再也找不到汗滴了（`_sweat` 引用还在，所以只错在名字，更难查）。
func stop_sweat() -> void:
	if is_instance_valid(_sweat):
		var parent := _sweat.get_parent()
		if parent != null:
			parent.remove_child(_sweat)
		_sweat.queue_free()
	_sweat = null
#endregion
