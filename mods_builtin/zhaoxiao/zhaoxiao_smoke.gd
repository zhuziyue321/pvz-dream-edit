extends Node
## 模组「招笑版」：**烟熏状态** —— 挂在被烟熏的僵尸身上，`SMOKE_TIME`（30 秒）后自己撤干净
##
## ★ 它的两条效果（需求 4）：
##
## **① 遇到植物时站立、不啃**：
##   本体判「我这只僵尸贴到植物了」就是 `zombie.is_attack`（攻击组件收到检测信号后置位，
##   同一根信号也把移动因素 `IsAttack` 打开 —— 所以它**本来就停住了**，这里不用自己定身）。
##   要做的是把那一下的**伤害压成 0** 并把动画**从「啃」换成待机**：
##     · 伤害：本体每 8 帧按 `curr_attack_value_per_min` 算一次啃咬伤害，把它摁成 0 即可
##       （0 走伤害管线会被直接取消，一滴血都不掉，也不播受击音效）；
##     · 动画：置 `is_idle = true` + 把动画状态机**硬跳到 `Idle`**
##       —— 本体**没有 `Walk→Idle` 转移**（Idle 只能从 `Start` 进），所以只能 `play()` 硬跳；
##       跳过去之后 `Idle→Walk` 的条件 `not is_idle` 被我们压住 ⇒ 站得住。
##       植物没了 / 被铲掉时 `is_attack` 自己落回 false ⇒ 我们放开 `is_idle`，本体自动走回 Walk。
##
## **② 被僵尸索敌**：
##   脚底下挂一株**隐形诱饵**（本体工具植物 `PlantIds.INVISIBLE`，见 `plant_invisible.gd`），
##   把它的 `damage_link` 指到宿主 —— 别的僵尸的啃咬检测会把它当**植物**（诱饵是植物方），
##   于是它们停下来啃诱饵；而啃在诱饵身上的伤害被**原样转给宿主**，诱饵自己不掉血。
##   ⚠️ 诱饵必须在**同一个假格子**里登记（见 `_spawn_decoy()`），否则本体的索敌问
##      「这一格该打哪一株」时会拿到空值、僵尸就不会停下。
##
## ⚠️ 本类是普通 `Node`（不是 `Character000Base` / `ComponentNormBase` 的子类），
##    `_ready()` 按 Godot 常态写即可 —— 硬约束 §1-3 只管那两类角色 / 组件。

const Settings := preload("zhaoxiao_settings.gd")

## 状态节点名（入口脚本 / 探针按它判「这只僵尸被烟熏过没有」）
const NODE_NAME := &"SmokedStatus"
## 同一个名字的 NodePath 形态（`get_node_or_null()` 只收 NodePath）
const NODE_PATH := ^"SmokedStatus"
## 诱饵节点名 / NodePath
const DECOY_NAME := &"SmokeDecoy"
const DECOY_PATH := ^"SmokeDecoy"
## 动画状态机里「待机」那个状态名（本体各僵尸通用：Idle / Walk / eat / Death …）
const IDLE_STATE := &"Idle"
## 动画状态机 playback 的参数路径（与 `component_anim_norm.gd` 的常量同源）
const PLAYBACK_PARAM := &"parameters/StateMachine/playback"

## 宿主（被烟熏的那只僵尸）
var _zombie: Zombie000Base
## 宿主的啃咬组件（普通僵尸版才有 `curr_attack_value_per_min`，其余僵尸拿不到就只做动画那半）
var _eater: AttackComponentZombieNorm
## 动画树与它的状态机 playback（拿不到就不切动画，只保留「停下 + 不啃」）
var _playback: AnimationNodeStateMachinePlayback
## 脚下那株隐形诱饵
var _decoy: PlantInvisible
## 倒计时
var _timer: Timer

## 烟熏前那只僵尸的啃咬值（撤离时按它还原，别把人家摁成 0 就回不来）
var _attack_value_before := -1
## 现在是不是我们把动画摁在待机上（撤离时要放开）
var _is_forcing_idle := false


#region 生命周期
func _ready() -> void:
	_zombie = get_parent() as Zombie000Base
	if _zombie == null:
		Log.error("招笑版模组：烟熏状态的父节点不是僵尸，本状态不生效")
		return
	_eater = _zombie.attack_component as AttackComponentZombieNorm
	if _eater != null:
		_attack_value_before = _eater.curr_attack_value_per_min
	var anim_tree := _zombie.get_node_or_null(^"AnimationTree") as AnimationTree
	if anim_tree != null:
		_playback = anim_tree.get(PLAYBACK_PARAM) as AnimationNodeStateMachinePlayback
	_spawn_decoy()
	_start_timer()
	set_process(true)


## 续时（同一只僵尸又被烟熏了一次：只把 30 秒重新数起，不重复挂状态）
func refresh() -> void:
	if is_instance_valid(_timer):
		_timer.start(Settings.SMOKE_TIME)


