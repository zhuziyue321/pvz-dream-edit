extends RefCounted
## 探针 PROBE6：冒险模式锁槽 + 紫卡/模仿者进商店 + 金钱/商店解锁
## 覆盖：
##   1. 冒险关卡 卡槽数 >= 拥有卡数 时按顺序固定选卡（锁定、不可取消）
##   2. 卡槽数 <  拥有卡数 时不锁定（保留玩家自由选择）
##   3. 金钱在 2-1 前不解锁且不掉落金币；商店在 3-4 前不解锁
##   4. 商店按扩展阶段上架紫卡/模仿者，购买后解锁植物并扣钱
##   5. 模仿者入口需要购买后才出现
## 机器可读汇总：最后一行 [CARDLOCK] result=PASS|FAIL failed=<n>

var _failed := 0
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure


func run(a) -> void:
	a.log("")
	a.log("========== PROBE6 冒险锁槽 / 商店 ==========")

	var state = Global.global_game_state
	## 新档：只有豌豆射手
	state.curr_plant.assign([CharacterRegistry.PlantType.P001PeaShooterSingle])
	state.curr_all_level_state_data = {}

	if not await _goto_level(a):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	await a.wait(4.0)

	# ------------------------------------------------ STEP1 1-1 锁槽
	var para = Global.main_game.game_para
	a.log("STEP1 关卡=%s 卡槽=%d 拥有卡数=%d" % [
		para.level_id, para.get_max_choosed_card_num(), state.curr_plant.size()])
	_check(a, "1-1 触发锁槽", para.is_locked_card_slot == true, str(para.is_locked_card_slot))
	var prechosen_ids: Array = para.prechosen_cards.map(func(r): return r.content_id)
	_check(a, "1-1 预选卡=拥有的卡", _first_n(prechosen_ids, state.curr_plant.size()) == state.curr_plant,
		str(prechosen_ids))
	var battle = Global.main_game.card_manager.card_slot_battle
	## 卡槽数由存档决定（基准 6 + 已购扩充）：1-1 只有 1 张已拥有卡，出战卡槽只填这一张，其余为空槽
	_check(a, "1-1 卡槽数=6", para.get_max_choosed_card_num() == 6, str(para.get_max_choosed_card_num()))
	_check(a, "1-1 出战卡槽只放已拥有的卡", battle.curr_cards.size() == state.curr_plant.size(),
		str(battle.curr_cards.size()))
	if battle.curr_cards.size() > 0:
		var c0 = battle.curr_cards[0]
		_check(a, "1-1 第 1 张是豌豆射手", c0.card_plant_type == CharacterRegistry.PlantType.P001PeaShooterSingle,
			str(c0.card_plant_type))
		## 预选卡没有连接点击信号 -> 点了也不会被取消（"固定"）
		c0._on_button_pressed()
		await a.wait(0.5)
		_check(a, "1-1 预选卡不可取消", battle.curr_cards.size() == state.curr_plant.size(),
			str(battle.curr_cards.size()))

	# ------------------------------------------------ STEP2 新档 金钱/商店 未解锁
	a.log("STEP2 新档解锁状态")
	_check(a, "新档金钱未解锁", not state.is_money_unlocked(), str(state.get_max_success_adventure_level()))
	_check(a, "新档商店未解锁", not state.is_shop_unlocked(), str(state.get_max_success_adventure_level()))
	_check(a, "新档商店扩展=0", state.get_shop_expand_stage() == 0, str(state.get_shop_expand_stage()))
	_check(a, "紫卡不在已解锁列表", not state.curr_plant.has(CharacterRegistry.PlantType.P041GatlingPea))
	_check(a, "模仿者不在已解锁列表", not state.curr_plant.has(CharacterRegistry.PlantType.P999Imitater))

	## 金钱未解锁时不应掉落金币
	var dim = Global.main_game.drop_item_manager.dim_coin
	if dim == null:
		_check(a, "找到 DIM_Coin 节点", false, "null")
	else:
		var before: int = dim.all_drop_coin_parent.get_child_count()
		EventBus.push_event("create_coin", [[1.0, 0.0, 0.0], Vector2(300, 300)])
		await a.wait(1.0)
		var after: int = dim.all_drop_coin_parent.get_child_count()
		_check(a, "金钱未解锁时不掉金币", after == before, str(before) + " -> " + str(after))

	# ------------------------------------------------ STEP3 推进到 3-4
	a.log("STEP3 模拟通关到 3-4（关卡序号 24）")
	_mark_cleared(state, 24)
	_check(a, "已通关序号=24", state.get_max_success_adventure_level() == 24,
		str(state.get_max_success_adventure_level()))
	_check(a, "3-4 后金钱已解锁", state.is_money_unlocked())
	_check(a, "3-4 后商店已解锁", state.is_shop_unlocked())
	_check(a, "3-4 刚解锁商店,扩展=0", state.get_shop_expand_stage() == 0, str(state.get_shop_expand_stage()))
	_check(a, "下一次扩展关卡=4-4", ConstUnlockLevel.get_next_shop_expand_level(24) == 34,
		str(ConstUnlockLevel.get_next_shop_expand_level(24)))
	_check(a, "关卡名反解 34->4-4", ConstUnlockLevel.get_adventure_level_name(34) == "4-4",
		ConstUnlockLevel.get_adventure_level_name(34))
	_check(a, "3-4 上架机枪射手", state.is_purple_card_can_buy(CharacterRegistry.PlantType.P041GatlingPea))
	_check(a, "3-4 未上架玉米加农炮", not state.is_purple_card_can_buy(CharacterRegistry.PlantType.P048CobCannon))
	_check(a, "3-4 未上架模仿者", not state.is_purple_card_can_buy(CharacterRegistry.PlantType.P999Imitater))
	_check(a, "关卡名反解 24->3-4", ConstUnlockLevel.get_adventure_level_name(24) == "3-4",
		ConstUnlockLevel.get_adventure_level_name(24))

	# ------------------------------------------------ STEP4 商店商品
	a.log("STEP4 进入商店")
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Store])
	if not await a.wait_scene("store", 12.0):
		a.log("!! 进不了商店")
		_finish(a)
		return
	await a.wait(2.0)
	var store: Node = a.get_node_or_null("/root/Store")
	if store == null:
		_check(a, "找到商店根节点", false, "null")
		_finish(a)
		return
	## 紫卡与模仿者按「一行为一页」分三行摆放
	var rows: Array = store.plant_card_rows
	_check(a, "找到紫卡商品行", rows != null and rows.size() > 0, str(rows))
	var goods_kids: Array[Node] = []
	for row in rows:
		goods_kids.append_array(row.get_children())
	_check(a, "商店生成 9 个植物卡商品", goods_kids.size() == 9, str(goods_kids.size()))

	var g_041 = _find_goods(goods_kids, CharacterRegistry.PlantType.P041GatlingPea)
	var g_048 = _find_goods(goods_kids, CharacterRegistry.PlantType.P048CobCannon)
	var g_999 = _find_goods(goods_kids, CharacterRegistry.PlantType.P999Imitater)
	_check(a, "机枪射手商品已上架", g_041 != null and g_041.visible and g_041.is_on_sale())
	_check(a, "玉米加农炮未上架(隐藏)", g_048 != null and not g_048.visible)
	_check(a, "模仿者未上架(隐藏)", g_999 != null and not g_999.visible)
	if g_041 != null:
		_check(a, "机枪射手售价 5000", g_041.price == 5000, str(g_041.price))

	## 翻页：一页两行（4 格 ×2）；3-4 时货架只有第一页，禅境花园页还没上架
	_check(a, "3-4 时货架只有 1 页", store.get_page_num() == 1, str(store.get_page_num()))
	_check(a, "第一页同时显示道具行与第一批紫卡行",
		store.row_tools.visible and store.row_upgrade_first.visible)
	_check(a, "3-4 时禅境花园页还没上架",
		not store.get_node("Bg/Car2/Panel/RowGarden").visible)

	# ------------------------------------------------ STEP5 购买
	a.log("STEP5 购买机枪射手")
	state.coin_value = 20000
	if g_041 != null:
		g_041.comfirm_get_this_goods()
		await a.wait(0.5)
	_check(a, "购买后解锁机枪射手", state.curr_plant.has(CharacterRegistry.PlantType.P041GatlingPea))
	_check(a, "购买后扣除 5000", state.coin_value == 15000, str(state.coin_value))
	if g_041 != null:
		_check(a, "已购买的商品标记已拥有", not g_041.is_have_goods)

	# ------------------------------------------------ STEP6 反例：槽数不够时不锁
	a.log("STEP6 拥有 7 张卡进 1-2（卡槽 6）")
	state.curr_plant.assign([
		CharacterRegistry.PlantType.P001PeaShooterSingle,
		CharacterRegistry.PlantType.P002SunFlower,
		CharacterRegistry.PlantType.P003CherryBomb,
		CharacterRegistry.PlantType.P004WallNut,
		CharacterRegistry.PlantType.P005PotatoMine,
		CharacterRegistry.PlantType.P006SnowPea,
		CharacterRegistry.PlantType.P007Chomper,
	])
	var p2 = (load("res://src/levels/mode_adventure/adventure_01_02.gd") as GDScript).new()
	p2.set_choose_level(ADV, 0, "0002")
	Global.game_para = p2
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront])
	await a.wait(3.0)
	var para2 = Global.main_game.game_para
	a.log("  1-2 卡槽=%d 拥有卡数=%d" % [para2.get_max_choosed_card_num(), state.curr_plant.size()])
	_check(a, "槽数<拥有卡数时不锁槽", para2.is_locked_card_slot == false, str(para2.is_locked_card_slot))
	_check(a, "槽数<拥有卡数时无预选卡(玩家自由选卡)",
		para2.get_valid_pre_choosed_card_num() == 0, str(para2.get_valid_pre_choosed_card_num()))
	_check(a, "槽数<拥有卡数时不跳过选卡", not para2.is_no_choose_permission())

	# ------------------------------------------------ STEP7 通关 5-10 后的商店扩展
	a.log("STEP7 模拟通关冒险模式（5-10，序号 50）")
	_mark_cleared(state, 50)
	_check(a, "5-10 后商店扩展=3", state.get_shop_expand_stage() == 3, str(state.get_shop_expand_stage()))
	_check(a, "5-10 上架玉米加农炮", state.is_purple_card_can_buy(CharacterRegistry.PlantType.P048CobCannon))
	_check(a, "5-10 上架模仿者", state.is_purple_card_can_buy(CharacterRegistry.PlantType.P999Imitater))
	_check(a, "全部扩展完后无下一批", ConstUnlockLevel.get_next_shop_expand_level(50) == -1,
		str(ConstUnlockLevel.get_next_shop_expand_level(50)))

	# ------------------------------------------------ STEP8 模仿者入口显隐
	a.log("STEP8 模仿者入口显隐")
	var seed_candidate = Global.main_game.card_manager.card_slot_norm.card_slot_candidate
	if seed_candidate == null:
		_check(a, "找到待选卡槽", false, "null")
	else:
		_check(a, "未购买模仿者时入口隐藏", seed_candidate.imitater_bg.visible == false,
			str(seed_candidate.imitater_bg.visible))
		state.unlock_plant(CharacterRegistry.PlantType.P999Imitater)
		_check(a, "购买模仿者后已解锁", state.is_plant_unlocked(CharacterRegistry.PlantType.P999Imitater))
		## 重新进关卡验证入口显示
		var p3 = (load("res://src/levels/mode_adventure/adventure_01_02.gd") as GDScript).new()
		p3.set_choose_level(ADV, 0, "0002")
		Global.game_para = p3
		a.get_tree().change_scene_to_file(
			Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront])
		await a.wait(3.0)
		var cand2 = Global.main_game.card_manager.card_slot_norm.card_slot_candidate
		if cand2 == null:
			_check(a, "重新进关卡后找到待选卡槽", false, "null")
		else:
			_check(a, "购买模仿者后入口显示", cand2.imitater_bg.visible == true, str(cand2.imitater_bg.visible))

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
	a.log("[CARDLOCK] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _first_n(arr: Array, n: int) -> Array:
	var out: Array = []
	for i in range(mini(n, arr.size())):
		out.append(arr[i])
	return out


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}


func _find_goods(kids: Array, plant_type) -> Node:
	for k in kids:
		if "plant_type" in k and k.plant_type == plant_type:
			return k
	return null


func _find_dim_coin(root: Node) -> Node:
	return _find_node_of_class(root, "DIM_Coin")


func _find_node_of_class(root: Node, cls: String) -> Node:
	for c in root.get_children():
		if c.get_class() == cls or c.is_class(cls):
			return c
		var r := _find_node_of_class(c, cls)
		if r != null:
			return r
	return null


## 启动 -> 冒险模式 -> 第 1 关
func _goto_level(a) -> bool:
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)
	await a.click_first("Menu/Button1")
	if not await a.wait_scene("choose_level", 12.0):
		return false
	var gcl: Node = a.get_node_or_null("/root/ChooseLevel/AllPage/GridContainer")
	if gcl == null:
		return false
	await a.press_first("ChooseLevelButton/TextureButton")
	return await a.wait_scene("main_game", 10.0)
#endregion
