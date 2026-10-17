extends Zombie001Norm
## 「招笑版」模组：**路障僵尸变种**（「绊倒路障僵尸」）—— 戴路障的普通僵尸，四件事：
##
##   1. **速度 = 普通僵尸的 10 倍**：`random_speed_range` 设成 10，让基类 deferred 的
##      `init_random_speed()` 读到的初始速度系数就是 10 ⇒ 动画倍速 10 倍 ⇒ 实际横移 10 倍
##      （与「闪电掉头僵尸」同一招）。
##   2. **无视植物**：整个禁用 `attack_component`（它会顺带把 `detect_component` 也禁用），
##      僵尸永远不进「啃食」、永远不置 `is_attack`，走到植物面前也不停、不啃、直接穿过去。
##      （植物照样能打它 —— 只是它不理植物。）
##   3. **走到第 4 列摔倒**：从僵尸入场一侧（右侧）数第 `CONE_ZOMBIE_FALL_COLUMN_FROM_RIGHT`
##      列，走到那一列就**摔倒**（挂 `zhaoxiao_fall.gd`：趴地上 `FALL_TIME` 秒再站起来），
##      同时头上的路障掉在地上。
##   4. **路障永久留在草坪上**：掉下来的路障是 `zhaoxiao_cone_drop.gd`（跟着僵尸行活到关尾），
##      后来走到它身上的僵尸都会被绊倒（挂同一个摔倒状态）。
##
## 本体复用路障僵尸场景（`zombie_cone.tscn`：头上的路障防具、破损外观、掉落物子树整套现成），
## 只改行为，是「僵尸热注册」（`ZombieRuntimeRecipe`）那条路：本体 + 本脚本。
##
## 关联：[僵尸热注册] / `mods_builtin/zhaoxiao/zhaoxiao_mod.gd` / `zhaoxiao_fall.gd`

const Settings := preload("zhaoxiao_settings.gd")
const FallStatus := preload("zhaoxiao_fall.gd")
const ConeDrop := preload("zhaoxiao_cone_drop.gd")

## 头上路障的节点（本体防具被打掉时藏的也是这一处，见 `zombie_cone.tscn` 的 body_change）
const CONE_SPRITE_PATH := ^"Body/BodyCorrect/Anim_cone"

## 摔倒那一列的世界 x（朝左走、x 递减；降到这以下就摔）
var _fall_x := INF
## 是否已经摔过（摔倒只触发一次：先被地上路障绊倒的那次不算，起来了走到第 4 列还会摔）
var _has_fallen := false


func ready_norm() -> void:
	## 先改速度范围，让基类 deferred 的 `init_random_speed()` 读到 10 倍
	random_speed_range = Vector2(Settings.CONE_ZOMBIE_SPEED, Settings.CONE_ZOMBIE_SPEED)
	super()
	## 无视植物：攻击组件整个禁用 ⇒ 永不啃食、永不因植物停下
	if is_instance_valid(attack_component):
		attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	## 算摔倒那一列的世界 x（只在真正进战斗时有主游戏、且是战斗态）
	_compute_fall_x()


func ready_show() -> void:
	super()
	## 图鉴 / 开局预览的展示态：不提速、不算摔倒列，避免展示态自己乱跑、摔下去
	## （展示态 `character_init_type` 是 `IsShow`，`_compute_fall_x()` 会自动跳过）


## 取本关格子布局，算出「从右侧数第 N 列」的中心 x
func _compute_fall_x() -> void:
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
	var target_col := clampi(col_num - Settings.CONE_ZOMBIE_FALL_COLUMN_FROM_RIGHT, 0, col_num - 1)
	var cell: PlantCell = row_cells[target_col] as PlantCell
	if cell == null:
		return
	_fall_x = cell.global_position.x + cell.size.x * 0.5


func _process(_delta: float) -> void:
	## 只在真正战斗里生效：展示态 / 已死亡 / 已经摔过都不再触发
	if is_death or character_init_type != Character000Base.E_CharacterInitType.IsNorm:
		return
	if _has_fallen or is_inf(_fall_x):
		return
	## 朝左（direction_x_root > 0）走到目标列就摔
	if direction_x_root > 0 and global_position.x <= _fall_x:
		_fall_and_drop_cone()


## 摔倒 + 把路障掉在草坪上
func _fall_and_drop_cone() -> void:
	_has_fallen = true
	_spawn_cone_drop()
	_drop_cone_armor()
	## 已经倒着的（先被地上的路障绊过一次）就不再挂第二次
	if get_node_or_null(FallStatus.NODE_PATH) == null:
		var fall := FallStatus.new()
		fall.name = FallStatus.NODE_NAME
		add_child(fall)


## 在摔倒点留下一根永久的路障（挂在僵尸行节点上，跟着这一行活到关尾）
func _spawn_cone_drop() -> void:
	var mg := get_main_game()
	if mg == null or mg.zombie_manager == null:
		return
	if lane < 0 or lane >= mg.zombie_manager.all_zombie_rows.size():
		return
	var row: ZombieRow = mg.zombie_manager.all_zombie_rows[lane]
	if row == null:
		return
	var drop := ConeDrop.new()
	drop.name = ConeDrop.NODE_NAME
	## 先 setup 再入树（`_ready()` 里要读 lane）
	drop.setup(lane, self)
	row.add_child(drop)
	## 入树之后再摆世界坐标（路障就躺在摔倒点，y 用僵尸当前所在地面线）
	drop.global_position = Vector2(global_position.x, global_position.y)


## 把头上的路障摘掉：藏起 sprite + 摘掉防具节点
##
## ⚠️ 不走 `break_armor()`（伤害管线）：那条路会顺带播场景里那个「弹一下淡出」的
##   掉落节点（`Body/NodeDrop/Node2D_Arm1_Drop`），与「永久留在草坪上」不是一回事。
##   这里照 more_armor 换防具那招：`remove_child` + `queue_free`，再让血量组件重收一遍
##   （防具表是它一次性收集的，少了这一步那一层还挂在表里 —— 而且是静默的）。
func _drop_cone_armor() -> void:
	var cone_sprite := get_node_or_null(CONE_SPRITE_PATH) as Node2D
	if cone_sprite != null:
		cone_sprite.visible = false
	var armor := get_armor(ConstArmor.E_ArmorType.Cone)
	if armor == null:
		return
	remove_child(armor)
	armor.queue_free()
	var zombie_hp := hp_component as HpComponentZombie
	if zombie_hp != null:
		zombie_hp.collect_armors()
