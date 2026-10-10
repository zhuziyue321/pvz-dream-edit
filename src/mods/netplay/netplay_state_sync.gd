extends Node
class_name NetplayStateSync
## 联机的**状态广播**：主机每帧把"场上现在长什么样"整份广播出去，客户端照着对齐
##
## 这是继命令同步（`NetplayBattleSync`）与波次下发（`NetplayWaveSync`）之后的第三层，
## 也是兜底的那一层：命令同步保证"**做了什么**"一致，但两端各自的本地模拟
## （僵尸 AI、啃食、减速、掉血）仍会慢慢分叉 —— 这一层每隔一小会儿就用主机的真相
## 把分叉抹平，两端看到的才是同一局。
##
##   host   `_physics_process` ──▶ 采一份快照 ──▶ `state_snapshot`（unreliable）广播
##   client 收到 ──▶ 按 `entity_id` 对齐：缺的补、多的（连续缺席的）删、属性覆盖
##
## ★ **阳光也进快照**（第二包）：`NetplaySunSync` 用**离散命令**管"多了一颗 / 少了一颗"，
##   但命令只管事件、不管"现在场上到底有几颗" —— 哪一包在乱序里晚到、或者客户端本地
##   多长了一颗，命令这条路上没有东西能把它纠正回来。快照是**兜底**：每帧把"场上这几颗"
##   整份报一遍，客户端照着补 / 删，任何遗漏都能自愈。
##   ⚠️ 早先这里写着"故意不管阳光"，理由是"僵尸掉的阳光两端各自生成、编号不同，
##   对齐会把玩家的阳光误删"。**这条已经不成立**：实测 `component_drop_item.gd` 里
##   **只有金币 / 花园植物 / 巧克力，没有阳光**，阳光的 5 个生成点全都过
##   `GlobalUtils.sun_spawn_gate` 且都推 `SUN_SPAWNED` ⇒ 客户端的每一颗都有主机编号。
##
## ★ **对齐靠 `entity_id`**，而编号不是各端自增就能对上的（谁先多生一颗阳光就整体错位），
##   所以波次那一批僵尸的编号由 `NetplayWaveSync` 随下发**指定**（见它的 `z_ids`）。
##
## ★ **只有主机喊得动**：客户端自己发的快照一律丢掉（与 `enter_level` / `battle_op` 同一条纪律）。
## ★ **用 unreliable**：快照是"最新真相"，丢一帧下一帧就补上，不值得为它重传（重传只会带来旧数据）。
##
## ⚠️ **包体与 MTU**：ENet 的不可靠包不分片，超 MTU（约 1400 字节）会**整包丢弃**。
## 所以快照用 `Packed*Array` 紧凑编码（不用字典数组），并给每类实体设了上限；
## 场上实体特别多时按上限截断（先保僵尸）。真遇到丢包就调大 `send_interval_frames`。
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜ [联机模组规范](../../docs/参考存档/联机模组规范.md)

const SELF_NODE_NAME := "NetplayStateSync"

## 每几帧广播一次：1 = 每帧
var send_interval_frames := 1
## 单帧快照的实体上限（MTU 保护，见文件头）
const MAX_ZOMBIES := 40
const MAX_PLANTS := 64
const MAX_SUNS := 24
const MAX_BULLETS := 32
## 字节预算：ENet 的不可靠包超过 MTU（约 1400B）会**整包丢弃**（见文件头）。
##
## ⚠️ 为什么非要算字节：光靠上面那三个"条数上限"**算不出真实体积** ——
## 40 只僵尸（24B）+ 64 株植物（8B）就已经 1472B，超了；再加子弹只会更超。
## 所以改成"先到先得填预算"，并且给后面的类留保底，免得僵尸一多植物就一条都发不出去
## （植物发不出去 ⇒ 客户端的植物永远死不了）。
## ⚠️ 这是**每一包**的预算，两包各自独立（见 `NetplaySession` 的 `state_snapshot_extra`）
const BYTE_BUDGET := 1300
const BYTES_PER_ZOMBIE := 28	## id / type / lane / anim / x / y / hp
const BYTES_PER_BULLET := 16	## id / type / x / y
## 植物补了类型与格子（16B）：只发血量时客户端**没法补种** —— 命令丢了 / 晚到就永远少一株，
## 而快照这一层的价值恰恰就是"能把少的补回来"。
## ⚠️ `place`（槽位）**不用发**：它由植物自己的种植条件决定，`create_plant(type)` 会放对
const BYTES_PER_PLANT := 16		## id / type / cell / hp
const BYTES_PER_SUN := 16		## id / value / x / y
const RESERVE_BULLETS := 320	## 20 颗
const RESERVE_SUNS := 160		## 10 颗
## 位置对齐的平滑系数：1.0 = 直接吸附，越小越平滑但越滞后
const POS_LERP := 0.5
## 本地有、主机没有的实体要**连续缺席**这么多帧才删 ——
## 差一两帧多半只是"主机还没采到 / 包还没到"，立刻删会让刚出生的僵尸闪一下
const MISS_FRAMES_BEFORE_DELETE := 90
## 子弹的缺席阈值要短得多：它活得就那么几秒，照僵尸那 90 帧（1.5 秒）等下去，
## 主机那颗早就命中消失了，客户端这颗还在原地飘着
const MISS_FRAMES_BEFORE_DELETE_BULLET := 6
## 阳光的缺席阈值取中间：比子弹长（它落地后要停留十几秒，不能 6 帧就判没了），
## 又比僵尸短（被捡走是**命令**驱动的，客户端收到就立刻摘掉，快照只兜底 ——
## 兜底拖 1.5 秒会让"已经被捡走的那一颗"还挂在画面上）
const MISS_FRAMES_BEFORE_DELETE_SUN := 30

