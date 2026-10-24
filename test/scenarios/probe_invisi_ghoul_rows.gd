extends RefCounted
## 探针：迷你游戏第 6 关「隐形战争」—— 开局几波最下行不出怪
##
## 原版 `Board.cpp`：
##   `if (mGameMode == GAMEMODE_CHALLENGE_INVISIGHOUL && mCurrentWave <= 3 && aRow == 5) 权重 = 0`
## 本作走通用能力：关卡脚本 `before_wave_spawn()` → `set_banned_spawn_rows()` → 选行系统权重归零。
##
## 断言：
##   ① 进关、第一波开起来后，最下行被禁
##   ② 这一波实际刷出来的僵尸没有一只落在最下行
##   ③ 钩子边界：波 3 仍禁（原版 `<= 3`），波 4 解除
##
## 机器可读汇总：最后一行 [INVISI_ROWS] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_minigame/minigame_06_invisi_ghoul.gd"
const WAVE_TIMEOUT := 150.0
const SAMPLE_SECONDS := 6.0

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 隐形战争：开局最下行不出怪 ==========")

	var para = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)

	var mg = GameContext.curr_main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "GameContext.curr_main_game 为空")
		_finish(a)
		return

	if not await _wait_main_game(a, mg):
		_finish(a)
		return

	var wm = mg.zombie_manager.zombie_wave_manager
	var cm = wm.zombie_wave_create_manager
	var rows = cm.zombie_choose_row_system
	var last_row: int = cm.get_row_num() - 1
	_check(a, "关卡有 6 行（最下行下标 5）", last_row == 5, "last_row=" + str(last_row))

	var waited := 0.0
	while waited < WAVE_TIMEOUT and wm.curr_wave < 0:
		await a.wait(0.5)
		waited += 0.5
	_check(a, "第一波已开起来", wm.curr_wave >= 0, "curr_wave=" + str(wm.curr_wave))
	if wm.curr_wave < 0:
		_finish(a)
		return

	_check(a, "第一波最下行被禁", rows.is_lane_banned(last_row),
		"banned_lanes=" + str(rows.banned_lanes))

	## 看真实刷出来的僵尸：这一波里最下行一只都不该有
	await a.wait(SAMPLE_SECONDS)
	var bottom_num := 0
	var total := 0
	for zombie: Zombie000Base in mg.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie):
			continue
		total += 1
		if zombie.lane == last_row:
			bottom_num += 1
	_check(a, "第一波没有僵尸落在最下行", bottom_num == 0,
		"最下行 %d 只 / 全场 %d 只" % [bottom_num, total])

	## 钩子边界：原版条件是 `mCurrentWave <= 3`（0 起算 ⇒ 第 1~4 波）
	para.before_wave_spawn(cm, 3, false)
	_check(a, "波 3 仍然禁最下行", rows.is_lane_banned(last_row),
		"banned_lanes=" + str(rows.banned_lanes))
	para.before_wave_spawn(cm, 4, false)
	_check(a, "波 4 解除最下行限制", not rows.is_lane_banned(last_row),
		"banned_lanes=" + str(rows.banned_lanes))
	_finish(a)


## 等流程推进到「战斗进行中」
func _wait_main_game(a, mg) -> bool:
	var waited := 0.0
	while waited < 120.0 and mg.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		await a.wait(0.5)
		waited += 0.5
	var ok: bool = mg.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME
	_check(a, "流程已推进到战斗阶段", ok, "progress=" + str(mg.main_game_progress))
	return ok


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[INVISI_ROWS] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
