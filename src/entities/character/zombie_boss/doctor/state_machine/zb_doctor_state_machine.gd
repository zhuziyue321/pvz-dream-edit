## 博士专用状态机：按原版四计数器优先级选择技能、同步计时倍率和校验配置，死亡始终优先。
## 由博士正常出战初始化显式启动；状态请求动画，专用控制器负责播放，速度仍由原动画组件处理。
## 每个技能管理自己的内部阶段与共享数据，根层不决定技能如何收尾。
## 场景中绑定角色、播放器、入场、待机、五技能和死亡状态。
##
## 技能调度完全照原版《植物大战僵尸》移植（参照 `../PvZ-Portable-main/src/Lawn/Zombie.cpp`
## 的 `UpdateBoss()` / `Boss*Attack()` 系列，行号基准见 `docs/参考存档/植物僵尸逻辑对照.md`）：
## 四条技能线（放置 / 脚踩 / 蹦极 / 吐球）各自持有倒计时计数器，并行倒计时；
## 每轮空闲按原版 else-if 链的固定优先级发招：
##   ① 破损阶段变化（<80% 进阶段 1 立即蹦极一次，<50% 进阶段 2 立即砸车一次）
##   ② 脚踩计数到 0 → 踩踏（无目标也消耗本轮并重置计数）
##   ③ 蹦极计数到 0 → 冒险 1/4、其余 1/2 概率改砸车，否则蹦极
##   ④ 吐球计数到 0 → 低头吐球
##   ⑤ 放置计数到 0 → 召唤一只僵尸（间隔随破损阶段递减）
## 踩踏与蹦极在首次砸车落地 / 首次进入阶段 1 前锁定（计数器为 -1，永不满足 == 0）。
extends CharacterStateMachine
class_name ZB001DoctorStateMachine

## 技能开跑即重置对应计数，不在此层保存跨技能的选择历史。

## 放置间隔按破损阶段递减，单位为秒，x 到 y 闭区间随机；原版 mSummonCounter
## 450~550 / 350~450 / 150~250 tick（100 tick = 1 秒）。
@export var summon_interval_by_stage: Array[Vector2] = [
	Vector2(4.5, 5.5), Vector2(3.5, 4.5), Vector2(1.5, 2.5),
]
## 脚踩重复间隔区间，单位为秒；原版 mBossStompCounter 5500~6500 tick。
@export var stomp_interval_range: Vector2 = Vector2(55.0, 65.0)
## 蹦极重复间隔区间，单位为秒；原版 mBossBungeeCounter 4000~5000 tick。
@export var bungee_interval_range: Vector2 = Vector2(40.0, 50.0)
## 吐球重复间隔区间，单位为秒；原版 mBossHeadCounter 4000~5000 tick。
@export var head_interval_range: Vector2 = Vector2(40.0, 50.0)
## 蹦极计数到 0 时改砸车的概率；原版 Rand(IsAdventureMode ? 4 : 2) == 0。
@export_range(0.0, 1.0, 0.05) var rv_chance_adventure: float = 0.25
@export_range(0.0, 1.0, 0.05) var rv_chance_other: float = 0.5
## 每轮空闲决策前的等待区间，单位为秒；原版 mPhaseCounter 100~200 tick。
@export var idle_duration_range: Vector2 = Vector2(1.0, 2.0)

## 开局首次放置的等待秒数；原版入场时 mSummonCounter = 500 tick。
const FIRST_SUMMON_DELAY: float = 5.0
## 开局首次吐球的等待秒数；原版入场时 mBossHeadCounter = 5000 tick。
const FIRST_HEAD_DELAY: float = 50.0
## 砸车落地后的统一重置；原版 BossRVLanding：
## summon 500 / head 5000 / stomp 4000（阶段 ≥1）/ bungee 6500（阶段 ≥2）tick。
const RV_SUMMON_DELAY: float = 5.0
const RV_HEAD_DELAY: float = 50.0
const RV_STOMP_DELAY: float = 40.0
const RV_BUNGEE_DELAY: float = 65.0

