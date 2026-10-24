extends MainGameSubManager
class_name PortalManager
## 传送门管理器 —— 迷你游戏**第 11 关**「斗转星移」(Portal Combat)
##
## 开关：ResourceLevelData.is_portal_combat（未开启时本管理器完全待机）。
##
## 本文件按**原版 C++ 口径**实现（../PvZ-Portable-main/src/Lawn/Challenge.cpp，
## 交叉验证 ../re-plants-vs-zombies-main/Lawn/Challenge.cpp）：
##   · 初始 4 扇门：方(2,0)、方(9,1)、圆(9,3)、圆(2,4)        —— Challenge::PortalStart
##   · 首次换位 90 秒、之后每 60 秒、每次**只动一扇**          —— Challenge::UpdatePortalCombat
##   · 换位前 5 秒弹提示「传送门重置中……」                   —— 同上（[ADVICE_PORTAL_RELOCATING]）
##   · 新落点 = 10 列 × N 行里「没有门、且与搭档门的列和行都不同」的格子，均匀随机
##                                                          —— Challenge::MoveAPortal
##   · 传送判定：僵尸 / 直线子弹 / 已启动的小推车，三套 x 窗口，行号必须一致
##                                                          —— Challenge::UpdatePortal
##   · 每行出怪权重受门位置影响                              —— Challenge::PortalCombatRowSpawnWeight
##   · 豌豆射手 / 双发 / 仙人掌可隔门索敌（最多 3 跳）        —— Challenge::CanTargetZombieWithPortals
##
## 坐标口径：原版用「全局像素」（格中心 = gridX*80+40，格子宽 80），
## 本仓用地图数据算出来的格子矩形，两者相差几像素，换算成「相对格中心的偏移」写死。

#region 原版常量
## 首次换位延迟（秒）：原版 mChallengeStateCounter = 9000 tick（100 tick/秒）
const FIRST_RELOCATE_DELAY := 90.0
## 稳态换位间隔（秒）：原版换位后把计数重置成 6000 tick
const RELOCATE_INTERVAL := 60.0
## 换位前的提示时长（秒）：原版计数剩 500 tick 时弹提示（5 秒）
const RELOCATE_WARNING := 5.0
## 原版提示文案（data/strings/lawn_strings.txt 的 [ADVICE_PORTAL_RELOCATING]）
const ADVICE_PORTAL_RELOCATING := "传送门重置中……"

## 原版候选列数：10（gridX 0..9）。本仓前院只有 9 列 → 第 10 列是「草坪右缘」的虚拟列
const ORIGIN_COL_NUM := 10

## 僵尸判定窗口：中心 = 格中心-15（原版 gridX*80+25），半宽 45
const ZOMBIE_JUDGE_OFFSET := -15.0
const ZOMBIE_JUDGE_HALF := 45.0
## 子弹判定窗口：中心 = 格中心+15（原版 gridX*80+55），半宽 40
const BULLET_JUDGE_OFFSET := 15.0
const BULLET_JUDGE_HALF := 40.0
## 小推车判定窗口：中心 = 格中心-15（原版 gridX*80+25），半宽 20；
## 推车自身的参考点比原点靠右 45（原版 aMowerX = mPosX + 45）
const MOWER_JUDGE_OFFSET := -15.0
const MOWER_JUDGE_HALF := 20.0
const MOWER_REFERENCE_OFFSET := 45.0

## 出口落点：原版僵尸 mX = otherGridX*80 - diffX，即**碰撞盒中心落到出口格左缘**
## （仓库僵尸原点就在受击框中心 → diffX ≈ 0）；半个格子宽 = 80/2 = 40
const EXIT_CELL_EDGE_OFFSET := 40.0
## 子弹出口：原版 mX += otherGridX*80 - aProjectileX + 60，即落到出口格中心 +20
const BULLET_EXIT_OFFSET := 20.0
## 每行出怪权重（原版 PortalCombatRowSpawnWeight）
const ROW_WEIGHT_NEAR_MOWER := 0.01		## 离小推车太近（门链距离 < 5）
const ROW_WEIGHT_HAS_PORTAL := 1.0		## 这一行有门
const ROW_WEIGHT_NORMAL := 0.2			## 其它行
## 门链距离上限（原版 GetPortalDistanceToMower 的 while 上限）
const PORTAL_DISTANCE_LIMIT := 40
#endregion

