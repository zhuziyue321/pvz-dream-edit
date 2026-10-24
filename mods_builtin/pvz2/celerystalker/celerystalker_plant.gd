extends Plant000Base
## 潜伏芹菜（PVZ2 的 Celery Stalker，由模组「PVZ2」提供）
##
## ★ 本株的玩法就一句话：**平时缩在地里（僵尸从它头上走过去，不吃它），
##   左边一有僵尸就从地里冒出来照着它后背连打，左边空了再缩回去**。
##
## ★ 整条逻辑只有一个判据（和仙人掌 `plant_cactus.gd` 那种「按条件起落」的状态机同一个路子）：
##   `_find_target()` **有 → 起身 / 一直打；没有 → 低头**。没有「打够几拳就收」这种计数。
##   场上循环就是：`idle_down*` ⇄ `up` → `attack` → `attack_loop`（循环打）→ `attack_end` → `down`。
##
## ★ 动画是 `.pam.bin` + 模组内的 PAM 播放器（**不是**菜问那条烘焙成 `AnimationPlayer` 的路）：
##   `celerystalker/` 下是 bin + 图集，播放器在 `pam/pam_animator.gd`（一个 `Node2D` 在 `_draw()`
##   里画四边形，没有 `AnimationPlayer`、没有 AnimationTree）。17 段状态全在 bin 里，
##   本脚本只决定「什么时候播哪一段」。**本脚本不参与动画制作。**
##
##   ★ 这 17 段各是什么（`celerystalker_anim.tscn` 的注释里只列了名字，含义是照着烘焙数据量出来的，
##     重新烘焙后可以按这三条复核）：
##     · `idle` / `idle2` / `idle3` / `idle4`（各 50 帧＝1.67 秒）：**站在地上**的呼吸循环。
##       全部部件的绘制包围盒 y ∈ [69, 240]（画布 390×390，地面线在 y≈240），是整株。
##     · `down`（32 帧）与 `up`（32 帧）：**缩回地里 / 冒出来**，一上一下各 1.07 秒，带扬土。
##       两段的包围盒在前后几帧里会横向撑到 x ∈ [90, 329]（那是土块），主体则从整株慢慢只剩一截。
##     · `idle_down` / `idle_down2` / `idle_down3`（各 50 帧）：**缩在地里**的循环 ——
##       只剩 y ∈ [165, 239] 那一小截（刚够贴着地面露头），所以「藏起来」时僵尸跨过去也看不见多少东西。
##     · `attack`（8 帧＝0.27 秒）：**朝左**打一拳，第 4 帧手伸到最远（x 从 136 → 89）。
##     · `attack_loop`（21 帧＝0.7 秒）：**朝左连打两拳**，第 1~9 帧与第 10~18 帧各一次大伸展
##       （最远 x 到 -21，离画布中心 ≈ 216 px），是一个循环段。
##     · `attack_end`（18 帧＝0.6 秒）：打完的收势（包围盒几乎不动），不造成伤害。
##     · `attack_special`（24 帧）、`plantfood_on` / `plantfood` / `plantfood_off`、`water`：
##       本株**不用**（能量豆 / 浇水 / 特殊攻击都没做；菜问那株同样只用了待机与出拳）。
##
##   ★ 出拳为什么只往**左**：僵尸从右往左走，走到芹菜身上再往左才叫「走到它背后」；
##     `attack` / `attack_loop` 的可视部件全部在左侧伸展（见上），PVZ2 原版也是从背后下手。
##     所以本株**不打右边** —— 右边来的僵尸只能啃它（出拳期间受击盒会打开，见下一条）。
##
## ★ 藏着的时候为什么啃不到：把受击盒 `hurt_box_component` 关掉（`E_IsEnableFactor.Character`）。
##   僵尸挑「啃哪株」靠它自己的 `DetectComponent`（`AttackComponent` 下那个前伸 50×5 的小框）
##   与植物的受击盒重叠 —— 受击盒 `monitorable = false` 之后根本重叠不到，也就不啃了。
##   这与地刺那种「受击状态位把僵尸的掩码挡掉」不是一条路（那条会一直生效，本株冒头时要能被打）。
##   缩回去的过程中同样关着（`down` 那 1.07 秒里它半截还在地面上）。
##
##   ★ 但「冒头之后」不能一直关着（那就无敌了）：出拳期间每 0.1 秒按目标位置重判一次 ——
##     目标走到 `behind_safe_distance`（32 px）之外才开受击盒。32 是量出来的：
##     僵尸啃食框在身前、宽 50 且中心偏 -13 ⇒ 有 12 px 伸到自己身后；植物受击框半宽 20 px。
##     12 + 20 = 32，比这更近时两个框还叠着，开着就等于「刚冒头就被它回头啃」。
##     走开之后就是正常代价：**右边**新来的僵尸照样能啃它（它打不到右边）。
##
## ★ 冒头的触发点（`trigger_offset`）：僵尸**中心**走到本方中心左边才算数（默认 4 px）。
##   再往右就冒头会出事：僵尸的啃食框在它身前（局部 x≈-13，宽 50），
##   植物还在它前头 → 冒头那一下就被啃。所以「踩到身上」= x 已经小于本方中心。
##   冒头过程（`up`，1.07 秒）也一直关着受击盒，出拳期间按下面那 32 px 的判据决定开不开。
##
## ★ 数值都是**模组自己的取值**，不是照 PVZ2 wiki 抄的 —— 要对齐请自己查过再改。
##
## ⚠️ 本文件跑在 `user://mods/pvz2/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_celerystalker.tscn` 按路径引用；
##    继承本体基类与跨文件引用一律用 `res://` 那套（`Plant000Base` / `preload`）。

