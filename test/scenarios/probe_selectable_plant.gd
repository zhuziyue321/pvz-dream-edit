extends RefCounted
## 探针：「可选植物列表」——进选卡界面的门禁（见 `AllCards.add_selectable_plant`）
##
## 覆盖这条规矩：**注册 / 解锁都不等于可选**。
##   1. 原版常规植物默认就在列表里（不需要谁去登记）；调试模式专属 / 模组新增这些**追加类**
##      不在，开「调试模式」才由 `GlobalGameState._sync_debug_mode_plants()` 追加进去；
##   2. 运行期热注册一株植物（`PlantRuntimeKit.install`）之后：它有卡位、也解锁了，
##      但**待选区里没有它的卡位** —— 注册与解锁都只说明「它存在」；
##   3. 再补一行 `kit.make_selectable()`：它追加到列表末尾、待选区里出现且可见，
##      落位照「顺序下标 / 每页格数」（普通植物在前 ⇒ 追加类在第 2 页）；
##   4. 关调试模式 / 卸模组要把这一项摘干净（否则选卡界面会留一张永远选不了的卡）。
##
## 无头可跑，只动内存（不写存档、不落配置）。
## 机器可读汇总：最后一行 [SELECTABLE] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

const CARD_SLOT_SCENE := "res://src/ui/card/card_slot/card_slot_norm.tscn"
## 借本体豌豆射手当「运行期新增的植物」：探针不造美术，只验这条门禁
const LOAN_PLANT := PlantIds.PEA_SHOOTER_SINGLE


func run(a) -> void:
	a.log("")
	a.log("========== 探针：可选植物列表（进选卡界面的门禁）==========")
	var state := Global.global_game_state

	# ------------------------------------------------ STEP1 默认内容
	a.log("STEP1 原版常规植物默认在列表里，追加类不在")
	state.apply_debug_mode(false)
	var ordered := AllCards.get_plant_types_in_choose_order()
	a.log("   列表共 %d 株（每页 %d 格）" % [ordered.size(), _per_page_from_scene()])
	_check(a, "豌豆射手（原版常规）默认就在可选植物列表里",
		ordered.has(LOAN_PLANT) and AllCards.is_selectable_plant(LOAN_PLANT), str(ordered.size()))
	_check(a, "没开调试模式 → 调试专属四株不在列表里",
		not ordered.has(PlantIds.WALL_NUT_BOWLING)
			and not AllCards.is_selectable_plant(PlantIds.WALL_NUT_BOWLING),
		"列表里有保龄球=%s" % ordered.has(PlantIds.WALL_NUT_BOWLING))

	# ------------------------------------------------ STEP2 调试模式：四株追加在末尾
	a.log("STEP2 打开「调试模式」→ 四株追加在列表末尾，并在待选区点亮")
	state.apply_debug_mode(true)
	ordered = AllCards.get_plant_types_in_choose_order()
	_check(a, "调试四株追加在列表末尾（顺序照名单）",
		_same_tail(ordered, ConstPlantUnlock.DEBUG_MODE_PLANT_TYPES), str(ordered.size()))
	_check(a, "调试四株都算可选", _all_selectable(ConstPlantUnlock.DEBUG_MODE_PLANT_TYPES), "")

	var slot := await _open_card_slot(a)
	if slot == null:
		state.apply_debug_mode(false)
		_finish(a)
		return
	var candidate := slot.get_node_or_null("CardSlotCandidate") as CardSlotCandidate
	var per_page := _per_page(candidate)
	_check(a, "每页卡片数取到", per_page > 0, str(per_page))
	for plant_type: StringName in ConstPlantUnlock.DEBUG_MODE_PLANT_TYPES:
		var container := _container_of(candidate, plant_type)
		_check(a, "%s 在待选区里有卡位且可见" % plant_type,
			container != null and container.visible,
			"card_id=%s" % str(AllCards.plant_card_ids.get(plant_type, -1)))
		## 落位规矩：页码 = 顺序下标 / 每页格数（普通植物在前 ⇒ 追加类不在第 1 页）
		var order_index := ordered.find(plant_type)
		var page := _page_of(candidate, container)
		@warning_ignore("integer_division")
		var expect_page := order_index / per_page
		_check(a, "%s 的页码 = 顺序下标 / 每页格数" % plant_type, page == expect_page,
			"第 %d 页（期望第 %d 页）" % [page + 1, expect_page + 1])
		_check(a, "%s 排在普通植物之后（不在第 1 页）" % plant_type, page >= 1, "第 %d 页" % (page + 1))
	slot.free()

	# ------------------------------------------------ STEP3 运行期注册 ≠ 可选
	a.log("STEP3 运行期注册一株植物：注册 + 解锁 ≠ 可选")
	state.apply_debug_mode(false)
	var kit := PlantRuntimeKit.new()
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_scene = Global.character_registry.get_plant_info(
		LOAN_PLANT, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	recipe.plant_name = &"ProbeSelectable"
	recipe.card_face_fallback_plant = LOAN_PLANT
	if not kit.install(recipe):
		_check(a, "运行期植物能装上", false, "install 返回 false")
		_finish(a)
		return
	var plant_type: StringName = kit.recipe.plant_type
	a.log("   热注册 id = %s" % plant_type)
	_check(a, "它有卡位（登记 + 插卡成功）", AllCards.plant_card_ids.has(plant_type), str(plant_type))
	_check(a, "它已解锁（Kit 顺手解锁了）", state.is_plant_unlocked(plant_type), str(plant_type))
	_check(a, "但它没进可选植物列表（注册 / 解锁都只是「它存在」）",
		not AllCards.is_selectable_plant(plant_type), str(AllCards.get_plant_types_in_choose_order()))
	var slot2 := await _open_card_slot(a)
	if slot2 == null:
		kit.uninstall()
		_finish(a)
		return
	var candidate2 := slot2.get_node_or_null("CardSlotCandidate") as CardSlotCandidate
	_check(a, "待选区里没有它的卡位（已解锁也不会凭空点亮一张卡）",
		_container_of(candidate2, plant_type) == null, "card_id=%d" % AllCards.plant_card_ids[plant_type])
	slot2.free()

	# ------------------------------------------------ STEP4 make_selectable 之后才进选卡界面
	a.log("STEP4 补一行 kit.make_selectable() → 进列表末尾、待选区里有卡且可见")
	_check(a, "make_selectable() 登记成功", kit.make_selectable(), str(kit.recipe))
	_check(a, "它进了可选植物列表", AllCards.is_selectable_plant(plant_type), "")
	ordered = AllCards.get_plant_types_in_choose_order()
	_check(a, "追加项排在列表最后", not ordered.is_empty() and ordered[ordered.size() - 1] == plant_type,
		str(ordered.size()))
	var slot3 := await _open_card_slot(a)
	if slot3 == null:
		kit.uninstall()
		_finish(a)
		return
	var candidate3 := slot3.get_node_or_null("CardSlotCandidate") as CardSlotCandidate
	var container3 := _container_of(candidate3, plant_type)
	_check(a, "待选区里有它的卡位且可见", container3 != null and container3.visible,
		"container=%s" % str(container3))
	slot3.free()

	# ------------------------------------------------ STEP5 卸载：列表项与卡位一起撤
	a.log("STEP5 卸载 → 卡位与可选植物列表里那一项一起撤掉")
	kit.uninstall()
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(plant_type), str(plant_type))
	_check(a, "可选植物列表里那一项也摘掉了",
		not AllCards.is_selectable_plant(plant_type)
			and not AllCards.get_plant_types_in_choose_order().has(plant_type), "")
	_check(a, "解锁也撤掉了", not state.is_plant_unlocked(plant_type), str(plant_type))

	_finish(a)


