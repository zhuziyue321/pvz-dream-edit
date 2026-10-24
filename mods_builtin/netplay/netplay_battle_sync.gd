extends Node
## 联机的战斗同步：**主机权威** —— 大家不做两份局面，只做主机那一份
##
## 规则只有一句：**会改变场面的那一次操作不在本地生效**，上行给主机；主机在自己这里
## 跑一遍，跑成的那一遍再下行给全屋，客户端（包括发起的那一个）照着做同样的动作。
## 所以两端看到的是**同一串**操作序列，而不是各自跑各自的。
##
## ★ 唯一留在本地的那一步是**拿起植物**（点卡）：卡是自己卡槽里那一张，主机那一局上没有它，
##   而"拿起来"本身不改变场上任何东西 —— 交给主机只会白等半个 RTT。
##   种不种得下去（点格子）才归主机判：那一步带上**卡在卡槽里的下标**上行，
##   主机照着**自己卡槽里那一张**来种（**所有卡与冷却都在房主这里**），
##   并先验"这一格是不是这个人的块"（联机的卡槽按人数切块，见 `NetplayCardSync`）。
##
##   client 按键 ──上行请求──▶ host 执行 ──下行事实──▶ 屋里的每一个人（含发起者）重放
##   host  按键 ────────────▶ host 执行 ──下行事实──▶ 客户端重放
##
## 为什么不"各跑各的、事后对齐"（阶段四的做法）：那样要先给每个实体配上稳定的网络 id、
## 还得做插值与纠偏；这一阶段先把"事实只有一份"这条立起来 —— **主机那一局就是这一局**。
##
## 为什么单开一个文件：`NetplayCardSync` 管挑卡、`NetplayReadyFlow` 管收工，这里管的是
## **开打之后每一次落子** —— 三件事都挂在每一局上，但干的活互不相干。

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录 / 上级的文件一律 preload 成常量再引用，不能写 `extends Xxx` / `var x: Xxx`
const NetplayCommand := preload("netplay_command.gd")
const NetplayDropSync := preload("netplay_drop_sync.gd")
const NetplayCardSync := preload("netplay_card_sync.gd")

const SELF_NODE_NAME := "NetplayBattleSync"

var _session = null
var _main_game: MainGameManager = null
var _notice: Callable = Callable()
## 重放中：防止 `execute()` 里推的那条本体事件再被当成一次新的玩家操作
var _executing := false


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session, main_game: MainGameManager, notice: Callable = Callable()) -> void:
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
## 本机刚发生的一次玩家操作（由 `NetplayActionGateway` 翻译成的命令）
##
## ★ 这是模组**唯一**把操作发出去的那一句：网关把本体的"操作 + 对象"翻译成纯数据命令，
##   剩下的"客户端上行 / 主机跑成后下行"全在这里定夺，不再有第二条发送路径。
##
## [return] true = 接管了，本体那一条不再本地派发（false = 照旧本地跑）
##
## · 主机：自己跑一遍，**跑成了才下行**给客户端（跑不动就是这一下没发生）
## · 客户端：只上行请求，本地一笔不动 —— 等主机把"事实"送回来（`_on_battle_op_received()`）
##
## [param from_peer_id] 这一笔是**谁**发起的：主机自己按的 = 本机 peer id；
##   客户端请求上行到主机时 = 那个客户端的 peer id（**房主靠它验"这一格是谁的块"**）；
##   客户端重放主机下发的事实时 = -1（事实已经验过了，不必再验）。
func handle_local_command(command: Dictionary) -> bool:
	if _session == null or not _session.is_linked():
		return false
	if _executing or not NetplayCommand.is_valid(command):
		return false
	var op := NetplayCommand.op_of(command)
	var args := NetplayCommand.args_of(command)
	if _session.is_host():
		## 主机这一侧：先在**自己这一局**上跑一遍，跑成了才把"事实"发下去
		if execute(op, args, _session.local_peer_id):
			_session.request_battle_op(command)
		return true
	_session.send_command(command)
	return true
#endregion