## 死亡演出状态引用，死亡请求会优先切换到此状态。
@export var dying_state: ZB001DoctorStateDying
## 死亡演出完成后的终止状态引用，负责停止行动并清理角色。
@export var dead_state: ZB001DoctorStateDead
## 博士自身的动画控制器，负责姿势过渡、实例动画副本及本体联动。
@export var animation_controller: ZB001DoctorAnimationController
## 普通待机状态引用；入场或技能收尾后进入，等待下一轮技能调度。
@export var idle_state: ZB001DoctorStateIdle

## 是否已接收逻辑死亡请求；置位后禁止新的普通技能转换与释放。
var _death_requested := false
## 死亡演出是否已经启动，用于阻止 stop/start 重复播放死亡流程。
var _death_started := false
## 实际连接的动画控制器，重新初始化或离树时据此清理旧连接。
var _connected_animation_controller: ZB001DoctorAnimationController
## 初始化时收集的动作计时器；仅含状态机子树，不含博士根节点的 DeathRemainTimer。
var _action_timers: Array[SpeedTimer] = []
## 上次已同步给动作计时器的实际倍率；合法值非负，-1 表示缓存失效，需重新同步全部计时器。
var _last_action_speed: float = -1.0
## 初始化时解析的直属技能状态；按子节点顺序缓存，技能开跑时据此重置对应计数器。
var _skill_states: Array[ZB001DoctorSkillState] = []

## —— 原版技能计数器（单位：秒；-1 表示该技能线尚未解锁）——
## 放置计数；开局 FIRST_SUMMON_DELAY，每次召唤开始时按破损阶段重置。
var summon_counter: float = FIRST_SUMMON_DELAY
## 吐球计数；开局 FIRST_HEAD_DELAY，每次吐球开始时重置。
var head_counter: float = FIRST_HEAD_DELAY
## 脚踩计数；首次砸车落地前为 -1（锁定），砸车落地后每次踩踏重置 55~65 秒。
var stomp_counter: float = -1.0
## 蹦极计数；首次进入破损阶段 1 前为 -1（锁定），此后每次蹦极 / 蹦极轮砸车重置 40~50 秒。
var bungee_counter: float = -1.0
## 当前破损阶段（原版 mBossMode / GetBodyDamageIndex：0 满血、1 低于 80%、2 低于 50%）。
var boss_damage_stage: int = 0
## 博士本局存活时长（原版 mZombieAge，秒）；放置类型按它分段，不受冻结影响。
var battle_age: float = 0.0

## 五个技能的缓存引用；初始化时按类型解析，缺失会在配置检查中报告。
var spawn_skill: ZB001DoctorStateSpawn
var head_skill: ZB001DoctorStateHeadSkill
var bungee_skill: ZB001DoctorStateBungee
var rv_skill: ZB001DoctorStateThrowRV
var stomp_skill: ZB001DoctorStateStomp

## 提供博士类型引用，避免各状态重复转换；原始引用仍由通用状态机统一维护。
var boss: ZB001Doctor:
	get:
		return character as ZB001Doctor


## 在状态注册前拒绝其他角色，避免专用状态读取博士接口时才发生错误。
## [param actor] 待检查或注入的所属角色；具体允许的角色类型由当前状态或状态机限定。
func accepts_character(actor: Character000Base) -> bool:
	return is_instance_valid(actor) and actor is ZB001Doctor


## 先让通用层重置旧连接并注册状态，再完成博士专用检查；通过前不会播放动画。
## 失败会清除初始化标记，保证后续 start() 不能绕过失败的配置检查。
## [param actor] 本次初始化的角色；null 表示保留已有角色引用。
## [param player] 主体动画播放器；传入 null 表示保留状态机已有引用。
func initialize(actor: Character000Base = null, player: AnimationPlayer = null) -> bool:
	if _switching:
		return false
	if not super.initialize(actor, player):
		Log.error("ZB001DoctorStateMachine：角色必须为博士，且状态节点和入口必须属于当前状态机。")
		return false
	_cache_skill_states()
	_cache_action_timers()
	# 具体检测分支已输出错误；这里只处理失败清理，避免日志统一指向 initialize()。
	var configuration_error := _get_configuration_error()
	if not configuration_error.is_empty():
		stop()
		_disconnect_animation_player()
		_initialized = false
		return false
	_reset_skill_counters()
	# 只有全部校验通过后才修正技能运行时配置，查询错误不会改变战力预算。
	# 当前已解析并通过校验的技能，按缓存引用初始化本实例的效果组件。
	for skill: ZB001DoctorSkillState in _skill_states:
		skill.effect_component.initialize_skill()
	_connected_animation_controller = animation_controller
	_connected_animation_controller.driver_animation_finished.connect(_on_driver_animation_finished)
	animation_controller.initialize(animation_player)
	return true


