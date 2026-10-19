extends Node
class_name BushManager
## 灌木丛管理器（结构与 TombStoneManager 同款：只维护「该位置有没有灌木」的二维表，
## 灌木实例自己长在 PlantCell 上，登记进 PlantCellManager.bush_list）

@onready var plant_cell_manager: PlantCellManager = %PlantCellManager

## 是否有灌木（二维）
var all_is_bush: Array[Array]
## 灌木数量
var bush_num := 0

func _ready() -> void:
	EventBus.subscribe(ConstEventName.CREATE_BUSH, create_bush)


## 初始化灌木管理器
## 只建立「该位置有没有灌木」的二维表（行列号由 PlantCellManager 统一赋值）
func init_bush_manager(_game_para: ResourceLevelData) -> void:
	for plant_cells_row_i in range(plant_cell_manager.all_plant_cells.size()):
		var plant_cells_row: Array = plant_cell_manager.all_plant_cells[plant_cells_row_i]
		var is_bush_row := []
		for _plant_cell in plant_cells_row:
			is_bush_row.append(false)
		all_is_bush.append(is_bush_row)


#region 灌木相关

## 生成待选位置：还没有灌木、也没有坑洞的格子
func _candidates_position(rows: int, cols_start: int, cols_end: int = plant_cell_manager.row_col.y) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for r in range(rows):
		for c in range(cols_start, cols_end):
			var plant_cell: PlantCell = plant_cell_manager.all_plant_cells[r][c]
			## 已经有灌木的位置、有坑洞的位置都跳过
			if all_is_bush[r][c] or is_instance_valid(plant_cell.crater):
				continue
			candidates.append(Vector2i(r, c))
	candidates.shuffle()
	return candidates


## 随机生成灌木的位置
## 与墓碑同款规则：先长草坪右侧三分之二（9 列里的第 4~9 列），右侧满了才轮到左三列。
## DLC 没给灌木的列区间口径，这里沿用墓碑的规则（保守，且灌木是障碍，长在右侧更挡人）
func _random_bush_pos(new_num: int) -> Array[Vector2i]:
	var rows = plant_cell_manager.row_col.x
	var cols = plant_cell_manager.row_col.y

	if new_num + bush_num >= rows * cols:
		var all_positions = _candidates_position(rows, 0, cols)
		return all_positions

	var usable_cols: int
	if bush_num < 6 * rows:
		usable_cols = clampi(cols - 6, 0, cols)
	else:
		usable_cols = cols

	var candidates = _candidates_position(rows, usable_cols)
	var selected_positions = candidates.slice(0, min(new_num, candidates.size()))

	if len(selected_positions) < new_num:
		var new_candidates = _candidates_position(rows, 0, usable_cols)
		var add_pos = new_candidates.slice(0, min(new_num - len(selected_positions), new_candidates.size()))
		selected_positions.append_array(add_pos)

	return selected_positions


## 创建一丛灌木
func _create_one_bush(plant_cell: PlantCell, pos: Vector2i) -> void:
	assert(not is_instance_valid(plant_cell.bush))
	assert(not all_is_bush[pos.x][pos.y], "第" + str(pos) + "灌木有问题")

	plant_cell.create_bush()
	plant_cell.signal_cell_delete_bush.connect(_delete_bush)

	all_is_bush[pos.x][pos.y] = true
	bush_num += 1


## 删除灌木修改对应的参数并断开信号连接
func _delete_bush(plant_cell: PlantCell, _bush: Bush) -> void:
	var pos: Vector2i = plant_cell.row_col
	all_is_bush[pos.x][pos.y] = false
	bush_num -= 1
	if plant_cell.signal_cell_delete_bush.is_connected(_delete_bush):
		plant_cell.signal_cell_delete_bush.disconnect(_delete_bush)


## 生成灌木（生成数量）
func create_bush(new_num: int) -> void:
	await get_tree().process_frame
	var selected_positions: Array[Vector2i] = _random_bush_pos(new_num)
	for pos in selected_positions:
		var plant_cell: PlantCell = plant_cell_manager.all_plant_cells[pos.x][pos.y]
		_create_one_bush(plant_cell, pos)

#endregion


#region 存档

func get_save_game_data_bush_manager() -> Dictionary:
	var save_game_data_bush_manager: Dictionary = {}
	save_game_data_bush_manager["all_is_bush"] = all_is_bush
	return save_game_data_bush_manager


func load_game_data_bush_manager(save_game_data_bush_manager: Dictionary) -> void:
	var new_all_is_bush: Array[Array] = save_game_data_bush_manager.get("all_is_bush", all_is_bush)
	for i in range(new_all_is_bush.size()):
		for j in range(new_all_is_bush[i].size()):
			var pos: Vector2i = Vector2i(i, j)
			if new_all_is_bush[i][j]:
				var plant_cell: PlantCell = plant_cell_manager.all_plant_cells[pos.x][pos.y]
				_create_one_bush(plant_cell, pos)

#endregion
