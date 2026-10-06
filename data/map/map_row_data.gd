extends Resource
class_name ResourceMapRowData

## 地图里「一行」的定义，由 ResourceMapData.rows 持有。
## 坐标相对主游戏场景的 PlantCellsRoot（它在场景原点）。

## 该行格子地形（草地 / 水池 / 屋顶裸地）
@export var plant_cell_type: PlantCell.PlantCellType = PlantCell.PlantCellType.Grass
## 该行僵尸行类型（陆地 / 水路 / 两栖）
@export var zombie_row_type: CharacterRegistry.ZombieRowType = CharacterRegistry.ZombieRowType.Land
## 该行格子顶边 y
@export var row_y: float = 0.0
## 该行格子高
@export var row_height: float = 96.0
## 逐列额外 x 偏移（该行格子相对地图基准列的横向偏移；长度不足或为空表示该列为 0）
@export var col_dx: PackedFloat32Array = PackedFloat32Array()
## 逐列额外 y 偏移（屋顶斜面阶梯用；长度不足或为空表示该列为 0）
@export var col_dy: PackedFloat32Array = PackedFloat32Array()
## 该行僵尸生成点（全局坐标，僵尸原点在脚部）
@export var zombie_create_global_pos: Vector2 = Vector2(950.0, 0.0)
## 该行是否有小推车（false = 该行没有小推车，如原版没铺草皮的行）
@export var have_lawn_mover: bool = true
## 该行小推车类型（GIM_LawnMover.E_LawnMoverType）
@export var lawn_mover_type: int = 0
## 该行是否有钉耙
@export var have_rake: bool = false


## 第 col 列的额外 x 偏移
func get_col_dx(col: int) -> float:
	if col < 0 or col >= col_dx.size():
		return 0.0
	return col_dx[col]


## 第 col 列的额外 y 偏移
func get_col_dy(col: int) -> float:
	if col < 0 or col >= col_dy.size():
		return 0.0
	return col_dy[col]
