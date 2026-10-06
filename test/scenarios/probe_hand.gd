extends RefCounted
## 探针 PROBE4：手持物组件机制
## 覆盖：
##   1. 组件注册与「手持 ⇄ 空手」状态流转（组件类型、is_holding_hand）
##   0. 解锁进度：铲子（未通关 1-4 卡槽不出现）、手套（未通关 4-5 卡槽不出现，戴夫在 4-6 交给你）
##   2. 反复点同一张卡不会在 TemporaryCharacter 下堆积节点（手持虚影泄漏回归）
##   3. 种植成功会放下手持物并扣阳光；点到不能种的格子会继续手持（不再丢卡）
##   4. 铲子：拿到手上时卡槽只留背景（不再出现两把铲子）、铲完自动放回、右键取消
##   5. 手套：搬运植物（不铲除不重种，实例与状态保持）、拿起中 top_level、右键取消放回原位
## 机器可读汇总：最后一行 [HAND] result=PASS|FAIL failed=<n>

const CARD_LIST := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotContainer/CardSlotBattle/CardUiList"
const SHOVEL := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotContainer/ShovelContainer/UIShovel"
const GLOVE := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotContainer/ShovelContainer/UIGlove"
const GRID := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotNorm/CardSlotCandidate/AllCardPage/GridContainerPlant"
## 手持美术挂载节点（手持物组件把卡片美术挂在这里）
const TEMP_CHARACTER := "/root/MainGame/CanvasLayerTemp/TemporaryCharacter"
## 目标格子：进关卡后按「当前卡片能种下」动态挑（1-1 只有部分行铺了草皮，写死坐标会点到不能种的格子）
var _cell := Vector2i(1, 1)
## 手套搬运的目标格子（与 _cell 同一行的另一个可种格子）
var _cell_dst := Vector2i(1, 2)
## 冒险模式 1-4 的关卡存档名（game_mode_level_page_level_id）
const LEVEL_1_4_SAVE_KEY := "%d_0_0004" % MainSceneRegistry.MainScenes.ChooseLevelAdventure
## 冒险模式 4-5 的关卡存档名：通关它之后戴夫才把手套交给玩家（ConstUnlockLevel.GLOVE_UNLOCK_ADVENTURE_LEVEL）
const LEVEL_4_5_SAVE_KEY := "%d_0_0035" % MainSceneRegistry.MainScenes.ChooseLevelAdventure
## 反复点卡次数（泄漏回归用）
const REPEAT_TIMES := 6

var _failed := 0
var _card_path := ""


func run(a) -> void:
	a.log("")
	a.log("========== PROBE4 手持物组件 ==========")
	if not await _goto_level(a):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	await a.wait(6.0)
	await _pick_card(a)
	if not await _to_battle(a):
		_finish(a)
		return

	var card := _first_battle_card(a)
	if card == null:
		a.log("!! 战斗卡槽没有卡")
		_finish(a)
		return
	_card_path = str(card.get_path())
	_pick_cells(a, card)
	a.log("  目标格子: 种植=%s 搬运=%s" % [str(_cell), str(_cell_dst)])
	## 关卡起手只有 50 阳光,而 1-1 解锁的豌豆射手要 100,
	## 用测试事件把阳光补到 500,保证手持物流程不被"买不起"卡住
	EventBus.push_event("test_change_sun_value", [500])
	a.log("  测试补充阳光 -> %d" % _sun())

	await _check_shovel_unlock(a)
	_check_registry(a)
	await _check_take_card(a)
	await _check_no_leak(a)
	await _check_plant(a)
	await _check_invalid_cell_keeps_hand(a)
	await _check_right_click_cancel(a)
	## 手套总开关关闭时整节跳过（ConstFeatureSwitch.GLOVE_ENABLED），否则第 7 节必挂
	if ConstFeatureSwitch.GLOVE_ENABLED:
		await _check_glove(a)
	else:
		a.log("")
		a.log("--- 7. 手套组件（GLOVE_ENABLED=false，已隐藏，跳过）---")
	await _check_shovel(a)
	_finish(a)


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[HAND] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion


#region 状态读取
func _hm() -> HandManager:
	return Global.main_game.hand_manager


