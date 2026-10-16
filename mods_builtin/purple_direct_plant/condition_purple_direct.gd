extends ResourcePlantCondition
## 「紫卡直接种植」模组：紫卡**没有基座也允许种**的种植条件
##
## 本体的紫卡判定（`ResourcePlantCondition.judge_is_can_plant()`）只有一条：
##   格子上有它的基座植物（`get_preplant_purple()`）才能种 —— 原版就是这样。
## 这里在它后面再开一条路：基座不在时，按**普通植物的落位条件**判（地形符合 + 该位置为空），
## 代价是价格加一截（见 `PurpleDirectPlantRule`，规则与价格都写在那一份里）。
##
## 为什么是"换掉整个条件资源"而不是改几个字段：能不能种是**方法**里的逻辑，
## 字段改不动；所以由模组入口造一份本类的实例、字段照抄原版那份，
## 再用 `CharacterRegistry.set_runtime_plant_condition()` 换上去（关掉模组就换回来）。

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**，
## 所以同目录的文件一律 preload 成常量再引用
const Rule := preload("purple_direct_plant_rule.gd")


func judge_is_can_plant(plant_cell: PlantCell, curr_plant_type: StringName) -> bool:
	## 格子限种（观星的星星轮廓点）：所有植物都要先过这一关，与本体保持一致
	if not plant_cell.is_plant_type_allowed(curr_plant_type):
		return false
	## 有基座：原版那条路 —— 种在基座上，价格照常
	if get_preplant_purple(plant_cell, curr_plant_type) != null:
		Rule.refresh_card_sun_cost(curr_plant_type, false)
		return true
	## 没有基座：模组开的口子 —— 落位条件与普通植物同一套，阳光要够付那个惩罚价
	if not _is_empty_place(plant_cell):
		return false
	Rule.refresh_card_sun_cost(curr_plant_type, true)
	return Rule.can_afford_without_base(curr_plant_type)


## 紫卡**随时可点**：原版要先有基座才点亮卡片，本模组允许直接种，也就没有这条门槛
## （阳光够不够由卡片自己判，与别的植物一样）
func judge_purple_card_can_plant(_all_plant_cells: Array,
		_curr_plant_type: StringName) -> bool:
	return true


## 没有基座时的落位条件：与本体普通植物那一支完全相同（地形符合 + 该位置为空）
func _is_empty_place(plant_cell: PlantCell) -> bool:
	return plant_cell.can_common_plant \
		and plant_condition & plant_cell.curr_condition \
		and not is_instance_valid(plant_cell.get_plant(place_plant_in_cell))