## 按类型解析当前实例的直属技能节点；每次初始化重建，缺失或重复的技能由配置检查报告。
func _cache_skill_states() -> void:
	_skill_states.clear()
	spawn_skill = null
	head_skill = null
	bungee_skill = null
	rv_skill = null
	stomp_skill = null
	# 直属子节点；技能必须挂在本状态机下，孙层子状态不参与调度。
	for child: Node in get_children():
		var skill := child as ZB001DoctorSkillState
		if skill == null:
			continue
		_skill_states.append(skill)
		if skill is ZB001DoctorStateSpawn:
			spawn_skill = skill
		elif skill is ZB001DoctorStateHeadSkill:
			head_skill = skill
		elif skill is ZB001DoctorStateBungee:
			bungee_skill = skill
		elif skill is ZB001DoctorStateThrowRV:
			rv_skill = skill
		elif skill is ZB001DoctorStateStomp:
			stomp_skill = skill


## 按原版入场初始化重置技能计数器（原版 ZombieInitialize BOSS 分支：
## mSummonCounter = 500、mBossHeadCounter = 5000，踩踏 / 蹦极保持 -1 锁定）。
func _reset_skill_counters() -> void:
	summon_counter = FIRST_SUMMON_DELAY
	head_counter = FIRST_HEAD_DELAY
	stomp_counter = -1.0
	bungee_counter = -1.0
	battle_age = 0.0
	# 当前阶段直接采信，不把初始化时的既有破损当作「阶段变化」。
	boss_damage_stage = _get_damage_stage()


## 原版 UpdateBoss 的技能优先级；返回 null 表示本轮不选技能，Idle 继续等待。
func select_skill() -> ZB001DoctorSkillState:
	# ① 破损阶段变化优先：进入阶段 1 立即放一次蹦极，进入阶段 2 立即扔一次房车。
	var stage: int = _get_damage_stage()
	if stage != boss_damage_stage:
		boss_damage_stage = stage
		if stage == 1 and bungee_skill != null:
			if bungee_skill.can_be_selected():
				return bungee_skill
			# 无偷取目标时仍按原版重置蹦极计数（BossBungeeAttack 一进来就写回计数器），
			# 之后按普通间隔重试，避免首次进入阶段 1 永久锁死蹦极线。
			bungee_counter = _rand_in_range(bungee_interval_range)
			return null
		if stage >= 2 and rv_skill != null:
			return rv_skill
	# ② 脚踩计数到 0：无目标时仍重置计数并消耗本轮（原版 BossStompAttack 提前返回）。
	if stomp_counter == 0.0:
		if stomp_skill != null and stomp_skill.can_be_selected():
			return stomp_skill
		stomp_counter = _rand_in_range(stomp_interval_range)
		return null
	# ③ 蹦极计数到 0：按模式概率改砸车，否则放蹦极；两种结果都先重置蹦极计数。
	if bungee_counter == 0.0:
		bungee_counter = _rand_in_range(bungee_interval_range)
		var rv_chance: float = rv_chance_adventure if _is_adventure_level() else rv_chance_other
		if rv_skill != null and randf() < rv_chance:
			return rv_skill
		if bungee_skill != null and bungee_skill.can_be_selected():
			return bungee_skill
		return null
	# ④ 吐球计数到 0。
	if head_counter == 0.0 and head_skill != null:
		head_counter = _rand_in_range(head_interval_range)
		return head_skill
	# ⑤ 放置计数到 0；间隔按当前破损阶段取区间。
	if summon_counter == 0.0 and spawn_skill != null:
		summon_counter = _get_summon_interval()
		return spawn_skill
	return null


