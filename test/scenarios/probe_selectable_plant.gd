extends RefCounted
## 探针：「可选植物列表」——进选卡界面的门禁（见 `AllCards.register_plant_choose_page`）
##
## 覆盖这条规矩：**注册 / 解锁都不等于可选**。
##   1. 原版常规植物默认就在列表里（不需要谁去登记）；运行期解锁的 / 模组新增这些**追加类**
##      不在，打开调试模组只把四株并进已解锁名单，**不登记**任何选卡页；
##   2. 运行期热注册一株植物（`PlantRuntimeKit.install`）之后：它有卡位、也解锁了，
##      但**待选区里没有它的卡位** —— 注册与解锁都只说明「它存在」；
##   3. 再自己登记一页（`register_plant_choose_page`）：它在那一页上、待选区里出现且可见
##      （页接在原版植物页之后 ⇒ 它不在第 1 页）；
##   4. 卸模组要把那一页摘干净（否则选卡界面会留一张永远选不了的卡）。
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
	ModManager.set_mod_enabled(ModIds.DEBUG, false)
	var ordered := AllCards.get_plant_types_in_choose_order()
	a.log("   列表共 %d 株（每页 %d 格）" % [ordered.size(), _per_page_from_scene()])
	_check(a, "豌豆射手（原版常规）默认就在可选植物列表里",
		ordered.has(LOAN_PLANT) and AllCards.is_selectable_plant(LOAN_PLANT), str(ordered.size()))
	_check(a, "没开调试模式 → 调试专属四株不在列表里",
		not ordered.has(PlantIds.WALL_NUT_BOWLING)
			and not AllCards.is_selectable_plant(PlantIds.WALL_NUT_BOWLING),
		"列表里有保龄球=%s" % ordered.has(PlantIds.WALL_NUT_BOWLING))

	# ------------------------------------------------ STEP2 调试模组：只解锁、不登记
	a.log("STEP2 打开「调试模式」→ 四株进已解锁名单，但不进可选植物列表")
	ModManager.set_mod_enabled(ModIds.DEBUG, true)
	_check(a, "四株都已解锁",
		_all_unlocked(state, ConstPlantUnlock.APPENDED_PLANT_TYPES), str(state.curr_plant))
	ordered = AllCards.get_plant_types_in_choose_order()
	_check(a, "但四株都不在可选植物列表里（调试模式不登记选卡界面）",
		not _has_any(ordered, ConstPlantUnlock.APPENDED_PLANT_TYPES), str(ordered.size()))
	_check(a, "四株都不算可选",
		not _any_selectable(ConstPlantUnlock.APPENDED_PLANT_TYPES), "")

	var slot := await _open_card_slot(a)
	if slot == null:
		ModManager.set_mod_enabled(ModIds.DEBUG, false)
		_finish(a)
		return
	var candidate := slot.get_node_or_null("CardSlotCandidate") as CardSlotCandidate
	for plant_type: StringName in ConstPlantUnlock.APPENDED_PLANT_TYPES:
		_check(a, "%s 在待选区里没有卡位（已解锁也没点亮）" % plant_type,
			_container_of(candidate, plant_type) == null,
			"card_id=%s" % str(AllCards.plant_card_ids.get(plant_type, -1)))
	slot.free()
	ModManager.set_mod_enabled(ModIds.DEBUG, false)

	# ------------------------------------------------ STEP3 运行期注册 ≠ 可选
	a.log("STEP3 运行期注册一株植物：注册 + 解锁 ≠ 可选")
	ModManager.set_mod_enabled(ModIds.DEBUG, false)
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

	# ------------------------------------------------ STEP4 登记一页之后才进选卡界面
	a.log("STEP4 自己登记一页选卡（第 1 格留空）→ 落位照模组排的版、待选区里有卡且可见")
	## 第 1 格写成空位：验证「排版归模组」—— 卡片必须落在模组指定的第 2 格，本体不往前补
	var page_handle: int = AllCards.register_plant_choose_page([PlantIds.NULL, plant_type])
	_check(a, "register_plant_choose_page() 登记成功", page_handle >= 0, str(kit.recipe))
	_check(a, "它进了可选植物列表", AllCards.is_selectable_plant(plant_type), "")
	ordered = AllCards.get_plant_types_in_choose_order()
	_check(a, "页里的卡片排在列表最后（空位不占列表项）",
		not ordered.is_empty() and ordered[ordered.size() - 1] == plant_type, str(ordered.size()))
	var slot3 := await _open_card_slot(a)
	if slot3 == null:
		AllCards.unregister_plant_choose_page(page_handle)
		kit.uninstall()
		_finish(a)
		return
	var candidate3 := slot3.get_node_or_null("CardSlotCandidate") as CardSlotCandidate
	var container3 := _container_of(candidate3, plant_type)
	_check(a, "待选区里有它的卡位且可见", container3 != null and container3.visible,
		"container=%s" % str(container3))
	if container3 != null:
		_check(a, "落在模组排的第 2 格（第 1 格留空，本体不往前补）",
			container3.get_parent().get_index() == 1, 
			"实际格位=%d" % container3.get_parent().get_index())
		var per_page: int = _per_page_from_scene()
		var base_count: int = AllCards.get_seed_chooser_catalog().plants.size()
		@warning_ignore("integer_division")
		var expected_page: int = base_count / per_page + (1 if base_count % per_page > 0 else 0)
		_check(a, "整页接在原版植物页之后（不混进第 1 页）",
			candidate3.all_card_page_array.find(container3.get_parent().get_parent()) == expected_page,
			"第 %d 页 / 期望第 %d 页" % [
				candidate3.all_card_page_array.find(container3.get_parent().get_parent()) + 1,
				expected_page + 1])
	slot3.free()

	# ------------------------------------------------ STEP5 卸载：页与卡位一起撤
	a.log("STEP5 卸载 → 卡位与登记的那一页一起撤掉")
	AllCards.unregister_plant_choose_page(page_handle)
	kit.uninstall()
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(plant_type), str(plant_type))
	_check(a, "那一页也摘掉了（它不再出现在可选植物列表里）",
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
## 这几株是不是都已解锁（curr_plant 里都有）
func _all_unlocked(state: GlobalGameState, plant_types: Array[StringName]) -> bool:
	for plant_type: StringName in plant_types:
		if not state.is_plant_unlocked(plant_type):
			return false
	return true


## 这几株里有没有一株算「可选」
func _any_selectable(plant_types: Array[StringName]) -> bool:
	for plant_type: StringName in plant_types:
		if AllCards.is_selectable_plant(plant_type):
			return true
	return false


## 列表里有没有这几株中的任意一株
func _has_any(ordered: Array[StringName], plant_types: Array[StringName]) -> bool:
	for plant_type: StringName in plant_types:
		if ordered.has(plant_type):
			return true
	return false


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