func _hand_type() -> int:
	return _hm().get_curr_hand_type()


func _holding() -> bool:
	return _hm().is_holding_hand()


func _hand_node_count() -> int:
	var tc: Node = Global.main_game.get_node_or_null("CanvasLayerTemp/TemporaryCharacter")
	if tc == null:
		return -1
	return tc.get_child_count()


func _sun() -> int:
	return Global.main_game.card_manager.card_slot_battle.sun_value


## 铲子组件
func _shovel_comp() -> HandComponentShovel:
	return _hm().get_hand_component(HandComponentBase.E_HandComponentType.Shovel) as HandComponentShovel


## 铲子卡槽是否显示
func _slot_visible(a) -> bool:
	var node: CanvasItem = a.get_node_or_null(SHOVEL)
	return node != null and node.visible


## 直接改 1-4 的通关状态，并按新的解锁结果重算铲子组件的启用状态
## unlocked: true = 标记为已通关 1-4（铲子已获取）
func _set_shovel_unlocked(a, unlocked: bool) -> void:
	var state := Global.global_game_state
	if unlocked:
		state.curr_all_level_state_data[LEVEL_1_4_SAVE_KEY] = {"IsSuccess": true}
	else:
		state.curr_all_level_state_data.erase(LEVEL_1_4_SAVE_KEY)
	var comp := _shovel_comp()
	if comp != null:
		comp.change_is_enabling(comp.is_can_has_shovel(), HandComponentBase.E_IsEnableFactor.HandItem)
	await a.frames(2)


## 直接改 4-5 的通关状态，并按新的解锁结果重算手套组件的启用状态
## 手套有解锁进度门槛（通关 4-5 后戴夫才给），探针进的是 1-1，不模拟就永远拿不到手套
func _set_glove_unlocked(a, unlocked: bool) -> void:
	var state := Global.global_game_state
	if unlocked:
		state.curr_all_level_state_data[LEVEL_4_5_SAVE_KEY] = {"IsSuccess": true}
	else:
		state.curr_all_level_state_data.erase(LEVEL_4_5_SAVE_KEY)
	var comp := _glove_comp()
	if comp != null:
		comp.change_is_enabling(comp.is_can_has_glove(), HandComponentBase.E_IsEnableFactor.HandItem)
	await a.frames(2)
	await a.wait(0.3)


## 手套组件
func _glove_comp() -> HandComponentGlove:
	return _hm().get_hand_component(HandComponentBase.E_HandComponentType.Glove) as HandComponentGlove


## 挑两个格子：第一个当前卡片能种下的作为种植点，同一行里再挑一个作为手套搬运目标
func _pick_cells(a, card: Control) -> void:
	var plant_type: int = card.get("card_plant_type")
	var cond: ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	if cond == null:
		return
	var found_src := false
	for row_cells in Global.main_game.plant_cell_manager.all_plant_cells:
		for c in row_cells:
			var pc := c as PlantCell
			if pc == null or not cond.judge_is_can_plant(pc, plant_type):
				continue
			if not found_src:
				_cell = pc.row_col
				found_src = true
				continue
			if pc.row_col.x == _cell.x:
				_cell_dst = pc.row_col
				return


func _cell_plants(spec: Vector2i) -> Array:
	var res: Array = []
	var pc = Global.main_game.plant_cell_manager.all_plant_cells[spec.x][spec.y]
	for key in pc.plant_in_cell:
		if is_instance_valid(pc.plant_in_cell[key]):
			res.append(str(pc.plant_in_cell[key].plant_type))
	return res
#endregion


