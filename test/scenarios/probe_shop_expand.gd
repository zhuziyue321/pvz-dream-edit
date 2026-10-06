extends RefCounted
## 探针：冒险模式 4-4 掉落玉米卷 / 商店扩充 / 通关后直接进商店
## 覆盖：
##   1. 4-4 关卡资源配了掉落解锁道具（通关时掉落 + 提示 + 玉米卷贴图），且掉落入口真的掉出来
##   2. 首次通关 4-4 后**直接进商店**（不回选关界面），商店扩展阶段 0 -> 1
##   3. 扩充后忧郁蘑菇 / 香蒲上架（未扩充时不上架）
##   4. 重打 4-4 不再跳商店，按原流程回选关界面（跳转只触发一次）
## 机器可读汇总：最后一行 [SHOPEXPAND] result=PASS|FAIL failed=<n>

var _failed := 0
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_04_04.gd"
const P043 := CharacterRegistry.PlantType.P043GloomShroom
const P044 := CharacterRegistry.PlantType.P044Cattail


func run(a) -> void:
	a.log("")
	a.log("========== 探针 4-4 玉米卷 / 商店扩充 ==========")
	## 等主菜单自身初始化完再切场景，否则切场景会撞上「父节点正忙」的报错
	await a.wait(2.0)

	var state = Global.global_game_state
	## 已通关到 4-3（序号 33）：商店已解锁但还没扩充
	_mark_cleared(state, 33)
	a.log("  已通关序号=%d 扩展阶段=%d" % [
		state.get_max_success_adventure_level(), state.get_shop_expand_stage()])
	_check(a, "已通关序号=33", state.get_max_success_adventure_level() == 33,
		str(state.get_max_success_adventure_level()))
	_check(a, "商店已解锁", state.is_shop_unlocked())
	_check(a, "扩充阶段=0", state.get_shop_expand_stage() == 0, str(state.get_shop_expand_stage()))
	_check(a, "下一次扩充关卡=4-4(34)", ConstUnlockLevel.get_next_shop_expand_level(33) == 34,
		str(ConstUnlockLevel.get_next_shop_expand_level(33)))
	_check(a, "扩充前忧郁蘑菇未上架", not state.is_purple_card_can_buy(P043))
	_check(a, "扩充前香蒲未上架", not state.is_purple_card_can_buy(P044))

	# ------------------------------------------------ STEP1 进 4-4 并验证掉落配置
	a.log("STEP1 进入 4-4")
	var p = (load(LEVEL_PATH) as GDScript).new()
	p.set_choose_level(ADV, 3, "0034")
	Global.game_para = p
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[p.game_sences])
	if not await a.wait_scene("main_game", 15.0):
		_check(a, "进入 4-4", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(5.0)

	var para = Global.main_game.game_para
	_check(a, "关卡 id=0034(4-4)", para.level_id == "0034", para.level_id)
	_check(a, "配的是通关时掉落", para.drop_unlock_on_level_complete)
	_check(a, "不再由波次携带", para.drop_unlock_wave < 0, str(para.drop_unlock_wave))
	_check(a, "掉落提示提到玉米卷", "玉米卷" in para.drop_unlock_tip, para.drop_unlock_tip)
	_check(a, "掉落贴图是玉米卷", para.drop_unlock_icon != null
		and "Taco" in para.drop_unlock_icon.resource_path,
		str(para.drop_unlock_icon.resource_path if para.drop_unlock_icon != null else "null"))

	## 真的掉一次：走通关掉落入口后掉落容器应多出一个礼包
	var dim = Global.main_game.drop_item_manager.dim_garden_plant
	var parent = dim.all_drop_garden_plant_parent
	var before: int = parent.get_child_count()
	Global.main_game.drop_item_manager.create_unlock_drop_on_level_complete(Vector2(600, 300))
	await a.wait(1.0)
	var after: int = parent.get_child_count()
	_check(a, "4-4 掉出了玉米卷礼包", after == before + 1, str(before) + " -> " + str(after))

	# ------------------------------------------------ STEP2 通关 4-4 应直接进商店
	a.log("STEP2 通关 4-4（走 Ctrl+D 的通关入口）")
	a.log("  通关前扩展阶段=%d 进度=%d" % [
		state.get_shop_expand_stage(), Global.main_game.main_game_progress])
	Global.main_game.shortcut_win_main_game()
	if not await a.wait_scene("store", 15.0):
		_check(a, "通关 4-4 后进入商店", false, str(a.get_tree().current_scene.scene_file_path))
		_finish(a)
		return
	_check(a, "通关 4-4 后进入商店", true)
	await a.wait(2.0)
	_check(a, "扩充阶段=1", state.get_shop_expand_stage() == 1, str(state.get_shop_expand_stage()))
	_check(a, "扩充后忧郁蘑菇可购买", state.is_purple_card_can_buy(P043))
	_check(a, "扩充后香蒲可购买", state.is_purple_card_can_buy(P044))

	# ------------------------------------------------ STEP3 商店里真的上架了
	a.log("STEP3 商店货架")
	var store: Node = a.get_node_or_null("/root/Store")
	if store == null:
		_check(a, "找到商店根节点", false, "null")
		_finish(a)
		return
	## 紫卡按「一行为一页」分三行摆放，忧郁蘑菇 / 香蒲在第一行
	var kids: Array[Node] = []
	for row in store.plant_card_rows:
		kids.append_array(row.get_children())
	_check(a, "紫卡三行里确实摆了商品", kids.size() > 0, str(kids.size()))
	var g_043 = _find_goods(kids, P043)
	var g_044 = _find_goods(kids, P044)
	_check(a, "忧郁蘑菇已上架(可见)", g_043 != null and g_043.visible, str(g_043))
	_check(a, "香蒲已上架(可见)", g_044 != null and g_044.visible, str(g_044))
	if g_043 != null:
		_check(a, "忧郁蘑菇售价 7500", g_043.price == 7500, str(g_043.price))
	if g_044 != null:
		_check(a, "香蒲售价 10000", g_044.price == 10000, str(g_044.price))

	# ------------------------------------------------ STEP4 反例：重打 4-4 不跳商店
	a.log("STEP4 重打 4-4（应回选关界面）")
	var p2 = (load(LEVEL_PATH) as GDScript).new()
	p2.set_choose_level(ADV, 3, "0034")
	Global.game_para = p2
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[p2.game_sences])
	if not await a.wait_scene("main_game", 15.0):
		_check(a, "重打进入 4-4", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(5.0)
	Global.main_game.shortcut_win_main_game()
	await a.wait(3.0)
	var path2: String = str(a.get_tree().current_scene.scene_file_path)
	_check(a, "重打 4-4 后回选关界面(不跳商店)", "adventure_choose_level" in path2, path2)

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
	a.log("[SHOPEXPAND] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}


func _find_goods(kids: Array, plant_type) -> Node:
	for k in kids:
		if "plant_type" in k and k.plant_type == plant_type:
			return k
	return null
#endregion
