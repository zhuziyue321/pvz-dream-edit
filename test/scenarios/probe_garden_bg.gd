extends RefCounted
## 探针：禅境花园背景的「拥有 / 未拥有」
## 覆盖：
##   1. 商店没买的背景（蘑菇园 / 水族馆）页数为 0，花园里不出现，翻页直接跳过
##   2. 买下后该背景才进入翻页循环，页码标签只统计已拥有的背景
##   3. 当前背景被置成未拥有的背景时，进页会自动纠正回已拥有的背景
## 机器可读汇总：最后一行 [GARDENBG] result=PASS|FAIL failed=<n>

var _failed := 0

const GARDEN_SCENE := "res://src/garden/garden.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针 禅境花园背景（拥有 / 未拥有） ==========")
	await a.wait(2.0)

	var state = Global.global_game_state
	## 通关到 5-10：花园已解锁
	_mark_cleared(state, 50)
	## 复位成「什么都没买过」：蘑菇园 / 水族馆 0 页
	state.garden_data = {"num_bg_page_0": 1, "num_bg_page_1": 0, "num_bg_page_2": 0}
	state.curr_num_new_garden_plant = 0

	a.log("STEP1 只拥有阳光房时，翻页不会进未购买的蘑菇园 / 水族馆")
	a.get_tree().change_scene_to_file(GARDEN_SCENE)
	if not await a.wait_scene("garden", 15.0):
		_check(a, "进入花园", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(2.0)

	var garden = a.get_tree().current_scene
	_check(a, "花园根节点是 GardenManager", garden is GardenManager, str(garden))
	_check(a, "已拥有背景只有阳光房",
		state.get_owned_garden_bg_types().size() == 1
		and state.is_garden_bg_owned(GardenManager.E_GardenBgType.GreenHouse),
		str(state.get_owned_garden_bg_types()))
	_check(a, "背景种类标签为 1/1", garden.page_info_label2.text == "1/1", garden.page_info_label2.text)

	garden._on_next_pressed()
	await a.wait(0.5)
	_check(a, "翻页后仍在阳光房",
		garden.curr_bg_type == GardenManager.E_GardenBgType.GreenHouse, str(garden.curr_bg_type))

	a.log("STEP2 买下蘑菇园后能翻到蘑菇园，未买的水族馆仍然跳过")
	_check(a, "购买蘑菇园成功", state.buy_garden_bg(GardenManager.E_GardenBgType.MushroomGraden))
	garden._on_next_pressed()
	await a.wait(0.5)
	_check(a, "翻到蘑菇园",
		garden.curr_bg_type == GardenManager.E_GardenBgType.MushroomGraden, str(garden.curr_bg_type))
	_check(a, "背景种类标签为 2/2", garden.page_info_label2.text == "2/2", garden.page_info_label2.text)
	garden._on_next_pressed()
	await a.wait(0.5)
	_check(a, "水族馆未买，翻回阳光房",
		garden.curr_bg_type == GardenManager.E_GardenBgType.GreenHouse, str(garden.curr_bg_type))
	_check(a, "重复购买蘑菇园被拒绝",
		not state.buy_garden_bg(GardenManager.E_GardenBgType.MushroomGraden))

	a.log("STEP3 当前背景被置为未拥有的水族馆时，进页自动纠正")
	garden.curr_bg_page_node.queue_free()
	garden.curr_bg_type = GardenManager.E_GardenBgType.Aquarium
	garden.init_new_page()
	await a.wait(0.5)
	_check(a, "自动纠正到阳光房",
		garden.curr_bg_type == GardenManager.E_GardenBgType.GreenHouse, str(garden.curr_bg_type))

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
	a.log("[GARDENBG] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}
#endregion