#region 动画状态（★ 由主机下发，客户端照着演）
##
## 为什么要下发动画：`zombie_norm.tscn` 的 AnimationTree 用 `advance_expression` 直接读
## **本体字段** —— 实测它读的就是这 7 个：
##
##   is_death / is_attack / is_swimming / is_idle
##   walk_status(1..2) / idle_status(1..2) / death_status(1..3)
##
## 也就是说**不必另发明一套动画协议**：主机把这 7 个值随快照发下来，客户端写回本体字段，
## 动画就跟着主机演 —— 哪怕客户端的 AI 被整体关掉，僵尸照样走、照样啃、照样倒地。
##
## ⚠️ 为什么连 `walk_status` 这些"变体"也要发：`zombie_norm.gd` 在 `_ready()` 里
## `randi_range(1, max)` 各挑一个变体，两端挑的**不是同一个** —— 主机这只走 1 号走路、
## 客户端这只走 2 号走路。两个变体都合法，所以不算错，但两端画面不一致。
## ⚠️ 这三个变体字段只在 `Zombie001Norm` 上有（其它僵尸类没有），读写都要走 `get` / `set` 兜着。
##
## 打包成一个 int（`z_anim`）而不是 7 条数组：7 条 × 4 字节 × 每只 = 一只就要 28 字节，
## 而快照贴着 ENet 的 MTU（见文件头）。挤位后一只只占 4 字节。
const ANIM_DEATH := 1 << 0
const ANIM_ATTACK := 1 << 1
const ANIM_SWIM := 1 << 2
const ANIM_IDLE := 1 << 3
## 三个变体各占 2 位（取值 1..3，足够覆盖 `death_status == 3`）
const ANIM_WALK_STATUS_SHIFT := 4
const ANIM_IDLE_STATUS_SHIFT := 6
const ANIM_DEATH_STATUS_SHIFT := 8
const ANIM_STATUS_MASK := 0b11
#endregion

var _session: NetplaySession = null
var _main_game: MainGameManager = null
var _notice: Callable = Callable()
var _frame := 0
## 本地有而快照里没有的实体（entity_id → 连续缺席帧数）
var _missing: Dictionary = {}
## 动画变体属性的探测缓存：类 → {属性名: 有没有}（见 `_has_anim_prop`）
var _anim_prop_cache: Dictionary = {}


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session: NetplaySession, main_game: MainGameManager, notice: Callable = Callable()) -> void:
	_session = session
	_main_game = main_game
	_notice = notice
	if _session == null or not _session.is_linked():
		return
	## 只有主机需要每帧采集（客户端是收的一方，靠信号驱动）
	if _session.is_host():
		set_physics_process(true)
	if _session.is_client():
		if not _session.state_snapshot_received.is_connected(_on_state_snapshot_received):
			_session.state_snapshot_received.connect(_on_state_snapshot_received)
		if not _session.state_snapshot_extra_received.is_connected(_on_state_snapshot_extra_received):
			_session.state_snapshot_extra_received.connect(_on_state_snapshot_extra_received)
		## 客户端不自己造子弹：开火动画照旧本地播，但那颗子弹由主机随快照下发 ——
		## 再造一份就是"一发豌豆两颗"（见 `GlobalUtils.bullet_spawn_gate`）
		GlobalUtils.bullet_spawn_gate = _on_local_bullet_spawn


func _physics_process(_delta: float) -> void:
	if _session == null or not _session.is_linked() or not _session.is_host():
		return
	var mg := _resolve_main_game()
	if mg == null:
		return
	_frame += 1
	if _frame % max(1, send_interval_frames) != 0:
		return
	## 两包各装一类，各自都在 MTU 以内（见 `NetplaySession` 的 `state_snapshot_extra`）
	_session.send_state_snapshot(collect_snapshot(mg))
	_session.send_state_snapshot_extra(collect_snapshot_extra(mg))


func _exit_tree() -> void:
	## 换关时旧节点会先灭：闸门要还回去，别把下一局的子弹也锁住
	if GlobalUtils.bullet_spawn_gate == _on_local_bullet_spawn:
		GlobalUtils.bullet_spawn_gate = Callable()
	if _session != null and _session.state_snapshot_received.is_connected(_on_state_snapshot_received):
		_session.state_snapshot_received.disconnect(_on_state_snapshot_received)
	if _session != null and _session.state_snapshot_extra_received.is_connected(_on_state_snapshot_extra_received):
		_session.state_snapshot_extra_received.disconnect(_on_state_snapshot_extra_received)


