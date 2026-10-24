extends Plant000Base
## 火焰豌豆射手（PVZ2 的 Fire Peashooter，由模组「PVZ2」提供）
##
## ★ 玩法就一句话：**一行直线射手** —— 本行右边有僵尸就朝右吐一颗火豌豆，
##   中间没有别的手脚（不用能量豆 / 不浇水 / 不打多行）。PVZ2 原版也是单发直射。
##
## ★ 动画走 `.pam.bin` + 模组内的 PAM 播放器（`pam/pam_animator.gd`），
##   与潜伏芹菜同一条路；本脚本只决定「什么时候播哪一段、哪一帧发子弹」：
##     · `idle` / `idle2`（各 31 帧）：站着的待机，两段接龙循环（`idle_world` 不用）
##     · `attack`（31 帧 ≈ 1.03 秒）：喷火攻击 —— 第 8 帧嘴前喷出火苗（量出来的），
##       子弹就在这一帧从 `Body/Marker2D` 出发
##     · `plantfood*` / `water`：本株不做（菜问 / 潜伏芹菜同样只用了待机与攻击段）
##
## ★ 为什么不用本体的 `AttackComponentBulletBase`：那条路的攻击节奏靠
##   `AnimationTree.set("parameters/OneShot/request")` 驱动，而 PAM 播放器没有
##   `AnimationTree`（`@onready var animation_tree: AnimationTree = $"../AnimationTree"`
##   会在场景加载时报「Node not found」）。所以这里照菜问的做法，自己挂
##   `DetectComponent` + `AttackCdTimer`，发射逻辑直接走 `BulletRegistry`
##   （参数口径与 `AttackComponentBulletBase.get_bullet_paras()` 一一对应）。
##
## ★ 数值都是**模组自己的取值**，不是照 PVZ2 wiki 抄的 —— 要对齐请自己查过再改。
##
## ⚠️ 本文件跑在 `user://mods/pvz2/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_firepeashooter.tscn` 按路径引用。

const PamBridge := preload("../pam_bridge.gd")

## 动画挂点：场景里是个**空 Node2D**，脚本由 `PamBridge.attach()` 在 `character_ready()` 里挂上
## （跨模组不能写死 `res://` 路径，见 `../pam_bridge.gd` 文件头）
@onready var _anim = $Body/FirePeashooterAnim
@onready var _detect_component: DetectComponent = $DetectComponent
@onready var _attack_cd_timer: Timer = $AttackCdTimer
## 子弹出生点（嘴前，位置按烘焙数据的包围盒量的，见场景注释）
@onready var _marker: Marker2D = $Body/Marker2D


#region 数值（RTON `FirePeaDefault` 的 BaseDamage = 40；冷却照本作射手的节奏）
## 一颗火豌豆的伤害
@export var bullet_damage := 40
## 攻击间隔（秒）
@export var attack_cd := 1.4
#endregion


#region 动画资源与摆放
const BIN_REL_PATH := "firepeashooter/firepeashooter.pam.bin"
const ATLAS_REL_PATH := "firepeashooter/firepeashooter_atlas.png"
## 摆放（数是从 `test/scenarios/probe_pvz2_pam.gd` 打印的待机包围盒量出来的）：
## 待机帧在画布坐标占 166×209、包围盒底部比画布中心高 35 px ⇒
## `pivot_offset = (-24, -50)` 把脚放回植物原点；`scale = 0.44` 让整株 ≈ 73×92 px（格子 76×95）
## ⚠️ `pivot_offset.y` 的作用是「整段往下挪 N 画布像素」：**值越小画面越靠上**，
##    所以脚悬空时要把 y **调大**（量出来的 `rect.end.y` 是负数，直接相加即可）。
## ⚠️ 换 PAM 版本 / 换状态后要重跑那条探针再核这两个值，别凭感觉。
const ANIM_PIVOT := Vector2(-24, -50)
const ANIM_SCALE := 0.44
## 这份 PAM 里 `custom_*` / `_custom` 在时间轴上从未出现，不需要关装扮
const HIDDEN_PARTS: Array[String] = []
## 单次播放的状态（播完发 `animation_finished`）
const ONESHOT_STATES: Array[String] = ["attack", "plantfood", "plantfood_end", "water"]
#endregion