## 技能请求提交成功即视为开跑；原版各 BossXxxAttack 在动画开始时写回自己的计数器。
## [param next_state] 已提交切换的目标状态；普通待机与死亡状态不重置任何计数。
func _on_skill_started(next_state: CharacterState) -> void:
	if next_state is ZB001DoctorStateSpawn:
		summon_counter = _get_summon_interval()
	elif next_state is ZB001DoctorStateStomp:
		stomp_counter = _rand_in_range(stomp_interval_range)
	elif next_state is ZB001DoctorStateBungee:
		bungee_counter = _rand_in_range(bungee_interval_range)
	elif next_state is ZB001DoctorStateHeadSkill:
		head_counter = _rand_in_range(head_interval_range)


## 原版 BossRVLanding：砸车落地统一重置技能线；
## 踩踏只在阶段 1 之后解锁，蹦极只在阶段 2 之后重新计时。
func on_rv_landed() -> void:
	summon_counter = RV_SUMMON_DELAY
	head_counter = RV_HEAD_DELAY
	if boss_damage_stage >= 1:
		stomp_counter = RV_STOMP_DELAY
	if boss_damage_stage >= 2:
		bungee_counter = RV_BUNGEE_DELAY


## 按当前破损阶段返回放置间隔；间隔区间见 summon_interval_by_stage。
func _get_summon_interval() -> float:
	var stage: int = clampi(boss_damage_stage, 0, summon_interval_by_stage.size() - 1)
	return _rand_in_range(summon_interval_by_stage[stage])


## 返回区间内随机秒数；x、y 顺序无关。
func _rand_in_range(range_value: Vector2) -> float:
	return randf_range(minf(range_value.x, range_value.y), maxf(range_value.x, range_value.y))


## 当前破损阶段（原版 GetBodyDamageIndex 的 BOSS 特判：<50% 为 2、<80% 为 1、其余 0）。
## 博士的破损阈值由场景按比例缩放（见 zb_base.gd），阶段索引直接复用 hp_stage_change 的结果。
func _get_damage_stage() -> int:
	if not is_instance_valid(boss) or not is_instance_valid(boss.hp_stage_change_component):
		return 0
	return clampi(boss.hp_stage_change_component.curr_hp_stage + 1, 0, 2)


## 本关是否冒险模式；原版砸车概率在冒险为 1/4、其余模式 1/2。
func _is_adventure_level() -> bool:
	if not is_instance_valid(boss):
		return false
	var game: MainGameManager = boss.get_main_game()
	var level_data := game.game_para if is_instance_valid(game) else null
	return level_data != null and level_data.game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure


## 返回本轮空闲等待秒数；每轮在区间内独立随机（原版 mPhaseCounter 100~200 tick）。
func get_idle_duration() -> float:
	return _rand_in_range(idle_duration_range)


## [param animation_name] 为已结束的本体动作；只有死亡状态可以推进本体死亡序列。
func _on_driver_animation_finished(animation_name: StringName) -> void:
	if is_running and (_death_requested or boss.is_death) and current_state == dying_state:
		dying_state.on_driver_animation_finished(animation_name)


## 清理本体事件、控制器播放器连接和通用机甲结束信号；重新初始化时重建计时器缓存。
func _disconnect_animation_player() -> void:
	if is_instance_valid(_connected_animation_controller):
		if _connected_animation_controller.driver_animation_finished.is_connected(_on_driver_animation_finished):
			_connected_animation_controller.driver_animation_finished.disconnect(_on_driver_animation_finished)
		_connected_animation_controller.disconnect_players()
	_connected_animation_controller = null
	_skill_states.clear()
	spawn_skill = null
	head_skill = null
	bungee_skill = null
	rv_skill = null
	stomp_skill = null
	_action_timers.clear()
	_last_action_speed = -1.0
	super._disconnect_animation_player()


## 死亡请求优先于技能请求；尚未启动或正在切换时延迟启动，避免重入 enter/exit。
func request_death() -> void:
	if _death_requested or not is_instance_valid(boss) or not boss.is_death:
		return
	_death_requested = true
	animation_controller.cancel_driver_reaction()
	_stop_action_timers()
	# 子状态机停止后会清空当前阶段，必须提前记录死亡是否需要先抬头。
	dying_state.prepare_interruption(current_state)
	# 立即停止当前技能子层，不能等下一物理帧再取消内部排队动作。
	if current_state is CharacterCompositeState:
		current_state.child_state_machine.stop()
	if is_running and not _switching:
		_pending_state = null
		change_state(dying_state)
	else:
		_start_death.call_deferred()


