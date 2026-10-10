extends Node
class_name NetplaySession
## 联机会话：ENet 主机 / 客户端连接 + 命令收发
##
## 管的三件事：
##   1. 连接状态机（创建主机 / 加入主机 / 断线）
##   2. 命令收发（`receive_command` 上行、`battle_op` / 快照下行）
##   3. 房间方位（进关 / 退关 / 通关裁决 / 准备状态 / 随机种子）
##
## ★ **不**管玩家操作怎么采集：那是 `NetplayActionGateway` 的事 ——
##   它占住本体的统一上报口 `GlobalUtils.player_action_gate`，把操作翻成命令后交给
##   `NetplayBattleSync`（由 `attach_battle_sync()` 登记在这里，`get_battle_sync()` 取回）。
##
## 为什么会话挂在 root 而不是挂在 `MainGameManager` 下：连线要跨场景存活 ——
## 双方得先在主菜单连上、再一起进关卡；挂在主游戏下会跟着关卡一起被销毁。
##
## 界面在哪：**全部在控制台**（`NetplayMod.register_console_entries()` 挂的「联机」栏）——
## 状态 / 最近流水是两行只读文本条目，会话一发信号就 `request_refresh()` 刷新。

## 默认端口（原版没有联机，端口随便挑一个不常用的）
const DEFAULT_PORT := 8912
const DEFAULT_ADDRESS := "127.0.0.1"
## 房间上限：合作共守一块草坪，先按 2 人 + 余量
const MAX_PLAYERS := 4
## 主机在 Godot 高层多人 API 里的 peer id 恒为 1
const SERVER_PEER_ID := 1

## 本机角色
enum E_Role { None, Host, Client }
## 连接状态
enum E_State { Idle, Hosting, Connecting, Connected, Failed }

## 状态变化（控制台那行「状态」据此刷新）
signal state_changed(state: E_State)
## 有人进来 / 有人掉线
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
## 收到对端的一条命令
signal command_received(from_peer_id: int, command: Dictionary)
## 房主开了一关 / 换了关：**客户端该跟进去**了（携带关卡标识，格式见 `NetplayMod`）
signal level_enter_requested(level_key: Dictionary)
## 房主退出了关卡：**客户端也跟着退出**（同进同出）
signal level_leave_requested()
## 有一个人**自己**退出了这一关（房主据此不再等他准备，见 `waiting_peer_ids()`）
signal peer_level_left(peer_id: int)
## 房间没了：房主关了房间 / 本机（客户端）与主机断开 —— 在关里的人该退回选关页
signal room_closed()
## 房主对本关结果的裁决（通关与否以房主为准）：key 是 `ResourceLevelData.save_game_name`
signal level_result_received(save_game_name: String, success: bool)
## 对端的选卡结果变了（元素是 `ResourceCardReference.to_dict()`）
signal card_selection_received(from_peer_id: int, selections: Array)
## 对端请你把选卡再报一遍
signal card_selection_refresh_requested()
## 一行流水日志（控制台那行「最近一条」显示最新的那条）
signal session_log(text: String)

## 主机下令：这一条操作**已经生效**（客户端照着做一遍自己的）
signal battle_op_received(op: StringName, args: Dictionary)
## 主机下发了这一局的随机种子（`GameRng.set_seed()` 的值）
signal battle_seed_received(seed_value: int)
## 主机广播了这一帧的**战斗快照**（客户端据此把场面对齐，见 `NetplayStateSync`）
## 走的是 unreliable：丢一帧下一帧就补上，不值得为它重传
signal state_snapshot_received(snapshot: Dictionary)
## 同一帧的**第二包快照**（植物 + 阳光）
##
## ★ 为什么要拆两包：ENet 的不可靠包**不分片**，超 MTU（约 1400B）就整包丢弃。
## 把植物与阳光补进快照之后，满盘一局（僵尸 25 + 子弹 20 + 植物 45 + 阳光 10）约 1900B，
## 一包装不下 —— 硬挤的结果就是植物被字节预算截断到十几株（满盘有 45 株），
## 而截断时又不能回收，等于"植物这一档名存实亡"。拆包后两类各自都有完整预算。
## ⚠️ 两包**独立丢失**：丢了一包只是那一类这一帧没对齐，下一帧就补上，互不影响。
signal state_snapshot_extra_received(snapshot: Dictionary)

