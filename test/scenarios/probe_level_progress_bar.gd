extends RefCounted
## 探针：关卡进度条控制器（LevelProgressBarController + 数据源）
##
## 覆盖两条口径：
##   1. 冒险 1-3（普通出怪关）：默认装「战斗进度」数据源 ——
##      开战前不显示；开战后显示、进度随时间上涨；旗帜数 = max_wave / 10。
##   2. 冒险 5-10（僵王关）：自动换成「僵王血量」数据源 ——
##      僵王出场后显示且进度 = 血量百分比；血量打到一半，进度跟着掉到 ~50；没有旗帜。
##
## 机器可读汇总：最后一行 [LEVELPROGRESSBAR] result=PASS|FAIL failed=<n>

const LEVEL_01_03 := "res://src/levels/mode_adventure/adventure_01_03.gd"
const LEVEL_05_10 := "res://src/levels/mode_adventure/adventure_05_10.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 关卡进度条控制器 ==========")
	await _check_battle_progress(a)
	await _check_zomboss_hp_progress(a)
	_finish(a)


#region 1. 默认口径：战斗进度
func _check_battle_progress(a) -> void:
	a.log("")
	a.log("-- 冒险 1-3：默认口径应为战斗进度 --")
	var mg = await _boot(a, LEVEL_01_03, MainSceneRegistry.MainScenes.MainGameFront)
	if mg == null:
		return

	var ctrl: LevelProgressBarController = mg.level_progress_controller
	_check(a, "取到进度条控制器", ctrl != null, "mg.level_progress_controller 为空")
	if ctrl == null:
		return
	_check(a, "默认装的是战斗进度数据源", ctrl.provider is LevelProgressBattleProvider,
		"实际 = " + str(ctrl.provider))
	var bar: FlagProgressBar = ctrl.progress_bar
	_check(a, "取到进度条节点", bar != null, "progress_bar 为空")
	if bar == null:
		return

	## 开战前：第一波没起就不该显示
	var is_hidden_before_battle := false
	for _i in 40:
		if mg.zombie_manager.is_battle_started():
			break
		is_hidden_before_battle = not bar.visible
		await a.wait(0.5)
	_check(a, "开战前进度条不显示", is_hidden_before_battle, "开战前 visible=true")

	## 等第一波（关卡流程跑到开战才起波）
	for _i in 60:
		if mg.zombie_manager.is_battle_started():
			break
		await a.wait(0.5)
	_check(a, "第一波已经开打", mg.zombie_manager.is_battle_started(), "30 秒没等到第一波")
	if not mg.zombie_manager.is_battle_started():
		return
	await a.wait(1.0)

	_check(a, "开战后进度条显示", bar.visible, "visible=false")
	var flag_num: int = mg.game_para.max_wave / 10
	_check(a, "旗帜数 = max_wave/10 = %d" % flag_num, bar.flag_arr.size() == flag_num,
		"实际 = " + str(bar.flag_arr.size()))

	var first := bar.real_value
	await a.wait(6.0)
	var second := bar.real_value
	a.log("  进度 %s -> %s（real_value）" % [str(first), str(second)])
	_check(a, "战斗进度随时间上涨", second > first, "%s 不涨" % str(second))
#endregion


#region 2. 僵王关口径：僵王血量百分比
func _check_zomboss_hp_progress(a) -> void:
	a.log("")
	a.log("-- 冒险 5-10：僵王关应为僵王血量百分比 --")
	var mg = await _boot(a, LEVEL_05_10, MainSceneRegistry.MainScenes.MainGameRoof)
	if mg == null:
		return

	var ctrl: LevelProgressBarController = mg.level_progress_controller
	_check(a, "取到进度条控制器", ctrl != null, "mg.level_progress_controller 为空")
	if ctrl == null:
		return
	_check(a, "僵王关自动装僵王血量数据源", ctrl.provider is ZombossProgressProvider,
		"实际 = " + str(ctrl.provider))
	var bar: FlagProgressBar = ctrl.progress_bar
	if bar == null:
		return

	## 等博士出场（boss_spawn_wave = 0，开战即自动出场）
	var boss: ZB000Base = null
	for _i in 40:
		var bosses: Array = mg.zombie_manager.get_living_bosses()
		if not bosses.is_empty():
			boss = bosses[0]
			break
		await a.wait(0.5)
	_check(a, "博士已出场", boss != null, "20 秒内没有僵王实例")
	if boss == null:
		return
	await a.wait(1.0)

	_check(a, "僵王出场后进度条显示", bar.visible, "visible=false")
	_check(a, "僵王战不画波次旗帜", bar.flag_arr.is_empty(), "还有 %d 面旗" % bar.flag_arr.size())
	var full := bar.real_value
	a.log("  满血进度 = " + str(full))
	_check(a, "满血 = 100%", absf(full - 100.0) < 1.0, "实际 = " + str(full))

	## 血量打到一半，进度应跟着掉到 ~50（real_value 是数据源当场的值，追赶动画另算）
	var hp = boss.get("hp_component")
	_check(a, "取到僵王血量组件", hp != null, "hp_component 为空")
	if hp == null:
		return
	hp.curr_hp = int(hp.max_hp * 0.5)
	await a.wait(0.5)
	var half := bar.real_value
	a.log("  半血进度 = " + str(half))
	_check(a, "半血 = 50%", absf(half - 50.0) < 2.0, "实际 = " + str(half))

	## 僵王没了进度条自己收起来
	boss.queue_free()
	await a.wait(1.0)
	_check(a, "僵王离场后进度条隐藏", not bar.visible, "visible=true")
#endregion


#region 辅助
## 进指定关卡（跳过选卡），返回主游戏；失败返回 null
func _boot(a, level_path: String, main_scene):
	var para: Resource = (load(level_path) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败: " + level_path)
		return null
	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[main_scene])
	await a.wait(3.0)
	var mg := Global.main_game
	_check(a, "已进入主游戏（%s）" % level_path.get_file(), mg != null, "Global.main_game 为空")
	if mg == null:
		return null
	if mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		mg.main_game_start()
	await a.wait(2.0)
	return Global.main_game
#endregion


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[LEVELPROGRESSBAR] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