#region 重放：唯一的"纯数据 → 本体动作"表
## 跑一遍这条操作（主机自己 / 收到下行的客户端都走这里）
##
## 为什么重放尽量**推本体的同一条事件**（而不是替它调 API）：推同一个事件就还是本体的
## 同一条链路 —— 音效、生命周期、边界校验全都不用模组再抄一遍。
## [param from_peer_id] 这一笔是谁发起的（-1 = 事实已经验过，不必再验；见 `handle_local_command()`）
func execute(op: StringName, args: Dictionary, from_peer_id: int = -1) -> bool:
	if _executing:
		return false
	_executing = true
	var ok := _execute_inner(op, args, from_peer_id)
	_executing = false
	return ok


func _execute_inner(op: StringName, args: Dictionary, from_peer_id: int) -> bool:
	match op:
		NetplayCommand.OP_CLICK_SHOVEL:
			return _replay_click_shovel()
		NetplayCommand.OP_CLICK_CELL:
			return _replay_click_cell(args, from_peer_id)
		NetplayCommand.OP_SWAP_CELL:
			return _replay_swap_cell(args)
		NetplayCommand.OP_PICK_SUN:
			return _replay_pick_sun(args)
		NetplayCommand.OP_SUN_CLAIM:
			return _replay_sun_claim(args)
		NetplayCommand.OP_PICK_DROP:
			return _replay_pick_drop(args)
	return false


func _replay_click_shovel() -> bool:
	EventBus.push_event(ConstEventName.MAIN_GAME_CLICK_SHOVEL)
	return true


