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
##                       收到 `sun_spawn` ⇒ 照着数据在同一处、同样快地长出同一颗
##
## 拾取走的是现成的主机权威链路（`NetplayBattleSync` 的重放表）：
##   client 点一颗 ──上行 `pick_sun(编号)`──▶ host 摘掉自己那颗 ──下行──▶ 屋里的每一个人摘同一颗
##
## ⚠️ 闸门只有**一个**（`GlobalUtils.sun_spawn_gate`），天降与向日葵共用：
## 上一版在天降管理器上另开了一个 `spawn_sun_gate`，模组却只装了全局那个 ——
## 结果客户端的天降**根本没被拦住**，而探针还报 PASS（它只验了"闸门装上了"，没验"被谁读"）。
##
## 边界：不是每一颗阳光都归主机 —— 客户端自己长的那一颗（例如某些关卡脚本直接生成的）
## 没有主机编号，主机那一局上根本不存在它，点它照单机那样本地生效
## （`is_host_spawned()` 挡着）：宁可不同步，也不能让玩家点着点不动。
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


#region 主机：掉一颗就发一颗
func _on_host_sun_spawned(sun: Sun) -> void:
	if _session == null or not _session.is_host():
		return
	if sun == null or not is_instance_valid(sun):
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
## 客户端自己长的那一颗没有主机编号 —— 主机那边根本不存在它，接管只会得到"点不动"，
## 所以放它回本机的老路：不同步，但照样能收。
func is_host_spawned(sun: Sun) -> bool:
	if sun == null or not is_instance_valid(sun):
		return false
	return _known_sun_ids.has(sun.entity_id)
#endregion


#region 客户端：照着主机的数据长出同一颗
func _on_battle_op_received(op: StringName, args: Dictionary) -> void:
	if _session == null or _session.is_host():
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
	if _find_sun(mg, sun_id) != null:
		return  ## 已经有了（重发 / 重复下发），别长出第二颗
	var sun: Sun = SceneRegistry.SUN.instantiate()
	## 编号在入树**之前**塞进去：`_ready()` 看到非 0 就不再自己分配，两端才是同一个编号
	sun.assign_entity_id(sun_id)
	sun.init_sun(int(args.get(NetplayCommand.ARG_SUN_VALUE, 25)),
		Vector2(args.get(NetplayCommand.ARG_FROM, Vector2.ZERO)))
	sun.spawn_target = Vector2(args.get(NetplayCommand.ARG_TO, Vector2.ZERO))
	sun.spawn_fall = float(args.get(NetplayCommand.ARG_FALL, 0.0))
	mg.suns.add_child(sun)
	_known_sun_ids[sun_id] = true
	_fall_to_target(sun)


## 照主机给的两个点走一段下落（起终点一致，两端才落在同一处）
func _fall_to_target(sun: Sun) -> void:
	var to := sun.spawn_target
	if to == Vector2.ZERO:
		return
	## 时长也照主机给的来：天降是"距离 / 速度"（慢悠悠），向日葵吐的是固定 0.9 秒（弹一下），
	## 客户端自己按速度算会把后者变成 0.15 秒 —— 位置对得上，看着对不上
	var duration := maxf(sun.spawn_fall, 0.05)
	sun.spawn_sun_tween = sun.create_tween()
	sun.spawn_sun_tween.set_parallel()
	if abs(to.x - sun.position.x) > 0.5:
		sun.spawn_sun_tween.tween_property(sun, "position:x", to.x, duration)
	sun.spawn_sun_tween.tween_property(sun, "position:y", to.y, duration)
	sun.spawn_sun_tween.finished.connect(sun.on_sun_tween_finished)
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
