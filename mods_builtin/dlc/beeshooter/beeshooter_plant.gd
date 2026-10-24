extends Plant000Base
## 蜜蜂射手（DLC 的 Beeshooter，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**单行直线射手** —— 本行右侧有僵尸就张嘴吐一只蜜蜂，
##   蜜蜂走直线飞过去（本体 `bullet_linear_base.tscn` 那条路），命中第一只僵尸扣血。
##
## ★ 数值（DLC Edition 的 wiki：Plants 总表 + Projectiles 表）：
##   · 阳光 100（总表直取）
##   · 伤害「Average」、等效 1 豌豆（Projectiles 表）→ 取 20，与本体豌豆同档
##   · 冷却 / 攻击间隔总表没给 —— 取豌豆口径：冷却 7.5 秒（fast）；
##     **攻击间隔必须长于开火动画**：开火动画 2.0 秒，取 2.1 秒
##
## ★ 动画是**两层**（这株的 reanim 被拆成了分图层动画，见 `plant_beeshooter.tscn` 文件头）：
##   · `AnimLib` 播 `BeeShooter_full_idle`：完整待机姿态（身体 + 头 + 嘴）
##   · `ShootLayer` 播 `BeeShooter_shooting_overlay`：开火时动的只有头 / 嘴 / 闪帧
##     （`shooting` 原段会把身体 visible 关掉，所以另生成一层「头部覆盖动画」）
##   开火那层播完自己停住，下一帧起待机层重新接管头部 —— 不用切回，也不会卡住姿势。
##   蜜蜂在 t≈0.5 秒（嘴收到最高点）吐出，见 `shoot_delay`。
##
## ★ 为什么不用本体的 `AttackComponentBulletBase`：那条路的攻击节奏靠
##   `AnimationTree.set("parameters/OneShot/request")` 驱动，而 DLC 动画只有
##   `AnimationPlayer`、没有 `AnimationTree`（`@onready var animation_tree: AnimationTree = $"../AnimationTree"`
##   会在场景加载时报「Node not found」）。所以照环轨仙人掌 / 投掷蘑菇那条路，
##   自己挂 `DetectComponent` + 冷却计时器。
##
## ★ 数值都是**模组自己的取值**（对齐 wiki 的那几项写在上面），别照 wiki 再改别的。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_beeshooter.tscn` 按路径引用。

## 蜜蜂（本体直线子弹基类 + 模组自己的贴图 / 数值）
const BEE_SCENE := preload("bullet_beeshooter_bee.tscn")

## 吐蜜蜂的音效（DLC 自己的两条蜂鸣，随机取一条）：原来借的是本体 `Throw`
const BEE_SFX: Array[AudioStream] = [
	preload("../audio/bee_1.ogg"),
	preload("../audio/bee_2.ogg"),
]

## 待机层：完整姿态
@onready var _anim_player: AnimationPlayer = $Body/BeeShooterAnim/AnimLib
## 开火层：只动头部 / 嘴的覆盖动画
@onready var _shoot_layer: AnimationPlayer = $Body/BeeShooterAnim/ShootLayer
@onready var _detect_component: DetectComponent = $DetectComponent
@onready var _attack_cd_timer: Timer = $AttackCdTimer
@onready var _shoot_timer: Timer = $ShootTimer
## 蜜蜂出生点（嘴部枪口，见场景注释）
@onready var _marker: Marker2D = $Body/Marker2D


#region 数值（模组的取值；对齐 wiki 的那几项写在文件头）
## 一只蜜蜂的伤害
@export var bullet_damage := 20
## 攻击间隔（秒）：wiki 的 `firerate = 1.5`
## 开火动画 2.0 秒**长于**这个间隔，所以动作段要按 `SHOOT_ANIM_SPEED` 加速播放，
## 否则每一轮 CD 到点 `play()` 都会把没播完的开火从头重置 —— 看起来就是「动画和发射对不上」
@export var attack_cd := 1.5
## 开火覆盖层的播放倍率：2.0 秒 ÷ 1.5 秒攻速，让一段开火正好在下一发之前播完
const SHOOT_ANIM_SPEED := 1.34
## 从开火动画开始到蜜蜂出嘴的延迟（秒）
## 开火覆盖动画 24 帧 @12fps：嘴在第 6 帧（t≈0.5 秒）收到最高点，蜜蜂就在这一刻吐出去
@export var shoot_delay := 0.5
#endregion


#region 动画常量
const STATE_IDLE := &"BeeShooter_full_idle"
const STATE_SHOOTING := &"BeeShooter_shooting_overlay"
#endregion

## 检测框里有敌人（由 `DetectComponent` 的两个信号维护）
var _has_enemy := false
## 关卡全场加速的当前倍率（1.0 = 原速）：开火层要在这个基础上再叠一层「段长 ÷ 攻速」的加速
var _speed_product := 1.0


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
	## 待机是单次动画（loop 关着），播完要靠这个回调续上 —— 看起来就是循环
	_anim_player.animation_finished.connect(_on_idle_finished)
	## 关卡全场加速（「僵尸快跑」）要连冷却与两层动画一起加速
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


