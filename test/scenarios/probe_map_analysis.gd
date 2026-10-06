extends RefCounted
## 探针：地图（草坪/泳池/屋顶）实现取证。
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_map_analysis
## 打印每张地图的网格数据、每格 rect/屏幕中心/地形、僵尸行与生成点、小推车、斜面，
## 并核对 PlantCell.row_col 与 all_plant_cells 下标是否一致。

const LEVELS: Array[String] = [
	## 1-1：5 行草坪，只有中间 1 行铺了草皮（map_front_1row）
	"res://src/levels/mode_adventure/adventure_01_01.gd",
	## 1-2 / 1-3：5 行草坪（map_front_5row）
	"res://src/levels/mode_adventure/adventure_01_02.gd",
	"res://src/levels/mode_adventure/adventure_03_01.gd",
	"res://src/levels/mode_adventure/adventure_05_01.gd",
]

const ProbeUtil := preload("res://test/scenarios/probe_util.gd")


func run(a) -> void:
	a.log("[MAP] ===== 探针开始 =====")
	for path in LEVELS:
		await _probe_scene(a, path)
	a.log("[MAP] ===== 探针结束 =====")
	a.quit_game()


func _probe_scene(a, path: String) -> void:
	var para: Resource = (load(path) as GDScript).new()
	if para == null:
		a.log("!! 关卡加载失败: " + path)
		return
	Global.game_para = para
	var scene_path: String = Global.main_scene_registry.MainScenesMap[para.game_sences]
	a.log("[MAP][SCENE] %s -> %s" % [path.get_file(), scene_path])
	a.get_tree().change_scene_to_file(scene_path)
	await a.wait(3.0)
	var mg = Global.main_game
	if mg == null:
		a.log("   !! Global.main_game 为空")
		return
	## 推车是关卡流程里的一项（「准备-安放-植物」之前登场，见 LevelTimelineEventLawnMover），
	## 这里替玩家点「开始游戏」并等推车到位，否则下面打出来的一定是「没有推车」
	await ProbeUtil.click_start(a)
	await ProbeUtil.wait_lawn_mowers(a, 20.0)
	a.log("   canvas_origin=%s" % str(a.canvas_origin()))
	var map_data = para.map_data
	if map_data == null:
		a.log("   !! 关卡没有地图数据")
	else:
		a.log("   地图数据 %s：%d 行 × %d 列  game_sences=%d  默认行类型=%d" % [
			map_data.display_name, map_data.get_row_num(), map_data.get_col_num(),
			map_data.game_sences, map_data.get_default_zombie_row_type()])
		a.log("   col_x=%s" % str(map_data.col_x))
		a.log("   col_width=%s" % str(map_data.col_width))
	_dump_grid(a, mg)
	_dump_zombie_rows(a, mg)
	_dump_mowers(a, mg)
	_dump_slope(a, mg)


## 植物格子：逐行打印每个格子的 rect / 屏幕中心 / 地形，并核对两套索引
func _dump_grid(a, mg) -> void:
	var pcm = mg.plant_cell_manager
	var cells: Array = pcm.all_plant_cells
	a.log("   网格 row_col=%s（行x列）" % str(pcm.row_col))
	for r in range(cells.size()):
		var row_cells: Array = cells[r]
		var first: Control = row_cells[0]
		var row_node: Node = first.get_parent()
		a.log("   行%d 节点=%s class=%s z_index=%d 首格rect=%s" % [
			r, str(row_node.name), row_node.get_class(), row_node.z_index, str(first.get_rect())])
		var parts: Array[String] = []
		var mism := 0
		for c in range(row_cells.size()):
			var cell: Control = row_cells[c]
			if cell.row_col != Vector2i(r, c):
				mism += 1
			parts.append("col%d(row_col=%s,rect=%s,sx=%.1f,sy=%.1f,t=%d)" % [
				c, str(cell.row_col), str(cell.get_rect()), a.screen_center(cell).x,
				a.screen_center(cell).y, cell.plant_cell_type])
		a.log("     " + " ".join(parts))
		a.log("     row_col 与 all_plant_cells 索引不一致的列数=%d" % mism)


## 僵尸行：节点类型 / z_index / 行类型 / 生成点
func _dump_zombie_rows(a, mg) -> void:
	var zm = mg.zombie_manager
	var rows: Array = zm.all_zombie_rows
	a.log("   僵尸行数=%d" % rows.size())
	for i in range(rows.size()):
		var row: Node = rows[i]
		var zcp: Node2D = row.zombie_create_position
		a.log("   僵尸行%d %s class=%s z_index=%d row_type=%d 生成点=%s 钉耙=%s" % [
			i, str(row.name), row.get_class(), row.z_index, row.zombie_row_type,
			str(zcp.global_position), str(row.have_rake)])


func _dump_mowers(a, mg) -> void:
	var gim = mg.game_item_manager
	if gim == null:
		return
	var lm = gim.gim_lawn_mover
	a.log("   小推车 数量=%d 类型=%s 位置=%s" % [
		lm.all_lawn_movers.size(), str(lm.all_lawn_movers_type), str(lm.all_lawn_movers_global_pos)])


func _dump_slope(a, mg) -> void:
	var slope = mg.main_game_slope
	if slope == null:
		a.log("   斜面=无（平地）")
		return
	a.log("   斜面 数量=%d" % slope.all_slopes.size())
	for s in slope.all_slopes:
		a.log("     %s x范围=%s start=%s end=%s" % [
			str(s.name), str(s.slope_global_pos_x_range), str(s.start_pos_slope), str(s.end_pos_slope)])
