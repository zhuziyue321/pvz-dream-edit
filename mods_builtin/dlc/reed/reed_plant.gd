extends Plant000Base
## 闪电芦苇（DLC 的 Reed，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**短距索敌 + 链状闪电** —— 本行内有僵尸进入短距检测框就放电；
##   闪电先打**最近**的那只僵尸，再沿「离上一击最近的、且没被打过的僵尸」连锁跳到最多 2 只
##   （充能后 4 只），每一击都造成等量伤害，相邻两点之间画一道电弧。
##
## ★ 索敌**跨三行**（wiki `range = Three lanes`，所以 `DetectComponent.is_lane = false`）：
##   检测框是一块覆盖本行与上下各一行的矩形，僵尸进框就打，出框就停手（见场景注释）。
##
## ★ 链状闪电不走子弹：打出的瞬间直接经伤害管线 `DamageSystem.apply()` 结算每一段，
##   再用 `reed_lightning.tscn` 补一道瞬时电弧特效（植物自己的场景，无贴图、纯 `draw_line`）。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/Reed/Reed.tscn`），
##   合成进同一条动画库 `AnimLib`：
##     · `Reed_idle`（1.29 秒）：站着待机
##     · `Reed_attack`（0.708 秒）：放电动作，`shoot_delay` 处落雷
##     · `Reed_idle_charged`：充能待机（本株暂不切到这条，只作数值上的「充能」）
##     · `Reed_blink` / `Reed_face`：本株不用
##
## ★ 为什么不用本体的 `AttackComponentBulletBase`：那条路的攻击节奏靠 `AnimationTree` 驱动，
##   而 DLC 动画只有 `AnimationPlayer`（见 kingcactus / pultshroom 同一条理由），
##   所以自己挂 `DetectComponent` + 冷却计时器，发射逻辑直接走 `DamageSystem`。
##
## ★ 数值都是**模组自己的取值**，不是照 wiki 抄的 —— 要对齐请自己查过再改。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_reed.tscn` 按路径引用。

## 链状闪电特效（模组自己的场景，纯 draw_line）
const LIGHTNING_SCENE := preload("reed_lightning.tscn")

@onready var _anim_player: AnimationPlayer = $Body/ReedAnim/AnimLib
@onready var _detect_component: DetectComponent = $DetectComponent
@onready var _attack_cd_timer: Timer = $AttackCdTimer
@onready var _shoot_timer: Timer = $ShootTimer
## 闪电落点（植物头部，见场景注释）
@onready var _marker: Marker2D = $Body/Marker2D


#region 数值（阳光 / 冷却 / 伤害 / 攻击间隔对齐 DLC Edition wiki 的 Lightning Reed 页：
## 125 阳光 / 冷却 7.5 秒 fast / 伤害 10 / 攻击间隔 1.5 秒 / 射程 Three lanes）
## 每段闪电的伤害：wiki 的 `damage = 10`
@export var bullet_damage := 10
## 攻击间隔（秒）：wiki 的 `firerate = 1.5`
## 必须**长于** `Reed_attack` 的时长（0.708 秒），否则 CD 到点动画还没播完就被重置
@export var attack_cd := 1.5
## 从开火动画开始到落雷的延迟（秒）：`Reed_attack` 0.708 秒，雷在动作中段落下
@export var shoot_delay := 0.4
## 一次连锁最多打几只（含首发）
@export var max_chain := 3
## 相邻两跳之间的最大距离（像素）：超过就不跳
@export var chain_range := 130.0
## 攻击这么多次后进入「充能」状态（多打几只、多扣点血）
@export var charge_threshold := 4
## 充能后每段额外多打几只
@export var charged_extra_chain := 2
## 充能后每段额外多扣的血
@export var charged_extra_damage := 5
#endregion


#region 动画常量
const STATE_IDLE := &"Reed_idle"
const STATE_ATTACK := &"Reed_attack"
#endregion


#region 音效
## 放电音效（DLC 自己的三条 zap，随机取一条）：原来借的是本体 `Throw`（投掷声），跟放电完全不搭
const ZAP_SFX: Array[AudioStream] = [
	preload("../audio/reed_zap.ogg"),
	preload("../audio/reed_zap2.ogg"),
	preload("../audio/reed_zap3.ogg"),
]
## 充能后的远距雷声（DLC 的三条 lightning，随机取一条）：
## 只在充能后叠在 zap 上，给「攒满了」一个更沉的收尾
const THUNDER_SFX: Array[AudioStream] = [
	preload("../audio/lightning.ogg"),
	preload("../audio/lightning2.ogg"),
	preload("../audio/lightning3.ogg"),
]
#endregion

## 检测框里有敌人（由 `DetectComponent` 的两个信号维护）
var _has_enemy := false
## 已经打了多少次：用来判断要不要进「充能」
var _attack_count := 0


