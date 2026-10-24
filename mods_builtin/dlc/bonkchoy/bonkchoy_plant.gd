extends Plant000Base
## 拳击白菜（DLC 的 BonkChoy，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**近战，不用子弹** —— 检测框铺本行左右两格，框里有僵尸就一拳一拳地打，
##   这一拳能直接打死目标时换成上勾拳（伤害更高）。伤害走 `DamageInfo` + `apply_damage()`，
##   与 `mods_builtin/pvz2/bonkchoy/bonkchoy_plant.gd` 同一套近战口径（那里是 PVZ2 美术，
##   这里是 DLC 的 reanim 动画，攻击判定完全一致）。
##
## ★ 为什么不用本体的 `AttackComponentBulletBase`：那条路的攻击节奏靠
##   `AnimationTree.set("parameters/OneShot/request")` 驱动，而 DLC 动画只有
##   `AnimationPlayer`、没有 `AnimationTree`（`@onready var animation_tree: AnimationTree = $"../AnimationTree"`
##   会在场景加载时报「Node not found」）。所以照 PVZ2 模组菜问那条路，
##   自己挂 `DetectComponent` + 冷却计时器，出拳直接结算伤害。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/BonkChoy/BonkChoy.tscn`），
##   五段都在同一条动画库 `AnimLib` 里：
##     · `BonkChoy_idle`（1.0 秒，循环）：站着待机
##     · `BonkChoy_shooting`（0.833 秒）：直拳（普通拳）
##     · `BonkChoy_uppercut`（0.917 秒）：上勾拳（能斩杀时换这一套）
##     · `BonkChoy_blink` / `BonkChoy_face`：本株不用（眨眼交给动画自己，
##       姿态切换不接 `BlinkComponent`，否则两套会打架）
##
## ★ 数值都是**模组自己的取值**，不是照 wiki 抄的 —— 要对齐请自己查过再改。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_bonkchoy.tscn` 按路径引用。

## 动画播放器：藏在 `Body` 下面（`Body` 是角色基类的节点，带 `BodyCharacter` 脚本）
@onready var _anim_player: AnimationPlayer = $Body/BonkChoyAnim/AnimLib
## 检测组件（与地刺 / 菜问同一条路）：本行左右两格里有僵尸就触发
@onready var _detect_component: DetectComponent = $DetectComponent
## 出拳间隔计时器（没有子弹，自己挂一个）
@onready var _attack_cd_timer: Timer = $AttackCdTimer


#region 数值（阳光 / 冷却 / 伤害 / 攻击间隔对齐 DLC Edition wiki 的 Bonk Choy 页：
## 150 阳光 / 冷却 7.5 秒 fast / 伤害 20 / 攻击间隔 0.36 秒 / 射程 1×2）
## 直拳伤害（这一拳打不死它时用的普通拳）：wiki 的 `damage = 20`
@export var jab_damage := 20
## 上勾拳伤害（这一拳能直接打死它时改用，判定见 `_punches_can_kill()`）：
## wiki 只有常规攻击 20，没有「斩杀拳」这一档 —— 取直拳的 2 倍（**模组自定**）
@export var uppercut_damage := 40
## 出手间隔（秒）：wiki 的 `firerate = 0.36`
@export var attack_cd := 0.36
## 动作段的播放倍率：**两段出拳动画都远长于攻击间隔**（直拳 0.833 秒 / 上勾拳 0.917 秒 vs 0.36 秒），
## 不加速的话每一轮 CD 到点 `play()` 都会把没播完的动作从头重置（拳头卡在半空）。
## 取「段长 ÷ attack_cd」，让一段动作正好在下一拳落下前播完 —— 视觉上就是原版那种快速连打。
## （与「开火动画必须短于攻击间隔」是同一条约束，只是这里靠加速动画来满足，而不是把 CD 拉长）
const JAB_ANIM_SPEED := 2.32		## 0.833 / 0.36
const UPPERCUT_ANIM_SPEED := 2.55	## 0.917 / 0.36
#endregion


#region 动画常量
const STATE_IDLE := &"BonkChoy_idle"
const STATE_SHOOTING := &"BonkChoy_shooting"   ## 直拳
const STATE_UPPERCUT := &"BonkChoy_uppercut"   ## 上勾拳
#endregion


#region 音效
## 出拳音效（DLC 自己的两条 bonk）：直拳用 `bonk1`、能斩杀时换的上勾拳用 `bonk2`。
## 原来借的是本体 `Throw`（投掷声），出拳听着像在扔东西
const JAB_SFX: AudioStream = preload("../audio/bonk1.ogg")
const UPPERCUT_SFX: AudioStream = preload("../audio/bonk2.ogg")
#endregion

## 检测框里有敌人（由 `DetectComponent` 的两个信号维护）
var _has_enemy := false
## 关卡全场加速的当前倍率（1.0 = 原速）：动作段要在这个基础上再叠一层「段长 ÷ 攻速」的加速
var _speed_product := 1.0


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	_detect_component.signal_can_attack.connect(_on_can_attack)
	_detect_component.signal_not_can_attack.connect(_on_not_can_attack)
	_attack_cd_timer.timeout.connect(_on_attack_cd_timer_timeout)
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


