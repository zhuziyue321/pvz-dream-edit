extends Plant000Base
## 芦荟（DLC 的 AloeVera，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**范围治疗，不攻击** —— 每隔 `heal_interval` 秒，把自己 3×3 范围内
##   血量未满的植物各回 `heal_amount` 点血；没敌人要打，所以**不挂检测组件**
##   （索敌 / 出弹那套它完全用不上），自写一个 `HealAreaComponent`
##   （Area2D 罩住周围 3×3，只监听植物的受击框层）代替。
##
## ★ 数值照 DLC Edition 的 wiki（Aloe Vera 页）：50 阳光 / 冷却 7.5 秒（fast）/ 生命 300 /
##   3×3 群体治疗 / 每 3 秒治疗一次 / **多株不叠加**；页面没给单次治疗量，
##   这里按模组取值 30（300 血满血约 10 次治疗量，节奏与治疗动画匹配）。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/AloeVera/AloeVera.tscn`），
##   四段都在同一条动画库 `AnimLib` 里：
##     · `AloeVera_idle`（1.333 秒，循环）：站着待机
##     · `AloeVera_heal`（1.167 秒）：治人时的治疗动作
##     · `AloeVera_blink` / `AloeVera_face`：本株不用（待机段自带眨眼，脚本只切 idle/heal）
##
## ★ 为什么不用本体的 `AttackComponent*`：那条路是「索敌 → 出子弹 / 出拳」，
##   而治疗既不索敌也不出弹。但仍照 BonkChoy / PultShroom 的模组口径自己挂
##   Area2D + 计时器（这里换成治疗版），因为 DLC 动画只有 `AnimationPlayer`、
##   没有 `AnimationTree`（本体攻击组件的 `@onready var animation_tree = $"../AnimationTree"`
##   会在场景加载时报「Node not found」）。
##
## ★ 全场加速：与 `AttackComponentBulletBase.owner_update_speed` 同口径 ——
##   `speed_product == 0` 时暂停计时器与动画，否则折算 `wait_time` 与剩余时间。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类（实测 Godot 4.6.2），
##    所以这里不写 class_name、全局类型只引用本体的，由同目录的 `plant_aloe.tscn` 按路径引用。

## 动画播放器：藏在 `Body` 下面（`Body` 是角色基类的节点，带 `BodyCharacter` 脚本）
@onready var _anim_player: AnimationPlayer = $Body/AloeVeraAnim/AnimLib
## 治疗范围组件：罩住本株周围 3×3 的 Area2D（见同目录 `aloe_heal_area_component.gd`）
## 不写类型：该脚本在 `user://` 下没有全局类名，按 Variant 走鸭子类型调用
@onready var _heal_area = $HealAreaComponent
## 治疗间隔计时器（与攻击冷却同一个口径：每治完一轮重记）
@onready var _heal_cd_timer: Timer = $HealCdTimer


#region 数值（wiki 的那几项写在文件头，治疗量是模组取值）
## 单次治疗量（对范围内每株受伤植物各加这么多）
@export var heal_amount := 30
## 治疗间隔（秒）：必须**长于** `AloeVera_heal` 的时长（1.167 秒），
## 否则 CD 到点时治疗动画还没播完就被 `play()` 从头重置 —— 看起来像「动画和治疗不同步」
@export var heal_interval := 3.0
#endregion


#region 动画常量
const STATE_IDLE := &"AloeVera_idle"
const STATE_HEAL := &"AloeVera_heal"

## 目标植物上记录「上一次被治疗的时刻（毫秒）」，多株芦荟不叠加治疗量（见 `_heal_once()`）
const META_LAST_HEAL_MS := &"_dlc_aloe_last_heal_ms"