## 血量可能在延迟入场前归零，此时直接从 Dying 启动，等待中的 Enter 启动会自行取消。
func _start_death() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(boss) \
		or not boss.is_inside_tree() or boss.is_queued_for_deletion():
		return
	if is_running:
		change_state(dying_state)
	elif not start(dying_state):
		Log.error("ZB001DoctorStateMachine：无法启动死亡演出，请检查状态与动画配置。")


## 已死亡的博士不能重新启动入场；死亡演出也不能通过 stop/start 重播。
## [param state] 指定启动状态；null 时使用已配置的 initial_state。
func start(state: CharacterState = null) -> bool:
	if is_running or _switching:
		return false
	if is_instance_valid(boss) and boss.is_death:
		if state != dying_state or not _death_requested or _death_started:
			return false
	# 提前死亡可能在普通初始化之前启动；初始化清理结束后才允许本体完成事件。
	if not _initialized and not initialize():
		return false
	animation_controller.set_active(true)
	# 通用启动成功后才记录死亡已开始，失败则恢复控制器停止状态。
	var started: bool = super.start(state)
	if not started:
		animation_controller.set_active(false)
	if started and current_state == dying_state:
		_death_started = true
	return started


## 死亡后只允许普通状态 -> Dying -> Dead，迟到的普通动作回调不能覆盖死亡请求。
## [param next_state] 请求进入的目标状态，必须是本状态机已注册的直属状态。
func change_state(next_state: CharacterState) -> bool:
	if _death_requested or (is_instance_valid(boss) and boss.is_death):
		if current_state == dead_state:
			return false
		if current_state == dying_state:
			if next_state != dead_state:
				return false
		elif next_state != dying_state:
			return false
	var changed: bool = super.change_state(next_state)
	if changed:
		_on_skill_started(next_state)
	return changed


## 停止、重新初始化与离树都会经过此入口，清理共享计时和非当前状态的遗留任务。
func stop() -> void:
	if is_instance_valid(animation_controller):
		animation_controller.set_active(false)
	_stop_action_timers()
	super.stop()


## 内部子状态改变受击规则后补发根节点通知，主层切换期间已有统一通知。
func notify_skill_status_changed() -> void:
	if is_running and not _switching and not boss.is_death:
		boss.signal_status_update.emit()


## 方法轨道携带动画名，拒绝其他动作的迟到事件；随后沿当前技能逐层路由。
## [param animation_name] 需要匹配的动画资源名称，与方法关键帧中的动画参数保持一致。
## [param event_name] 动画方法轨道传入的事件名，由当前活动状态判断是否处理。
func notify_skill_event(animation_name: StringName, event_name: StringName) -> void:
	if not is_running or _death_requested or boss.is_death or not current_state is ZB001DoctorSkillState:
		return
	# current_animation 在自然播放结束后为空；同帧跨过释放帧和末尾时方法轨道仍会延迟调用。
	# assigned_animation 保留刚结束的动画，结合当前活动状态的事件去重接受这次合法释放。
	if animation_player.assigned_animation != animation_name:
		return
	notify_animation_event(event_name)


## 初始化时收集固定状态树的动作计时器；运行时不遍历节点，结构改变后需重新初始化。
func _cache_action_timers() -> void:
	_action_timers.clear()
	# 新收集的计时器尚未同步；即使重初始化后的倍率相同，也必须完成一次完整同步。
	_last_action_speed = -1.0
	# 只遍历主状态机子树，死亡保留计时器在博士根节点下，由博士单独管理。
	for node: Node in find_children("*", "Timer", true, false):
		if node is SpeedTimer:
			_action_timers.append(node)


## 停止本次初始化收集的动作计时器；忽略运行时已被释放的引用。
func _stop_action_timers() -> void:
	# 缓存可能保留已释放对象，先以 Variant 检查有效性，再访问计时器。
	for timer in _action_timers:
		if is_instance_valid(timer):
			timer.stop()


