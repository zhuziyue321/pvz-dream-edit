extends RefCounted
## 探针：调试模组与它解锁的植物 / 僵尸卡片
##   · 三种保龄球（1001 坚果保龄球 / 1002 爆炸坚果 / 1003 巨型坚果墙）与反向双发（049）
##     仍在卡片目录里；调试模组**只把它们并进已解锁名单**，不登记进可选植物列表
##     （所以选卡界面里没有这四张卡）
##   · 僵尸卡片：调试模组打开时开放，且整页落在选卡界面第 2 页
##
## 无头可跑。开关走 `ModManager.set_mod_enabled(ModIds.DEBUG, ...)`（会写模组存档，
## 跑批把用户目录重定向到临时目录，不污染真实存档）。校验：
##   1. 四张卡在 AllCards 里有卡位，且按「每页卡片数」算都落在卡片目录第 2 页
##   2. 反向双发本体可用：plant_info_data 里有场景条目，且场景能实例化出节点
##   3. 模组表里有「调试模式」
##   4. 打开 → 四株进已解锁名单、但不进可选植物列表；关掉 → 退出已解锁名单并清 selected_cards
##   5. 僵尸卡：关着不可用 → 打开可用；造出待选卡槽后共 2 页（植物 1 页 + 僵尸页）；
##      关掉后 selected_cards 里的僵尸条目一起清掉
##
## 机器可读汇总：最后一行 [BOWLINGDEBUG] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：调试专属植物 / 调试模组 ==========")

	var plant_types := ConstPlantUnlock.APPENDED_PLANT_TYPES
	var per_page := _count_card_per_page()

	# ------------------------------------------------ STEP1 卡位与页码
	a.log("STEP1 三张保龄球 + 反向双发仍占着卡片目录第 2 页")
	a.log("   待选网格模板每页卡片数=%d" % per_page)
	_check(a, "隐藏植物名单是三保龄球 + 反向双发共四株", plant_types.size() == 4, str(plant_types))
	_check(a, "反向双发在隐藏植物名单里", plant_types.has(
		PlantIds.PEA_SHOOTER_DOUBLE_REVERSE), str(plant_types))
	_check(a, "每页卡片数已取到", per_page > 0, str(per_page))
	if per_page <= 0:
		_finish(a)
		return
	for plant_type: StringName in plant_types:
		if not AllCards.plant_card_ids.has(plant_type):
			_check(a, "保龄球 %d 有卡位" % plant_type, false, "没有任何卡位")
			continue
		var card_id: int = AllCards.plant_card_ids[plant_type]
		## 页码 = card_id / 每页格数，整除取整（与 card_slot_candidate 的排页口径一致）
		@warning_ignore("integer_division")
		var page: int = card_id / per_page + 1
		var slot_in_page: int = card_id % per_page + 1
		_check(a, "隐藏植物 %d 落在卡片目录第 2 页" % plant_type, page == 2,
			"card_id=%d → 第 %d 页第 %d 格" % [card_id, page, slot_in_page])

	# ------------------------------------------------ STEP1.5 反向双发本体
	a.log("STEP1.5 反向双发本体可用（数据表有条目、场景能实例化）")
	_check_reverse_double(a)

	# ------------------------------------------------ STEP2 模组表
	a.log("STEP2 模组表里有「调试模式」")
	var debug_mod = ModManager.get_mod(ModIds.DEBUG)
	_check(a, "取到调试模组", debug_mod != null, "null")
	if debug_mod == null:
		_finish(a)
		return
	_check(a, "模组名 = 调试模式", debug_mod.get_mod_name() == "调试模式", debug_mod.get_mod_name())

	# ------------------------------------------------ STEP3 开 / 关只动已解锁名单
	a.log("STEP3 开 / 关只同步已解锁名单，不登记选卡界面")
	var state := Global.global_game_state
	ModManager.set_mod_enabled(ModIds.DEBUG, false)
	_check(a, "初始状态四株调试植物都未解锁", not _any_unlocked(state, plant_types), str(state.curr_plant))

	ModManager.set_mod_enabled(ModIds.DEBUG, true)
	_check(a, "打开「调试模式」后四株调试植物都进已解锁列表", _all_unlocked(state, plant_types),
		str(state.curr_plant))
	_check(a, "但四株没进可选植物列表（调试模式不登记选卡界面）", not _any_selectable(plant_types),
		str(AllCards.get_plant_types_in_choose_order().size()))

	## 「重选上次卡片」照着 selected_cards 直接点卡位，卡片容器关掉实验后已隐藏 —— 条目必须一起清
	state.selected_cards.clear()
	for plant_type: StringName in plant_types:
		state.selected_cards.append({"card_type": ResourceCardReference.CardType.Plant,
			"content_id": plant_type, "is_imitater": false})
	ModManager.set_mod_enabled(ModIds.DEBUG, false)
	_check(a, "关掉后四株调试植物退出已解锁列表", not _any_unlocked(state, plant_types), str(state.curr_plant))
	_check(a, "关掉后 selected_cards 里的对应条目也清掉", state.selected_cards.is_empty(),
		str(state.selected_cards))

	# ------------------------------------------------ STEP4 僵尸卡片（调试模组打开时第 2 页）
	a.log("STEP4 僵尸卡片：调试模组打开时开放，整页落在选卡界面第 2 页")
	state.selected_cards.clear()
	_check(a, "总开关关 + 模组关着 → 僵尸卡不可用", not state.is_zombie_card_enabled())

	ModManager.set_mod_enabled(ModIds.DEBUG, true)
	_check(a, "打开「调试模式」→ 僵尸卡可用", state.is_zombie_card_enabled())

	## 真的把待选卡槽造出来数页：页码不是算出来的，是 CardSlotCandidate 自己排的
	var slot_scene: PackedScene = load("res://src/ui/card/card_slot/card_slot_norm.tscn")
	var slot_root: Control = slot_scene.instantiate()
	a.get_tree().root.add_child(slot_root)
	await a.frames(2)
	var candidate: CardSlotCandidate = slot_root.get_node_or_null("CardSlotCandidate") as CardSlotCandidate
	if candidate == null:
		_check(a, "待选卡槽能造出来", false, "取不到 CardSlotCandidate")
		ModManager.set_mod_enabled(ModIds.DEBUG, false)
		_finish(a)
		return
	var page_num: int = candidate.all_card_page_array.size()
	a.log("   待选卡槽共生成 %d 页，可显示 %d 页，页码显示 %s" % [
		page_num, candidate.all_show_page.size(), candidate.label_page.text])
	## 隐藏植物不再进可选植物列表 ⇒ 植物只有 1 页；僵尸（含僵王）共 1 页 ⇒ 合计 2 页
	_check(a, "调试模式下共 2 页（植物 1 页 + 僵尸页，僵王已并入僵尸页）", page_num == 2, str(page_num))
	_check(a, "2 页全部可显示（僵尸页有默认解锁的僵尸）",
			candidate.all_show_page.size() == 2, str(candidate.all_show_page.size()))
	if page_num >= 2:
		_check(a, "第 2 页是僵尸页", _count_zombie_card(candidate.all_card_page_array[1]) > 0,
			"第 2 页上僵尸卡 %d 张" % _count_zombie_card(candidate.all_card_page_array[1]))
		_check(a, "僵尸页上有待选容器",
			candidate.all_card_candidate_containers_zombie.size() > 0,
			str(candidate.all_card_candidate_containers_zombie.size()))
	slot_root.free()

	## 关掉调试模组：僵尸页不再生成，「重选上次卡片」里的僵尸条目必须一起清
	state.selected_cards.clear()
	state.selected_cards.append({"card_type": ResourceCardReference.CardType.Zombie,
		"content_id": ZombieIds.NORM, "is_imitater": false})
	ModManager.set_mod_enabled(ModIds.DEBUG, false)
	_check(a, "关掉后僵尸卡重新不可用", not state.is_zombie_card_enabled())
	_check(a, "关掉后 selected_cards 里的僵尸条目也清掉", state.selected_cards.is_empty(),
		str(state.selected_cards))

	_finish(a)


