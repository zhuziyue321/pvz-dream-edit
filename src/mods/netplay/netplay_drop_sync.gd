extends Node
class_name NetplayDropSync
## 联机的**掉落物同步**：掉不掉、掉哪一种、落在哪儿由主机说了算，捡走哪一枚也要主机点头
##
## 与 [NetplaySunSync] 完全同一套（**闸门 + 观测口**），只是对象从阳光换成金币 / 巧克力：
##
##   host   生成点 ──▶ `DROP_ITEM_SPAWNED(drop)` ──▶ battle_op(drop_item: 编号/种类/起点/落点)
##   client            `GlobalUtils.drop_gate` 占住：本地一件都不掉
##                     收到 `drop_item` ⇒ 照着数据在同一处长出同一枚
##
##   client 点一枚 ──上行 `pick_drop(编号)`──▶ host 收走自己那枚 ──下行──▶ 屋里的每一个人收同一枚
##
## **为什么这属于"客户端不该跑战斗逻辑"**：
## "这只僵尸死了掉什么"是一次掷骰（`randf()` 定概率、`randf()` 定落点），
## 客户端自己掷就会掷出另一枚 —— 掉的种类、位置、时机全都对不上，钱数也就各记一笔。
##
## 边界（与阳光那边的取舍一致）：
## - **礼包 `Present` 不归这里管** —— 那是解锁道具 / 战利品 / 关卡结算线，
##   时机由**关卡数据**决定（确定性），拾取还要写存档、触发本关结算；拦了会断关卡流程。
## - 只接管**主机下发过的**那些掉落物：客户端自己长的（不该有，但兜个底）没有主机编号，
##   点它照单机那样本地生效 —— 宁可不同步，也不能让玩家点着点不动。
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜ [联机模组规范](../../docs/参考存档/联机模组规范.md)

const SELF_NODE_NAME := "NetplayDropSync"

var _session: NetplaySession = null
var _main_game: MainGameManager = null
var _notice: Callable = Callable()
## 主机下发下来的那些掉落物的编号（客户端用：只有这些"有身份"的才走主机权威）
var _known_drop_ids: Dictionary = {}


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session: NetplaySession, main_game: MainGameManager, notice: Callable = Callable()) -> void:
	_session = session
	_main_game = main_game
	_notice = notice
	if _session == null or not _session.is_linked():
		return
	## ⚠️ 不能在 `setup()` 里直接接线：模组装在 `drop_item_manager.init_manager()` **之前**，
	## 那一刻子管理器还没就位。推到帧末，第一件掉落远在后面几帧，闸门来得及生效
	call_deferred("_install")


func _exit_tree() -> void:
	## 换关时旧节点会先灭：闸门要还回去，别把下一局的掉落也锁住
	EventBus.unsubscribe(ConstEventName.DROP_ITEM_SPAWNED, _on_host_drop_spawned)
	if GlobalUtils.drop_gate == _on_local_drop:
		GlobalUtils.drop_gate = Callable()


## 真正接线（帧末执行一次）
func _install() -> void:
	if _session == null or not _session.is_linked():
		return
	if not _session.battle_op_received.is_connected(_on_battle_op_received):
		_session.battle_op_received.connect(_on_battle_op_received)
	if _session.is_host():
		## 主机：自己照旧掉，掉一件就把这一件发下去（金币与巧克力都在这一条事件上）
		EventBus.subscribe(ConstEventName.DROP_ITEM_SPAWNED, _on_host_drop_spawned)
		return
	## 客户端：本地一件都不掉
	## （点掉落物那一下的上行不在这里 —— 所有玩家操作统一由 `NetplayActionGateway` 发出去，
	##  它只问本节点一句"这一枚是主机下发过的吗"，见 `is_host_spawned()`）
	GlobalUtils.drop_gate = _on_local_drop


#region 主机：掉一件就发一件
func _on_host_drop_spawned(drop: Node) -> void:
	if _session == null or not _session.is_host():
		return
	if drop == null or not is_instance_valid(drop):
		return
	var kind := _kind_of(drop)
	if kind < 0:
		return
	_session.request_battle_op(NetplayCommand.build(NetplayCommand.OP_DROP_ITEM, {
		NetplayCommand.ARG_SUN_ID: _id_of(drop),
		NetplayCommand.ARG_DROP_KIND: kind,
		NetplayCommand.ARG_FROM: _position_of(drop),
		NetplayCommand.ARG_TO: _spawn_target_of(drop),
	}))


