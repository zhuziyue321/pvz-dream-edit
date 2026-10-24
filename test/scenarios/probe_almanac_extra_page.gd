extends RefCounted
## 探针：图鉴「扩展植物」页（运行期解锁的植物 + 模组新增植物）
##
## 覆盖这一页的三件事：
##   1. 场景能造出来，索引页上有「查看扩展植物」按钮，点它切到这一页
##   2. **哪些植物进这一页**：与选卡界面同一口径（AllCards.is_appended_plant），
##      且按 curr_plant（已解锁）过滤 —— 没解锁 / 没登记进可选列表时一株都没有
##      （调试模组只解锁、不登记 ⇒ 打开它这一页仍是空的）
##   3. **图鉴文本从哪来**：本体那四株取 json 的 ExtraPlant 段；没写过的（含模组植物）
##      兜一条最简条目；模组登记 / 摘掉自己的条目
##
## 无头可跑（模组开关会写模组存档，跑批把用户目录重定向到临时目录）。
## 机器可读汇总：最后一行 [ALMANACEXTRA] result=PASS|FAIL failed=<n>

var _failed := 0

## 图鉴场景路径（照 MainSceneRegistry 取，别写死）
const ALMANAC_BTN := "StartPage/Panel3/ExtraPlantButton"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：图鉴扩展植物页 ==========")

	var scene_path := Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.Almanac)
	_check(a, "图鉴场景路径能取到", scene_path != "", scene_path)

	# ------------------------------------------------ STEP1 没解锁时是空页
	a.log("STEP1 默认（调试模组关着、没装别的模组）→ 这一页是空的")
	ModManager.set_mod_enabled(ModIds.DEBUG, false)
	var page1: AlmanacExtraPlantPage = await _open_page(a, scene_path)
	if page1 == null:
		_finish(a)
		return
	var root1 := page1.get_parent()
	_check(a, "索引页上有「查看扩展植物」按钮",
		root1.get_node_or_null(NodePath(ALMANAC_BTN)) != null, ALMANAC_BTN)
	_check(a, "没解锁任何扩展植物 → 卡片数为 0", page1.extra_plant_types.is_empty(),
		str(page1.extra_plant_types))
	_check(a, "没解锁时面板给的是提示条目（不是空白）",
		page1.almanac_character_show_panel.character_text_1.text != "",
		page1.almanac_character_show_panel.character_text_1.text)
	root1.free()

	# ------------------------------------------------ STEP2 开调试模组 → 仍不进页
	a.log("STEP2 打开「调试模式」→ 四株只进已解锁名单；不在可选植物列表 ⇒ 这一页仍为空")
	ModManager.set_mod_enabled(ModIds.DEBUG, true)
	var page_mode: AlmanacExtraPlantPage = await _open_page(a, scene_path)
	if page_mode == null:
		_finish(a)
		return
	_check(a, "调试模式下扩展页仍没有卡片（调试模式不登记选卡界面）",
		page_mode.extra_plant_types.is_empty(), str(page_mode.extra_plant_types))
	page_mode.get_parent().free()
	ModManager.set_mod_enabled(ModIds.DEBUG, false)

	# ------------------------------------------------ STEP2.5 登记一页 → 四株进页
	a.log("STEP2.5 手动登记一页选卡（模组那条路）→ 四株进页")
	var state := Global.global_game_state
	state.unlock_plants(ConstPlantUnlock.APPENDED_PLANT_TYPES)
	var debug_page := AllCards.register_plant_choose_page(ConstPlantUnlock.APPENDED_PLANT_TYPES)
	_check(a, "登记一页选卡成功", debug_page >= 0, str(debug_page))
	var page2: AlmanacExtraPlantPage = await _open_page(a, scene_path)
	if page2 == null:
		_finish(a)
		return
	var root2 := page2.get_parent()
	_check(a, "四种调试植物全部进页",
		page2.extra_plant_types.size() == ConstPlantUnlock.APPENDED_PLANT_TYPES.size(),
		str(page2.extra_plant_types))
	_check(a, "普通植物不进这一页（豌豆射手不在扩展页里）",
		not page2.extra_plant_types.has(PlantIds.PEA_SHOOTER_SINGLE),
		str(page2.extra_plant_types))
	## 顺序照选卡界面：扩展页里的相对先后与 AllCards 的排列顺序一致
	var ordered := AllCards.get_plant_types_in_choose_order()
	var last_index := -1
	var in_order := true
	for plant_type: StringName in page2.extra_plant_types:
		var i := ordered.find(plant_type)
		if i <= last_index:
			in_order = false
		last_index = i
	_check(a, "顺序与选卡界面一致", in_order, str(page2.extra_plant_types))

	# ------------------------------------------------ STEP3 点卡片出图鉴文本
	a.log("STEP3 点开卡片：正文取自 ExtraPlant 段")
	var cards := page2.card_grid_container.get_children()
	_check(a, "卡片挂进了网格容器", cards.size() == page2.extra_plant_types.size(),
		"卡片 %d 张 / 植物 %d 株" % [cards.size(), page2.extra_plant_types.size()])
	for plant_type: StringName in page2.extra_plant_types:
		var entry := Global.global_read_data.get_extra_almanac_entry(plant_type)
		_check(a, "%s 有图鉴条目" % plant_type, not entry.is_empty(), str(entry))
		_check(a, "%s 有中文名" % plant_type, str(entry.get("名字", "")) != "",
			str(entry.get("名字", "")))
		_check(a, "%s 有简介" % plant_type, str(entry.get("简介", "")) != "", "")
	## 真的点一张卡，面板要换成那一株
	if not page2.extra_plant_types.is_empty():
		page2.almanac_character_show_panel.almanac_update_extra_plant_panel(
			page2.extra_plant_types[0])
		var shown: String = page2.almanac_character_show_panel.character_name.text
		var expect: String = str(Global.global_read_data.get_extra_almanac_entry(
			page2.extra_plant_types[0]).get("名字", ""))
		_check(a, "点卡片后面板换成那一株", shown == expect, "显示=%s 期望=%s" % [shown, expect])
	root2.free()
	## 撤销手动登记，别把状态留给后面的步骤
	AllCards.unregister_plant_choose_page(debug_page)
	for plant_type: StringName in ConstPlantUnlock.APPENDED_PLANT_TYPES:
		state.lock_plant(plant_type)

	# ------------------------------------------------ STEP4 模组登记 / 摘掉
	a.log("STEP4 模组自己登记条目（水盆那一路）")
	## 借一株本体植物当「模组植物」来试登记 / 摘掉：探针不真的造植物，
	## 用没登记过的 id 会让注册表打一串 error（污染 stderr）
	var mod_plant := PlantIds.PEA_SHOOTER_SINGLE
	const MOD_NAME := "临时模组植物"
	_check(a, "没登记时取到的是兜底条目（不报错、不为空）",
		not Global.global_read_data.get_extra_almanac_entry(mod_plant).is_empty(), "")
	_check(a, "没登记时不是模组那条",
		str(Global.global_read_data.get_extra_almanac_entry(mod_plant).get("名字", "")) != MOD_NAME,
		str(Global.global_read_data.get_extra_almanac_entry(mod_plant).get("名字", "")))
	Global.global_read_data.register_extra_almanac_entry(mod_plant, {
		"名字": MOD_NAME, "描述": "探针造的", "参数": {"a": "b"},
		"简介": "探针造的", "背景": "Pool"})
	_check(a, "登记后取到的是模组那条",
		str(Global.global_read_data.get_extra_almanac_entry(mod_plant).get("名字", "")) == MOD_NAME,
		str(Global.global_read_data.get_extra_almanac_entry(mod_plant)))
	Global.global_read_data.clear_extra_almanac_entry(mod_plant)
	_check(a, "摘掉后回到兜底条目",
		str(Global.global_read_data.get_extra_almanac_entry(mod_plant).get("名字", "")) != MOD_NAME,
		str(Global.global_read_data.get_extra_almanac_entry(mod_plant).get("名字", "")))

	_finish(a)


## 造一个图鉴场景，返回里面的扩展植物页（失败返回 null）
func _open_page(a, scene_path: String) -> AlmanacExtraPlantPage:
	var scene: PackedScene = load(scene_path)
	if scene == null:
		_check(a, "图鉴场景能 load", false, scene_path)
		return null
	var root: Control = scene.instantiate()
	a.get_tree().root.add_child(root)
	await a.frames(2)
	var page := root.get_node_or_null("ExtraPlantPage") as AlmanacExtraPlantPage
	if page == null:
		_check(a, "图鉴里有 ExtraPlantPage", false, "取不到 /root/.../ExtraPlantPage")
		return null
	_check(a, "扩展植物页有卡片网格容器", page.card_grid_container != null, "")
	_check(a, "扩展植物页有展示面板", page.almanac_character_show_panel != null, "")
	return page


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[ALMANACEXTRA] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