## 开一次攻击：开火覆盖层播一遍，蜜蜂在 `shoot_delay` 后出嘴
## 待机层一直跑着（身体 + 待机头），不打断
func _start_attack() -> void:
	if is_death:
		return
	## 开火段按「段长 ÷ 攻速」加速播放（见 `SHOOT_ANIM_SPEED`），全场加速的倍率叠在外面一层
	_shoot_layer.speed_scale = _speed_product * SHOOT_ANIM_SPEED
	_shoot_layer.play(STATE_SHOOTING)
	## 用无参 start：让 `_on_update_speed()` 折算过的 `wait_time` 生效
	_attack_cd_timer.start()
	_shoot_timer.start()


## 吐一只蜜蜂：直线飞向右（本体射手的口径，命中交给子弹自己的攻击框与受击框）
func _shoot_bullet() -> void:
	if is_death or not _has_enemy:
		return
	var main_game := get_main_game()
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.bullets):
		return
	var bullets: Node2D = main_game.bullets
	## 闸门被占住时（联机客户端）这一只不造：与 `BulletRegistry.create_bullet()` 同一条闸门
	if GlobalUtils.bullet_spawn_gate.is_valid() and bool(GlobalUtils.bullet_spawn_gate.call()):
		return
	var status := _detect_component.can_attack_status_component
	var bullet_damage_value := bullet_damage
	## 角色自己的 `attack_value` 有值就按它来（与本体「攻击力字段接入子弹伤害」同一条优先级）
	if attack_value > 0:
		bullet_damage_value = attack_value
	var bullet: Bullet000Base = BEE_SCENE.instantiate() as Bullet000Base
	if bullet == null:
		return
	## 走模组自己的场景，所以注册表那套「领号」也得自己补上（见 `Bullet000Base.entity_id`）
	bullet.entity_id = Character000Base.take_next_entity_id()
	## 双向射手（wiki `range = Forward and backward`）：朝**离自己最近的那只**开火 ——
	## 它在左边就往左吐（僵尸从右侧涌来，所以「身后」那一侧就是左边）
	var direction := Vector2.RIGHT
	var spawn_pos := _marker.global_position
	var nearest: Character000Base = null
	var nearest_d := INF
	for enemy in _detect_component.get_all_enemy_can_be_attacked():
		if not is_instance_valid(enemy):
			continue
		var d := absf(enemy.global_position.x - global_position.x)
		if d < nearest_d:
			nearest_d = d
			nearest = enemy
	if nearest != null and nearest.global_position.x < global_position.x:
		direction = Vector2.LEFT
		## 出弹点跟着方向镜像：`Marker2D` 画在右侧嘴部，往左吐时挪到对称的左侧嘴部
		spawn_pos.x = global_position.x - (_marker.global_position.x - global_position.x)
	var paras: Dictionary[Bullet000NormBase.E_InitParasAttr, Variant] = {
		## 直线射手只打本行：吃行属性，命中由子弹攻击框与僵尸受击框决定
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: true,
		Bullet000NormBase.E_InitParasAttr.BulletLane: lane,
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(spawn_pos),
		Bullet000NormBase.E_InitParasAttr.Direction: direction,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState: status.can_attack_plant_status,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState: status.can_attack_zombie_status,
		Bullet000NormBase.E_InitParasAttr.BulletCamp: CharacterRegistry.CharacterType.Plant,
		Bullet000NormBase.E_InitParasAttr.AttackValue: bullet_damage_value,
	}
	bullet.init_bullet(paras)
	bullets.add_child(bullet)
	SoundManager.play_sfx_with_pool(BEE_SFX.pick_random())


## 全场加速：冷却与两层动画按倍率折算（与 `AttackComponentBulletBase.owner_update_speed` 同口径）
func _on_update_speed(speed_product: float) -> void:
	_speed_product = speed_product
	if speed_product == 0:
		_attack_cd_timer.paused = true
		_anim_player.speed_scale = 0.0
		_shoot_layer.speed_scale = 0.0
		return
	_attack_cd_timer.paused = false
	_anim_player.speed_scale = speed_product
	## 开火层只在没在开火时直接写回（开火那一段还叠着自己的加速，播完由 `_start_attack` 重设）
	if not _shoot_layer.is_playing():
		_shoot_layer.speed_scale = speed_product
	if not _attack_cd_timer.is_stopped():
		_attack_cd_timer.start(_attack_cd_timer.time_left / speed_product)
	_attack_cd_timer.wait_time = attack_cd / speed_product
	_shoot_timer.wait_time = shoot_delay / speed_product
#endregion


#region 动画回调
## 待机是单次动画：播完再起一遍（不打断正在跑的那一遍）
func _on_idle_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if anim_name == STATE_IDLE:
		_play_idle()


## 已经在播待机就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)
#endregion