var role: E_Role = E_Role.None
var state: E_State = E_State.Idle
var local_peer_id: int = 0
## 当前接入的这一局（未进关时为 null）
var main_game: MainGameManager = null
## 房里正在打的这一关（空 = 房主还在主菜单）
var room_level_id: String = ""
## 房里的随机种子（主机开一关时换一个；两端种同一个种子才会在同一时刻抽到同一只僵尸）
var room_seed: int = 0

## 每局的战斗同步节点（由它自己登记进来，见 `attach_battle_sync()`）
var _battle_sync: NetplayBattleSync = null
## 房主当前这一关的完整键值（用于给后加入的人补发，见 `request_enter_level()`）
var _room_level_key: Dictionary = {}


#region 连接
## 创建主机（监听端口，等人进来）
func create_host(port: int = DEFAULT_PORT) -> bool:
	if multiplayer.multiplayer_peer != null:
		close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		Log.error("联机模组：监听端口 %d 失败（错误码 %d）—— 端口可能已被占用" % [port, err])
		_set_state(E_State.Failed)
		return false
	multiplayer.multiplayer_peer = peer
	_connect_multiplayer_signals()
	role = E_Role.Host
	local_peer_id = multiplayer.get_unique_id()
	_set_state(E_State.Hosting)
	_emit_log("已创建主机，监听端口 %d（本地 peer id=%d）" % [port, local_peer_id])
	return true


## 加入主机
func join(address: String = DEFAULT_ADDRESS, port: int = DEFAULT_PORT) -> bool:
	if multiplayer.multiplayer_peer != null:
		close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		Log.error("联机模组：连接 %s:%d 失败（错误码 %d）" % [address, port, err])
		_set_state(E_State.Failed)
		return false
	multiplayer.multiplayer_peer = peer
	_connect_multiplayer_signals()
	role = E_Role.Client
	local_peer_id = multiplayer.get_unique_id()
	_set_state(E_State.Connecting)
	_emit_log("正在连接 %s:%d ..." % [address, port])
	return true


## 断开（回到 Idle）
func close() -> void:
	detach_main_game()
	_disconnect_multiplayer_signals()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	role = E_Role.None
	local_peer_id = 0
	_set_state(E_State.Idle)
	room_level_id = ""
	_room_level_key.clear()
	ready_peers.clear()
	_level_left_peers.clear()
	_emit_log("已断开")
#endregion


#region 对外查询
func is_host() -> bool:
	return role == E_Role.Host


func is_client() -> bool:
	return role == E_Role.Client


## 是否处于「能收发命令」的状态
##
## ⚠️ 不能叫 `is_connected()`：`Node.is_connected(signal, callable)` 是引擎方法，
##   同名无参覆盖会因签名不符直接编译报错（GDScript 不接受改签名的覆盖）。
func is_linked() -> bool:
	return state == E_State.Connected or (is_host() and state == E_State.Hosting)
#endregion


#region 命令收发
## 发一条命令：客户端发往主机，主机广播给所有客户端
func send_command(command: Dictionary) -> void:
	if not NetplayCommand.is_valid(command):
		Log.warn("联机模组：丢弃一条不认识的命令 %s" % str(command))
		return
	if not is_linked():
		_emit_log("未连接，命令仅本地记录：%s" % str(NetplayCommand.op_of(command)))
		return
	receive_command.rpc(command)