## 打开着的门（同一类型两扇为一对；配对 = 同类型的另一扇）
var _doors: Array[Portal] = []
## 距离下次换位还有多少秒
var _relocate_countdown := FIRST_RELOCATE_DELAY
## 换位提示是否已经弹过（避免每帧重复弹）
var _warning_shown := false
## 出口记忆：对象 instance_id → {grid_x = 出口门的列号, obj = 对象}
## 原版用 `mLastPortalX`（记出口门的 gridX），语义一致：刚从这列的门出来就别再被同一列的门吸回去
var _exit_memory: Dictionary[int, Dictionary] = {}
## 门节点的父节点
var _door_root: Node2D


func _ready() -> void:
	## 未开启的关一动不动（不扫僵尸不摆门）；map_data 在 MainGameManager._enter_tree
	## 就已 resolve（见 ResourceLevelData.resolve_map_data），这里直接可用
	if game_para == null or not game_para.is_portal_combat or game_para.map_data == null:
		set_physics_process(false)
		set_process(false)
		return
	_door_root = Node2D.new()
	_door_root.name = "Portals"
	add_child(_door_root)
	_spawn_initial_doors()


func init_manager() -> void:
	pass ## 摆门与传送判定都在 _ready / _physics_process 自驱，无需外部初始化


#region 摆门与换位
## 初始 4 扇门：原版 Challenge::PortalStart 写死的四个格子（列, 行）
##   方门 (2,0) 与 (9,1)；圆门 (9,3) 与 (2,4)
## 第 10 列（gridX=9）是草坪右缘 —— 僵尸从那儿进场就会被门吸走，这是原版关卡的核心
func _spawn_initial_doors() -> void:
	_spawn_door(Portal.E_PortalType.Square, 2, 0)
	_spawn_door(Portal.E_PortalType.Square, 9, 1)
	_spawn_door(Portal.E_PortalType.Circle, 9, 3)
	_spawn_door(Portal.E_PortalType.Circle, 2, 4)


## 在指定格子开一扇门（淡入 + 传送门音效）
func _spawn_door(portal_type: Portal.E_PortalType, grid_x: int, lane: int) -> Portal:
	var door: Portal = Portal.new()
	door.name = "Portal_%d_%d" % [grid_x, lane]
	door.z_index = lane * 50 + 20
	_door_root.add_child(door)
	door.init_portal(portal_type, grid_x, lane)
	## 用 global_position：门节点挂在 Manager 下面，父节点未必在原点
	door.global_position = _door_draw_position(door)
	_doors.append(door)
	door.open_portal()
	## 原版 OpenPortal 会播传送门音效（开门有声音、传送本身没有）
	SoundManager.play_character_SFX(&"Portal")
	return door


## 换位倒计时与提示（原版 Challenge::UpdatePortalCombat）
func _process(delta: float) -> void:
	## 奖杯落下 / 关卡结束就不再换位（原版 HasLevelAwardDropped 时清提示并停表）
	if _is_level_finished():
		_hide_relocate_advice()
		return
	_relocate_countdown -= delta
	if not _warning_shown and _relocate_countdown <= RELOCATE_WARNING:
		_warning_shown = true
		_show_relocate_advice()
	if _relocate_countdown <= 0.0:
		_relocate_countdown = RELOCATE_INTERVAL
		_warning_shown = false
		_hide_relocate_advice()
		_move_a_portal()


