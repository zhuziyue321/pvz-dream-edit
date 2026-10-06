extends BeghouledManager
## 僵尸迷阵 旋风（Beghouled Twist）三消玩法管理器
##
## 原版迷你游戏第 9 关「僵尸迷阵 旋风」：与第 5 关「僵尸迷阵」同源，
## 区别只是玩家操作方式 —— 本关**顺时针旋转一个 2×2 的植物方块**来凑三消，
## 不是交换相邻两株。其它规则（棋盘 / 阳光 / 升级 / 弹坑 / 通关条件）与原版一致。
##
## 旋转规则：玩家点击一株植物，以它为左上角基准取一个 2×2 方块（点在最后一行/列时，
## 方块会自动往左上缩，保证不越界）。方块顺时针旋转 90°，若未凑成连线则自动转回。
##
## 谁在用它：**只有 minigame_09_beghouled_twist 一关**，所以与关卡脚本同目录、
## 文件名带本关前缀；继承的 `BeghouledManager`（与 05 共用）在 `src/levels/core/beghouled/`。
##
## 注：本脚本**没有 class_name**，由关卡脚本通过 preload 加载（避免动态加载的关卡脚本
## 在首次运行时找不到全局 class_name）。内部类型仍可用 BeghouledManager 接收。

## 旋转后到判定之间的停顿（秒）：让玩家看清方块转了一下
const ROTATE_WAIT := 0.22

## 当前高亮的 2×2 方块（4 个 ColorRect，点击后短暂显示）
var _block_highlights: Array[ColorRect] = []


## 覆盖基类的按下处理：旋风关是「点一下旋转」，按住拖动对它没意义（基类那条拖动链走不到这里）
func _on_press_cell(_cell: PlantCell) -> void:
	pass


## 覆盖基类的点击处理：旋风模式是「点一下旋转一个 2×2 方块」
func _on_click_cell(cell: PlantCell) -> void:
	if not _can_operate():
		return
	if not is_board_cell(cell):
		return
	if get_cell_plant(cell) == null:
		return
	var block := _get_twist_block(cell)
	if block.size() < 4:
		return
	for block_cell in block:
		if not is_board_cell(block_cell) or is_crater(block_cell) or get_cell_plant(block_cell) == null:
			return
	await _try_twist(block)


## 根据点击的格子，取出要旋转的 2×2 方块（点在最后一行/列时往左上靠）
func _get_twist_block(cell: PlantCell) -> Array[PlantCell]:
	var row := cell.row_col.x
	var col := cell.row_col.y
	var top := mini(row, board_row_num - 2)
	var left := mini(col, board_col_num - 2)
	return [
		get_cell(top, left),
		get_cell(top, left + 1),
		get_cell(top + 1, left),
		get_cell(top + 1, left + 1),
	]


## 顺时针旋转一个 2×2 方块；凑不成连线就转回来
func _try_twist(block: Array[PlantCell]) -> void:
	is_resolving = true
	_cancel_drag()
	_rotate_block(block, true)
	_show_block_highlight(block)
	await _wait(ROTATE_WAIT)
	_hide_block_highlight()
	if _find_match_groups(_build_type_grid()).is_empty():
		_rotate_block(block, false)
		await _wait(ROTATE_WAIT)
		is_resolving = false
		Log.debug("僵尸迷阵旋风：旋转没有凑成连线，已转回")
		return
	await _resolve_board()


## 旋转 2×2 方块：clockwise = true 时顺时针，false 时逆时针
## 四格顺序：0=左上 1=右上 2=左下 3=右下
## 顺时针后新位置：左上←左下、右上←左上、右下←右上、左下←右下
func _rotate_block(block: Array[PlantCell], clockwise: bool) -> void:
	var plants: Array[Plant000Base] = []
	for block_cell in block:
		plants.append(get_cell_plant(block_cell))
	## 先全部拿出来，避免同一格被反复覆盖
	for i in range(4):
		block[i].glove_take_plant(plants[i])
	## 新位置上的植物下标
	var new_indices: Array[int]
	if clockwise:
		new_indices = [2, 0, 3, 1]
	else:
		new_indices = [1, 3, 0, 2]
	for i in range(4):
		var place := block[i].glove_get_put_place(plants[new_indices[i]])
		block[i].glove_put_plant(plants[new_indices[i]], place)


## 覆盖基类：是否存在「旋转一次 2×2 就能凑成连线」的走法
func _has_possible_move() -> bool:
	var grid := _build_type_grid()
	for row in range(board_row_num - 1):
		for col in range(board_col_num - 1):
			if grid[row][col] == CharacterRegistry.PlantType.Null \
					or grid[row][col + 1] == CharacterRegistry.PlantType.Null \
					or grid[row + 1][col] == CharacterRegistry.PlantType.Null \
					or grid[row + 1][col + 1] == CharacterRegistry.PlantType.Null:
				continue
			var old: Array[CharacterRegistry.PlantType] = [
				grid[row][col], grid[row][col + 1],
				grid[row + 1][col], grid[row + 1][col + 1],
			]
			## 顺时针旋转后的值
			var rotated: Array[CharacterRegistry.PlantType] = [old[2], old[0], old[3], old[1]]
			grid[row][col] = rotated[0]
			grid[row][col + 1] = rotated[1]
			grid[row + 1][col] = rotated[2]
			grid[row + 1][col + 1] = rotated[3]
			var matched := _has_match_at(grid, row, col) \
				or _has_match_at(grid, row, col + 1) \
				or _has_match_at(grid, row + 1, col) \
				or _has_match_at(grid, row + 1, col + 1)
			grid[row][col] = old[0]
			grid[row][col + 1] = old[1]
			grid[row + 1][col] = old[2]
			grid[row + 1][col + 1] = old[3]
			if matched:
				return true
	return false


func _show_block_highlight(block: Array[PlantCell]) -> void:
	_hide_block_highlight()
	for block_cell in block:
		var rect := ColorRect.new()
		rect.color = Color(1.0, 1.0, 0.4, 0.28)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		block_cell.add_child(rect)
		_block_highlights.append(rect)


func _hide_block_highlight() -> void:
	for rect in _block_highlights:
		if rect.get_parent() != null:
			rect.get_parent().remove_child(rect)
		rect.queue_free()
	_block_highlights.clear()


func _cancel_drag() -> void:
	super._cancel_drag()
	_hide_block_highlight()
