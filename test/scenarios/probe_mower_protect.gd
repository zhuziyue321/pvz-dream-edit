extends RefCounted
## 探针：丢车保护（小推车触发后本行一段时间内不出怪，原版机制）
##
## 覆盖：
##   1. 默认开启：ZombieChooseRowSystem.mower_protect_time > 0
##   2. 真实链路：小推车 _start_mower() 经 EventBus 把本行置为保护中，其它行不受影响
##   3. 保护生效：保护期间 select_spawn_row 选不到该行，其余行照常出怪
##   4. 计时结束：保护时间走完后该行恢复出怪（_process 递减剩余时间）
##   5. 兜底：所有行都在保护中时选行仍返回合法行号（保护不能让整波停刷）
##   6. 越界：行号越界的触发请求被安全忽略
##
## 机器可读汇总：最后一行 [MOWER] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"
const ProbeUtil := preload("res://test/scenarios/probe_util.gd")

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 丢车保护 ==========")
	if not await _boot(a):
		_finish(a)
		return

	var choose := _choose_row_system()
	if choose == null:
		_finish(a)
		return

	_check(a, "默认开启丢车保护（保护时长 > 0）", choose.mower_protect_time > 0.0,
		"mower_protect_time=%s" % str(choose.mower_protect_time))

	var row_num: int = Global.main_game.zombie_manager.all_zombie_rows.size()
	_check(a, "关卡有多行僵尸行（可验证\"只保护本行\"）", row_num > 1, "row_num=%d" % row_num)
	_check(a, "开局没有任何行处于保护中", not _any_protected(choose, row_num))
	if row_num <= 1:
		_finish(a)
		return

	var lane: int = await _trigger_mower(a, choose)
	if lane < 0:
		_finish(a)
		return

	_check(a, "触发小推车后本行进入保护（行%d）" % lane, choose.is_lane_in_mower_protect(lane))
	_check(a, "其它行不受影响", not _any_protected_but(choose, row_num, lane))

	_check_protect_block_row(a, choose, row_num, lane)
	await _check_protect_expire(a, choose, lane)
	_check_all_row_protect_fallback(a, choose, row_num)
	_check_out_of_range(a, choose, row_num)
	_finish(a)


#region 关卡与推车准备

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
	## 替玩家点「开始游戏」：提前 main_game_start() 会让「初始化小推车」永远跑不到
	await ProbeUtil.click_start(a)
	await ProbeUtil.wait_lawn_mowers(a, 20.0)
	return Global.main_game.main_game_progress != null

func _choose_row_system() -> ZombieChooseRowSystem:
	if Global.main_game == null or Global.main_game.zombie_manager == null:
		return null
	if Global.main_game.zombie_manager.zombie_wave_manager == null:
		return null
	var create_mgr = Global.main_game.zombie_manager.zombie_wave_manager.zombie_wave_create_manager
	if create_mgr == null:
		return null
	var choose: ZombieChooseRowSystem = create_mgr.zombie_choose_row_system
	return choose if is_instance_valid(choose) else null


## 真实触发一辆小推车（走 _start_mower → EventBus → 选行系统），返回其所在行，失败返回 -1
func _trigger_mower(a, choose) -> int:
	if choose == null:
		_check(a, "选行系统可用", false, "zombie_choose_row_system 为空")
		return -1
	var gim = Global.main_game.game_item_manager.gim_lawn_mover
	if gim == null:
		_check(a, "小推车管理器可用", false, "gim_lawn_mover 为空")
		return -1
	for i in range(gim.all_lawn_movers.size()):
		var mower: LawnMover = gim.all_lawn_movers[i]
		if mower == null or not is_instance_valid(mower) or mower.is_moving:
			continue
		mower._start_mower()
		await a.frames(3)
		_check(a, "小推车已启动（行%d）" % i, mower.is_moving == true, "is_moving=%s" % str(mower.is_moving))
		return i
	_check(a, "找到一辆可用的小推车", false, "all_lawn_movers 里没有未启动的推车")
	return -1

#endregion


#region 断言

## 保护期间：本行选不到，其它行照常
func _check_protect_block_row(a, choose: ZombieChooseRowSystem, row_num: int, lane: int) -> void:
	var weights := _all_rows_weight(row_num)
	var hit_protected := false
	var picked_rows: Dictionary = {}
	for i in range(60):
		var row: int = choose.select_spawn_row(CharacterRegistry.ZombieRowType.Land, weights)
		if row == lane:
			hit_protected = true
		picked_rows[row] = true
	_check(a, "保护期间选行不会选到本行（60 次）", not hit_protected, "命中保护行=%s" % str(hit_protected))
	_check(a, "保护期间其它行照常出怪（选中 %d / %d 行）" % [picked_rows.size(), row_num - 1],
		picked_rows.size() == row_num - 1, "选中行=%s" % str(picked_rows.keys()))


## 计时走完后本行恢复
func _check_protect_expire(a, choose: ZombieChooseRowSystem, lane: int) -> void:
	var ori_time: float = choose.mower_protect_time
	choose.mower_protect_time = 0.5
	EventBus.push_event("lawn_mover_triggered", [lane])
	_check(a, "再次触发后本行重新进入保护", choose.is_lane_in_mower_protect(lane))
	await a.wait(1.2)
	_check(a, "保护时间走完后本行恢复出怪", not choose.is_lane_in_mower_protect(lane),
		"剩余=%s" % str(choose.lane_protect_time_left[lane] if lane < choose.lane_protect_time_left.size() else -1))
	choose.mower_protect_time = ori_time


## 所有行都在保护中：选行仍要返回合法行号（保护只减少出怪，不能停刷）
func _check_all_row_protect_fallback(a, choose: ZombieChooseRowSystem, row_num: int) -> void:
	for i in range(row_num):
		EventBus.push_event("lawn_mover_triggered", [i])
	var row: int = choose.select_spawn_row(CharacterRegistry.ZombieRowType.Land, _all_rows_weight(row_num))
	_check(a, "所有行都保护时仍返回合法行号", row >= 0 and row < row_num, "row=%d" % row)


## 越界行号被安全忽略
func _check_out_of_range(a, choose: ZombieChooseRowSystem, row_num: int) -> void:
	choose.on_lawn_mover_triggered(-1)
	choose.on_lawn_mover_triggered(row_num + 5)
	var ok := true
	for i in range(choose.lane_protect_time_left.size()):
		if choose.lane_protect_time_left[i] < 0.0:
			ok = false
	_check(a, "越界行号的保护请求被忽略", ok)

#endregion


#region 工具

## 让每一行都可出怪的临时基础权重（1-1 只有一行铺了草皮，权重表按行类型算会只剩一行）
func _all_rows_weight(row_num: int) -> Array[float]:
	var weights: Array[float] = []
	for i in range(row_num):
		weights.append(1.0)
	return weights


func _any_protected(choose: ZombieChooseRowSystem, row_num: int) -> bool:
	for i in range(row_num):
		if choose.is_lane_in_mower_protect(i):
			return true
	return false


func _any_protected_but(choose: ZombieChooseRowSystem, row_num: int, lane: int) -> bool:
	for i in range(row_num):
		if i != lane and choose.is_lane_in_mower_protect(i):
			return true
	return false

#endregion


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[MOWER] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
