extends Plant000Base
## 臼炮蘑菇（DLC 的 Mortar-shroom，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**抛射蘑菇** —— 本行约 6 格内有僵尸就朝它抛一颗会溅射的炮弹
##   （迷你西瓜投手式：直接命中 + 落点一片 AoE），**贴脸的也照打**（见下面「近身」那条）；
##   白天睡觉（蘑菇类，`SleepComponent.is_sleep_in_day`），夜里才工作。
##
## ★ 数值（DLC Edition 的 wiki：Mortar-shroom 页）：
##   75 阳光 / 冷却 7.5 秒（fast）/ 直接命中 40（moderate）/ 溅射 sum 60 / 攻击间隔 6 秒 /
##   射程「抛射·Lobbed」（约 6 格）/ 生命 300。本体 6 格 = 76 × 6 = 456 px。
##
## ★ 为什么不用本体的 `AttackComponentBulletPultBase`：那条路的攻击节奏靠
##   `AnimationTree.set("parameters/OneShot/request")` 驱动，而 DLC 动画只有
##   `AnimationPlayer`、没有 `AnimationTree`（`@onready var animation_tree: AnimationTree = $"../AnimationTree"`
##   会在场景加载时报「Node not found」）。所以照投掷蘑菇 / 环轨仙人掌那条路，
##   自己挂 `DetectComponent` + 冷却计时器，发射逻辑直接走模组自己的炮弹场景。
##
## ★ 投手的目标要**发射那一刻现取**（`update_first_enemy()`），不能在检测到敌人时就记住：
##   僵尸一直在往前走，记住的引用与位置到出弹时会过期。
##
## ★ 近身**不是**盲点：wiki 正文「Changes target when the enemy is close」—— 敌人贴到近处时
##   它换目标继续打，**不是打不到**。所以 `DetectComponent` 的碰撞框左边缘压在自己脚下、
##   再往左留 20 px 兜住正在啃它的僵尸（见场景文件）。
##   ⚠️ 早先把「Lobbed（抛射）」误读成「只轰远处」，把左边缘放到 +114 px（1.5 格），
##      贴脸的僵尸进不了框 → 打不到近处。2026-10-19 修掉，别再照旧注释改回去。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/MortarShroom/MortarShroom.tscn`），
##   三段合成进同一条动画库 `AnimLib`：
##     · `MortarShroom_idle`（1.167 秒）：站着待机
##     · `MortarShroom_shooting`（1.417 秒）：蓄力后坐再甩出炮弹，t≈0.45 秒（≈0.32 × 时长）发射
##     · `MortarShroom_sleep`：白天睡觉的姿势
##
## ★ 数值都是**模组自己的取值**（对齐 wiki 的那几项写在上面），别照 wiki 再改别的。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_mortarshroom.tscn` 按路径引用。

## 炮弹（本体抛物线基类 + 模组自己的贴图 / 数值 / 溅射）
const SHELL_SCENE := preload("bullet_mortarshroom_shell.tscn")

@onready var _anim_player: AnimationPlayer = $Body/MortarShroomAnim/AnimLib
@onready var _detect_component: DetectComponent = $DetectComponent
@onready var _attack_cd_timer: Timer = $AttackCdTimer
@onready var _shoot_timer: Timer = $ShootTimer
## 炮弹出生点（臼炮口，见场景注释）
@onready var _marker: Marker2D = $Body/Marker2D


#region 数值（模组的取值；对齐 wiki 的那几项写在文件头）
## 一发炮弹的直接命中伤害（落点溅射另走 SpatterComponent.sum_attack_value）
@export var bullet_damage := 40
## 攻击间隔（秒）：wiki 的 FiringSpeed=1/4x → 6 秒
## 必须**长于** `MortarShroom_shooting` 的时长（1.417 秒），否则 CD 到点时开火动画还没播完就被
## `play()` 从头重置 —— 看起来就是「动画和发射对不上」
@export var attack_cd := 6.0
## 从开火动画开始到炮弹出膛的延迟（秒）
## `MortarShroom_shooting` 约 17 帧 @12fps：蓄力后坐约在 t≈0.45 秒（≈0.32 × 时长）到达峰值，
## 炮弹就在这一刻甩出去
@export var shoot_delay := 0.45
#endregion


#region 动画常量
const STATE_IDLE := &"MortarShroom_idle"
const STATE_SHOOTING := &"MortarShroom_shooting"
const STATE_SLEEP := &"MortarShroom_sleep"
#endregion

