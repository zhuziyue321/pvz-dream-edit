extends RefCounted
## 探针：僵尸掉落巧克力（原版：买了蜗牛之后僵尸才会掉巧克力）
## 覆盖：
##   1. 没买蜗牛时，僵尸死亡什么都不掉
##   2. 买了蜗牛后，僵尸死亡掉一块巧克力（掉落物挂在 AllDropChocolate 下）
##   3. 点开巧克力 -> 巧克力库存 +1
##   4. 巧克力库存到上限（ConstShop.TOOL_MAX_OWN_NUM）后不再掉
## 机器可读汇总：最后一行 [CHOCO] result=PASS|FAIL failed=<n>

var _failed := 0

## 僵尸的出生点（世界坐标，落在 can_drop_x_range 0~900 内才会掉）
const ZOMBIE_POS := Vector2(400.0, 300.0)


func run(a) -> void:
	a.log("")
	a.log("========== 探针 僵尸掉落巧克力 ==========")

	var state = Global.global_game_state
	## 复位成「没买过任何花园工具」的存档
	state.garden_data[GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY] = []
	state.garden_data[GlobalGameState.GARDEN_TOOL_NUM_KEY] = {}

	if not await _goto_level(a):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	await a.wait(3.0)

	# ------------------------------------------------ STEP1 拿到掉落节点与一只僵尸
	a.log("STEP1 准备：掉落节点 + 一只僵尸")
	var dim = Global.main_game.drop_item_manager.dim_chocolate
	if dim == null:
		_check(a, "找到 DIM_Chocolate 节点", false, "null")
		_finish(a)
		return
	var drop_parent: Node2D = dim.all_drop_chocolate_parent
	if drop_parent == null:
		_check(a, "找到 AllDropChocolate 父节点", false, "null")
		_finish(a)
		return
	var zombie := _create_zombie()
	if zombie == null:
		_check(a, "生成一只僵尸", false, "null")
		_finish(a)
		return
	var comp: DropItemComponent = zombie.drop_item_component
	## 概率调成必掉，免得探针靠运气
	comp.drop_chocolate_rate = 1.0

	# ------------------------------------------------ STEP2 没买蜗牛：不掉
	a.log("STEP2 没买蜗牛时僵尸死了不掉巧克力")
	var num_before: int = drop_parent.get_child_count()
	comp.drop_chocolate()
	await a.wait(0.5)
	_check(a, "没买蜗牛时不掉巧克力", drop_parent.get_child_count() == num_before,
		str(num_before) + " -> " + str(drop_parent.get_child_count()))

	# ------------------------------------------------ STEP3 买了蜗牛：掉一块
	a.log("STEP3 买了蜗牛后僵尸死了掉一块巧克力")
	_check(a, "买断蜗牛成功", state.buy_garden_tool(GardenManager.E_GardenTool.Snail))
	comp.drop_chocolate()
	await a.wait(0.5)
	_check(a, "买了蜗牛后掉了一块巧克力", drop_parent.get_child_count() == num_before + 1,
		str(num_before) + " -> " + str(drop_parent.get_child_count()))
	var drop_node: ChocolateDrop = null
	for c in drop_parent.get_children():
		if c is ChocolateDrop:
			drop_node = c
	_check(a, "掉落物是 ChocolateDrop", drop_node != null, str(drop_node))
	if drop_node == null:
		_finish(a)
		return

	# ------------------------------------------------ STEP4 点开：库存 +1
	a.log("STEP4 点开巧克力 -> 库存 +1")
	var choco_before: int = state.get_garden_tool_num(GardenManager.E_GardenTool.Chocolate)
	drop_node.texture_button.pressed.emit()
	await a.wait(1.5)
	var choco_after: int = state.get_garden_tool_num(GardenManager.E_GardenTool.Chocolate)
	_check(a, "点开后巧克力库存 +1", choco_after == choco_before + 1,
		str(choco_before) + " -> " + str(choco_after))
	_check(a, "点开后掉落物已回收", not is_instance_valid(drop_node), str(drop_node))

	# ------------------------------------------------ STEP5 库存到上限：不再掉
	a.log("STEP5 巧克力库存到上限后不再掉")
	state.add_garden_tool_num(GardenManager.E_GardenTool.Chocolate, ConstShop.TOOL_MAX_OWN_NUM)
	_check(a, "库存已到持有上限",
		state.get_garden_tool_num(GardenManager.E_GardenTool.Chocolate) >= ConstShop.TOOL_MAX_OWN_NUM,
		str(state.get_garden_tool_num(GardenManager.E_GardenTool.Chocolate)))
	var num_before_full: int = drop_parent.get_child_count()
	comp.drop_chocolate()
	await a.wait(0.5)
	_check(a, "库存满了不再掉巧克力", drop_parent.get_child_count() == num_before_full,
		str(num_before_full) + " -> " + str(drop_parent.get_child_count()))

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
	a.log("[CHOCO] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 在当前关卡里生成一只普通僵尸（走 ZombieManager，与波次刷新同一条路）
func _create_zombie() -> Zombie000Base:
	var zombie_manager = Global.main_game.zombie_manager
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: 0,
		Zombie000Base.E_ZInitAttr.CurrWave: 1,
	}
	return zombie_manager.create_norm_zombie(
		CharacterRegistry.ZombieType.Z001Norm,
		zombie_manager.all_zombie_rows[0],
		init_para,
		ZOMBIE_POS)


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
