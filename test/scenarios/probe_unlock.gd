extends RefCounted
## 探针 PROBE5：冒险模式通关 -> 植物解锁进度
## 覆盖：
##   1. 新档只解锁初始植物（豌豆射手）
##   2. 通关 1-1 后解锁向日葵，通关 2-1（关卡序号 11）后解锁阳光菇
##   3. 已通关关卡序号可被反解（get_max_success_adventure_level）
##   4. 重新读档不会丢解锁（按已通关关卡重新推导）
## 机器可读汇总：最后一行 [UNLOCK] result=PASS|FAIL failed=<n>

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE5 植物解锁进度 ==========")
	if not await _goto_level(a):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	await a.wait(4.0)
	## 卡槽被系统自动填满时关卡已跳过选卡并进入主游戏，不要重复触发开始流程
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.choosed_card_start_game()
	await a.wait(4.0)

	var state = Global.global_game_state
	var before: Array = state.curr_plant.duplicate()
	a.log("  1-1 通关前已解锁: %s" % str(before))
	_check(a, "新档只解锁初始植物", before.size() == 1 and before.has(CharacterRegistry.PlantType.P001PeaShooterSingle), str(before))

	## 通关 1-1（关卡序号 1）-> 向日葵
	Global.main_game.save_manager.update_level_state_data_success()
	await a.wait(0.5)
	var after1: Array = state.curr_plant.duplicate()
	a.log("  1-1 通关后已解锁: %s" % str(after1))
	_check(a, "通关 1-1 解锁向日葵", after1.has(CharacterRegistry.PlantType.P002SunFlower), str(after1))
	_check(a, "已通关关卡序号=1", state.get_max_success_adventure_level() == 1, str(state.get_max_success_adventure_level()))

	## 通关 2-1（关卡序号 11）-> 阳光菇
	var new_on_11: Array = state.unlock_plant_on_adventure_level(11)
	a.log("  2-1 解锁: %s" % str(new_on_11))
	_check(a, "通关 2-1 解锁阳光菇", state.curr_plant.has(CharacterRegistry.PlantType.P010SunShroom), str(state.curr_plant))
	_check(a, "重复通关不重复解锁", state.unlock_plant_on_adventure_level(1).is_empty())

	## 重新读档：解锁不能丢
	Global.save_service.load_global_game_data()
	await a.wait(0.5)
	var reloaded: Array = state.curr_plant.duplicate()
	a.log("  重新读档后已解锁: %s" % str(reloaded))
	_check(a, "重新读档保留豌豆射手", reloaded.has(CharacterRegistry.PlantType.P001PeaShooterSingle), str(reloaded))
	_check(a, "重新读档保留向日葵", reloaded.has(CharacterRegistry.PlantType.P002SunFlower), str(reloaded))

	## 紫卡购买资格（未通关到对应关卡时不开放）
	_check(a, "未通关的紫卡不开放购买", not state.is_purple_card_can_buy(CharacterRegistry.PlantType.P048CobCannon))
	_finish(a)


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[UNLOCK] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion


## 启动 -> 冒险模式 -> 第 1 关
func _goto_level(a) -> bool:
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)
	await a.click_first("Menu/Button1")
	if not await a.wait_scene("choose_level", 12.0):
		return false
	var gcl: Node = a.get_node_or_null("/root/ChooseLevel/AllPage/GridContainer")
	if gcl == null:
		return false
	await a.press_first("ChooseLevelButton/TextureButton")
	return await a.wait_scene("main_game", 10.0)
