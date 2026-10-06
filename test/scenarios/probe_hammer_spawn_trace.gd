extends RefCounted
## 锤僵尸出怪节奏观测：把每一次「墓碑出怪」和场上的墓碑 / 僵尸数按时间打点，
## 用来核对 HammerZombieManager 的实际出怪是否兑现了它自己的配置
## （每小组几只、每大组结束后补墓碑、墓碑忙碌时会不会丢怪）
##
## 机器可读汇总：最后一行 [HAMMERTRACE] result=PASS|FAIL failed=<n>

const LEVEL_MINI_15 := "res://src/levels/mode_minigame/minigame_15_hammer_zombie.gd"
const MINI := MainSceneRegistry.MainScenes.ChooseLevelMiniGame
const PAGE_MINI := 0
const ID_MINI_15 := "0014"
const ID_MINI_SAVE_KEY := "102_0_0002"
const DAVE_CLICK_POS := Vector2(400, 300)
## 观测时长（秒）：覆盖若干个大组
const TRACE_SECONDS := 70.0

var _failed := 0
var _created := 0


func run(a) -> void:
	a.log("")
	a.log("========== 锤僵尸出怪节奏观测（迷你游戏 15） ==========")
	Global.global_game_state.curr_all_level_state_data = {ID_MINI_SAVE_KEY: {"IsSuccess": true}}
	var para: ResourceLevelData = (load(LEVEL_MINI_15) as GDScript).new()
	para.set_choose_level(MINI, PAGE_MINI, ID_MINI_15)
	Global.game_para = para
	await a.wait(2.0)
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	if not await _wait_main_game(a, 60.0):
		_check(a, "进入 MAIN_GAME", false, "超时")
		_finish(a)
		return

	var mg = Global.main_game
	var zm = mg.zombie_manager
	var source = zm.wave_source as HammerZombieManager
	_check(a, "出怪器是 HammerZombieManager", source != null, str(source))
	if source == null:
		_finish(a)
		return
	## 僵尸是挂在各条 ZombieRow 下的，不是直接挂 zombies_root
	for row in zm.all_zombie_rows:
		row.child_entered_tree.connect(_on_zombie_created)

	a.log("  t(s)  wave/grp  tombstones(busy)  created  alive  progress")
	var max_group_seen := -2
	var waited := 0.0
	while waited < TRACE_SECONDS:
		if mg.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
			a.log("  观测提前结束：主游戏已离开 MAIN_GAME -> " + str(mg.main_game_progress))
			break
		## 没有玩家代打，不清理的话僵尸很快进家触发 GAME_OVER，就看不出后面的出怪节奏了
		for z: Zombie000Base in zm.all_zombies_1d.duplicate():
			if is_instance_valid(z) and not z.is_death and z.global_position.x < 260:
				z.be_attack_to_death()
		var busy := 0
		for t: TombStone in mg.plant_cell_manager.tombstone_list:
			if is_instance_valid(t) and t.is_creating_zombie():
				busy += 1
		var alive := 0
		for z: Zombie000Base in zm.all_zombies_1d:
			if is_instance_valid(z) and not z.is_death:
				alive += 1
		a.log("  [%5.1f] %d/%d  tomb=%d(%d)  created=%d  alive=%d  %s" % [
			waited, source.curr_wave, source.curr_group_min,
			mg.plant_cell_manager.tombstone_list.size(), busy, _created, alive,
			str(mg.main_game_progress),
		])
		max_group_seen = maxi(max_group_seen, source.curr_all_group_min_num_sum)
		await a.wait(2.0)
		waited += 2.0

	## 卡 bug 时它会停在第一组（caught_wave=0/小组和 0），这里要求至少跑过 15 个小组
	_check(a, "出怪器持续推进（>15 小组）", max_group_seen > 15, "sum=" + str(max_group_seen))
	_check(a, "整段观测期间一直在刷新僵尸", _created > 10, "created=" + str(_created))
	_finish(a)


func _on_zombie_created(_n: Node) -> void:
	_created += 1


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[HAMMERTRACE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null:
			if _find_dave() != null and not await _skip_dave_dialog(a):
				return false
			if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
				return true
		await a.wait(0.5)
		waited += 0.5
	return false


func _find_dave() -> CrazyDave:
	var mg = Global.main_game
	if mg == null:
		return null
	for child in mg.canvas_layer_ui.get_children():
		if child is CrazyDave:
			return child as CrazyDave
	return null


func _skip_dave_dialog(a, timeout: float = 40.0) -> bool:
	var waited := 0.0
	while waited < timeout:
		if _find_dave() == null:
			return true
		await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
		await a.wait(0.5)
		waited += 0.5
	return _find_dave() == null
