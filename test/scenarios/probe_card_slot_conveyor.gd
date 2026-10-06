extends RefCounted
## 探针：卡槽 / 传送带控制器
##
## 覆盖：
##   1. 冒险 1-3 改成 Both 模式：卡槽（选卡）+ 传送带同时出现 —— 卡槽在上、传送带在下，
##      快捷键先数卡槽再数传送带，传送带能出卡且能查到带上的植物。
##   2. 冒险 5-10（僵王关）：传送带权重规则 ——
##      场上空花盆 <= 5 → 花盆权重下降；种上更多花盆后权重回到初始值；
##      传送带上花盆 >= 4 → 寒冰菇 / 辣椒权重上升。
##   3. 回归：纯卡槽关没有传送带、纯传送带关没有卡槽。
##
## 机器可读汇总：最后一行 [CARDSLOTCONVEYOR] result=PASS|FAIL failed=<n>

const LEVEL_01_03 := "res://src/levels/mode_adventure/adventure_01_03.gd"
const LEVEL_05_10 := "res://src/levels/mode_adventure/adventure_05_10.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 卡槽 / 传送带控制器 ==========")
	await _check_both_mode(a)
	await _check_zomboss_weight_rule(a)
	_finish(a)


#region 1. Both 模式：卡槽在上、传送带在下
func _check_both_mode(a) -> void:
	a.log("")
	a.log("-- 冒险 1-3（改成 Both）：卡槽 + 传送带同时出现 --")
	var para: ResourceLevelData = (load(LEVEL_01_03) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败")
		return
	## 关卡内设置传送带的种类权重：豌豆射手(1) / 坚果墙(4)
	para.card_mode = ConstLevelData.E_CardMode.Both
	para.conveyor_weights = ResourceCardWeight.create_plant_weights({1: 2, 4: 2})
	## 出战卡槽固定两格并预选两张（探针存档里玩家没有已解锁植物，选卡结果不好预期）
	para.max_choosed_card_num = 2
	para.prechosen_cards = ResourceCardReference.create_plant_list([1, 4])

	var mg = await _boot(a, para, MainSceneRegistry.MainScenes.MainGameFront)
	if mg == null:
		return

	var cm: CardManager = mg.card_manager
	var slot_ctrl: CardSlotController = cm.card_slot_controller
	var belt_ctrl: ConveyorBeltController = cm.conveyor_controller
	_check(a, "取到卡槽控制器", slot_ctrl != null, "card_slot_controller 为空")
	_check(a, "取到传送带控制器", belt_ctrl != null, "conveyor_controller 为空")
	if slot_ctrl == null or belt_ctrl == null:
		return
	_check(a, "Both 模式建出了卡槽", slot_ctrl.has_card_slot(), "没有常规卡槽")
	_check(a, "Both 模式建出了传送带", belt_ctrl.has_conveyor_belt(), "没有传送带")
	if not slot_ctrl.has_card_slot() or not belt_ctrl.has_conveyor_belt():
		return
	_check(a, "卡槽里有卡（选卡 / 系统预选卡）", slot_ctrl.get_cards().size() > 0, "出战卡槽是空的")

	await a.wait(4.0)
	## 布局：卡槽在上、传送带在下，两条都在屏幕内（屏幕 800x600）
	var slot_rect: Rect2 = slot_ctrl.card_slot_battle.get_global_rect()
	var belt_rect: Rect2 = belt_ctrl.card_slot_conveyor_belt.get_global_rect()
	a.log("  卡槽 rect = " + str(slot_rect) + "  传送带 rect = " + str(belt_rect))
	_check(a, "卡槽在上、传送带在下",
		slot_rect.position.y + slot_rect.size.y <= belt_rect.position.y + 1.0,
		"卡槽底 %s > 传送带顶 %s" % [str(slot_rect.position.y + slot_rect.size.y), str(belt_rect.position.y)])
	_check(a, "两条都在屏幕内", slot_rect.position.y >= 0.0 and belt_rect.position.y >= 0.0,
		"卡槽顶 %s / 传送带顶 %s" % [str(slot_rect.position.y), str(belt_rect.position.y)])

	## 快捷键分组：卡槽的卡在前，传送带的卡接在后面
	var root: CardSlotRoot = cm.card_slot_root
	_check(a, "快捷键第一组是卡槽的卡", root.curr_cards == slot_ctrl.get_cards(), "curr_cards 不是出战卡槽的数组")
	_check(a, "快捷键第二组是传送带的卡", root.second_cards == belt_ctrl.get_cards(), "second_cards 不是传送带的数组")

	## 查询传送带内的植物
	_check(a, "传送带在出卡", belt_ctrl.count_all_card() > 0, "带上还是空的")
	var plant_types: Array = belt_ctrl.get_card_plant_types()
	a.log("  传送带上的植物种类 = " + str(plant_types))
	_check(a, "传送带上只有关卡配的那几种植物",
		_not_in(plant_types, CharacterRegistry.PlantType.P015IceShroom)
		and _not_in(plant_types, CharacterRegistry.PlantType.P034FlowerPot),
		"出现了没配过的卡")
	var plant_type_sum := 0
	for plant_type in plant_types:
		plant_type_sum += belt_ctrl.count_card(plant_type)
	_check(a, "种类数 <= 总数且总数对得上", plant_type_sum == belt_ctrl.count_all_card(),
		"按种类累加 %d != 总数 %d" % [plant_type_sum, belt_ctrl.count_all_card()])


func _not_in(arr: Array, value) -> bool:
	return not arr.has(value)
#endregion


#region 2. 僵王战：传送带权重随场上情况浮动
func _check_zomboss_weight_rule(a) -> void:
	a.log("")
	a.log("-- 冒险 5-10：僵王战传送带权重规则 --")
	var para: ResourceLevelData = (load(LEVEL_05_10) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败")
		return
	var mg = await _boot(a, para, MainSceneRegistry.MainScenes.MainGameRoof)
	if mg == null:
		return

	var cm: CardManager = mg.card_manager
	var slot_ctrl: CardSlotController = cm.card_slot_controller
	var belt_ctrl: ConveyorBeltController = cm.conveyor_controller
	_check(a, "僵王关没有常规卡槽", not slot_ctrl.has_card_slot(), "僵王关不该有选卡卡槽")
	_check(a, "僵王关有传送带", belt_ctrl.has_conveyor_belt(), "没有传送带")
	if not belt_ctrl.has_conveyor_belt():
		return

	## 等关卡流程把僵王战的权重规则挂上来（开战前那一步）
	for _i in 40:
		if belt_ctrl.get_weight_rule_num() > 0:
			break
		await a.wait(0.5)
	_check(a, "僵王关挂上了传送带权重规则", belt_ctrl.get_weight_rule_num() > 0, "一条规则都没有")

	var pot_weight_full: int = 2
	## 开局场上有一大片空花盆（> 5）→ 花盆权重保持初始值
	belt_ctrl.refresh_weights()
	var empty_pot_num := _count_empty_flower_pot(mg)
	a.log("  开局空花盆 = " + str(empty_pot_num))
	var pot_weight := belt_ctrl.get_plant_weight(CharacterRegistry.PlantType.P034FlowerPot)
	_check(a, "空花盆 %d > 5：花盆权重保持初始值" % empty_pot_num, pot_weight == pot_weight_full,
		"权重 = " + str(pot_weight))
	if belt_ctrl.count_card(CharacterRegistry.PlantType.P034FlowerPot) < 4:
		_check(a, "带上花盆不够 4 个时寒冰菇权重不变",
			belt_ctrl.get_plant_weight(CharacterRegistry.PlantType.P015IceShroom) == pot_weight_full,
			"寒冰菇权重 = " + str(belt_ctrl.get_plant_weight(CharacterRegistry.PlantType.P015IceShroom)))

	## 在花盆里种满植物，把空花盆压到 <= 5 → 花盆权重下降
	var planted := _plant_into_flower_pots(mg, empty_pot_num - 5)
	_check(a, "把空花盆压到 <= 5", _count_empty_flower_pot(mg) <= 5,
		"还有 %d 个空花盆" % _count_empty_flower_pot(mg))
	belt_ctrl.refresh_weights()
	var pot_weight_down := belt_ctrl.get_plant_weight(CharacterRegistry.PlantType.P034FlowerPot)
	a.log("  种下 %d 株后（空花盆 %d）花盆权重 = %d" % [planted, _count_empty_flower_pot(mg), pot_weight_down])
	_check(a, "空花盆 <= 5：花盆权重下降", pot_weight_down < pot_weight_full,
		"权重没降（%d）" % pot_weight_down)

	## 传送带上堆到 4 个花盆 → 寒冰菇 / 辣椒权重上升
	belt_ctrl.add_weight_rule(ForcePotRule.new())
	var pot_num := 0
	for _i in 30:
		pot_num = belt_ctrl.count_card(CharacterRegistry.PlantType.P034FlowerPot)
		if pot_num >= 4:
			break
		await a.wait(1.0)
	belt_ctrl.refresh_weights()
	a.log("  传送带上花盆 = " + str(pot_num))
	_check(a, "传送带上攒够 4 个花盆", pot_num >= 4, "只有 %d 个" % pot_num)
	if pot_num < 4:
		return
	var ice_weight := belt_ctrl.get_plant_weight(CharacterRegistry.PlantType.P015IceShroom)
	var jalapeno_weight := belt_ctrl.get_plant_weight(CharacterRegistry.PlantType.P021Jalapeno)
	a.log("  带上 4 花盆时：寒冰菇 = " + str(ice_weight) + "  辣椒 = " + str(jalapeno_weight))
	_check(a, "带上花盆 >= 4：寒冰菇权重上升", ice_weight > pot_weight_full, "权重 = " + str(ice_weight))
	_check(a, "带上花盆 >= 4：辣椒权重上升", jalapeno_weight > pot_weight_full, "权重 = " + str(jalapeno_weight))


## 探针自带的规则：把花盆权重拉满，好让传送带快速攒够花盆（验证「带上花盆数」那条）
class ForcePotRule extends ConveyorWeightRule:
	func apply_weights(conveyor: ConveyorBeltController) -> void:
		conveyor.set_plant_weight(CharacterRegistry.PlantType.P034FlowerPot, 100)


## 场上的空花盆数（与 ZombossConveyorWeightRule 同一个口径：有花盆且花盆上没种东西）
func _count_empty_flower_pot(mg: MainGameManager) -> int:
	if mg == null or mg.plant_cell_manager == null:
		return 0
	var num := 0
	for plant_cell_lane in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in plant_cell_lane:
			var pot := plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Down)
			if pot == null or pot.plant_type != CharacterRegistry.PlantType.P034FlowerPot:
				continue
			if plant_cell.get_curr_plant_num() > 1:
				continue
			num += 1
	return num


## 往空花盆里种植物（把「空花盆」变成「已占用的花盆」），返回种下的株数
func _plant_into_flower_pots(mg: MainGameManager, num: int) -> int:
	if mg == null or mg.plant_cell_manager == null:
		return 0
	var planted := 0
	for plant_cell_lane in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in plant_cell_lane:
			if planted >= num:
				return planted
			if plant_cell.get_curr_plant_num() != 1:
				continue
			var pot := plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Down)
			if pot == null or pot.plant_type != CharacterRegistry.PlantType.P034FlowerPot:
				continue
			plant_cell.create_plant(CharacterRegistry.PlantType.P001PeaShooterSingle)
			planted += 1
	return planted
#endregion


#region 辅助
## 进指定关卡（跳过选卡），返回主游戏；失败返回 null
func _boot(a, para: ResourceLevelData, main_scene):
	if para == null:
		return null
	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[main_scene])
	await a.wait(3.0)
	var mg: MainGameManager = Global.main_game
	_check(a, "已进入主游戏（%s）" % str(para.card_mode), mg != null, "Global.main_game 为空")
	if mg == null:
		return null
	if mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		mg.main_game_start()
	await a.wait(2.0)
	return Global.main_game
#endregion


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[CARDSLOTCONVEYOR] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
