extends RefCounted
## 一次性探针：解谜模式对齐原版后的关卡数据落位（实机进关）
##
## 校验：
##   1. 花瓶终结者第 1 关：25 个罐子（5 排 × 5）、无提示罐、无小推车
##   2. 僵尸公敌（无限）：卡槽 9 张僵尸卡（原版无尽没有巨人）、起始阳光 300

var _failed := 0


func run(a) -> void:
	await _check_pot(a)
	await _check_zombie_endless(a)
	a.log("")
	a.log("[PCHECK] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _enter(a, level_path: String) -> void:
	var para: Resource = (load(level_path) as GDScript).new()
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(3.0)
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.main_game_start()
	await a.wait(3.0)


func _check_pot(a) -> void:
	await _enter(a, "res://src/levels/mode_puzzle/puzzle_pot_01.gd")
	var mg = Global.main_game
	if mg == null:
		_failed += 1
		a.log("[PCHECK] FAIL 砸罐子关未创建主游戏")
		return
	_check(a, "砸罐子关已进入 MAIN_GAME",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME)
	var pot_num: int = mg.plant_cell_manager.curr_pot_num
	a.log("[PCHECK] 罐子数=%d" % pot_num)
	_check(a, "第 1 关 25 个罐子（5 排 × 5）", pot_num == 25)
	_check(a, "砸罐子关没有小推车", not mg.game_para.is_lawn_mover)


func _check_zombie_endless(a) -> void:
	await _enter(a, "res://src/levels/mode_puzzle/puzzle_zombie_10.gd")
	var mg = Global.main_game
	if mg == null:
		_failed += 1
		a.log("[PCHECK] FAIL 无尽关未创建主游戏")
		return
	var slot = mg.card_manager.card_slot_battle
	var cards: int = slot.curr_cards.size()
	a.log("[PCHECK] 无尽关卡槽僵尸卡=%d 阳光=%d" % [cards, slot.sun_value])
	_check(a, "无尽关 9 张僵尸卡（原版无巨人）", cards == 9)
	_check(a, "无尽关起始阳光 = 300", slot.sun_value == 300)
	_check(a, "无尽关不判负（阳光充足）",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME)


func _check(a, label: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	a.log("[PCHECK] %s %s" % ["PASS" if ok else "FAIL", label])
