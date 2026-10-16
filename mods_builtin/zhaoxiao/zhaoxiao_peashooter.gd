extends Node
## 模组「招笑版」：挂在**每一株傻豆射手（原豌豆射手）**身上的观察者 —— 由入口脚本
## `zhaoxiao_mod.gd` 在**每一局主游戏**里现挂（本体场景里没有这个节点）。
##
## 它把豌豆射手改成「傻豆射手」，管四件事（需求原文 2~4 条）：
##   1. **普通攻击改成打傻豆**：本体射击组件每次要出弹时，本观察者替它造一颗**傻豆**
##      （`zhaoxiao_shadou.gd`：两种随机，且**没有碰撞箱**、不造成伤害）；
##   2. **攒怒气**：每打出一颗傻豆攒 `ANGER_PER_SHOT`；
##   3. **怒气把整株染红**：按怒气比例把 `Body` 的底色从白渐变到红（满了就该放大招了）；
##   4. **满怒放大招**：怒气**匀速**降到 0（正好花 `ULTIMATE_TIME`），
##      这段时间里朝正前方 ±`ULTIMATE_ANGLE_DEG` 度、以随机速度散射**普通豌豆**
##      （真·本体豌豆子弹，会打伤害）。大招期间不再打傻豆。
##
## ★ 怎么把「本体射击」换成「傻豆」（本模组唯一的技术点）：
##   本体那条链路是「计时器 → 播攻击动画 → 动画的方法轨道调 `_shoot_bullet()`」，
##   模组**插不进**动画里那一步。所以反过来做：
##   · 先把组件的发射点（`markers_2d_bullet`）**抄一份**到自己手上，再把那份**腾空**；
##   · 于是动画照常播、音效照常响、`signal_shoot_bullet` 照常发，
##     但组件自己**一颗本体豌豆都不会造**（它循环的是空数组）；
##   · 本观察者接的就是这条现成信号，在同一个时机造自己的傻豆。
##   ⚠️ 发射点只在**抄完**之后再腾空 —— 位置得继续读原来那个 `Marker2D`（它挂在
##       `stem_correct` 底下，被动画逐帧写位置），自己记一份死坐标过两帧就不准了。
##
## ★ 大招的豌豆与傻豆相反，是**走注册表的真子弹**（`BulletRegistry` + `BulletIds.PEA`），
##   所以那部分会正常碰撞、正常掉血 —— 大招才有意义。
##
## ⚠️ 本类是普通 `Node`（不是 `Character000Base` / `ComponentNormBase` 的子类），
##    `_ready()` 按 Godot 常态写即可 —— 硬约束 §1-3 只管那两类角色 / 组件。

const Settings := preload("zhaoxiao_settings.gd")
const Shadou := preload("zhaoxiao_shadou.gd")

## 观察者节点的名字 / NodePath（入口脚本按它判「这株挂过没有」）
const NODE_NAME := &"ShadouWatcher"
const NODE_PATH := ^"ShadouWatcher"
## 本体射击组件的节点名
const ATTACK_NODE_PATH := ^"AttackComponent"

## 宿主（那株傻豆射手）
var _plant: Plant000Base
## 宿主的射击组件（本观察者接管的就是它）
var _attack: AttackComponentBulletBase
## 主游戏（造子弹要用它的 `bullets` 父节点）
var _main_game: MainGameManager

## 抄下来的发射点（**原物**：位置每帧从它读）
var _markers: Array[Marker2D] = []
## 抄下来的发射方向（`DetectComponent.ray_area_direction`，与发射点一一对应）
var _directions: Array[Vector2] = []

## 怒气：0 ~ `ANGER_MAX`
var _anger := 0.0
## 上一次真正写进 `Body.base_color` 的怒气值（值没变就不重复写，省得每帧都合成一遍颜色）
var _anger_applied := -1.0
## 大招剩余秒数（> 0 = 正在放大招）
var _ultimate_left := 0.0
## 下一次散射豌豆还要等多久
var _ultimate_spawn_wait := 0.0


