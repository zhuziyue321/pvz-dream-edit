extends Node
## 联机的**阳光同步**：天上掉哪一颗由主机说了算，捡走哪一颗也要主机点头
##
## 为什么单开一个文件：`NetplayBattleSync` 管的是"玩家按下的一次操作"，
## 这里管的是**场上多出来 / 少掉一个实体** —— 阳光全是本地定时器摇出来的（`randf_range`），
## 两端各摇各的，连"场上有没有这一颗"都对不上；拾取则要回答"点的是哪一颗"，
## 光有 `ADD_SUN_VALUE`（只带数值）说不清，所以两步合起来才是一件事。
##
## 做法（与波次同步同一套：**闸门 + 观测口**，本体只多两个通用问询口）：
##   host   任一生成点 ──▶ `SUN_SPAWNED(sun)` ──▶ 下发 `sun_spawn(编号/值/起点/落点/时长)`
##   client              `GlobalUtils.sun_spawn_gate` 占住：本地一条都不长
##                       收到 `sun_spawn` ⇒ 在同一处长出同一颗（**位置不归这条命令管**，见下）
##
## ★ **位置归快照管，命令只管"多了这一颗"**（`NetplayStateSync` 每帧下发每一颗的坐标）：
##   客户端**不再自己重放那一下下落**。早先照主机给的"落点 + 时长"自己起一遍 tween，
##   两端跑的是两条时间轴 —— 下落那一段始终差着整整一个 RTT 的位移（落点对得上，过程对不上）。
##   现在客户端不起 tween，位置逐帧抄主机 ⇒ 场上**每一颗**阳光在两端都在同一处。
##   代价：客户端没有"落地那一刻"的 tween 回调（`on_sun_tween_finished`）——
##   自动收集阳光改由**位置到达落点**来判（`NetplayStateSync._check_sun_landed`）。
##
## 拾取走的是现成的主机权威链路（`NetplayBattleSync` 的重放表）：
##   client 点一颗 ──上行 `pick_sun(编号)`──▶ host 摘掉自己那颗 ──下行──▶ 屋里的每一个人摘同一颗
##
## ⚠️ 闸门只有**一个**（`GlobalUtils.sun_spawn_gate`），天降与向日葵共用：
## 上一版在天降管理器上另开了一个 `spawn_sun_gate`，模组却只装了全局那个 ——
## 结果客户端的天降**根本没被拦住**，而探针还报 PASS（它只验了"闸门装上了"，没验"被谁读"）。
##
## ★ **客户端自己长的那一颗也归主机**：正常情况下客户端**根本不会自己长**（生成闸门占着），
##   但若哪天有个生成点漏装了闸门，那颗会既不同步、又被快照的缺席回收凭空删掉 ⇒
##   客户端发现它就**删掉本地那颗 + 上行 `sun_claim`**，请主机照同样的数据也长一颗，
##   主机那颗照常下发 ⇒ 两端一致（见下面「客户端：本地自己长的那一颗」那一段）。
## ⚠️ 早先这里写着"僵尸掉落的阳光还没收归主机"是**误记**：`DropItemComponent` 只掉
## 金币 / 花园植物 / 巧克力，压根不掉阳光 —— 生成点全景见 [联机模组](../../docs/参考存档/联机模组.md) §4.8。
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜ [联机模组规范](../../docs/参考存档/联机模组规范.md)

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录 / 上级的文件一律 preload 成常量再引用，不能写 `extends Xxx` / `var x: Xxx`
const NetplayCommand := preload("netplay_command.gd")

const SELF_NODE_NAME := "NetplaySunSync"