## 治疗特效：作用在被治疗的**植物**身上（不是芦荟自己身上）——
## 原来只有芦荟自己叶子动，被治的植物身上什么都没发生，玩家看不出它到底有没有在工作
const FX_SCRIPT := preload("../dlc_sprite_fx.gd")
const HEAL_TEXTURE := preload("aloe_heal.png")
## `aloe_heal.png` 是横向 4 帧、单帧 64×64 的柔光 / 上升光点
const HEAL_FRAMES := 4
## 0.5 秒播完 4 帧（比 3 秒的治疗间隔短得多，看着就是「补了一下」）
const HEAL_FPS := 8.0
## 光落在被治疗植物身上的高度（植物本地坐标，约胸口）
const HEAL_FX_POSITION := Vector2(0, -30)
#endregion


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	## 把宿主注入组件（组件不自己去 `get_parent()` 抓宿主，见组件文件头）
	_heal_area.host_character = self
	_heal_area.signal_can_heal.connect(_on_can_heal)
	_heal_area.signal_not_can_heal.connect(_on_not_can_heal)
	## 按导出值再设一次 `wait_time`（场景里的值只作默认，改导出值不会自动同步到 Timer）
	_heal_cd_timer.wait_time = heal_interval
	_heal_cd_timer.timeout.connect(_on_heal_cd_timer_timeout)
	_anim_player.animation_finished.connect(_on_animation_finished)
	## 关卡全场加速（「僵尸快跑」）要连治疗间隔与动画一起加速
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


#region 治疗
## 范围内出现可以治疗的植物 → 立刻治一轮（与本体射手「刚进范围先打一发」同口径）
func _on_can_heal() -> void:
	if _heal_cd_timer.is_stopped():
		_heal_once()


## 范围内没有可治疗的植物 → 停表：再有人受伤时才能「立刻治第一轮」
func _on_not_can_heal() -> void:
	_heal_cd_timer.stop()


func _on_heal_cd_timer_timeout() -> void:
	_heal_once()


## 治一轮：播治疗动画 + 给范围内每株受伤植物回血，随后开始下一轮冷却计时
func _heal_once() -> void:
	if is_death or is_queued_for_deletion():
		return
	var targets: Array = _heal_area.get_all_can_be_heal()
	var now := Time.get_ticks_msec()
	var healed_any := false
	for target: Plant000Base in targets:
		if not is_instance_valid(target) or target.is_death or target == self:
			continue
		var hp: HpComponent = target.hp_component
		if hp == null or hp.is_death:
			continue
		## 多株芦荟**不叠加**（wiki：Heals adjacent plants, does not stack）：
		## 同一轮治疗窗口里已被别的芦荟治过就跳过 —— 每株受伤植物每 `heal_interval`
		## 只吃一次治疗量，场上摆一排芦荟也不会成倍回血
		var last_ms: int = target.get_meta(META_LAST_HEAL_MS, -1000000)
		if now - last_ms < int(heal_interval * 750.0):
			continue
		if hp.hp_heal(heal_amount) > 0:
			target.set_meta(META_LAST_HEAL_MS, now)
			healed_any = true
			_spawn_heal_fx(target)
	if healed_any:
		_anim_player.play(STATE_HEAL)
		SoundManager.play_character_SFX(&"PlantGrow")
	## 只要范围里还有受伤植物就续上下一轮（可能本轮因为「不叠加」全跳过，
	## 不能把"这轮没治到"当成没目标，否则它会被自己的冷却表卡死）
	if not targets.is_empty():
		## 用无参 start：让 `_on_update_speed()` 折算过的 `wait_time` 生效
		_heal_cd_timer.start()


## 在被治疗的植物身上放一段治疗光（`aloe_heal.png` 播一遍）
## 挂在目标植物下：目标被铲 / 被吃时特效跟着一起走，不用另外清理
func _spawn_heal_fx(target: Plant000Base) -> void:
	var fx := FX_SCRIPT.new()
	fx.position = HEAL_FX_POSITION
	target.add_child(fx)
	## 先入树再 setup：`play()` 离树跑不动（见 `dlc_sprite_fx.gd` 文件头）
	fx.setup(HEAL_TEXTURE, HEAL_FRAMES, HEAL_FPS)
#endregion


#region 全场加速
## 全场加速：治疗间隔按倍率折算（与 `AttackComponentBulletBase.owner_update_speed` 同口径）
func _on_update_speed(speed_product: float) -> void:
	if speed_product == 0:
		_heal_cd_timer.paused = true
		_anim_player.speed_scale = 0.0
		return
	_heal_cd_timer.paused = false
	_anim_player.speed_scale = speed_product
	if not _heal_cd_timer.is_stopped():
		_heal_cd_timer.start(_heal_cd_timer.time_left / speed_product)
	_heal_cd_timer.wait_time = heal_interval / speed_product
#endregion


#region 动画回调
## 一段动画播完：治疗动画回待机（待机是循环的，正常走不到这里，兜底）
func _on_animation_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if anim_name == STATE_HEAL:
		_play_idle()


## 待机是循环的：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)
#endregion
