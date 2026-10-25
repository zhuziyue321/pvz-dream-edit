extends Plant000Base
## 豌豆荚（PVZ2 的 Pea Pod，由模组「PVZ2」提供）
##
## ★ 玩法：**同格叠层射手** —— 一株最多叠 5 层，每层一个头；
##   攻击时按层数连发同样数量的豌豆（1 层 1 颗 … 5 层 5 颗）。
##   同格再种一次本植物 = 叠一层（不是新种第二株），这条走的是本体通用叠层口子：
##     `ResourcePlantCondition.judge_is_can_plant()` 认出「同种 + 还能叠」放行虚影，
##     `PlantCell.create_plant()` 认出同样的情况改调 `try_stack_up()`，不新建植物。
##
## ★ 动画走 `.pam.bin` + 模组内的 PAM 播放器（`pam/pam_animator.gd`）。
##   层数与状态的对应是**量出来的**（每多一层，动画里的部件数 +4 / 出拳段 +6）：
##     · 1~5 层待机：`idle` / `idle2` / `idle3` / `idle4` / `idle5`（各 30 帧）
##     · 1~5 层攻击：`attack` / `attack 2` / `attack 3` / `attack 4` / `attack 5`（30~31 帧）
##     · `plantfood*` / `water` / `lv5_*` / `idle6` / `idle7` 本株不用
##       （`idle6` 多出 10 个部件、`idle7` 的包围盒撑到 4009×3431，像是另一套特效数据，
##        不是「6 层 / 7 层」，别拿它当第 6、7 层用）
##
## ★ 发几颗与帧号：攻击段第 8 帧开始出豆，之后每 3 帧一颗（第 8 / 11 / 14 / 17 / 20 帧），
##   5 层刚好在 30 帧的攻击段内发完。按帧号算（不是按时间猜）才不会被帧率带偏。
##
## ★ 数值都是**模组自己的取值**，不是照 PVZ2 wiki 抄的 —— 要对齐请自己查过再改。
##
## ⚠️ 本文件跑在 `user://mods/pvz2/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_peapod.tscn` 按路径引用。

const PamBridge := preload("../pam_bridge.gd")

## 动画挂点：场景里是个**空 Node2D**，脚本由 `PamBridge.attach()` 在 `character_ready()` 里挂上
## （跨模组不能写死 `res://` 路径，见 `../pam_bridge.gd` 文件头）
@onready var _anim = $Body/PeaPodAnim
@onready var _detect_component: DetectComponent = $DetectComponent
@onready var _attack_cd_timer: Timer = $AttackCdTimer
## 子弹出生点（最上面那个头的嘴前，位置按烘焙数据的包围盒量的，见场景注释）
@onready var _marker: Marker2D = $Body/Marker2D


#region 数值（RTON `PeaDefault.BaseDamage` = 20；攻击冷却取 RTON 的 1.35~1.5 上沿）
## 一颗豌豆的伤害
@export var bullet_damage := 20
## 攻击间隔（秒）
@export var attack_cd := 1.5
#endregion


#region 动画资源与摆放
const BIN_REL_PATH := "peapod/peapod.pam.bin"
const ATLAS_REL_PATH := "peapod/peapod_atlas.png"
## 摆放（数是从 `test/scenarios/probe_pvz2_pam.gd` 打印的待机包围盒量出来的）：
## 待机帧在画布坐标占 218×230、底部比画布中心高 16 px ⇒
## `pivot_offset = (-31, -72)`；`scale = 0.40` 让整株 ≈ 87×92 px（格子 76×95）
## ⚠️ `pivot_offset.y` 越小画面越靠上（脚悬空就把它调大），口径见
##    `../firepeashooter/firepeashooter_plant.gd` 同名常量上的说明。
const ANIM_PIVOT := Vector2(-31, -72)
const ANIM_SCALE := 0.40
## 这份 PAM 里 `custom_03b` / `custom_2a~2e` 是**本体部件**（时间轴一直在用），不是装扮，
## 所以只关真正没用到的两个（重新烘焙后要照这条复核，别整片 `custom*` 全关）
const HIDDEN_PARTS: Array[String] = ["custom_01", "custom_03a"]
## 单次播放的状态
const ONESHOT_STATES: Array[String] = [
	"attack", "attack 2", "attack 3", "attack 4", "attack 5",
	"plantfood_on", "plantfood_off", "water",
	"lv5_01", "lv5_02",
	"plantfood_on_lv5_01", "plantfood_off_lv5_01",
	"plantfood_on_lv5_02", "plantfood_off_lv5_02",
]
#endregion