var _session = null
var _main_game: MainGameManager = null
var _notice: Callable = Callable()
## 主机下发下来的那些阳光的编号（客户端用：只有这些"有身份"的才走主机权威）
var _known_sun_ids: Dictionary = {}
## 主机**当前**名册里的阳光编号（来自第二包快照）：用来认出"本地这一颗主机那局上没有"
var _host_sun_ids: Dictionary = {}
## 已经收到过主机的名册了吗（没收到过就别判断 —— 那时候会误判成"全是自长的"）
var _got_host_roster := false
## 上一份名册**被截断**了吗（截断 ⇒ 名册不完整 ⇒ 不能拿它判断"主机没有这一颗"）
var _host_roster_cut := false
## 已经请过主机的那些本地编号（一颗只请一次，免得主机长出好几颗）
var _claimed_sun_ids: Dictionary = {}
## 「等认领」的那些颗：本地编号 → 阳光节点（主机把编号回填回来时靠它认人）
var _pending_suns: Dictionary = {}


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session, main_game: MainGameManager, notice: Callable = Callable()) -> void:
	_session = session
	_main_game = main_game
	_notice = notice
	if _session == null or not _session.is_linked():
		return
	## ⚠️ 不能在 `setup()` 里直接接线：模组装在 `day_suns_manager.init_manager()` **之前**，
	## 那一刻子管理器还没就位。推到帧末，第一颗天降阳光远在后面几帧，闸门来得及生效。
	call_deferred("_install")


func _exit_tree() -> void:
	## 换关时旧节点会先灭：闸门要还回去，别把下一局的阳光也锁住
	EventBus.unsubscribe(ConstEventName.SUN_SPAWNED, _on_host_sun_spawned)
	if GlobalUtils.sun_spawn_gate == _on_local_sun_spawn:
		GlobalUtils.sun_spawn_gate = Callable()
	if _session != null and _session.state_snapshot_extra_received.is_connected(_on_state_snapshot_extra_received):
		_session.state_snapshot_extra_received.disconnect(_on_state_snapshot_extra_received)


## 真正接线（帧末执行一次）
func _install() -> void:
	if _session == null or not _session.is_linked():
		return
	if not _session.battle_op_received.is_connected(_on_battle_op_received):
		_session.battle_op_received.connect(_on_battle_op_received)
	if _session.is_host():
		## 主机：自己照旧长，长一颗就把这一颗发下去。
		## 订阅的是**全局事件**而不是某个管理器的信号 —— 天降 / 植物产 / 掉落都在这一条上，
		## 一处订阅全覆盖（生成点各自在落点写完之后才推，见 `ConstEventName.SUN_SPAWNED` 的注释）
		EventBus.subscribe(ConstEventName.SUN_SPAWNED, _on_host_sun_spawned)
		return
	## 客户端：本地的定时器不再掉阳光
	## （点阳光那一下的上行不在这里 —— 所有玩家操作统一由 `NetplayActionGateway` 发出去，
	##  它只问本节点一句"这一颗是主机下发过的吗"，见 `is_host_spawned()`）
	GlobalUtils.sun_spawn_gate = _on_local_sun_spawn
	## ★ 主机的名册（快照第二包）—— 用来认出"本地这一颗主机那局上没有"
	if not _session.state_snapshot_extra_received.is_connected(_on_state_snapshot_extra_received):
		_session.state_snapshot_extra_received.connect(_on_state_snapshot_extra_received)


#region 主机：掉一颗就发一颗
func _on_host_sun_spawned(sun: Sun) -> void:
	if _session == null or not _session.is_host():
		return
	if sun == null or not is_instance_valid(sun):
		return
	## ★ 「认领」来的那一颗**不从这里下发**：认领那条命令已经带全了
	##   （编号 / 起点 / 落点 / 用时 / 面值），再发一遍标准 `sun_spawn`
	##   会让客户端**同编号长出两颗**（一颗新建 + 一颗原地改的）。
	if sun.has_meta(NetplayCommand.META_SUN_CLAIMED):
		return
	_session.request_battle_op(NetplayCommand.build(NetplayCommand.OP_SUN_SPAWN, {
		NetplayCommand.ARG_SUN_ID: sun.entity_id,
		NetplayCommand.ARG_SUN_VALUE: sun.sun_value,
		NetplayCommand.ARG_FROM: sun.position,
		NetplayCommand.ARG_TO: sun.spawn_target,
		NetplayCommand.ARG_FALL: sun.spawn_fall,
	}))
#endregion