#region 检查项
## 组件注册 + 空手初始状态 + 铲子界面初始状态
func _check_registry(a) -> void:
	a.log("")
	a.log("--- 1. 组件注册与初始状态 ---")
	var hm = _hm()
	a.log("  已注册组件类型: %s" % str(hm.all_hand_components.keys()))
	_check(a, "空手组件已注册", hm.get_hand_component(HandComponentBase.E_HandComponentType.Null) != null)
	_check(a, "角色组件已注册", hm.get_hand_component(HandComponentBase.E_HandComponentType.Character) != null)
	var shovel_comp = hm.get_hand_component(HandComponentBase.E_HandComponentType.Shovel)
	_check(a, "铲子组件已注册", shovel_comp != null)
	_check(a, "初始为空手", _hand_type() == HandComponentBase.E_HandComponentType.Null, "type=%d" % _hand_type())
	_check(a, "初始未手持", not _holding())
	if shovel_comp != null:
		_check(a, "铲子组件按关卡参数与解锁进度启用", shovel_comp.is_enabling, "is_enabling=%s" % str(shovel_comp.is_enabling))
	var ui_shovel: Control = a.get_node_or_null(SHOVEL)
	if ui_shovel != null:
		_check(a, "游玩阶段显示铲子卡槽", (ui_shovel as CanvasItem).visible)
		var icon: Control = a.get_node_or_null(SHOVEL + "/Shovel")
		_check(a, "空手时显示铲子图标", icon != null and (icon as CanvasItem).visible)


## 0. 铲子解锁进度：未通关 1-4 时没有铲子，通关 1-4 后卡槽出现铲子
func _check_shovel_unlock(a) -> void:
	a.log("")
	a.log("--- 0. 铲子解锁进度 ---")
	var comp := _shovel_comp()
	if comp == null:
		_check(a, "（前置）铲子组件存在", false)
		return
	await _set_shovel_unlocked(a, false)
	_check(a, "未通关 1-4 时组件被禁用", not comp.is_enabling, "is_enabling=%s" % str(comp.is_enabling))
	_check(a, "未通关 1-4 时不显示铲子卡槽", not _slot_visible(a), "visible=%s" % str(_slot_visible(a)))
	await _set_shovel_unlocked(a, true)
	_check(a, "通关 1-4 后组件启用", comp.is_enabling, "is_enabling=%s" % str(comp.is_enabling))
	_check(a, "通关 1-4 后显示铲子卡槽", _slot_visible(a), "visible=%s" % str(_slot_visible(a)))


## 点卡 → 拿在手上
func _check_take_card(a) -> void:
	a.log("")
	a.log("--- 2. 点卡拿到手上 ---")
	await a.click_node(_card_path)
	await a.wait(0.3)
	_check(a, "手持类型=角色", _hand_type() == HandComponentBase.E_HandComponentType.Character, "type=%d" % _hand_type())
	_check(a, "处于手持中", _holding())
	_check(a, "手持美术=2 个节点", _hand_node_count() == 2, "count=%d" % _hand_node_count())


## 反复点同一张卡：手持美术应当只有 2 个节点，不允许堆积（回归：手持虚影泄漏）
func _check_no_leak(a) -> void:
	a.log("")
	a.log("--- 3. 反复点卡不堆积节点（共 %d 次）---" % REPEAT_TIMES)
	var base_hand := _hand_node_count()
	var base_all: int = a.get_tree().get_node_count()
	for i in range(REPEAT_TIMES):
		await a.click_node(_card_path)
		await a.wait(0.15)
	await a.frames(5)
	var now_hand := _hand_node_count()
	var now_all: int = a.get_tree().get_node_count()
	## TemporaryCharacter 是手持美术与柱子虚影唯一的挂载点，所以它的子节点数就是
	## 手持物是否泄漏的精确信号；全场景节点数会被同时进行的刷怪/阳光干扰，只做参考。
	a.log("  手持美术节点: %d -> %d ; 全场景节点: %d -> %d（参考值，含同时进行的刷怪）" % [
		base_hand, now_hand, base_all, now_all])
	_check(a, "手持美术节点数恰好为 2", now_hand == 2, "%d -> %d" % [base_hand, now_hand])
	## HandManager 下挂 5 个组件：Null / Character / Shovel / Glove / Hammer
	## （锤子是锤僵尸玩法的手持物，默认禁用，由玩法规则启用，见 HandComponentHammer）
	_check(a, "组件节点数不变", _hm().get_child_count() == 5, "count=%d" % _hm().get_child_count())
	_check(a, "反复点卡后仍在手持", _holding())


