extends RefCounted
## 探针：坚果包扎术（Wall-nut First Aid）与商店模仿者图标
## 覆盖：
##   1. 常量：售价 $2000；可修复植物 = 坚果 / 高坚果 / 南瓜头，大蒜 / 地刺王不在其中
##   2. 商店：通关冒险模式后坚果包扎术上架（$2000），买下后 Sold Out 且写进存档
##   3. 商店：模仿者商品有静态形象（图标不再是空白）
##   4. 关卡：坚果掉手 / 裂开后 get_first_aid_plant() 命中，be_first_aid_heal() 回满血并复原外观
##   5. 反例：没买包扎术 / 外观完好 / 植物类型不符 —— 都不能补种
## 机器可读汇总：最后一行 [FIRSTAID] result=PASS|FAIL failed=<n>

const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_01_01 := "res://src/levels/mode_adventure/adventure_01_01.gd"
const STORE_SCENE := "res://src/store/store.tscn"
const P004 := CharacterRegistry.PlantType.P004WallNut
const P024 := CharacterRegistry.PlantType.P024TallNut
const P031 := CharacterRegistry.PlantType.P031Pumpkin
const P047 := CharacterRegistry.PlantType.P047SpikeRock
const P999 := CharacterRegistry.PlantType.P999Imitater

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 坚果包扎术 / 模仿者图标 ==========")
	await a.wait(2.0)

	var state = Global.global_game_state
	## 通关冒险模式（5-10 = 50）+ 给够钱，商店第二页与坚果包扎术才上架
	_mark_cleared(state, 50)
	state.coin_value = 999999
	for plant_type in [P004, P024, P031]:
		state.unlock_plant(plant_type)

	# ------------------------------------------------ STEP0 常量
	a.log("STEP0 常量")
	_check(a, "售价 $2000", ConstShop.WALL_NUT_FIRST_AID_PRICE == 2000,
		str(ConstShop.WALL_NUT_FIRST_AID_PRICE))
	_check(a, "坚果可修复", ConstShop.is_first_aid_plant(P004))
	_check(a, "高坚果可修复", ConstShop.is_first_aid_plant(P024))
	_check(a, "南瓜头可修复", ConstShop.is_first_aid_plant(P031))
	_check(a, "地刺王不可修复(原版: 非防御植物)", not ConstShop.is_first_aid_plant(P047))
	_check(a, "模仿者不可修复", not ConstShop.is_first_aid_plant(P999))

	# ------------------------------------------------ STEP1 商店上架与购买
	a.log("STEP1 商店")
	state.is_wall_nut_first_aid_bought = false
	a.get_tree().change_scene_to_file(STORE_SCENE)
	if not await a.wait_scene("store", 15.0):
		_check(a, "进入商店", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(2.0)

	var store: Node = a.get_node_or_null("/root/Store")
	if store == null:
		_check(a, "找到商店根节点", false, "null")
		_finish(a)
		return

	var goods = store.goods_wall_nut_first_aid
	if goods == null:
		_check(a, "货架上摆了坚果包扎术", false, "null")
		_finish(a)
		return
	_check(a, "通关后坚果包扎术上架(可见)", goods.visible, str(goods.visible))
	_check(a, "坚果包扎术售价 $2000", goods.price == 2000, str(goods.price))
	_check(a, "排在模仿者之后(行内最后一个)",
		goods.get_index() == goods.get_parent().get_child_count() - 1,
		str(goods.get_index()))

	## 模仿者图标：GoodsPlantCard 是种子包样式的商品图标，模仿者此前取不到卡片 -> 种子包里没有植物
	var imitater_goods = null
	for row in store.plant_card_rows:
		for ch in row.get_children():
			if "plant_type" in ch and ch.plant_type == P999:
				imitater_goods = ch
	if imitater_goods == null:
		_check(a, "货架上有模仿者商品", false, "null")
	else:
		## 商品图标现在直接复用出战卡片 Card,不再手工拼底图 + 静态形象
		var icon_container: Node = imitater_goods.seed_packet_icon
		var icon_card: Card = null
		if icon_container.get_child_count() > 0:
			icon_card = icon_container.get_child(0) as Card
		var has_icon := icon_card != null and icon_card.character_static.get_child_count() > 0
		_check(a, "模仿者商品种子包里有静态形象", has_icon,
			str(icon_card.character_static.get_children() if icon_card != null else "null"))
		_check(a, "图标卡片不接鼠标事件(不挡商品按钮)",
			icon_card != null and icon_card.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			str(icon_card.mouse_filter if icon_card != null else "null"))

	## 真的买一次
	var coin_before: int = state.coin_value
	goods.comfirm_get_this_goods()
	await a.wait(0.5)
	_check(a, "购买后已拥有", state.is_wall_nut_first_aid_owned(),
		str(state.is_wall_nut_first_aid_bought))
	_check(a, "扣了 $2000", state.coin_value == coin_before - 2000,
		str(coin_before) + " -> " + str(state.coin_value))
	_check(a, "买完售罄", not goods.is_have_goods, str(goods.is_have_goods))

	# ------------------------------------------------ STEP2 关卡里补种修复
	a.log("STEP2 进 1-1 补种修复")
	if not await _enter_level(a):
		_finish(a)
		return

	var cell: PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[0][0]
	var nut = cell.create_plant(P004)
	await a.wait(0.5)
	if not is_instance_valid(nut):
		_check(a, "种下坚果", false, "null")
		_finish(a)
		return

	var max_hp: int = nut.hp_component_plant.max_hp
	_check(a, "外观完好时不能补种", cell.get_first_aid_plant(P004) == null)

	## 打掉大半血 -> 掉手 / 裂开
	nut.hp_component_plant.Hp_loss(max_hp - 1000)
	await a.wait(0.5)
	var stage_component := nut.get_node_or_null(^"HpStageChangeComponent") as HpStageChangeComponent
	if stage_component == null:
		_check(a, "坚果有血量阶段组件", false, "null")
		_finish(a)
		return
	a.log("  受损后 hp=%d/%d 阶段=%d" % [nut.hp_component_plant.curr_hp, max_hp, stage_component.curr_hp_stage])
	_check(a, "受损后进入裂纹阶段", stage_component.curr_hp_stage >= 1,
		str(stage_component.curr_hp_stage))
	_check(a, "受损后可补种(命中本株)", cell.get_first_aid_plant(P004) == nut)
	_check(a, "拿高坚果卡片不能补坚果", cell.get_first_aid_plant(P024) == null)

	## 没买包扎术时不能补种
	state.is_wall_nut_first_aid_bought = false
	_check(a, "没买包扎术时不能补种", cell.get_first_aid_plant(P004) == null)
	state.is_wall_nut_first_aid_bought = true

	## 真的补种：血量与外观一起复原
	nut.be_first_aid_heal()
	await a.wait(0.5)
	_check(a, "补种后回满血", nut.hp_component_plant.curr_hp == max_hp,
		str(nut.hp_component_plant.curr_hp) + "/" + str(max_hp))
	_check(a, "补种后外观复原(阶段 -1)", stage_component.curr_hp_stage == -1,
		str(stage_component.curr_hp_stage))
	_check(a, "复原后不再是可补种目标", cell.get_first_aid_plant(P004) == null)

	_finish(a)


#region 断言与工具
func _enter_level(a) -> bool:
	var para: Resource = (load(LEVEL_01_01) as GDScript).new()
	if para == null:
		_check(a, "1-1 关卡资源可加载", false, LEVEL_01_01)
		return false
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(3.0)
	if Global.main_game == null:
		_check(a, "进入 1-1", false, "main_game 为空")
		return false
	if Global.main_game.plant_cell_manager == null:
		_check(a, "进入 1-1", false, "plant_cell_manager 为空")
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
	a.log("[FIRSTAID] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 把冒险模式前 upto 关标成已通关（存关键 = "101_0_%04d"）
func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}
#endregion
