extends MainGameSubManager
class_name PortalManager
## 传送门管理器 —— 迷你游戏**第 11 关**「斗转星移」(Portal Combat)
##
## 开关：ResourceLevelData.is_portal_combat（未开启时本管理器完全待机）。
##
## 做的事（原版机制，见 docs/参考存档/斗转星移传送门.md）：
##   · 草坪上摆两对传送门（下标 0/1 一对方形、2/3 一对圆形，配对 = 下标 ^ 1）
##   · 每隔 portal_reshuffle_interval 秒把四扇门随机换位
##   · 每个物理帧向物理服务器问一次「四扇门的矩形里有什么 Area2D」，
##     落在里面的（x 在门判定范围 + 行号一致）挪到配对门处，
##     行进方向不变；僵尸同时换行（lane）
##     判定走空间查询而不是自己遍历全场，理由见 _check_door_overlaps 的注释
##
## 防来回横跳：角色 / 子弹刚从某扇门出来时记下它，**离开那扇门判定范围之前**
## 不再触发传送（不用固定冷却 —— 僵尸走得慢，时间冷却要么不够要么太久）。
## 传送门整关一直存在（门节点不销毁，只换位置），所以出口记忆不用考虑门被释放。

## 一对门的落点偏移：顺着行进方向从门里走出来半步，别叠在门正中
const EXIT_OFFSET := 20.0
## 门中心在地面上方的高度（僵尸原点在脚部，门画在身体高度）
const DOOR_CENTER_ABOVE_GROUND := 45.0
## 门 z_index 排法与格子行（row*50+10）/ 僵尸行（row*50+30）一致，插在两者中间
const PORTAL_Z_BASE := 20
const PORTAL_Z_STEP := 50
## 子弹 z_index 公式与 Bullet000NormBase.init_bullet 保持一致（lane * 50 + 45）
const BULLET_Z_BASE := 45
const BULLET_Z_STEP := 50
## 传送判定矩形的**半高**：刻意做得远超门本身的高度（屏幕才 600 高）
##
## 为什么：门本体只有 120px 高，但传送判定**从来不看 y** —— 抛物线子弹（西瓜 / 卷心菜）
## 飞到最高点时 y 早就飘到门口以上很远，原实现照样传送它。沿用「只看 x + 行号」的口径，
## 查询矩形就必须放宽到角色 / 子弹飞不出去的高度，否则会悄悄改掉这一关的手感。
## 放宽 y 不会引入跨行误传：行号那道闸（_is_teleportable）会挡掉别行的单位。
const DETECT_HALF_HEIGHT := 400.0
## 一次空间查询最多取多少个 Area2D（门只有 72px 宽，正常远到不了，留上限防异常）
const MAX_HITS_PER_DOOR := 64
## 查询掩码取全位：先把门范围内**所有** Area2D 捞出来，是僵尸还是子弹下一步按类型分。
## 不写成具体层位的好处：不必卷进敌我层 / 阵营层 / 新旧物理层那套配对规则，
## 而且这个查询是**只读**的 —— 不改任何对象的 collision_layer / mask，
## 因此不会影响索敌、受击、阵营这些既有判定
const DETECT_MASK_ALL := 0xFFFFFFFF

const PORTAL_SCRIPT := preload("res://src/items/mini_game/portal.gd")

## 四扇门（0/1 方形一对，2/3 圆形一对；配对 = 下标 ^ 1）
var _doors: Array[Portal] = []
## 换位计时器（portal_reshuffle_interval <= 0 时不创建）
var _reshuffle_timer: Timer
## 出口记忆：角色 / 子弹 instance_id → 出口门 instance_id
var _exit_memory: Dictionary[int, int] = {}
## 传送判定用的矩形（四扇门共用一份，宽 = Portal.HALF_WIDTH * 2，高见 DETECT_HALF_HEIGHT）
var _detect_shape: RectangleShape2D


func _ready() -> void:
	## 未开启的关一动不动（不扫僵尸不摆门）；map_data 在 MainGameManager._enter_tree
	## 就已 resolve（见 ResourceLevelData.resolve_map_data），这里直接可用
	if game_para == null or not game_para.is_portal_combat or game_para.map_data == null:
		set_physics_process(false)
		return
	_create_doors()
	_reshuffle_portals()
	if game_para.portal_reshuffle_interval > 0.0:
		_reshuffle_timer = Timer.new()
		_reshuffle_timer.wait_time = game_para.portal_reshuffle_interval
		_reshuffle_timer.autostart = true
		_reshuffle_timer.timeout.connect(_reshuffle_portals)
		add_child(_reshuffle_timer)


func init_manager() -> void:
	pass ## 摆门与传送判定都在 _ready / _physics_process 自驱，无需外部初始化


