extends RefCounted
## 探针：三种保龄球（1001 坚果保龄球 / 1002 爆炸坚果 / 1003 巨型坚果墙）在选卡界面的落位与解锁
##
## 无头可跑，只动内存（不调 save_config）。校验：
##   1. 三张卡在 AllCards 里有卡位，且按「每页卡片数」算都落在选卡界面第 2 页
##   2. 控制台「调试模式」条目存在且在调试分组
##   3. 勾上 → 三种保龄球进 curr_plant；勾掉 → 连同 selected_cards 里的对应条目一起清掉
##
## 机器可读汇总：最后一行 [BOWLINGDEBUG] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：保龄球植物的调试模式解锁 ==========")

	var plant_types := ConstPlantUnlock.DEBUG_MODE_PLANT_TYPES
	var per_page := _count_card_per_page()

	# ------------------------------------------------ STEP1 卡位与页码
	a.log("STEP1 三张保龄球卡落在选卡界面第 2 页")
	a.log("   待选网格模板每页卡片数=%d" % per_page)
	_check(a, "调试模式名下正好三种保龄球", plant_types.size() == 3, str(plant_types))
	_check(a, "每页卡片数已取到", per_page > 0, str(per_page))
	if per_page <= 0:
		_finish(a)
		return
	for plant_type: CharacterRegistry.PlantType in plant_types:
		if not AllCards.plant_card_ids.has(plant_type):
			_check(a, "保龄球 %d 有卡位" % plant_type, false, "没有任何卡位")
			continue
		var card_id: int = AllCards.plant_card_ids[plant_type]
		var page: int = card_id / per_page + 1
		var slot_in_page: int = card_id % per_page + 1
		_check(a, "保龄球 %d 落在第 2 页" % plant_type, page == 2,
			"card_id=%d → 第 %d 页第 %d 格" % [card_id, page, slot_in_page])

	# ------------------------------------------------ STEP2 控制台条目
	a.log("STEP2 控制台里有「调试模式」")
	var entry := Global.console_registry.get_entry(&"debug_mode")
	_check(a, "取到条目 debug_mode", entry != null, "null" if entry == null else entry.text)
	if entry == null:
		_finish(a)
		return
	_check(a, "条目挂在调试分组", entry.category == ConsoleBuiltinEntries.CATEGORY_DEBUG, entry.category)

	# ------------------------------------------------ STEP3 开 / 关同步
	a.log("STEP3 勾上 / 勾掉都要同步到 curr_plant")
	var state := Global.global_game_state
	state.apply_debug_mode(false)
	_check(a, "初始状态三种保龄球都未解锁", not _any_unlocked(state, plant_types), str(state.curr_plant))

	entry.set_value(true)
	_check(a, "勾上「调试模式」后三种保龄球进已解锁列表", _all_unlocked(state, plant_types), str(state.curr_plant))

	## 「重选上次卡片」照着 selected_cards 直接点卡位，卡片容器关掉实验后已隐藏 —— 条目必须一起清
	state.selected_cards.clear()
	for plant_type: CharacterRegistry.PlantType in plant_types:
		state.selected_cards.append({"card_type": ResourceCardReference.CardType.Plant,
			"content_id": plant_type, "is_imitater": false})
	entry.set_value(false)
	_check(a, "勾掉后三种保龄球退出已解锁列表", not _any_unlocked(state, plant_types), str(state.curr_plant))
	_check(a, "勾掉后 selected_cards 里的对应条目也清掉", state.selected_cards.is_empty(),
		str(state.selected_cards))

	_finish(a)


#region 断言与工具
func _any_unlocked(state: GlobalGameState, plant_types: Array[CharacterRegistry.PlantType]) -> bool:
	for plant_type: CharacterRegistry.PlantType in plant_types:
		if state.is_plant_unlocked(plant_type):
			return true
	return false


func _all_unlocked(state: GlobalGameState, plant_types: Array[CharacterRegistry.PlantType]) -> bool:
	for plant_type: CharacterRegistry.PlantType in plant_types:
		if not state.is_plant_unlocked(plant_type):
			return false
	return true


## 选卡界面一页能放几张卡：直接数待选网格模板的占位数量（与 CardSlotCandidate 的分页算法同源）
func _count_card_per_page() -> int:
	var template: PackedScene = load("res://src/ui/card/card_slot/card_slot_norm.tscn")
	if template == null:
		return 0
	var slot: Control = template.instantiate()
	var grid: GridContainer = slot.get_node_or_null(
		"CardSlotCandidate/AllCardPage/GridContainerPlant") as GridContainer
	var num: int = grid.get_child_count() if grid != null else 0
	slot.free()
	return num


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[BOWLINGDEBUG] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
#endregion