## 点某一格：种植物 / 铲植物是同一个入口（手里拿着什么就做什么）
##
## ★ **种植的校验在这一侧（主机）做**，分四步：
##   1. ★ **认人**：客户端报的是“卡在**出战卡槽**里的第几格”（`ARG_SLOT_INDEX`）——
##      主机先验“这一格是不是**这个人的块**”（联机的卡槽按人数切块，见 `NetplayCardSync`），
##      不是 ⇒ 这一笔不认（别人的卡不许种）；
##   2. ★ **取卡**：照主机**自己卡槽里那一张**来种 ⇒ 扣的是房主的阳光、开始的是房主的冷却
##      （**所有卡与冷却都在房主这里**）；手上那张卡不在卡槽里时（传送带 / 临时卡）
##      才走“照身份拿一张”的旧路；
##   3. 主机并没有把鼠标放到那一格上 —— 虚影 / 能不能种（`is_shadow_in_cell`）原本是
##      hover 算出来的，不补一次 hover，主机判的就是"自己鼠标底下那一格"（种错地方）；
##   4. 走本体的那一枚入口 `HandManager._on_click_cell()` —— 地形 / 占用 / 紫卡前置 /
##      坚果包扎术 / 音效 / 扣阳光全都不用模组再抄一遍。
## [param from_peer_id] 这一笔是谁发起的（-1 = 主机下发的事实，已经验过，不必再验）
func _replay_click_cell(args: Dictionary, from_peer_id: int) -> bool:
	var mg := _resolve_main_game()
	if mg == null or mg.hand_manager == null or mg.plant_cell_manager == null:
		return false
	var cell := _plant_cell_of(args)
	if cell == null:
		return false
	## ★ 先定下"这一下要用哪一张卡"
	var card: Card = null
	var is_temp := false
	var index := int(args.get(NetplayCommand.ARG_SLOT_INDEX, -1))
	if index >= 0:
		## 卡槽下标那条路（联机分块）：卡与冷却都在房主这里
		if from_peer_id >= 0 and not _owns_slot_index(from_peer_id, index):
			Log.warn("联机模组：卡槽第 %d 格不在玩家 %d 的块里 —— 这一笔不认" % [index, from_peer_id])
			return false
		card = _slot_card_at(mg, index)
		if card == null:
			Log.warn("联机模组：卡槽第 %d 格上没有卡 —— 这一笔不认" % index)
			return false
		if not _card_usable(card):
			Log.info("联机模组：卡槽第 %d 格现在用不了（阳光不够 / 冷却中）—— 这一笔不认" % index)
			return false
	else:
		## 旧路：那张卡不在卡槽里（传送带上的卡 / 临时卡）—— 照身份拿一张同样的
		## ⚠️ **手上根本不是卡**（铲子那一类，命令里没有卡的身份）时不用取卡 ——
		##   照旧让本体那枚入口自己处理（`click_cell()` 走的是当前手持组件）。
		if args.has(NetplayCommand.ARG_CARD_REF):
			var taken := _take_card_for_replay(mg, args)
			if taken.is_empty():
				return false
			card = taken["card"]
			is_temp = bool(taken.get("temp", false))
	## 手上不是这一张 ⇒ 拿起它（走本体同一个入口 `MAIN_GAME_CLICK_CARD`）
	if card != null and not _is_holding(mg, card):
		EventBus.push_event(ConstEventName.MAIN_GAME_CLICK_CARD, [card])
		if not _is_holding(mg, card):
			return false
	## ★ 补一次 hover：主机没有把鼠标放到这一格上，不补的话判的是"自己鼠标底下那一格"
	## ★ 顺手记下这一格现在有哪些株：种成之后凭差集认出"刚种下的那一株"
	var before := _plant_ids_in_cell(cell)
	mg.hand_manager._on_cell_mouse_enter(cell)
	mg.hand_manager._on_click_cell(cell)
	_claim_fresh_plant(cell, before, args)
	## 手上已经没有这一张 = 种成了（`click_cell()` 返回 true 才会 `drop_hand()`）
	## ⚠️ 手上根本不是卡（铲子那一类）时没有"这一张"可比 ⇒ 照旧判成功
	var ok := (not _is_holding(mg, card)) if card != null else true
	## ★★ **"快照先到"会让这一笔重复抵达，必须判成功**：
	## 主机的快照（unreliable、每帧发）常常比这条 battle_op（reliable）**先到**，
	## 客户端那一头已经照快照把这一株**补种出来**了。于是重放种植时 `create_plant()`
	## 撞上"当前位置已经有植物"直接 return ⇒ `click_cell()` 返回 false ⇒
	## **`drop_hand()` 不发生 ⇒ 手里的植物一直举着**：
	##   · 玩家看不到"种下去了"的反馈，就会再点 ⇒ 每一次点击都重演这条失败链；
	##   · 日志被同一句刷屏（手上多一张卡就多一个格子交替出现，掩掉真正要找的日志）。
	## 而在联机语义里这条 op 是**主机已经生效的事实**，它重复抵达应当判**成功** ——
	## 所以这里补一次"放手"，让客户端这一笔正常收尾。
	## ⚠️ 判据必须是"这一格**真的有植物了**"：地形不符 / 阳光不够那些真失败时格子还是空的，
	##    那种情况不能放手（`curr_hand_component.click_cell()` 的 false 语义要保持）。
	if not ok and cell.get_curr_plant_num() > 0:
		## ⚠️ **无条件放手**：拿"手上还有没有这张卡"当条件会判不准 ——
		## 客户端手上那一张与命令里带的那一份只要有一个字段对不上就判 false；
		## 拿它当"要不要放手"的开关，判不准时这一笔就一直卡在手上（表现就是反复种同一格）。
		## `drop_hand()` 本身幂等（就是切回本关的空闲手持物），空手时调也没有副作用。
		mg.hand_manager.drop_hand()
		ok = true
	if is_temp:
		## 临时那一张只是"替客户端拿一下卡"的壳，用完就扔 —— 别把它留在主机的场上
		mg.hand_manager.drop_hand()
		card.queue_free()
	return ok


## 交换草坪上两株植物（三消类玩法那一次滑动）：推本体那条**通用事件**
##
## ★ 为什么不在这里找三消管理器：三消是一关专属玩法，模组不认识它（硬约束 §1-8）。
##   本体早就把「两格互换」做成一条通用事件（`ConstEventName.MAIN_GAME_SWAP_CELL`），
##   谁在用由关卡侧自己订阅 —— 模组推同一条事件，音效 / 结算 / 边界校验全都不用抄一遍
##   （与 `_replay_click_shovel()` 推 `MAIN_GAME_CLICK_SHOVEL` 同一套写法）。
## ⚠️ 这里恒返回 true：换不动（那一格是空的 / 正在结算）由订阅方自己判掉 ——
##   那一笔在主机上就没发生，自然也不会被广播下来，两端依旧一致。
func _replay_swap_cell(args: Dictionary) -> bool:
	var row_a := int(args.get(NetplayCommand.ARG_ROW, -1))
	var col_a := int(args.get(NetplayCommand.ARG_COL, -1))
	var row_b := int(args.get(NetplayCommand.ARG_ROW2, -1))
	var col_b := int(args.get(NetplayCommand.ARG_COL2, -1))
	if row_a < 0 or col_a < 0 or row_b < 0 or col_b < 0:
		return false
	EventBus.push_event(ConstEventName.MAIN_GAME_SWAP_CELL, [row_a, col_a, row_b, col_b])
	return true


