## 博士放置技能：按原版口径每次召唤一只僵尸，先选行再由博士存活时长决定类型。
## 原版参照 `../PvZ-Portable-main/src/Lawn/Zombie.cpp` 的 `BossSpawnAttack()` / `BossSpawnContact()`：
## 类型分段 mZombieAge < 3500 普僵 / < 8000 路障 / < 12500 铁桶，之后从 gBossZombieList 随机
## （最上行不放巨人）；100 tick = 1 秒，秒数见各阈值导出。
extends ZB001DoctorSkillBase
class_name ZB001DoctorSkillSpawn

## 手指下的生成标记，仅在释放时读取全局 X；Y 使用清单目标行的出生点。
@export var spawn_marker: Marker2D
## 存活时长低于该秒数时只放普通僵尸；原版 mZombieAge < 3500 tick。
@export_range(0.0, 600.0, 0.5) var norm_phase_age: float = 35.0
## 存活时长低于该秒数时只放路障僵尸；原版 mZombieAge < 8000 tick。
@export_range(0.0, 600.0, 0.5) var cone_phase_age: float = 80.0
## 存活时长低于该秒数时只放铁桶僵尸；原版 mZombieAge < 12500 tick。
@export_range(0.0, 600.0, 0.5) var pail_phase_age: float = 125.0
## 后期随机池；原版 gBossZombieList 的类型与顺序，最上行在运行期剔除巨人。
@export var late_pool: Array[StringName] = [
	ZombieIds.CONE, ZombieIds.BUCKET, ZombieIds.FOOTBALL, ZombieIds.POLE_VAULTER,
	ZombieIds.JACKBOX, ZombieIds.LADDER, ZombieIds.ZAMBONI, ZombieIds.CATAPULT,
	ZombieIds.POGO, ZombieIds.PAPER, ZombieIds.SCREEN_DOOR, ZombieIds.GARGANTUAR,
]

## 本批清单；原版一次召唤一只，始终只有一个条目。
var spawn_entries: Array[ZB001DoctorSpawnEntry] = []
## 本批已完整播放的放置动作数；动画结束时推进，释放失败也沿用原有次数规则。
var completed_count: int = 0
## 当前动画绑定的放置任务，重复释放由技能基类阻止。
var _current_entry: ZB001DoctorSpawnEntry
## 博士自己的选行实例；首次正式准备时初始化，技能之间保留历史。
@onready var choose_row_system: ZombieChooseRowSystem = get_node_or_null("SpawnChooseRowSystem") as ZombieChooseRowSystem


## 等价原版 BossSpawnAttack：成功锁定本批唯一任务后开始技能。
func begin_skill() -> bool:
	super.begin_skill()
	return _prepare_spawn() > 0


## 为映射支持的动画行准备本批唯一清单，返回计划放置数量（0 或 1）。
## 选行失败或无合法类型时返回 0，不生成半批任务。
func _prepare_spawn() -> int:
	_clear_spawn_data()
	# 当前博士所属的战斗管理器，只读取场地数据和生成合法性。
	var manager: ZombieManager = _get_active_manager()
	if manager == null or not is_instance_valid(choose_row_system):
		return 0
	if not choose_row_system.is_initialized:
		choose_row_system.init_zombie_choose_row_system(manager.all_zombie_rows)
	# 原版先按普僵的行规则选行，再决定本行的类型。
	var lane: int = _pick_spawn_lane(manager)
	if lane < 0:
		return 0
	var zombie_type: StringName = _pick_zombie_type(manager, lane)
	if zombie_type.is_empty():
		return 0
	spawn_entries.append(ZB001DoctorSpawnEntry.new(zombie_type, lane))
	return 1