const PamBridge := preload("../pam_bridge.gd")

## 动画挂点：场景里是个**空 Node2D**，脚本由 `PamBridge.attach()` 在 `character_ready()` 里挂上
## （跨模组不能写死 `res://` 路径，见 `../pam_bridge.gd` 文件头）
@onready var _anim = $Body/CeleryStalkerAnim
@onready var _detect_component: DetectComponent = $DetectComponent
## 露头判定用的扫查计时器（藏在地里时每 0.1 秒看一次「有没有僵尸走到我左边」）
@onready var _scan_timer: Timer = $ScanTimer


#region 数值
## 一拳的伤害（RTON `CeleryStalkerProps` 的原值：100 / 0.5 秒）
@export var punch_damage := 100
## 拳头往左够多远（像素）。`attack_loop` 最远伸展 ≈ 216 画布像素 × 0.55 缩放 ≈ 119
@export var reach_left := 130.0
## 僵尸中心走到本方中心左边多少像素才算「踩到它身上」（见文件头「冒头的触发点」）
@export var trigger_offset := -4.0
## 僵尸中心离本方多近时**还不能**被啃（它的啃食框还有 12 px 伸到自己身后，植物受击框半宽 20 px：
## 12 + 20 = 32 —— 比这更近时两个框还叠着，开着受击盒就等于「刚冒头就被回头啃」）
@export var behind_safe_distance := 32.0
#endregion


#region 动画资源与摆放
const BIN_REL_PATH := "celerystalker/celerystalker.pam.bin"
const ATLAS_REL_PATH := "celerystalker/celerystalker_atlas.png"
## 摆放（数是从 `test/scenarios/probe_pvz2_pam.gd` 打印的待机包围盒量出来的）：
## 待机帧在画布坐标占 155×170、底部正好落在画布中心线上 ⇒ `pivot_offset = (0, -45)`
## （画布 390×390，地面线在 y≈240）；`scale = 0.55` 让整株 ≈ 85×94 px（格子 76×95）
## ⚠️ `pivot_offset.y` 越小画面越靠上（脚悬空就把它调大），口径见
##    `../firepeashooter/firepeashooter_plant.gd` 同名常量上的说明。
const ANIM_PIVOT := Vector2(0, -45)
const ANIM_SCALE := 0.55
## 装扮（海盗帽 + 蓝外套那一套）：PVZ2 把服饰和本体塞在同一条时间轴上，本作不需要
const HIDDEN_PARTS: Array[String] = [
	"custom_02", "custom_01", "_custom_left", "custom_02_02", "custom_01_01", "_custom_right",
]
## 单次播放的状态（播完发 `animation_finished`）
const ONESHOT_STATES: Array[String] = [
	"attack", "attack_end", "attack_special", "down", "up", "plantfood_on", "plantfood_off",
]
#endregion


#region 状态与动画常量
## 四段流程：藏着 / 冒头 / 出拳 / 缩回
##
## ★ 判据只有一个（和仙人掌 `plant_cactus.gd` 那种「按条件起落」的状态机同一个路子）：
##   **左边有僵尸就起身，没有就低头**。没有「打几拳就收」这种计数 —— 只要 `_find_target()` 还在，
##   就一直 `attack` → `attack_loop` 循环打；它一走空（走出 `reach_left` / 死了），立刻收势缩回去。
enum E_Phase { Hidden, Rise, Attack, Sink }