## 跟随主体实际播放倍率，包括暂停与自定义播放倍率；倍率未变时跳过整个计时器列表。
## 返回本次读取的非负动作倍率，供逐帧更新复用；全局倍率由 Timer 自行处理。
func sync_action_timer_speed() -> float:
	# 当前动作计时倍率；播放器暂停或停止时为零。
	var action_speed: float = _get_action_speed()
	if action_speed == _last_action_speed:
		return action_speed
	_last_action_speed = action_speed
	# 缓存可能保留已释放对象，先以 Variant 检查有效性，再访问计时器。
	for timer in _action_timers:
		if is_instance_valid(timer):
			timer.set_speed_scale(action_speed)
	return action_speed


## 读取主体实际播放速度；蹦极等待改由事件结束，不需要额外推进计时。
func _get_action_speed() -> float:
	# 停止、暂停或非法倍率统一视为零速，状态切换仍由 advance 处理。
	var action_speed := animation_player.get_playing_speed() if is_instance_valid(animation_player) else 0.0
	return maxf(action_speed, 0.0) if is_finite(action_speed) else 0.0


## 更新前恢复死亡优先级；每帧读取实际动作倍率，仅在变化时同步计时器，再消化状态请求。
## [param delta] 本次更新步长，单位为秒；角色倍率是否已换算由调用层约定。
func advance(delta: float) -> void:
	if is_instance_valid(animation_controller):
		animation_controller.sync_driver_speed()
	if _death_requested and is_running and current_state != dying_state and current_state != dead_state:
		_pending_state = dying_state
	# 本帧已经读取并同步的实际倍率，后续状态更新和视觉复位复用，不再重复读取播放器。
	var action_speed: float = sync_action_timer_speed()
	# 仍保留状态逐帧行为的动作时间语义；零速也必须处理死亡等待切换请求。
	# 动作秒只在主层换算一次，状态更新和视觉复位共用同一时间尺度。
	var action_delta: float = maxf(delta, 0.0) * action_speed
	# 技能计数器跟随动作时间推进；动画暂停（冻结等）时四条技能线同步停住，
	# 对应原版 mIceTrapCounter > 0 时不递减计数器的口径。存活时长按真实秒累计。
	_tick_skill_counters(action_delta)
	battle_age += maxf(delta, 0.0)
	super.advance(action_delta)
	if is_instance_valid(animation_controller):
		animation_controller.advance_visual_returns(action_delta)
	if current_state == dying_state or current_state == dead_state:
		_death_started = true


## 四条技能线并行倒计时；锁定线（-1）与已到期的 0 不再递减。
## [param delta] 本帧动作秒；零或负数时跳过。
func _tick_skill_counters(delta: float) -> void:
	if delta <= 0.0:
		return
	if summon_counter > 0.0:
		summon_counter = maxf(0.0, summon_counter - delta)
	if stomp_counter > 0.0:
		stomp_counter = maxf(0.0, stomp_counter - delta)
	if bungee_counter > 0.0:
		bungee_counter = maxf(0.0, bungee_counter - delta)
	if head_counter > 0.0:
		head_counter = maxf(0.0, head_counter - delta)


## 死亡已请求但还未切换时，禁止旧动画继续分发技能关键帧。
## [param event_name] 动画方法轨道传入的事件名，由当前活动状态判断是否处理。
func notify_animation_event(event_name: StringName) -> void:
	if _death_requested and current_state != dying_state and current_state != dead_state:
		return
	super.notify_animation_event(event_name)


## [param anim_name] 本次结束的动画名称，供状态过滤无关动作的完成通知。
func _on_animation_finished(anim_name: StringName) -> void:
	if _death_requested and current_state != dying_state:
		return
	super._on_animation_finished(anim_name)


