extends RefCounted
## 探针：禅境花园的水壶（基础水壶 / 黄金水壶）
## 覆盖：
##   1. 没买黄金水壶时是基础水壶：普通壶身 / 普通按钮图标 / 没有范围准星 / 检测半径是个点，一次只浇 1 株
##   2. 买断黄金水壶后换黄金款：金色壶身 / 金色按钮图标 / 显示范围准星 / 检测半径放大，一次最多浇 4 株
##   3. 两套浇水动画在动画库里都存在（避免动画名写错，play 时才炸）
## 机器可读汇总：最后一行 [WATERCAN] result=PASS|FAIL failed=<n>

var _failed := 0

const GARDEN_SCENE := "res://src/garden/garden.tscn"
const PLANT_CELL_SCENE := preload("res://src/garden/plant_cell_garden.tscn")
const NORM_CAN_PNG := "res://assets/reanim/ZenGarden_wateringcan1.png"
const GOLD_CAN_PNG := "res://assets/reanim/ZenGarden_wateringcan1_gold.png"
const NORM_ICON_PNG := "res://assets/image/garden/WateringCan.png"
const GOLD_ICON_PNG := "res://assets/image/garden/WateringCanGold.png"


func run(a) -> void:
	a.log("")
	a.log("========== 探针 禅境花园水壶（基础 / 黄金） ==========")
	await a.wait(2.0)

	var state = Global.global_game_state
	## 通关到 5-10：花园已解锁
	_mark_cleared(state, 50)
	## 复位成「什么都没买过」：清掉已买断的花园工具
	state.garden_data = {"num_bg_page_0": 1, "num_bg_page_1": 0, "num_bg_page_2": 0}
	state.curr_num_new_garden_plant = 0

	a.get_tree().change_scene_to_file(GARDEN_SCENE)
	if not await a.wait_scene("garden", 15.0):
		_check(a, "进入花园", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(2.0)

	var garden = a.get_tree().current_scene
	var can: WateringCan = garden.watering_can

	a.log("STEP1 未买黄金水壶时是基础水壶")
	_check(a, "没买黄金水壶", not can.is_gold())
	_check(a, "壶身是普通水壶贴图",
		can.water_sprite.texture != null and can.water_sprite.texture.resource_path == NORM_CAN_PNG,
		str(can.water_sprite.texture))
	_check(a, "按钮图标是普通水壶图标",
		can.item_button.item_texture.texture != null
		and can.item_button.item_texture.texture.resource_path == NORM_ICON_PNG,
		str(can.item_button.item_texture.texture))
	_check(a, "不显示黄金水壶的范围准星", not can.zen_gold_tool_reticle_result.visible)
	_check(a, "检测半径是个点（一次只罩 1 株）",
		is_equal_approx((can.collision_shape.shape as CircleShape2D).radius, 0.1),
		str((can.collision_shape.shape as CircleShape2D).radius))

	a.log("STEP2 两套浇水动画都在动画库里")
	_check(a, "基础水壶动画存在", can.anim_lib.has_animation(can.WATER_ANIM[false]), str(can.WATER_ANIM[false]))
	_check(a, "黄金水壶动画存在", can.anim_lib.has_animation(can.WATER_ANIM[true]), str(can.WATER_ANIM[true]))

	a.log("STEP3 基础水壶一次只浇 1 株，黄金水壶一次最多 4 株")
	var dummy_cells := _make_dummy_cells(garden)
	can.curr_plant_cells = dummy_cells.duplicate()
	_check(a, "基础水壶只取 1 株", can.get_target_plant_cells().size() == 1,
		str(can.get_target_plant_cells().size()))

	a.log("STEP4 买断黄金水壶后换成黄金款")
	_check(a, "购买黄金水壶成功", state.buy_garden_tool(GardenManager.E_GardenTool.GoldWateringCan))
	garden._update_back_from_store()
	await a.wait(1.0)
	_check(a, "已拥有黄金水壶", can.is_gold())
	_check(a, "壶身换成黄金水壶贴图",
		can.water_sprite.texture != null and can.water_sprite.texture.resource_path == GOLD_CAN_PNG,
		str(can.water_sprite.texture))
	_check(a, "按钮图标换成黄金水壶图标",
		can.item_button.item_texture.texture != null
		and can.item_button.item_texture.texture.resource_path == GOLD_ICON_PNG,
		str(can.item_button.item_texture.texture))
	_check(a, "显示黄金水壶的范围准星", can.zen_gold_tool_reticle_result.visible)
	_check(a, "检测半径放大成范围圈",
		(can.collision_shape.shape as CircleShape2D).radius > 1.0,
		str((can.collision_shape.shape as CircleShape2D).radius))

	can.curr_plant_cells = dummy_cells.duplicate()
	_check(a, "黄金水壶一次最多浇 4 株", can.get_target_plant_cells().size() == 4,
		str(can.get_target_plant_cells().size()))

	for cell in dummy_cells:
		cell.queue_free()
	can.curr_plant_cells = []

	_finish(a)


#region 断言与工具
## 造 5 个假格子用来验证「一次浇几株」的上限（只用到 global_position）
func _make_dummy_cells(garden: Node) -> Array[PlantCellGarden]:
	var cells: Array[PlantCellGarden] = []
	for i in range(5):
		var cell: PlantCellGarden = PLANT_CELL_SCENE.instantiate()
		garden.add_child(cell)
		cell.global_position = Vector2(100 + i * 10, 100)
		cells.append(cell)
	return cells


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[WATERCAN] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}
#endregion