#region 出拳
func _on_can_attack() -> void:
	_has_enemy = true
	## 刚进范围立刻来一拳，之后交给冷却计时器续上（与本体射手的口径一致）
	if _attack_cd_timer.is_stopped():
		_punch()


func _on_not_can_attack() -> void:
	_has_enemy = false
	## 没有敌人就停表：再进范围时才能「立刻打第一拳」
	_attack_cd_timer.stop()


func _on_attack_cd_timer_timeout() -> void:
	if _has_enemy:
		_punch()


## 打一拳：朝向 + 一段出拳动画 + 一次伤害结算
func _punch() -> void:
	if is_death:
		return
	var targets := _detect_component.get_all_enemy_can_be_attacked()
	## 这一拳能不能斩杀：能就换成上勾拳（伤害与动画一起换）
	var is_uppercut := _punches_can_kill(targets)
	## 动作段按「段长 ÷ 攻速」加速播放（见 `JAB_ANIM_SPEED`），全场加速的倍率叠在外面一层
	_anim_player.speed_scale = _speed_product * (UPPERCUT_ANIM_SPEED if is_uppercut else JAB_ANIM_SPEED)
	_anim_player.play(STATE_UPPERCUT if is_uppercut else STATE_SHOOTING)
	_attack_once(targets, uppercut_damage if is_uppercut else jab_damage, is_uppercut)
	## 用无参 start：让 `_on_update_speed()` 折算过的 `wait_time` 生效
	_attack_cd_timer.start()


## 这一拳能不能把目标**直接打死**（决定直拳还是上勾拳）
##
## 口径：**这一拳（上勾拳 35）打下去，目标的总血会落到它的死亡临界值以下** ——
## `get_all_hp() - uppercut_damage <= death_hp`（`get_all_hp()` = 本体 + 全部防具）。
## 本拳走 `Real` 伤害模式（与地刺 `plant_caltrop.gd` 同款）：二类防具（铁门 / 报纸）不参与吸收。
##
## ⚠️ 不要写成「总血 ≤ 35」：僵尸 `death_hp` 是本体满血的 1/3（普僵 270 → 89），
## 总血掉到 35 那会儿它**早就判过死亡**了（`character_death` → 检测框不再认它），
## 上勾拳会永远不触发。按「打完会不会死」算才是真正可触发的那一档。
func _punches_can_kill(targets: Array[Character000Base]) -> bool:
	for target in targets:
		var zombie := target as Zombie000Base
		if zombie == null or zombie.is_death:
			continue
		var hp := zombie.hp_component
		if hp.get_all_hp() - uppercut_damage <= hp.death_hp:
			return true
	return false


## 一次伤害结算：与地刺（`plant_caltrop.gd`）同一条路子 —— 逐个敌人发一个伤害包
## [param is_uppercut] 这一拳是上勾拳（音效换 `bonk2`，比直拳那一下更重）
func _attack_once(targets: Array[Character000Base], damage: int, is_uppercut := false) -> void:
	SoundManager.play_sfx_with_pool(UPPERCUT_SFX if is_uppercut else JAB_SFX)
	for i in range(targets.size() - 1, -1, -1):
		var zombie := targets[i] as Zombie000Base
		if zombie == null:
			continue
		var info := DamageInfo.create(zombie, damage,
			ConstDamage.E_DamageMode.Real, ConstDamage.E_DamageCause.Script)
		## 写上发起者：伤害归属（反伤 / 统计）要用
		info.attacker = self
		var result := zombie.apply_damage(info)
		## 打中了才闪白光（原来是无条件闪，被免疫了也闪）
		if result.is_applied:
			zombie.be_hit_light()
		## 自己已经死了就别再打后面的了
		if is_death:
			break
#endregion


#region 全场加速
## 全场加速：冷却按倍率折算（与 `AttackComponentBulletBase.owner_update_speed` 同口径）
func _on_update_speed(speed_product: float) -> void:
	_speed_product = speed_product
	if speed_product == 0:
		_attack_cd_timer.paused = true
		_anim_player.speed_scale = 0.0
		return
	_attack_cd_timer.paused = false
	## 动作段正在播时不直接写回（它那层加速还在），等播完由 `_play_idle()` 恢复
	if _anim_player.current_animation == STATE_IDLE:
		_anim_player.speed_scale = speed_product
	if not _attack_cd_timer.is_stopped():
		_attack_cd_timer.start(_attack_cd_timer.time_left / speed_product)
	_attack_cd_timer.wait_time = attack_cd / speed_product
#endregion


#region 动画回调
## 出拳播完就回待机（收拳的过渡交给待机段，不在出拳末帧定格）
func _on_animation_finished(_anim_name: StringName) -> void:
	if is_death:
		return
	_play_idle()


## 待机是循环的：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	## 回待机就撤掉动作段那层加速，只剩全场加速的倍率
	_anim_player.speed_scale = _speed_product
	_anim_player.play(STATE_IDLE)
#endregion
