extends Node2D
## 模组「招笑版」：一颗**傻豆** —— 傻豆射手普通攻击打出来的那种「豌豆」
##
## ★ 它就是一颗**长得像正常豌豆的贴图**：连 Area2D 都不挂，**没有碰撞箱**，
##   所以哪怕视觉上跟僵尸叠在一起，也**一点伤害都不造成**（需求原文第 6 条）。
##   本体那套子弹（`Bullet000Base`）**不是**它的基类 —— 那套的碰撞框是它的立身之本，
##   这里要的恰好相反，所以整颗豆是本模组自己造的一个纯 `Node2D`。
##
## ★ 两种（需求原文第 5 条），由 `setup()` 抛硬币决定：
##   1. `E_Kind.DropToGround` —— 看着跟正常豌豆一模一样地往前飞，飞到**僵尸前面**
##      （受击框前缘再往前 `SHADOU_FALL_GAP`）就往下掉，**落到本行地面上**，
##      落地那一下原地播一次本体那套「豌豆命中」特效，然后这颗傻豆自己消失；
##      本行前面一只僵尸都没有时，飞 `SHADOU_FALL_DISTANCE` 之后自己掉下来。
##   2. `E_Kind.ShootOff` —— 射偏：方向不是随便偏的，而是算出来**恰好从僵尸受击框边上
##      擦过去**（偏上 = 擦着头顶、偏下 = 贴地从脚底过），所以它永远打不中；
##      前面一只僵尸都没有时才退化成「随便偏一个角度」。飞 `SHADOU_MAX_DISTANCE` 就消失。
##
## ★ 「僵尸受击框」一律**从实例上读**（`HurtBoxComponent/HurtBoxReal` 下那个碰撞形状），
##   不写死尺寸 —— 原版僵尸的受击框各不相同（普僵是竖直胶囊、巨人更高、雪橇车斜着放…）。
##
## ★ 素材是**借本体的那些豌豆素材**（`ProjectilePea.png` / `pea_shadows.png` / 命中特效）
##   —— 「看起来像正常豌豆」正需要它们；与朝阳葵借禅境花园那颗水珠是同一个口径。
##
## ⚠️ 本类是普通 `Node2D`（不是 `Character000Base` / `ComponentNormBase` 的子类），
##    `_ready()` 按 Godot 常态写即可 —— 硬约束 §1-3 只管那两类角色 / 组件。

const Settings := preload("zhaoxiao_settings.gd")

## 傻豆的两种
enum E_Kind {
	DropToGround,	## 看起来像正常豌豆，但飞到僵尸前面会掉到地上
	ShootOff,		## 射偏的（擦着头顶 / 贴着脚底过去，反正打不中）
}

## 场上所有傻豆共用一个组名（探针按它数现在飞着几颗；也给将来的联机同步留个抓手）
const GROUP := &"zhaoxiao_shadou"
## 节点名（**不唯一**：同时可以有好几颗，引擎会自动加 `@N` 后缀，不靠名字找）
const NODE_NAME := &"Shadou"
## 贴图节点名（探针按它找那颗豆）
const SPRITE_NAME := &"ShadouBody"
## 同一个名字的 NodePath 形态（`get_node_or_null()` 只收 NodePath，写清楚少一层转换）
const SPRITE_PATH := ^"ShadouBody"
## 影子贴图节点名
const SHADOW_NAME := &"ShadouShadow"

## 落地那一下播的「豌豆命中」特效共用一个组名（探针按它判有没有播）
const PEA_HIT_GROUP := &"zhaoxiao_pea_hit"
## 借本体特效时临时给它当爹的那个空壳（本体那颗特效要求「自己挂在子弹下面」）
const PEA_HIT_HOLDER_NAME := &"ShadouPeaHitHolder"
## 本体豌豆场景里那颗特效节点 / 那张溅射贴图的名字
const PEA_EFFECT_NAME := ^"BulletEffect"
const PEA_SPLAT_NAME := ^"Splats"

