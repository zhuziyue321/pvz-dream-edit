extends Plant000Base
## 电击蘑菇（DLC 的 VoltShroom，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**周围持续放电 AOE** —— 3×5 范围内有僵尸就先蓄电（`VoltShroom_charge`），
##   蓄满放电（`VoltShroom_shooting`）的瞬间把**这一轮的总输出均分**给范围内所有僵尸，
##   只要还有目标就一轮接一轮地放（wiki `firerate = Constant`），目标清空才停下。
##   白天睡觉（蘑菇类，`SleepComponent.is_sleep_in_day`），夜里才工作。
##
## ★ 数值（对齐 wiki 的 Volt-shroom 页；旧值是模组自定的，已按 wiki 改过）：
##   225 阳光 / 冷却 7.5 秒（fast）/ 放电「单目标约 40 DPS，多个目标之间均分」/ 生命 300 /
##   射程 3×5（**跨行**，所以检测组件 `is_lane = false`）/ 白天睡觉。
##
## ★ 为什么不用本体攻击组件：同投掷蘑菇 / 环轨仙人掌 —— DLC 动画只有 `AnimationPlayer`、
##   没有 `AnimationTree`，本体的 `AttackComponentBullet*` 在场景加载时会因
##   `$"../AnimationTree"` 取不到节点直接报错。所以自己挂 `DetectComponent` + 冷却计时器，
##   放电是 **AOE 直伤**（不发射子弹），用 `DetectComponent.get_all_enemy_can_be_attacked()`
##   拿范围内所有僵尸，逐个走 `DamageSystem.apply()`（全仓唯一伤害入口）。
##
## ★ 动画五段合成进同一个 `AnimLib`（覆盖转换工具那条只有 `ALL_ANIMS` 的合并库）：
##     · `VoltShroom_idle`（1.5s）    待机（循环）
##     · `VoltShroom_charge`（0.667s）蓄电（单次）
##     · `VoltShroom_shooting`（0.333s）放电（zap 在这段闪现；伤害在播它的那一刻结算）
##     · `VoltShroom_fin`（0.333s）   收尾（单次）
##     · `VoltShroom_sleep`（1.5s）   白天睡觉姿势（循环）
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类（实测 Godot 4.6.2），
##    所以这里不写 class_name，由同目录 `plant_voltshroom.tscn` 按路径引用。

const STATE_IDLE := &"VoltShroom_idle"
const STATE_CHARGE := &"VoltShroom_charge"
const STATE_SHOOTING := &"VoltShroom_shooting"
const STATE_FIN := &"VoltShroom_fin"
const STATE_SLEEP := &"VoltShroom_sleep"

## 放电音效（DLC 自己的 `voltage` / `electric_zap`，随机取一条）：
## 原来借的是本体 `Throw`（投掷声），放电听着像在扔东西
const ZAP_SFX: Array[AudioStream] = [
	preload("../audio/voltage.ogg"),
	preload("../audio/electric_zap.ogg"),
]

@onready var _anim_player: AnimationPlayer = $Body/VoltShroomAnim/AnimLib
@onready var _detect_component: DetectComponent = $DetectComponent
@onready var _attack_cd_timer: Timer = $AttackCdTimer


#region 数值（对齐 DLC Edition wiki 的 Volt-shroom 页：225 阳光 / 冷却 7.5 秒 fast /
## 伤害「potent（单目标约 40 DPS），在多个僵尸之间均分」/ 生命 300 / 射程 3×5 / 白天睡觉）
## 放电的**每秒总输出**：wiki 写「单目标约 40 DPS」—— 这里按总输出记，
## 只有一个目标时它挨满 40，多个目标就除以目标数（见 `_apply_aoe_damage()`）
@export var discharge_dps := 40.0
## 一轮「蓄电 → 放电 → 收尾」的总时长（秒）：三段动画 0.667 + 0.333 + 0.333 ≈ 1.33，
## 用来把「每秒输出」折算成「每轮输出」
const DISCHARGE_PERIOD := 1.33
## 两轮放电之间的额外冷却（秒）：wiki `firerate = Constant` —— 有目标就连着放，默认不等。
## 留成导出值是为了给「想让它喘口气」的场景留口子；为 0 时不起表，下一轮由收尾段直接接上
@export var attack_cd := 0.0
#endregion