## 生成闸门：客户端一颗子弹都不自己造（都由快照下发）
func _on_local_bullet_spawn() -> bool:
	return _session != null and _session.is_linked() and _session.is_client()


#region 采集（主机）
## 采一份"场上现在长什么样"
##
## 编码刻意用 `Packed*Array` 而不是字典数组：每只僵尸一个字典的话，30 只就 3KB，
## 超过 ENet 不可靠包的 MTU 会被整包丢掉（见文件头）。现在是每只 7 个数字，约 28 字节
## （**动画状态只占 1 个数字**：7 个动画字段挤在同一个 int 里，见 `ANIM_*` 常量）。
func collect_snapshot(mg: MainGameManager) -> Dictionary:
	var snap: Dictionary = {}
	if mg == null:
		return snap
	snap[&"f"] = _frame

	## 按字节预算排上限：第一包只有僵尸 ▶ 子弹（植物与阳光在第二包，见 `collect_snapshot_extra`）
	var z_cap := _cap_for(BYTES_PER_ZOMBIE, MAX_ZOMBIES, BYTE_BUDGET - RESERVE_BULLETS)
	var left := BYTE_BUDGET

	## 僵尸：id / 类型 / 行 / **动画状态** / 位置 / 血量
	var z_id := PackedInt32Array()
	var z_type := PackedInt32Array()
	var z_lane := PackedInt32Array()
	var z_anim := PackedInt32Array()
	var z_x := PackedFloat32Array()
	var z_y := PackedFloat32Array()
	var z_hp := PackedFloat32Array()
	if mg.zombie_manager != null:
		## 一边遍历一边可能被删（`character_death_disappear()`），先复制一份
		for z in mg.zombie_manager.all_zombies_1d.duplicate():
			if not is_instance_valid(z) or z.entity_id == 0:
				continue
			if z_id.size() >= z_cap:
				snap[&"z_cut"] = true
				break
			z_id.append(z.entity_id)
			z_type.append(int(z.zombie_type))
			z_lane.append(z.lane)
			z_anim.append(_pack_anim(z))
			z_x.append(z.global_position.x)
			z_y.append(z.global_position.y)
			z_hp.append(_hp_of(z))
	snap[&"z_id"] = z_id
	snap[&"z_type"] = z_type
	snap[&"z_lane"] = z_lane
	snap[&"z_anim"] = z_anim
	snap[&"z_x"] = z_x
	snap[&"z_y"] = z_y
	snap[&"z_hp"] = z_hp
	left -= z_id.size() * BYTES_PER_ZOMBIE

	## 子弹：id / 类型 / 位置（客户端不自己造子弹，场上飞着的由主机下发）
	var b_cap := _cap_for(BYTES_PER_BULLET, MAX_BULLETS, left)
	var b_id := PackedInt32Array()
	var b_type := PackedInt32Array()
	var b_x := PackedFloat32Array()
	var b_y := PackedFloat32Array()
	if mg.bullets != null:
		for child in mg.bullets.get_children():
			var bullet := child as Bullet000Base
			if bullet == null or not is_instance_valid(bullet) or bullet.entity_id == 0:
				continue
			if b_id.size() >= b_cap:
				snap[&"b_cut"] = true
				break
			b_id.append(bullet.entity_id)
			b_type.append(int(bullet.bullet_type))
			b_x.append(bullet.global_position.x)
			b_y.append(bullet.global_position.y)
	snap[&"b_id"] = b_id
	snap[&"b_type"] = b_type
	snap[&"b_x"] = b_x
	snap[&"b_y"] = b_y
	left -= b_id.size() * BYTES_PER_BULLET

	return snap


