extends Plant000Base
## 毒液豌豆（PVZ2 的 Goo Peashooter，由模组「PVZ2」提供）
##
## ★ 玩法：**一行直线射手** —— 本行右边有僵尸就朝右吐一颗毒豌豆（与火焰豌豆同一条骨架）。
##
##   ⚠️ PVZ2 原版的毒液豌豆还带「中弹后持续掉血」的毒，本株**没做**那层（本作没有对应的
##   状态组件，硬塞一个每帧判定的计时器会跟暂停 / 变速 / 存档三处打架）。
##   现在就是「伤害较低的直线射手」：单发按 RTON `PoisonPeaDefault.BaseDamage` = 10。
##   要补毒，正确做法是给本体加一个状态组件，不是在植物脚本里挂计时器。
##
## ★ 动画走 `.pam.bin` + 模组「PAM 动画播放器」（`ModIds.PAM`），见 `../pam_bridge.gd`。
##   状态：`idle` / `idle2` / `idle3`（待机三段）、`attack`（喷毒液）、`plantfood` / `water`（本株不用）。
##
## ★ 数值来自 `..\2代解包资源` 的 RTON：`PLANTTYPES.RTON` 里阳光 100 / 冷却 5.0 秒，
##   `PROJECTILETYPES.RTON` 里 `PoisonPeaDefault.BaseDamage` = 10。
##
## ⚠️ 本文件跑在 `user://mods/pvz2/` 下：**`class_name` 不会注册成全局类**，
##    所以这里不写 class_name，由同目录的 `plant_goopeashooter.tscn` 按路径引用本脚本。

const PamBridge := preload("../pam_bridge.gd")

## 动画挂点：场景里是个**空 Node2D**，脚本由 `PamBridge.attach()` 在 `character_ready()` 里挂上
@onready var _anim = $Body/GooPeashooterAnim
@onready var _detect_component: DetectComponent = $DetectComponent
@onready var _attack_cd_timer: Timer = $AttackCdTimer
## 子弹出生点（嘴前）
@onready var _marker: Marker2D = $Body/Marker2D


#region 数值（RTON 原值：BaseDamage 10 / 阳光 100 / 冷却 5.0 秒）
## 一颗毒豌豆的伤害
@export var bullet_damage := 10
## 攻击间隔（秒）
@export var attack_cd := 1.4
#endregion


#region 动画资源与摆放
const BIN_REL_PATH := "goopeashooter/goopeashooter.pam.bin"
const ATLAS_REL_PATH := "goopeashooter/goopeashooter_atlas.png"
## 摆放（数是从 `test/scenarios/probe_pvz2_pam.gd` 打印的待机包围盒量出来的）：
## 这份 PAM 的画布同样是 390×390，但毒液豌豆在画布里只占 128×122（画得比其它株小），
## 待机帧底部比画布中心高 31 px ⇒ `pivot_offset = (-24, -54)`；`scale = 0.72`
## 让整株 ≈ 92×88 px（格子 76×95）。
## ⚠️ `pivot_offset.y` 越小画面越靠上（脚悬空就把它调大），口径见
##    `../firepeashooter/firepeashooter_plant.gd` 同名常量上的说明。
const ANIM_PIVOT := Vector2(-24, -54)
const ANIM_SCALE := 0.72
## 装扮：`custom_01` 是本株头上那顶草帽，`_custom` 是空占位
const HIDDEN_PARTS: Array[String] = ["custom_01", "_custom"]
## 单次播放的状态
const ONESHOT_STATES: Array[String] = ["attack", "plantfood", "water"]

## 待机三段接龙
const IDLE_ANIMS: Array[String] = ["idle", "idle2", "idle3"]
const STATE_ATTACK := "attack"
## 喷毒液的出手帧（口径与火焰豌豆一致：攻击段第 8 帧；重新烘焙后要照这一帧复核）
const ATTACK_SHOOT_FRAME := 8

var _idle_index := 0
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


## 发一颗毒豌豆：参数与 `AttackComponentBulletBase.get_bullet_paras()` 同口径
func _shoot_bullet() -> void:
	if is_death or _shot_in_this_attack:
		return
	_shot_in_this_attack = true
	var main_game := get_main_game()
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.bullets):
		return
	var bullets: Node2D = main_game.bullets
	var bullet: Bullet000Base = Global.bullet_registry.create_bullet(BulletIds.PEA)
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


## 待机段转完一圈：接下一段（idle → idle2 → idle3 → idle）
func _on_anim_loop_completed(state_name: String) -> void:
	if is_death:
		return
	if state_name in IDLE_ANIMS:
		_play_idle()


## 状态内帧号推进：到喷毒液帧发子弹
func _on_anim_state_frame_changed(state_name: String, frame: int) -> void:
	if is_death:
		return
	if state_name == STATE_ATTACK and frame >= ATTACK_SHOOT_FRAME:
		_shoot_bullet()


## 待机三段接龙：播当前这段，游标挪到下一段
func _play_idle() -> void:
	_anim.set_state(IDLE_ANIMS[_idle_index])
	_idle_index = (_idle_index + 1) % IDLE_ANIMS.size()
#endregion
