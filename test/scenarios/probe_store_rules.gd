extends RefCounted
## 探针：商店购买规则对齐原版
## 覆盖：
##   1. 花园背景类（蘑菇园 / 水族馆）买一次即售罄，不能重复购买；购买 = 解锁背景（0 页 -> 1 页）
##   2. 智慧树售价 $10000 且买一次即售罄
##   3. 金盏花幼苗 $2500 且每个盆槽位每天只能买一次（一天最多 3 个）；花园没空位时也禁售
##   4. 商店里不再出售温室（原版只卖蘑菇园 / 水族馆）
##   5. 货架分页：一页 8 格分两行；卡槽排在第一页第一行首位，蘑菇园 / 水族馆 / 蜗牛 / 智慧树排在最后一页第一行（详见 STEP6）
##   6. 第三页：3 个植物盆 + 黄金水壶 / 肥料 / 杀虫剂 / 留声机 / 园艺手套（详见 STEP7）
##   6. 禅境花园类商品统一要求「花园已解锁」（原版同属 Zen Garden 段）
## 机器可读汇总：最后一行 [STORERULES] result=PASS|FAIL failed=<n>

var _failed := 0

const STORE_SCENE := "res://src/store/store.tscn"
## 商店禅境花园页的商品节点（货架 Row* 容器见 store.tscn，一页两行）
const PATH_MUSHROOM := "Bg/Car2/Panel/RowGarden/Goods2"
const PATH_AQUARIUM := "Bg/Car2/Panel/RowGarden/Goods3"
const PATH_TREE := "Bg/Car2/Panel/RowGarden/Goods4"
const PATH_SPROUT := "Bg/Car2/Panel/RowGardenSprout/Goods1"