## 这一格上现在有哪些植株的编号（种前先记一份，种后凭差集认出新的那一株）
func _plant_ids_in_cell(cell: PlantCell) -> Dictionary:
	var ids := {}
	for place in cell.plant_in_cell:
		var plant: Plant000Base = cell.get_plant(place)
		if is_instance_valid(plant) and plant.entity_id != 0:
			ids[plant.entity_id] = true
	return ids


## ★★ 两端必须认得**同一株植物**，否则快照层会每帧补种
##
## 客户端种下的那一株，编号是**本地自增**出来的（`Character000Base.take_next_entity_id()`，
## 两端各数各的），天生和主机报的号不同 ⇒ `_align_plants()` 按号找不到它 ⇒ 判定"缺这一株"
## ⇒ `_spawn_plant()` 撞在"该格已有植物"上 ⇒ 每帧刷一条日志。
## 更糟的是本地号还可能**恰好撞上**主机另一株的号，让对齐层认错人 —— 那种错位靠
## "按格子+类型认领"补不回来（它已经被当成匹配上了）。
##
## 所以：主机种成后把新植株的编号回填进这条命令，客户端照着改写自己那一株。
func _claim_fresh_plant(cell: PlantCell, before: Dictionary, args: Dictionary) -> void:
	var fresh: Plant000Base = null
	for place in cell.plant_in_cell:
		var plant: Plant000Base = cell.get_plant(place)
		if is_instance_valid(plant) and plant.entity_id != 0 and not before.has(plant.entity_id):
			fresh = plant
			break
	if fresh == null or _session == null:
		return
	if _session.is_host():
		## 主机：写进命令里一起下发（args 是引用，`handle_local_command()` 随后广播的就是它）
		args[NetplayCommand.ARG_NEW_ID] = fresh.entity_id
		return
	## 客户端：改写成主机的编号（命令里没带就维持原样，交给 `_align_plants()` 认领兜底）
	var host_id := int(args.get(NetplayCommand.ARG_NEW_ID, 0))
	if host_id != 0:
		fresh.assign_entity_id(host_id)


## 客户端自己长了一颗阳光、**请主机也长一模一样的一颗**
##
## 主机：照客户端报的（起点 / 落点 / 用时 / 面值）长一颗 —— **一个随机都不摇** ⇒ 两端落在同一处。
##
## ★ **回填主机这一颗的编号**：`args` 是**引用**（`NetplayCommand.args_of()` 返回的就是命令里
##   那个字典），`handle_local_command()` 随后广播的正是这份**改过的**命令 ⇒
##   客户端收到后把那颗**原地改成**这个编号 ⇒ 屏幕上一直是同一颗（不闪）。
##   不回填的话客户端只能"删了重建" ⇒ 玩家会看到那颗阳光**闪一下**。
##
## ⚠️ **本地编号只当身份用**：客户端那颗的本地编号两端会撞（各自独立自增），
##   真正认"是不是主机给的"靠实例级标记（`META_SUN_FROM_HOST`）。
func _replay_sun_claim(args: Dictionary) -> bool:
	var mg := _resolve_main_game()
	if mg == null or mg.suns == null or not is_instance_valid(mg.suns):
		return false
	var from := Vector2(args.get(NetplayCommand.ARG_FROM, Vector2.ZERO))
	var to := Vector2(args.get(NetplayCommand.ARG_TO, Vector2.ZERO))
	## 客户端没给落点（那颗是绕过生成口长出来的，压根没写落点）⇒ 就让它落在当时的位置
	if to == Vector2.ZERO:
		to = from
	var value := int(args.get(NetplayCommand.ARG_SUN_VALUE, SunSpawner.DEFAULT_SUN_VALUE))
	var fall := float(args.get(NetplayCommand.ARG_FALL, 0.0))
	var sun := SunSpawner.spawn_at(mg.suns, from, value, to, fall)
	if sun == null:
		return false
	## ★ 打标记：这一颗是「认领」来的 ⇒ **事件路径别再单独下发** ——
	##   认领那条命令已经带全了（编号 / 起点 / 落点 / 用时 / 面值），
	##   再发一遍标准 `sun_spawn` 会让客户端**同编号长出两颗**。
	sun.set_meta(NetplayCommand.META_SUN_CLAIMED, true)
	## ★ **回填主机的编号**：`args` 是**引用**（`NetplayCommand.args_of()` 返回的就是命令里
	##   那个字典），`handle_local_command()` 随后广播的正是这份**改过的**命令 ⇒
	##   客户端收到后把那颗**原地改成**这个编号 ⇒ 屏幕上一直是同一颗（不闪）。
	##   不回填的话客户端只能"删了重建" ⇒ 玩家会看到那颗阳光**闪一下**。
	args[NetplayCommand.ARG_SUN_ID] = sun.entity_id
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
	return NetplayDropSync.collect_drop_by_id(GameContext.curr_main_game,
		int(args.get(NetplayCommand.ARG_SUN_ID, 0)))


