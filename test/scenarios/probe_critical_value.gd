extends RefCounted
## 探针 PROBE9：临界值组件（CriticalValueComponent）回归
##
## 覆盖：
##   1. 僵尸场景挂载：普僵身上有 CriticalValueComponent，宿主转发属性 is_below_critical_value 可用
##   2. 默认临界值 = 角色自身的死亡临界值（DeathBoundary）：等于 hp_component.death_hp（原版"掉头"那一下）
##   3. 判定口径：临界值本身算"低于"（<=），临界值 +1 不算
##   4. 小推车规则：血量在临界值以下的僵尸、已死亡的僵尸都不触发小推车（原版），健康僵尸照常触发
##   5. 自定义临界值（Ratio 0.5）+ 掉血：进入事件发一次、3.2 秒至少掉 2 点血、离开临界值后状态复位
##   6. 死亡禁用：血量清零后组件被宿主按 E_IsEnableFactor.Death 禁用（is_enabling = false）
##
## 机器可读汇总：最后一行 [CRIT] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"
const ProbeUtil := preload("res://test/scenarios/probe_util.gd")

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE9 临界值组件 ==========")
	if not await _boot(a):
		_finish(a)
		return

	## 地图是按行配推车的（1-1 的 map_front_1row 只有最中间那一行有），
	## 推车断言用的僵尸要落在有车的那一行
	var z: Zombie000Base = await _new_norm_zombie(a, _mower_lane())
	if z == null:
		_finish(a)
		return

	var comp: CriticalValueComponent = z.get_node_or_null(^"CriticalValueComponent")
	_check(a, "僵尸挂了临界值组件", comp != null, str(comp) if comp != null else "null")
	if comp == null:
		_finish(a)
		return

	_check_death_boundary(a, z, comp)
	_check_mower_family(a)
	_switch_to_ratio(a, z, comp)
	await _check_below(a, z, comp)
	await _check_drain(a, z, comp)
	await _check_leave(a, z, comp)
	await _check_mower_blocked(a)
	await _check_mower_healthy(a, z)
	_finish(a)


#region 关卡与僵尸准备

func _boot(a) -> bool:
	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败: " + LEVEL)
		return false
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(2.0)
	if Global.main_game == null:
		a.log("!! Global.main_game 为空")
		return false
	## 替玩家点「开始游戏」：小推车是在「准备-安放-植物」之前登场的，
	## 提前开战会让流程停在选卡那一步，推车永远不出现（断言会白失败）
	await ProbeUtil.click_start(a)
	await ProbeUtil.wait_lawn_mowers(a, 20.0)
	return Global.main_game.main_game_progress != null

func _new_norm_zombie(a, lane: int) -> Zombie000Base:
	var mgr := Global.main_game.zombie_manager
	if mgr == null or mgr.zombie_wave_manager == null:
		_check(a, "僵尸管理器可用", false, "zombie_wave_manager 为空")
		return null
	var z: Zombie000Base = mgr.zombie_wave_manager.zombie_wave_create_manager.wave_create_zombie(
		CharacterRegistry.ZombieType.Z001Norm, lane, 0
	)
	await a.wait(0.5)
	_check(a, "普僵创建成功（行%d）" % lane, z != null and is_instance_valid(z),
		"wave_create_zombie 返回空" if z == null else "")
	return z


func _mower_of(lane: int) -> LawnMover:
	var gim = Global.main_game.game_item_manager.gim_lawn_mover
	if gim == null or lane >= gim.all_lawn_movers.size():
		return null
	var mower: LawnMover = gim.all_lawn_movers[lane]
	return mower if is_instance_valid(mower) else null


## 第一行真的配了推车的行号：没铺草皮的行本来就没有推车（见地图数据 have_lawn_mover）
func _mower_lane() -> int:
	var gim = Global.main_game.game_item_manager.gim_lawn_mover
	if gim == null:
		return 0
	for lane in range(gim.all_lawn_movers.size()):
		if is_instance_valid(gim.all_lawn_movers[lane]):
			return lane
	return 0

#endregion


#region 断言

## 默认配置：临界值跟随角色自身的死亡临界值（原版"掉头"那一下）
func _check_death_boundary(a, z: Zombie000Base, comp: CriticalValueComponent) -> void:
	var death_hp: int = z.hp_component.death_hp
	_check(a, "默认取值方式是 DeathBoundary", comp.critical_value_type == CriticalValueComponent.E_CriticalValueType.DeathBoundary,
		"type=%d" % comp.critical_value_type)
	_check(a, "临界值 = hp_component.death_hp", comp.get_critical_value() == death_hp,
		"临界值=%d death_hp=%d" % [comp.get_critical_value(), death_hp])
	_check(a, "僵尸的死亡临界值是本体满血的约 1/3（原版掉头）",
		death_hp > 0 and death_hp < z.hp_component.max_hp,
		"max_hp=%d death_hp=%d" % [z.hp_component.max_hp, death_hp])
	_check(a, "满血时不在临界值以下", not comp.is_below_critical(),
		"curr_hp=%d 临界值=%d" % [z.hp_component.curr_hp, comp.get_critical_value()])
	_check(a, "宿主转发属性可用（满血为 false）", z.is_below_critical_value == false)
	## 判定口径：<= 临界值算进入（原版/血量阶段变化组件一致），临界值 +1 不算
	_check(a, "判定含等号：hp = 临界值 -> true", comp.is_hp_below_critical(death_hp) == true)
	_check(a, "判定上界：hp = 临界值 + 1 -> false", comp.is_hp_below_critical(death_hp + 1) == false)


