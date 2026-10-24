extends Plant000Base
## 菜问（PVZ2 的 Bonk Choy，由模组「PVZ2」提供）
##
## ★ 玩法：近战，打**本行左右相邻两格**里的僵尸（不用子弹）。
##   检测走本体的 `DetectComponent`（与地刺同一条路），伤害走 `DamageInfo.create()` +
##   `apply_damage()`（`plant_caltrop.gd` 的同款写法）。
##
## ★ 动画：`bonkchoy.pam.bin` + 模组「PAM 动画播放器」（`ModIds.PAM`），
##   见 `../pam_bridge.gd`。本脚本**不参与动画制作**，只决定「什么时候播哪一段」。
##
##   ★ 八段出拳怎么分工（`attack3` / `attack6` / `attack7` 本株不用）：
##     · 直拳 0.33 秒：`attack` 朝右 / `attack2` 朝左 —— **同一动作的两个朝向**，按目标方位挑
##     · 上勾拳 0.5 秒：`attack4` 朝右 / `attack5` 朝左 —— 同上
##     · `attack3`（0.67 秒）是左右两连击、`attack6` / `attack7`（1.67 秒）是击飞段，
##       与「0.35 秒一拳」的出手口径对不上
##   朝向按什么认：看一段里**可见部件的绘制坐标 x 跨度**（待机 x ∈ [93, 247]，
##   `attack` 伸到 497 ⇒ 往右；`attack2` 伸到 -108 ⇒ 往左）。重新烘焙后按这条复核。
##
##   ★ 装扮（PVZ2 的 12 件服饰）**不画**：靠 `HIDDEN_PARTS` 关掉 ——
##     这份 PAM 把服饰和本体塞在同一条时间轴上，全开会同时戴着帽子 / 水手装 / 围巾 / 腰带…
##     清单是从部件名里筛出来的（`custom*` / `_custom*`），重新烘焙后要再核一遍。
##
## ★ 数值来自 `..\2代解包资源` 的 RTON（`PLANTPROPERTIES.RTON` → `BonkchoyProps`）：
##   阳光 150 / 冷却 5.0 秒 / 本体 300 血 / 直拳 15 / 上勾拳 60。
##   ⚠️ 伤害是**PVZ2 口径原样搬过来的**：本作僵尸血量比 PVZ2 低，会比原版更快被打死，
##   要平衡就改下面这几个 `@export`（场景里也能改）。
##
## ⚠️ 本文件跑在 `user://mods/pvz2/` 下：**`class_name` 不会注册成全局类**，
##    所以这里不写 class_name，由同目录的 `plant_bonkchoy.tscn` 按路径引用本脚本。

const PamBridge := preload("../pam_bridge.gd")

## 动画挂点：场景里是个**空 Node2D**，脚本由 `PamBridge.attach()` 在 `character_ready()` 里挂上
## （跨模组不能写死 `res://` 路径，见 `../pam_bridge.gd` 文件头）
@onready var _anim = $Body/BonkChoyAnim
@onready var detect_component: DetectComponent = $DetectComponent
## 出拳间隔计时器（本体的子弹流用 `BulletAttackCdTimer`，这里没有子弹，自己挂一个）
@onready var attack_cd_timer: Timer = $AttackCdTimer


#region 数值（RTON `BonkchoyProps` 的原值；本作僵尸更脆，见文件头）
## 直拳伤害（这一拳打不死它时用的普通拳）
@export var jab_damage := 15
## 上勾拳伤害（这一拳能直接打死它时改用，判定见 `_punches_can_kill()`）
@export var uppercut_damage := 60
## 出手间隔（秒）：与一段直拳动画等长（`attack` / `attack2` 都是 10 帧 / 30fps = 0.33 秒）
@export var attack_cd := 0.35
#endregion


#region 动画常量
const BIN_REL_PATH := "bonkchoy/bonkchoy.pam.bin"
const ATLAS_REL_PATH := "bonkchoy/bonkchoy_atlas.png"
## 摆放（数是从 `test/scenarios/probe_pvz2_pam.gd` 打印的待机包围盒量出来的）：
## 待机帧在画布坐标占 196×170、底部正好落在画布中心线上 ⇒ `pivot_offset = (0, -45)`
## （画布 390×390，地面线在 y≈240）；`scale = 0.55` 让整株 ≈ 108×94 px
## （格子 76×95 —— 菜问本来就是横向偏宽的矮胖体型）
## ⚠️ `pivot_offset.y` 越小画面越靠上（脚悬空就把它调大），口径见
##    `../firepeashooter/firepeashooter_plant.gd` 同名常量上的说明。
const ANIM_PIVOT := Vector2(0, -45)
const ANIM_SCALE := 0.55
## 要关掉的装扮部件（PVZ2 把服饰和本体塞在同一条时间轴上）
const HIDDEN_PARTS: Array[String] = [
	"_custom", "custom_01", "custom_01_01", "custom_02", "custom_02_02",
	"custom_03", "custom_04", "custom_05", "custom_06", "custom_07",
	"custom_08", "custom_09", "_custom_left", "_custom_right", "custom_valentines",
]
## 单次播放的状态（播完发 `animation_finished`）
const ONESHOT_STATES: Array[String] = [
	"attack", "attack2", "attack3", "attack4", "attack5", "attack6", "attack7",
	"plantfood_on", "plantfood_off",
]