## 第二包：植物名册 + 场上阳光（为什么要单独一包，见 `NetplaySession` 那个信号的注释）
func collect_snapshot_extra(mg: MainGameManager) -> Dictionary:
	var snap: Dictionary = {}
	if mg == null:
		return snap
	snap[&"f"] = _frame

	var left := BYTE_BUDGET

	## 植物：id / 类型 / 格子 / 血量
	##
	## ★ 为什么连类型与格子都要发：只发血量的话，客户端**没法补种** ——
	## 一条种植命令在路上丢了 / 晚到，客户端就永远少这一株，而快照这一层存在的意义
	## 恰恰是"能把少的补回来"。带上类型与格子，客户端就能照名册自己种出来。
	var p_cap := _cap_for(BYTES_PER_PLANT, MAX_PLANTS, left - RESERVE_SUNS)
	var p_id := PackedInt32Array()
	var p_type := PackedInt32Array()
	var p_cell := PackedInt32Array()
	var p_hp := PackedFloat32Array()
	if mg.plant_cell_manager != null:
		for row in mg.plant_cell_manager.all_plant_cells:
			for cell in row:
				if not is_instance_valid(cell):
					continue
				for place in cell.plant_in_cell:
					if p_id.size() >= p_cap:
						snap[&"p_cut"] = true
						break
					## ⚠️ 只能走 `get_plant()`：植物死了槽位不清，直接下标会拿到已释放实例
					## （`get_plant()` 没标返回类型，`var x :=` 推断不出来，必须写明类型）
					var plant: Plant000Base = cell.get_plant(place)
					if not is_instance_valid(plant) or plant.entity_id == 0:
						continue
					p_id.append(plant.entity_id)
					p_type.append(int(plant.plant_type))
					p_cell.append(_pack_cell(cell))
					p_hp.append(_hp_of(plant))
	snap[&"p_id"] = p_id
	snap[&"p_type"] = p_type
	snap[&"p_cell"] = p_cell
	snap[&"p_hp"] = p_hp
	left -= p_id.size() * BYTES_PER_PLANT

	## 阳光：id / 面值 / 位置（场上飘着的每一颗，客户端照着补 / 删）
	var s_cap := _cap_for(BYTES_PER_SUN, MAX_SUNS, left)
	var s_id := PackedInt32Array()
	var s_value := PackedInt32Array()
	var s_x := PackedFloat32Array()
	var s_y := PackedFloat32Array()
	if mg.suns != null:
		for child in mg.suns.get_children():
			var sun := child as Sun
			if sun == null or not is_instance_valid(sun) or sun.entity_id == 0:
				continue
			if s_id.size() >= s_cap:
				snap[&"s_cut"] = true
				break
			s_id.append(sun.entity_id)
			s_value.append(sun.sun_value)
			s_x.append(sun.position.x)
			s_y.append(sun.position.y)
	snap[&"s_id"] = s_id
	snap[&"s_value"] = s_value
	snap[&"s_x"] = s_x
	snap[&"s_y"] = s_y

	return snap


## 格子的二维下标压成一个 int（行 × 100 + 列，列不会到 100）
static func _pack_cell(cell: PlantCell) -> int:
	var rc: Vector2i = cell.row_col
	return rc.x * 100 + rc.y


static func _unpack_cell(packed: int) -> Vector2i:
	return Vector2i(packed / 100, packed % 100)


## 还剩 `bytes` 字节时，这一类最多能装几条
static func _cap_for(bytes_per_entry: int, hard_cap: int, bytes: int) -> int:
	if bytes_per_entry <= 0:
		return 0
	return mini(hard_cap, maxi(bytes, 0) / bytes_per_entry)


## 当前血量（组件被摘掉时按 0 算，别让快照炸在这一行）
func _hp_of(character: Character000Base) -> float:
	if character == null or character.hp_component == null:
		return 0.0
	return float(character.hp_component.curr_hp)
#endregion


#region 对齐（客户端）
## 收到主机那份真相 ⇒ 照着把本地摆成同一副样子
func _on_state_snapshot_received(snap: Dictionary) -> void:
	if _session == null or _session.is_host():
		return
	var mg := _resolve_main_game()
	if mg == null:
		return
	_apply_snapshot(mg, snap)


func _apply_snapshot(mg: MainGameManager, snap: Dictionary) -> void:
	_align_zombies(mg, snap)
	_align_bullets(mg, snap)


func _on_state_snapshot_extra_received(snap: Dictionary) -> void:
	if _session == null or _session.is_host():
		return
	var mg := _resolve_main_game()
	if mg == null:
		return
	_apply_snapshot_extra(mg, snap)


## 第二包：植物名册 + 场上阳光（两包独立，丢了谁都不影响另一类，见 `NetplaySession`）
func _apply_snapshot_extra(mg: MainGameManager, snap: Dictionary) -> void:
	_align_plants(mg, snap)
	_align_suns(mg, snap)


## 子弹：位置覆盖；主机有本地没有的照类型造一颗；主机没有的缺席几帧就删
func _align_bullets(mg: MainGameManager, snap: Dictionary) -> void:
	if mg.bullets == null:
		return
	var b_id: PackedInt32Array = snap.get(&"b_id", PackedInt32Array())
	var b_type: PackedInt32Array = snap.get(&"b_type", PackedInt32Array())
	var b_x: PackedFloat32Array = snap.get(&"b_x", PackedFloat32Array())
	var b_y: PackedFloat32Array = snap.get(&"b_y", PackedFloat32Array())

	var local := {}
	for child in mg.bullets.get_children():
		var bullet := child as Bullet000Base
		if bullet != null and is_instance_valid(bullet) and bullet.entity_id != 0:
			local[bullet.entity_id] = bullet

	var seen := {}
	for i in range(b_id.size()):
		var id := b_id[i]
		seen[id] = true
		var target := Vector2(b_x[i], b_y[i])
		if local.has(id):
			var bullet: Bullet000Base = local[id]
			if is_instance_valid(bullet):
				## 直接吸附不用 `POS_LERP`：子弹飞得快，插值会一直落在后面拖出一条残影
				bullet.global_position = target
		else:
			_spawn_bullet(mg, id, b_type[i], target)

	## ⚠️ 主机那一帧**截断**了（实体太多装不下）就不能回收：
	## 本地这几颗只是"主机这一帧没采到"，不是"主机那边没有了" —— 回收会把它们误删
	if not _is_cut(snap, &"b_cut"):
		_reap_missing(mg, local, seen, _delete_bullet, MISS_FRAMES_BEFORE_DELETE_BULLET)