## 豌豆贴图 / 豌豆影子贴图：**直接借本体那两张原版素材**
const PEA_TEXTURE := preload("res://pak/images/ProjectilePea.png")
const PEA_SHADOW_TEXTURE := preload("res://pak/images/pea_shadows.png")
## 影子相对豆子往下多少（与本体 `bullet_base.tscn` 里那颗影子同一个偏移）
const SHADOW_OFFSET_Y := 50.0
## 影子贴图是「两张并排」的横条，取第一张（本体 `bullet_base.tscn` 用的 `hframes = 2`）
const SHADOW_HFRAMES := 2
## 层级口径与本体子弹一致：行号越大越靠前（见 `Bullet000NormBase.init_bullet()`）
const Z_INDEX_PER_LANE := 50
const Z_INDEX_BULLET_OFFSET := 45

## 这一颗是哪种傻豆（`setup()` 里抛硬币；探针可以先 `set_kind()` 指定）
var kind: int = E_Kind.DropToGround
## 飞行的直线方向（`ShootOff` 用算出来的擦边方向，`DropToGround` 用原始方向）
var direction := Vector2.RIGHT
## 飞行速度
var speed := Settings.SHADOU_SPEED
## 所在行（决定画在哪一层 / 去问哪一行有没有僵尸）
var lane := -1
## 已经飞了多远（像素）
var traveled := 0.0

## `ShootOff` 那种往哪边偏：`-1` = 偏上（擦头顶）、`+1` = 偏下（贴脚底）
var _off_sign := -1.0
## `ShootOff` 那种的实际方向
var _off_direction := Vector2.RIGHT
## 掉落阶段的当前速度向量
var _fall_velocity := Vector2.ZERO
## `DropToGround` 那种：落地高度（世界坐标 y）—— 本行地面
var _ground_global_y := 0.0
var _is_falling := false
var _sprite: Sprite2D
var _shadow: Sprite2D


#region 初始化
## 初始化一颗傻豆（与本体子弹一样：**加入场景树之前**调）
##
## [param p_start_global] 出生点（世界坐标，取发射点的 `global_position`）
## [param p_direction]    正前方（取攻击组件那条射线的方向）
## [param p_lane]         哪一行
## [param p_ground_global_y] 这一行的地面 y（落地用）
func setup(p_start_global: Vector2, p_direction: Vector2, p_lane: int, p_ground_global_y: float) -> void:
	global_position = p_start_global
	direction = p_direction.normalized() if p_direction.length_squared() > 0.0 else Vector2.RIGHT
	lane = p_lane
	## 地面总得在豆子下面：万一算出来的地面比出生点还高（异常地形），至少留一段可见的下落
	_ground_global_y = maxf(p_ground_global_y, p_start_global.y + 24.0)
	speed = Settings.SHADOU_SPEED
	_roll_kind()


## 抛硬币决定是「掉地上」还是「射偏（上 / 下）」，并把射偏那颗的方向算出来
func _roll_kind() -> void:
	var total := Settings.SHADOU_DROP_WEIGHT + Settings.SHADOU_OFF_WEIGHT
	if randf() * total < Settings.SHADOU_DROP_WEIGHT:
		kind = E_Kind.DropToGround
		return
	kind = E_Kind.ShootOff
	_off_sign = -1.0 if randf() < 0.5 else 1.0
	_update_off_direction()


## 指定这一颗是哪种傻豆（给探针用：随机的那套断言不出来）
##
## [param off_sign] 「射偏」那种偏哪边：`-1` = 偏上、`+1` = 偏下；给 `0` 就沿用随机那个
func set_kind(value: int, off_sign: float = 0.0) -> void:
	kind = value
	if not is_zero_approx(off_sign):
		_off_sign = signf(off_sign)
	_update_off_direction()
#endregion


#region 生命周期
func _ready() -> void:
	z_index = lane * Z_INDEX_PER_LANE + Z_INDEX_BULLET_OFFSET
	_build_sprites()
	add_to_group(GROUP)