## 待机三段：PVZ2 里 idle 本来就是三段接起来的循环（不分朝向）
const IDLE_ANIMS: Array[String] = ["idle", "idle2", "idle3"]
## 直拳（各 0.33 秒，水平出拳）的两个朝向：朝右 / 朝左
const JAB_ANIM_RIGHT := "attack"
const JAB_ANIM_LEFT := "attack2"
## 上勾拳（各 0.5 秒，拳头往上挑）的两个朝向：朝右 / 朝左
const UPPERCUT_ANIM_RIGHT := "attack4"
const UPPERCUT_ANIM_LEFT := "attack5"
var _idle_index := 0
## 检测框里有敌人（由 `DetectComponent` 的两个信号维护）
var _is_attack := false
#endregion


#region 生命周期
## 与初始化类型无关：把空挂点变成 PAM 播放器（三条分支都要，图鉴里才有姿势）
func character_ready() -> void:
	super()
	PamBridge.attach(_anim, BIN_REL_PATH, ATLAS_REL_PATH, HIDDEN_PARTS, ONESHOT_STATES,
		ANIM_PIVOT, ANIM_SCALE)


## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	detect_component.signal_can_attack.connect(_on_can_attack)
	detect_component.signal_not_can_attack.connect(_on_not_can_attack)
	attack_cd_timer.timeout.connect(_on_attack_cd_timer_timeout)
	_anim.animation_finished.connect(_on_animation_finished)


## 初始化正常出战角色
func ready_norm() -> void:
	super()
	_play_idle()


## 初始化展示角色（选卡界面 / 图鉴里的静态形象也要有姿势，不然是一堆默认姿态的贴图）
func ready_show() -> void:
	super()
	_play_idle()
#endregion


#region 出拳
## 打一拳：朝向段 + 一次伤害结算
func _punch() -> void:
	var targets := detect_component.get_all_enemy_can_be_attacked()
	## 这一拳朝哪边：按**最近的那只**目标（检测框铺了左右两格，它才是先挨拳的）
	var is_left := _is_target_on_left(targets)
	## 这一拳能不能斩杀：能就换成上勾拳（伤害与动画一起换）
	var is_uppercut := _punches_can_kill(targets)
	_anim.set_state(_pick_punch_anim(is_uppercut, is_left))
	_attack_once(targets, uppercut_damage if is_uppercut else jab_damage)
	attack_cd_timer.start(attack_cd)


## 挑这一拳播哪一段：上勾拳 / 直拳 × 朝左 / 朝右
##
## 出拳里直拳与上勾拳**各有两个朝向**（同一动作的镜像，判据见文件头），
## 所以这里不能随机挑 —— 随机挑会有一半的拳朝着背后打。
func _pick_punch_anim(is_uppercut: bool, is_left: bool) -> String:
	var anim_right := UPPERCUT_ANIM_RIGHT if is_uppercut else JAB_ANIM_RIGHT
	var anim_left := UPPERCUT_ANIM_LEFT if is_uppercut else JAB_ANIM_LEFT
	return anim_left if is_left else anim_right


## 这一拳朝哪边：取**距离最近**的那只目标，它在本体左边就返回 true
##
## 框里没有可打的目标（理论上不会走到）按朝右兜底。
func _is_target_on_left(targets: Array[Character000Base]) -> bool:
	var nearest: Zombie000Base = null
	var nearest_dist := INF
	for target in targets:
		var zombie := target as Zombie000Base
		if zombie == null or zombie.is_death:
			continue
		var dist := absf(zombie.global_position.x - global_position.x)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = zombie
	if nearest == null:
		return false
	return nearest.global_position.x < global_position.x


## 这一拳能不能把目标**直接打死**（决定直拳还是上勾拳）
##
## 口径：**这一拳（上勾拳 60）打下去，目标的总血会落到它的死亡临界值以下** ——
## `get_all_hp() - uppercut_damage <= death_hp`（`get_all_hp()` = 本体 + 全部防具）。
## 本拳走 `Real` 伤害模式（与地刺 `plant_caltrop.gd` 同款）：二类防具（铁门 / 报纸）不参与吸收。
##
## ⚠️ 不要写成「总血 ≤ 60」：僵尸的 `death_hp` 是本体满血的 1/3，
## 总血掉到 60 那会儿它**早就判过死亡**了（`character_death` → 检测框不再认它），
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
func _attack_once(targets: Array[Character000Base], damage: int) -> void:
	SoundManager.play_character_SFX("Throw")
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


func _on_can_attack() -> void:
	_is_attack = true
	## 刚进范围立刻来一拳，之后交给冷却计时器续上
	if attack_cd_timer.is_stopped():
		_punch()


func _on_not_can_attack() -> void:
	_is_attack = false


func _on_attack_cd_timer_timeout() -> void:
	if _is_attack:
		_punch()
#endregion


#region 播动画
## 出拳播完就回待机；待机播完接下一段
##
## ⚠️ 这里**不能**因为「检测框里还有敌人」就不播待机 —— 那样出拳段播完会定格在最后一帧，
## 拳头停在空中直到下一拳（0.35 秒后）才换动作。收拳的过渡一律交给待机段。
func _on_animation_finished(_state_name: String) -> void:
	_play_idle()


## 待机三段接龙：播当前这段，把游标挪到下一段
func _play_idle() -> void:
	_anim.set_state(IDLE_ANIMS[_idle_index])
	_idle_index = (_idle_index + 1) % IDLE_ANIMS.size()
#endregion