const IDLE_DOWN_ANIMS: Array[String] = ["idle_down", "idle_down2", "idle_down3"]
const IDLE_ANIMS: Array[String] = ["idle", "idle2", "idle3", "idle4"]

const STATE_UP := "up"
const STATE_ATTACK := "attack"
const STATE_ATTACK_LOOP := "attack_loop"
const STATE_ATTACK_END := "attack_end"
const STATE_DOWN := "down"

## 出拳的命中帧（量出来的：`attack` 第 4 帧手伸到最远；`attack_loop` 第 7、16 帧是两次大伸展的顶点）
const ATTACK_IMPACT_FRAME := 4
const ATTACK_LOOP_IMPACT_FRAMES: Array[int] = [7, 16]

var _phase := E_Phase.Hidden
## 已经在收势（防止「命中帧那一拳」与「循环转完」两条路各调一次 `attack_end`，把收势打断重播）
var _finishing := false
var _idle_down_index := 0
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
	_anim.animation_finished.connect(_on_anim_finished)
	_anim.loop_completed.connect(_on_anim_loop_completed)
	_anim.state_frame_changed.connect(_on_anim_state_frame_changed)
	_scan_timer.timeout.connect(_on_scan_timer_timeout)


## 初始化正常出战角色：一落地就是「缩在地里」，受击盒先关掉
func ready_norm() -> void:
	super()
	_phase = E_Phase.Hidden
	_set_eatable(false)
	_play_idle_down()
	_scan_timer.start()


## 初始化展示角色（图鉴 / 选卡界面里的静态形象）：站着的待机，不是「缩在地里」那一截
func ready_show() -> void:
	super()
	_anim.set_state(IDLE_ANIMS[0])
#endregion


#region 藏着 → 冒头
## 每 0.1 秒扫一次：
##  · 藏着时 —— 有僵尸走到左边（并且还在拳头够得到的范围里）就冒头
##  · 出拳时 —— 重新判一次「能不能被啃」（僵尸走开 / 又贴上来都会变，见 `_refresh_eatable()`）
func _on_scan_timer_timeout() -> void:
	if is_death:
		return
	match _phase:
		E_Phase.Hidden:
			## 睡着（睡眠组件把检测组件关掉）/ 检测组件没启用时不动
			if not _detect_component.is_enabling:
				return
			if _find_target() != null:
				_start_rise()
		E_Phase.Attack:
			_refresh_eatable()


## 冒头：受击盒仍然关着（这时僵尸就站在它头顶，开着一冒头就被啃）
func _start_rise() -> void:
	_phase = E_Phase.Rise
	_set_eatable(false)
	_anim.set_state(STATE_UP)


## 冒头播完 → 开始出拳
func _start_attack() -> void:
	_phase = E_Phase.Attack
	_finishing = false
	## 受击盒开不开看「僵尸走开了没有」，见 `_refresh_eatable()`
	_refresh_eatable()
	_anim.set_state(STATE_ATTACK)


## 出拳期间能不能被啃：**目标已经走出它的啃食框**（`behind_safe_distance`）才能被啃
##
## ★ 为什么要这一条：僵尸的啃食框在它身前（局部 x ≈ -13，宽 50 → 还有 12 px 伸到自己身后），
##   而植物的受击框以自身为中心、半宽 20 px。僵尸刚走到芹菜身后（dx 只有几像素）时两个框还叠着 ——
##   这时候把受击盒打开，等于「刚冒头就被目标回头啃」，伏击这层玩法直接没了。
##   等它走开 32 px（12 + 20）之后再开：这时它啃不到我，而右边新来的僵尸照样能啃（这才是代价）。
func _refresh_eatable() -> void:
	var target := _find_target()
	if target == null:
		_set_eatable(false)
		return
	var dx := target.global_position.x - global_position.x
	_set_eatable(dx <= -behind_safe_distance)
#endregion


#region 出拳
## 挑目标：本行里「已经走到我左边、又还没走出拳头范围」的最近那只僵尸
##
## 检测框本身已经按行与敌我过滤过（见 `DetectComponent._judge_enemy_is_can_be_attack`），
## 这里只补「位置」这一条 —— 还在右边的（没走到它身后）不打。
func _find_target() -> Zombie000Base:
	var nearest: Zombie000Base = null
	var nearest_dist := INF
	for enemy in _detect_component.get_all_enemy_can_be_attacked():
		var zombie := enemy as Zombie000Base
		if zombie == null or zombie.is_death:
			continue
		var dx := zombie.global_position.x - global_position.x
		if dx > trigger_offset:
			continue
		if dx < -reach_left:
			continue
		var dist := absf(dx)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = zombie
	return nearest


