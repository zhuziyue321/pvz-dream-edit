extends Plant000Base
## 国王仙人掌（DLC 的 KingCactus，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**全屏索敌 + 八方向散射** —— 场上**任何一行**有僵尸就一轮甩出
##   **8 根刺（每 45° 一根）**，刺的轨迹是「径向匀加速 + 轴向匀加速」
##   （见 `kingcactus_spike.gd`）：沿发射方向越飞越快，同时被一个较小的侧向加速度慢慢掰弯，
##   且**相邻两轮齐射的侧向加速度方向相反**（一轮往左弯、下一轮往右弯）。
##
## ★ 索敌是**全屏**的：检测框是一块 2400×1600 的大矩形（植物种在屏幕角落也罩得住整场），
##   并关掉 `DetectComponent.is_lane` 的行过滤 —— 否则检测组件自己会按行把别的行僵尸筛掉。
##
## ★ 因为要打场上的各个方向，这一株的子弹**也不吃行属性**（`IsActivateLane = false`）：
##   命中只由攻击框与受击框的空间重叠决定，45° / 90° 那几根才能打到别的行。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/KingCactus/KingCactus.tscn`），
##   四段都在同一条动画库 `AnimLib` 里：
##     · `KingCactus_idle`（1.5 秒）：站着待机
##     · `KingCactus_shooting`（1.4167 秒）：射刺，第 6 帧左右出刺
##     · `KingCactus_blink` / `KingCactus_face`：本株不用（眨眼交给动画自己，
##       姿态切换不接 `BlinkComponent`，否则两套眨眼会打架）
##
## ★ 为什么不用本体的 `AttackComponentBulletBase`：那条路的攻击节奏靠
##   `AnimationTree.set("parameters/OneShot/request")` 驱动，而 DLC 动画只有
##   `AnimationPlayer`、没有 `AnimationTree`（`@onready var animation_tree: AnimationTree = $"../AnimationTree"`
##   会在场景加载时报「Node not found」）。所以照 PVZ2 模组火焰豌豆射手那条路，
##   自己挂 `DetectComponent` + 冷却计时器，发射逻辑直接走 `BulletRegistry`。
##
## ★ 数值都是**模组自己的取值**，不是照 wiki 抄的 —— 要对齐请自己查过再改。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_kingcactus.tscn` 按路径引用。

## 尖刺场景（模组自己的「径向 + 轴向匀加速」版，继承本体 `bullet_cactus.tscn`）
const SPIKE_SCENE := preload("kingcactus_spike.tscn")
## 一轮齐射几根：8 个方向，每 45° 一根
const SPRAY_DIRECTION_COUNT := 8

@onready var _anim_player: AnimationPlayer = $Body/KingCactusAnim/AnimLib
@onready var _detect_component: DetectComponent = $DetectComponent
@onready var _attack_cd_timer: Timer = $AttackCdTimer
@onready var _shoot_timer: Timer = $ShootTimer
## 刺的出生点（身体中心偏上，8 个方向都从这里出发，见场景注释）
@onready var _marker: Marker2D = $Body/Marker2D


#region 数值（模组的取值，不是照 wiki 抄的）
## 一根刺的伤害
@export var bullet_damage := 20
## 攻击间隔（秒）
## 必须**长于** `KingCactus_shooting` 的时长（17 帧 @12fps ≈ 1.417 秒），
## 否则每轮 CD 到点时开火动画还没播完就被 `play()` 从头重置 —— 看起来就是「动画和发射对不上」
@export var attack_cd := 1.6
## 从开火动画开始到出刺的延迟（秒）
## `KingCactus_shooting` 17 帧 @12fps：整株在第 12 帧（t≈1.0 秒）蹲到最低，
## 刺就在这一刻甩出（量法：所有可见部件 position.y 的平均值，最大 = 最矮）
@export var shoot_delay := 1.0
## 每根刺沿自己的方向往外推多远再出发（像素）：让 8 根从「刺座外缘」散开，
## 而不是全挤在身体中心同一个点上
@export var spray_spawn_radius := 24.0
#endregion


#region 动画常量
const STATE_IDLE := &"KingCactus_idle"
const STATE_SHOOTING := &"KingCactus_shooting"
#endregion

## 检测框里有敌人（由 `DetectComponent` 的两个信号维护）
var _has_enemy := false
## 已经打出了几轮齐射：用来让相邻两轮的轴向加速度方向相反
var _volley_index := 0


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	## 计时时长以导出值为准：场景里的 `wait_time` 只是编辑器里的默认值，
	## 改 `attack_cd` / `shoot_delay` 时不必再回头改两个 Timer
	_attack_cd_timer.wait_time = attack_cd
	_shoot_timer.wait_time = shoot_delay
	_detect_component.signal_can_attack.connect(_on_can_attack)
	_detect_component.signal_not_can_attack.connect(_on_not_can_attack)
	_attack_cd_timer.timeout.connect(_on_attack_cd_timer_timeout)
	_shoot_timer.timeout.connect(_shoot_bullet)
	_anim_player.animation_finished.connect(_on_animation_finished)
	## 关卡全场加速（「僵尸快跑」）要连冷却与动画一起加速
	signal_update_speed.connect(_on_update_speed)


## 初始化正常出战角色
func ready_norm() -> void:
	super()
	_play_idle()


## 初始化展示角色（图鉴 / 选卡界面里的形象）
func ready_show() -> void:
	super()
	_play_idle()