## 收一条命令（RPC 入口，只转发成信号，不碰本体 —— 重放逻辑属于下一阶段）
@rpc("any_peer", "reliable")
func receive_command(command: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	command_received.emit(sender_id, command)
	_emit_log("收到 [%d] %s %s" % [sender_id, str(NetplayCommand.op_of(command)), str(NetplayCommand.args_of(command))])
#endregion


#region 房间：房主进关，全屋跟进
## 房主带着大家进同一关：[param level_key] 是客房那边重建关卡所需的全部信息
##
## 只有房主能喊这一句（`is_host()` 挡住），客户端喊了也没用 —— 方位不能由客户端决定。
## 现在还没人的时候也照记不误：那样后加入的人会被 `_on_peer_connected()` 直接补进这一关。
func request_enter_level(level_key: Dictionary) -> void:
	if not is_host() or level_key.is_empty():
		return
	_room_level_key = level_key
	room_level_id = str(level_key.get("id", ""))
	## 新的一局：上一局"自己退了关"的那几个人重新算进来（他这次会被一起拉进这一关）
	_level_left_peers.clear()
	## 房间关卡那一行要跟着变（`state_changed` 是面板刷新的钩子）
	state_changed.emit(state)
	## 开一关换一颗随机种子：两端 `GameRng` 同源，"抽奖型"的随机才会抽到同一份结果
	request_battle_seed(new_battle_seed())
	if not is_linked():
		return
	enter_level.rpc(level_key)
	_emit_log("带着大家进 [%s]" % room_level_id)


## 收一句「进哪关」：只认房主那一句，客户端冒名发来的一律丢掉
@rpc("any_peer", "reliable")
func enter_level(level_key: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER_ID:
		Log.warn("联机模组：收到非房主发来的进关指令，已丢弃")
		return
	_room_level_key = level_key
	room_level_id = str(level_key.get("id", ""))
	state_changed.emit(state)
	_emit_log("跟房主进 [%s]" % room_level_id)
	level_enter_requested.emit(level_key)


## 房主退出关卡 ⇒ 客户端也退出（同进同出：一起进、一起退）
##
## 照样只有房主喊得动；记录清掉之前先把 `level_leave_requested` 发出去，
## 让外面（模组）拿着自己记的那份关卡键值决定退回哪个选关页。
func request_leave_level() -> void:
	if not is_host():
		return
	var leaving_id := room_level_id
	_clear_room_level()
	if is_linked():
		leave_level.rpc()
	if not leaving_id.is_empty():
		_emit_log("大家退出 [%s]" % leaving_id)
	level_leave_requested.emit()


@rpc("any_peer", "reliable")
func leave_level() -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER_ID:
		return
	var leaving_id := room_level_id
	_clear_room_level()
	level_leave_requested.emit()
	if not leaving_id.is_empty():
		_emit_log("房主退出，跟着离开 [%s]" % leaving_id)


## 房间关卡的记录清掉（`room_level_id` 一空，控制台那一行就回到占位文本）
func _clear_room_level() -> void:
	_room_level_key.clear()
	room_level_id = ""
	state_changed.emit(state)


## 房主这一关打完了 ⇒ 把结果发下去（客户端按这个结果决定是否写入自己的通关存档）
func request_level_result(save_game_name: String, success: bool) -> void:
	if not is_host() or save_game_name.is_empty():
		return
	if not is_linked():
		return
	level_result.rpc(save_game_name, success)


@rpc("any_peer", "reliable")
func level_result(save_game_name: String, success: bool) -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER_ID:
		return
	level_result_received.emit(save_game_name, success)
#endregion


#region 选卡协商的传输
## 广播本机当前的出战卡（元素是 `ResourceCardReference.to_dict()`）
##
## 谁都可以喊 —— 选卡是**各自主张**的协商，不是房主说了算，所以不必过房主那道闸。
func report_card_selection(selections: Array) -> void:
	if not is_linked():
		return
	card_selection.rpc(selections)


## 请对端把他现在的选卡再报一遍（本机晚进选卡界面时用，不然看不到对面已经挑了什么）
func ask_card_selection_refresh() -> void:
	if not is_linked():
		return
	_card_selection_refresh_asked.rpc()


@rpc("any_peer", "reliable")
func _card_selection_refresh_asked() -> void:
	card_selection_refresh_requested.emit()


@rpc("any_peer", "reliable")
func card_selection(selections: Array) -> void:
	card_selection_received.emit(multiplayer.get_remote_sender_id(), selections)
#endregion


#region 准备 / 开始的传输
## 房里每个人在本次选卡阶段的准备状态：{peer_id = true}
## 房主拿着这一份判定"可不可以开始"；每局开始时会清一次
var ready_peers: Dictionary = {}
## 这一局里**已经自己退了关**的人（客户端退出关卡时上行一句，见 `report_leave_level()`）
##
## ★ 为什么非记不可：只把他的准备状态擦掉是不够的 —— 房主的「开始」按的是
##   "名单里的每个人都准备好了"，一个已经不在局里的人永远也不会再按准备，
##   房主就会**永远等下去**（与双进程实测抓到的那个死局同一类）。
##   记下他之后，判定名单改走 `waiting_peer_ids()`，把他排除掉。
var _level_left_peers: Dictionary = {}
## 有人点了（或取消了）准备
signal ready_state_changed(peer_id: int, ready: bool)
## 房主喊「收工」：**客户端据此把自己的选卡结算下去**（不然房主打起来了客户端还站在选卡界面）
signal choose_card_start_requested()


## 客户端：报上本机的准备状态（本机这一侧立刻生效，不必等房主绕回来）
##
## ⚠️ 不能叫 `request_ready()`：那是引擎 `Node` 的方法（「我要重新跑一遍 ready」），
##    同名不同义会被 GDScript 判为"签名不符的覆盖"，直接编译不过 —— 跟 `is_linked()` 那次是同一类坑。
func declare_ready(ready: bool) -> void:
	if not is_linked():
		return
	_apply_ready(local_peer_id, ready)
	report_ready.rpc(ready)


## 收一句准备好了：房主记账 ⇒ 转告全屋（同屋的伙伴也要看得见别人的准备情况）
@rpc("any_peer", "reliable")
func report_ready(ready: bool) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == SERVER_PEER_ID:
		return
	_apply_ready(sender_id, ready)
	sync_ready.rpc(sender_id, ready)


@rpc("any_peer", "reliable")
func sync_ready(peer_id: int, ready: bool) -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER_ID:
		return
	_apply_ready(peer_id, ready)


## 房主：收工，带着大家一起开始（客户端那边会收到 `choose_card_start_requested`）
func request_choose_card_start() -> void:
	if not is_host() or not is_linked():
		return
	choose_card_start.rpc()


@rpc("any_peer", "reliable")
func choose_card_start() -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER_ID:
		return
	choose_card_start_requested.emit()


## 新一轮选卡之前把上一轮的准备状态清干净（同一局多轮关卡会重进选卡）
func clear_ready() -> void:
	ready_peers.clear()


## 客户端：**我自己退出了这一关**（不是被房主拉去下一关）时喊一句
##
## 为什么非喊不可：房主那边还记着"这个人在局里"，于是「开始」按钮永远等他点准备 ——
## 而他已经不在局里，永远点不到 ⇒ 房主被永久卡住（见 `_level_left_peers` 那段注释）。
## 判据由 `NetplayMod` 那边给：被房主拉去换关时旧的本局节点**同样**会退场，那种不算。
func declare_level_left() -> void:
	if not is_client() or not is_linked():
		return
	report_leave_level.rpc()


## 收一句「我退了」：房主记账（客户端之间不会互发，`rpc()` 在星型拓扑里只到主机）
@rpc("any_peer", "reliable")
func report_leave_level() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == SERVER_PEER_ID or not is_host():
		return
	_apply_level_left(sender_id)


func _apply_level_left(peer_id: int) -> void:
	_level_left_peers[peer_id] = true
	## 他的准备状态一并擦掉：面板上不该还挂着"已准备"的那一行
	ready_peers.erase(peer_id)
	ready_state_changed.emit(peer_id, false)
	peer_level_left.emit(peer_id)
	_emit_log("玩家 %d 已退出这一关（不再等他准备）" % peer_id)


func _apply_ready(peer_id: int, ready: bool) -> void:
	if bool(ready_peers.get(peer_id, false)) == ready:
		return
	ready_peers[peer_id] = ready
	ready_state_changed.emit(peer_id, ready)


## 屋里除了自己以外的 peer id（一个人都没有就是空表）
func other_peer_ids() -> Array:
	var out: Array = []
	if not is_linked():
		return out
	for peer_id in multiplayer.get_peers():
		out.append(peer_id)
	return out


## 判定"可以开始了吗"用的名单：`other_peer_ids()` 里**已经退出这一局**的不算
##
## ★ 为什么不能直接用 `other_peer_ids()`：退出关卡的人连接还在（他只是不打这一关了），
##   仍在那份名单里；可他永远也不会再点准备 ⇒ 房主的「开始」永远按不动。
##   判定名单把 `_level_left_peers` 里那几个剔掉，房主才不会被一个不在局里的人卡住。
func waiting_peer_ids() -> Array:
	var out: Array = []
	for peer_id in other_peer_ids():
		if not _level_left_peers.has(peer_id):
			out.append(peer_id)
	return out
#endregion


#region 战斗同步：操作下行 + 随机种子
## 主机 ⇒ 客户端：一条**已经在主机上生效**的操作，客户端照着在自己这里重放一遍
##
## 只有主机喊得动（`request_...` 里那道 `is_host()`）。这一条是"主机权威"的关键：
## 客户端上行的是**请求**，下来的才是**事实** —— 客户端自己按下的那一次不在本地生效。
func request_battle_op(command: Dictionary) -> void:
	if not is_host() or not is_linked():
		return
	if not NetplayCommand.is_valid(command):
		return
	battle_op.rpc(command)


@rpc("any_peer", "reliable")
func battle_op(command: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER_ID:
		return
	var op := NetplayCommand.op_of(command)
	if op == &"":
		return
	battle_op_received.emit(op, NetplayCommand.args_of(command))


## 主机：开一关就换一个随机种子，两端 `GameRng` 种同一颗 —— 主机与客户端各跑各的定时器，
## 但"这一波出什么怪 / 落在哪一行"这类抽奖型的随机能对齐（真正的波次下发属下一阶段）
func request_battle_seed(seed_value: int) -> void:
	if not is_host() or seed_value == 0:
		return
	_apply_battle_seed(seed_value)
	if is_linked():
		sync_battle_seed.rpc(seed_value)


@rpc("any_peer", "reliable")
func sync_battle_seed(seed_value: int) -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER_ID:
		return
	_apply_battle_seed(seed_value)
	_emit_log("同步随机种子 %d" % seed_value)


## 主机 ⇒ 客户端：这一帧的**战斗快照**（场上僵尸 / 植物 / 阳光的位置与血量）
##
## ⚠️ 用 **unreliable**：快照是"最新真相"，丢一帧下一帧立刻补上，
## 为它重传只会把旧数据迟到送到 —— 与操作命令（`battle_op`，reliable）正好相反。
## 包体是 `Packed*Array`，超过 ENet 不可靠包的 MTU 会被整包丢弃，见 `NetplayStateSync` 文件头。
func send_state_snapshot(snapshot: Dictionary) -> void:
	if not is_host() or not is_linked():
		return
	state_snapshot.rpc(snapshot)


@rpc("any_peer", "unreliable")
func state_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER_ID:
		return
	state_snapshot_received.emit(snapshot)


## 同帧的第二包（植物 + 阳光）—— 为什么要拆两包见上面那个信号的注释
func send_state_snapshot_extra(snapshot: Dictionary) -> void:
	if not is_host() or not is_linked():
		return
	state_snapshot_extra.rpc(snapshot)


@rpc("any_peer", "unreliable")
func state_snapshot_extra(snapshot: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER_ID:
		return
	state_snapshot_extra_received.emit(snapshot)


## 抽一颗新种子：要的是"这一局的值"，不必密码学级；毫秒时刻够用也够分散
static func new_battle_seed() -> int:
	return int(Time.get_ticks_msec()) & 0x7FFFFFFF


## 两端同一种一颗：本机立刻生效 + 记下房间种子（后加入的人要靠它补发）
func _apply_battle_seed(seed_value: int) -> void:
	room_seed = seed_value
	GameRng.set_seed(seed_value)
	battle_seed_received.emit(seed_value)


## 每局的战斗同步节点：登记进来
##
## 谁会来问它：玩家操作的统一网关（`NetplayActionGateway`）把操作翻译完，
## 就是交给这一位去发（客户端上行请求 / 主机跑成后下行），见 `get_battle_sync()`。
func attach_battle_sync(node: NetplayBattleSync) -> void:
	_battle_sync = node


## 当前这一局的战斗同步（还没登记就是 null）
func get_battle_sync() -> NetplayBattleSync:
	return _battle_sync


## 摘掉登记（由每一局的节点在 `_exit_tree()` 里喊，见 `NetplayBattleSync`）
##
## 带上 node 是为了**换关时不看错人**：旧那一局退场时新的一局已经装好了，
## 只在这一位就是自己时才清，别把新房客的记录抹掉。
func detach_battle_sync(node: NetplayBattleSync = null) -> void:
	if node == null or _battle_sync == node:
		_battle_sync = null
#endregion


#region 本局钩子
## 把这一局接进联机（由 `NetplayMod.install_to_main_game()` 调用，每局一次）
##
## ★ 玩家操作的采集**不在这里**：本体那一个统一上报口（`GlobalUtils.player_action_gate`）
##   由 `NetplayActionGateway` 占住，本局里的每一个操作都从它那一处上行。
##   （早年这里装的是 `EventBus` 拦截器 —— 它只能采到"有事件的"那两种操作，
##   点格子 / 捡阳光 / 捡掉落物各要另开一个闸门；现在一律走统一口，拦截器交还给本体。）
func attach_main_game(mg: MainGameManager) -> void:
	if mg == null:
		return
	detach_main_game()
	main_game = mg
	_emit_log("已接入本局，玩家操作开始上行")


## 摘掉本局（断线 / 换局时）
func detach_main_game() -> void:
	main_game = null
#endregion


#region 内部
func _set_state(new_state: E_State) -> void:
	state = new_state
	state_changed.emit(state)


func _emit_log(text: String) -> void:
	Log.info("联机模组: %s" % text)
	session_log.emit(text)


func _connect_multiplayer_signals() -> void:
	var mp := multiplayer
	if not mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.connect(_on_peer_connected)
	if not mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.connect(_on_peer_disconnected)
	if not mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.connect(_on_connected_to_server)
	if not mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.connect(_on_connection_failed)
	if not mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.connect(_on_server_disconnected)


func _disconnect_multiplayer_signals() -> void:
	var mp := multiplayer
	if mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.disconnect(_on_peer_connected)
	if mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.disconnect(_on_peer_disconnected)
	if mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.disconnect(_on_connected_to_server)
	if mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.disconnect(_on_connection_failed)
	if mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.disconnect(_on_server_disconnected)


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)
	_set_state(E_State.Connected)
	_emit_log("玩家 %d 已加入" % peer_id)
	## 后加入的人：房主已经在关里了就一把把他拉进来（不然他只能自己在菜单里猜是哪一关）
	## ⚠️ **关卡中途加入整体是未定义行为**（见 [联机模组规范](../../docs/参考存档/联机模组规范.md) §1.5）：
	## 这里补的只是"房主**连线状态下**进的那一关" —— 房主先进关、后开房时 `_room_level_key` 是空的，
	## 新来的人什么都收不到（那不是 bug 要修，是 v1 明确不给承诺的那条路）。
	if is_host() and not _room_level_key.is_empty():
		enter_level.rpc_id(peer_id, _room_level_key)
		_emit_log("已把新玩家拉进 [%s]" % room_level_id)
		## 后加入的人也要拿到同一颗种子（他这一局的抽奖得跟屋里的人对齐）
		if room_seed != 0:
			sync_battle_seed.rpc_id(peer_id, room_seed)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)
	ready_peers.erase(peer_id)
	_emit_log("玩家 %d 已离开" % peer_id)


func _on_connected_to_server() -> void:
	_set_state(E_State.Connected)
	_emit_log("已连上主机（本地 peer id=%d）" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	_set_state(E_State.Failed)
	_emit_log("连接失败：主机没开或地址不对")


func _on_server_disconnected() -> void:
	_set_state(E_State.Idle)
	_emit_log("主机已断开")
	## 房主把房间关了（不只是退关）：客户端还站在关卡里的话得退回去
	room_closed.emit()
#endregion