#region 生命周期
func _ready() -> void:
	_plant = get_parent() as Plant000Base
	if _plant == null:
		Log.error("招笑版模组：傻豆观察者的父节点不是植物，本株不参与")
		return
	_main_game = _plant.get_main_game()
	_attack = _plant.get_node_or_null(ATTACK_NODE_PATH) as AttackComponentBulletBase
	if _attack == null:
		Log.error("招笑版模组：傻豆射手身上找不到射击组件，本株不参与")
		return
	_take_over_shooting()
	## 刚挂上时怒气是 0（贴图不染），显式跑一次把上一次写进的值复位
	_anger_applied = -1.0
	_apply_anger_tint()
#endregion


#region 接管射击：抄下发弹点 → 腾空 → 接信号
## 把本体的发射点抄下来，再让组件自己「打空气」；造什么由本观察者决定
func _take_over_shooting() -> void:
	_markers.clear()
	_directions.clear()
	for marker in _attack.markers_2d_bullet:
		_markers.append(marker)
	var ray_directions: Array[Vector2] = _attack.detect_component.ray_area_direction
	for direction in ray_directions:
		_directions.append(direction)
	## 腾空（`clear()` 原地清，不换数组实例）：组件照旧循环它，只是循环了 0 次
	_attack.markers_2d_bullet.clear()
	if not _attack.signal_shoot_bullet.is_connected(on_shoot_bullet):
		_attack.signal_shoot_bullet.connect(on_shoot_bullet)


## 「本体射击组件该出弹了」—— 本体每放一次攻击动画、走一次这个方法轨道，这里就跑一次
##
## 公开方法（供信号连、也供探针直接调）。
func on_shoot_bullet() -> void:
	if not is_inside_tree() or not is_instance_valid(_plant):
		return
	## 大招期间不打傻豆：这段时间打出去的是普通豌豆（见 `_scatter_ultimate_peas()`）
	if _ultimate_left > 0.0:
		return
	spawn_shadou()
	_add_anger(Settings.ANGER_PER_SHOT)


## 打出一颗傻豆：每个发射点各一颗（本体豌豆射手只有一个，口径与它一致）
##
## [param forced_kind] 指定这一颗是哪种傻豆（`zhaoxiao_shadou.gd` 的 `E_Kind`），
## 给 < 0 时按权重随机 —— 探针用它（随机那套断言不出来）。
## [param off_sign] 「射偏」那种偏哪边：`-1` = 偏上、`+1` = 偏下、`0` = 随机（同样只给探针用）。
## 返回最后造出来的那一颗（造不出来 / 没有子弹父节点时给 null）。
##
## 公开方法：`on_shoot_bullet()` 用它，探针也用它。
func spawn_shadou(forced_kind: int = -1, off_sign: float = 0.0) -> Node2D:
	if _main_game == null or not is_instance_valid(_main_game.bullets):
		return null
	var spawned: Node2D = null
	var count := maxi(_markers.size(), 1)
	for i in range(count):
		var shadou := Shadou.new()
		shadou.name = Shadou.NODE_NAME
		shadou.setup(_origin_of(i), _direction_of(i), _lane(), _ground_global_y())
		if forced_kind >= 0:
			shadou.set_kind(forced_kind, off_sign)
		## 与本体子弹同一个父节点、同一套层级口径（`z_index` 在傻豆自己的 `_ready()` 里按行算）
		_main_game.bullets.add_child(shadou)
		spawned = shadou
	return spawned


func _origin_of(index: int) -> Vector2:
	var marker: Marker2D = _markers[index] if index < _markers.size() else null
	if is_instance_valid(marker):
		return marker.global_position
	return _plant.global_position


func _direction_of(index: int) -> Vector2:
	if index >= 0 and index < _directions.size():
		return _directions[index]
	return Vector2.RIGHT


func _lane() -> int:
	return _plant.lane


## 本行的地面 y（傻豆掉地上要落到这儿）
func _ground_global_y() -> float:
	if _main_game != null and is_instance_valid(_main_game.plant_cell_manager) and _lane() >= 0:
		return _main_game.get_row_base_global_y(_lane())
	return _plant.global_position.y
#endregion


#region 怒气
## 当前怒气（0 ~ 1；给探针读）
func get_anger() -> float:
	return _anger


## 正在放大招吗？（给探针读）
func is_in_ultimate() -> bool:
	return _ultimate_left > 0.0