## 自己造两个贴图节点（**不用场景**：本模组整目录拷到 `user://mods/` 也要能跑，
## 路径读不到的 `.tscn` 不如直接 `new()` 一个 `Sprite2D` 省事）
func _build_sprites() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = SPRITE_NAME
	_sprite.texture = PEA_TEXTURE
	add_child(_sprite)

	## 影子只在**飞行中**留着：一进掉落阶段（豆子贴着地了）它还挂在下面 50 像素就成穿地了
	## （见 `_hide_shadow()`）
	_shadow = Sprite2D.new()
	_shadow.name = SHADOW_NAME
	_shadow.texture = PEA_SHADOW_TEXTURE
	## 贴图是两张影子并排的横条，本体 `bullet_base.tscn` 里取的正是第一张
	_shadow.hframes = SHADOW_HFRAMES
	_shadow.position = Vector2(0.0, SHADOW_OFFSET_Y)
	_shadow.z_index = -1
	add_child(_shadow)
#endregion


#region 飞行 / 掉落
func _physics_process(delta: float) -> void:
	match kind:
		E_Kind.DropToGround:
			_process_drop_to_ground(delta)
		E_Kind.ShootOff:
			_process_shoot_off(delta)


## 掉地上那种：先水平飞，到僵尸前面转成自由落体，落到地面上就播命中特效并消失
func _process_drop_to_ground(delta: float) -> void:
	if not _is_falling:
		global_position += direction * speed * delta
		traveled += speed * delta
		if _should_start_falling():
			_start_falling()
		return
	_fall_velocity.y += Settings.SHADOU_GRAVITY * delta
	global_position += _fall_velocity * delta
	if global_position.y >= _ground_global_y:
		global_position.y = _ground_global_y
		_land()


## 该往下掉了吗 —— 「到僵尸前面」= 本行最靠前那只僵尸的**受击框前缘**离我不到
## `SHADOU_FALL_GAP` 了；一只僵尸都没有（或都还很远）时看飞行距离
func _should_start_falling() -> bool:
	var zombie := _nearest_zombie_ahead()
	if is_instance_valid(zombie):
		var box := _hurt_box_rect(zombie)
		## 僵尸朝左走，面对豌豆的那一侧是它的**左缘**
		var front_edge := box.position.x
		if box.size == Vector2.ZERO:
			## 形状读不出来（少见）：退回到僵尸原点
			front_edge = zombie.global_position.x
		return front_edge - global_position.x <= Settings.SHADOU_FALL_GAP
	return traveled >= Settings.SHADOU_FALL_DISTANCE


func _start_falling() -> void:
	_is_falling = true
	_fall_velocity = Vector2(direction.x * speed * Settings.SHADOU_FALL_H_RATIO, 0.0)
	## 影子跟着往下走就成穿地了：一进掉落阶段就藏掉
	_hide_shadow()


## 掉到地上了：这一颗到此为止 —— 原地播一次本体那套「豌豆命中」特效，然后自己消失
func _land() -> void:
	_is_falling = false
	_play_pea_hit_effect()
	queue_free()


## 射偏那种：沿「恰好擦过僵尸」的方向一直飞，飞够距离就消失（没有重力、没有碰撞）
func _process_shoot_off(delta: float) -> void:
	global_position += _off_direction * speed * delta
	traveled += speed * delta
	if traveled >= Settings.SHADOU_MAX_DISTANCE:
		queue_free()


func _hide_shadow() -> void:
	if is_instance_valid(_shadow):
		_shadow.visible = false
#endregion


