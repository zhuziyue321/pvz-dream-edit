class_name ZmBossRegistry
extends RefCounted

## 僵王实例的登记与生命周期管理。
##
## 原先这 267 行散落在 zombie_manager.gd 里，与波次刷新、行生成、技能僵尸共用同一个文件。
## 僵王本身是一块自洽的业务（登记 -> 存活查询 -> 死亡回调 -> 存档恢复 -> 奖杯 -> 轮间清场），
## 这里把它连同它的 11 个私有变量一起搬出来，zombie_manager 只保留转发。
##
## 通过 manager 反查宿主的关卡参数与运行状态，不复制宿主状态（硬约束 1-2）。

var manager: ZombieManager

func _init(p_manager: ZombieManager) -> void:
	manager = p_manager

#region 僵王管理
## 本关已登记的僵王弱引用；死亡演出期间保留，离树时按实例 ID 移除。
var _registered_bosses: Dictionary[int, WeakRef] = {}
## 仍计入敌方数量的僵王 ID；死亡和离树共用此集合，保证只扣一次。
var _counted_boss_ids: Dictionary[int, bool] = {}
## 实例对应的注册类型，用于保存存活僵王，不依赖节点名称。
var _boss_types: Dictionary[int, CharacterRegistry.ZombieBossType] = {}
## 自动生成入口是否已经成功出场；卡牌召唤不占用此记录。
var _auto_boss_spawned := false
## 自动生成实例的 ID，仅用于自动入口重复调用时返回原实例。
var _auto_boss_id: int = 0
## 本局累计成功生成数量，自动出场和卡牌召唤均计入，恢复存档不重复增加。
var _boss_spawn_total: int = 0
## 本局累计确认死亡数量；直接移除不计为击杀。
var _boss_dead_total: int = 0
## 额外 Boss 条件实际开始结算后接受最后死亡实例的请求；0 表示没有待结算实例。
var _boss_trophy_pending_id: int = 0
## 本轮奖杯是否已由僵王演出请求过，防止方法轨道重复触发。
var _boss_trophy_created := false
## 轮间读档暂存的数据；选卡完成后才恢复正常出战实例。
var _saved_boss_data: Dictionary = {}
## 自动僵王是否已经尝试过出场（开战时生成一次）。
var _boss_auto_checked := false
#endregion

## 开战时按关卡配置自动生成一次僵王；由 start_game() 调用，卡牌召唤不占用该记录。
func try_auto_spawn_boss() -> ZB000Base:
	if _boss_auto_checked:
		return _get_registered_boss(_auto_boss_id)
	_boss_auto_checked = true
	if not manager.game_para.has_boss() or manager.game_para.boss_spawn_wave != 0:
		return null
	return create_boss()


## 自动入口按关卡配置只生成一次；失败返回 null。
func create_boss() -> ZB000Base:
	if _auto_boss_spawned:
		return _get_registered_boss(_auto_boss_id)
	if not manager.is_game_running() or not manager.game_para.has_boss():
		return null
	if manager.monster_mode != ConstLevelData.E_MonsterMode.Norm and manager.monster_mode != ConstLevelData.E_MonsterMode.Null:
		return null
	var boss: ZB000Base = _create_boss_instance(manager.game_para.boss_type, ZB000Base.FIXED_SPAWN_POSITION)
	if boss != null:
		_auto_boss_spawned = true
		_auto_boss_id = boss.get_instance_id()
	return boss


## 僵王出场坐标由 ZB000Base 硬编码，关卡不再配置出生点。[br]
## [param boss_type] 已注册的僵王类型；正式战斗、有效根节点及注册表允许时返回 true。
func can_summon_boss(boss_type: CharacterRegistry.ZombieBossType) -> bool:
	if not manager.is_game_running() or not is_instance_valid(manager.zombie_boss_root) \
		or not manager.zombie_boss_root.is_inside_tree() or manager.zombie_boss_root.is_queued_for_deletion() \
		or not Global.character_registry.ZombieBossInfo.has(boss_type):
		return false
	var scene: PackedScene = Global.character_registry.get_zombie_boss_info(
		boss_type, CharacterRegistry.ZombieBossInfoAttribute.BossScenes
	) as PackedScene
	return scene != null and scene.can_instantiate()


## [param boss_type] 卡牌引用中的僵王类型；每次成功返回新实例，失败返回 null。
func try_create_boss_from_card(boss_type: CharacterRegistry.ZombieBossType) -> ZB000Base:
	return _create_boss_instance(boss_type, ZB000Base.FIXED_SPAWN_POSITION)