#region 断言与工具
## 反向双发本体自检：登记 / 场景 / 种植条件 / 卡面阳光都要和数据表对得上，
## 免得卡片目录里留着一条「种下去什么都没有」的空卡
func _check_reverse_double(a) -> void:
	var reverse_type := PlantIds.PEA_SHOOTER_DOUBLE_REVERSE
	if not PlantInfoData.PLANT_INFO.has(reverse_type):
		_check(a, "反向双发在 plant_info_data 里有条目", false, "缺 %d" % reverse_type)
		return
	var info: Dictionary = PlantInfoData.PLANT_INFO[reverse_type]
	_check(a, "反向双发在 plant_info_data 里有条目", true,
		str(info.get(CharacterRegistry.PlantInfoAttribute.PlantName, "")))

	var scene = info.get(CharacterRegistry.PlantInfoAttribute.PlantScenes, null)
	_check(a, "反向双发登记了植物场景", scene is PackedScene, str(scene))
	if scene is PackedScene:
		var instance: Node = scene.instantiate()
		_check(a, "反向双发场景能实例化", instance != null,
			"节点名=%s" % (instance.name if instance != null else "null"))
		if instance != null:
			instance.free()

	_check(a, "反向双发登记了种植条件",
		info.get(CharacterRegistry.PlantInfoAttribute.PlantConditionResource, null) != null,
		str(info.get(CharacterRegistry.PlantInfoAttribute.PlantConditionResource, null)))

	## all_plant_card_prefabs 的值是 Card 节点本身（不是 NodePath），直接取即可
	if AllCards.all_plant_card_prefabs.has(reverse_type):
		var card_node: Node = AllCards.all_plant_card_prefabs[reverse_type]
		var card_sun: int = int(card_node.get("sun_cost"))
		var data_sun: int = int(info.get(CharacterRegistry.PlantInfoAttribute.SunCost, -1))
		_check(a, "卡面阳光与数据表 SunCost 一致", card_sun == data_sun,
			"卡面=%d 数据表=%d" % [card_sun, data_sun])


func _any_unlocked(state: GlobalGameState, plant_types: Array[StringName]) -> bool:
	for plant_type: StringName in plant_types:
		if state.is_plant_unlocked(plant_type):
			return true
	return false


func _all_unlocked(state: GlobalGameState, plant_types: Array[StringName]) -> bool:
	for plant_type: StringName in plant_types:
		if not state.is_plant_unlocked(plant_type):
			return false
	return true


func _any_selectable(plant_types: Array[StringName]) -> bool:
	for plant_type: StringName in plant_types:
		if AllCards.is_selectable_plant(plant_type):
			return true
	return false


## 一页上有几张僵尸卡：翻这一页的占位，看挂着的待选容器里那张卡是什么类型
func _count_zombie_card(page: GridContainer) -> int:
	var num := 0
	if page == null:
		return num
	for placeholder in page.get_children():
		if placeholder.get_child_count() == 0:
			continue
		var container = placeholder.get_child(0)
		if container == null or not is_instance_valid(container):
			continue
		var card: Card = container.get("card") as Card
		if card == null:
			continue
		if card.card_zombie_type != ZombieIds.NULL:
			num += 1
	return num


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
