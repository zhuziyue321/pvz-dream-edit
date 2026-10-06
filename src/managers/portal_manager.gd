extends MainGameSubManager
class_name PortalManager
## 传送门管理器 —— 迷你游戏**第 11 关**「斗转星移」(Portal Combat)
##
## 开关：ResourceLevelData.is_portal_combat（未开启时本管理器完全待机）。
##
## 做的事（原版机制，见 docs/参考存档/斗转星移传送门.md）：
##   · 草坪上摆两对传送门（下标 0/1 一对方形、2/3 一对圆形，配对 = 下标 ^ 1）
##   · 每隔 portal_reshuffle_interval 秒把四扇门随机换位
##   · 物理帧扫描僵尸与子弹：进门的（x 落在门判定范围 + 行号一致）
##     立刻挪到配对门处，行进方向不变；僵尸同时换行（lane）
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

const PORTAL_SCRIPT := preload("res://src/items/mini_game/portal.gd")

## 四扇门（0/1 方形一对，2/3 圆形一对；配对 = 下标 ^ 1）
var _doors: Array[Portal] = []
## 换位计时器（portal_reshuffle_interval <= 0 时不创建）
var _reshuffle_timer: Timer
## 出口记忆：角色 / 子弹 instance_id → 出口门 instance_id
var _exit_memory: Dictionary[int, int] = {}


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
	pass ## 摆门与扫描都在 _ready / _physics_process 自驱，无需外部初始化


func _physics_process(_delta: float) -> void:
	_check_zombies()
	_check_bullets()


#region 摆门与换位
## 建四扇门（门节点常驻，换位只挪位置）
func _create_doors() -> void:
	var door_root := Node2D.new()
	door_root.name = "Portals"
	add_child(door_root)
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
## 僵尸进门 → 挪到配对门（换行 + 落点对齐新行地面，方向不变）
func _check_zombies() -> void:
	var zm := main_game.zombie_manager
	for z: Zombie000Base in zm.all_zombies_1d:
		if not is_instance_valid(z) or z.is_death:
			continue
		## 被魅惑的己方僵尸不传：signal_lane_update 会把它挪回 all_zombies_2d，
		## 而魅惑僵尸死亡时只从 all_zombies_be_hypno 清理，会在 2d 列表里留下悬空引用
		if z.is_hypno:
			continue
		var entry_door := _find_entry_door(z)
		if entry_door == null:
			continue
		_teleport_zombie(z, entry_door)


## 子弹进门 → 挪到配对门（换行 + 重置射程基准，方向不变）
## 只处理 NormBase 系子弹（lane / start_pos 都在它上面）；
## 玉米炮弹直接继承 Bullet000Base 没有行属性，且一发清屏不该被门转送
func _check_bullets() -> void:
	for child in main_game.bullets.get_children():
		var bullet := child as Bullet000NormBase
		if bullet == null:
			continue
		var entry_door := _find_entry_door(bullet)
		if entry_door == null:
			continue
		_teleport_bullet(bullet, entry_door)


## 找 obj（僵尸 / 子弹）当前踩进的那扇门，没踩进返回 null
func _find_entry_door(obj: Node2D) -> Portal:
	## 先结算出口记忆：已离开出口门判定范围就清掉，否则本轮不传
	var obj_id := obj.get_instance_id()
	if _exit_memory.has(obj_id):
		var exit_door := _door_by_instance_id(_exit_memory[obj_id])
		if exit_door != null and exit_door.contains_x(obj.global_position.x):
			return null
		_exit_memory.erase(obj_id)
	for door in _doors:
		if not door.contains_x(obj.global_position.x):
			continue
		## 行号一致才算进门（判定不看 y：僵尸原点 y 即行地面 y，子弹斜飞时 y 会飘）
		if door.lane != obj.lane:
			continue
		return door
	return null


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
	Log.debug("斗转星移：僵尸传送到 %d 行" % z.lane)


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