## 三种小推车（小推车 / 泳池清洁器 / 屋顶清洁器）必须共用 LawnMover 的触发过滤：
## 子类各自复制一份的话，"临界值以下不触发"就会在泳池与屋顶漏掉（原版三种清洁器行为一致）
func _check_mower_family(a) -> void:
	var base_path := "res://src/items/lawn_mower/lawn_mower.gd"
	var base_text := FileAccess.get_file_as_string(base_path)
	_check(a, "基类 LawnMover 实现了启动触发过滤", base_text.contains("func start_trigger_filter"))
	_check(a, "触发过滤里按临界值拦截", base_text.contains("is_below_critical_value"))
	_check(a, "触发过滤里拦截已死亡的僵尸", base_text.contains("zombie.is_death"))
	for sub_path: String in [
		"res://src/items/lawn_mower/pool_cleaner.gd",
		"res://src/items/lawn_mower/roof_cleaner.gd",
	]:
		var sub_text := FileAccess.get_file_as_string(sub_path)
		_check(a, "%s 未重写触发过滤（沿用基类）" % sub_path.get_file(),
			sub_text != "" and not sub_text.contains("func start_trigger_filter"),
			"len=%d" % sub_text.length())


## 切到自定义临界值（Ratio 0.5），验证"高于死亡血量才能生效"的自定义路径
func _switch_to_ratio(a, z: Zombie000Base, comp: CriticalValueComponent) -> void:
	comp.critical_value_type = CriticalValueComponent.E_CriticalValueType.Ratio
	comp.critical_value_ratio = 0.5
	var expect := roundi(z.hp_component.max_hp * 0.5)
	_check(a, "自定义临界值 = roundi(max_hp * ratio)", comp.get_critical_value() == expect,
		"临界值=%d 期望=%d" % [comp.get_critical_value(), expect])
	_check(a, "自定义临界值高于死亡血量", comp.get_critical_value() > z.hp_component.death_hp,
		"临界值=%d death_hp=%d" % [comp.get_critical_value(), z.hp_component.death_hp])


## 掉到临界值以下：状态与事件
func _check_below(a, z: Zombie000Base, comp: CriticalValueComponent) -> void:
	var below_count := [0]
	var leave_count := [0]
	comp.signal_below_critical.connect(func(_hp: int, _cv: int) -> void: below_count[0] += 1)
	comp.signal_leave_critical.connect(func(_hp: int) -> void: leave_count[0] += 1)

	## 掉血只打到「死亡血量 < 血量 <= 临界值」的中间位置：
	## 一次性跨过太多会直接把僵尸打死（本体 1/3 就是死亡血量），那样测的是死亡流程而不是临界值流程。
	## 防具为 0，Real 直接进本体。
	var critical := comp.get_critical_value()
	var death_hp: int = z.hp_component.death_hp
	var target_hp: int = death_hp + maxi((critical - death_hp) / 2, 1)
	z.hp_component.Hp_loss(z.hp_component.max_hp - target_hp, BulletRegistry.AttackMode.Real, true, false)
	await a.wait(0.3)

	_check(a, "掉血后僵尸仍存活（停在死亡血量之上）", is_instance_valid(z) and not z.is_death,
		"curr_hp=%d 死亡血量=%d" % [z.hp_component.curr_hp, death_hp])
	_check(a, "掉血后 is_below_critical() = true", comp.is_below_critical(),
		"curr_hp=%d 临界值=%d" % [z.hp_component.curr_hp, comp.get_critical_value()])
	_check(a, "组件状态 is_in_critical_value = true", comp.is_in_critical_value == true)
	_check(a, "宿主转发属性 is_below_critical_value = true", z.is_below_critical_value == true)
	## 状态由 hp_component.signal_hp_loss 同步，掉血那一帧就该发出去（不依赖物理帧轮询）
	_check(a, "进入临界值事件触发一次", below_count[0] == 1, "below=%d" % below_count[0])
	await a.wait(0.3)
	_check(a, "持续低于临界值时不重复发事件", below_count[0] == 1 and leave_count[0] == 0,
		"below=%d leave=%d" % [below_count[0], leave_count[0]])