## 僵尸：位置 / 血量覆盖；主机有本地没有的补一只；主机没有的连续缺席够了才删
func _align_zombies(mg: MainGameManager, snap: Dictionary) -> void:
	if mg.zombie_manager == null:
		return
	var z_id: PackedInt32Array = snap.get(&"z_id", PackedInt32Array())
	var z_type: PackedInt32Array = snap.get(&"z_type", PackedInt32Array())
	var z_lane: PackedInt32Array = snap.get(&"z_lane", PackedInt32Array())
	var z_anim: PackedInt32Array = snap.get(&"z_anim", PackedInt32Array())
	var z_x: PackedFloat32Array = snap.get(&"z_x", PackedFloat32Array())
	var z_y: PackedFloat32Array = snap.get(&"z_y", PackedFloat32Array())
	var z_hp: PackedFloat32Array = snap.get(&"z_hp", PackedFloat32Array())

	var local := {}
	for z in mg.zombie_manager.all_zombies_1d.duplicate():
		if is_instance_valid(z) and z.entity_id != 0:
			local[z.entity_id] = z
			## 客户端的僵尸一律转"只渲染"（只做一次，内部用 meta 记着）
			_make_zombie_render_only(z)

	var seen := {}
	for i in range(z_id.size()):
		var id := z_id[i]
		seen[id] = true
		var target := Vector2(z_x[i], z_y[i])
		## `z_lane` 就是纯行号（动画状态在另一条 `z_anim` 里）
		var lane := z_lane[i]
		var anim := z_anim[i] if i < z_anim.size() else 0
		if local.has(id):
			var z: Zombie000Base = local[id]
			if not is_instance_valid(z):
				continue
			z.global_position = z.global_position.lerp(target, POS_LERP)
			if z.hp_component != null:
				z.hp_component.curr_hp = int(z_hp[i])
			_apply_zombie_anim(z, anim)
		else:
			## 补一只：多半是"主机这一波先出生 / 包到得晚"，照主机的编号生出来
			_spawn_zombie(mg, id, z_type[i], lane, target)

	## ⚠️ 同上：主机这一帧截断过就不能回收（否则僵尸一多，装不下的那批会被客户端误删）
	if not _is_cut(snap, &"z_cut"):
		_reap_missing(mg, local, seen, _delete_zombie)


## 这一帧主机把这一类**截断**了吗（实体太多装不下，见 `BYTE_BUDGET`）？
## 截断过就**不能回收**：本地多出来的那几颗只是"主机这一帧没采到"，不是"主机那边没有了"。
static func _is_cut(snap: Dictionary, key: StringName) -> bool:
	return bool(snap.get(key, false))


## 把本体的动画字段读成一个 int（位布局见文件头的 `ANIM_*` 常量）
func _pack_anim(z: Zombie000Base) -> int:
	var packed := 0
	if z.is_death:
		packed |= ANIM_DEATH
	if z.is_attack:
		packed |= ANIM_ATTACK
	if z.is_swimming:
		packed |= ANIM_SWIM
	if z.is_idle:
		packed |= ANIM_IDLE
	## ⚠️ 三个"变体"只在 `Zombie001Norm` 上有（其它僵尸类没这几个属性），
	## 所以走 `get()` 兜底 —— 拿不到就当 1 号，别让快照崩在不认识的僵尸类型上
	packed |= (_anim_status_of(z, &"walk_status") << ANIM_WALK_STATUS_SHIFT)
	packed |= (_anim_status_of(z, &"idle_status") << ANIM_IDLE_STATUS_SHIFT)
	packed |= (_anim_status_of(z, &"death_status") << ANIM_DEATH_STATUS_SHIFT)
	return packed


## 取一个动画变体值（1..3）；这个属性在这类僵尸上不存在就当 1 号
func _anim_status_of(z: Zombie000Base, prop: StringName) -> int:
	if not _has_anim_prop(z, prop):
		return 1
	return clampi(int(z.get(prop)), 1, ANIM_STATUS_MASK)


## 把主机下发的动画状态写回本体 —— 动画由 AnimationTree 的 `advance_expression`
## **直接读这几个字段**，所以写回它们就等价于"照主机演"，不必另发明动画协议
func _apply_zombie_anim(z: Zombie000Base, packed: int) -> void:
	z.is_attack = (packed & ANIM_ATTACK) != 0
	z.is_swimming = (packed & ANIM_SWIM) != 0
	z.is_idle = (packed & ANIM_IDLE) != 0
	var walk := (packed >> ANIM_WALK_STATUS_SHIFT) & ANIM_STATUS_MASK
	var idle := (packed >> ANIM_IDLE_STATUS_SHIFT) & ANIM_STATUS_MASK
	var death := (packed >> ANIM_DEATH_STATUS_SHIFT) & ANIM_STATUS_MASK
	_apply_anim_status(z, &"walk_status", walk)
	_apply_anim_status(z, &"idle_status", idle)
	_apply_anim_status(z, &"death_status", death)
	## 主机说它死了而本地还没死 ⇒ 补一次死亡表现（掉金币那条路已被掉落闸门拦住）。
	## 为什么必须补：客户端自己一旦不再结算伤害（关掉 `Hp_loss` 那个闸门之后），
	## 就永远走不到本地的死亡流程，僵尸会 0 血站着走，直到快照缺席 90 帧把它凭空删掉。
	## 有这一句，死亡表现就仍然由"主机说它死了"触发，而不是由本地的伤害推算。
	if (packed & ANIM_DEATH) != 0 and not z.is_death and z.hp_component != null:
		z.hp_component.Hp_loss_death(false)