func _start_timer() -> void:
	if not is_instance_valid(_timer):
		_timer = Timer.new()
		_timer.name = &"SmokeTimer"
		_timer.one_shot = true
		_timer.wait_time = Settings.SMOKE_TIME
		add_child(_timer)
		_timer.timeout.connect(_on_smoke_timer_timeout)
	_timer.start(Settings.SMOKE_TIME)


func _on_smoke_timer_timeout() -> void:
	## 到点：撤干净然后自己消失
	stop_smoke()
	queue_free()
#endregion


#region 每帧：摁住啃咬伤害 + 按「贴没贴到植物」切待机
func _process(_delta: float) -> void:
	if not is_instance_valid(_zombie):
		return
	_keep_bite_damage_zero()
	var should_idle := _zombie.is_attack
	if should_idle == _is_forcing_idle:
		return
	if should_idle:
		_force_idle()
	else:
		_release_idle()


## 把啃咬伤害摁在 0
##
## 每帧摁而不是只摁一次：本体在速度变化（冰冻 / 黄油 / 报纸破防…）时会**重算**这个值，
## 只摁一次会被它盖回去。
func _keep_bite_damage_zero() -> void:
	if _eater != null and _eater.curr_attack_value_per_min != 0:
		_eater.curr_attack_value_per_min = 0


## 切到「站着待机」（贴到植物了）
func _force_idle() -> void:
	_is_forcing_idle = true
	_zombie.is_idle = true
	if _playback != null:
		_playback.play(IDLE_STATE)


## 放开待机（植物没了 / 被铲了）：本体自己会从 Idle 走回 Walk
func _release_idle() -> void:
	_is_forcing_idle = false
	_zombie.is_idle = false
#endregion


#region 隐形诱饵：让别的僵尸「看得到、啃得到」宿主
## 在宿主脚下挂一株隐形诱饵，并把它的伤害转移指到宿主
##
## 造法照本体 `PlantCell.create_plant()` 的顺序：**先 `init_plant()` 再 `add_child()`**
## （反了的话 `character_init_type` 还是默认值，`_ready()` 会走错初始化分支）。
## ⚠️ `CharacterInitType` 必须是 `IsNorm`：展示态（`IsShow`）会**关掉受击框**
##   （`Character000Base.ready_show()`），那就谁都索敌不到它了。
## ⚠️ 那个 `PlantCell` 是个**没入树的假格子**：它只当坐标载体（`row_col` 决定 `lane`），
##   不入 `PlantCellManager.all_plant_cells` ⇒ 不占真实格子、不进存档、不影响种植。
func _spawn_decoy() -> void:
	var scene := _decoy_scene()
	if scene == null:
		Log.warn("招笑版模组：拿不到隐形植物场景，本次烟熏只有「站立 + 不啃」那半")
		return
	var decoy := scene.instantiate() as PlantInvisible
	if decoy == null:
		return
	var cell := PlantCell.new()
	cell.row_col = Vector2i(_zombie.lane, 0)
	decoy.name = DECOY_NAME
	## 打在诱饵身上的伤害原样转给宿主 —— 「僵尸啃诱饵」等于「啃被烟熏的那只」
	decoy.damage_link = _zombie
	decoy.init_plant({
		Plant000Base.E_PInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Plant000Base.E_PInitAttr.PlantCell: cell,
		Plant000Base.E_PInitAttr.IsImitaterMaterial: false,
	})
	## 诱饵必须登记在这个假格子的 Norm 槽里：本体索敌会问「这一格该打哪一株」
	## （`DetectTargetStrategy.get_first_be_hit_plant_in_cell`），查的就是这个槽
	cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm] = decoy
	_zombie.add_child(decoy)
	decoy.position = Settings.SMOKE_DECOY_OFFSET
	_decoy = decoy


## 诱饵场景：**走注册表按 id 取**（硬约束 §1-4：别在业务代码里散落「id → 场景」映射表）
func _decoy_scene() -> PackedScene:
	return Global.character_registry.get_plant_info(
		PlantIds.INVISIBLE, CharacterRegistry.PlantInfoAttribute.PlantScenes) as PackedScene
#endregion


#region 撤离
## 把烟熏做的事全部还回去（探针也会直接调它，不必等 30 秒）
func stop_smoke() -> void:
	if is_instance_valid(_zombie):
		if _is_forcing_idle:
			_release_idle()
		if _eater != null and _attack_value_before >= 0:
			_eater.curr_attack_value_per_min = _attack_value_before
	_remove_decoy()


## 拆掉诱饵
##
## 走**正常死亡流程**而不是直接 `queue_free()`：它会发 `signal_character_death`，
## 正咬着它的那些僵尸靠这条信号重判目标 —— 不然它们的 `enemy_can_be_attacked`
## 会一直指着一个已释放的实例，表现为「烟熏没了但那只僵尸还站在那儿啃空气」。
func _remove_decoy() -> void:
	if not is_instance_valid(_decoy):
		_decoy = null
		return
	_decoy.damage_link = null
	_decoy.hp_component_plant.is_death_free = true
	_decoy.character_death()
	_decoy = null
#endregion