#region 客户端：本地不掉
## 生成闸门：客户端一条都不自己长（天降 + 向日葵都归主机下发）
func _on_local_sun_spawn() -> bool:
	return _session != null and _session.is_linked() and _session.is_client()


## 这一颗是不是**主机下发过的**（`NetplayActionGateway` 点阳光时先问这一句）
##
## 只有这些走主机权威：主机那一局上有同一颗，才能"两端摘同一颗"。
## ⚠️ 客户端自己长的那一颗**现在也会归主机**（请主机也长一颗，见下面的「自长」那一段），
##   所以场上留着的每一颗都是主机给的 —— 这里判 true 才上行，不会让玩家"点着点不动"。
func is_host_spawned(sun: Sun) -> bool:
	if sun == null or not is_instance_valid(sun):
		return false
	return _known_sun_ids.has(sun.entity_id)
#endregion


#region 客户端：本地自己长的那一颗 ⇒ 请主机也长一颗
## 主机的名册（快照第二包）：记下"主机当前有哪几颗"
##
## ★ 为什么不能只拿编号认"主机给的"：两端的 `entity_id` **各自独立自增**，
##   同一颗阳光在两端拿到的本地编号往往**相同** ⇒ 客户端自己长的那颗与主机的某一颗
##   编号撞上，拿编号认根本分不开。真正判"是不是主机给的"靠**实例级标记**
##   （`NetplayCommand.META_SUN_FROM_HOST`），名册只用来兜底。
func _on_state_snapshot_extra_received(snap: Dictionary) -> void:
	if _session == null or _session.is_host():
		return
	var ids: PackedInt32Array = snap.get(&"s_id", PackedInt32Array())
	_host_sun_ids.clear()
	for id in ids:
		_host_sun_ids[id] = true
		## 名册里出现过的 ⇒ 主机给的（拾取该不该上行也认它，见 `is_host_spawned()`）
		_known_sun_ids[id] = true
	_got_host_roster = true
	## ⚠️ **截断时名册不完整** ⇒ 不能拿它判断"主机没有这一颗"（见 `_physics_process`）
	_host_roster_cut = bool(snap.get(&"s_cut", false))


## 客户端每帧扫一遍：本地有没有"主机那局上不存在"的阳光
##
## ⚠️ **正常情况下不会有**：客户端的生成闸门占着，五处生成点一条都不长。
##   这一段是给"哪天有哪个生成点漏装了闸门"兜底的 —— 漏了的那颗若放着不管：
##   ① 两端数量对不上；② 它还会被快照的缺席回收**凭空删掉**（本地老路与快照名册打架）。
## ⇒ 发现它 ⇒ **删掉本地那颗**（免得与主机长出来的那颗重影）⇒ 上行 `sun_claim`，
##   请主机照着同样的数据也长一颗 ⇒ 主机那颗照常下发 ⇒ 两端一致。
func _physics_process(_delta: float) -> void:
	if _session == null or not _session.is_linked() or not _session.is_client():
		return
	## ⚠️ **名册还没到 / 名册被截断时一律不判断**：前者会把主机下发的全当成"自长的"，
	##   后者的名册不完整、会把"这帧没采到的主机阳光"当成"自长的"⇒ 误删 ⇒ 两端直接对不上。
	if not _got_host_roster or _host_roster_cut:
		return
	var mg := _resolve_main_game()
	if mg == null or mg.suns == null or not is_instance_valid(mg.suns):
		return
	var locals: Array[Sun] = []
	for child in mg.suns.get_children():
		var sun := child as Sun
		if sun == null or not is_instance_valid(sun) or sun.entity_id == 0:
			continue
		## ★ **有标记的 = 主机给的**（命令下发的 / 快照补种的）⇒ 不碰
		if sun.has_meta(NetplayCommand.META_SUN_FROM_HOST):
			continue
		if _claimed_sun_ids.has(sun.get_instance_id()):
			continue
		locals.append(sun)
	for sun in locals:
		## ★ 记的是**实例**而不是编号：编号会被主机回收再利用，记编号会漏掉后面那几颗
		_claimed_sun_ids[sun.get_instance_id()] = true
		var src_id := sun.entity_id
		## ★ **不删本地那颗**（删了就得重建 ⇒ 玩家看到它「闪一下」：出现 → 消失 → 再出现）。
		##   改成「等认领」的临时编号，等主机把它的编号回填回来再**原地改**过去 ——
		##   屏幕上自始至终是同一颗。
		##   这个临时编号主机永远不会发 ⇒ 不会与主机的名册撞上
		##   （两端 `entity_id` 各自独立自增，同一颗在两端编号往往相同 ⇒ 撞上就会被串位）。
		sun.assign_entity_id(NetplayCommand.PENDING_SUN_ID)
		sun.set_meta(NetplayCommand.META_SUN_PENDING, true)
		_pending_suns[src_id] = sun
		_claim_to_host(sun, src_id)