## 换一扇门的位置（原版 Challenge::MoveAPortal）
##   1. 在 4 扇打开的门里等概率随机挑一扇
##   2. 找到它的搭档（同类型的另一扇）
##   3. 在 10 列 × N 行里筛候选：没有门、且**列与行都**不同于搭档 → 均匀随机挑一个
##   4. 新门在新格淡入，旧门淡出消失
func _move_a_portal() -> void:
	if _doors.is_empty():
		return
	var door: Portal = _doors.pick_random()
	var other := _other_portal(door)
	if other == null:
		return
	var candidates: Array[Vector2i] = []
	for grid_x in range(ORIGIN_COL_NUM):
		for lane in range(_row_num()):
			## 该格已经有门（原版 GetPortalAt 只认打开的门）
			if _portal_at(grid_x, lane) != null:
				continue
			## 与搭档门的列、行都要不同（原版是 && 不是 ||）
			if grid_x == other.grid_x or lane == other.lane:
				continue
			candidates.append(Vector2i(grid_x, lane))
	if candidates.is_empty():
		return
	var target: Vector2i = candidates.pick_random()
	_spawn_door(door.portal_type, target.x, target.y)
	## 旧门淡出并从「打开的门」名单里摘掉（节点由 Portal.close_portal 淡出后自毁）
	_doors.erase(door)
	door.close_portal()


## 门的绘制锚点：格中心 + 原版偏移，行地面 + 原版纵向偏移
func _door_draw_position(door: Portal) -> Vector2:
	var offset := door.get_draw_offset()
	return Vector2(
		_cell_center_x(door.grid_x, door.lane) + offset.x,
		_lane_ground_y(door.lane) + offset.y
	)
#endregion


#region 传送判定
## 传送判定入口（每个物理帧一次）
##
## 按**原版口径**遍历：每扇打开的门 × 全部僵尸 / 子弹 / 小推车，
## 判的是「x 落在窗口里 + 行号一致」，不是碰撞盒重叠 ——
## 所以这里不能用物理查询（子弹的 x 取发射点，跟它的受击框并不重合）。
func _physics_process(_delta: float) -> void:
	if _doors.is_empty():
		return
	_prune_exit_memory()
	for door in _doors:
		if not is_instance_valid(door) or not door.is_open:
			continue
		if _other_portal(door) == null:
			continue
		_check_zombies_through(door)
		_check_bullets_through(door)
		_check_mowers_through(door)


## 僵尸过门（原版 Challenge::UpdatePortal 的僵尸分支）
func _check_zombies_through(door: Portal) -> void:
	var zm := main_game.zombie_manager
	if zm == null:
		return
	var judge_x := _cell_center_x(door.grid_x, door.lane) + ZOMBIE_JUDGE_OFFSET
	for lane in range(zm.all_zombies_2d.size()):
		if lane != door.lane:
			continue
		for zombie in zm.all_zombies_2d[lane]:
			if not is_instance_valid(zombie) or zombie.is_death:
				continue
			## 刚从这个列号的门出来就别再被同一列的门吸回去（原版 mLastPortalX）
			if _is_blocked_by_exit_memory(zombie, door):
				continue
			if absf(zombie.global_position.x - judge_x) > ZOMBIE_JUDGE_HALF:
				continue
			_teleport_zombie(zombie, door)


## 直线子弹过门（原版只传 MOTION_STRAIGHT，抛物线 / 追踪子弹不过门）
func _check_bullets_through(door: Portal) -> void:
	var bullets := main_game.bullets
	if bullets == null:
		return
	var judge_x := _cell_center_x(door.grid_x, door.lane) + BULLET_JUDGE_OFFSET
	for child in bullets.get_children():
		var bullet := child as BulletLinear000Base
		if bullet == null or not is_instance_valid(bullet):
			continue
		if bullet.lane != door.lane:
			continue
		if _is_blocked_by_exit_memory(bullet, door):
			continue
		if absf(bullet.global_position.x - judge_x) > BULLET_JUDGE_HALF:
			continue
		_teleport_bullet(bullet, door)


## 已启动的小推车过门（原版只传 MOWER_TRIGGERED 的推车）
func _check_mowers_through(door: Portal) -> void:
	var item_manager := main_game.game_item_manager
	if item_manager == null:
		return
	var judge_x := _cell_center_x(door.grid_x, door.lane) + MOWER_JUDGE_OFFSET
	for mover: LawnMover in item_manager.gim_lawn_mover.all_lawn_movers:
		if not is_instance_valid(mover) or not mover.is_moving:
			continue
		if mover.lane != door.lane:
			continue
		if _is_blocked_by_exit_memory(mover, door):
			continue
		var mower_x: float = mover.global_position.x + MOWER_REFERENCE_OFFSET
		if absf(mower_x - judge_x) > MOWER_JUDGE_HALF:
			continue
		_teleport_mower(mover, door)


