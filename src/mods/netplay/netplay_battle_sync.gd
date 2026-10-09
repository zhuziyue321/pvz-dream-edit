extends Node
class_name NetplayBattleSync
## 联机的战斗同步：**主机权威** —— 大家不做两份局面，只做主机那一份
##
## 规则只有一句：**客户端按下的一次操作不在本地生效**，上行给主机；主机在自己这里
## 跑一遍，跑成的那一遍再下行给全屋，客户端（包括发起的那一个）照着做同样的动作。
## 所以两端看到的是**同一串**操作序列，而不是各自跑各自的。
##
##   client 按键 ──上行请求──▶ host 执行 ──下行事实──▶ 屋里的每一个人（含发起者）重放
##   host  按键 ────────────▶ host 执行 ──下行事实──▶ 客户端重放
##
## 为什么不"各跑各的、事后对齐"（阶段四的做法）：那样要先给每个实体配上稳定的网络 id、
## 还得做插值与纠偏；这一阶段先把"事实只有一份"这条立起来 —— **主机那一局就是这一局**。
##
## 为什么单开一个文件：`NetplayCardSync` 管挑卡、`NetplayReadyFlow` 管收工，这里管的是
## **开打之后每一次落子** —— 三件事都挂在每一局上，但干的活互不相干。

const SELF_NODE_NAME := "NetplayBattleSync"

var _session: NetplaySession = null
var _main_game: MainGameManager = null
var _notice: Callable = Callable()
## 重放中：`EventBus` 拦截器据此判断"这一条是自己推的，不要又上行一圈"
var _executing := false


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session: NetplaySession, main_game: MainGameManager, notice: Callable = Callable()) -> void:
	_session = session
	_main_game = main_game
	_notice = notice
	if _session == null:
		return
	_session.attach_battle_sync(self)
	## 主机的回馈 / 客户端的请求，两条路在同一个节点里汇合
	if not _session.battle_op_received.is_connected(_on_battle_op_received):
		_session.battle_op_received.connect(_on_battle_op_received)
	if not _session.command_received.is_connected(_on_remote_command):
		_session.command_received.connect(_on_remote_command)
	if not _session.battle_seed_received.is_connected(_on_battle_seed_received):
		_session.battle_seed_received.connect(_on_battle_seed_received)


func _exit_tree() -> void:
	if _session != null and is_instance_valid(_session):
		_session.detach_battle_sync(self)


func is_executing() -> bool:
	return _executing


#region 本机的一次操作：要不要接管
## 本机刚发生的一次玩家操作（本体事件采出来的命令）
##
## [return] true = 接管了，本体那一条不再本地派发（false = 照旧本地跑）
##
## · 主机：自己跑一遍，**跑成了才下行**给客户端（跑不动就是这一下没发生）
## · 客户端：只上行请求，本地一笔不动 —— 等主机把"事实"送回来（`_on_battle_op_received()`）
func handle_local_command(command: Dictionary) -> bool:
	if _session == null or not _session.is_linked():
		return false
	if _executing or not NetplayCommand.is_valid(command):
		return false
	var op := NetplayCommand.op_of(command)
	var args := NetplayCommand.args_of(command)
	if _session.is_host():
		## 主机这一侧：先在**自己这一局**上跑一遍，跑成了才把"事实"发下去
		if execute(op, args):
			_session.request_battle_op(command)
		return true
	_session.send_command(command)
	return true
#endregion


## 点了某一格草地（挂在 `HandManager.cell_click_gate` 上的那个口）
func handle_cell_click(plant_cell: PlantCell) -> bool:
	if plant_cell == null or not is_instance_valid(plant_cell):
		return false
	var row_col := plant_cell.row_col
	return handle_local_command(NetplayCommand.build(NetplayCommand.OP_CLICK_CELL, {
		NetplayCommand.ARG_ROW: row_col.x,
		NetplayCommand.ARG_COL: row_col.y,
	}))


#region 重放：唯一的"纯数据 → 本体动作"表
## 跑一遍这条操作（主机自己 / 收到下行的客户端都走这里）
##
## 为什么重放尽量**推本体的同一条事件**（而不是替它调 API）：推同一个事件就还是本体的
## 同一条链路 —— 音效、生命周期、边界校验全都不用模组再抄一遍。
func execute(op: StringName, args: Dictionary) -> bool:
	if _executing:
		return false
	_executing = true
	var ok := _execute_inner(op, args)
	_executing = false
	return ok


func _execute_inner(op: StringName, args: Dictionary) -> bool:
	match op:
		NetplayCommand.OP_CLICK_CARD:
			return _replay_click_card(args)
		NetplayCommand.OP_CLICK_SHOVEL:
			return _replay_click_shovel()
		NetplayCommand.OP_CLICK_CELL:
			return _replay_click_cell(args)
		NetplayCommand.OP_PICK_SUN:
			return _replay_pick_sun(args)
		NetplayCommand.OP_PICK_DROP:
			return _replay_pick_drop(args)
	return false


