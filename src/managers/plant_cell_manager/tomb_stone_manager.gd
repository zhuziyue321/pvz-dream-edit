extends Node
class_name TombStoneManager

@onready var plant_cell_manager: PlantCellManager = %PlantCellManager

## 是否有墓碑(二维)
var all_is_tombstone:Array[Array]
## 墓碑数量
var tombstone_num := 0

func _ready() -> void:
	## 注册创建墓碑全局事件
	EventBus.subscribe("create_tombstone", create_tombstone)

## 初始化墓碑管理器
## 只建立「该位置有没有墓碑」的二维表。格子行列号由 PlantCellManager 统一赋值，
## 这里不要再写一遍（曾经写成「列号 = 行内倒序下标」，与 all_plant_cells 的下标方向相反，
## 只靠 init_manager 的调用顺序才被覆盖回正确值）。
func init_tomb_stone_manager(_game_para:ResourceLevelData):
	for plant_cells_row_i in range(plant_cell_manager.all_plant_cells.size()):
		var plant_cells_row:Array = plant_cell_manager.all_plant_cells[plant_cells_row_i]
		var is_tombstone_row := []
		for _plant_cell in plant_cells_row:
			## 该位置没有墓碑
			is_tombstone_row.append(false)

		all_is_tombstone.append(is_tombstone_row)

#region 墓碑相关
## 生成待选位置,没有墓碑的行和列
## 原版:墓碑不长在坑洞上(用毁灭菇把第 4~9 列铺满坑洞就能阻止墓碑生长)
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Grave_(PvZ) "Survival: Night Levels")
func _candidates_position(rows:int, cols_start:int, cols_end:int=plant_cell_manager.row_col.y) -> Array[Vector2i]:
	# 构建可选位置列表
	var candidates: Array[Vector2i]= []
	for r in range(rows):
		for c in range(cols_start, cols_end):
			var plant_cell:PlantCell = plant_cell_manager.all_plant_cells[r][c]
			## 已经有墓碑的位置,以及有坑洞的位置都跳过
			if all_is_tombstone[r][c] or is_instance_valid(plant_cell.crater):
				continue
			candidates.append(Vector2i(r, c))

	# 打乱顺序确保随机性
	candidates.shuffle()
	return candidates

## 随机生成墓碑的位置
func _reandom_tombstone_pos(new_num:int) ->  Array[Vector2i]:
	var rows = plant_cell_manager.row_col.x
	var cols = plant_cell_manager.row_col.y

	# 如果请求的数量超过所有格子总数，就返回所有格子
	if new_num + tombstone_num >= rows * cols:
		## 候选区间是 [cols_start, cols_end)：要「全部列」必须写 (rows, 0, cols)。
		## 只传 cols 会让起点 == 终点，得到空区间，一个墓碑都长不出来
		var all_positions = _candidates_position(rows, 0, cols)
		return all_positions

	var usable_cols : int
	## 原版:墓碑只长草坪右侧三分之二(9 列里的第 4~9 列,即 0 基列 3~8);
	## 右侧区域被墓碑占满后才轮到左三列。这里用「候选列区间 = [usable_cols, cols)」表达:
	##   · 右侧没满 → 起点夹紧到 cols-6,只在第 4~9 列(0 基 3~8)长
	##   · 右侧满了 → 起点 = cols,主候选为空,下面的兜底会退回 [0, cols) 全列
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Grave_(PvZ))
	## 当场上墓碑数量小于 6列 * 行数时
	if tombstone_num < 6 * rows:
		## 列数少于 6 的关卡会得到负数列号（Godot 负索引会环回），这里夹紧到 [0, cols]
		usable_cols = clampi(cols - 6, 0, cols)
	else:
		usable_cols = cols

	# 构建可选位置列表
	var candidates = _candidates_position(rows, usable_cols)
	Log.debug(str("待选位置") + str(candidates))
	# 取前n个作为随机选择位置
	var selected_positions = candidates.slice(0, min(new_num, candidates.size()))

	if len(selected_positions) < new_num:
		# 构建可选位置列表
		var new_candidates = _candidates_position(rows, 0, usable_cols)
		var add_pos = new_candidates.slice(0, min(new_num- len(selected_positions), new_candidates.size()))

		selected_positions.append_array(add_pos)

	Log.debug(str("墓碑生成位置：") + str(selected_positions))

	return selected_positions

## 创建一个墓碑
func _create_one_tombstone(plant_cell: PlantCell, pos:Vector2i):
	assert(not is_instance_valid(plant_cell.tombstone))
	assert(not all_is_tombstone[pos.x][pos.y], "第"+str(pos)+"墓碑有问题")

	## plant_cell生成墓碑并连接信号
	plant_cell.create_tombstone()
	plant_cell.signal_cell_delete_tombstone.connect(_delete_tombstone)

	# 创建墓碑相关参数变化
	all_is_tombstone[pos.x][pos.y] = true
	tombstone_num += 1


## 删除墓碑修改对应的参数并断开信号连接
func _delete_tombstone(plant_cell:PlantCell, _tombstone:TombStone):
	var pos:Vector2i = plant_cell.row_col
	all_is_tombstone[pos.x][pos.y] = false
	tombstone_num -= 1
	## 先判断再断开：信号被重复发射时，第二次 disconnect 会报 "nonexistent connection"
	if plant_cell.signal_cell_delete_tombstone.is_connected(_delete_tombstone):
		plant_cell.signal_cell_delete_tombstone.disconnect(_delete_tombstone)


## 黑夜关卡生成墓碑（生成数量）
func create_tombstone(new_num:int):
	await get_tree().process_frame
	## 最大数量： 最大可生成列数 * 行数
	## 生成随机位置
	Log.debug(str("墓碑生成数量") + str(new_num))
	var selected_positions :Array[Vector2i]= _reandom_tombstone_pos(new_num)

	Log.debug(str("墓碑生成位置") + str(selected_positions))
	for pos in selected_positions:
		var plant_cell:PlantCell = plant_cell_manager.all_plant_cells[pos.x][pos.y]

		_create_one_tombstone(plant_cell, pos)


#endregion

#region 存档

func get_save_game_data_tomb_stone_manager()->Dictionary:
	var save_game_data_tomb_stome_manager:Dictionary = {}
	save_game_data_tomb_stome_manager["all_is_tombstone"] = all_is_tombstone

	return save_game_data_tomb_stome_manager

func load_game_data_tomb_stone_manager(save_game_data_tomb_stome_manager:Dictionary):
	var new_all_is_tombstone:Array[Array] = save_game_data_tomb_stome_manager.get("all_is_tombstone", all_is_tombstone)
	for i in range(new_all_is_tombstone.size()):
		for j in range(new_all_is_tombstone[i].size()):
			var pos:Vector2i = Vector2i(i,j)
			if new_all_is_tombstone[i][j]:
				var plant_cell:PlantCell = plant_cell_manager.all_plant_cells[pos.x][pos.y]
				_create_one_tombstone(plant_cell, pos)

#endregion
