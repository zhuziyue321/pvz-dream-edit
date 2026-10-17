extends Zombie001Norm
## 「招笑版」模组：闪电掉头僵尸 —— 普通僵尸的变种
##
## 三种行为（都只动自己、不动本体）：
##   1. **速度 = 普通僵尸的 10 倍**：`random_speed_range` 设成 10，让基类 deferred 的
##      `init_random_speed()` 读到的初始速度系数就是 10。普通僵尸靠动画驱动位移
##      （`MoveComponent.E_MoveMode.Ground`，见 `level_data.gd` 注释），动画倍速 10 倍
##      ⇒ 实际横向移动速度就是 10 倍。
##   2. **无视植物**：整个禁用 `attack_component`（它会顺带把 `detect_component` 也禁用，
##      见 `component_attack_base.gd` 的 `disable_component`），僵尸永远不进入「啃食」、
##      永远不置 `is_attack`，于是走到植物面前也不停、不啃、直接穿过去。
##      （植物照样能打它 —— 只是它不理植物。）
##   3. **走到第 N 列自己掉头**：从僵尸入场一侧（右侧）数第 `TURN_COLUMN_FROM_RIGHT` 列，
##      走到那一列就 `update_direction_x_root(-1)` 翻向右，往屏幕外走；离开草坪即 `queue_free()`，
##      不永久占着场。N 的口径见 `TURN_COLUMN_FROM_RIGHT` 注释。
##
## 复用普通僵尸本体（`res://src/entities/character/zombie/zombie_norm.tscn`）与全部外观，
## 只改行为，是「僵尸热注册」（`ZombieRuntimeRecipe`）那条路：本体 + 本脚本。
##
## 关联：[僵尸热注册] / `mods_builtin/zhaoxiao/zhaoxiao_mod.gd` / `zombie_runtime_recipe.gd`

## 速度倍数（相对普通僵尸的动画倍速）
const SPEED_MULTIPLIER := 10.0

## 从僵尸入场一侧（右侧）数起，走到第几列自己掉头。
## 普通草坪 9 列，右侧第 4 列即 0-based 下标 5；若想「从房子一侧（左侧）数第 N 列」，
## 把 `_compute_turn_and_spawn_x()` 里的 `col_num - TURN_COLUMN_FROM_RIGHT` 改成
## `TURN_COLUMN_FROM_RIGHT - 1` 即可。
const TURN_COLUMN_FROM_RIGHT := 4

## 掉头用的世界 x（普通僵尸朝左走、x 递减；降到这以下就翻向右）
var _turn_x := INF
## 进入关卡时的 x（掉头后往右走出草坪、超过它就把僵尸移除，免得永久占场）
var _spawn_x := INF
## 是否已经掉过头
var _has_turned := false


func ready_norm() -> void:
	## 先改速度范围，让基类 deferred 的 `init_random_speed()` 读到 10 倍
	random_speed_range = Vector2(SPEED_MULTIPLIER, SPEED_MULTIPLIER)
	super()
	## 无视植物：攻击组件整个禁用 ⇒ 永不啃食、永不因植物停下
	if is_instance_valid(attack_component):
		attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	## 计算掉头列的世界 x 与入场 x（只在真正进战斗时有主游戏、且是战斗态）
	_compute_turn_and_spawn_x()


func ready_show() -> void:
	super()
	## 图鉴 / 开局预览的展示态：不提速、不算掉头，避免展示态自己乱跑
	## （展示态 `character_init_type` 是 `IsShow`，`_compute_turn_and_spawn_x` 会自动跳过）


## 取本关格子布局，算出「从右侧数第 N 列」的中心 x 与入场 x
func _compute_turn_and_spawn_x() -> void:
	if character_init_type != Character000Base.E_CharacterInitType.IsNorm:
		return
	var mg := get_main_game()
	if mg == null or mg.plant_cell_manager == null:
		return
	var cells: Array = mg.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= cells.size():
		return
	var row_cells: Array = cells[lane]
	var col_num := row_cells.size()
	## 从右侧数第 N 列的 0-based 下标（clamp 到合法范围，列数不足时退化成最右列）
	var target_col := clampi(col_num - TURN_COLUMN_FROM_RIGHT, 0, col_num - 1)
	var cell: PlantCell = row_cells[target_col] as PlantCell
	if cell == null:
		return
	_turn_x = cell.global_position.x + cell.size.x * 0.5
	_spawn_x = global_position.x


func _process(_delta: float) -> void:
	## 只在真正战斗里生效：展示态 / 已死亡都不掉头、不移除
	if is_death or character_init_type != Character000Base.E_CharacterInitType.IsNorm:
		return
	## 掉头：朝左（direction_x_root > 0）走到目标列就翻向右
	if not _has_turned and direction_x_root > 0 and not is_inf(_turn_x) \
			and global_position.x <= _turn_x:
		update_direction_x_root(-1)
		_has_turned = true
	## 掉头后往右走出草坪、超过入场点就移除，免得永久占着场
	if _has_turned and not is_inf(_spawn_x) and global_position.x > _spawn_x:
		queue_free()