## 点一张卡：卡槽下标是"第几张出战卡"，重放时还要对一下植物类型（下标错位就宁可不动）
func _replay_click_card(args: Dictionary) -> bool:
	var card := _card_of(args)
	if card == null:
		return false
	EventBus.push_event(ConstEventName.MAIN_GAME_CLICK_CARD, [card])
	return true


func _replay_click_shovel() -> bool:
	EventBus.push_event(ConstEventName.MAIN_GAME_CLICK_SHOVEL)
	return true


## 点某一格：种植物 / 铲植物是同一个入口（手里拿着什么就做什么），所以只按 row_col 走
func _replay_click_cell(args: Dictionary) -> bool:
	var mg := _resolve_main_game()
	if mg == null or mg.hand_manager == null or mg.plant_cell_manager == null:
		return false
	var cell := _plant_cell_of(args)
	if cell == null:
		return false
	## 走的就是鼠标点格子那一条入口，所以地形 / 冷却 / 阳光够不够都还是本体说了算
	mg.hand_manager._on_click_cell(cell)
	return true


## 捡一颗阳光：按**实体编号**找到自己这一局上的同一颗，再走本体的拾取入口
## （`Sun.collect()` 内部照旧推 `ADD_SUN_VALUE`，音效 / 飞向收集点 / 卡槽加数值全都不用模组再抄一遍）
func _replay_pick_sun(args: Dictionary) -> bool:
	var sun := _sun_of(args)
	if sun == null:
		return false
	sun.collect()
	return true


## 捡一枚金币 / 巧克力（与捡阳光同一条链路：按**编号**找到自己这一局上的同一枚）
## 查找与拾取都收在 `NetplayDropSync` 上（金币与巧克力不在同一个父节点下，那边已经收过口了）
func _replay_pick_drop(args: Dictionary) -> bool:
	return NetplayDropSync.collect_drop_by_id(Global.main_game,
		int(args.get(NetplayCommand.ARG_SUN_ID, 0)))


func _on_battle_op_received(op: StringName, args: Dictionary) -> void:
	if _session == null:
		return
	## 主机自己早就跑过了 —— 再跑一遍等于重复落子
	if _session.is_host():
		return
	execute(op, args)


## 主机收到客户端的请求：在**自己这一局**上跑一遍，跑成了才把"事实"发下去
func _on_remote_command(_from_peer_id: int, command: Dictionary) -> void:
	if _session == null or not _session.is_host():
		return
	if not NetplayCommand.is_valid(command):
		return
	var op := NetplayCommand.op_of(command)
	var args := NetplayCommand.args_of(command)
	if execute(op, args):
		_session.request_battle_op(command)
	else:
		_notify("伙伴的那一步没落成（%s）—— 主机这一局上跑不动" % str(op))


func _on_battle_seed_received(seed_value: int) -> void:
	_notify("同一颗随机种子已成（%d）" % seed_value)
#endregion


#region 小工具
## 出战卡槽里的那张卡（下标 + 植物类型双重对照，任一不符就当没有）
func _card_of(args: Dictionary) -> Card:
	var index := int(args.get(NetplayCommand.ARG_CARD_INDEX, -1))
	var plant_type := int(args.get(NetplayCommand.ARG_PLANT_TYPE, -1))
	var cards := NetplayCommand.battle_cards()
	if cards.is_empty() or index < 0 or index >= cards.size():
		return null
	var card: Card = cards[index]
	if plant_type >= 0 and card.card_plant_type != plant_type:
		return null
	return card


func _plant_cell_of(args: Dictionary) -> PlantCell:
	var mg := _resolve_main_game()
	if mg == null or mg.plant_cell_manager == null:
		return null
	var row := int(args.get(NetplayCommand.ARG_ROW, -1))
	var col := int(args.get(NetplayCommand.ARG_COL, -1))
	if row < 0 or col < 0:
		return null
	var rows: Array = mg.plant_cell_manager.all_plant_cells
	if row >= rows.size():
		return null
	var cells: Array = rows[row]
	if col >= cells.size():
		return null
	var cell: PlantCell = cells[col]
	return cell if is_instance_valid(cell) else null


## 场上还在的那一颗阳光（按实体编号对；两端同一颗的编号是主机发下来的那一个）
func _sun_of(args: Dictionary) -> Sun:
	var sun_id := int(args.get(NetplayCommand.ARG_SUN_ID, 0))
	if sun_id == 0:
		return null
	var mg := _resolve_main_game()
	if mg == null or mg.suns == null or not is_instance_valid(mg.suns):
		return null
	for child in mg.suns.get_children():
		var sun := child as Sun
		if sun == null or not is_instance_valid(sun):
			continue
		if sun.entity_id == sun_id:
			return sun
	return null


## 本节点记录的这一局还活着就用它，否则退回去问 `Global.main_game`
## （换关时旧节点会先灭再换新，用"活着的那一份"才不会对着空气操作）
func _resolve_main_game() -> MainGameManager:
	if _main_game != null and is_instance_valid(_main_game):
		return _main_game
	## `:=` 推断不出来（`Global.main_game` 出来是 Variant），这里必须写明类型
	var mg: MainGameManager = Global.main_game
	return mg if is_instance_valid(mg) else null


func _notify(text: String) -> void:
	if _notice.is_valid():
		_notice.call(text)
#endregion