## [param count_as_new] 恢复存档时为 false；[param restored_hp] 为正数时恢复存活血量。
func _create_boss_instance(boss_type: CharacterRegistry.ZombieBossType, spawn_position: Vector2,
	count_as_new: bool = true, restored_hp: int = -1) -> ZB000Base:
	if not can_summon_boss(boss_type) or not spawn_position.is_finite():
		return null
	var scene: PackedScene = Global.character_registry.get_zombie_boss_info(
		boss_type, CharacterRegistry.ZombieBossInfoAttribute.BossScenes
	) as PackedScene
	var instance: Node = scene.instantiate()
	var boss: ZB000Base = instance as ZB000Base
	if boss == null:
		Log.error("ZombieManager：僵王场景根节点必须继承 ZB000Base。")
		instance.free()
		return null
	var boss_hp: HpComponent = boss.get_node_or_null("%HpComponent") as HpComponent
	if boss_hp == null or boss_hp.max_hp <= 0 or boss.is_death:
		Log.error("ZombieManager：僵王必须具有正数初始血量，且不能预设为死亡。")
		boss.free()
		return null
	## 关卡覆盖的血量必须在角色入树之前写入：血量组件 _ready 才按上限初始化当前血量。
	boss.set_boss_hp(manager.game_para.boss_hp)
	boss.character_init_type = Character000Base.E_CharacterInitType.IsNorm
	boss.position = spawn_position
	## 先连接信号并计数，再触发角色 _ready，避免初始化期间发出的通知被遗漏。
	if not register_boss(boss, boss_type, count_as_new):
		boss.free()
		return null
	manager.zombie_boss_root.add_child(boss)
	if restored_hp > 0:
		boss_hp.Hp_loss(boss_hp.max_hp - mini(restored_hp, boss_hp.max_hp),
			BulletRegistry.AttackMode.Norm, false, false, false)
	manager.signal_living_bosses_changed.emit()
	return boss


## 登记僵王实例并接入敌方计数；同一实例重复登记只返回 true。
func register_boss(boss: ZB000Base, boss_type: CharacterRegistry.ZombieBossType, count_as_new: bool = true) -> bool:
	if not is_instance_valid(boss) or boss.is_queued_for_deletion():
		return false
	var instance_id: int = boss.get_instance_id()
	if _registered_bosses.has(instance_id):
		return true
	if not manager.is_game_running() or boss.is_death \
		or boss.character_init_type != Character000Base.E_CharacterInitType.IsNorm \
		or not Global.character_registry.ZombieBossInfo.has(boss_type):
		return false
	if boss.get_parent() != null and boss.get_parent() != manager.zombie_boss_root:
		return false
	_registered_bosses[instance_id] = weakref(boss)
	_counted_boss_ids[instance_id] = true
	_boss_types[instance_id] = boss_type
	if count_as_new:
		_boss_spawn_total += 1
	boss.signal_character_death.connect(_on_boss_dead.bind(instance_id))
	boss.signal_trophy_requested.connect(_on_boss_trophy_requested.bind(instance_id))
	boss.tree_exiting.connect(_on_boss_tree_exiting.bind(instance_id))
	manager.curr_zombie_num += 1
	if boss.is_inside_tree():
		manager.signal_living_bosses_changed.emit()
	return true


## [param instance_id] 发出死亡通知的登记实例；先检查原有清场条件，再检查额外 Boss 条件。
func _on_boss_dead(instance_id: int) -> void:
	var boss: ZB000Base = _get_registered_boss(instance_id)
	if boss == null or not boss.is_death or not _counted_boss_ids.erase(instance_id):
		return
	_boss_dead_total += 1
	manager.curr_zombie_num -= 1
	manager.signal_living_bosses_changed.emit()
	## 同一次死亡也满足普通清场时，保留原清场结算时机，不强制等待 Boss 演出。
	manager._try_finish_wave(boss.global_position)
	if manager.game_para.win_on_boss_death and manager.is_game_running() \
		and _boss_spawn_total > 0 and _boss_dead_total == _boss_spawn_total \
		and _claim_boss_round_end():
		_boss_trophy_pending_id = instance_id
		manager.main_game.main_game_progress = MainGameManager.E_MainGameProgress.GAME_OVER
		manager.check_zombie_end_wave_timer.stop()
		if is_instance_valid(manager.multi_round_end_wave_timer):
			manager.multi_round_end_wave_timer.stop()


## 额外 Boss 胜利条件是否已经接受；每轮最多一次，已经进入结算则不再接受。
func _claim_boss_round_end() -> bool:
	if _boss_trophy_pending_id != 0 or _boss_trophy_created:
		return false
	return not TreePauseManager.curr_pause_factor.get(TreePauseManager.E_PauseFactor.GameOver, false)


## [param global_pos] 死亡动画请求的奖杯生成位置；只完成已接受的 Boss 胜利。
func _on_boss_trophy_requested(global_pos: Vector2, instance_id: int) -> void:
	if not manager.game_para.win_on_boss_death or instance_id != _boss_trophy_pending_id or _boss_trophy_created:
		return
	if not manager.is_inside_tree() or manager.is_queued_for_deletion() or not is_instance_valid(manager.main_game) \
		or manager.main_game.is_queued_for_deletion() or not manager.main_game.is_inside_tree():
		return
	var boss: ZB000Base = _get_registered_boss(instance_id)
	if boss == null or not boss.is_death or boss.is_queued_for_deletion() or not boss.is_inside_tree():
		return
	_boss_trophy_created = true
	_boss_trophy_pending_id = 0
	EventBus.push_event("create_trophy", [global_pos])


