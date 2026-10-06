class_name GlobalGardenState
extends RefCounted

## 禅境花园的存档状态逻辑：背景页数、智慧树、花园工具库存。
##
## 原先这 148 行混在 global_game_state.gd 里，与金币、关卡进度、植物解锁、商店共享同一文件。
## 花园是独立业务，抽这里只对位置的形式 judgings 操作集中在这一个文件。
##
## garden_data 本体仍留在 GlobalGameState：存档系统与花园 UI 共 14 处直接读写它，
## 属于跨模块的全局存档数据，不适合圈进某一个业务对象。这里只搬逻辑，通过 state 反查。

var state: GlobalGameState

func _init(p_state: GlobalGameState) -> void:
	state = p_state

#region 禅境花园背景
## 该花园背景的页数在 state.garden_data 里的键(与 GardenManager / GardenConditionFlag 的读法一致)
static func get_bg_page_num_key(bg_type: GardenManager.E_GardenBgType) -> String:
	return "num_bg_page_" + str(int(bg_type))

## 该花园背景当前的页数
func get_garden_bg_page_num(bg_type: GardenManager.E_GardenBgType) -> int:
	return int(state.garden_data.get(get_bg_page_num_key(bg_type), 0))

## 该花园背景是否已拥有(页数 >= 1)
## 原版:阳光房默认就有;蘑菇园 / 水族馆要在商店花 $30000 买了才有(见 ConstShop.GARDEN_BG_PRICE)
func is_garden_bg_owned(bg_type: GardenManager.E_GardenBgType) -> bool:
	return get_garden_bg_page_num(bg_type) >= 1

## 已拥有的花园背景(按枚举顺序),商店里没买的蘑菇园 / 水族馆不在其中
func get_owned_garden_bg_types() -> Array[GardenManager.E_GardenBgType]:
	var result: Array[GardenManager.E_GardenBgType] = []
	for i in range(GardenManager.E_GardenBgType.size()):
		var bg_type := i as GardenManager.E_GardenBgType
		if is_garden_bg_owned(bg_type):
			result.append(bg_type)
	return result

## 购买(解锁)一个花园背景:未拥有时置为 1 页,已拥有时返回 false,不重复加页
## 原版这类商品买一次即 Sold Out,不存在"买第二页"的入口
func buy_garden_bg(bg_type: GardenManager.E_GardenBgType) -> bool:
	if is_garden_bg_owned(bg_type):
		return false
	state.garden_data[get_bg_page_num_key(bg_type)] = 1
	return true

#region 智慧树
## 智慧树是否已在商店买断(原版 $10000,见 ConstShop.TREE_OF_WISDOM_PRICE)
func is_tree_of_wisdom_bought() -> bool:
	return bool(state.garden_data.get(ConstShop.TREE_OF_WISDOM_BOUGHT_KEY, false))

## 买下智慧树:记下"已购买" + 解锁花园里的智慧树页 + 送戴夫白送的那几袋树肥料
## 原版:买断,并且戴夫当场送几袋肥料让你好开始(见 ConstTreeOfWisdom.TREE_FOOD_START_NUM)
func buy_tree_of_wisdom() -> bool:
	if is_tree_of_wisdom_bought():
		return false
	state.garden_data[ConstShop.TREE_OF_WISDOM_BOUGHT_KEY] = true
	buy_garden_bg(GardenManager.E_GardenBgType.TreeBg)
	add_garden_tool_num(GardenManager.E_GardenTool.TreeFood, ConstTreeOfWisdom.TREE_FOOD_START_NUM)
	return true

## 智慧树现在多少英尺高(喂一袋树肥料 +1 英尺;读回来是 float,必须 int())
func get_tree_of_wisdom_height() -> int:
	return int(state.garden_data.get(ConstShop.TREE_OF_WISDOM_HEIGHT_KEY, 0))

## 给智慧树长高,返回长完后的高度(原版上限是 int32,这里同样只做上限保护)
func add_tree_of_wisdom_height(add_feet: int = ConstTreeOfWisdom.TREE_FOOD_GROW_FEET) -> int:
	var height: int = mini(
		get_tree_of_wisdom_height() + add_feet, ConstTreeOfWisdom.TREE_MAX_HEIGHT)
	state.garden_data[ConstShop.TREE_OF_WISDOM_HEIGHT_KEY] = height
	return height
#endregion

#region 禅境花园工具
## 该工具是不是消耗型(肥料 / 杀虫剂,见 ConstShop.CONSUMABLE_GARDEN_TOOL_PRICE)
static func is_consumable_garden_tool(tool_type: GardenManager.E_GardenTool) -> bool:
	return ConstShop.CONSUMABLE_GARDEN_TOOL_PRICE.has(tool_type)