func _apply_anim_status(z: Zombie000Base, prop: StringName, value: int) -> void:
	## ⚠️ `set()` 到不存在的属性会**报错**，所以先探一下（与读取同一条兜底）
	if value <= 0 or not _has_anim_prop(z, prop):
		return
	z.set(prop, value)


## 这类僵尸有没有这个"动画变体"属性？按**脚本**缓存 —— `get_property_list()` 每帧调太贵
##
## ⚠️ 缓存键必须按**脚本**算，不能用 `get_class()`：它返回的是**引擎基类**
## （普僵和僵尸基类都是同一个），结果两只僵尸共用一个键 —— 先查的那只把结果污染给另一只，
## 于是普僵被判成"没有走路变体"，变体永远同步不过去。
func _has_anim_prop(z: Zombie000Base, prop: StringName) -> bool:
	var key := _anim_prop_cache_key(z)
	var props: Dictionary = _anim_prop_cache.get(key, {})
	if props.has(prop):
		return bool(props[prop])
	var found := false
	for info in z.get_property_list():
		if StringName(info["name"]) == prop:
			found = true
			break
	props[prop] = found
	_anim_prop_cache[key] = props
	return found


## 缓存键：优先用脚本路径（每个 `.gd` 唯一），拿不到才退回 `get_class()`
func _anim_prop_cache_key(z: Zombie000Base) -> StringName:
	## ⚠️ 这里必须写死类型：`var script = get_script()` 是 Variant，
	## 后面 `var path := script.resource_path` 会**推断不出类型**而整份脚本解析失败
	var script: Script = z.get_script()
	if script != null:
		var path: String = script.resource_path
		if not path.is_empty():
			return StringName(path)
	return StringName(z.get_class())


#region 客户端僵尸转"只渲染"
##
## 客户端的僵尸**只负责演**：不索敌、不啃、不被打，判定全交给主机。
## 动画由 `z_anim` 下发（见 `_apply_zombie_anim`），所以关掉判定**不会**让动画停 ——
## 这正是上一轮必须先把动画状态同步下来的原因：顺序反了就是"僵尸 0 血站着走"。
##
## ★ **为什么不动 `move_component`**：位置每帧都被快照拉齐（`POS_LERP`），
## 本地多走的那点立刻被拉回来（60fps 下是半像素级），收益很小；而停掉它的代价很具体 ——
## 快照**截断**时（场上僵尸太多装不下，见 `BYTE_BUDGET`）那几只既收不到位置、又不会被回收，
## 会**僵在原地**。移动组件还管着地面 / 斜坡那部分表现，一并停掉画面还会缺一块。
##
## ★ **为什么不动植物**：植物的开火动画长在攻击组件里，停掉它植物就只剩静止贴图；
## 而"客户端不自己造子弹"已经由 `GlobalUtils.bullet_spawn_gate` 兜住了。
const RENDER_ONLY_META := &"netplay_render_only"


## 把这只僵尸的判定关掉，只留下渲染
func _make_zombie_render_only(z: Zombie000Base) -> void:
	if bool(z.get_meta(RENDER_ONLY_META, false)):
		return
	## ⚠️ 组件是 `@onready`，刚生出来那一帧可能还是 null —— 那就下一帧再来（meta 先不落，
	## 免得"这一次没关成"被记成"已经关过了"）
	if not is_instance_valid(z.attack_component) or not is_instance_valid(z.hurt_box_component):
		return
	## ⚠️ `disable_component` 是**粘的**：它把 Netplay 这个因素置成 false，之后任何人
	## `enable_component(别的因素)` 都拉不回来（`is_enabling` 是所有因素的**与**）。
	## 死亡 / 魅惑 / 睡眠这些正常流程里的启用不会把这道闸门顶开。
	## ⚠️ 攻击组件内部会连带禁用它自己的检测组件（见 `AttackComponentBase.disable_component`），
	## 所以**不必**再单独关一次检测组件。
	var factor := ComponentNormBase.E_IsEnableFactor.Netplay
	z.attack_component.disable_component(factor)
	z.hurt_box_component.disable_component(factor)
	z.set_meta(RENDER_ONLY_META, true)
#endregion