## 检测框里有敌人（由 `DetectComponent` 的两个信号维护）
var _has_enemy := false


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
	## 蘑菇白天睡觉：进 / 出睡眠时换姿势（本体的蘑菇靠 AnimationTree 的状态机，
	## 这株没有 AnimationTree，只能自己听信号）
	sleep_component.signal_is_sleep.connect(_on_sleep_start)
	sleep_component.signal_not_is_sleep.connect(_on_sleep_end)
	## 关卡全场加速（「僵尸快跑」）要连冷却与动画一起加速
	signal_update_speed.connect(_on_update_speed)


## 初始化正常出战角色
func ready_norm() -> void:
	super()
	## `super()` 里可能已经按白天进入睡眠并播了睡眠姿势 —— 别再用待机盖掉
	if not is_sleeping:
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


## 开一次攻击：播 `shooting`（单次），炮弹在 `shoot_delay` 后抛出去
func _start_attack() -> void:
	if is_death or is_sleeping:
		return
	_anim_player.play(STATE_SHOOTING)
	## 用无参 start：让 `_on_update_speed()` 折算过的 `wait_time` 生效
	_attack_cd_timer.start()
	_shoot_timer.start()


## 抛一颗炮弹：目标在**这一刻**重新取（僵尸一直在走，早先记住的位置会过期）
func _shoot_bullet() -> void:
	if is_death or is_sleeping or not _has_enemy:
		return
	var target: Character000Base = _detect_component.update_first_enemy()
	if not is_instance_valid(target):
		return
	var main_game := get_main_game()
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.bullets):
		return
	var bullets: Node2D = main_game.bullets
	## 闸门被占住时（联机客户端）这一颗不造：与 `BulletRegistry.create_bullet()` 同一条闸门
	if GlobalUtils.bullet_spawn_gate.is_valid() and bool(GlobalUtils.bullet_spawn_gate.call()):
		return
	## 抛物线子弹的落点：目标活着就每帧跟（见 `BulletMovementParabola`），
	## 这里先给一个“发射时”的位置，目标半路死掉也有终点可落
	var target_pos := target.global_position
	if is_instance_valid(target.hurt_box_component):
		target_pos = target.hurt_box_component.global_position
	var status := _detect_component.can_attack_status_component
	var bullet_damage_value := bullet_damage
	## 角色自己的 `attack_value` 有值就按它来（与本体「攻击力字段接入子弹伤害」同一条优先级）
	if attack_value > 0:
		bullet_damage_value = attack_value
	var bullet: Bullet000Base = SHELL_SCENE.instantiate() as Bullet000Base
	if bullet == null:
		return
	## 走模组自己的场景，所以注册表那套「领号」也得自己补上（见 `Bullet000Base.entity_id`）
	bullet.entity_id = Character000Base.take_next_entity_id()
	var paras: Dictionary[Bullet000NormBase.E_InitParasAttr, Variant] = {
		## 投手只打本行：抛物线子弹照样可以用行属性（它的命中靠攻击框与受击框重叠）
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: true,
		Bullet000NormBase.E_InitParasAttr.BulletLane: lane,
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(_marker.global_position),
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.RIGHT,
		## 抛物线专用：目标 + 目标位置（缺了这两个键，贝塞尔曲线会落在原点）
		Bullet000NormBase.E_InitParasAttr.Enemy: target,
		Bullet000NormBase.E_InitParasAttr.EnemyGloPos: target_pos,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState: status.can_attack_plant_status,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState: status.can_attack_zombie_status,
		Bullet000NormBase.E_InitParasAttr.BulletCamp: CharacterRegistry.CharacterType.Plant,
		Bullet000NormBase.E_InitParasAttr.AttackValue: bullet_damage_value,
	}
	bullet.init_bullet(paras)
	bullets.add_child(bullet)
	SoundManager.play_character_SFX(&"Throw")


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
## 一段动画播完：shooting / idle 都回到待机（睡着时回睡眠姿势）
func _on_animation_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if anim_name == STATE_SHOOTING or anim_name == STATE_IDLE:
		if is_sleeping:
			_play_sleep()
		else:
			_play_idle()


func _on_sleep_start() -> void:
	if is_death:
		return
	## 睡着就不再打：开火计时器一起停（检测组件已由本体按 Sleep 因子禁用）
	_shoot_timer.stop()
	_play_sleep()


func _on_sleep_end() -> void:
	if is_death:
		return
	_play_idle()


## 待机是循环的：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)


## 睡眠段也是循环的
func _play_sleep() -> void:
	if _anim_player.current_animation == STATE_SLEEP and _anim_player.is_playing():
		return
	_anim_player.play(STATE_SLEEP)
#endregion
