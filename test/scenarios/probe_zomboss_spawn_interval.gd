extends RefCounted
## 探针：僵王血量按关卡配置（5-10 = 40000 / 僵尸博士的复仇 = 60000）+ 放置间隔随血量变化
## 覆盖：逐关进僵王关 → 断言僵王 max_hp / 破损阈值 → 在 5-10 断言满血 6s、低于 50% 变 4s，
##      并打印一次真实「放置间隔」状态里计时器的基础周期（技能选择带随机，只作 INFO）。
## 机器可读汇总：最后一行 [ZOMBOSSHP] result=PASS|FAIL failed=<n>

const LEVELS: Array[Dictionary] = [
	{
		"name": "冒险 5-10",
		"path": "res://src/levels/mode_adventure/adventure_05_10.gd",
		"hp": 40000,
		"stages": [20000, 10000, 0],
	},
	{
		"name": "僵尸博士的复仇",
		"path": "res://src/levels/mode_minigame/minigame_20_zomboss_revenge.gd",
		"hp": 60000,
		"stages": [30000, 15000, 0],
	},
]

const FULL_INTERVAL := 6.0
const LOW_INTERVAL := 4.0
const LOW_RATIO := 0.5

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵王血量 / 放置间隔 ==========")
	for level: Dictionary in LEVELS:
		await _check_level(a, level)
	_finish(a)


## 进一关僵王关，断言僵王的血量与机甲破损阈值。[br]
## [param level] 关卡名、脚本路径、期望血量与期望破损阈值。
func _check_level(a, level: Dictionary) -> void:
	a.log("")
	a.log("---------- " + str(level["name"]) + " ----------")
	var para: Resource = (load(level["path"]) as GDScript).new()
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameRoof]
	)
	await a.wait(3.0)

	var mg := Global.main_game
	_check(a, "已进入主游戏", mg != null, "Global.main_game 为空")
	if mg == null:
		return
	if mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		mg.main_game_start()
	await a.wait(2.0)

	## 等博士出场（boss_spawn_wave = 0，开战即自动出场）
	var boss: Node2D = null
	for _i in 40:
		var bosses := mg.zombie_manager.get_living_bosses()
		if not bosses.is_empty():
			boss = bosses[0]
			break
		await a.wait(0.5)
	_check(a, "博士已出场", boss != null, "20 秒内没有僵王实例")
	if boss == null:
		return

	var hp_component = boss.get("hp_component")
	var stage_component = boss.get_node_or_null("%HpStageChangeComponent")
	var expect_hp: int = int(level["hp"])
	a.log("  max_hp=%d curr_hp=%d 破损阈值=%s"
		% [hp_component.max_hp, hp_component.curr_hp, str(stage_component.boundary_value_hp)])
	_check(a, "僵王 max_hp = %d" % expect_hp, hp_component.max_hp == expect_hp, str(hp_component.max_hp))
	_check(a, "开局满血", hp_component.curr_hp == hp_component.max_hp,
		"curr_hp=%d max_hp=%d" % [hp_component.curr_hp, hp_component.max_hp])
	var expect_stages: Array[int] = []
	expect_stages.assign(level["stages"])
	_check(a, "破损阈值按比例缩放为 %s" % str(expect_stages),
		stage_component.boundary_value_hp == expect_stages, str(stage_component.boundary_value_hp))

	if level["path"] == LEVELS[0]["path"]:
		await _check_spawn_interval(a, boss)


## 只在 5-10 断言放置间隔随血量变化；血量改回满血后再观察一次真实间隔计时器。
func _check_spawn_interval(a, boss: Node2D) -> void:
	var sm = boss.get("state_machine")
	var spawn_state = sm.get_node_or_null("Spawn") if sm != null else null
	var timer = sm.get_node_or_null("Spawn/StateMachine/Interval/SpawnIntervalTimer") if sm != null else null
	_check(a, "取到 Spawn 技能状态", spawn_state != null, "StateMachine/Spawn 缺失")
	_check(a, "取到放置间隔计时器", timer != null, "SpawnIntervalTimer 缺失")
	if spawn_state == null:
		return

	var hp_component = boss.get("hp_component")
	var max_hp: int = hp_component.max_hp

	a.log("  满血（100%）-> " + str(spawn_state.get_spawn_interval_duration()))
	_check(a, "满血放置间隔为 6s",
		is_equal_approx(spawn_state.get_spawn_interval_duration(), FULL_INTERVAL),
		str(spawn_state.get_spawn_interval_duration()))

	## 50% 边界：不低于阈值仍走常态
	hp_component.curr_hp = int(roundi(max_hp * LOW_RATIO))
	a.log("  阈值边界（%d/%d）-> %s" % [hp_component.curr_hp, max_hp, str(spawn_state.get_spawn_interval_duration())])
	_check(a, "剩余 50% 时仍为 6s",
		is_equal_approx(spawn_state.get_spawn_interval_duration(), FULL_INTERVAL),
		str(spawn_state.get_spawn_interval_duration()))

	## 刚跌破阈值
	hp_component.curr_hp = int(roundi(max_hp * LOW_RATIO)) - 1
	a.log("  跌破阈值（%d/%d）-> %s" % [hp_component.curr_hp, max_hp, str(spawn_state.get_spawn_interval_duration())])
	_check(a, "低于 50% 后为 4s",
		is_equal_approx(spawn_state.get_spawn_interval_duration(), LOW_INTERVAL),
		str(spawn_state.get_spawn_interval_duration()))

	## 深残血
	hp_component.curr_hp = maxi(1, int(roundi(max_hp * 0.40)))
	a.log("  残血（%d/%d）-> %s" % [hp_component.curr_hp, max_hp, str(spawn_state.get_spawn_interval_duration())])
	_check(a, "残血放置间隔为 4s",
		is_equal_approx(spawn_state.get_spawn_interval_duration(), LOW_INTERVAL),
		str(spawn_state.get_spawn_interval_duration()))
	_check(a, "改血量没有把博士打死", not boss.get("is_death"), "博士已死亡，请调高探针的测试血量")

	## 恢复满血后观察一次真实放置间隔（技能选择带随机，只打印不断言）
	hp_component.curr_hp = max_hp
	var spawn_sm = spawn_state.get("child_state_machine")
	var observed := false
	var was_in_interval := true
	for _i in 200:
		var in_interval: bool = sm.current_state == spawn_state \
			and spawn_sm != null and spawn_sm.current_state != null \
			and spawn_sm.current_state.name == "Interval"
		if in_interval and not was_in_interval:
			a.log("  [INFO] 进入放置间隔，计时器 base_wait_time=%s（speed_scale=%s）"
				% [str(timer.base_wait_time), str(timer.speed_scale)])
			observed = true
			break
		was_in_interval = in_interval
		await a.wait(0.25)
	if not observed:
		a.log("  [INFO] 50 秒内没等到放置间隔状态（技能随机，不算失败）")


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBOSSHP] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