## 植物：照名册对齐 —— 血量覆盖、主机有本地没有的**补种**、多出来的缺席够了才回收
##
## ★ 为什么现在要能"凭空种一棵"：早先这里只拉血量，理由是"种植是命令同步的事"。
## 但命令只保证"做了什么一致"，**不保证客户端真的有这一株** ——
## 一条种植命令迟到 / 在换关的接缝里被吞掉，客户端就永远少这一株，
## 而快照这一层存在的意义恰恰就是"能把少的补回来"。不补种，这一层对植物就等于没有。
##
## ⚠️ 误删会不会把玩家刚种的抖掉：不会。种植命令是 **reliable**，
## 一个 RTT 内主机的快照里就会带上这一株，而缺席阈值有 90 帧（1.5 秒），裕量大。
func _align_plants(mg: MainGameManager, snap: Dictionary) -> void:
	if mg.plant_cell_manager == null:
		return
	var p_id: PackedInt32Array = snap.get(&"p_id", PackedInt32Array())
	var p_type: PackedInt32Array = snap.get(&"p_type", PackedInt32Array())
	var p_cell: PackedInt32Array = snap.get(&"p_cell", PackedInt32Array())
	var p_hp: PackedFloat32Array = snap.get(&"p_hp", PackedFloat32Array())

	var local := {}
	for row in mg.plant_cell_manager.all_plant_cells:
		for cell in row:
			if not is_instance_valid(cell):
				continue
			for place in cell.plant_in_cell:
				var plant: Plant000Base = cell.get_plant(place)
				if is_instance_valid(plant) and plant.entity_id != 0:
					local[plant.entity_id] = plant

	var seen := {}
	for i in range(p_id.size()):
		var id := p_id[i]
		seen[id] = true
		if local.has(id):
			_apply_plant_hp(local[id], int(p_hp[i]))
		else:
			_spawn_plant(mg, id, p_type[i], _unpack_cell(p_cell[i]))

	## 主机这一帧截断过就不能回收（同上：那几株只是"没采到"，不是"没有了"）
	if not _is_cut(snap, &"p_cut"):
		_reap_missing(mg, local, seen, _delete_plant)


func _apply_plant_hp(plant, hp: int) -> void:
	if not is_instance_valid(plant) or plant.hp_component == null:
		return
	plant.hp_component.curr_hp = hp
	## 主机这株已经被啃死了而本地还活着 ⇒ 补一次死亡表现。
	## ⚠️ 这里**没有**专门的死亡标志位：植物血量被啃到 0 就是死了，
	## 再开一条数组要多 256 字节（快照贴着 MTU，见文件头），不值当。
	## 为什么必须补，见 `_apply_zombie_anim()` 里同一段理由。
	if hp <= 0 and not plant.is_death:
		plant.hp_component.Hp_loss_death(false)


## 照主机的名册补种一株（客户端漏了的那些）
func _spawn_plant(mg: MainGameManager, id: int, plant_type: int, rc: Vector2i) -> void:
	if mg.plant_cell_manager == null:
		return
	var cells := mg.plant_cell_manager.all_plant_cells
	if rc.x < 0 or rc.x >= cells.size():
		return
	var row = cells[rc.x]
	if rc.y < 0 or rc.y >= row.size():
		return
	var cell: PlantCell = row[rc.y]
	if not is_instance_valid(cell):
		return
	## ⚠️ 第三参数 `is_plant_start_effect = false`：补种**不该**再放一次种植特效，
	## 那是"刚种下"的表现；补的是"主机那边早就有了、本地漏了"的那一株。
	## ⚠️ `place`（槽位）不用传：它由植物自己的种植条件决定，`create_plant()` 会放对
	var plant: Plant000Base = cell.create_plant(plant_type, false, false)
	if not is_instance_valid(plant):
		return
	## `create_plant()` 里已经入树领过号了，这里改成主机的编号，两端才认得同一株
	plant.assign_entity_id(id)


## 阳光：位置覆盖；主机有本地没有的补一颗；主机没有的缺席够了才回收
##
## ★ 为什么要进快照：`NetplaySunSync` 那条是**离散命令**（多一颗 / 少一颗各发一条），
## 命令只管事件、不管"现在场上到底有几颗"。哪一包在乱序里晚到、或者本地多长了一颗，
## 命令这条路上没有东西纠正得回来 —— 快照每帧整份报一遍，漏了的能补、多了的能删。
func _align_suns(mg: MainGameManager, snap: Dictionary) -> void:
	if mg.suns == null:
		return
	var s_id: PackedInt32Array = snap.get(&"s_id", PackedInt32Array())
	var s_value: PackedInt32Array = snap.get(&"s_value", PackedInt32Array())
	var s_x: PackedFloat32Array = snap.get(&"s_x", PackedFloat32Array())
	var s_y: PackedFloat32Array = snap.get(&"s_y", PackedFloat32Array())

	var local := {}
	for child in mg.suns.get_children():
		var sun := child as Sun
		if sun != null and is_instance_valid(sun) and sun.entity_id != 0:
			local[sun.entity_id] = sun

	var seen := {}
	for i in range(s_id.size()):
		var id := s_id[i]
		seen[id] = true
		var target := Vector2(s_x[i], s_y[i])
		if local.has(id):
			var sun: Sun = local[id]
			if not is_instance_valid(sun):
				continue
			## ⚠️ 正在跑下落 tween 的那颗**不要**覆盖位置：命令通道那颗正在演"弹起来再落下"，
			## 快照每帧吸附会把它按死在半空（两端都看得到它不动，只是不动的位置不同）。
			## 落定之后 tween 就结束了，位置才交回快照管。
			if _is_sun_falling(sun):
				continue
			sun.position = target
		else:
			_spawn_sun(mg, id, s_value[i], target)

	if not _is_cut(snap, &"s_cut"):
		_reap_missing(mg, local, seen, _delete_sun, MISS_FRAMES_BEFORE_DELETE_SUN)


