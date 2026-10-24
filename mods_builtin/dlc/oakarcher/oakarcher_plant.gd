extends Plant000Base
## 橡木弓箭手（DLC 的 Oak Archer，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**本行直线射手** —— 本行右侧 9 格内有僵尸就朝右射一支箭，
##   箭走本体匀速直线（`bullet_cactus.tscn` 那条路），撞上僵尸即命中。
##   不是蘑菇，白天不睡觉。
##
## ★ 数值（DLC Edition 的 wiki：Oak Archer 页）：
##   阳光 200 / 冷却 7.5 秒（fast）/ 伤害 80（普通攻击，wiki 带问号；暴击 160 未实现）/
##   射程 1x9（本行 9 格）/ 攻击间隔 4.25 秒 / 生命 300（本体默认）。
##   本体 9 格 = 76 × 9 = 684 px。
##
## ★ 为什么不用本体的 `AttackComponentBulletBase`：那条路的攻击节奏靠
##   `AnimationTree.set("parameters/OneShot/request")` 驱动，而 DLC 动画只有
##   `AnimationPlayer`、没有 `AnimationTree`（`@onready var animation_tree: AnimationTree = $"../AnimationTree"`
##   会在场景加载时报「Node not found」）。所以照国王仙人掌 / 投掷蘑菇那条路，
##   自己挂 `DetectComponent` + 冷却计时器，发射逻辑直接走模组自己的子弹场景
##   （与它们同一套「领号 + 联机闸门」补法）。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/OakArcher/OakArcher.tscn`），
##   本株只用三段，合成进同一条动画库 `AnimLib`：
##     · `OakArcher_idle`（1.75 秒）：站着待机
##     · `OakArcher_shooting`（0.9167 秒）：拉弓 → 放箭，**弓拉满在 t≈0.17 秒**出箭
##       （量法：持弓手 `Oak_archer_arm1_2` 的 rotation 在 0.17 秒到 -2.142 的最大值，之后回弹；
##         箭矢节点 `Oak_archer_arrow` 的 visible 在第 1 帧后消失 = 已离弦）
##     · `OakArcher_blink`：本株不用（眨眼交给动画自己）
##   （`OakArcher_reload` / `OakArcher_idle_empty` 是原版「射空→装填」的两段，
##     本株按其它 DLC 植物的口径用「待机↔开火」两态，不实现装填轮。）
##
## ★ 数值都是**模组自己的取值**（对齐 wiki 的那几项已写在上面），别照 wiki 再改别的。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_oakarcher.tscn` 按路径引用。

## 箭矢（模组自己的直线子弹，继承本体 `bullet_cactus.tscn`）
const ARROW_SCENE := preload("bullet_oakarcher_arrow.tscn")

@onready var _anim_player: AnimationPlayer = $Body/OakArcherAnim/AnimLib
@onready var _detect_component: DetectComponent = $DetectComponent
@onready var _attack_cd_timer: Timer = $AttackCdTimer
@onready var _shoot_timer: Timer = $ShootTimer
## 箭的出生点（持弓手前方，见场景注释）
@onready var _marker: Marker2D = $Body/Marker2D


#region 数值（模组的取值；对齐 wiki 的那几项写在文件头）
## 一支箭的伤害
@export var bullet_damage := 80
## 攻击间隔（秒）：wiki 的 4.25 秒
## 必须**长于** `OakArcher_shooting` 的时长（11 帧 @12fps ≈ 0.917 秒），
## 否则每轮 CD 到点时开火动画还没播完就被 `play()` 从头重置 —— 看起来就是「动画和发射对不上」
@export var attack_cd := 4.25
## 从开火动画开始到箭离弦的延迟（秒）
## `OakArcher_shooting` 持弓手 rotation 在 t≈0.17 秒拉满、之后回弹放箭
@export var shoot_delay := 0.17
#endregion


#region 动画常量
const STATE_IDLE := &"OakArcher_idle"
const STATE_SHOOTING := &"OakArcher_shooting"
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


## 开一次攻击：播 `shooting`（单次），箭在 `shoot_delay` 后离弦
func _start_attack() -> void:
	if is_death:
		return
	_anim_player.play(STATE_SHOOTING)
	## 用无参 start：让 `_on_update_speed()` 折算过的 `wait_time` 生效
	_attack_cd_timer.start()
	_shoot_timer.start()


## 射一支箭：本行直线往右，撞僵尸即命中（不吃目标键，抛物线才需要）
func _shoot_bullet() -> void:
	if is_death or not _has_enemy:
		return
	var main_game := get_main_game()
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.bullets):
		return
	var bullets: Node2D = main_game.bullets
	## 闸门被占住时（联机客户端）这一支不造：与 `BulletRegistry.create_bullet()` 同一条闸门
	if GlobalUtils.bullet_spawn_gate.is_valid() and bool(GlobalUtils.bullet_spawn_gate.call()):
		return
	var status := _detect_component.can_attack_status_component
	var bullet_damage_value := bullet_damage
	## 角色自己的 `attack_value` 有值就按它来（与本体「攻击力字段接入子弹伤害」同一条优先级）
	if attack_value > 0:
		bullet_damage_value = attack_value
	var bullet: Bullet000Base = ARROW_SCENE.instantiate() as Bullet000Base
	if bullet == null:
		return
	## 走模组自己的场景，所以注册表那套「领号」也得自己补上（见 `Bullet000Base.entity_id`）
	bullet.entity_id = Character000Base.take_next_entity_id()
	var paras: Dictionary[Bullet000NormBase.E_InitParasAttr, Variant] = {
		## 直线射手只打本行：子弹照样吃行属性（命中靠攻击框与受击框重叠 + 行判定）
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: true,
		Bullet000NormBase.E_InitParasAttr.BulletLane: lane,
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(_marker.global_position),
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.RIGHT,
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
