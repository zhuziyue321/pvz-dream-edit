extends Node
## 联机的**出卡同步**：传送带上出哪一张由主机下发，客户端不自己抽
##
## 为什么必须下发：传送带是从随机池里抽的 —— `CardRandomPool.get_random_reference()` 走的是
## **全局 `randi_range`**（不是 `GameRng`），两端各跑各的，抽出来的**不是同一张卡**。
## 客户端手里那一张主机没有 ⇒ 点下去主机重放时认不出它（`execute()` 找不到这张卡），
## 这一下操作就**凭空消失**了。
##
## 做法 —— 与阳光同款（"生成"是战斗逻辑，一律归主机）：
##   host   传送带出了一张 ──▶ `card_created` ──▶ battle_op(card_spawn: 卡的身份) 下行
##   client 收到          ──▶ `spawn_card_by_reference()` 照着重建同一张
##   client 自己          ──▶ `create_card_gate` 恒 false，本地一张都不出
##
## ★ 只接管**传送带**：种子雨（天降卡）是迷你游戏 04 的**一关专属玩法**，节点由关卡脚本自己挂
##   （`minigame_04_seed_rain.gd`），联机不碰 —— 一次性玩法归关卡脚本，见硬约束 §1-8。
##   本体那一侧的通用槽位照样留着（闸门 / 指定身份出卡 / `card_created`），谁想用谁用。
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜ [联机模组规范](../../docs/参考存档/联机模组规范.md)

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录 / 上级的文件一律 preload 成常量再引用，不能写 `extends Xxx` / `var x: Xxx`
const NetplayCommand := preload("netplay_command.gd")

const SELF_NODE_NAME := "NetplayCardSpawnSync"

## 传送带卡槽由关卡脚本**现场 instantiate**，挂上来的时刻不保证在帧末之前 ⇒
## `_install()` 那一次没接到就轮询等它出现（见 `_retry_install_async()`）。
## 等不到 = 本关没有传送带，什么都不用做。
const INSTALL_RETRY_TIMES := 20
const INSTALL_RETRY_INTERVAL := 0.25

var _session = null
var _main_game: MainGameManager = null
var _notice: Callable = Callable()
var _retrying := false


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session, main_game: MainGameManager, notice: Callable = Callable()) -> void:
	_session = session
	_main_game = main_game
	_notice = notice
	if _session == null or not _session.is_linked():
		return
	## ⚠️ 与其它 sync 同一条纪律：模组装在 `card_manager` 初始化**之前**，那一刻传送带
	## 卡槽还没被关卡挂上来（它是 `ConveyorBeltController` 现场 instantiate 的），
	## 推到帧末再接线，那时卡槽已经在了。
	call_deferred("_install")


## 真正接线（帧末执行一次）
func _install() -> void:
	if _session == null or not _session.is_linked():
		return
	var belt := _conveyor()
	if belt == null:
		## ⚠️ 帧末这一刻还没有传送带 ⇒ 不能就此放弃：晚挂上来的话，客户端就永远
		## 接不到闸门、定时器也停不掉 —— 那局面是"客户端照自己随机池出卡"，
		## 出的是主机没有的卡，点下去主机认不出，这一下操作凭空消失（整关玩不了）。
		_retry_install_async()
		return
	_bind(belt)


## 真正接线（只有拿到传送带卡槽之后才会走到这里）
func _bind(belt: CardSlotConveyorBelt) -> void:
	if _session.is_host():
		if not belt.card_created.is_connected(_on_card_created):
			belt.card_created.connect(_on_card_created)
	else:
		## 客户端：本地随机池不再出卡，只认主机下发的那一张
		belt.create_card_gate = _client_card_gate
		## 出卡定时器一并停掉（闸门是双保险，守的是"定时器回调漏过来"那条路）
		if belt.create_new_card_timer != null:
			belt.create_new_card_timer.stop()
	if not _session.battle_op_received.is_connected(_on_battle_op_received):
		_session.battle_op_received.connect(_on_battle_op_received)


## 轮询等传送带卡槽出现，出现了立刻接线；等不到就放弃（本关没有传送带）
func _retry_install_async() -> void:
	if _retrying:
		return
	_retrying = true
	for _i in INSTALL_RETRY_TIMES:
		await get_tree().create_timer(INSTALL_RETRY_INTERVAL).timeout
		## 换关 / 退出房间时自己已经不在树上：`get_tree()` 随后就用不了了
		if not is_instance_valid(self) or _session == null or not _session.is_linked():
			break
		var belt := _conveyor()
		if belt != null:
			_bind(belt)
			break
	_retrying = false


func _exit_tree() -> void:
	## 换关时旧节点会先灭：闸门要还回去，别把下一局也锁住
	var belt := _conveyor()
	if belt == null:
		return
	if belt.create_card_gate == _client_card_gate:
		belt.create_card_gate = Callable()
	if belt.card_created.is_connected(_on_card_created):
		belt.card_created.disconnect(_on_card_created)


## 闸门：客户端**永远不自己出卡**（返回 false = 这一次不许本地出卡）
##
## 为什么可以无条件关闭：出哪一张归主机，客户端照着重建就是了 —— 本地随机池没有任何
## 一次出卡的必要。照旧留着闸门是因为"定时器回调"和"命令"是两条路，都要堵上。
func _client_card_gate() -> bool:
	return false


## 主机出了一张 ⇒ 把"是哪一张"发下去
func _on_card_created(reference: ResourceCardReference, _index: int) -> void:
	if _session == null or not _session.is_host() or reference == null:
		return
	_session.request_battle_op(NetplayCommand.build(NetplayCommand.OP_CARD_SPAWN, {
		NetplayCommand.ARG_CARD_REF: reference.to_dict(),
	}))


## 客户端收到 ⇒ 照着重建同一张（不经闸门、也不走随机池）
func _on_battle_op_received(op: StringName, args: Dictionary) -> void:
	if _session == null or _session.is_host():
		return
	if op != NetplayCommand.OP_CARD_SPAWN:
		return
	var belt := _conveyor()
	if belt == null:
		return
	var data: Variant = args.get(NetplayCommand.ARG_CARD_REF, {})
	if not data is Dictionary:
		return
	var reference := ResourceCardReference.from_dict(data)
	if reference == null:
		return
	belt.spawn_card_by_reference(reference)


## 本局的传送带卡槽（关卡没配传送带时为 null，这时什么都不用做）
func _conveyor() -> CardSlotConveyorBelt:
	if _main_game == null or not is_instance_valid(_main_game):
		return null
	if _main_game.card_manager == null:
		return null
	return _main_game.card_manager.card_slot_conveyor_belt