## 请主机也长一模一样的一颗（上行 `sun_claim`）
##
## ★ **把自己的本地编号带上**（`ARG_SUN_SRC_ID`）：主机回填它那颗的编号之后，
##   客户端靠这个认出「是哪一颗要原地改编号」—— 不带的话客户端只能删了重建 ⇒ 闪一下。
## ⚠️ 这个编号**只当身份用**：两端各自独立自增，同一颗在两端编号往往相同。
func _claim_to_host(sun: Sun, src_id: int) -> void:
	var battle_sync = _session.get_battle_sync() if _session != null else null
	if battle_sync == null or not is_instance_valid(battle_sync):
		return
	var to := sun.spawn_target
	## 落点是 ZERO = 那一颗压根没写落点（绕过生成口长出来的）⇒ 就让它落在当时的位置
	if to == Vector2.ZERO:
		to = sun.position
	battle_sync.handle_local_command(NetplayCommand.build(NetplayCommand.OP_SUN_CLAIM, {
		NetplayCommand.ARG_SUN_SRC_ID: src_id,
		NetplayCommand.ARG_SUN_VALUE: sun.sun_value,
		NetplayCommand.ARG_FROM: sun.position,
		NetplayCommand.ARG_TO: to,
		NetplayCommand.ARG_FALL: sun.spawn_fall,
	}))


## 主机把编号回填回来了 ⇒ **原地改编号**（认领成功）
##
## ① 是我上报的那颗 ⇒ 改成主机的编号：屏幕上是同一颗，**不闪**。
##    位置从此归快照管 ⇒ 本地那一下下落**收掉**（不收就是两个东西抢同一个位置 ⇒ 抖）；
##    落地回调也随之没了 ⇒ 自动收集改由落点判定接管（`NetplayStateSync._check_sun_landed`）。
## ② 房里别的客户端 ⇒ 本地没有这一颗 ⇒ **新建**（数据都在这条命令里）。
func _on_sun_claim_received(args: Dictionary) -> void:
	var host_id := int(args.get(NetplayCommand.ARG_SUN_ID, 0))
	if host_id == 0:
		return
	var src_id := int(args.get(NetplayCommand.ARG_SUN_SRC_ID, 0))
	var mine: Sun = _pending_suns.get(src_id, null)
	if mine != null and is_instance_valid(mine):
		_pending_suns.erase(src_id)
		mine.assign_entity_id(host_id)
		mine.spawn_target = Vector2(args.get(NetplayCommand.ARG_TO, Vector2.ZERO))
		mine.spawn_fall = float(args.get(NetplayCommand.ARG_FALL, 0.0))
		mine.set_meta(NetplayCommand.META_SUN_FROM_HOST, true)
		mine.remove_meta(NetplayCommand.META_SUN_PENDING)
		## 位置从此归快照管：本地那一下下落**收掉**（不收就是两个东西抢同一个位置 ⇒ 抖）
		if mine.spawn_sun_tween != null and mine.spawn_sun_tween.is_valid():
			mine.spawn_sun_tween.kill()
		_known_sun_ids[host_id] = true
		return
	## ② 本地没有这一颗（房里别的客户端）⇒ 新建一颗（与标准 `sun_spawn` 同一套）
	_spawn_from_host(args)
#endregion