## 传送僵尸：换行 + 落点挪到出口格左缘，行进方向不变
func _teleport_zombie(zombie: Zombie000Base, entry_door: Portal) -> void:
	var exit_door := _other_portal(entry_door)
	if exit_door == null:
		return
	var zm := main_game.zombie_manager
	## 换行：改行号 → 发信号让僵尸管理器挪 all_zombies_2d → 换父节点到新行
	## （顺序照 ZombieGarlicLaneUtil.update_lane 的先改 lane 再 reparent）
	zombie.lane = exit_door.lane
	zombie.curr_zombie_row_type = zm.all_zombie_rows[zombie.lane].zombie_row_type
	zombie.signal_lane_update.emit()
	zombie.reparent(zm.all_zombie_rows[zombie.lane])
	## 落点：原版 mX = otherGridX*80 - diffX（碰撞盒中心落到出口格左缘），仓库僵尸原点即受击框中心
	zombie.global_position = Vector2(
		_cell_left_x(exit_door.grid_x, exit_door.lane),
		_lane_ground_y(exit_door.lane)
	)
	_remember_exit(zombie, exit_door)


## 传送直线子弹：换行 + 出口落在出口格中心 +20，行进方向不变
func _teleport_bullet(bullet: BulletLinear000Base, entry_door: Portal) -> void:
	var exit_door := _other_portal(entry_door)
	if exit_door == null:
		return
	bullet.lane = exit_door.lane
	bullet.z_index = Bullet000Base.z_index_of_lane(bullet.lane)
	## y 按两行地面之差平移（原版是 (出口行-入口行)*100，仓库按地图实际行距算）
	var delta_y := _lane_ground_y(exit_door.lane) - _lane_ground_y(entry_door.lane)
	bullet.global_position = Vector2(
		_cell_center_x(exit_door.grid_x, exit_door.lane) + BULLET_EXIT_OFFSET,
		bullet.global_position.y + delta_y
	)
	## 重置最大射程基准（start_pos 是 bullets 容器局部坐标，须在 global_position 赋值后取），
	## 否则传送后距离暴涨、子弹立刻被当超程销毁（原版没有射程计数，只看出界，
	## 仓库用 start_pos 近似 → 传送后重置才等价）
	bullet.start_pos = bullet.position
	_remember_exit(bullet, exit_door)


## 传送小推车：换行 + 落点挪到出口门（原版 mPosY 写的是相对位移，仓库改成新行地面绝对 y）
func _teleport_mower(mower: LawnMover, entry_door: Portal) -> void:
	var exit_door := _other_portal(entry_door)
	if exit_door == null:
		return
	mower.lane = exit_door.lane
	mower.z_index = exit_door.lane * 50 + 40
	mower.global_position = Vector2(
		_cell_center_x(exit_door.grid_x, exit_door.lane) + MOWER_JUDGE_OFFSET,
		_lane_ground_y(exit_door.lane)
	)
	_remember_exit(mower, exit_door)
#endregion


#region 出口记忆与配对
## 记下「这个对象是从哪列的门出来的」（原版 mLastPortalX）
func _remember_exit(obj: Node2D, exit_door: Portal) -> void:
	_exit_memory[obj.get_instance_id()] = {"grid_x": exit_door.grid_x, "obj": obj}


## 出口记忆拦截：这个对象是不是刚从「同一列」的门出来的？
## 原版语义：刚出来的僵尸不会被同一列的门再吸回去，但换成别的列的门仍然能传
func _is_blocked_by_exit_memory(obj: Node2D, door: Portal) -> bool:
	var record: Dictionary = _exit_memory.get(obj.get_instance_id(), {})
	return record.get("grid_x", -1) == door.grid_x