#region 动画常量
## 待机两段接龙（`idle_world` 是 PVZ2 的场地待机，本作不用）
const IDLE_ANIMS: Array[String] = ["idle", "idle2"]
const STATE_ATTACK := "attack"
## 喷火的命中帧：`attack` 第 8 帧嘴前火苗最亮（量出来的，重新烘焙后按这个复核）
const ATTACK_SHOOT_FRAME := 8

var _idle_index := 0
## 检测框里有敌人（由 `DetectComponent` 的两个信号维护）
var _has_enemy := false
## 本次攻击的子弹已经发出去了（防止跳帧时补发 / 重复发）
var _shot_in_this_attack := false
#endregion


#region 生命周期
## 与初始化类型无关：把空挂点变成 PAM 播放器（图鉴 / 展示态同样要有姿势）
func character_ready() -> void:
	super()
	PamBridge.attach(_anim, BIN_REL_PATH, ATLAS_REL_PATH, HIDDEN_PARTS, ONESHOT_STATES,
		ANIM_PIVOT, ANIM_SCALE)


## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	_detect_component.signal_can_attack.connect(_on_can_attack)
	_detect_component.signal_not_can_attack.connect(_on_not_can_attack)
	_attack_cd_timer.timeout.connect(_on_attack_cd_timer_timeout)
	_anim.animation_finished.connect(_on_anim_finished)
	_anim.loop_completed.connect(_on_anim_loop_completed)
	_anim.state_frame_changed.connect(_on_anim_state_frame_changed)
	## 关卡全场加速（「僵尸快跑」）要连冷却一起加速，否则加速关里它反而变慢
	signal_update_speed.connect(_on_update_speed)


## 初始化正常出战角色
func ready_norm() -> void:
	super()
	_play_idle()


## 初始化展示角色（图鉴 / 选卡界面里的静态形象）
func ready_show() -> void:
	super()
	_anim.set_state(IDLE_ANIMS[0])
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


func _on_attack_cd_timer_timeout() -> void:
	if _has_enemy:
		_start_attack()


## 开一次攻击：播 `attack`（单次），子弹由命中帧回调发出去
func _start_attack() -> void:
	if is_death:
		return
	_shot_in_this_attack = false
	_anim.set_state(STATE_ATTACK)
	_attack_cd_timer.start(attack_cd)


## 发一颗火豌豆：参数与 `AttackComponentBulletBase.get_bullet_paras()` 同口径
func _shoot_bullet() -> void:
	if is_death or _shot_in_this_attack:
		return
	_shot_in_this_attack = true
	var main_game := get_main_game()
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.bullets):
		return
	var bullets: Node2D = main_game.bullets
	var bullet: Bullet000Base = Global.bullet_registry.create_bullet(BulletIds.PEA_FIRE)
	## 闸门被占住时（联机客户端）造不出来：那一颗由主机随快照下发
	if bullet == null:
		return
	var status := _detect_component.can_attack_status_component
	var bullet_damage_value := bullet_damage
	## 角色自己的 `attack_value` 有值就按它来（与本体「攻击力字段接入子弹伤害」同一条优先级）
	if attack_value > 0:
		bullet_damage_value = attack_value
	var paras: Dictionary[Bullet000NormBase.E_InitParasAttr, Variant] = {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: _detect_component.is_lane,
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
		return
	_attack_cd_timer.paused = false
	if not _attack_cd_timer.is_stopped():
		_attack_cd_timer.start(_attack_cd_timer.time_left / speed_product)
	_attack_cd_timer.wait_time = attack_cd / speed_product
#endregion


#region 动画回调
func _on_anim_finished(state_name: String) -> void:
	if is_death:
		return
	if state_name == STATE_ATTACK:
		_play_idle()


## 待机段转完一圈：接下一段（idle → idle2 → idle）
func _on_anim_loop_completed(state_name: String) -> void:
	if is_death:
		return
	if state_name in IDLE_ANIMS:
		_play_idle()


## 状态内帧号推进：到喷火帧发子弹
func _on_anim_state_frame_changed(state_name: String, frame: int) -> void:
	if is_death:
		return
	if state_name == STATE_ATTACK and frame >= ATTACK_SHOOT_FRAME:
		_shoot_bullet()


## 待机两段接龙：播当前这段，游标挪到下一段
func _play_idle() -> void:
	_anim.set_state(IDLE_ANIMS[_idle_index])
	_idle_index = (_idle_index + 1) % IDLE_ANIMS.size()
#endregion