## 检测框里有敌人（由 `DetectComponent` 的两个信号维护）
var _has_enemy := false
## 正在走「蓄电 → 放电 → 收尾」这段序列：序列中不响应新一轮开火
var _is_attacking := false


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	## 计时时长以导出值为准：场景里的 `wait_time` 只是编辑器默认值，
	## 改 `attack_cd` 时不必再回头改 Timer
	_attack_cd_timer.wait_time = attack_cd
	_detect_component.signal_can_attack.connect(_on_can_attack)
	_detect_component.signal_not_can_attack.connect(_on_not_can_attack)
	_attack_cd_timer.timeout.connect(_on_attack_cd_timer_timeout)
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
	## 刚进范围立刻放一发，之后交给冷却计时器续上（与本体射手的口径一致）
	if _attack_cd_timer.is_stopped() and not _is_attacking:
		_start_attack()


func _on_not_can_attack() -> void:
	_has_enemy = false
	## 没有敌人就停表：再进范围时才能「立刻放第一发」
	_attack_cd_timer.stop()


func _on_attack_cd_timer_timeout() -> void:
	if _has_enemy and not _is_attacking and not is_sleeping:
		_start_attack()


## 开一次放电：播 `charge`（蓄电，单次），并同时起冷却表
func _start_attack() -> void:
	if is_death or is_sleeping or _is_attacking:
		return
	_is_attacking = true
	_anim_player.play(STATE_CHARGE)
	## 持续放电（wiki `firerate = Constant`）：`attack_cd` 为 0 时不起表，
	## 下一轮由 `_on_animation_finished()` 的收尾分支直接接上
	if attack_cd > 0.0:
		_attack_cd_timer.start()


## 一段动画播完：驱动「蓄电 → 放电（结算伤害）→ 收尾 → 回待机」这条链
func _on_animation_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if anim_name == STATE_CHARGE:
		if is_sleeping:
			return
		_anim_player.play(STATE_SHOOTING)
		## 放电这一帧：对范围内所有僵尸结算一次性高伤害
		_apply_aoe_damage()
	elif anim_name == STATE_SHOOTING:
		_anim_player.play(STATE_FIN)
	elif anim_name == STATE_FIN:
		_is_attacking = false
		if is_sleeping:
			_play_sleep()
		elif _has_enemy:
			## 范围内还有目标就接着放下一轮（wiki `firerate = Constant`）
			_start_attack()
		else:
			_play_idle()


## AOE 直伤：把这一轮的总输出**均分**给范围内所有目标（不发射子弹）。
##
## wiki：`damage = potent (~40 DPS for one target), divides between several zombies` ——
## 先按本轮时长把 DPS 折成这一轮的总输出，再除以目标数：只有一个目标时它挨满，
## 目标越多每个挨到的越少（**总输出恒定，不随目标数放大** —— 这正是 wiki 那句 divides 的意思）。
## 走 `DamageSystem.apply()`（全仓唯一伤害入口），模式 `Real`（跳过二类防具，直打一类防具与本体）。
func _apply_aoe_damage() -> void:
	var enemies := _detect_component.get_all_enemy_can_be_attacked()
	var alive: Array[Character000Base] = []
	for enemy in enemies:
		if is_instance_valid(enemy):
			alive.append(enemy)
	if alive.is_empty():
		return
	var total := roundi(discharge_dps * DISCHARGE_PERIOD)
	## 均分后至少 1 点：目标多到「每人不到 1 点」时不至于变成 0 伤害（整数除法会截断）
	var per_target := maxi(1, total / alive.size())
	for enemy in alive:
		var info := DamageInfo.create(
			enemy, per_target,
			ConstDamage.E_DamageMode.Real, ConstDamage.E_DamageCause.Bomb)
		info.attacker = self
		info.source = self
		DamageSystem.apply(info)
	SoundManager.play_sfx_with_pool(ZAP_SFX.pick_random())


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
#endregion


#region 动画回调
func _on_sleep_start() -> void:
	if is_death:
		return
	## 睡着就不再放：序列与冷却表一起停（检测组件已由本体按 Sleep 因子禁用）
	_is_attacking = false
	_attack_cd_timer.stop()
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