## 清掉已经不在场上的对象的出口记忆（对象没了还留着就是内存泄漏）
func _prune_exit_memory() -> void:
	if _exit_memory.is_empty():
		return
	var dead_ids: Array[int] = []
	for id in _exit_memory.keys():
		var record: Dictionary = _exit_memory[id]
		var obj = record.get("obj")
		if not is_instance_valid(obj):
			dead_ids.append(id)
	for id in dead_ids:
		_exit_memory.erase(id)


## 配对门：同类型的另一扇打开的门
##
## 原版 GetOtherPortal 只看「类型相同且没死」，会把**正在消失的旧门**也算进去 ——
## 换位后那约 1 秒里新门会先配上正在消失的旧门（原版的一个小 bug）。
## 本仓按意图修正为「配对 = 另一扇**打开**的同型门」。
func _other_portal(door: Portal) -> Portal:
	for other in _doors:
		if other != door and is_instance_valid(other) and other.is_open \
				and other.portal_type == door.portal_type:
			return other
	return null


## 某格上有没有打开的门
func _portal_at(grid_x: int, lane: int) -> Portal:
	for door in _doors:
		if is_instance_valid(door) and door.is_open and door.grid_x == grid_x and door.lane == lane:
			return door
	return null


## 某行里、位于给定列**左边**的最靠右一扇门（原版 GetPortalToLeft）
func _portal_to_left(grid_x: int, lane: int) -> Portal:
	var found: Portal = null
	for door in _doors:
		if not is_instance_valid(door) or not door.is_open:
			continue
		if door.lane != lane or door.grid_x >= grid_x:
			continue
		if found == null or found.grid_x < door.grid_x:
			found = door
	return found


## 某行里、位于给定列**右边**的最靠左一扇门（原版 GetPortalToRight）
func _portal_to_right(grid_x: int, lane: int) -> Portal:
	var found: Portal = null
	for door in _doors:
		if not is_instance_valid(door) or not door.is_open:
			continue
		if door.lane != lane or door.grid_x <= grid_x:
			continue
		if found == null or found.grid_x > door.grid_x:
			found = door
	return found
#endregion


#region 出怪行权重（原版 Challenge::PortalCombatRowSpawnWeight）
## 每行的出怪权重：离小推车太近 → 0.01；这行有门 → 1.0；其它行 → 0.2
## 传空数组 = 走默认行权重（本关之外的关卡走这条）
func get_row_spawn_weights() -> Array[float]:
	if not _is_enabled():
		return []
	var weights: Array[float] = []
	for lane in range(_row_num()):
		if _portal_distance_to_mower(lane) < 5:
			weights.append(ROW_WEIGHT_NEAR_MOWER)
		elif _portal_at_in_row(lane) != null:
			weights.append(ROW_WEIGHT_HAS_PORTAL)
		else:
			weights.append(ROW_WEIGHT_NORMAL)
	return weights


## 这一行有没有门
func _portal_at_in_row(lane: int) -> Portal:
	for door in _doors:
		if is_instance_valid(door) and door.is_open and door.lane == lane:
			return door
	return null


## 从最右列往左、沿门链数一共能"跳过"多少列（原版 Challenge::GetPortalDistanceToMower）
## 距离越小 = 僵尸越快到家，这一行几乎不出怪（权重 0.01）
func _portal_distance_to_mower(lane: int) -> int:
	var grid_x := ORIGIN_COL_NUM
	var cur_lane := lane
	var distance := 0
	while distance < PORTAL_DISTANCE_LIMIT:
		var portal := _portal_to_left(grid_x, cur_lane)
		if portal == null:
			distance += grid_x
			break
		var other := _other_portal(portal)
		if other == null:
			break
		distance += grid_x - portal.grid_x
		grid_x = other.grid_x
		cur_lane = other.lane
	return distance
#endregion


