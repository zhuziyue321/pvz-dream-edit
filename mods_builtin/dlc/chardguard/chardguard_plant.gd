extends Plant000Base
## 甜菜守卫（DLC 的 ChardGuard，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**高血量的防御植物 + 近战击退** —— 僵尸从右边凑过来想啃它时，
##   甜菜守卫抡起胳膊把对方**往后（右）崩飞一截**，一共能崩 **3 次**；3 次用完就变成
##   `idle_broken` 的「普通墙」，不再出拳，只能硬扛着被啃（靠高血量拖时间）。
##
## ★ 为什么是「击退」而不是「伤害」：原版甜菜守卫那一拳不造成伤害，只把僵尸打退，
##   僵尸得重新走回来，走回来又被崩飞 —— 直到 3 次击退额度用完。所以这里**不走
##   `DamageSystem`**，直接把僵尸的 `position.x` 往右加一截（僵尸一直在往左走，
##   这一截就是净后退；`MoveComponent` 每帧只按 ground / 速度的增量改 position.x，
##   不会把这一截抹掉）。要改成「带伤害的击退」在 `_on_punch_timer_timeout()` 里
##   补一次 `DamageInfo.create(...) + apply_damage()` 即可（口径见菜问 / 地刺）。
##
## ★ 为什么不用本体的 `AttackComponentBulletBase`：那条路的攻击节奏靠
##   `AnimationTree.set(...)` 驱动，而 DLC 动画只有 `AnimationPlayer`、没有
##   `AnimationTree`（`@onready var animation_tree = $"../AnimationTree"` 会报
##   「Node not found」）。所以照拳击白菜 / 国王仙人掌那条路，自己挂 `DetectComponent`
##   + 冷却计时器，逻辑全写在脚本里。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/ChardGuard/ChardGuard.tscn`），
##   三段合成进同一条动画库 `AnimLib`：
##     · `ChardGuard_idle`（1.5 秒）：站着待机（满血姿态）
##     · `ChardGuard_attack`（0.9167 秒）：抡胳膊崩飞，t≈0.5 秒崩出去
##     · `ChardGuard_idle_broken`：3 次击退用完后的「残血」待机姿态
##
## ★ 数值都是**模组自己的取值**，不是照 wiki 抄的 —— 要对齐请自己查过再改。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_chardguard.tscn` 按路径引用。

@onready var _anim_player: AnimationPlayer = $Body/ChardGuardAnim/AnimLib
@onready var _detect_component: DetectComponent = $DetectComponent
@onready var _attack_cd_timer: Timer = $AttackCdTimer
## 从出拳动画开始到真正崩飞的延迟计时器（单次）
@onready var _punch_timer: Timer = $PunchTimer


#region 数值（模组自己的取值；对齐 wiki 的那几项写在文件头）
## 一共能击退几次：用完就变 idle_broken（wiki：三片叶子，掉光后成纯肉盾）
@export var max_punches := 3
## 每次击退把僵尸往右崩多远（像素）。僵尸从右往左走，+x = 往后（右）崩。
## wiki 正文「knocks back ... by three tiles」→ 3 格 × 76 px/格 = 228 px
@export var knockback_distance := 228.0
## 出拳间隔（秒）：必须**长于** `ChardGuard_attack` 的时长（0.9167 秒），
## 否则 CD 到点时出拳动画还没播完就被 `play()` 从头重置 —— 看着像「动画和崩飞对不上」
@export var attack_cd := 1.2
## 从出拳动画开始到真正崩飞的延迟（秒）：`ChardGuard_attack` 抡胳膊的峰值约在 t≈0.5 秒
@export var punch_delay := 0.5
#endregion


#region 动画常量
const STATE_IDLE := &"ChardGuard_idle"
const STATE_ATTACK := &"ChardGuard_attack"
const STATE_IDLE_BROKEN := &"ChardGuard_idle_broken"
#endregion


#region 击退特效
## 击退冲击（`chardguard_knock.png`：横向 3 帧、单帧 48×48 的环形冲击波 / 尘土），
## 作用在**被崩飞的僵尸**身上 —— 原来只有自己挥胳膊的 `woosh`，被崩的僵尸身上没有表现
const FX_SCRIPT := preload("../dlc_sprite_fx.gd")
const KNOCK_TEXTURE := preload("chardguard_knock.png")
const KNOCK_FRAMES := 3
## 0.2 秒播完 3 帧：短促，跟着僵尸一起被推走
const KNOCK_FPS := 15.0
## 冲击波落在僵尸身上的高度（僵尸本地坐标，约胸口）
const KNOCK_POSITION := Vector2(0, -40)
#endregion

