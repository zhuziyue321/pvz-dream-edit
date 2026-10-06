extends RefCounted
## 探针：第一次掉落钱的一次性提示
## 覆盖：
##   1. 金钱解锁后第一次掉金币 -> 弹出「存钱来买更酷的道具吧！」（原版 ADVICE_CLICKED_ON_COIN）
##   2. 提示标记落进全局状态（全局只弹一次，见 GlobalGameState.is_first_coin_advice_shown）
##   3. 之后再掉金币不再重复弹
##   4. 停留时长到了提示自动消失
## 机器可读汇总：最后一行 [FIRSTCOIN] result=PASS|FAIL failed=<n>

var _failed := 0
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
## 与 MainGameManager.ADVICE_FIRST_COIN 保持一致
const ADVICE_TEXT := "存钱来买更酷的道具吧！"
## 与 MainGameManager.ADVICE_FIRST_COIN_SHOW_TIME 保持一致（多给 1 秒余量）
const SHOW_TIME := 6.0


func run(a) -> void:
	a.log("")
	a.log("========== 第一次掉落钱的一次性提示 ==========")

	var state = Global.global_game_state
	state.curr_all_level_state_data = {}
	state.is_first_coin_advice_shown = false

	if not await _goto_level(a):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	await a.wait(4.0)

	# ------------------------------------------------ STEP1 通关 1-10：进 2-1 金钱解锁
	a.log("STEP1 模拟通关到 1-10（关卡序号 10）-> 正在打 2-1")
	_mark_cleared(state, 9)
	_check(a, "还在 1-10 时金钱未解锁", not state.is_money_unlocked(), str(state.get_max_success_adventure_level()))
	_mark_cleared(state, 10)
	_check(a, "进 2-1 后金钱已解锁", state.is_money_unlocked(), str(state.get_max_success_adventure_level()))

	var dim = Global.main_game.drop_item_manager.dim_coin
	if dim == null:
		_check(a, "找到 DIM_Coin 节点", false, "null")
		_finish(a)
		return

	# ------------------------------------------------ STEP2 第一次掉金币
	a.log("STEP2 第一次掉金币")
	var coin_num_before: int = dim.all_drop_coin_parent.get_child_count()
	EventBus.push_event("create_coin", [[1.0, 0.0, 0.0], Vector2(300, 300)])
	await a.wait(1.0)
	_check(a, "金币已生成", dim.all_drop_coin_parent.get_child_count() == coin_num_before + 1,
		str(coin_num_before) + " -> " + str(dim.all_drop_coin_parent.get_child_count()))
	var advice = _find_advice_ui()
	_check(a, "第一次掉金币弹出提示", advice != null)
	if advice != null:
		_check(a, "提示文本=存钱来买更酷的道具吧！", advice.get_advice_text() == ADVICE_TEXT,
			advice.get_advice_text())
		_check(a, "提示条可见", advice.is_advice_visible())
	_check(a, "提示标记已置位", state.is_first_coin_advice_shown, str(state.is_first_coin_advice_shown))

	# ------------------------------------------------ STEP3 第二次掉金币不再弹
	a.log("STEP3 第二次掉金币")
	EventBus.push_event("create_coin", [[1.0, 0.0, 0.0], Vector2(320, 300)])
	await a.wait(1.0)
	## 本关是 1-1 教程关，教程自己也会挂一个提示条，这里只数「第一次掉钱那一个之外」的
	_check(a, "第二次掉金币不再重复弹提示", _count_advice_ui_except(advice) == 0,
		str(_count_advice_ui_except(advice)))

	# ------------------------------------------------ STEP4 提示自动消失
	a.log("STEP4 等待提示自动消失")
	await a.wait(SHOW_TIME)
	_check(a, "提示自动消失", not is_instance_valid(advice))

	_finish(a)


#region 断言与工具
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[FIRSTCOIN] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}


## 主游戏界面层下的提示条（第一次掉钱时由 MainGameManager 挂上去）
func _find_advice_ui():
	var ui_layer: Node = Global.main_game.canvas_layer_ui
	if ui_layer == null:
		return null
	for c in ui_layer.get_children():
		if c is TutorialAdviceUI:
			return c
	return null


## 界面层下除 except 以外的提示条数量（教程关自己也会挂提示条，要排除掉）
func _count_advice_ui_except(except) -> int:
	var ui_layer: Node = Global.main_game.canvas_layer_ui
	if ui_layer == null:
		return 0
	var num := 0
	for c in ui_layer.get_children():
		if c is TutorialAdviceUI and c != except:
			num += 1
	return num


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
#endregion