#region 隔门索敌（原版 Challenge::CanTargetZombieWithPortals）
## 找「隔着一道门能打到」的僵尸：原版豌豆射手 / 双发 / 仙人掌可以隔着传送门
## 打到门另一行的僵尸（最多穿 3 道门）。返回 null = 没有这样的目标。
func find_target_through_portal(plant_lane: int, plant_col: int) -> Zombie000Base:
	if not _is_enabled():
		return null
	var zm := main_game.zombie_manager
	if zm == null:
		return null
	var grid_x := plant_col
	var lane := plant_lane
	for _i in range(3):
		var portal := _portal_to_right(grid_x, lane)
		if lane < zm.all_zombies_2d.size():
			var range_left := _cell_left_x(grid_x, lane)
			var range_right := _cell_left_x(portal.grid_x, portal.lane) if portal != null else _board_right_x(lane)
			for zombie in zm.all_zombies_2d[lane]:
				if not is_instance_valid(zombie) or zombie.is_death:
					continue
				## 植物不打魅惑僵尸（阵营过滤，与检测组件同口径）
				if not BulletCampConfig.is_enemy(CharacterRegistry.CharacterType.Plant, zombie):
					continue
				if zombie.global_position.x > range_left and zombie.global_position.x < range_right:
					return zombie
		if portal == null:
			break
		var other := _other_portal(portal)
		if other == null:
			break
		grid_x = other.grid_x
		lane = other.lane
	return null
#endregion


#region 坐标换算
## 本关是否开着传送门
func _is_enabled() -> bool:
	return game_para != null and game_para.is_portal_combat and game_para.map_data != null


## 地图行数
func _row_num() -> int:
	if game_para == null or game_para.map_data == null:
		return 0
	return game_para.map_data.get_row_num()


## 第 col 列的格子中心 x（超出的列 = 草坪右缘的虚拟列）
func _cell_center_x(grid_x: int, lane: int) -> float:
	var map := game_para.map_data
	if map == null:
		return 0.0
	if grid_x < map.get_col_num():
		var rect := map.get_cell_rect(lane, grid_x)
		return rect.position.x + rect.size.x * 0.5
	return _board_right_x(lane)


## 第 col 列的格子左缘 x（原版的 gridX*80，仓库按半个格子宽 40 折算）
func _cell_left_x(grid_x: int, lane: int) -> float:
	return _cell_center_x(grid_x, lane) - EXIT_CELL_EDGE_OFFSET


## 草坪右缘 x（虚拟列 / 原版的 800 边界）
func _board_right_x(lane: int) -> float:
	var map := game_para.map_data
	if map == null or map.get_col_num() <= 0:
		return 0.0
	var last := map.get_col_num() - 1
	return map.col_x[last] + map.col_width[last] + map.rows[lane].get_col_dx(last)


## 某一行的地面 y（僵尸原点在脚部，y 即行地面）
## **以地图数据为准**：门的落位在 _ready 就要算，那时僵尸行可能还没摆好
func _lane_ground_y(lane: int) -> float:
	if game_para != null and game_para.map_data != null and lane >= 0 \
			and lane < game_para.map_data.get_row_num():
		return game_para.map_data.rows[lane].zombie_create_global_pos.y
	var zm := main_game.zombie_manager
	if zm != null and lane >= 0 and lane < zm.all_zombie_rows.size():
		return zm.all_zombie_rows[lane].zombie_create_position.global_position.y
	return 0.0
#endregion


#region 提示条与结束判定
## 弹换位提示（原版 DisplayAdviceAgain("[ADVICE_PORTAL_RELOCATING]", MESSAGE_STYLE_HINT_FAST)）
func _show_relocate_advice() -> void:
	var hint := TutorialAdviceUI.ensure_level_hint(main_game)
	if hint != null:
		hint.show_advice(ADVICE_PORTAL_RELOCATING)


## 收掉换位提示
func _hide_relocate_advice() -> void:
	var hint := TutorialAdviceUI.find_level_hint(main_game)
	if hint != null and hint.is_advice_visible():
		hint.hide_advice()


## 关卡是否已经结束（奖杯落下 / 失败）：原版 HasLevelAwardDropped 之后不再换位
func _is_level_finished() -> bool:
	if main_game == null:
		return false
	return main_game.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER
#endregion