func run(a) -> void:
	a.log("")
	a.log("========== 探针 商店购买规则（对齐原版） ==========")
	await a.wait(2.0)

	var state = Global.global_game_state
	## 通关到 5-10（序号 50）：商店解锁、花园解锁、紫卡全部上架
	_mark_cleared(state, 50)
	## 花园数据复位成「什么都没买过」:蘑菇园 / 水族馆 0 页 = 尚未拥有
	state.garden_data = {"num_bg_page_0": 1, "num_bg_page_1": 0, "num_bg_page_2": 0}
	state.curr_num_new_garden_plant = 0
	state.coin_value = 1000000

	a.log("STEP1 进入商店")
	a.get_tree().change_scene_to_file(STORE_SCENE)
	if not await a.wait_scene("store", 15.0):
		_check(a, "进入商店", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(2.0)

	var store: Node = a.get_tree().current_scene
	var g_mushroom := store.get_node_or_null(PATH_MUSHROOM)
	var g_aquarium := store.get_node_or_null(PATH_AQUARIUM)
	var g_tree := store.get_node_or_null(PATH_TREE)
	var g_sprout := store.get_node_or_null(PATH_SPROUT)
	_check(a, "找到蘑菇园商品", g_mushroom != null, str(g_mushroom))
	_check(a, "找到水族馆商品", g_aquarium != null, str(g_aquarium))
	_check(a, "找到智慧树商品", g_tree != null, str(g_tree))
	_check(a, "找到金盏花幼苗商品", g_sprout != null, str(g_sprout))
	if g_mushroom == null or g_aquarium == null or g_tree == null or g_sprout == null:
		_finish(a)
		return

	# ------------------------------------------------ STEP2 售价
	a.log("STEP2 售价")
	_check(a, "蘑菇园 $30000", g_mushroom.price == 30000, str(g_mushroom.price))
	_check(a, "水族馆 $30000", g_aquarium.price == 30000, str(g_aquarium.price))
	_check(a, "智慧树 $10000", g_tree.price == 10000, str(g_tree.price))
	_check(a, "金盏花幼苗 $2500", g_sprout.price == 2500, str(g_sprout.price))
	_check(a, "温室不再是商品（花园行只有 3 件）",
		store.get_node("Bg/Car2/Panel/RowGarden").get_child_count() == 3,
		str(store.get_node("Bg/Car2/Panel/RowGarden").get_child_count()))

	# ------------------------------------------------ STEP3 花园背景买完售罄
	a.log("STEP3 蘑菇园 / 水族馆买一次即售罄")
	_check(a, "蘑菇园初始可购买", g_mushroom.is_have_goods and not g_mushroom.button.disabled)
	var before_coin: int = state.coin_value
	g_mushroom.comfirm_get_this_goods()
	_check(a, "买蘑菇园扣了 $30000", state.coin_value == before_coin - 30000,
		str(before_coin) + " -> " + str(state.coin_value))
	_check(a, "蘑菇园 未拥有 -> 拥有 1 页", int(state.garden_data.get("num_bg_page_1", 0)) == 1,
		str(state.garden_data.get("num_bg_page_1", 0)))
	_check(a, "蘑菇园已拥有", state.is_garden_bg_owned(GardenManager.E_GardenBgType.MushroomGraden))
	_check(a, "蘑菇园已售罄", not g_mushroom.is_have_goods)
	_check(a, "蘑菇园按钮已禁用", g_mushroom.button.disabled)
	_check(a, "水族馆仍未拥有", not state.is_garden_bg_owned(GardenManager.E_GardenBgType.Aquarium))

	var coin_after: int = state.coin_value
	g_mushroom.comfirm_get_this_goods()
	_check(a, "重复点蘑菇园不再扣钱", state.coin_value == coin_after, str(state.coin_value))

	# ------------------------------------------------ STEP4 智慧树买完售罄
	a.log("STEP4 智慧树买一次即售罄")
	_check(a, "智慧树初始可购买", g_tree.is_have_goods and not g_tree.button.disabled)
	g_tree.comfirm_get_this_goods()
	_check(a, "智慧树已售罄", not g_tree.is_have_goods)
	_check(a, "智慧树按钮已禁用", g_tree.button.disabled)
	_check(a, "智慧树已落库存档",
		bool(state.garden_data.get(ConstShop.TREE_OF_WISDOM_BOUGHT_KEY, false)))

	# ------------------------------------------------ STEP5 每个植物盆槽位每天限购 1 次
	a.log("STEP5 每个植物盆槽位每天限购 1 次")
	var all_sprouts: Array[GoodsGardenSrpout] = []
	var sprout_row := store.get_node("Bg/Car2/Panel/RowGardenSprout")
	for child in sprout_row.get_children():
		if child is GoodsGardenSrpout:
			all_sprouts.append(child as GoodsGardenSrpout)
	g_sprout = all_sprouts[0]
	_check(a, "货架上摆 %d 个植物盆" % ConstShop.MARIGOLD_SPROUT_DAILY_LIMIT,
		all_sprouts.size() == ConstShop.MARIGOLD_SPROUT_DAILY_LIMIT, str(all_sprouts.size()))
	_check(a, "幼苗初始可购买", not g_sprout.button.disabled)

	## 同一个盆当天只能买一次：买过即售罄，再点不再扣钱
	var sprout_coin: int = state.coin_value
	g_sprout.comfirm_get_this_goods()
	_check(a, "买到第 1 株待放置植物", state.curr_num_new_garden_plant == 1,
		str(state.curr_num_new_garden_plant))
	_check(a, "买盆扣了 $2500", state.coin_value == sprout_coin - 2500, str(state.coin_value))
	_check(a, "买过的盆当天售罄", not g_sprout.is_have_goods and g_sprout.button.disabled)
	g_sprout.comfirm_get_this_goods()
	_check(a, "同一个盆当天重复买不再扣钱", state.coin_value == sprout_coin - 2500,
		str(state.coin_value))

	## 其余盆各自独立：三个盆各买一次 = 一天最多 3 株
	for i in range(1, all_sprouts.size()):
		_check(a, "第 %d 个盆仍可购买" % (i + 1), not all_sprouts[i].button.disabled)
		all_sprouts[i].comfirm_get_this_goods()
	_check(a, "三个盆各买一次共 %d 株" % ConstShop.MARIGOLD_SPROUT_DAILY_LIMIT,
		state.curr_num_new_garden_plant == ConstShop.MARIGOLD_SPROUT_DAILY_LIMIT,
		str(state.curr_num_new_garden_plant))
	_check(a, "所有盆当天都售罄", all_sprouts.all(func(g): return g.button.disabled))

	## 模拟跨天：把各槽位记录的日期都改成昨天，应恢复可购买
	var slot_buy_date: Dictionary = state.garden_data.get(
		ConstShop.MARIGOLD_SPROUT_SLOT_BUY_DATE_KEY, {}) as Dictionary
	for slot_key in slot_buy_date.keys():
		slot_buy_date[slot_key] = "2000-01-01"
	state.garden_data[ConstShop.MARIGOLD_SPROUT_SLOT_BUY_DATE_KEY] = slot_buy_date
	g_sprout.judge_can_get_goods()
	_check(a, "跨天后恢复可购买", not g_sprout.button.disabled)

	## 原版：花园满了就不卖幼苗，卖掉植物腾出空位后才恢复
	_fill_all_garden_cells(state)
	g_sprout.judge_can_get_goods()
	_check(a, "花园满了后幼苗禁售", g_sprout.button.disabled)
	state.garden_data.erase("第0类背景")
	state.garden_data.erase("第1类背景")
	g_sprout.judge_can_get_goods()
	_check(a, "腾出空位后幼苗恢复可购买", not g_sprout.button.disabled)

	# ------------------------------------------------ STEP6 货架分页（一页 8 格＝上下两行）
	a.log("STEP6 货架分页（一页 8 格，上下两行）")
	var first_row := store.get_node("Bg/Car2/Panel/RowTools")
	var first_page_second_row := store.get_node("Bg/Car2/Panel/RowUpgradeFirst")
	var last_page := store.get_node("Bg/Car2/Panel/RowGarden")
	_check(a, "卡槽排在第一页第一行首位",
		first_row.get_child_count() > 0 and first_row.get_child(0) is GoodsCardSlot,
		str(first_row.get_child(0) if first_row.get_child_count() > 0 else null))
	## 通关 5-10 后: 道具+第一批紫卡 / 第二批紫卡+模仿者 / 植物盆+工具 / 禅境花园+巧克力, 共 4 页
	_check(a, "通关 5-10 后放出 4 页", store.get_page_num() == 4, str(store.get_page_num()))
	_check(a, "默认显示第一页（道具行 + 第一批紫卡行）",
		first_row.visible and first_page_second_row.visible and not last_page.visible)
	store._on_prev_page_button_pressed()
	_check(a, "第一页往前翻到最后一页（禅境花园行）",
		not first_row.visible and last_page.visible)
	store._on_next_page_button_pressed()
	_check(a, "最后一页往后翻回第一页",
		first_row.visible and first_page_second_row.visible and not last_page.visible)
	## 原版第四页第一行: 蘑菇园 → 水族馆 → 蜗牛 → 智慧树
	_check(a, "第四页第一行摆 4 件", last_page.get_child_count() == 4, str(last_page.get_child_count()))
	var snail_goods := last_page.get_child(2) as GoodsGardenTool
	_check(a, "第 3 格是蜗牛",
		snail_goods != null and snail_goods.garden_tool == GardenManager.E_GardenTool.Snail,
		str(snail_goods))
	_check(a, "蜗牛买断 $3000", snail_goods != null and snail_goods.price == 3000,
		str(snail_goods.price if snail_goods != null else null))
	## 巧克力不从商店购买(只有花园掉落),货架上不该有它
	_check(a, "商店里不出售巧克力",
		not all_goods_has_tool(store.all_goods, GardenManager.E_GardenTool.Chocolate))

	# ------------------------------------------------ STEP7 第三页花园工具
	a.log("STEP7 第三页：3 个植物盆 + 黄金水壶 / 花园工具四件")
	var tool_row := store.get_node("Bg/Car2/Panel/RowGardenTools")
	## 原版货架顺序: 植物盆 ×3 → 黄金水壶(sprout_row 见 STEP5)
	_check(a, "第一行摆 3 个植物盆 + 黄金水壶", sprout_row.get_child_count() == 4,
		str(sprout_row.get_child_count()))
	_check(a, "前 3 格都是植物盆",
		sprout_row.get_child(0) is GoodsGardenSrpout
		and sprout_row.get_child(1) is GoodsGardenSrpout
		and sprout_row.get_child(2) is GoodsGardenSrpout,
		str(sprout_row.get_child(0)))
	## 三个盆各编一个槽位序号,限购按槽位独立判定
	_check(a, "三个盆的槽位序号各不相同",
		all_sprouts[0].slot_index != all_sprouts[1].slot_index
		and all_sprouts[1].slot_index != all_sprouts[2].slot_index
		and all_sprouts[0].slot_index != all_sprouts[2].slot_index,
		str(all_sprouts.map(func(g): return g.slot_index)))
	_check(a, "第 4 格是黄金水壶商品", sprout_row.get_child(3) is GoodsGardenTool)
	_check(a, "第二行摆 4 件花园工具", tool_row.get_child_count() == 4, str(tool_row.get_child_count()))
	_check(a, "肥料一份 $750", tool_row.get_child(0).price == 750, str(tool_row.get_child(0).price))
	_check(a, "杀虫剂一份 $1000", tool_row.get_child(1).price == 1000, str(tool_row.get_child(1).price))
	_check(a, "留声机 $15000", tool_row.get_child(2).price == 15000, str(tool_row.get_child(2).price))
	_check(a, "园艺手套 $1000", tool_row.get_child(3).price == 1000, str(tool_row.get_child(3).price))

	# ------------------------------------------------ STEP7 禅境花园段的「花园已解锁」门槛
	a.log("STEP7 花园未解锁时禅境花园类商品禁售")
	_mark_cleared(state, 44)  ## 通关到 5-4：商店已解锁，花园还没解锁
	g_aquarium.judge_can_get_goods()
	g_sprout.judge_can_get_goods()
	_check(a, "花园未解锁时水族馆禁售", g_aquarium.button.disabled)
	_check(a, "花园未解锁时金盏花幼苗禁售", g_sprout.button.disabled)
	_mark_cleared(state, 50)  ## 回到通关状态
	g_aquarium.judge_can_get_goods()
	g_sprout.judge_can_get_goods()
	_check(a, "花园解锁后水族馆恢复可购买", not g_aquarium.button.disabled)
	_check(a, "花园解锁后金盏花幼苗恢复可购买", not g_sprout.button.disabled)

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
	a.log("[STORERULES] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 货架上有没有卖某件花园工具的商品(巧克力不从商店出售,只能靠花园掉落)
func all_goods_has_tool(all_goods: Array, tool_type: GardenManager.E_GardenTool) -> bool:
	for goods in all_goods:
		var garden_tool_goods := goods as GoodsGardenTool
		if garden_tool_goods != null and garden_tool_goods.garden_tool == tool_type:
			return true
	return false


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}


## 把已拥有的每个花园背景的每一页格子全部占满，模拟原版「Zen Garden is full」
func _fill_all_garden_cells(state) -> void:
	var full_cell := {"curr_plant_type": CharacterRegistry.PlantType.P001PeaShooterSingle}
	for bg_type in state.get_owned_garden_bg_types():
		var cell_num := GardenManager.get_plant_cell_num_per_page(bg_type)
		var bg_data := {}
		for page in range(state.get_garden_bg_page_num(bg_type)):
			var page_data := {}
			for i in range(cell_num):
				page_data["第" + str(i) + "个植物格子"] = full_cell
			bg_data["第" + str(page) + "页"] = page_data
		state.garden_data["第" + str(int(bg_type)) + "类背景"] = bg_data
#endregion