## 打一拳：只打挑中的那一只（拳头是朝左直出，不是横扫）
func _punch_once() -> void:
	var target := _find_target()
	if target == null:
		## 目标跑了 / 打死了：不再空挥，直接收势
		_start_finish()
		return
	SoundManager.play_character_SFX("Throw")
	var info := DamageInfo.create(target, punch_damage,
		ConstDamage.E_DamageMode.Real, ConstDamage.E_DamageCause.Script)
	## 写上发起者：伤害归属（反伤 / 统计）要用
	info.attacker = self
	var result := target.apply_damage(info)
	## 打中了才闪白光（被免疫了不闪）
	if result.is_applied:
		target.be_hit_light()
	## 打完这一拳再看一眼：左边空了（打死了 / 走出范围）就收势，否则接着打
	if _find_target() == null:
		_start_finish()


## 收势（`attack_end` 那 0.6 秒）：左边空了就走这里
func _start_finish() -> void:
	if _phase != E_Phase.Attack or _finishing:
		return
	_finishing = true
	_anim.set_state(STATE_ATTACK_END)


## 缩回地里：受击盒关掉（`down` 的过程里半截身子还在地面上，但已经不算「在场上」）
func _start_sink() -> void:
	_phase = E_Phase.Sink
	_set_eatable(false)
	_anim.set_state(STATE_DOWN)


## 缩回去播完 → 回到藏着，继续等下一只
func _back_to_hidden() -> void:
	_phase = E_Phase.Hidden
	_finishing = false
	_play_idle_down()
#endregion


#region 动画回调
## 单次段播完：冒头 → 出拳，出拳 → 循环，收势 → 缩回，缩回 → 藏着
##
## ⚠️ `attack_loop` 是**循环段**，不会走到这里（循环段的结束看 `loop_completed`）。
func _on_anim_finished(state_name: String) -> void:
	if is_death:
		return
	match state_name:
		STATE_UP:
			if _phase == E_Phase.Rise:
				_start_attack()
		STATE_ATTACK:
			if _phase != E_Phase.Attack or _finishing:
				return
			if _find_target() == null:
				_start_finish()
			else:
				_anim.set_state(STATE_ATTACK_LOOP)
		STATE_ATTACK_END:
			if _phase == E_Phase.Attack:
				_start_sink()
		STATE_DOWN:
			if _phase == E_Phase.Sink:
				_back_to_hidden()


## 循环段转完一圈
func _on_anim_loop_completed(state_name: String) -> void:
	if is_death:
		return
	if state_name == STATE_ATTACK_LOOP and _phase == E_Phase.Attack:
		## 循环段里目标跑掉了（这一圈的命中帧都没打上）：别原地空挥，收势
		if _find_target() == null:
			_start_finish()
		return
	if _phase == E_Phase.Hidden and state_name in IDLE_DOWN_ANIMS:
		## 藏在低下的待机三段接龙
		_play_idle_down()


## 状态内帧号变化：到命中帧就打一拳
func _on_anim_state_frame_changed(state_name: String, frame: int) -> void:
	if is_death or _phase != E_Phase.Attack:
		return
	match state_name:
		STATE_ATTACK:
			if frame == ATTACK_IMPACT_FRAME:
				_punch_once()
		STATE_ATTACK_LOOP:
			if frame in ATTACK_LOOP_IMPACT_FRAMES:
				_punch_once()


## 藏在地里的待机三段接龙：播当前这段，游标挪到下一段
func _play_idle_down() -> void:
	_anim.set_state(IDLE_DOWN_ANIMS[_idle_down_index])
	_idle_down_index = (_idle_down_index + 1) % IDLE_DOWN_ANIMS.size()
#endregion


#region 受击盒
## 能不能被啃（也能不能被炸）：藏着时整个受击盒关掉，僵尸的检测框重叠不到它
func _set_eatable(value: bool) -> void:
	if not is_instance_valid(hurt_box_component):
		return
	## 已经死了就别再打开（死亡那条路自己也关了一次，别把它顶回来）
	if value and is_death:
		return
	hurt_box_component.change_is_enabling(value, ComponentNormBase.E_IsEnableFactor.Character)
#endregion