## 初始化花园角色
func ready_garden() -> void:
	super()
	_play_idle()
#endregion


#region 攻击
func _on_can_attack() -> void:
	_has_enemy = true
	## 刚进范围立刻打一发，之后交给冷却计时器续上（与本体射手的口径一致）
	if _attack_cd_timer.is_stopped():
		_start_attack()


func _on_not_can_attack() -> void:
	_has_enemy = false
	## 没有敌人就停表：再进范围时才能「立刻打第一发」
	_attack_cd_timer.stop()
	_shoot_timer.stop()


func _on_attack_cd_timer_timeout() -> void:
	if _has_enemy:
		_start_attack()


## 开一次攻击：播 `shooting`（单次），刺由 `shoot_delay` 后发出
func _start_attack() -> void:
	if is_death:
		return
	_anim_player.play(STATE_SHOOTING)
	## 用无参 start：让 `_on_update_speed()` 折算过的 `wait_time` 生效
	_attack_cd_timer.start()
	_shoot_timer.start()


## 一轮齐射：8 个方向各一根，轴向加速度方向每轮翻转
func _shoot_bullet() -> void:
	if is_death or not _has_enemy:
		return
	var main_game := get_main_game()
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.bullets):
		return
	var bullets: Node2D = main_game.bullets
	## 闸门被占住时（联机客户端）这一轮不造：与 `BulletRegistry.create_bullet()` 同一条闸门
	if GlobalUtils.bullet_spawn_gate.is_valid() and bool(GlobalUtils.bullet_spawn_gate.call()):
		return
	var status := _detect_component.can_attack_status_component
	var bullet_damage_value := bullet_damage
	## 角色自己的 `attack_value` 有值就按它来（与本体「攻击力字段接入子弹伤害」同一条优先级）
	if attack_value > 0:
		bullet_damage_value = attack_value
	var spawn_pos := bullets.to_local(_marker.global_position)
	var axial_sign := get_next_axial_sign()
	for spray_direction: Vector2 in get_spray_directions():
		var bullet: Bullet000Base = SPIKE_SCENE.instantiate() as Bullet000Base
		if bullet == null:
			return
		## 走模组自己的场景，所以注册表那套「领号」也得自己补上（见 `Bullet000Base.entity_id`）
		bullet.entity_id = Character000Base.take_next_entity_id()
		## 轴向加速度朝哪边（+1 / -1）由这一轮决定，见 `get_next_axial_sign()`
		bullet.set(&"axial_sign", axial_sign)
		var paras: Dictionary[Bullet000NormBase.E_InitParasAttr, Variant] = {
			## 八方向要打别的行：**不吃行属性**，命中只靠攻击框与受击框重叠
			Bullet000NormBase.E_InitParasAttr.IsActivateLane: false,
			Bullet000NormBase.E_InitParasAttr.BulletLane: lane,
			## 出生点沿各自方向外推一圈：8 根同时从身体中心冒出来会「重叠成一坨」，
			## 推到刺座外缘才像是一身刺同时甩出去（也让出生点与开火动画的刺座对得上）
			Bullet000NormBase.E_InitParasAttr.Position: spawn_pos + spray_direction * spray_spawn_radius,
			Bullet000NormBase.E_InitParasAttr.Direction: spray_direction,
			Bullet000NormBase.E_InitParasAttr.CanAttackPlantState: status.can_attack_plant_status,
			Bullet000NormBase.E_InitParasAttr.CanAttackZombieState: status.can_attack_zombie_status,
			Bullet000NormBase.E_InitParasAttr.BulletCamp: CharacterRegistry.CharacterType.Plant,
			Bullet000NormBase.E_InitParasAttr.AttackValue: bullet_damage_value,
		}
		bullet.init_bullet(paras)
		bullets.add_child(bullet)
	_volley_index += 1
	SoundManager.play_character_SFX(&"Throw")


## 这一轮齐射的 8 个方向：从正右开始，每 45° 一根（逆时针）
func get_spray_directions() -> Array[Vector2]:
	var directions: Array[Vector2] = []
	for i in range(SPRAY_DIRECTION_COUNT):
		directions.append(Vector2.RIGHT.rotated(TAU * float(i) / float(SPRAY_DIRECTION_COUNT)))
	return directions


## 下一轮齐射的轴向加速度符号：相邻两轮相反（+1 / -1 交替）
func get_next_axial_sign() -> float:
	return 1.0 if _volley_index % 2 == 0 else -1.0


## 全场加速：冷却按倍率折算（与 `AttackComponentBulletBase.owner_update_speed` 同口径）
func _on_update_speed(speed_product: float) -> void:
	if speed_product == 0:
		_attack_cd_timer.paused = true
		_anim_player.speed_scale = 0.0
		return
	_attack_cd_timer.paused = false
	_anim_player.speed_scale = speed_product
	if not _attack_cd_timer.is_stopped():
		_attack_cd_timer.start(_attack_cd_timer.time_left / speed_product)
	_attack_cd_timer.wait_time = attack_cd / speed_product
	_shoot_timer.wait_time = shoot_delay / speed_product
#endregion


#region 动画回调
## 一段动画播完：shooting / idle 都回到待机
func _on_animation_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if anim_name == STATE_SHOOTING or anim_name == STATE_IDLE:
		_play_idle()


## 待机是循环的：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)
#endregion
