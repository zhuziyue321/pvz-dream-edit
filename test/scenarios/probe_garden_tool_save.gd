extends RefCounted
## 探针：所有园艺工具的「购买 → 落存档 → 重开档还在」全链路
## 覆盖：
##   1. 走真实购买链路（goods_garden_tool.tscn 的 comfirm_get_this_goods，含扣钱 / 落盘）
##      把 7 件工具全买一遍：黄金水壶 / 留声机 / 园艺手套 / 蜗牛（买断）；肥料 / 杀虫剂 / 巧克力（消耗）
##   2. 盘上的存档文件里确实有这两处记录：garden_data.bought_garden_tools（4 个枚举值）
##      与 garden_data.garden_tool_num（3 个消耗品各 5 个）
##   3. 内存状态清空后重新读档（模拟重开游戏），7 件工具一件不少：is_garden_tool_available 全真
## 机器可读汇总：最后一行 [GARDENTOOLSAVE] result=PASS|FAIL failed=<n>

var _failed := 0

const GOODS_SCENE := preload("res://src/store/goods_garden_tool.tscn")

## 买断型工具（买了永久拥有）
const ONE_TIME_TOOLS: Array[GardenManager.E_GardenTool] = [
	GardenManager.E_GardenTool.GoldWateringCan,
	GardenManager.E_GardenTool.Phonograph,
	GardenManager.E_GardenTool.GardeningGlove,
	GardenManager.E_GardenTool.Snail,
]
## 消耗型工具（一份 5 个）
const CONSUMABLE_TOOLS: Array[GardenManager.E_GardenTool] = [
	GardenManager.E_GardenTool.Fertilizer,
	GardenManager.E_GardenTool.BugSpray,
	GardenManager.E_GardenTool.Chocolate,
]


func run(a) -> void:
	a.log("")
	a.log("========== 探针 园艺工具全部落存档 ==========")
	await a.wait(2.0)

	var state = Global.global_game_state
	var save_service = Global.save_service
	## 通关到 5-10：花园已解锁（花园类商品有这道门槛）
	_mark_cleared(state, 50)
	## 复位成「什么都没买过」
	state.garden_data = GlobalGameState.DEFAULT_GARDEN_DATA.duplicate(true)
	state.coin_value = 999999

	var user_name: String = Global.user_manager.curr_user_name
	_check(a, "已有登录用户（存档路径非空）", not user_name.is_empty(), user_name)

	a.log("STEP1 走真实购买链路，把 7 件工具全买一遍")
	for tool_type in ONE_TIME_TOOLS:
		await _buy_one(a, state, tool_type)
	for tool_type in CONSUMABLE_TOOLS:
		await _buy_one(a, state, tool_type)

	a.log("STEP2 内存里 7 件工具都应到手")
	for tool_type in ONE_TIME_TOOLS:
		_check(a, "已买断：" + _tool_name(tool_type), state.is_garden_tool_bought(tool_type))
	for tool_type in CONSUMABLE_TOOLS:
		_check(a, "有库存：" + _tool_name(tool_type) + "（5 个）",
			state.get_garden_tool_num(tool_type) == ConstShop.TOOL_NUM_PER_BUY,
			str(state.get_garden_tool_num(tool_type)))

	a.log("STEP3 盘上的存档文件里要有这两处记录")
	save_service.save_now()
	var file_data := _read_save_file()
	var saved_garden: Dictionary = file_data.get("garden_data", {}) as Dictionary
	_check(a, "存档文件读得到", not file_data.is_empty())
	var saved_bought: Array = saved_garden.get(GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY, []) as Array
	var saved_num: Dictionary = saved_garden.get(GlobalGameState.GARDEN_TOOL_NUM_KEY, {}) as Dictionary
	for tool_type in ONE_TIME_TOOLS:
		_check(a, "存档里有买断记录：" + _tool_name(tool_type), _has_int(saved_bought, int(tool_type)),
			str(saved_bought))
	for tool_type in CONSUMABLE_TOOLS:
		_check(a, "存档里有库存记录：" + _tool_name(tool_type),
			int(saved_num.get(str(int(tool_type)), 0)) == ConstShop.TOOL_NUM_PER_BUY,
			str(saved_num))
	_check(a, "存档里花园背景页数没被冲掉",
		int(saved_garden.get("num_bg_page_0", 0)) == 1, str(saved_garden.get("num_bg_page_0", -1)))

	a.log("STEP3.5 读回来的买断记录要转回 int，不能一直是 JSON 的 float")
	save_service.load_global_game_data()
	var reloaded_bought: Array = state.garden_data.get(
		GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY, []) as Array
	var all_int := true
	for bought_tool in reloaded_bought:
		if typeof(bought_tool) != TYPE_INT:
			all_int = false
	_check(a, "买断记录元素都是 int", all_int and not reloaded_bought.is_empty(), str(reloaded_bought))

	a.log("STEP4 清空内存后重新读档（等于重开游戏），7 件工具一件不少")
	state.garden_data = GlobalGameState.DEFAULT_GARDEN_DATA.duplicate(true)
	_check(a, "清空后手套确实没了（确保下一步不是假阳性）",
		not state.is_garden_tool_bought(GardenManager.E_GardenTool.GardeningGlove))
	save_service.load_global_game_data()
	for tool_type in ONE_TIME_TOOLS:
		_check(a, "读档后仍已拥有：" + _tool_name(tool_type), state.is_garden_tool_bought(tool_type))
	for tool_type in CONSUMABLE_TOOLS:
		_check(a, "读档后库存还在：" + _tool_name(tool_type),
			state.get_garden_tool_num(tool_type) == ConstShop.TOOL_NUM_PER_BUY,
			str(state.get_garden_tool_num(tool_type)))
	for tool_type in ONE_TIME_TOOLS + CONSUMABLE_TOOLS:
		_check(a, "读档后可用：" + _tool_name(tool_type), state.is_garden_tool_available(tool_type))

	_finish(a)


#region 工具与断言
## 造一个商品节点并真的买一次（扣钱 + get_one_goods + save_now 全在里面）
func _buy_one(a, state, tool_type: GardenManager.E_GardenTool) -> void:
	var goods: GoodsGardenTool = GOODS_SCENE.instantiate()
	goods.garden_tool = tool_type
	a.get_tree().current_scene.add_child(goods)
	await a.wait(0.3)
	state.coin_value = 999999
	_check(a, "购买 " + _tool_name(tool_type) + " 按钮可点", not goods.button.disabled)
	goods.comfirm_get_this_goods()
	await a.wait(0.2)
	goods.queue_free()


## JSON 一律把数字读成 float，数组判存要逐个 int() 比
func _has_int(arr: Array, value: int) -> bool:
	for element in arr:
		if int(element) == value:
			return true
	return false


func _tool_name(tool_type: GardenManager.E_GardenTool) -> String:
	return GardenManager.E_GardenTool.keys()[int(tool_type)] + "(" + str(int(tool_type)) + ")"


## 直接读盘上的存档 JSON（绕开内存状态，验证「真的写进文件了」）
func _read_save_file() -> Dictionary:
	var path := "user://" + Global.user_manager.curr_user_name + "/" + Global.save_service.SaveGameFileName
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text) as Dictionary


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[GARDENTOOLSAVE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}
#endregion