#region 「射偏」的方向：恰好擦过僵尸
## 算射偏那颗的飞行方向：瞄准「受击框上缘 / 下缘再往外 `SHADOU_OFF_CLEARANCE`」那个点
##
## 为什么不随便偏一个角度：随便偏要么还是打中，要么飞得老远、不像「擦着过去」。
## ⚠️ 还要算**提前量**：僵尸是朝豌豆走过来的，直接瞄它**此刻**的位置的话，
## 等豌豆飞到那儿它早已挪开，视线与它的交角会让豌豆实际擦得比预期更贴近（有打中的风险）。
## 所以把瞄准点往它走的那个方向挪一个「相遇点」（慢速僵尸，`gap / 速度` 估一下就够）。
func _update_off_direction() -> void:
	var zombie := _nearest_zombie_ahead()
	var box := _hurt_box_rect(zombie)
	if box.size == Vector2.ZERO:
		## 前面一只僵尸都没有：那就真的只是「射偏」了，随便偏一个角度
		var degree := randf_range(Settings.SHADOU_OFF_ANGLE_DEG.x, Settings.SHADOU_OFF_ANGLE_DEG.y)
		_off_direction = direction.rotated(deg_to_rad(degree * _off_sign))
		return
	var box_x := box.get_center().x
	var edge_y := box.position.y - Settings.SHADOU_OFF_CLEARANCE
	if _off_sign > 0.0:
		edge_y = box.end.y + Settings.SHADOU_OFF_CLEARANCE
	var lead_time := maxf((box_x - global_position.x) / maxf(speed, 1.0), 0.0)
	var aim := Vector2(box_x + _zombie_velocity_x(zombie) * lead_time, edge_y)
	var aimed := aim - global_position
	if aimed.length_squared() < 1.0:
		return
	_off_direction = aimed.normalized()


## 僵尸此刻在 x 上的速度（像素 / 秒，往左为负）—— 给射偏算提前量用
##
## 本体的移动组件是 `position.x -= 速度 * 朝向`（见 `component_move.gd`），朝左时就是负的。
func _zombie_velocity_x(zombie: Zombie000Base) -> float:
	if not is_instance_valid(zombie):
		return 0.0
	var mover: MoveComponent = zombie.move_component
	if mover == null:
		return 0.0
	return -mover.curr_speed * float(zombie.direction_x_root)
#endregion


#region 落地那一下的「豌豆命中」特效
## 在豆子**当前的位置**播一次本体那套「豌豆命中」特效（溅射贴图 + 粒子）
##
## 借的是本体 `BulletIds.PEA` 那颗子弹场景里的 `BulletEffect` 子树 —— 与本体豌豆打中僵尸时
## 播的是**同一份东西**（粒子参数、贴图都不用本模组自己攒）。
## ⚠️ 本体那颗特效是照着「自己挂在子弹下面」写的：它用 `owner.get_parent()` 把自己挪到子弹的父层
##   （也就是 `%Bullets`）再开播。所以这里临时造一个空壳当它的父节点，
##   让它自己搬到自己该去的那一层；空壳搬完就没用了，当场回收。
func _play_pea_hit_effect() -> void:
	var main_game: MainGameManager = GameContext.curr_main_game
	if main_game == null or not is_instance_valid(main_game.bullets):
		return
	var scene := Global.bullet_registry.get_bullet_scenes(BulletIds.PEA)
	if scene == null:
		return
	var sample := scene.instantiate()
	var effect: BulletEffect000Base = \
		sample.get_node_or_null(PEA_EFFECT_NAME) as BulletEffect000Base
	if effect == null:
		sample.free()
		return
	## 只借那颗特效，被剖开的豌豆壳子（还没入过树）直接扔掉
	sample.remove_child(effect)
	## ⚠️ 必须先把它的 owner 清掉再挂到新爹下面：它的 owner 现在还指着那颗豌豆壳子，
	## 挂到空壳下面时引擎会警告「owner 不一致」（owner 必须在同一条祖先链上）
	effect.owner = null

	var holder := Node2D.new()
	holder.name = PEA_HIT_HOLDER_NAME
	holder.z_index = z_index
	main_game.bullets.add_child(holder)
	holder.global_position = global_position
	holder.add_child(effect)
	effect.owner = holder
	effect.add_to_group(PEA_HIT_GROUP)

	var splats := effect.get_node_or_null(PEA_SPLAT_NAME) as Sprite2D
	## 先让特效自己搬家开播（它会 `reparent()` 到 `%Bullets`）；Tween 排在搬完家之后再建，
	## 不去赌「搬家（先出树再入树）会不会把绑在这颗特效上的 Tween 打断」
	effect.activate_bullet_effect()
	if splats != null and splats.hframes > 1:
		## 本体那套只显示溅射贴图的第一帧，这里把它自带的那几帧走一遍
		## —— 不然「豌豆命中动画」是张不动的图。
		## ⚠️ 不能用 `tween_method` 挂脚本回调：那个 Callable 会绑在**本颗傻豆**身上，
		## 而傻豆落地就 `queue_free()` 了（要求就是「落地即消失」），回调打在一个已释放的
		## 实例上 —— 实测帧数一动不动。`tween_property` 只认「目标对象 + 属性名」，没有这个包袱。
		## Tween 本身建在**特效**上（它要活到粒子播完），所以这条动画不会被傻豆带走。
		splats.frame = 0
		var tween := effect.create_tween()
		tween.tween_property(splats, "frame", splats.hframes - 1, Settings.SHADOU_SPLAT_ANIM_TIME)

	holder.queue_free()
	sample.free()