func _physics_process(_delta: float) -> void:
	_check_door_overlaps()


#region 摆门与换位
## 建四扇门（门节点常驻，换位只挪位置）
func _create_doors() -> void:
	var door_root := Node2D.new()
	door_root.name = "Portals"
	add_child(door_root)
	## 传送判定矩形：宽与 Portal.HALF_WIDTH 的判定口径完全对齐（左右各 36px），
	## 高度按 DETECT_HALF_HEIGHT 放宽（理由见该常量注释）
	_detect_shape = RectangleShape2D.new()
	_detect_shape.size = Vector2(Portal.HALF_WIDTH * 2.0, DETECT_HALF_HEIGHT * 2.0)
	for i in range(4):
		var door: Portal = PORTAL_SCRIPT.new()
		door.name = "Portal%d" % (i + 1)
		door_root.add_child(door)
		_doors.append(door)


## 四扇门随机换位：每扇门挑一个行 + 半区一列（左半区列 0..中列前，右半区列中列后..末列），
## 行尽量不重复；方形门占一对、圆形门占一对
func _reshuffle_portals() -> void:
	var map: ResourceMapData = game_para.map_data
	var row_num := map.get_row_num()
	var col_num := map.get_col_num()
	## 行洗牌后依次取（行数 < 4 时取模重复用）
	var lanes := range(row_num)
	lanes.shuffle()
	## 中间一列不放门（门压在草坪正中不好看，也容易让两扇门贴太近）
	var mid_col := floori(col_num / 2.0)
	var left_cols := range(0, mid_col)
	var right_cols := range(mid_col + 1, col_num)
	var types: Array[Portal.E_PortalType] = [Portal.E_PortalType.Square, Portal.E_PortalType.Circle]

	for pair_i in range(2):
		for half_i in range(2):
			var door_i := pair_i * 2 + half_i
			var door: Portal = _doors[door_i]
			var lane: int = lanes[door_i % lanes.size()]
			var cols := left_cols if half_i == 0 else right_cols
			door.init_portal(types[pair_i], lane)
			door.z_index = lane * PORTAL_Z_STEP + PORTAL_Z_BASE
			door.relocate(_door_pos(map, lane, cols.pick_random()))


## 门的全局位置：格子中心 x + 行地面上方门中心高度
func _door_pos(map: ResourceMapData, lane: int, col: int) -> Vector2:
	var cell_rect := map.get_cell_rect(lane, col)
	return Vector2(
		cell_rect.position.x + cell_rect.size.x / 2.0,
		map.rows[lane].zombie_create_global_pos.y - DOOR_CENTER_ABOVE_GROUND
	)
#endregion


#region 传送判定
## 传送判定入口（每个物理帧一次）
##
## **为什么不再自己遍历全场**：原本每个物理帧都要遍历 zombie_manager 的全部僵尸
## + bullets 的全部子节点、逐个比对 x 坐标。后期一波四五十个单位时这是两次 O(n) 全扫描，
## 而真正踩进门的通常**一个都没有** —— 等于给场上每个对象都做一次注定失败的比对。
##
## 改成问物理服务器「这块矩形里现在有什么 Area2D」：Godot 内部有 BVH 宽相位，
## 开销跟**实际相交数量**相关而不是场上总量，空跑几乎不花钱。
## 查询只读不写，行为上与旧实现等价（判定口径仍是 x 范围 + 行号，见 _is_teleportable）。
func _check_door_overlaps() -> void:
	if _detect_shape == null:
		return
	## 本管理器 extends MainGameSubManager（再往上是 Node），**没有** get_world_2d()——
	## 那是 CanvasItem（Node2D）/ Viewport 的方法，在 Node 上直接写会编译不过
	## （报错 Function "get_world_2d()" not found in base self）。
	## 正解：Node 自带 get_viewport()，取最近的视口后再拿 2D 世界。
	## 本方法只在 _physics_process 里调，此刻必在场景树中；get_viewport() 理论上仍可能
	## 返回 null（极端情况），故与下面的 space 一样保留判空。
	var viewport := get_viewport()
	if viewport == null:
		return
	var space: PhysicsDirectSpaceState2D = viewport.get_world_2d().direct_space_state
	if space == null:
		return
	## 同一个对象可能一次被多扇门的查询都捞到，本帧只传一次
	var teleported: Dictionary[int, bool] = {}
	for door in _doors:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = _detect_shape
		query.transform = Transform2D(0.0, door.global_position)
		query.collision_mask = DETECT_MASK_ALL
		query.collide_with_areas = true
		query.collide_with_bodies = false
		for hit in space.intersect_shape(query, MAX_HITS_PER_DOOR):
			var area := hit["collider"] as Area2D
			if area == null:
				continue
			var obj := _root_actor_of(area)
			if obj == null:
				continue
			var obj_id := obj.get_instance_id()
			if teleported.has(obj_id):
				continue
			if not _is_teleportable(obj, door):
				continue
			teleported[obj_id] = true
			if obj is Zombie000Base:
				_teleport_zombie(obj, door)
			elif obj is Bullet000Base:
				_teleport_bullet(obj, door)