## 启动前校验主流程、五技能及死亡链路，避免运行中卡在缺少动画或引用的状态。
## 错误由检测分支就地输出；返回值供上层中止初始化，转发时不重复报错。
func _get_configuration_error() -> String:
	# 本函数发现的配置错误；下层返回的错误已经由下层报告。
	var detected_error: String = ""
	if character != get_parent():
		detected_error = "character 必须绑定状态机所属的博士根节点。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	if not is_instance_valid(animation_controller) or animation_controller.get_parent() != boss:
		detected_error = "animation_controller 必须绑定博士根节点下的动画控制器。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	# 先验证播放器和基础动画，后续状态才可安全读取动画资源检查方法事件。
	var animation_error: String = animation_controller.get_configuration_error(boss, animation_player)
	if not animation_error.is_empty():
		return animation_error
	if not initial_state is ZB001DoctorStateEnter or not _is_registered(initial_state):
		detected_error = "initial_state 必须绑定直属的 ZB001DoctorStateEnter 入场状态。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	if not idle_state is ZB001DoctorStateIdle or not _is_registered(idle_state):
		detected_error = "idle_state 必须绑定直属的 ZB001DoctorStateIdle 待机状态。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	if not _has_valid_range(idle_duration_range) or idle_duration_range.x <= 0.0:
		detected_error = "空闲等待区间必须为有限正数且下限不大于上限。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	# 五个技能各缓存一个实例；缺失说明场景少了节点或类型绑定错误。
	for skill: ZB001DoctorSkillState in [spawn_skill, head_skill, bungee_skill, rv_skill, stomp_skill]:
		if skill == null or not _is_registered(skill):
			detected_error = "必须配置放置、吐球、蹦极、砸车、脚踩五个直属技能各一个。"
			Log.error("%s：%s" % [get_path(), detected_error])
			return detected_error
	# 吐球技能必须唯一，供阶段 1 保底与计数器重置使用。
	var head_count: int = 0
	for skill: ZB001DoctorSkillState in _skill_states:
		if skill is ZB001DoctorStateHeadSkill:
			head_count += 1
	if head_count != 1:
		detected_error = "吐球技能必须恰好配置一个。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	# 调度区间与概率配置；非法值会在随机取值时表现异常，启动前拦截。
	if not _has_valid_range(summon_interval_by_stage[0]) or not _has_valid_range(summon_interval_by_stage[1]) \
		or not _has_valid_range(summon_interval_by_stage[2]) or summon_interval_by_stage.size() != 3:
		detected_error = "放置间隔必须为三个有限区间，且下限不大于上限。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	if not _has_valid_range(stomp_interval_range) or not _has_valid_range(bungee_interval_range) \
		or not _has_valid_range(head_interval_range):
		detected_error = "脚踩、蹦极、吐球的重复间隔必须为有限区间，且下限不大于上限。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	if not is_finite(rv_chance_adventure) or not is_finite(rv_chance_other) \
		or rv_chance_adventure < 0.0 or rv_chance_adventure > 1.0 \
		or rv_chance_other < 0.0 or rv_chance_other > 1.0:
		detected_error = "砸车概率必须位于 0 到 1 之间。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	# 当前技能及其子状态的配置错误；非空时阻止主状态机启动。
	for skill: ZB001DoctorSkillState in _skill_states:
		var skill_error := skill.get_configuration_error()
		if not skill_error.is_empty():
			return skill_error
	# 当前待停止、同步倍率或校验配置的动作计时器。
	for timer: SpeedTimer in _action_timers:
		if not timer.one_shot or timer.autostart or timer.process_callback != Timer.TIMER_PROCESS_PHYSICS \
			or timer.process_mode != Node.PROCESS_MODE_INHERIT or timer.ignore_time_scale:
			detected_error = "动作计时器必须单次触发、禁止自动启动，使用物理更新并继承场景暂停与全局时间倍率。"
			Log.error("%s：%s" % [get_path(), detected_error])
			return detected_error
	if not _is_registered(dying_state) or not _is_registered(dead_state):
		detected_error = "dying_state 和 dead_state 必须绑定直属的死亡状态。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	# 死亡阶段负责本体启动事件，博士根节点负责奖杯与保留计时依赖。
	var dying_error: String = dying_state.get_configuration_error()
	if not dying_error.is_empty():
		return dying_error
	return boss.get_death_configuration_error()


## 区间是否有限且下限不大于上限。
func _has_valid_range(range_value: Vector2) -> bool:
	return is_finite(range_value.x) and is_finite(range_value.y) and range_value.x <= range_value.y
