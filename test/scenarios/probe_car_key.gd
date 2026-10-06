extends RefCounted
## 探针：冒险模式 3-4 通关时掉落车钥匙 / 商店解锁
## 覆盖：
##   1. 3-4 配的是"通关时掉落"（drop_unlock_on_level_complete），不再由第 10 波僵尸携带
##   2. 通关瞬间掉车钥匙代替奖杯（首次通关奖励）
##   3. 点开车钥匙后直接结算：首次通关 3-4 -> 商店解锁，直接进商店
##   4. 反例：重打 3-4 不再掉钥匙，直接出奖杯
## 机器可读汇总：最后一行 [CARKEY] result=PASS|FAIL failed=<n>

var _failed := 0
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_03_04.gd"


func run(a) -> void:
	a.log("")
	a.log("========== 探针 3-4 车钥匙（通关掉落）==========")
	## 等主菜单自身初始化完再切场景，否则切场景会撞上「父节点正忙」的报错
	await a.wait(2.0)

	var state = Global.global_game_state
	## 已通关到 3-3（序号 23）：商店还没解锁
	_mark_cleared(state, 23)
	_check(a, "已通关序号=23", state.get_max_success_adventure_level() == 23,
		str(state.get_max_success_adventure_level()))
	_check(a, "商店未解锁", not state.is_shop_unlocked())

	# ------------------------------------------------ STEP1 进 3-4 并验证掉落配置
	a.log("STEP1 进入 3-4")
	var p = (load(LEVEL_PATH) as GDScript).new()
	p.set_choose_level(ADV, 2, "0024")
	Global.game_para = p
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[p.game_sences])
	if not await a.wait_scene("main_game", 15.0):
		_check(a, "进入 3-4", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(5.0)

	var para = Global.main_game.game_para
	_check(a, "关卡 id=0024(3-4)", para.level_id == "0024", para.level_id)
	_check(a, "配的是通关时掉落", para.drop_unlock_on_level_complete)
	_check(a, "不再由波次携带", para.drop_unlock_wave < 0, str(para.drop_unlock_wave))
	_check(a, "掉落提示提到车钥匙", "车钥匙" in para.drop_unlock_tip, para.drop_unlock_tip)
	_check(a, "掉落贴图是车钥匙", para.drop_unlock_icon != null
		and "CarKeys" in para.drop_unlock_icon.resource_path,
		str(para.drop_unlock_icon.resource_path if para.drop_unlock_icon != null else "null"))

	# ------------------------------------------------ STEP2 通关掉落：掉钥匙代替奖杯
	a.log("STEP2 触发通关掉落（create_trophy）")
	var dim = Global.main_game.drop_item_manager.dim_garden_plant
	var parent = dim.all_drop_garden_plant_parent
	var temp_layer = Global.main_game.canvas_layer_temp
	var drop_before: int = parent.get_child_count()
	var temp_before: int = temp_layer.get_child_count()
	Global.main_game.reward_manager.create_trophy(Vector2(600, 300))
	await a.wait(1.5)

	var new_drop = _find_new_present(parent)
	_check(a, "通关掉出了车钥匙礼包", new_drop != null,
		str(drop_before) + " -> " + str(parent.get_child_count()))
	_check(a, "掉落时还没抛奖杯", temp_layer.get_child_count() == temp_before,
		str(temp_before) + " -> " + str(temp_layer.get_child_count()))
	if new_drop == null:
		_finish(a)
		return
	_check(a, "礼包用的是车钥匙贴图", new_drop.icon_texture != null
		and "CarKeys" in new_drop.icon_texture.resource_path,
		str(new_drop.icon_texture.resource_path if new_drop.icon_texture != null else "null"))

	## 玩家点开礼包：奖励代替奖杯，读完提示后自动结算
	## 结算会切场景，所以"有没有抛奖杯"必须在切场景之前查（切完旧节点已释放）
	a.log("STEP3 点开车钥匙（应直接结算，不再抛奖杯）")
	new_drop._on_texture_button_pressed()
	await a.wait(2.0)
	_check(a, "礼包已被拾取", not is_instance_valid(new_drop) or new_drop.is_queued_for_deletion())
	_check(a, "拾取后不再抛奖杯", temp_layer.get_child_count() == temp_before,
		str(temp_before) + " -> " + str(temp_layer.get_child_count()))

	# ------------------------------------------------ STEP4 结算：首次通关 3-4 直接进商店
	a.log("STEP4 结算 3-4（应直接进商店）")
	if not await a.wait_scene("store", 15.0):
		_check(a, "通关 3-4 后进入商店", false, str(a.get_tree().current_scene.scene_file_path))
		_finish(a)
		return
	_check(a, "通关 3-4 后进入商店", true)
	await a.wait(2.0)
	_check(a, "商店已解锁", state.is_shop_unlocked())

	# ------------------------------------------------ STEP5 反例：重打 3-4 不再掉钥匙
	a.log("STEP5 重打 3-4（不再掉钥匙，直接出奖杯）")
	var p2 = (load(LEVEL_PATH) as GDScript).new()
	p2.set_choose_level(ADV, 2, "0024")
	Global.game_para = p2
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[p2.game_sences])
	if not await a.wait_scene("main_game", 15.0):
		_check(a, "重打进入 3-4", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(5.0)
	var dim2 = Global.main_game.drop_item_manager.dim_garden_plant
	var parent2 = dim2.all_drop_garden_plant_parent
	var temp2 = Global.main_game.canvas_layer_temp
	var drop_before2: int = parent2.get_child_count()
	var temp_before2: int = temp2.get_child_count()
	Global.main_game.reward_manager.create_trophy(Vector2(600, 300))
	await a.wait(1.5)
	_check(a, "重打不再掉钥匙", parent2.get_child_count() == drop_before2,
		str(drop_before2) + " -> " + str(parent2.get_child_count()))
	_check(a, "重打直接出奖杯", temp2.get_child_count() == temp_before2 + 1,
		str(temp_before2) + " -> " + str(temp2.get_child_count()))

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
	a.log("[CARKEY] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}


## 掉落容器里新出现的礼包（解锁道具）
func _find_new_present(parent: Node) -> Node:
	var found: Node = null
	for k in parent.get_children():
		if k is Present and not k.is_opened:
			found = k
	return found
#endregion