## 按原版 PickRowForNewZombie 的口径选行：以普僵的陆行规则、等权候选行；
## 交由博士独立选行系统维护行历史。
func _pick_spawn_lane(manager: ZombieManager) -> int:
	# 行权重与地图行数一致；合法行为 1，其余为 0。
	var row_weights: Array[float] = []
	row_weights.resize(manager.all_zombie_rows.size())
	row_weights.fill(0.0)
	# 动画只覆盖场地资源映射的行；其余行不参与选行。
	for row: int in scene_config.spawn_row_actions:
		# 配置行号从 1 开始，转成零起始下标。
		var lane: int = row - 1
		if lane < 0 or lane >= row_weights.size():
			continue
		if manager.can_spawn_skill_zombie(ZombieIds.NORM, lane):
			row_weights[lane] = 1.0
	# 普僵的水陆分类；屋顶与前后院均为陆行。
	var row_type: CharacterRegistry.ZombieRowType = Global.character_registry.get_zombie_info(ZombieIds.NORM, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
	return choose_row_system.select_spawn_row(row_type, row_weights)


## 按博士存活时长三段给固定类型，之后从后期随机池抽取。
## 最上行不放巨人（原版 BossSpawnContact 对 mTargetRow == 0 的特判）；
## 本行不可生成的类型先剔除，池空时放弃本次召唤。
func _pick_zombie_type(manager: ZombieManager, lane: int) -> StringName:
	# 存活时长来自主状态机（原版 mZombieAge）。
	var age: float = _get_battle_age()
	if age < norm_phase_age:
		return ZombieIds.NORM
	if age < cone_phase_age:
		return ZombieIds.CONE
	if age < pail_phase_age:
		return ZombieIds.BUCKET
	# 后期随机池；复制后按行剔除，不改写共享导出配置。
	var pool: Array[StringName] = late_pool.duplicate()
	if lane == 0:
		pool.erase(ZombieIds.GARGANTUAR)
	pool = pool.filter(func(zombie_type: StringName) -> bool: return manager.can_spawn_skill_zombie(zombie_type, lane))
	if pool.is_empty():
		return &""
	return pool.pick_random()


## 返回博士本局存活时长（原版 mZombieAge，秒）；状态机无效时按 0 处理。
func _get_battle_age() -> float:
	var doctor: ZB001Doctor = owner as ZB001Doctor
	if not is_instance_valid(doctor) or not is_instance_valid(doctor.state_machine):
		return 0.0
	return doctor.state_machine.battle_age


## 按完整动画结束次数选择本批任务；不重新随机类型或行。
func prepare_action() -> StringName:
	_current_entry = null
	if completed_count >= spawn_entries.size():
		return _arm_action(&"")
	_current_entry = spawn_entries[completed_count]
	# 动画和部件位置来自同一行资源，允许多行复用动画而不复用实际生成行。
	var action: ZB001DoctorRowAction = scene_config.spawn_row_actions.get(_current_entry.lane + 1)
	if action == null:
		return _arm_action(&"")
	return _arm_position_action(action.animation_name, action.part_position)


## 完整动作结束时推进一次，返回是否还有下一次放置；不在释放关键帧累计。
func complete_action() -> bool:
	# 复位由动画关键帧启动，动作状态退出时补齐端点；这里仅推进批次，不重复写位置。
	completed_count += 1
	return completed_count < spawn_entries.size()


## 当前场地的手臂平移参数；使用共享只读资源，不把 Tween 状态写回配置。
func get_part_motion_config() -> ZB001DoctorPartMotionConfig:
	return scene_config.spawn_part_motion if scene_config != null else null


## 清理本轮任务；选行历史与存活时长分段阈值保留。
func cancel_skill() -> void:
	super.cancel_skill()
	_clear_spawn_data()


## 清理尚未执行的本批任务。
func _clear_spawn_data() -> void:
	spawn_entries.clear()
	completed_count = 0
	_current_entry = null


## 使用当前任务的类型与行创建僵尸，释放时才读取手部 X。
## 关卡结束、博士死亡或类型在本行失效时跳过本项，不临时换行或重新抽取。
func _release_action() -> void:
	# 重新确认释放时的生命周期，避免迟到方法轨道补生僵尸。
	var manager: ZombieManager = _get_active_manager()
	if manager == null or not is_instance_valid(spawn_marker) or not spawn_marker.is_inside_tree() \
		or spawn_marker.is_queued_for_deletion() or _current_entry == null:
		return
	# 类型与行必须和播放中的动画使用同一份准备结果。
	var zombie_type: StringName = _current_entry.zombie_type
	var lane: int = _current_entry.lane
	if not manager.can_spawn_skill_zombie(zombie_type, lane):
		return
	manager.create_skill_zombie(zombie_type, lane, spawn_marker.global_position.x)


## 只读校验博士专属依赖、存活时长分段与后期随机池；错误在检测位置报告。
func get_configuration_error() -> String:
	# 基类先检查共享资源和博士自身的定位节点，错误已在发现处报告。
	var placement_error: String = super.get_configuration_error()
	if not placement_error.is_empty():
		return placement_error
	# 行号、动画与位置统一由场地资源校验；实际地图缺失的行在选行阶段过滤。
	var row_error: String = scene_config.get_row_actions_error(scene_config.spawn_row_actions, str(get_path()))
	if not row_error.is_empty():
		return row_error
	# 当前检测分支的错误文本，在发现问题的位置报告，方便定位场景配置。
	var detected_error: String = ""
	if not is_instance_valid(spawn_marker) or not is_instance_valid(owner) or not owner.is_ancestor_of(spawn_marker):
		detected_error = "SpawnSkill 必须绑定博士自身的 Marker2DSpawnZombie。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	if not is_instance_valid(choose_row_system) or choose_row_system.get_parent() != self:
		detected_error = "SpawnSkill 必须配置独立的 SpawnChooseRowSystem 子节点。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	# 存活时长分段必须严格递增，保证三段互斥且覆盖前期。
	if norm_phase_age <= 0.0 or cone_phase_age <= norm_phase_age or pail_phase_age <= cone_phase_age:
		detected_error = "存活时长分段必须满足 0 < norm_phase_age < cone_phase_age < pail_phase_age。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	if late_pool.is_empty():
		detected_error = "后期随机池必须配置至少一种僵尸类型。"
		Log.error("%s：%s" % [get_path(), detected_error])
		return detected_error
	# 拒绝重复类型，避免同一类型获得额外抽取概率。
	var seen_types: Array[StringName] = []
	for zombie_type: StringName in late_pool:
		if not Global.character_registry.ZombieInfo.has(zombie_type):
			detected_error = "后期随机池的类型必须具有角色注册信息。"
			Log.error("%s：%s" % [get_path(), detected_error])
			return detected_error
		if Global.character_registry.ZombieSpawnPower.get(zombie_type, 0) <= 0:
			detected_error = "后期随机池的每种僵尸必须配置正数战力。"
			Log.error("%s：%s" % [get_path(), detected_error])
			return detected_error
		if seen_types.has(zombie_type):
			detected_error = "后期随机池的僵尸类型不能重复。"
			Log.error("%s：%s" % [get_path(), detected_error])
			return detected_error
		seen_types.append(zombie_type)
	return ""


## 返回本博士所在战斗的管理器；展示实例、死亡实例及离开关卡后均返回 null。
func _get_active_manager() -> ZombieManager:
	# 公共入口先检查博士与关卡的生命周期，本技能只确认自己的管理器。
	var game: MainGameManager = _get_active_game()
	if game == null:
		return null
	# 管理器正在释放或已离树时不再读取场地及生成对象。
	var manager: ZombieManager = game.zombie_manager
	return manager if is_instance_valid(manager) and manager.is_inside_tree() and not manager.is_queued_for_deletion() else null


## 返回行映射中首次出现的动画集合；场地资源统一查询，供状态检查资源和方法关键帧。
func get_action_animations() -> Array[StringName]:
	if scene_config != null:
		return scene_config.get_row_action_animations(scene_config.spawn_row_actions)
	# 未绑定场地资源时仍返回元素类型明确的新空列表，保持状态层的返回约定。
	var empty_animations: Array[StringName] = []
	return empty_animations