func _on_battle_op_received(op: StringName, args: Dictionary) -> void:
	if _session == null:
		return
	## 主机自己早就跑过了 —— 再跑一遍等于重复落子
	if _session.is_host():
		return
	execute(op, args)


## 主机收到客户端的请求：在**自己这一局**上跑一遍，跑成了才把"事实"发下去
##
## ★ 请求来自哪个 peer 是**必须的**：房主靠它验"卡槽第几格是不是这个人的块"
##   （联机的卡槽按人数切块，见 `NetplayCardSync`）。
func _on_remote_command(from_peer_id: int, command: Dictionary) -> void:
	if _session == null or not _session.is_host():
		return
	if not NetplayCommand.is_valid(command):
		return
	var op := NetplayCommand.op_of(command)
	var args := NetplayCommand.args_of(command)
	if execute(op, args, from_peer_id):
		_session.request_battle_op(command)
	else:
		_notify("伙伴的那一步没落成（%s）—— 主机这一局上跑不动" % str(op))


func _on_battle_seed_received(seed_value: int) -> void:
	_notify("同一颗随机种子已成（%d）" % seed_value)
#endregion


#region 小工具
## 主机这一侧"替客户端拿起同一张卡"：命令里那一张卡的身份（没有 / 认不出时返回 null）
func _card_ref_of(args: Dictionary) -> ResourceCardReference:
	var data: Variant = args.get(NetplayCommand.ARG_CARD_REF, {})
	if not data is Dictionary:
		return null
	return ResourceCardReference.from_dict(data)


## 本机现在手上拿的是不是**这一张**（拿卡与点格子之间可能隔了一段时间，每次都要重判）
func _is_holding_card(mg: MainGameManager, args: Dictionary) -> bool:
	var reference := _card_ref_of(args)
	if reference == null:
		return false
	var hand := mg.hand_manager.curr_hand_component as HandComponentCharacter
	if hand == null:
		return false
	var card: Card = hand.curr_card
	if card == null or not is_instance_valid(card) or card.card_reference == null:
		return false
	return card.card_reference.to_dict() == reference.to_dict()


## 手上拿的是不是**这一张**（比的是**同一个节点**，不是卡的身份字典）
##
## ⚠️ 为什么不比身份字典：比字典时"客户端手上那一张"与"命令里带的那一份"
##   只要有一个字段对不上就判 false，判不准会让"这一笔到底种没种成"跟着歪
##   （见 `_replay_click_cell` 里那段"快照先到"的注释）。
func _is_holding(mg: MainGameManager, card: Card) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	var hand := mg.hand_manager.curr_hand_component as HandComponentCharacter
	if hand == null:
		return false
	var held: Card = hand.curr_card
	return held != null and is_instance_valid(held) and held == card


## 手上的那一张卡（手上没有卡时返回 null）
func _held_card(mg: MainGameManager) -> Card:
	if mg == null or mg.hand_manager == null:
		return null
	var hand := mg.hand_manager.curr_hand_component as HandComponentCharacter
	if hand == null:
		return null
	var card: Card = hand.curr_card
	if card == null or not is_instance_valid(card):
		return null
	return card


## 出战卡槽里的第 [param index] 格（越界 / 没有出战卡槽时返回 null）
func _slot_card_at(mg: MainGameManager, index: int) -> Card:
	var slot := _battle_slot(mg)
	if slot == null or index < 0 or index >= slot.curr_cards.size():
		return null
	var card: Card = slot.curr_cards[index]
	return card if card != null and is_instance_valid(card) else null


