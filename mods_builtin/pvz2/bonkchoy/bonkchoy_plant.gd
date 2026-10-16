extends Plant000Base
## 菜问（PVZ2 战斗植物，由模组「PVZ2」提供）
##
## ★ 为什么要在模组里：菜问是《植物大战僵尸 **2**》的植物，原版（PVZ1）没有它，
##   连美术都不是同一套格式（PVZ2 是 PAM / XFL，不是原版的 `.reanim`）。
##   原版之外的角色一律做成模组 —— 关掉 = 不装载，回到原版。
##
## ★ 动画是**离线烘焙好的，不是本脚本做的**：
##   PVZ2 的 PAM 动画由另一个转换工程（仓库外的 `新建游戏项目/`）转成
##   「57 个 Sprite2D 复用槽 + 一个 AnimationPlayer」的 `.tscn`（本目录下的 `bonkchoy_anim.tscn`），
##   里面躺着 17 段动画：**idle / idle2 / idle3（待机三段循环）、attack ~ attack7（七段出拳）、
##   plantfood_on / plantfood / plantfood_off 及带 2 的那一套（能量豆）、water（浇水）**。
##   本脚本**不参与动画制作**，只决定「什么时候播哪一段」。
##
##   ⚠️ 烘焙产物里 57 个槽位（`draw_slot_00` ~ `draw_slot_56`）的 `z_index` 曾被写成**它的序号**，
##   那等于让整株植物占掉 0~56 共 57 个层级，会把 0 层上的**血条**（`HpComponent/HpControl`）
##   与**卡片冷却遮罩**（`card_base.tscn` 的 `ProgressBar`）一起盖住 —— 已全部归零。
##   槽位之间的先后本来就靠**子节点顺序**表达（与 z_index 等价），归零不改变任何画面顺序；
##   重新烘焙这个 `.tscn` 后要再核一遍（见 [渲染层级](../../../docs/参考存档/渲染层级.md)）。
##
##   ★ 七段出拳怎么分工（`attack3` / `attack6` / `attack7` 本株不用）：
##     · 直拳 0.333 秒：`attack` 朝右 / `attack2` 朝左 —— **同一动作的两个朝向**，按目标方位挑
##     · 上勾拳 0.5 秒：`attack4` 朝右 / `attack5` 朝左 —— 同上
##     · `attack3`（0.667 秒）是左右两连击、`attack6` / `attack7`（1.667 秒）是击飞段，
##       与「0.35 秒一拳」的出手口径对不上
##   朝向是怎么认出来的（重新烘焙后按这个复核，别凭感觉猜）：
##     · 看一段里**可见槽位的绘制坐标 x 跨度**：待机（基准，不分朝向）占 x ∈ [93, 247]，
##       `attack` 伸到 497、`attack4` 伸到 350 ⇒ 往右出拳；`attack2` 伸到 -108 ⇒ 往左；
##     · 再看**镜像**：`attack2` / `attack5` 有 28/57 个槽位的变换矩阵第一分量 `a < 0`
##       （那一半是镜像过的），基准段与朝右段都只有 4/57（那 4 个本来就是旋转件）。
##
##   ★ 装扮（PVZ2 的服饰）**不画**：
##     PVZ2 这套 PAM 把打扮用的 12 件装扮和本体一起塞进了时间轴，烘焙产物照单全收 ——
##     结果是菜问同时戴着 12 件装扮（帽子 / 水手装 / 围巾 / 腰带 / 花环 / 绷带…）。
##     已把它们的 `visible` 轨道**按帧压成 false**（节点默认可见性也一并关掉），
##     重新烘焙后要照这份清单再压一遍：
##       55x60 / 77x171 / 79x40 / 96x34 / 96x40 / 97x37 /
##       98x101 / 102x68 / 103x67 / 105x134 / 109x59 / 130x52
##     怎么认出它们：看**绘制顺序的尾巴** —— 每段动画里那一撮「17 段动画全都在画、
##     又不属于本体」的部件就是装扮，它们永远画在本体之上。
##     ⚠️ 别只用颜色筛：`103x67` 是条**绿**腰带（77% 是绿），按「非绿 = 装扮」会漏掉它，
##     漏掉的表现就是「菜问还剩一条腰带」—— 用上面的清单/绘制顺序核对才靠得住。
##     ⚠️ 贴图轨道是**稀疏**的（只在贴图变化时打点），按「第几个值」配可见性是错的 ——
##     要按 `"times"` 时间轴对齐后再压（逐帧取「该时刻生效的贴图」）。
##
## ★ 结构与本体的差别：本体的植物是「reanim → `.tres` 动画 → AnimationTree 状态机」，
##   本株没有 AnimationTree —— 播放器在 `Body/BonkChoyAnim/AnimationPlayer`，
##   由本脚本直接 `play()`（跟 PVZ2 那边「一段动画 = 一个动作」的口径一致）。
##
## ★ 玩法：近战，打**本行左右相邻两格**里的僵尸（不用子弹）。
##   检测走本体的 `DetectComponent`（与地刺同一条路），
##   伤害走 `DamageInfo.create()` + `apply_damage()`（`plant_caltrop.gd` 的同款写法）。
##
## ⚠️ 本文件跑在 `user://mods/pvz2/` 下：**`class_name` 不会注册成全局类**，
##    所以这里不写 class_name，由同目录的 `plant_bonkchoy.tscn` 按路径引用本脚本；
##    继承本体基类可以直接用类名（`Plant000Base` 在 `res://`）。