## [param instance_id] 即将离树的登记实例；直接移除不计为击杀。
func _on_boss_tree_exiting(instance_id: int) -> void:
	_registered_bosses.erase(instance_id)
	_boss_types.erase(instance_id)
	if _counted_boss_ids.erase(instance_id):
		manager.curr_zombie_num -= 1
		manager.signal_living_bosses_changed.emit()
	if _boss_trophy_pending_id == instance_id:
		_boss_trophy_pending_id = 0


## [param instance_id] 本局实例 ID；返回仍有效的登记僵王。
func _get_registered_boss(instance_id: int) -> ZB000Base:
	if not _registered_bosses.has(instance_id):
		return null
	var boss = _registered_bosses[instance_id].get_ref()
	return boss as ZB000Base if is_instance_valid(boss) else null


## 返回按登记顺序排列的存活实例快照。
func get_living_bosses() -> Array[ZB000Base]:
	var bosses: Array[ZB000Base] = []
	for instance_id: int in _registered_bosses:
		var boss: ZB000Base = _get_registered_boss(instance_id)
		if _counted_boss_ids.has(instance_id) and boss != null and not boss.is_death \
			and boss.is_inside_tree() and not boss.is_queued_for_deletion():
			bosses.append(boss)
	return bosses


## 返回存活僵王及累计结算数据，供关卡存档保存。
func get_save_game_data_bosses() -> Dictionary:
	if not _saved_boss_data.is_empty():
		return _saved_boss_data.duplicate(true)
	var living_bosses: Array[Dictionary] = []
	for boss: ZB000Base in get_living_bosses():
		var instance_id: int = boss.get_instance_id()
		living_bosses.append({"boss_type": _boss_types[instance_id], "hp": boss.hp_component.curr_hp,
			"position": boss.position, "is_auto": instance_id == _auto_boss_id})
	return {"living_bosses": living_bosses, "spawn_total": _boss_spawn_total,
		"dead_total": _boss_dead_total, "auto_spawned": _auto_boss_spawned}


## [param data] 可选僵王存档数据；仅暂存，正式战斗开始时再恢复。
func load_game_data_bosses(data: Dictionary) -> void:
	_saved_boss_data = data.duplicate(true)


## 正式战斗开始后一次性恢复存活实例及累计记录，不重复计数。
func restore_saved_bosses() -> void:
	if _saved_boss_data.is_empty() or not manager.is_game_running():
		return
	var data: Dictionary = _saved_boss_data
	_saved_boss_data = {}
	_boss_spawn_total = maxi(int(data.get("spawn_total", 0)), 0)
	_boss_dead_total = clampi(int(data.get("dead_total", 0)), 0, _boss_spawn_total)
	_auto_boss_spawned = bool(data.get("auto_spawned", false))
	for snapshot: Dictionary in data.get("living_bosses", []):
		var boss_type: CharacterRegistry.ZombieBossType = snapshot.get("boss_type", CharacterRegistry.ZombieBossType.Null)
		var hp: int = snapshot.get("hp", 0)
		if hp <= 0:
			continue
		# 坐标固定，读档不套用存档里记录的旧位置。
		var boss: ZB000Base = _create_boss_instance(boss_type, ZB000Base.FIXED_SPAWN_POSITION, false, hp)
		if boss == null:
			Log.error("ZombieManager：无法恢复存档中的僵王：%s。" % boss_type)
			continue
		if snapshot.get("is_auto", false):
			_auto_boss_id = boss.get_instance_id()


## 我是僵尸模式轮间清场时一并移除僵王；清场不产生击杀或奖杯。
## 僵王没了进度条自己会收起来（数据源每帧读 get_living_bosses()）。
func clear_bosses_for_next_round() -> void:
	var bosses: Array[ZB000Base] = []
	for instance_id: int in _registered_bosses:
		var boss: ZB000Base = _get_registered_boss(instance_id)
		if boss != null:
			bosses.append(boss)
	manager.curr_zombie_num -= _counted_boss_ids.size()
	_counted_boss_ids.clear()
	_registered_bosses.clear()
	_boss_types.clear()
	_saved_boss_data.clear()
	_auto_boss_spawned = false
	_auto_boss_id = 0
	_boss_spawn_total = 0
	_boss_dead_total = 0
	_boss_trophy_pending_id = 0
	_boss_trophy_created = false
	_boss_auto_checked = false
	for boss: ZB000Base in bosses:
		boss.queue_free()
	manager.signal_living_bosses_changed.emit()


