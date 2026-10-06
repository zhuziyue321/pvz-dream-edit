extends RefCounted
## 探针：禅境花园工具栏的「买了才出现 / 用完才撤下」
## 覆盖：
##   1. 什么都没买时，手套 / 肥料 / 巧克力的工具栏按钮都藏起来
##   2. 商店买断手套后从商店返回（_update_back_from_store），手套按钮当场出现
##      —— 修的就是这里：以前要退回主菜单重进花园（走 _ready）才出现
##   3. 补一份肥料库存后从商店返回，肥料按钮当场出现
##   4. 道具本体不被误显示：按钮出现 ≠ 道具被激活（激活态由 ItemBase 管）
## 机器可读汇总：最后一行 [GARDENTOOLBAR] result=PASS|FAIL failed=<n>

var _failed := 0

const GARDEN_SCENE := "res://src/garden/garden.tscn"
const PLANT_CELL_SCENE := preload("res://src/garden/plant_cell_garden.tscn")


func run(a) -> void:
	a.log("")
	a.log("========== 探针 禅境花园工具栏（买了才出现） ==========")
	await a.wait(2.0)

	var state = Global.global_game_state
	## 通关到 5-10：花园已解锁
	_mark_cleared(state, 50)
	## 复位成「什么都没买过」：清掉已买断的花园工具与消耗品库存
	state.garden_data = {"num_bg_page_0": 1, "num_bg_page_1": 0, "num_bg_page_2": 0}
	state.curr_num_new_garden_plant = 0

	a.get_tree().change_scene_to_file(GARDEN_SCENE)
	if not await a.wait_scene("garden", 15.0):
		_check(a, "进入花园", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(2.0)

	var garden = a.get_tree().current_scene
	var glove = garden.glove
	var fertilizer = garden.garden_tool_items[GardenManager.E_GardenTool.Fertilizer]

	a.log("STEP1 没买过的工具不上工具栏")
	_check(a, "手套按钮隐藏", not glove.item_button.visible, str(glove.item_button.visible))
	_check(a, "肥料按钮隐藏", not fertilizer.item_button.visible, str(fertilizer.item_button.visible))

	a.log("STEP2 商店买断手套后从商店返回，手套当场出现")
	_check(a, "购买园艺手套成功", state.buy_garden_tool(GardenManager.E_GardenTool.GardeningGlove))
	garden._update_back_from_store()
	await a.wait(1.0)
	_check(a, "手套已拥有", state.is_garden_tool_bought(GardenManager.E_GardenTool.GardeningGlove))
	_check(a, "手套按钮已出现", glove.item_button.visible, str(glove.item_button.visible))
	_check(a, "手套本体仍是未激活（没被误显示）", not glove.visible and not glove.is_activate)
	_check(a, "没买的肥料按钮还是藏着的", not fertilizer.item_button.visible)

	a.log("STEP3 补一份肥料库存后从商店返回，肥料当场出现")
	_check(a, "买入一份肥料", state.add_garden_tool_num(GardenManager.E_GardenTool.Fertilizer, 1))
	garden._update_back_from_store()
	await a.wait(1.0)
	_check(a, "肥料按钮已出现", fertilizer.item_button.visible, str(fertilizer.item_button.visible))
	_check(a, "肥料本体仍是未激活（没被误显示）", not fertilizer.visible and not fertilizer.is_activate)

	a.log("STEP4 在花园里用掉最后一份肥料，按钮当场撤下（走真实的 use_it 流程）")
	_check(a, "当前只有一份肥料库存", state.get_garden_tool_num(GardenManager.E_GardenTool.Fertilizer) == 1)
	var dummy_cell: PlantCellGarden = PLANT_CELL_SCENE.instantiate()
	garden.add_child(dummy_cell)
	dummy_cell.global_position = Vector2(200, 200)
	fertilizer.curr_plant_cell = dummy_cell
	fertilizer.use_it()
	await a.wait(3.0)
	_check(a, "肥料库存已扣光", state.get_garden_tool_num(GardenManager.E_GardenTool.Fertilizer) == 0)
	_check(a, "肥料按钮已撤下", not fertilizer.item_button.visible)
	dummy_cell.queue_free()

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
	a.log("[GARDENTOOLBAR] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}
#endregion