## 这张卡现在用得了吗（阳光够 + 不在冷却 + 没被关卡封住）
##
## ★ 房主验种植时的第二道门：客户端说"我要种卡槽第 N 格"，房主先看**自己**那张卡
##   现在能不能用 —— 阳光不够 / 还在冷却 ⇒ 这一笔不认（不种、也不扣钱）。
static func _card_usable(card: Card) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	if not card.is_sun_enough:
		return false
	if card.cool_remain > 0.0:
		return false
	return card.is_can_click


## 卡槽第 [param index] 格是不是落在 [param peer_id] 那一块里
##
## ★ 这是房主验种植的那一句：**不属于这个人的块 ⇒ 这一笔不认**（别人的卡不许种）。
##   分块与合并卡表由 `NetplayCardSync` 持有（它才是管选卡与卡槽的那一枚）。
func _owns_slot_index(peer_id: int, index: int) -> bool:
	var card_sync := _card_sync()
	if card_sync == null:
		return false
	return card_sync.owns_index(peer_id, index)


## 本局的选卡 / 卡槽同步节点（没有就返回 null：这一关没有常规卡槽）
func _card_sync() -> Node:
	var mg := _resolve_main_game()
	if mg == null:
		return null
	return mg.get_node_or_null(NetplayCardSync.SELF_SYNC_NODE_NAME)


## 这一下要用哪一张卡（已经拿到手上）
##
## ★ 只走**旧路**用得到：卡不在卡槽里时（传送带上的卡 / 临时卡），
##   主机那一局没有它 ⇒ 照着身份拿一张同样的。
## [return] `{card: Card, temp: bool}`；拿不到返回空字典
func _take_card_for_replay(mg: MainGameManager, args: Dictionary) -> Dictionary:
	if not args.has(NetplayCommand.ARG_CARD_REF):
		return {}
	## 手上正是那一张 ⇒ 照旧用它
	if _is_holding_card(mg, args):
		var held := _held_card(mg)
		if held != null:
			return {"card": held, "temp": false}
	## ★ **传送带关优先拿主机传送带上那一张**：客户端手里的卡是照主机下发重建的，
	## 它拿走一张，主机的传送带上就有对应的一张（同身份）—— 直接拿它，本体自己会
	## 走 `card_use_end` 消耗掉，两端传送带上的卡才对得上。
	## 走 `_take_card_of()` 造临时卡的话，主机传送带**永远不消耗**这一张（临时卡种完
	## 就 `queue_free()`），而客户端每拿一张少一张 ⇒ 两端越差越多，最后客户端无卡可取。
	## ⚠️ 传送带上找不到（主机那几张已被拿走 / 已经流走）才回退造临时卡兜底。
	if _take_belt_card_of(mg, args):
		var belt_card := _held_card(mg)
		if belt_card != null:
			return {"card": belt_card, "temp": false}
		return {}
	## 主机这一局里没有这一张（那是客户端自己卡槽里的卡）⇒ 照着身份造一张**临时的**
	var temp_card := _take_card_of(mg, args)
	if temp_card == null:
		return {}
	return {"card": temp_card, "temp": true}


## 主机这一局里没有这一张（那是客户端自己卡槽里的卡）⇒ 照着身份造一张**临时的**并拿到手上
##
## [return] 临时造出来的那一张（调用方用完要 `queue_free()`）；造不出来 / 拿不起来返回 null
##
## ★ 为什么必须造一张：两端是**各挑各的卡**（选卡协商只保证不重复），客户端那一株主机手上
##   根本没有 —— 不造的话主机重放"点格子"时手里是空的，这一下操作就凭空消失了。
## ★ 造出来之后走的还是本体那一整套（`MAIN_GAME_CLICK_CARD` → 手持组件 → `click_cell()`），
##   所以地形 / 占用 / 阳光 / 音效 / 种植特效都不用模组再抄一遍。
func _take_card_of(mg: MainGameManager, args: Dictionary) -> Card:
	var card := _make_temp_card(mg, args)
	if card == null:
		return null
	EventBus.push_event(ConstEventName.MAIN_GAME_CLICK_CARD, [card])
	if _is_holding_card(mg, args):
		return card
	Log.warn("联机模组：主机这一侧拿不起这一张卡 %s" % str(args.get(NetplayCommand.ARG_CARD_REF, {})))
	card.queue_free()
	return null