#region 客户端：照着主机的数据长出同一颗
func _on_battle_op_received(op: StringName, args: Dictionary) -> void:
	if _session == null or _session.is_host():
		return
	if op == NetplayCommand.OP_SUN_CLAIM:
		## ★ 主机把编号回填回来了 ⇒ 原地改编号（不闪）
		_on_sun_claim_received(args)
		return
	if op != NetplayCommand.OP_SUN_SPAWN:
		return
	_spawn_from_host(args)


func _spawn_from_host(args: Dictionary) -> void:
	var sun_id := int(args.get(NetplayCommand.ARG_SUN_ID, 0))
	if sun_id == 0:
		return
	var mg := _resolve_main_game()
	if mg == null or mg.suns == null or not is_instance_valid(mg.suns):
		return
	var existing := _find_sun(mg, sun_id)
	if existing != null:
		## ★ **快照先到、命令后到**：那颗是快照补种出来的（**没有落点**）——
		##   这里把落点与用时补上，"落地判定"（自动收集）才用得上。
		existing.spawn_target = Vector2(args.get(NetplayCommand.ARG_TO, Vector2.ZERO))
		existing.spawn_fall = float(args.get(NetplayCommand.ARG_FALL, 0.0))
		existing.set_meta(NetplayCommand.META_SUN_FROM_HOST, true)
		return  ## 已经有了（重发 / 重复下发），别长出第二颗
	var sun: Sun = SceneRegistry.SUN.instantiate()
	## 编号在入树**之前**塞进去：`_ready()` 看到非 0 就不再自己分配，两端才是同一个编号
	sun.assign_entity_id(sun_id)
	sun.init_sun(int(args.get(NetplayCommand.ARG_SUN_VALUE, 25)),
		Vector2(args.get(NetplayCommand.ARG_FROM, Vector2.ZERO)))
	sun.spawn_target = Vector2(args.get(NetplayCommand.ARG_TO, Vector2.ZERO))
	sun.spawn_fall = float(args.get(NetplayCommand.ARG_FALL, 0.0))
	## ★ 打标记：这颗是主机给的（`is_host_spawned()` 与"自长检测"都认它）
	sun.set_meta(NetplayCommand.META_SUN_FROM_HOST, true)
	mg.suns.add_child(sun)
	_known_sun_ids[sun_id] = true
	## ★ **不再自己演那一下下落**（`SunSpawner.replay_fall` 已随之删除）：
	## 位置逐帧由 `NetplayStateSync` 的快照接管（每颗阳光的坐标都在第二包里）。
	## 客户端不起 tween ⇒ 也就没有"落地那一刻"的回调，自动收集改由落点判定触发
	## （见 `NetplayStateSync._check_sun_landed`）。
	## 落点 / 时长仍然记在这颗阳光上：`spawn_target` 是落点判定的依据，
	## `spawn_fall` 记着主机那一趟的用时（两端字段一致，将来要恢复本地重放也不用改命令格式）。
#endregion


#region 小工具
func _find_sun(mg: MainGameManager, sun_id: int) -> Sun:
	if mg == null or mg.suns == null or not is_instance_valid(mg.suns):
		return null
	for child in mg.suns.get_children():
		var sun := child as Sun
		if sun == null or not is_instance_valid(sun):
			continue
		if sun.entity_id == sun_id:
			return sun
	return null


func _day_suns_manager() -> DaySunsManagner:
	var mg := _resolve_main_game()
	if mg == null or mg.day_suns_manager == null:
		return null
	var manager: DaySunsManagner = mg.day_suns_manager
	return manager if is_instance_valid(manager) else null


## 本节点记录的这一局还活着就用它，否则退回去问 `GameContext.curr_main_game`
## （换关时旧节点会先灭再换新，用"活着的那一份"才不会对着空气操作）
func _resolve_main_game() -> MainGameManager:
	if _main_game != null and is_instance_valid(_main_game):
		return _main_game
	var mg: MainGameManager = GameContext.curr_main_game
	return mg if is_instance_valid(mg) else null


func _notify(text: String) -> void:
	if _notice.is_valid():
		_notice.call(text)
#endregion