## 种植成功：放下手持物 + 扣阳光
func _check_plant(a) -> void:
	a.log("")
	a.log("--- 4. 种植成功 ---")
	var sun_before := _sun()
	var before := _cell_plants(_cell)
	await a.click_plant_cell(_cell.x, _cell.y)
	await a.wait(0.6)
	var after := _cell_plants(_cell)
	a.log("  格子%s 植物 %s -> %s ; 阳光 %d -> %d" % [str(_cell), str(before), str(after), sun_before, _sun()])
	_check(a, "植物已种下", after.size() > before.size())
	_check(a, "阳光已扣除", _sun() < sun_before, "%d -> %d" % [sun_before, _sun()])
	_check(a, "种植后回到空手", _hand_type() == HandComponentBase.E_HandComponentType.Null, "type=%d" % _hand_type())
	_check(a, "手持美术已释放", _hand_node_count() == 0, "count=%d" % _hand_node_count())


## 点到已占用的格子：不能种，但卡片必须留在手上
func _check_invalid_cell_keeps_hand(a) -> void:
	a.log("")
	a.log("--- 5. 点到不能种的格子仍然手持 ---")
	await _reset_card_cooldown(a)
	await a.click_node(_card_path)
	await a.wait(0.3)
	if not _holding():
		_check(a, "（前置）重新拿卡成功", false, "type=%d" % _hand_type())
		return
	await a.click_plant_cell(_cell.x, _cell.y)
	await a.wait(0.5)
	a.log("  点击已占用格子后 手持类型=%d 手持中=%s" % [_hand_type(), str(_holding())])
	_check(a, "不能种时不丢卡", _holding() and _hand_type() == HandComponentBase.E_HandComponentType.Character)


## 右键取消手持
func _check_right_click_cancel(a) -> void:
	a.log("")
	a.log("--- 6. 右键取消手持 ---")
	## 右键点卡槽空白（保证当前不在格子上）
	await _right_click(a, Vector2(300, 30))
	await a.wait(0.3)
	_check(a, "右键后回到空手", _hand_type() == HandComponentBase.E_HandComponentType.Null, "type=%d" % _hand_type())
	_check(a, "右键后未手持", not _holding())
	_check(a, "右键后手持美术已释放", _hand_node_count() == 0, "count=%d" % _hand_node_count())


