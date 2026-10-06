extends RefCounted
## 墓碑出怪回归：僵尸在「从墓碑冒头」的过程中被打死后，这块墓碑必须还能继续出怪
##
## 背景（本次修的 bug）：
##   原先 TombStone.create_new_zombie() 靠 await new_zombie.zombie_up_from_tombstone() 收尾，
##   收尾时才把 new_zombie 置空解锁墓碑。而冒头表现是 await body.zombie_body_up_from_ground()
##   一路 await 到 body 节点上的一个 tween.finished。
##   僵尸在冒头途中被锤死 → 节点 queue_free() → 那个 tween 随之被销毁且不会再发 finished →
##   挂在这行的协程永远醒不过来 → new_zombie 永远非空 → 这块墓碑从此不再出怪。
##   「冒头瞬间锤死」在锤僵尸玩法（迷你游戏 15 / 冒险 2-5）里是常规操作，
##   每发生一次就永久少一路出怪口，后期出怪越来越稀。
##
## 本探针手工驱动一块墓碑：出怪 → 冒头途中打死 → 等它销毁 → 再出一次，验第二只放得出来。
##
## 实测补充：僵尸被销毁后 Godot 会把引用变成「已释放对象」，`is_instance_valid()` 转 false，
## 所以墓碑**不会**永久锁死；但协程永不返回会让解锁时机变得不可控，
## 这条探针守住的是「中途被打死的僵尸不留下任何卡住墓碑的残留状态」。
##
## 机器可读汇总：最后一行 [TOMBSPAWN] result=PASS|FAIL failed=<n>

const LEVEL_MINI_15 := "res://src/levels/mode_minigame/minigame_15_hammer_zombie.gd"
const MINI := MainSceneRegistry.MainScenes.ChooseLevelMiniGame
const PAGE_MINI := 0
const ID_MINI_15 := "0014"
## 迷你游戏 15 的存档键（关卡脚本里写死的老值）
const ID_MINI_SAVE_KEY := "102_0_0002"
const DAVE_CLICK_POS := Vector2(400, 300)

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 墓碑出怪回归（冒头中被打死仍可再出怪） ==========")
	## 通关记录：没通关时首次通关会掉植物奖励代替奖杯，与本探针无关但会打乱流程
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
	await a.wait(1.0)

	## 停掉出怪器自己的节奏：本探针手工驱动墓碑，避免背景出怪干扰计数
	var source_timer: Timer = mg.zombie_manager.wave_source.get_node_or_null("HammerZombieTimer") as Timer
	if source_timer != null:
		source_timer.stop()
	await a.wait(0.5)

	var tomb_list = mg.plant_cell_manager.tombstone_list
	_check(a, "场上有墓碑", tomb_list.size() > 0, "num=" + str(tomb_list.size()))
	if tomb_list.is_empty():
		_finish(a)
		return
	var tomb: TombStone = tomb_list[0]

	## 1) 正常出一只
	var ok1 := tomb.create_new_zombie(CharacterRegistry.ZombieType.Z001Norm, 1.0)
	_check(a, "1) 第一次出怪成功", ok1, str(ok1))
	if not ok1:
		_finish(a)
		return
	_check(a, "1) 出怪期间墓碑标记为忙碌",
		tomb.is_creating_zombie(), str(tomb.is_creating_zombie()))
	## 忙碌期间重复调用必须被挡住
	_check(a, "1) 忙碌期间重复出怪被拒绝",
		not tomb.create_new_zombie(CharacterRegistry.ZombieType.Z001Norm, 1.0))

	## 2) 冒头途中把它打死 —— 正是原 bug 的触发条件
	var victim: Zombie000Base = tomb.new_zombie
	_check(a, "2) 抓到正在冒头的僵尸", is_instance_valid(victim), str(victim))
	if not is_instance_valid(victim):
		_finish(a)
		return
	victim.be_attack_to_death()
	## 等死亡淡出 1s → queue_free → tree_exited
	await a.wait(3.0)

	## 3) 墓碑必须恢复空闲，并且还能再放一只
	_check(a, "3) 墓碑恢复空闲（出怪中僵尸被销毁不留残留）",
		not tomb.is_creating_zombie(), str(tomb.is_creating_zombie()))
	var ok2 := tomb.create_new_zombie(CharacterRegistry.ZombieType.Z001Norm, 1.0)
	_check(a, "3) 第二次出怪成功", ok2, str(ok2))
	await a.wait(2.5)
	var alive := 0
	for z: Zombie000Base in mg.zombie_manager.all_zombies_1d:
		if is_instance_valid(z) and not z.is_death:
			alive += 1
	_check(a, "3) 场上确实冒出了新僵尸", alive > 0, "alive=" + str(alive))
	_finish(a)


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[TOMBSPAWN] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 等主游戏进入 MAIN_GAME（有戴夫对话就逐句点掉）
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


## 界面上正在说话的戴夫（挂在 canvas_layer_ui 下）
func _find_dave() -> CrazyDave:
	var mg = Global.main_game
	if mg == null:
		return null
	for child in mg.canvas_layer_ui.get_children():
		if child is CrazyDave:
			return child as CrazyDave
	return null


## 点掉戴夫对话（点面板覆盖全屏，每点一次推进一句）
func _skip_dave_dialog(a, timeout: float = 40.0) -> bool:
	var waited := 0.0
	while waited < timeout:
		if _find_dave() == null:
			return true
		await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
		await a.wait(0.5)
		waited += 0.5
	return _find_dave() == null
