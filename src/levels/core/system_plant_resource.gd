extends Resource
class_name SystemPlantResource
## 「系统种植」的一条植物数据：由系统代种，不消耗阳光、不需要卡片、不走手牌
##
## 用在 `LevelScriptBase.system_plant()`（关卡脚本 run_flow 里 `await`）和
## 「系统种植」时间轴事件上：开局摆造型 / 中途补种 / 屋顶铺花盆都走这条。
## 种法见 `PlantCellManager.system_plant_one()`。

## 植物类型
@export var plant_type :CharacterRegistry.PlantType
## 植物位置（从 1 起，0 表示整行 / 整列，见 system_plant_one）
@export var plant_cell_pos:Vector2i
## 是否为模仿者植物
@export var is_imitater_plant:bool = false


#region 批量构造
## 快捷构造「连续若干列花盆」 —— 屋顶 / 夜屋顶是裸地，没有花盆什么都种不下，
## 屋顶关都要先沿整列铺出种植位。
##
## `plant_cell_pos` 的语义（见 PlantCellManager.system_plant_one）：x = 0 表示整列，列号从 1 起，
## 所以「第 y 列整列」= `Vector2i(0, y)` —— 本函数就是批量造这一串 Vector2i 的，
## 省得每列手写一条 SystemPlantResource（铺 8 列要写 25 行）。
##
## 关卡脚本铺花盆走 `LevelScriptBase.plant_flower_pot_columns()`（在 run_flow() 里 await，
## 本函数只是给它凑数据）；要给「系统种植」单独凑数据时也可以直接用本函数。
## [col_count] 铺几列（<= 0 时不铺，只打一条警告）
## [begin_col] 从第几列开始铺（从 1 起）
static func create_flower_pot_columns(col_count: int, begin_col: int = 1) -> Array[SystemPlantResource]:
	var result: Array[SystemPlantResource] = []
	if col_count <= 0 or begin_col <= 0:
		Log.warn(str("铺花盆列的参数不合法，本次一列都不铺：col_count=", col_count, " begin_col=", begin_col))
		return result
	for i in col_count:
		var pot := SystemPlantResource.new()
		pot.plant_type = CharacterRegistry.PlantType.P034FlowerPot
		pot.plant_cell_pos = Vector2i(0, begin_col + i)
		result.append(pot)
	return result
#endregion