## 这一件是哪种 / 编号几 / 落在哪儿（两类掉落物字段名不同，在这里收口）
static func _kind_of(drop: Node) -> int:
	if drop is Coin:
		return (drop as Coin).drop_kind
	if drop is ChocolateDrop:
		return (drop as ChocolateDrop).drop_kind
	return -1


static func _id_of(drop: Node) -> int:
	if drop is Coin:
		return (drop as Coin).entity_id
	if drop is ChocolateDrop:
		return (drop as ChocolateDrop).entity_id
	return 0


func _position_of(drop: Node) -> Vector2:
	return (drop as Node2D).global_position if drop is Node2D else Vector2.ZERO


static func _spawn_target_of(drop: Node) -> Vector2:
	if drop is Coin:
		return (drop as Coin).spawn_target
	if drop is ChocolateDrop:
		return (drop as ChocolateDrop).spawn_target
	return Vector2.ZERO
#endregion


#region 客户端：本地不掉
func _on_local_drop() -> bool:
	return _session != null and _session.is_linked() and _session.is_client()


## 这一枚是不是**主机下发过的**（`NetplayActionGateway` 点掉落物时先问这一句）
##
## 只有这些走主机权威（主机那一局上有同一枚，才能"两端收同一枚"）；
## 客户端自己长的那一枚没有主机编号，接管只会得到"点不动"，放它回本机的老路。
func is_host_spawned(drop: Node) -> bool:
	if drop == null or not is_instance_valid(drop):
		return false
	return _known_drop_ids.has(_id_of(drop))
#endregion


#region 客户端：照着主机的数据长出同一枚
func _on_battle_op_received(op: StringName, args: Dictionary) -> void:
	if _session == null or _session.is_host():
		return
	if op != NetplayCommand.OP_DROP_ITEM:
		return
	_spawn_from_host(args)


func _spawn_from_host(args: Dictionary) -> void:
	var drop_id := int(args.get(NetplayCommand.ARG_SUN_ID, 0))
	if drop_id == 0:
		return
	var mg := _resolve_main_game()
	if mg == null or mg.drop_item_manager == null or not is_instance_valid(mg.drop_item_manager):
		return
	if find_drop_by_id(mg, drop_id) != null:
		return  ## 已经有了（重发 / 重复下发），别掉出第二枚
	var kind := int(args.get(NetplayCommand.ARG_DROP_KIND, -1))
	var from_pos := Vector2(args.get(NetplayCommand.ARG_FROM, Vector2.ZERO))
	var to_pos := Vector2(args.get(NetplayCommand.ARG_TO, Vector2.ZERO))
	var drop := mg.drop_item_manager.create_drop_of_kind(kind, drop_id, from_pos, to_pos)
	if drop == null:
		return
	_known_drop_ids[drop_id] = true
#endregion


#region 小工具
## 收走这一件（**主机重放**用：走的是本体的拾取入口，音效 / 飞向钱袋 / 入账都不用抄一遍）
static func collect_drop_by_id(mg: MainGameManager, drop_id: int) -> bool:
	var drop := find_drop_by_id(mg, drop_id)
	if drop == null:
		return false
	if drop is Coin:
		(drop as Coin).collect()
		return true
	if drop is ChocolateDrop:
		(drop as ChocolateDrop)._on_texture_button_pressed()
		return true
	return false


## 在两堆父节点里按编号找一件掉落物（金币与巧克力不在同一个父节点下）
static func find_drop_by_id(mg: MainGameManager, drop_id: int) -> Node:
	if drop_id == 0:
		return null
	if mg == null or mg.drop_item_manager == null or not is_instance_valid(mg.drop_item_manager):
		return null
	var parents: Array[Node] = []
	if mg.drop_item_manager.dim_coin != null and is_instance_valid(mg.drop_item_manager.dim_coin):
		parents.append(mg.drop_item_manager.dim_coin.all_drop_coin_parent)
	if mg.drop_item_manager.dim_chocolate != null and is_instance_valid(mg.drop_item_manager.dim_chocolate):
		parents.append(mg.drop_item_manager.dim_chocolate.all_drop_chocolate_parent)
	for parent in parents:
		if parent == null or not is_instance_valid(parent):
			continue
		for child in parent.get_children():
			if _id_of(child) == drop_id and _id_of(child) != 0:
				return child
	return null


## 本节点记录的这一局还活着就用它，否则退回去问 `Global.main_game`
func _resolve_main_game() -> MainGameManager:
	if _main_game != null and is_instance_valid(_main_game):
		return _main_game
	var mg: MainGameManager = Global.main_game
	return mg if is_instance_valid(mg) else null


func _notify(text: String) -> void:
	if _notice.is_valid():
		_notice.call(text)
#endregion