## 这颗是不是还在下落？（见 `_align_suns` 里"不要覆盖位置"那段）
func _is_sun_falling(sun: Sun) -> bool:
	return sun.spawn_sun_tween != null and sun.spawn_sun_tween.is_valid() \
		and sun.spawn_sun_tween.is_running()


func _spawn_zombie(mg: MainGameManager, id: int, zombie_type: int, lane: int, pos: Vector2) -> void:
	## 行号越界（换过地图 / 数据不对）就别生，省得挂到错误的行节点上
	if mg.zombie_manager == null or lane < 0 or lane >= mg.zombie_manager.all_zombie_rows.size():
		return
	var para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrWave: -1,
	}
	var z := mg.zombie_manager.create_norm_zombie(zombie_type, null, para, pos)
	if z == null:
		return
	## `create_norm_zombie()` 里已经入树领过号了，这里改成主机的编号，两端才认得同一只
	z.assign_entity_id(id)


func _spawn_sun(mg: MainGameManager, id: int, sun_value: int, pos: Vector2) -> void:
	var sun: Sun = SceneRegistry.SUN.instantiate()
	if sun == null:
		return
	sun.assign_entity_id(id)
	sun.init_sun(sun_value, pos)
	mg.suns.add_child(sun)


## 本地有、主机连续好几帧都没有的实体 ⇒ 删掉（多半是主机那边已经死了 / 被捡了）
## [threshold] 缺席多少帧才判删；子弹比僵尸短得多（见 `MISS_FRAMES_BEFORE_DELETE_BULLET`）
func _reap_missing(_mg: MainGameManager, local: Dictionary, seen: Dictionary, delete: Callable,
		threshold: int = MISS_FRAMES_BEFORE_DELETE) -> void:
	for id in local.keys():
		if seen.has(id):
			_missing.erase(id)
			continue
		var missed := int(_missing.get(id, 0)) + 1
		if missed < threshold:
			_missing[id] = missed
			continue
		_missing.erase(id)
		delete.call(local[id])


func _delete_zombie(z) -> void:
	if is_instance_valid(z):
		z.queue_free()


## 回收"主机那边没有的"植物
##
## ⚠️ 为什么不走 `PlantCell.one_plant_free()`：它**只发信号**（`signal_plant_free`）
## 和收拾梯子 / 容器，**不删节点**（里面那句清空槽位的代码是被注释掉的）。
## 这里要的是"把这株真的移除"，所以直接 `queue_free()`。
## 槽位里留下的悬空引用由 `get_plant()` + `is_instance_valid()` 兜住 ——
## 植物正常死亡走的也是同一条路（槽位不清），不是这条路新引入的。
func _delete_plant(plant) -> void:
	if is_instance_valid(plant):
		plant.queue_free()


func _delete_sun(sun) -> void:
	if is_instance_valid(sun):
		sun.queue_free()


## 照主机的类型造一颗子弹（客户端不自己开火，场上的子弹全是从这里长出来的）
func _spawn_bullet(mg: MainGameManager, id: int, bullet_type: int, pos: Vector2) -> void:
	## ⚠️ `is_ignore_gate = true`：客户端自己占着"不造子弹"的闸门，重建必须绕过它，
	## 否则客户端一颗都造不出来（场上完全没有豌豆）。只有这条重建路径能传 true。
	var bullet := Global.bullet_registry.create_bullet(bullet_type, true)
	if bullet == null or mg.bullets == null:
		return
	bullet.assign_entity_id(id)
	mg.bullets.add_child(bullet)
	bullet.global_position = pos
	## ★ 这是一颗**木偶**：位置每帧由快照写，它自己不要再算飞行与命中
	## （`_physics_process` 里既跑位移也跑命中判定，留着就是客户端在跑战斗逻辑）。
	## 代价：子弹自己的动画 / 旋转（比如抛物线的翻滚）不走了 —— 待办，见 §4.11。
	bullet.set_physics_process(false)


func _delete_bullet(b) -> void:
	if is_instance_valid(b):
		b.queue_free()
#endregion


## 本节点记录的这一局还活着就用它，否则退回去问 `Global.main_game`
func _resolve_main_game() -> MainGameManager:
	if _main_game != null and is_instance_valid(_main_game):
		return _main_game
	var mg: MainGameManager = Global.main_game
	return mg if is_instance_valid(mg) else null


func _notify(text: String) -> void:
	if _notice.is_valid():
		_notice.call(text)
