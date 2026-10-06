extends Resource
class_name ResourceMapData

## 一张战斗地图（草坪 / 泳池 / 屋顶）的完整数据定义。
##
## 格子不再手摆在场景里 —— PlantCellManager / ZombieManager / GIM_LawnMover
## 在运行时按这份数据生成行与格子（见 docs/参考存档/地图实现.md）。
## 坐标相对主游戏场景的 PlantCellsRoot / ZombiesRoot（两者都在场景原点）。

## 这张地图配套的主游戏场景（前院 / 泳池 / 屋顶三选一），仅作标注与日志用：
## 真正用哪张图由关卡的 map_data 决定，不再靠「为单关单开场景枚举」反查
@export var game_sences: MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.MainGameFront
## 备注名（日志用）
@export var display_name: String = ""

## 本地图的背景动画脚本（MapBgAnimBase 子类）。
## 只管表现（泳池水面、浓雾、雨……），关卡逻辑不进它 —— BackgroundManager 在运行时
## 按它 new 一个节点挂到主游戏上，见 docs/参考存档/地图实现.md
@export var map_bg_script: GDScript
## 本地图的背景场景（PackedScene）：把地图专属的静态表现节点（背景贴图宿主、房子、
## 屋顶斜面、僵尸进家面板与落点）封装成一份 .tscn，BackgroundManager 在运行时按本字段
## 实例化并挂到 CanvasLayerBG 下。格子 / 僵尸行 / 小推车仍由本资源数据驱动生成（见 docs/参考存档/地图实现.md）。
@export var map_bg_scene: PackedScene
## 是否有屋顶斜面。斜面是**逻辑**（僵尸落位 / 小推车 / 子弹影子都要查它），
## 所以不进动画脚本，由 BackgroundManager 装配到 MainGameManager.main_game_slope
@export var have_slope: bool = false
## 僵尸进家面板矩形（Home/Door/DoorDown/PanelZombieGoHome），不同地图房门位置不同
@export var zombie_go_home_panel: Rect2 = Rect2(92, 0, 200, 600)
## 僵尸进家落点（Home/Door/DoorDown/PanelZombieGoHome/Marker2DZombieGoHome）
@export var zombie_go_home_marker: Vector2 = Vector2(72, 424)

## 可选的「无草皮」底图覆盖：非空时替换按 game_BG 选出的背景贴图。
## 用于冒险模式 1-1~1-3 —— 这些关用 background1unsodded（没铺草皮的底图），
## 再由 bg_sod_overlay 叠加草皮条；留空则继续按 game_BG 取背景。
@export var bg_base_texture: Texture2D
## 可选的草皮叠加贴图：非空时在底图上叠加草皮条（sod1row / sod3row），
## 仅覆盖地图里标记为 Grass 的行。见 BackgroundManager.init_sod_overlay()。
@export var bg_sod_overlay: Texture2D

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


## 自然刷怪用的关口行类型：忽略「不出怪」的行后，全部行同类型 → 该类型；水陆混合 → Both。
## 忽略 None 行很重要：1-1 / 1-2 那种只铺了部分草皮的图，若把 None 也算进去会误判成 Both，
## 于是水陆僵尸全部进白名单（见 level_data._init_zombie_refresh_from_whitelist）。
## 全是 None 行时按 Both 兜底 —— 此时本来也不会刷怪。
func get_default_zombie_row_type() -> CharacterRegistry.ZombieRowType:
	var first_type: CharacterRegistry.ZombieRowType = CharacterRegistry.ZombieRowType.None
	for row_data: ResourceMapRowData in rows:
		if row_data == null or row_data.zombie_row_type == CharacterRegistry.ZombieRowType.None:
			continue
		if first_type == CharacterRegistry.ZombieRowType.None:
			first_type = row_data.zombie_row_type
		elif row_data.zombie_row_type != first_type:
			return CharacterRegistry.ZombieRowType.Both
	if first_type == CharacterRegistry.ZombieRowType.None:
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