## 手套：拿起 → 搬进另一个格子（同一个实例、状态不中断）→ 右键取消放回原位
func _check_glove(a) -> void:
	a.log("")
	a.log("--- 7. 手套组件（搬运植物）---")
	var glove_comp = _hm().get_hand_component(HandComponentBase.E_HandComponentType.Glove)
	if glove_comp == null:
		_check(a, "（前置）手套组件存在", false)
		return
	var ui_glove: CanvasItem = a.get_node_or_null(GLOVE)
	var icon: CanvasItem = a.get_node_or_null(GLOVE + "/Glove")
	if ui_glove == null or icon == null:
		_check(a, "（前置）手套界面节点齐全", false)
		return
	## 手套有解锁进度门槛：未通关 4-5 时禁用，通关 4-5 后才启用（与铲子的 1-4 同一套口径）
	await _set_glove_unlocked(a, false)
	_check(a, "未通关 4-5 时手套组件被禁用", not glove_comp.is_enabling, "is_enabling=%s" % str(glove_comp.is_enabling))
	_check(a, "未通关 4-5 时不显示手套卡槽", not ui_glove.visible, "visible=%s" % str(ui_glove.visible))
	await _set_glove_unlocked(a, true)
	_check(a, "通关 4-5 后手套组件启用", glove_comp.is_enabling, "is_enabling=%s" % str(glove_comp.is_enabling))
	_check(a, "游玩阶段显示手套卡槽", ui_glove.visible)

	await a.click_node(GLOVE + "/Button")
	await a.wait(0.3)
	_check(a, "手持类型=手套", _hand_type() == HandComponentBase.E_HandComponentType.Glove, "type=%d" % _hand_type())
	_check(a, "卡槽手套图标已隐藏", not icon.visible)

	## 拿起：来源格子的植物，搬到同一行的另一个可种格子
	var src := _cell
	var dst := _cell_dst
	var src_cell = Global.main_game.plant_cell_manager.all_plant_cells[src.x][src.y]
	var dst_cell = Global.main_game.plant_cell_manager.all_plant_cells[dst.x][dst.y]
	var plant_before = src_cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	if not is_instance_valid(plant_before):
		_check(a, "（前置）来源格子有植物", false)
		return
	var plant_id: int = plant_before.get_instance_id()
	await a.click_plant_cell(src.x, src.y)
	await a.wait(0.4)
	var carry = glove_comp.curr_carry_plant
	_check(a, "已从格子拿起植物", is_instance_valid(carry) and carry.get_instance_id() == plant_id)
	_check(a, "拿起后仍留在场景树内（top_level 位移，不是摘出树）",
		is_instance_valid(carry) and carry.is_inside_tree() and carry.top_level)
	_check(a, "拿走后来源格子已空", src_cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm) == null)
	_check(a, "拿起后手套仍在手上", _holding() and _hand_type() == HandComponentBase.E_HandComponentType.Glove)
	if not is_instance_valid(carry):
		return

	## 放下：搬进 (1,2)
	await a.click_plant_cell(dst.x, dst.y)
	await a.wait(0.4)
	var moved = dst_cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	_check(a, "植物已搬进目标格子", is_instance_valid(moved) and moved.get_instance_id() == plant_id)
	_check(a, "搬运后是同一个实例（没有重新种植）", is_instance_valid(moved) and moved.get_instance_id() == plant_id)
	_check(a, "放下后 top_level 已复位", is_instance_valid(moved) and not moved.top_level)
	_check(a, "放下后植物仍在场景树内", is_instance_valid(moved) and moved.is_inside_tree())
	_check(a, "放下后回到空手", _hand_type() == HandComponentBase.E_HandComponentType.Null)
	_check(a, "空手后卡槽手套图标恢复", icon.visible)

	## 取消：再拿起一次后右键，植物必须回到来源格子
	await a.click_node(GLOVE + "/Button")
	await a.wait(0.3)
	await a.click_plant_cell(dst.x, dst.y)
	await a.wait(0.4)
	if not is_instance_valid(glove_comp.curr_carry_plant):
		_check(a, "（前置）再次拿起成功", false)
		return
	await _right_click(a, Vector2(300, 30))
	await a.wait(0.4)
	var back = dst_cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	_check(a, "取消搬运后植物回到来源格子", is_instance_valid(back) and back.get_instance_id() == plant_id)
	_check(a, "取消后回到空手", _hand_type() == HandComponentBase.E_HandComponentType.Null)

	## 把植物搬回原来的格子：后面的铲子检查还在老格子上铲它
	await a.click_node(GLOVE + "/Button")
	await a.wait(0.3)
	await a.click_plant_cell(dst.x, dst.y)
	await a.wait(0.4)
	await a.click_plant_cell(src.x, src.y)
	await a.wait(0.4)
	var restored = src_cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	_check(a, "植物已搬回原格子", is_instance_valid(restored) and restored.get_instance_id() == plant_id)


## 铲子：界面收敛 + 铲除 + 第二次点击不产生双铲子
func _check_shovel(a) -> void:
	a.log("")
	a.log("--- 8. 铲子组件 ---")
	var shovel_comp = _hm().get_hand_component(HandComponentBase.E_HandComponentType.Shovel)
	if shovel_comp == null:
		_check(a, "（前置）铲子组件存在", false)
		return
	var ui_shovel: CanvasItem = a.get_node_or_null(SHOVEL)
	var icon: CanvasItem = a.get_node_or_null(SHOVEL + "/Shovel")
	var real_shovel: CanvasItem = a.get_node_or_null("/root/MainGame/CanvasLayerTemp/RealShovel")
	if ui_shovel == null or icon == null or real_shovel == null:
		_check(a, "（前置）铲子界面节点齐全", false)
		return

	await a.click_node(SHOVEL + "/Button")
	await a.wait(0.3)
	_check(a, "手持类型=铲子", _hand_type() == HandComponentBase.E_HandComponentType.Shovel, "type=%d" % _hand_type())
	_check(a, "处于手持中", _holding())
	_check(a, "真铲子显示", real_shovel.visible)
	_check(a, "铲子卡槽仍显示(留背景)", ui_shovel.visible)
	_check(a, "卡槽铲子图标已隐藏", not icon.visible)

	## 再点一次卡槽铲子：不允许出现「手上一把 + 卡槽一把」
	await a.click_node(SHOVEL + "/Button")
	await a.wait(0.3)
	_check(a, "重复点铲子不产生双铲子", _hand_type() == HandComponentBase.E_HandComponentType.Shovel \
		and (not icon.visible) and ui_shovel.visible)

	## 铲掉刚才种的植物
	var before := _cell_plants(_cell)
	await a.click_plant_cell(_cell.x, _cell.y)
	await a.wait(0.8)
	var after := _cell_plants(_cell)
	a.log("  格子%s 植物 %s -> %s" % [str(_cell), str(before), str(after)])
	_check(a, "植物已被铲除", after.size() < before.size())
	_check(a, "铲除后回到空手", _hand_type() == HandComponentBase.E_HandComponentType.Null, "type=%d" % _hand_type())
	_check(a, "真铲子已收起", not real_shovel.visible)
	_check(a, "空手后卡槽铲子图标恢复", icon.visible)
