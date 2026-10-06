extends RefCounted
## 临时探针：2-5 锤僵尸关实机冒烟
## 覆盖：进入 MAIN_GAME、固定 3 张出战卡、锤子就位、开局墓碑 9、锤僵尸出怪、砸僵尸掉阳光

const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_DIR := "res://src/levels/mode_adventure/"
const LEVEL_FILE_FORMAT := "adventure_02_%02d.gd"
const PAGE_02 := 1
const ID_02_05 := "0015"
const EXPECT_CARDS: Array[int] = [5, 12, 3]
## 戴夫对话的点击位置（设计分辨率 800x600 的屏幕中心；戴夫的点击面板覆盖全屏，点哪都能推进）
const DAVE_CLICK_POS := Vector2(400, 300)

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 2-5 锤僵尸关实机 ==========")
	Global.global_game_state.curr_plant.assign([CharacterRegistry.PlantType.P001PeaShooterSingle])
	Global.global_game_state.curr_all_level_state_data = {}
	var para: ResourceLevelData = (load(LEVEL_DIR + (LEVEL_FILE_FORMAT % 5)) as GDScript).new()
	para.set_choose_level(ADV, PAGE_02, ID_02_05)
	Global.game_para = para
	await a.wait(2.0)
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	if not await _wait_main_game(a, 60.0):
		_check(a, "2-5 进入 MAIN_GAME", false, "超时")
		_finish(a)
		return
	_check(a, "2-5 进入 MAIN_GAME", true)

	var mg = Global.main_game
	await a.wait(1.0)

	## 固定出战卡
	var battle = mg.card_manager.card_slot_battle
	var got: Array[int] = []
	if battle != null:
		for c in battle.curr_cards:
			got.append(c.card_plant_type)
	_check(a, "出战卡槽 = 3 张卡", got.size() == 3, str(got))
	_check(a, "固定卡 = 土豆地雷 / 墓碑吞噬者 / 樱桃炸弹", got == EXPECT_CARDS, str(got))
	a.log("  出战卡=%s 场上阳光节点=%d" % [str(got), mg.suns.get_child_count()])

	## 锤子（不再挂在 game_item_manager.gim_other 上，改由 LevelRuleHammerZombie 装到 UI 之上）
	var hammer: Hammer = null
	for node in mg.canvas_layer_temp.get_children():
		if node is Hammer:
			hammer = node
			break
	_check(a, "场上生成了锤子", hammer != null, str(hammer))
	if hammer != null:
		_check(a, "锤子已启用", hammer.is_used, str(hammer.is_used))
		_check(a, "锤子会掉阳光", hammer.can_sun, str(hammer.can_sun))

	## 墓碑
	_check(a, "开局墓碑 = 9",
		mg.plant_cell_manager.tomb_stone_manager.tombstone_num == 9,
		str(mg.plant_cell_manager.tomb_stone_manager.tombstone_num))

	## 出怪器不再常驻主场景，改由本关的玩法规则注入
	var zm = mg.zombie_manager
	_check(a, "出怪器已注入 ZombieManager（不再常驻主场景）", zm.wave_source != null, str(zm.wave_source))
	_check(a, "注入的是锤僵尸出怪器", zm.wave_source is HammerZombieManager, str(zm.wave_source))

	## 出怪（锤僵尸模式固定 2 秒后开波，僵尸从墓碑冒头）
	var seen := false
	var waited := 0.0
	while waited < 25.0:
		if zm.zombies_root.get_child_count() > 0 \
		or mg.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
			seen = true
			break
		await a.wait(0.5)
		waited += 0.5
	_check(a, "25 秒内出现了僵尸", seen, "num=" + str(zm.zombies_root.get_child_count()))
	_finish(a)


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[HAMMER25] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 等主游戏进入 MAIN_GAME 阶段：2-5 有开场戴夫对话，要逐句点完才进得去
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


## 界面上正在说话的戴夫（挂在 canvas_layer_ui 下），没有则返回 null
func _find_dave() -> CrazyDave:
	var mg = Global.main_game
	if mg == null:
		return null
	for child in mg.canvas_layer_ui.get_children():
		if child is CrazyDave:
			return child as CrazyDave
	return null


## 点掉戴夫对话：戴夫的点击面板覆盖全屏，每点一次推进一句，说到最后一句后自动离场
func _skip_dave_dialog(a, timeout: float = 40.0) -> bool:
	var waited := 0.0
	while waited < timeout:
		if _find_dave() == null:
			return true
		await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
		await a.wait(0.5)
		waited += 0.5
	return _find_dave() == null