#endregion


#region 找「前面那只僵尸」/ 读它的受击框
## 本行最靠前（横坐标最小）的、还在我前面的僵尸；一只都没有就给 null
##
## 走 `ZombieManager.all_zombies_2d`（**按行**存的僵尸列表，本体自己也在用）——
## 只查自己这一行，不全场扫。
func _nearest_zombie_ahead() -> Zombie000Base:
	var manager: ZombieManager = _zombie_manager()
	if manager == null or lane < 0 or lane >= manager.all_zombies_2d.size():
		return null
	var row_zombies: Array = manager.all_zombies_2d[lane]
	var nearest: Zombie000Base = null
	for i in range(row_zombies.size()):
		var zombie: Zombie000Base = row_zombies[i]
		if not is_instance_valid(zombie):
			continue
		## 被魅惑的僵尸现在是友军、空中的僵尸在头顶上 —— 都**不算**「前面那只僵尸」
		if zombie.is_hypno or zombie.curr_be_attack_status \
				== Zombie000Base.E_BeAttackStatusZombie.IsSky:
			continue
		if zombie.global_position.x - global_position.x < -Settings.SHADOU_FALL_OVERSHOOT:
			continue
		if nearest == null or zombie.global_position.x < nearest.global_position.x:
			nearest = zombie
	return nearest


## 僵尸**真实受击框**在世界坐标里的矩形（左上角 + 尺寸）；读不到就给 `Rect2()`（尺寸为零）
##
## 本体僵尸的受击框是 `HurtBoxComponent/HurtBoxReal` 下面那个 `CollisionShape2D`，
## 尺寸各只僵尸都不一样，所以一律**从实例上读**、不写死。
func _hurt_box_rect(zombie: Zombie000Base) -> Rect2:
	if not is_instance_valid(zombie):
		return Rect2()
	var component: HurtBoxComponent = zombie.hurt_box_component
	if component == null or not is_instance_valid(component.hurt_box_real):
		return Rect2()
	var shape_node := _first_collision_shape(component.hurt_box_real)
	if shape_node == null:
		return Rect2()
	var shape := shape_node.shape
	var half_size := Vector2.ZERO
	if shape is CapsuleShape2D:
		## 胶囊的 `height` 是**含两端半圆**的总高
		var capsule := shape as CapsuleShape2D
		half_size = Vector2(capsule.radius, capsule.height * 0.5)
	elif shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		half_size = rectangle.size * 0.5
	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		half_size = Vector2(circle.radius, circle.radius)
	else:
		return Rect2()
	if half_size.y <= 0.0:
		return Rect2()
	var center := shape_node.global_position
	return Rect2(center - half_size, half_size * 2.0)


func _first_collision_shape(area: Area2D) -> CollisionShape2D:
	for child in area.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null:
			return shape_node
	return null


func _zombie_manager() -> ZombieManager:
	var main_game: MainGameManager = GameContext.curr_main_game
	if main_game == null:
		return null
	return main_game.zombie_manager
#endregion