## 该买断型工具(黄金水壶 / 留声机 / 园艺手套 / 蜗牛)是否已购买
## ⚠️ 必须逐个 int() 比,不能 Array.has(int):存档走 JSON,读回来的是 float(如 4.0),
## 而 Array.has() 认不出"float 4.0 == int 4",买断记录读档后会全部失效(工具像没买过一样)
## (老存档里存的就是 float,所以读取侧必须容错,光在写档时转 int 救不回来)
func is_garden_tool_bought(tool_type: GardenManager.E_GardenTool) -> bool:
	for bought_tool in (state.garden_data.get(GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY, []) as Array):
		if int(bought_tool) == int(tool_type):
			return true
	return false

## 买断一个花园工具,已拥有时返回 false
func buy_garden_tool(tool_type: GardenManager.E_GardenTool) -> bool:
	if is_garden_tool_bought(tool_type):
		return false
	var bought: Array = state.garden_data.get(GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY, [])
	bought.append(int(tool_type))
	state.garden_data[GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY] = bought
	return true

## 消耗型工具(肥料 / 杀虫剂)当前的持有数量
func get_garden_tool_num(tool_type: GardenManager.E_GardenTool) -> int:
	var tool_num: Dictionary = state.garden_data.get(GlobalGameState.GARDEN_TOOL_NUM_KEY, {})
	return int(tool_num.get(str(int(tool_type)), 0))

## 给消耗型工具加库存(商店一次买 ConstShop.get_garden_tool_num_per_buy() 个),
## 已到持有上限 ConstShop.get_tool_max_own_num() 时返回 false(商店据此禁售)
func add_garden_tool_num(tool_type: GardenManager.E_GardenTool, add_num: int) -> bool:
	var curr_num := get_garden_tool_num(tool_type)
	var max_own_num := ConstShop.get_tool_max_own_num(tool_type)
	if curr_num >= max_own_num:
		return false
	var tool_num: Dictionary = state.garden_data.get(GlobalGameState.GARDEN_TOOL_NUM_KEY, {})
	tool_num[str(int(tool_type))] = mini(curr_num + add_num, max_own_num)
	state.garden_data[GlobalGameState.GARDEN_TOOL_NUM_KEY] = tool_num
	return true

## 用掉一个消耗型工具(花园里用一次扣一个),没有库存时返回 false
func use_garden_tool(tool_type: GardenManager.E_GardenTool) -> bool:
	var curr_num := get_garden_tool_num(tool_type)
	if curr_num <= 0:
		return false
	var tool_num: Dictionary = state.garden_data.get(GlobalGameState.GARDEN_TOOL_NUM_KEY, {})
	tool_num[str(int(tool_type))] = curr_num - 1
	state.garden_data[GlobalGameState.GARDEN_TOOL_NUM_KEY] = tool_num
	return true

## 把 state.garden_data 里从 JSON 读回来的数字统一转回 int
## (存档里写的是 int,但 JSON 一律读成 float:不转回去的话,下次写档还是 float,存档里永远看着像 "4.0")
## 由 SaveService.load_global_game_data() 读档后调一次;读取侧的 int() 容错仍要保留(老存档救不回来)
func normalize_garden_data_numbers() -> void:
	var bought: Array = []
	for bought_tool in (state.garden_data.get(GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY, []) as Array):
		var tool_int := int(bought_tool)
		if not bought.has(tool_int):
			bought.append(tool_int)
	state.garden_data[GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY] = bought
	var raw_tool_num: Dictionary = state.garden_data.get(GlobalGameState.GARDEN_TOOL_NUM_KEY, {}) as Dictionary
	var tool_num: Dictionary = {}
	for tool_key in raw_tool_num:
		tool_num[str(tool_key)] = int(raw_tool_num[tool_key])
	state.garden_data[GlobalGameState.GARDEN_TOOL_NUM_KEY] = tool_num


## 该花园工具现在能不能用:买断型 = 已买,消耗型 = 还有库存
## 花园工具栏据此决定要不要把该工具藏起来(见 GardenManager._refresh_garden_tool_visible)
func is_garden_tool_available(tool_type: GardenManager.E_GardenTool) -> bool:
	if is_consumable_garden_tool(tool_type):
		return get_garden_tool_num(tool_type) > 0
	return is_garden_tool_bought(tool_type)
#endregion

## 禅境花园是否还有空位(原版: 花园满了就不卖金盏花幼苗,卖掉植物后才恢复)
## 未记录过的页视为全空(玩家还没进去摆过植物)
func has_empty_garden_cell() -> bool:
	for bg_type in get_owned_garden_bg_types():
		var cell_num := GardenManager.get_plant_cell_num_per_page(bg_type)
		var bg_data: Dictionary = state.garden_data.get(
			"第" + str(int(bg_type)) + "类背景", {})
		for page in range(get_garden_bg_page_num(bg_type)):
			var page_data: Dictionary = bg_data.get("第" + str(page) + "页", {})
			for i in range(cell_num):
				if page_data.get("第" + str(i) + "个植物格子", {}).is_empty():
					return true
	return false
#endregion