#region 生命周期
func ready_norm_signal_connect() -> void:
	super()
	## 计时时长以导出值为准：改 `attack_cd` / `shoot_delay` 时不必回头改两个 Timer
	_attack_cd_timer.wait_time = attack_cd
	_shoot_timer.wait_time = shoot_delay
	_detect_component.signal_can_attack.connect(_on_can_attack)
	_detect_component.signal_not_can_attack.connect(_on_not_can_attack)
	_attack_cd_timer.timeout.connect(_on_attack_cd_timer_timeout)
	_shoot_timer.timeout.connect(_zap)
	_anim_player.animation_finished.connect(_on_animation_finished)
	## 关卡全场加速（「僵尸快跑」）要连冷却与动画一起加速
	signal_update_speed.connect(_on_update_speed)


func ready_norm() -> void:
	super()
	_play_idle()


func ready_show() -> void:
	super()
	_play_idle()


func ready_garden() -> void:
	super()
	_play_idle()
#endregion


#region 攻击
func _is_charged() -> bool:
	return _attack_count >= charge_threshold


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


## 开一次攻击：播 `attack`（单次），雷在 `shoot_delay` 后落下
func _start_attack() -> void:
	if is_death:
		return
	_anim_player.play(STATE_ATTACK)
	## 用无参 start：让 `_on_update_speed()` 折算过的 `wait_time` 生效
	_attack_cd_timer.start()
	_shoot_timer.start()


## 落雷：链式选取目标 → 逐段结算伤害 → 画电弧
func _zap() -> void:
	if is_death or not _has_enemy:
		return
	## `.duplicate()`：`get_all_enemy_can_be_attacked()` 返回的是检测组件内部缓冲的引用，
	## 下面要 sort / erase，就地改会污染组件状态
	## 复制一份带类型的列表：`get_all_enemy_can_be_attacked()` 返回的是检测组件内部缓冲的引用，
	## 下面要 sort / erase，就地改会污染组件状态（`.duplicate()` 会退化成无类型 Array，
	## 迭代出的元素是 Variant，这里显式建成 `Array[Character000Base]`）
	var pool: Array[Character000Base] = []
	for enemy in _detect_component.get_all_enemy_can_be_attacked():
		pool.append(enemy)
	if pool.is_empty():
		return
	var origin := _marker.global_position
	## 按离植物由近到远排序，首发打最近的
	pool.sort_custom(func(a: Character000Base, b: Character000Base) -> bool:
		return a.global_position.distance_to(origin) < b.global_position.distance_to(origin))
	var chain_count := max_chain + (charged_extra_chain if _is_charged() else 0)
	var dmg := bullet_damage + (charged_extra_damage if _is_charged() else 0)
	## 角色自己的 `attack_value` 有值就按它来（与本体「攻击力字段接入子弹伤害」同一条优先级）
	if attack_value > 0:
		dmg = attack_value

	var chain: Array[Character000Base] = []
	var current := origin
	for i in range(chain_count):
		var best: Character000Base = null
		var best_d := INF
		## 首发从植物出发（不限距），后续跳跃受 `chain_range` 限制
		var limit := chain_range if i > 0 else INF
		for e in pool:
			var d := e.global_position.distance_to(current)
			if d <= limit and d < best_d:
				best = e
				best_d = d
		if best == null:
			break
		chain.append(best)
		pool.erase(best)
		current = best.global_position

	## 逐段走伤害管线；并把相邻两点收进电弧
	var pts := PackedVector2Array()
	pts.append(origin - global_position)
	for c in chain:
		## 同一帧里前一段把某个目标打死、或它被别的来源清掉时，引用可能已失效，跳过这一段
		if not is_instance_valid(c):
			continue
		DamageSystem.apply(DamageInfo.create(
			c, dmg, ConstDamage.E_DamageMode.Real, ConstDamage.E_DamageCause.Bullet))
		pts.append(c.global_position - global_position)
	_spawn_lightning(pts)
	_attack_count += 1
	SoundManager.play_sfx_with_pool(ZAP_SFX.pick_random())
	## 充能后多一道远距雷声（先记 `_attack_count` 再判，这一发算进充能）
	if _is_charged():
		SoundManager.play_sfx_with_pool(THUNDER_SFX.pick_random())


## 把一串本地坐标点交给电弧特效（相对父节点 = 植物，落点正是植物原点）
func _spawn_lightning(local_points: PackedVector2Array) -> void:
	if local_points.size() < 2:
		return
	var fx: Node2D = LIGHTNING_SCENE.instantiate()
	fx.points = local_points
	add_child(fx)


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
## 一段动画播完：attack / idle 都回到待机
func _on_animation_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if anim_name == STATE_ATTACK or anim_name == STATE_IDLE:
		_play_idle()


## 待机是循环的：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)
#endregion