## 某个 Area2D 所属的行进物（僵尸 / 子弹的根节点），找不到返回 null
##
## 注意这是从物理查询结果**反向追溯**所属对象，不是组件去猜自己的父节点
## （后者才是硬约束 1-2 禁止的写法）：受击框 / 攻击框都挂在组件更深的一层，
## 「这个框属于谁」只能沿树往上问。
static func _root_actor_of(area: Area2D) -> Node2D:
	var node: Node = area
	while node != null:
		if node is Zombie000Base or node is Bullet000Base:
			return node as Node2D
		node = node.get_parent()
	return null


## obj 现在能不能从 entry_door 传送（出口记忆 + 阵营 / 死亡 / 行号过滤都在这里）
func _is_teleportable(obj: Node2D, entry_door: Portal) -> bool:
	## 行号一致才算进门（判定不看 y：僵尸原点 y 即行地面 y，子弹斜飞时 y 会飘）
	if entry_door.lane != obj.lane:
		return false
	var obj_id := obj.get_instance_id()
	## 先结算出口记忆：还留在出口门判定范围内就先不传，走出来了才清掉
	if _exit_memory.has(obj_id):
		var exit_door := _door_by_instance_id(_exit_memory[obj_id])
		if exit_door != null and exit_door.contains_x(obj.global_position.x):
			return false
		_exit_memory.erase(obj_id)
	if obj is Zombie000Base:
		var z := obj as Zombie000Base
		## 被魅惑的己方僵尸不传：signal_lane_update 会把它挪回 all_zombies_2d，
		## 而魅惑僵尸死亡时只从 all_zombies_be_hypno 清理，会在 2d 列表里留下悬空引用
		return not z.is_death and not z.is_hypno
	## 只处理 NormBase 系子弹（lane / start_pos 都在它上面）；
	## 玉米炮弹直接继承 Bullet000Base 没有行属性，且一发清屏不该被门转送
	return obj is Bullet000NormBase


## 传送僵尸
func _teleport_zombie(z: Zombie000Base, entry_door: Portal) -> void:
	var exit_door := _pair_of(entry_door)
	var zm := main_game.zombie_manager
	## 换行：改行号 → 发信号让僵尸管理器挪 all_zombies_2d → 换父节点到新行
	## （顺序照 ZombieGarlicLaneUtil.update_lane 的先改 lane 再 reparent）
	z.lane = exit_door.lane
	z.curr_zombie_row_type = zm.all_zombie_rows[z.lane].zombie_row_type
	z.signal_lane_update.emit()
	z.reparent(zm.all_zombie_rows[z.lane])
	## 落点：出口门 x 顺行进方向偏半步，y 对齐新行地面
	z.global_position = Vector2(
		exit_door.global_position.x - EXIT_OFFSET * z.direction_x_root,
		zm.all_zombie_rows[z.lane].zombie_create_position.global_position.y
	)
	_remember_exit(z, exit_door)
	SoundManager.play_character_SFX(&"Portal")


## 传送子弹
func _teleport_bullet(bullet: Bullet000Base, entry_door: Portal) -> void:
	var exit_door := _pair_of(entry_door)
	bullet.lane = exit_door.lane
	## z_index 更新公式与 Bullet000NormBase.init_bullet 一致
	bullet.z_index = bullet.lane * BULLET_Z_STEP + BULLET_Z_BASE
	bullet.global_position = exit_door.global_position
	## 重置最大射程基准（start_pos 是 bullets 容器局部坐标，须在 global_position 赋值后取），
	## 否则传送后距离暴涨、子弹立刻被当超程销毁
	bullet.start_pos = bullet.position
	_remember_exit(bullet, exit_door)
	SoundManager.play_character_SFX(&"Portal")
#endregion


#region 出口记忆与配对
func _remember_exit(obj: Node2D, exit_door: Portal) -> void:
	_exit_memory[obj.get_instance_id()] = exit_door.get_instance_id()


func _door_by_instance_id(id: int) -> Portal:
	for door in _doors:
		if door.get_instance_id() == id:
			return door
	return null


## 配对门：0↔1、2↔3
func _pair_of(door: Portal) -> Portal:
	var door_i := _doors.find(door)
	return _doors[door_i ^ 1]
#endregion