## 传送带关：从主机**自己的传送带**上拿起同身份的那一张（拿不到返回 false）
##
## ★ 与 `_take_card_of()` 的区别：这一张是**本体传送带上的实体**，拿走之后本体照自己的
## `card_use_end` 把它消耗掉 —— 主机传送带因此与客户端同步少一张（客户端那一张是照
## 主机下发重建的，拿走即销毁）。而 `_take_card_of()` 造的是临时卡，不消耗传送带任何东西。
## ⚠️ 走的是本体同一个入口 `MAIN_GAME_CLICK_CARD`，所以拿起来的表现 / 校验全都不用模组抄。
func _take_belt_card_of(mg: MainGameManager, args: Dictionary) -> bool:
	if mg.card_manager == null:
		return false
	var belt := mg.card_manager.card_slot_conveyor_belt
	if belt == null or not is_instance_valid(belt):
		return false
	var reference := _card_ref_of(args)
	if reference == null:
		return false
	var wanted := reference.to_dict()
	for entry in belt.curr_cards:
		var card := entry as Card
		if card == null or not is_instance_valid(card) or card.card_reference == null:
			continue
		if card.card_reference.to_dict() != wanted:
			continue
		EventBus.push_event(ConstEventName.MAIN_GAME_CLICK_CARD, [card])
		return _is_holding_card(mg, args)
	return false


## 照着身份造一张**不在任何卡槽上**的卡（只为让主机"替客户端拿一下"）
##
## 造法照抄传送带那一份（`CardSlotConveyorBelt.spawn_card_by_reference()`）：
##   取模板 → 复制 → 换独立引用 → 入树。
## ⚠️ 必须入树：手持组件要复制卡里的静态形象（`character_static` 是 `@onready`，不入树取不到）
## ⚠️ 挂在本局节点下而不是卡槽下：卡槽是容器，塞进去会把主机自己的卡槽撑出一格
func _make_temp_card(mg: MainGameManager, args: Dictionary) -> Card:
	var reference := _card_ref_of(args)
	if reference == null:
		return null
	var template := AllCards.get_template(reference)
	if template == null:
		Log.error("联机模组：没有这一张卡的模板 %s" % str(reference.to_dict()))
		return null
	var card := template.duplicate() as Card
	if card == null:
		return null
	## ⚠️ 身份用**命令里那一份**（而不是模板自带的）：模板不区分"是不是模仿者"
	##   （`get_template_key()` 只认类别 + 角色编号），照模板走会把模仿者种成原版那一张
	card.card_reference = reference
	## 此刻值多少是**持卡那一端**在管（紫卡会随场上株数加价，主机算不出来），照它报的数扣
	if args.has(NetplayCommand.ARG_SUN_COST):
		card.sun_cost = int(args[NetplayCommand.ARG_SUN_COST])
	card.visible = false
	mg.add_child(card)
	## 扣阳光走本体那一份（出战卡槽自己就是这么接的）；没有出战卡槽的关（传送带）本来就 0 花费
	var slot := _battle_slot(mg)
	if slot != null:
		card.signal_card_use_end.connect(slot.card_use_end.bind(card))
	return card


## 本局的出战卡槽（这一关没有常规卡槽时为 null）
func _battle_slot(mg: MainGameManager) -> CardSlotBattle:
	if mg.card_manager == null:
		return null
	var slot: CardSlotBattle = mg.card_manager.card_slot_battle
	return slot if is_instance_valid(slot) else null


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


## 本节点记录的这一局还活着就用它，否则退回去问 `GameContext.curr_main_game`
## （换关时旧节点会先灭再换新，用"活着的那一份"才不会对着空气操作）
func _resolve_main_game() -> MainGameManager:
	if _main_game != null and is_instance_valid(_main_game):
		return _main_game
	## 显式写明类型：下面 is_instance_valid() 判的是「实例还活着」，
	## 类型写清是为了一眼看出判的是 MainGameManager（GameContext 里它本来就有类型，`:=` 也推得出来）
	var mg: MainGameManager = GameContext.curr_main_game
	return mg if is_instance_valid(mg) else null


func _notify(text: String) -> void:
	if _notice.is_valid():
		_notice.call(text)
#endregion