#region 动画常量
## 层数（1~5）→ 待机状态
const IDLE_ANIMS: Array[String] = ["idle", "idle2", "idle3", "idle4", "idle5"]
## 层数（1~5）→ 攻击状态（名字里带空格的是 PAM 原标签，别自己改名）
const ATTACK_ANIMS: Array[String] = ["attack", "attack 2", "attack 3", "attack 4", "attack 5"]
## 攻击段第一颗豆的帧号，以及之后每颗的间隔帧数
const ATTACK_FIRST_SHOT_FRAME := 8
const ATTACK_SHOT_FRAME_STEP := 3

var _has_enemy := false
## 本次攻击已经发了几颗（按层数封顶，见 `_on_anim_state_frame_changed`）
var _shots_fired := 0
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
	_anim.state_frame_changed.connect(_on_anim_state_frame_changed)
	## 关卡全场加速（「僵尸快跑」）要连冷却一起加速，否则加速关里它反而变慢
	signal_update_speed.connect(_on_update_speed)


## 初始化正常出战角色
func ready_norm() -> void:
	super()
	stack_layers = clampi(stack_layers, 1, max_stack_layers)
	_play_idle()


## 初始化展示角色（图鉴 / 选卡界面里的静态形象：单层待机）
func ready_show() -> void:
	super()
	_anim.set_state(IDLE_ANIMS[0])
#endregion


#region 叠层
## 还能不能再叠一层
func can_stack_up() -> bool:
	return not is_death and stack_layers < max_stack_layers


## 叠一层（同格再种一次本株时由 `PlantCell.create_plant()` 调）
func try_stack_up() -> bool:
	if not can_stack_up():
		return false
	stack_layers += 1
	## 正在攻击时先不动画：等这一段播完回待机，新的层数自然生效
	if not (String(_anim.get_current_state()) in ATTACK_ANIMS):
		_play_idle()
	Log.info("豌豆荚：叠到第 %d 层" % stack_layers)
	return true


## 存档：层数要跟着走，否则读档会缩回 1 层
func gat_save_game_data_plant() -> Dictionary:
	var data: Dictionary = super()
	data["stack_layers"] = stack_layers
	return data


## 读档：恢复层数并刷新成对应层数的待机
func load_game_data_plant(save_game_data_plant: Dictionary) -> void:
	super(save_game_data_plant)
	stack_layers = clampi(int(save_game_data_plant.get("stack_layers", 1)), 1, max_stack_layers)
	_play_idle()
#endregion


#region 攻击
func _on_can_attack() -> void:
	_has_enemy = true
	if _attack_cd_timer.is_stopped():
		_start_attack()


func _on_not_can_attack() -> void:
	_has_enemy = false
	_attack_cd_timer.stop()


func _on_attack_cd_timer_timeout() -> void:
	if _has_enemy:
		_start_attack()


## 开一次攻击：播当前层数对应的攻击段
func _start_attack() -> void:
	if is_death:
		return
	_shots_fired = 0
	_anim.set_state(ATTACK_ANIMS[stack_layers - 1])
	_attack_cd_timer.start(attack_cd)


## 发一颗豌豆：参数与 `AttackComponentBulletBase.get_bullet_paras()` 同口径
func _shoot_bullet() -> void:
	if is_death:
		return
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
	if state_name in ATTACK_ANIMS:
		_play_idle()


## 状态内帧号推进：到「第 8 / 11 / 14 …」帧发下一颗，发满当前层数就停
func _on_anim_state_frame_changed(state_name: String, frame: int) -> void:
	if is_death or _shots_fired >= stack_layers:
		return
	if state_name != ATTACK_ANIMS[stack_layers - 1]:
		return
	if frame < ATTACK_FIRST_SHOT_FRAME:
		return
	## 按帧号算出「到这一帧为止该发几颗」：卡顿导致跳帧时也能把该发的补齐
	@warning_ignore("integer_division")
	var allowed := 1 + (frame - ATTACK_FIRST_SHOT_FRAME) / ATTACK_SHOT_FRAME_STEP
	var target := mini(allowed, stack_layers)
	while _shots_fired < target:
		_shots_fired += 1
		_shoot_bullet()


## 待机：播当前层数那一段（这一段本身就是完整循环，不用接龙）
func _play_idle() -> void:
	_anim.set_state(IDLE_ANIMS[clampi(stack_layers, 1, IDLE_ANIMS.size()) - 1])
#endregion
