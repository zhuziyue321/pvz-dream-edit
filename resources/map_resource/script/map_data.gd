extends Resource
class_name ResourceMapData

## 一张战斗地图（草坪 / 泳池 / 屋顶）的完整数据定义。
##
## 格子不再手摆在场景里 —— PlantCellManager / ZombieManager / GIM_LawnMover
## 在运行时按这份数据生成行与格子（见 docs/地图实现.md）。
## 坐标相对主游戏场景的 PlantCellsRoot / ZombiesRoot（两者都在场景原点）。

## 这张地图配套的主游戏场景：只提供美术（背景、泳池、屋顶斜面、房子）
@export var game_sences: MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.MainGameFront
## 备注名（日志用）
@export var display_name: String = ""

## 每列左边缘 x（长度 = 列数）
@export var col_x: PackedFloat32Array = PackedFloat32Array()
## 每列格子宽（长度 = 列数）
@export var col_width: PackedFloat32Array = PackedFloat32Array()
## 每行定义（长度 = 行数）
@export var rows: Array[ResourceMapRowData] = []


func get_row_num() -> int:
	return rows.size()


func get_col_num() -> int:
	return col_x.size()


## 第 row 行第 col 列的格子矩形
func get_cell_rect(row: int, col: int) -> Rect2:
	var row_data: ResourceMapRowData = rows[row]
	return Rect2(
		col_x[col] + row_data.get_col_dx(col),
		row_data.row_y + row_data.get_col_dy(col),
		col_width[col],
		row_data.row_height
	)


## 自然刷怪用的关口行类型：全部行同类型 → 该类型；水陆混合 → Both
func get_default_zombie_row_type() -> CharacterRegistry.ZombieRowType:
	if rows.is_empty():
		return CharacterRegistry.ZombieRowType.Both
	var first_type: CharacterRegistry.ZombieRowType = rows[0].zombie_row_type
	for row_data: ResourceMapRowData in rows:
		if row_data.zombie_row_type != first_type:
			return CharacterRegistry.ZombieRowType.Both
	return first_type


## 数据是否自洽：列数 > 0、行数 > 0、每行高度/列宽合法，行数与僵尸生成点数量一致
func is_valid() -> bool:
	var ok := true
	if get_row_num() <= 0 or get_col_num() <= 0:
		Log.error("地图数据非法(%s)：%d 行 × %d 列" % [display_name, get_row_num(), get_col_num()])
		return false
	if col_width.size() != col_x.size():
		Log.error("地图数据非法(%s)：col_x 与 col_width 长度不一致" % display_name)
		ok = false
	for i in range(get_row_num()):
		var row_data: ResourceMapRowData = rows[i]
		if row_data == null:
			Log.error("地图数据非法(%s)：第 %d 行为空" % [display_name, i])
			ok = false
			continue
		if row_data.row_height <= 0.0:
			Log.error("地图数据非法(%s)：第 %d 行高度为 %f" % [display_name, i, row_data.row_height])
			ok = false
	return ok