## 自动掉血：等 3.2 秒，至少掉 2 点
func _check_drain(a, z: Zombie000Base, comp: CriticalValueComponent) -> void:
	var drain_count := [0]
	comp.signal_drain_hp.connect(func(_hp: int, _loss: int) -> void: drain_count[0] += 1)
	var hp_before: int = z.hp_component.curr_hp
	await a.wait(3.2)
	if not is_instance_valid(z):
		_check(a, "掉血期间僵尸存活", false, "僵尸被提前释放（掉血把本体打到死亡血量以下？）")
		return
	var hp_after: int = z.hp_component.curr_hp
	_check(a, "低于临界值时自动掉血（3.2 秒至少掉 2）", hp_before - hp_after >= 2,
		"before=%d after=%d 掉血事件=%d" % [hp_before, hp_after, drain_count[0]])
	_check(a, "掉血事件 signal_drain_hp 已触发", drain_count[0] >= 2, "drain=%d" % drain_count[0])
	_check(a, "掉血走的是血量组件（本体血量同步下降）", hp_after < hp_before,
		"血条值=%d" % z.hp_component.curr_hp)


## 血量回到临界值之上：离开事件 + 状态复位
func _check_leave(a, z: Zombie000Base, comp: CriticalValueComponent) -> void:
	if not is_instance_valid(z):
		_check(a, "回到临界值之上", false, "僵尸已被释放")
		return
	var leave_count := [0]
	comp.signal_leave_critical.connect(func(_hp: int) -> void: leave_count[0] += 1)
	z.hp_component.curr_hp = z.hp_component.max_hp
	await a.wait(0.3)
	_check(a, "回到临界值之上：组件状态复位", comp.is_in_critical_value == false)
	_check(a, "回到临界值之上：离开事件触发一次", leave_count[0] == 1, "leave=%d" % leave_count[0])
	_check(a, "回到临界值之上：宿主转发属性为 false", z.is_below_critical_value == false)


## 小推车规则（正例）：健康的僵尸照常触发小推车
## 注意：本函数会让行车不再可用（is_moving = true），必须放在所有"不触发"的断言之后
func _check_mower_healthy(a, z: Zombie000Base) -> void:
	var lane := z.lane
	var mower := _mower_of(lane)
	_check(a, "行%d小推车存在" % lane, mower != null, "null" if mower == null else str(mower.get_path()))
	if mower == null or not is_instance_valid(z):
		return
	_check(a, "触发前小推车未启动", mower.is_moving == false)
	mower.start_trigger_filter(z)
	await a.frames(3)
	_check(a, "健康僵尸（未到临界值）照常触发小推车", mower.is_moving == true,
		"is_moving=%s" % str(mower.is_moving))


## 小推车规则（反例）：临界值以下 / 已死亡的僵尸都不触发小推车
func _check_mower_blocked(a) -> void:
	## 反例一：本体血量在临界值以下（但仍存活）
	var z: Zombie000Base = await _new_norm_zombie(a, _mower_lane())
	if z == null:
		return
	var comp: CriticalValueComponent = z.get_node_or_null(^"CriticalValueComponent")
	if comp == null:
		_check(a, "推车行僵尸挂了临界值组件", false, "null")
		return
	comp.critical_value_type = CriticalValueComponent.E_CriticalValueType.Ratio
	comp.critical_value_ratio = 0.5
	var critical := comp.get_critical_value()
	var death_hp: int = z.hp_component.death_hp
	var target_hp: int = death_hp + maxi((critical - death_hp) / 2, 1)
	z.hp_component.Hp_loss(z.hp_component.max_hp - target_hp, BulletRegistry.AttackMode.Real, true, false)
	await a.wait(0.3)
	var mower := _mower_of(z.lane)
	_check(a, "行%d小推车存在" % z.lane, mower != null, "null" if mower == null else str(mower.get_path()))
	if mower == null:
		return
	_check(a, "推车行僵尸血量已在临界值以下但存活",
		is_instance_valid(z) and not z.is_death and z.is_below_critical_value,
		"curr_hp=%d 临界值=%d is_death=%s" % [z.hp_component.curr_hp, critical, str(z.is_death)])
	mower.start_trigger_filter(z)
	await a.frames(3)
	_check(a, "临界值以下的僵尸不触发小推车", mower.is_moving == false,
		"is_moving=%s" % str(mower.is_moving))

	## 反例二：同一只僵尸死亡（掉头）之后仍然不触发
	z.hp_component.Hp_loss(z.hp_component.get_all_hp(), BulletRegistry.AttackMode.Norm, true, false)
	await a.wait(0.3)
	_check(a, "僵尸已死亡", z.is_death == true, "is_death=%s" % str(z.is_death))
	_check(a, "死亡后组件被禁用", comp.is_enabling == false, "is_enabling=%s" % str(comp.is_enabling))
	_check(a, "死亡后组件不再参与判定（物理帧已停）", comp.is_physics_processing() == false,
		"is_physics_processing=%s" % str(comp.is_physics_processing()))
	mower.start_trigger_filter(z)
	await a.frames(3)
	_check(a, "已死亡的僵尸不触发小推车", mower.is_moving == false,
		"is_moving=%s" % str(mower.is_moving))


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[CRIT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()

#endregion