## 攒怒气：满了就放大招
func _add_anger(value: float) -> void:
	if _ultimate_left > 0.0:
		return
	_anger = clampf(_anger + value, 0.0, Settings.ANGER_MAX)
	_apply_anger_tint()
	if _anger >= Settings.ANGER_MAX:
		_start_ultimate()


## 按怒气比例把整株染红
##
## 走 `BodyCharacter.base_color`：它是身体颜色的**乘法合成根**（`_update_modulate()` 会把
## `base_color` 与受击闪白 / 冰冻 / 隐形那几项**相乘**），所以染色与它们互不覆盖。
## **不能**去改各张贴图的 `modulate / self_modulate` —— 动画资源给每个部件都带了
## `self_modulate` 轨道、逐帧写回，改那儿下一帧就被盖掉（`BodyCharacter.set_invisible()` 的注释同理）。
func _apply_anger_tint() -> void:
	if is_equal_approx(_anger, _anger_applied):
		return
	_anger_applied = _anger
	if not is_instance_valid(_plant) or not is_instance_valid(_plant.body):
		return
	var ratio := clampf(_anger / Settings.ANGER_MAX, 0.0, 1.0)
	_plant.body.base_color = Color.WHITE.lerp(Settings.ANGER_TINT, ratio)
	_plant.body._update_modulate()
#endregion


#region 大招
## 开大招：怒气从这一刻起**匀速**往下走
func _start_ultimate() -> void:
	_ultimate_left = Settings.ULTIMATE_TIME
	## 立刻先来一发，别让玩家等一个间隔
	_ultimate_spawn_wait = 0.0
	Log.info("招笑版模组：傻豆射手怒气满了，放大招（%s 秒内散射普通豌豆）" % str(Settings.ULTIMATE_TIME))


## 每帧：怒气匀速减少 + 按间隔散射普通豌豆
func _process(delta: float) -> void:
	if _ultimate_left <= 0.0:
		return
	_ultimate_left = maxf(_ultimate_left - delta, 0.0)
	## **匀速**：从满到 0 正好花 `Settings.ULTIMATE_TIME`
	_anger = Settings.ANGER_MAX * (_ultimate_left / Settings.ULTIMATE_TIME)
	_apply_anger_tint()
	_scatter_ultimate_peas(delta)
	if _ultimate_left <= 0.0:
		## 收尾时把怒气归零，贴图回到原色（否则会停在「还剩一点点」的微红上）
		_anger = 0.0
		_apply_anger_tint()


## 大招期间按固定间隔散射普通豌豆（角度与速度都在设置给的区间里随机）
func _scatter_ultimate_peas(delta: float) -> void:
	_ultimate_spawn_wait -= delta
	while _ultimate_spawn_wait <= 0.0:
		_ultimate_spawn_wait += Settings.ULTIMATE_SHOT_INTERVAL
		_spawn_ultimate_pea()


## 散射一颗**普通豌豆**（本体真子弹：会碰撞、会打伤害）
##
## 与傻豆的区别就在这里：傻豆是本模组自己造的纯贴图，这一颗是**注册表里的 `BulletIds.PEA`**。
func _spawn_ultimate_pea() -> void:
	if _main_game == null or not is_instance_valid(_main_game.bullets) or not is_instance_valid(_attack):
		return
	var index := 0 if _markers.is_empty() else randi() % _markers.size()
	var angle_degree := randf_range(-Settings.ULTIMATE_ANGLE_DEG, Settings.ULTIMATE_ANGLE_DEG)
	var direction := _direction_of(index).rotated(deg_to_rad(angle_degree))
	var bullet: Bullet000NormBase = \
		Global.bullet_registry.create_bullet(BulletIds.PEA) as Bullet000NormBase
	## 造不出来（闸门被占住：联机客户端由主机下发）就当这一发没打
	if bullet == null:
		return
	## 初始参数照抄射击组件那一套（行 / 阵营 / 可攻击状态都由它算好），
	## 位置和方向用这一发自己的（方向已经偏了个随机角）
	bullet.init_bullet(_attack.get_bullet_paras(_origin_of(index), direction))
	bullet.speed = randf_range(Settings.ULTIMATE_SPEED_RANGE.x, Settings.ULTIMATE_SPEED_RANGE.y)
	_main_game.bullets.add_child(bullet)
#endregion