@onready var detect_component: DetectComponent = $DetectComponent
## 出拳间隔计时器（本体的子弹流用 `BulletAttackCdTimer`，这里没有子弹，自己挂一个）
@onready var attack_cd_timer: Timer = $AttackCdTimer
## 烘焙动画的播放器：藏在 `Body` 下面（`Body` 是角色基类的节点，带 `BodyCharacter` 脚本）
@onready var anim_player: AnimationPlayer = $Body/BonkChoyAnim/AnimationPlayer


#region 数值（都是模组的取值，不是照 PVZ2 wiki 抄的；要对齐请自己查过再改）
## 直拳伤害（这一拳打不死它时用的普通拳）
@export var jab_damage := 15
## 上勾拳伤害（这一拳能直接打死它时改用，判定见 `_punches_can_kill()`）
@export var uppercut_damage := 35
## 出手间隔（秒）：与一段直拳动画等长（`attack` / `attack2` 都是 0.333 秒），两拳几乎连着出
@export var attack_cd := 0.35
#endregion


#region 动画
## 待机三段：PVZ2 里 idle 本来就是三段接起来的循环（不分朝向）
const IDLE_ANIMS: Array[String] = ["idle", "idle2", "idle3"]
## 直拳（各 0.333 秒，水平出拳）的两个朝向：朝右 / 朝左
const JAB_ANIM_RIGHT := &"attack"
const JAB_ANIM_LEFT := &"attack2"
## 上勾拳（各 0.5 秒，拳头往上挑）的两个朝向：朝右 / 朝左
const UPPERCUT_ANIM_RIGHT := &"attack4"
const UPPERCUT_ANIM_LEFT := &"attack5"
var _idle_index := 0
## 检测框里有敌人（由 `DetectComponent` 的两个信号维护）
var _is_attack := false
#endregion


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	detect_component.signal_can_attack.connect(_on_can_attack)
	detect_component.signal_not_can_attack.connect(_on_not_can_attack)
	attack_cd_timer.timeout.connect(_on_attack_cd_timer_timeout)
	anim_player.animation_finished.connect(_on_animation_finished)


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
	anim_player.play(_pick_punch_anim(is_uppercut, is_left))
	_attack_once(targets, uppercut_damage if is_uppercut else jab_damage)
	attack_cd_timer.start(attack_cd)


## 挑这一拳播哪一段：上勾拳 / 直拳 × 朝左 / 朝右
##
## 七段出拳里直拳与上勾拳**各有两个朝向**（同一动作的镜像，判据见文件头），
## 所以这里不能随机挑 —— 随机挑会有一半的拳朝着背后打。
func _pick_punch_anim(is_uppercut: bool, is_left: bool) -> StringName:
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
## 口径：**这一拳（上勾拳 35）打下去，目标的总血会落到它的死亡临界值以下** ——
## `get_all_hp() - uppercut_damage <= death_hp`（`get_all_hp()` = 本体 + 全部防具）。
## 本拳走 `Real` 伤害模式（与地刺 `plant_caltrop.gd` 同款）：二类防具（铁门 / 报纸）不参与吸收。
##
## ⚠️ 不要写成「总血 ≤ 35」：僵尸的 `death_hp` 是本体满血的 1/3（普僵 270 → 89，
## 见 `ComponentHpStageChange`），总血掉到 35 那会儿它**早就判过死亡**了
## （`character_death` → 检测框不再认它，见 `DetectComponent._judge_enemy_is_can_be_attack`），
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
func _on_animation_finished(_anim_name: StringName) -> void:
	_play_idle()


## 待机三段接龙：播当前这段，把游标挪到下一段
func _play_idle() -> void:
	anim_player.play(IDLE_ANIMS[_idle_index])
	_idle_index = (_idle_index + 1) % IDLE_ANIMS.size()
#endregion
