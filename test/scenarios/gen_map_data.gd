extends RefCounted
## 一次性迁移工具：把「场景里手摆的格子」导出成 ResourceMapData。
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario gen_map_data
## 导出的 .tres 是数据驱动地图的唯一几何真相源，之后场景里的格子会被删掉。

const ENTRIES: Array[Dictionary] = [
	{
		"level": "res://src/levels/mode_adventure/adventure_01_01.gd",
		"out": "res://data/map/map_front.tres",
		"name": "front（白天草坪）",
	},
	{
		"level": "res://src/levels/mode_adventure/adventure_03_01.gd",
		"out": "res://data/map/map_pool.tres",
		"name": "pool（泳池/浓雾）",
	},
	{
		"level": "res://src/levels/mode_adventure/adventure_05_01.gd",
		"out": "res://data/map/map_roof.tres",
		"name": "roof（屋顶）",
	},
]


func run(a) -> void:
	for entry: Dictionary in ENTRIES:
		await _gen_one(a, entry)
	a.log("[GEN] ===== 全部完成 =====")
	a.quit_game()


func _gen_one(a, entry: Dictionary) -> void:
	var para: Resource = (load(entry["level"]) as GDScript).new()
	if para == null:
		a.log("!! 关卡加载失败: " + str(entry["level"]))
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)
	var mg = Global.main_game
	if mg == null:
		a.log("!! 进不了关卡: " + str(entry["name"]))
		return

	var pcm = mg.plant_cell_manager
	var root_pos: Vector2 = pcm.plant_cells_root.global_position
	var rows: Array = pcm.all_plant_cells
	var row_num: int = rows.size()
	var col_num: int = rows[0].size()
	var zm = mg.zombie_manager
	var mower_types: Array = mg.game_item_manager.gim_lawn_mover.all_lawn_movers_type

	var map_data := ResourceMapData.new()
	map_data.game_sences = para.game_sences
	map_data.display_name = str(entry["name"])

	## 基准列：第 0 行的格子矩形
	for c in range(col_num):
		var cell: Control = rows[0][c]
		var rect: Rect2 = cell.get_global_rect()
		map_data.col_x.append(rect.position.x - root_pos.x)
		map_data.col_width.append(rect.size.x)

	var max_col_w_diff := 0.0
	var max_row_h_diff := 0.0
	for r in range(row_num):
		var row_data := ResourceMapRowData.new()
		## 逐格矩形
		var rects: Array[Rect2] = []
		var heights: Array[float] = []
		for c in range(col_num):
			var cell: Control = rows[r][c]
			var rect: Rect2 = cell.get_global_rect()
			rects.append(Rect2(rect.position - root_pos, rect.size))
			heights.append(rect.size.y)
			max_col_w_diff = maxf(max_col_w_diff, absf(rect.size.x - map_data.col_width[c]))
			if cell.plant_cell_type != rows[r][0].plant_cell_type:
				a.log("  !! 第 %d 行地形不统一" % r)
		## 行高取该行出现次数最多的格子高（避免个别手摆误差把整行拉短）
		var row_height: float = heights[0]
		var best_count := 0
		for h in heights:
			var count := 0
			for h2 in heights:
				if is_equal_approx(h, h2):
					count += 1
			if count > best_count:
				best_count = count
				row_height = h
		## 基准行 y 取“行节点自身的 y”，也就是该行斜面阶梯的平地检测基准。
		## 不能取 rects[0].position.y（第 0 列被阶梯偏移后的绝对 y）：
		## 那会把整行的平地基准带偏（屋顶约 99px），植物/僵尸的检测面错开，互相不索敌。
		var row_node := rows[r][0].get_parent() as Node2D
		row_data.row_y = row_node.global_position.y - root_pos.y
		row_data.row_height = row_height
		row_data.plant_cell_type = rows[r][0].plant_cell_type
		for c in range(col_num):
			row_data.col_dx.append(rects[c].position.x - map_data.col_x[c])
			row_data.col_dy.append(rects[c].position.y - row_data.row_y)
			max_row_h_diff = maxf(max_row_h_diff, absf(rects[c].size.y - row_height))
		var zombie_row: Node = zm.all_zombie_rows[r]
		row_data.zombie_row_type = zombie_row.zombie_row_type
		row_data.zombie_create_global_pos = zombie_row.zombie_create_position.global_position
		row_data.have_rake = zombie_row.have_rake
		if r < mower_types.size():
			row_data.lawn_mover_type = int(mower_types[r])
		map_data.rows.append(row_data)

	a.log("[GEN] %s -> %s" % [str(entry["name"]), str(entry["out"])])
	a.log("   列x=%s" % str(map_data.col_x))
	a.log("   列宽=%s  跨行列宽最大偏差=%.2f 行内格高最大偏差=%.2f" % [
		str(map_data.col_width), max_col_w_diff, max_row_h_diff])
	for r in range(row_num):
		var row_data: ResourceMapRowData = map_data.rows[r]
		a.log("   行%d y=%.1f 高=%.1f 地形=%d 行类型=%d 生成点=%s 小推车=%d dy=%s dx=%s" % [
			r, row_data.row_y, row_data.row_height, row_data.plant_cell_type, row_data.zombie_row_type,
			str(row_data.zombie_create_global_pos), row_data.lawn_mover_type,
			str(row_data.col_dy), str(row_data.col_dx)])
	a.log("   数据自检=%s 默认行类型=%d" % [str(map_data.is_valid()), map_data.get_default_zombie_row_type()])

	var err: int = ResourceSaver.save(map_data, str(entry["out"]))
	a.log("   保存 err=%d" % err)
	await a.wait(0.5)
