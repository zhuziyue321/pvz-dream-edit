extends Node2D
class_name CellStarOverlay
## 通用的「格子植物虚影层」：给一批格子各摆一棵**半透明、不动的植物**，
## 「这一格达标没有」用两套透明度区分 —— 没达标的亮、达标的暗。
##
## **本节点不含任何玩法规则** —— 标记哪些格子、显示哪种植物、什么算达标，全部由使用方（关卡脚本）
## 在 init_item() 时传进来；这里只负责显示，以及格子上的植物变化时刷新透明度。
## 观星（迷你游戏第 7 关）是目前的唯一使用者，规则都在
## src/levels/mode_minigame/minigame_07_seeing_stars.gd。
## 本文件就放在**关卡侧**（与那关的脚本同目录）：只服务一关的东西不进游戏本体（硬约束 §1-8）。
##
## 虚影的形象 = 「某种植物的 idle 动画的某一帧」，走 AnimationFrameUtil.create_frame_node() 取：
## 它先把脚本 / AnimationTree / 碰撞体剥掉再定格，拿到的是一棵**不会再有任何行为**的植物，
## 可以直接当草坪上的静态装饰挂出来（原版 reanim 素材本来就是一帧一帧播的）。
## 不用卡片里那套手摆的 CharacterStatic —— 它的杨桃 idle 主视觉缺贴图（没有身体），
## 而且那里已经按卡片尺寸缩过 + 偏移过。

## 还没达标的格子：亮一些，玩家一眼看出「该动哪一格」
const ALPHA_TODO := 0.45
## 已经达标的格子：压暗，剩下的空格更显眼
const ALPHA_DONE := 0.14

## 被标记的格子
var cells: Array[PlantCell] = []
## 「这一格算不算达标」的判定，由使用方传入（签名 (PlantCell) -> bool）
var is_cell_done: Callable
## 每个格子对应的虚影节点，与 cells 同序（格子失效的项为 null）
var ghosts: Array[Node2D] = []


## [cells_value] 要标记的格子
## [plant_scene] 虚影显示哪种植物的场景
## [idle_anim_name] 定格在这个动画的第 0 帧（一般就是 idle）
## [is_cell_done_value] 达标判定；不传时全部按「未达标」显示
func init_item(cells_value: Array[PlantCell], plant_scene: PackedScene, idle_anim_name: StringName,
		is_cell_done_value: Callable = Callable()) -> void:
	cells.assign(cells_value)
	is_cell_done = is_cell_done_value
	_build_ghosts(plant_scene, idle_anim_name)
	## 格子上的植物种上 / 掉光时刷新透明度，让「还差几个」看得见
	for plant_cell: PlantCell in cells:
		if plant_cell.signal_plant_create.is_connected(_on_cell_plant_changed):
			continue
		plant_cell.signal_plant_create.connect(_on_cell_plant_changed)
		plant_cell.signal_plant_free.connect(_on_cell_plant_changed)
	_refresh_alpha()


## 清理：断开格子信号、释放自己 —— **可重复调用**
## （关卡结束时调一次、重进关时可能再调一次；已排队释放的节点直接忽略）
func free_item() -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	for plant_cell: PlantCell in cells:
		if not is_instance_valid(plant_cell):
			continue
		if plant_cell.signal_plant_create.is_connected(_on_cell_plant_changed):
			plant_cell.signal_plant_create.disconnect(_on_cell_plant_changed)
		if plant_cell.signal_plant_free.is_connected(_on_cell_plant_changed):
			plant_cell.signal_plant_free.disconnect(_on_cell_plant_changed)
	cells.clear()
	ghosts.clear()
	queue_free()


## 某格是否达标（没给判定时一律算没达标）
func _is_done(plant_cell: PlantCell) -> bool:
	if not is_cell_done.is_valid():
		return false
	return bool(is_cell_done.call(plant_cell))


## 所有被标记格子的几何中心（各格中心的平均位置）—— 掉奖杯这类表现用它定位
func get_center_global_position() -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for plant_cell: PlantCell in cells:
		if not is_instance_valid(plant_cell):
			continue
		sum += plant_cell.global_position + plant_cell.size / 2.0
	return sum / float(cells.size())


## 给每个格子各取一帧植物定格下来
## ⚠️ 不要试图「取一次帧再 duplicate()」：这棵树是 PackedScene 实例化来的、脚本又被剥过，
## duplicate() 走 DUPLICATE_USE_INSTANTIATION 时结构会对不上（get_child 越界 + 子节点丢失），
## 20 次「实例化 + 取帧」的代价也就是几十毫秒，这里不值得为省这点复用同一个节点
func _build_ghosts(plant_scene: PackedScene, idle_anim_name: StringName) -> void:
	var is_failed_logged := false
	for plant_cell: PlantCell in cells:
		if not is_instance_valid(plant_cell):
			ghosts.append(null)
			continue
		var ghost := _create_ghost(plant_scene, idle_anim_name)
		if ghost == null:
			if not is_failed_logged:
				Log.error(str("植物虚影取帧失败，跳过显示：") + str(idle_anim_name))
				is_failed_logged = true
			ghosts.append(null)
			continue
		add_child(ghost)
		## 摆在「种下去之后植物会落在的那个点」上，虚影与真实植物重合
		ghost.global_position = plant_cell.get_new_plant_static_shadow_global_position(
			CharacterRegistry.PlacePlantInCell.Norm)
		ghosts.append(ghost)


## 取「植物 idle 动画第 0 帧」的静态形象：脚本 / 播放器 / 碰撞体已被剥掉，拿到的是棵死树
func _create_ghost(plant_scene: PackedScene, idle_anim_name: StringName) -> Node2D:
	var node := AnimationFrameUtil.create_frame_node(plant_scene, idle_anim_name)
	if node == null:
		return null
	## 只留 Body 这一枝：血条（HpComponent/HpControl）与阴影（Shadow）是战斗时才有意义的
	## 附属显示，虚影不该带它们 —— 成分与卡片里手摆的 CharacterStatic 一致
	for child in node.get_children():
		if child.name == &"Body":
			continue
		node.remove_child(child)
		child.free()
	return node


## 刷新每格的透明度：没达标的亮、达标的暗
func _refresh_alpha() -> void:
	for i in ghosts.size():
		var ghost: Node2D = ghosts[i]
		if ghost == null or i >= cells.size():
			continue
		ghost.modulate.a = ALPHA_DONE if _is_done(cells[i]) else ALPHA_TODO


## 格子上的植物种上 / 掉光时重刷（PlantCell 的信号带参数，这里不需要）
func _on_cell_plant_changed(_plant_cell: PlantCell = null,
		_plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	_refresh_alpha()