## 剩余可击退次数
var _punches_left := 0
## 检测框里有敌人（由 `DetectComponent` 的两个信号维护）
var _has_enemy := false


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	_punches_left = max_punches
	## 计时时长以导出值为准：场景里的 `wait_time` 只是编辑器里的默认值，
	## 改 `attack_cd` / `punch_delay` 时不必再回头改两个 Timer
	_attack_cd_timer.wait_time = attack_cd
	_punch_timer.wait_time = punch_delay
	_detect_component.signal_can_attack.connect(_on_can_attack)
	_detect_component.signal_not_can_attack.connect(_on_not_can_attack)
	_attack_cd_timer.timeout.connect(_on_attack_cd_timer_timeout)
	_punch_timer.timeout.connect(_on_punch_timer_timeout)
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


#region 攻击（击退）
func _on_can_attack() -> void:
	_has_enemy = true
	## 刚进范围立刻崩一发，之后交给冷却计时器续上（与本体射手的口径一致）
	if _punches_left > 0 and _attack_cd_timer.is_stopped():
		_start_attack()


func _on_not_can_attack() -> void:
	_has_enemy = false
	## 崩飞后僵尸多半已出框：没有敌人就停表，再进范围时才能「立刻崩第一发」
	_attack_cd_timer.stop()
	_punch_timer.stop()


func _on_attack_cd_timer_timeout() -> void:
	if _has_enemy and _punches_left > 0:
		_start_attack()


## 开一次击退：播 `attack`（单次），真正崩飞在 `punch_delay` 后
func _start_attack() -> void:
	if is_death or _punches_left <= 0:
		return
	_anim_player.play(STATE_ATTACK)
	## 用无参 start：让 `_on_update_speed()` 折算过的 `wait_time` 生效
	_attack_cd_timer.start()
	_punch_timer.start()


## 崩飞一次：把**右边**最近的那只僵尸往右挪一截（不造成伤害，纯击退）
func _on_punch_timer_timeout() -> void:
	if is_death or _punches_left <= 0:
		return
	var target := _find_target()
	if not is_instance_valid(target):
		return
	## 击退 = 直接把僵尸往右挪一截（僵尸一直在往左走，这一截是净后退）
	target.position.x += knockback_distance
	_spawn_knock_fx(target)
	SoundManager.play_character_SFX(&"Throw")
	_punches_left -= 1
	if _punches_left <= 0:
		## 击退额度用完：不再起新拳（冷却表掐掉），让当前这拳播完再由
		## `_on_animation_finished` 换成 idle_broken 姿态
		_attack_cd_timer.stop()


## 崩飞的冲击波：挂在**僵尸**身上（僵尸一直往左走，冲击波跟着它一起被推走）
func _spawn_knock_fx(target: Zombie000Base) -> void:
	var fx := FX_SCRIPT.new()
	fx.position = KNOCK_POSITION
	target.add_child(fx)
	## 先入树再 setup：`play()` 离树跑不动（见 `dlc_sprite_fx.gd` 文件头）
	fx.setup(KNOCK_TEXTURE, KNOCK_FRAMES, KNOCK_FPS)


## 挑目标：检测框里**靠右**（正凑过来啃它）的最近那只僵尸
##
## 僵尸从右往左走，只有右边那只才在啃它 —— 左边的（理论上不会有）不打。
func _find_target() -> Zombie000Base:
	var nearest: Zombie000Base = null
	var nearest_dist := INF
	for enemy in _detect_component.get_all_enemy_can_be_attacked():
		var zombie := enemy as Zombie000Base
		if zombie == null or zombie.is_death:
			continue
		var dx := zombie.global_position.x - global_position.x
		if dx <= 0.0:
			continue
		if dx < nearest_dist:
			nearest_dist = dx
			nearest = zombie
	return nearest
#endregion


#region 全场加速
## 全场加速：冷却按倍率折算（与 `AttackComponentBulletBase.owner_update_speed` 同口径）
func _on_update_speed(speed_product: float) -> void:
	if speed_product == 0:
		_attack_cd_timer.paused = true
		_punch_timer.paused = true
		_anim_player.speed_scale = 0.0
		return
	_attack_cd_timer.paused = false
	_punch_timer.paused = false
	_anim_player.speed_scale = speed_product
	if not _attack_cd_timer.is_stopped():
		_attack_cd_timer.start(_attack_cd_timer.time_left / speed_product)
	_attack_cd_timer.wait_time = attack_cd / speed_product
	_punch_timer.wait_time = punch_delay / speed_product
#endregion


#region 动画回调
## 一段动画播完：待机 / 出拳都按「还有没有击退额度」决定回满血待机还是残血待机
func _on_animation_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if _punches_left <= 0:
		## 残血姿态：出拳播完 / 待机转到这里都停在 idle_broken
		_play_idle_broken()
		return
	if anim_name == STATE_ATTACK or anim_name == STATE_IDLE:
		_play_idle()


## 满血待机是循环的：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)


## 残血待机也是循环的
func _play_idle_broken() -> void:
	if _anim_player.current_animation == STATE_IDLE_BROKEN and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE_BROKEN)
#endregion
