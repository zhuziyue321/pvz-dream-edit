extends ResourcePlantConditionCobCannon
## 「紫卡直接种植」模组：**玉米加农炮**没有两株玉米投手也能种
##
## 加农炮是「特殊紫卡」：本体走 `judge_special_plants_condition()`（不是紫卡那一支），
## 判据是"这一格与后一格各有一株玉米投手、且没套南瓜壳"。
## 这里在它后面再开一条路：两株投手都不在时，只要**后轮两格都空着**就能直接种，
## 代价与别的紫卡一样（基座植物的阳光 + 惩罚阳光，见 `PurpleDirectPlantRule`）。
##
## 加农炮自己会占住后轮那一格（`Plant048CobCannon.ready_norm()`），
## 所以本模组不需要替它登记格子 —— 只要保证种下去的那一刻后轮是空的。

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**，
## 所以同目录的文件一律 preload 成常量再引用
const Rule := preload("purple_direct_plant_rule.gd")

const COB_CANNON_TYPE := PlantIds.COB_CANNON


func judge_special_plants_condition(plant_cell: PlantCell) -> bool:
	## 有基座（两株玉米投手）：原版那条路，价格照常
	if get_preplant_purple(plant_cell, COB_CANNON_TYPE) != null:
		Rule.refresh_card_sun_cost(COB_CANNON_TYPE, false)
		return true
	## 没有基座：模组开的口子 —— 后轮两格都空着才给种，阳光要够付那个惩罚价
	if not _is_empty_place_for_cannon(plant_cell):
		return false
	Rule.refresh_card_sun_cost(COB_CANNON_TYPE, true)
	return Rule.can_afford_without_base(COB_CANNON_TYPE)


## 后轮两格都空着（本体 `condition_cob_cannon.gd` 的落位口径：不占最后一列、没有南瓜壳）
func _is_empty_place_for_cannon(plant_cell: PlantCell) -> bool:
	var main_game := GameContext.curr_main_game
	if main_game == null or main_game.plant_cell_manager == null:
		return false
	var manager := main_game.plant_cell_manager
	if plant_cell.row_col.y >= manager.row_col.y - 1:
		return false
	var next_cell: PlantCell = manager.all_plant_cells[plant_cell.row_col.x][plant_cell.row_col.y + 1]
	if next_cell == null:
		return false
	var cells: Array[PlantCell] = [plant_cell, next_cell]
	for cell in cells:
		if not cell.can_common_plant:
			return false
		if not plant_condition & cell.curr_condition:
			return false
		## 普通位置与壳位置都得空着：加农炮横跨两格，套了南瓜壳就没地方放
		if is_instance_valid(cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)):
			return false
		if is_instance_valid(cell.get_plant(CharacterRegistry.PlacePlantInCell.Shell)):
			return false
	return true