#region 待选卡槽
## 造一个待选卡槽场景（调用方用完自己 `free()`），失败返回 null
func _open_card_slot(a) -> Control:
	var scene: PackedScene = load(CARD_SLOT_SCENE)
	if scene == null:
		_check(a, "待选卡槽场景能 load", false, CARD_SLOT_SCENE)
		return null
	var root: Control = scene.instantiate()
	a.get_tree().root.add_child(root)
	await a.frames(2)
	return root


## 某株植物在待选区里的卡位容器；没有卡位返回 null
func _container_of(candidate: CardSlotCandidate, plant_type: StringName) -> CardCandidateContainer:
	if candidate == null:
		return null
	return candidate.all_card_candidate_containers_plant.get(
		AllCards.plant_card_ids.get(plant_type, -1), null)


## 容器在第几页（页下标）
func _page_of(candidate: CardSlotCandidate, container: CardCandidateContainer) -> int:
	if candidate == null or container == null:
		return -1
	return candidate.all_card_page_array.find(container.get_parent().get_parent())


## 已造好的卡槽每页几格
func _per_page(candidate: CardSlotCandidate) -> int:
	if candidate == null or candidate.all_card_page_array.is_empty():
		return 0
	return candidate.all_card_page_array[0].get_child_count()


## 还没造卡槽时先看一眼模板每页几格（只为日志）
func _per_page_from_scene() -> int:
	var scene: PackedScene = load(CARD_SLOT_SCENE)
	if scene == null:
		return 0
	var slot: Control = scene.instantiate()
	var grid: GridContainer = slot.get_node_or_null(
		"CardSlotCandidate/AllCardPage/GridContainerPlant") as GridContainer
	var num: int = grid.get_child_count() if grid != null else 0
	slot.free()
	return num
#endregion


#region 断言与工具
func _all_selectable(plant_types: Array[StringName]) -> bool:
	for plant_type: StringName in plant_types:
		if not AllCards.is_selectable_plant(plant_type):
			return false
	return true


## src 的末尾几项是否与 expect 逐项相同（顺序也要一致）
func _same_tail(src: Array, expect: Array) -> bool:
	if src.size() < expect.size():
		return false
	var offset: int = src.size() - expect.size()
	for i in expect.size():
		if src[offset + i] != expect[i]:
			return false
	return true


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[SELECTABLE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
#endregion