#endregion


#region 操作封装
## 清掉卡片冷却，便于探针反复用同一张卡（探针专用）
func _reset_card_cooldown(a) -> void:
	await a.call_on(_card_path, "set_card_cool_end")
	await a.call_on(_card_path, "card_ready")


func _first_battle_card(a) -> Control:
	var cl: Node = a.get_node_or_null(CARD_LIST)
	if cl == null:
		return null
	for slot in cl.get_children():
		for c in slot.get_children():
			if c is Control and (c as Control).is_visible_in_tree() and c.get("sun_cost") != null:
				return c as Control
	return null


func _screen_center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


func _move(a, p: Vector2) -> void:
	Input.warp_mouse(p)
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await a.frames(3)


func _click(a, p: Vector2) -> void:
	await _move(a, p)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	down.global_position = p
	Input.parse_input_event(down)
	await a.frames(2)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p
	up.global_position = p
	Input.parse_input_event(up)
	await a.frames(2)


func _right_click(a, p: Vector2) -> void:
	await _move(a, p)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = p
	down.global_position = p
	Input.parse_input_event(down)
	await a.frames(2)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = p
	up.global_position = p
	Input.parse_input_event(up)
	await a.frames(2)


## 启动 → 选关 → 进主游戏场景
func _goto_level(a) -> bool:
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)
	await a.click_first("Menu/Button1")
	if not await a.wait_scene("choose_level", 12.0):
		return false
	var gcl: Node = a.get_node_or_null("/root/ChooseLevel/AllPage/GridContainer")
	if gcl == null:
		return false
	var chosen := ""
	for ch in gcl.get_children():
		var nm := str(ch.name)
		if not nm.begins_with("ChooseLevelButton"):
			continue
		var btn := ch.get_node_or_null("TextureButton")
		if btn == null or (btn as BaseButton).disabled:
			continue
		if nm == "ChooseLevelButton":
			chosen = nm
			break
		if chosen == "":
			chosen = nm
	if chosen == "":
		return false
	await a.press_first(chosen + "/TextureButton")
	return await a.wait_scene("main_game", 10.0)


## 选卡阶段选一张卡（和 probe_plant 一致，选 Card5）
func _pick_card(a) -> void:
	var g: Node = a.get_node_or_null(GRID)
	if g == null:
		a.log("!! 找不到选卡面板")
		return
	var target: Control = null
	for ph in g.get_children():
		var cc := ph.get_node_or_null("CardCandidateContainer")
		if cc == null or not (cc as Control).is_visible_in_tree():
			continue
		for c in cc.get_children():
			if str(c.name) == "Card5":
				target = cc
	if target == null:
		## 植物解锁进度生效后,1-1 只解锁豌豆射手,Card5 不可见,直接用关卡预选卡
		a.log("-- 没找到可选的 Card5(未解锁?),跳过选卡")
		return
	await _click(a, _screen_center(target))
	await a.wait(0.6)


func _to_battle(a) -> bool:
	## 卡槽被系统自动填满时关卡已跳过选卡并进入主游戏，不要重复触发开始流程
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.choosed_card_start_game()
	await a.wait(6.0)
	a.log("  阶段=%d 阳光=%d" % [Global.main_game.main_game_progress, _sun()])
	if Global.main_game.main_game_progress != 3:
		a.log("!! 还没到 MAIN_GAME 阶段")
		return false
	return true
#endregion
