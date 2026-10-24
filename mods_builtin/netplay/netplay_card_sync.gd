extends Node
## 联机选卡协商 + **卡槽分块**（联机时才装）的一枚节点（由 `NetplayMod.install_to_main_game()` 现场挂到本局上）
##
## 为什么单开一个文件：要做的事是"盯着玩家选卡 + 跟对面商量 + 把卡槽切成每人一块"，
## 跟连线本身（会话）不是一回事，跟模组的装配也不是一回事。会话只管把消息送到，
## `NetplayMod` 只管装配 —— 各管一件事。
##
## 四件事：
##   1. 本机选了什么 —— 边了就广播出去（用全量快照，不面向 increment，丢包也不拆歪）
##   2. 对面挑走的卡 —— 在本机待选区**留在原处压暗（变黑）**，点不动（这就是"不能选重复"）
##   3. 撞车（几乎同一刻选了同一张）—— **peer id 大的一方让**，自动取消掉自己那张，
##      两端用同一条规则算，结果必然一致，不需要再额外问一句谁让
##   4. ★ **卡槽分块**（联机的卡槽按人数切块，见 `NetplaySlotLayout`）：
##      选卡收工那一刻，房主把各人选的卡**按块顺序拼成一份**，换进自己的卡槽 ——
##      **所有卡与冷却都在房主这里**，全局只有一份；
##      客户端照着把自己的卡槽换成同一份 ⇒ 两端"卡槽第几格"指的是同一张卡。
##      种植时客户端只报"第几格"，房主验"这一格落在谁的块里"（见 `NetplayBattleSync`）。
##
## 为什么是"各自主张 + 事后置灰"，不是"房主发牌"：卡自带**各自的存档**（解锁的植物不一样），
## 房主手里不一定有我想要的那张，也不一定有我已经解锁的那张。
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜
## [NetplaySlotLayout](netplay_slot_layout.gd) ｜ [NetplayBattleSync](netplay_battle_sync.gd)

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录 / 上级的文件一律 preload 成常量再引用，不能写 `extends Xxx` / `var x: Xxx`
const NetplaySlotLayout := preload("netplay_slot_layout.gd")

const SELF_SYNC_NODE_NAME := "NetplayCardSync"
## 对面挑走之后本机这一张的压暗色（同"阳光不够 / 冷却中"那类不可用卡的观感一致）
const TAKEN_TINT := Color(0.45, 0.45, 0.45, 1.0)

var _session = null
var _main_game: MainGameManager = null
## 本机上一帧发出去的快照（避免没变也一遍遍发）
var _mine_sent: Array[Dictionary] = []
## 对端的快照：{peer_id = Array[Dictionary]}
var _others: Dictionary = {}
## 进选卡阶段后第一次同步要向对面要一次现状（不然晚进的人看不到对面已经挑了什么）
var _asked_refresh := false
## 上一帧还在选卡吗（选卡结束时要用它触发一次还原）
var _was_in_choose := false
## ★ **分块方案**：{peer_id = 那人那块能放几张}（房主算出来，客户端照着限自己的选卡张数）
var _widths: Dictionary = {}
## ★ **合并卡表里每块的范围**：{peer_id = {start, count}}（房主验种植时用）
var _ranges: Dictionary = {}
## 房主下发的那份分块方案（客户端存着，等收工那一刻换成自己的卡槽）
var _layout: Dictionary = {}
## 本机卡槽**已经换成合并卡表**了吗（没换之前"卡槽第几格"没有意义）
var _shared_ready := false
## 选卡张数上限**已经落到卡槽上**了吗
var _cap_applied := false
## ★ 房主那边**留着的**那份合并卡表（客户端来要时可以重发）
var _composed_layout: Dictionary = {}
## 已经向房主要过几次合并卡表（别要太勤）
var _refresh_asks := 0
## `_process` 跑过没有（第一帧记一条日志，好确认这枚节点真的在动）
var _seen_process := false
## 已经按**几格**的卡槽发过方案（卡槽建好 / 格数变了才重发）
var _plan_capacity := 0
## 上一次要合并卡表的时刻（毫秒）
var _last_refresh_ask := 0
## 一句话写进日志（回调由 `NetplayMod` 传进来；没接上就什么都不做）
var _notice: Callable = Callable()


## 挂上来之后要先接线：[param notice] `func(text: String) -> void`
func setup(session, main_game: MainGameManager, notice: Callable = Callable()) -> void:
	_session = session
	_main_game = main_game
	_notice = notice
	if _session == null:
		return
	if not _session.card_selection_received.is_connected(_on_remote_selection):
		_session.card_selection_received.connect(_on_remote_selection)
	if not _session.card_selection_refresh_requested.is_connected(_on_refresh_requested):
		_session.card_selection_refresh_requested.connect(_on_refresh_requested)
	## ★ 卡槽分块方案：房主下发 ⇒ 本机照着限选卡张数 / 收工时换成合并卡表
	if not _session.slot_layout_received.is_connected(_on_slot_layout_received):
		_session.slot_layout_received.connect(_on_slot_layout_received)
	## 客户端来要合并卡表 ⇒ 房主重发一次（见 `_on_slot_layout_refresh_requested()`）
	if not _session.slot_layout_refresh_requested.is_connected(_on_slot_layout_refresh_requested):
		_session.slot_layout_refresh_requested.connect(_on_slot_layout_refresh_requested)
	## 屋里有人进 / 出 ⇒ 人数变了 ⇒ 每块的宽度也变了 ⇒ 房主重发一次方案
	if not _session.peer_joined.is_connected(_on_room_changed):
		_session.peer_joined.connect(_on_room_changed)
	if not _session.peer_left.is_connected(_on_room_changed):
		_session.peer_left.connect(_on_room_changed)
	## 房主：进关这一刻先把方案发出去（客户端要靠它限住自己选几张）
	if _session.is_host():
		_send_plan()


func _exit_tree() -> void:
	## 节点随本局一起没（见 `ModBase`：随场景灭）。离开前要把**协商压暗**的那些卡还原：
	## 换一局时卡槽界面会重建，本节点加的状态不跟着走，留着也没用；
	## 更重要的是别让"这一局的变黑"被误当成下一局的实际状态。
	_restore_taken_visuals()


func _process(_delta: float) -> void:
	if _session == null or _main_game == null:
		return
	if not _seen_process:
		_seen_process = true
		Log.info("联机模组: 卡槽同步在跑（当前阶段=%d）" % int(_main_game.main_game_progress))
	## ★ 卡槽控制器可能比模组装配晚一步才建好 ⇒ 方案要**等卡槽出来再发**
	##   （早发的话"容量"是 0，客户端的选卡张数上限就成了错的）。
	_ensure_plan()
	## 选卡张数上限：方案可能比卡槽先到（卡槽建好之后补一次）
	_apply_select_cap()
	if not _in_choose_phase():
		## 选卡已经结束（进入 PREPARE 打起来了）：压暗没有意义了，清掉
		if _was_in_choose:
			_was_in_choose = false
			_restore_taken_visuals()
			## ★ 选卡收工这一刻：房主拼出合并卡表，客户端把自己的卡槽换成那一份
			_on_choose_phase_end()
		## ★ 还没换上合并卡表 ⇒ **继续向房主要**（收工那一刻可能比房主早，
		##   或者那一份在路上丢了）—— 冷却与次数上限在 `_ask_for_layout_refresh()` 里。
		if not _shared_ready:
			_ask_for_layout_refresh()
		return
	_was_in_choose = true
	if not _asked_refresh:
		_asked_refresh = true
		_session.ask_card_selection_refresh()
	var mine := _local_selection()
	if mine != _mine_sent:
		_mine_sent = mine
		_session.report_card_selection(mine)


#region 本机 → 对端
## 当前出战卡槽里的卡（全是 `ResourceCardReference.to_dict()`，可直接进 RPC）
func _local_selection() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var battle := _battle_slot()
	if battle == null:
		return out
	for card: Card in battle.curr_cards:
		if card == null or card.card_reference == null or not card.card_reference.is_valid():
			continue
		out.append(card.card_reference.to_dict())
	return out
#endregion


#region 对端 → 本机
func _on_remote_selection(from_peer_id: int, selections: Array) -> void:
	if not _in_choose_phase():
		return
	var mine_then := _local_selection()
	_others[from_peer_id] = selections
	_apply_taken_visuals()
	_resolve_conflicts(from_peer_id, mine_then)


func _on_refresh_requested() -> void:
	if not _in_choose_phase():
		return
	_session.report_card_selection(_local_selection())


## 屋里有人进 / 出：房主重发一次分块方案（每块的宽度变了）
func _on_room_changed(_peer_id: int) -> void:
	if _session == null or not _session.is_host():
		return
	_send_plan()


## 房主下发了分块方案（宽度 + 可能还有合并卡表）
func _on_slot_layout_received(layout: Dictionary) -> void:
	if layout.is_empty():
		return
	## 宽度：拿来限住本机选卡能选几张
	var widths: Dictionary = layout.get("widths", {})
	if not widths.is_empty():
		_widths = widths
		_apply_select_cap()
	## 合并卡表：收工之后才发；收到了就换掉本机卡槽（"第几格"两端从此对得上）
	if layout.has("ranges"):
		_layout = layout
		Log.info("联机模组: 收到合并卡表（%d 张）" % int(layout.get("refs", []).size()))
		if not _in_choose_phase():
			_apply_shared_slot()
	else:
		Log.info("联机模组: 收到卡槽分块方案（宽度 %s）" % str(widths))
#endregion


## 对面挑走的那些卡：留在本机待选区**变黑 + 点不动**
## 不用 `set_plant_card_banned()`：那是留给关卡禁选的（`CardCandidateContainer.set_banned()` 会把卡**整张撤走**），
## 对面挑走的卡要**留在原处压暗** —— 一眼看得出"他抽走了哪一张"，也知道自己还能挑什么。
func _apply_taken_visuals() -> void:
	var candidates := _candidates()
	if candidates == null:
		return
	var taken := _taken_by_others()
	_each_plant_container(candidates, func(container: CardCandidateContainer, card: Card) -> void:
		var is_taken := taken.has(card.card_plant_type)
		_set_card_taken_look(container, card, is_taken))


## 遍历待选区（普通植物页 + 模仿者页）里每一张还有卡在的容器
func _each_plant_container(candidates: CardSlotCandidate, body: Callable) -> void:
	for containers in [candidates.all_card_candidate_containers_plant,
			candidates.all_card_candidate_containers_plant_imitater]:
		for card_id in containers:
			var container: CardCandidateContainer = containers[card_id]
			if container == null or not is_instance_valid(container):
				continue
			if container.card == null or not is_instance_valid(container.card):
				continue
			body.call(container, container.card)


## 压暗 + 点不动 / 还原（都是 `Card` 与 `Container` 的公开 API，不涉及关卡自己的判据）
func _set_card_taken_look(_container: CardCandidateContainer, card: Card, taken: bool) -> void:
	card.modulate = TAKEN_TINT if taken else Color(1, 1, 1, 1)
	if taken:
		card.mouse_filter_stop()
	else:
		card.mouse_filter_start()


## 离开选卡 / 本局结束前把"变黑"还原：压暗是本 node 加在 UI 上的，
## 界面会从 `card_slot_norm.tscn` 重新实例化，留着的状态不跟着走。
func _restore_taken_visuals() -> void:
	var candidates := _candidates()
	if candidates == null:
		return
	_each_plant_container(candidates, func(_container: CardCandidateContainer, card: Card) -> void:
		card.modulate = Color(1, 1, 1, 1)
		card.mouse_filter_start())


## 对面已经挑走的全部植物类型（本机挑的不算：自己还要能点掉）
func _taken_by_others() -> Array[StringName]:
	var out: Array[StringName] = []
	for peer_id in _others:
		for one in _others[peer_id]:
			if not (one is Dictionary):
				continue
			var plant_type := _plant_type_of(one)
			if plant_type == PlantIds.NULL:
				continue
			if not out.has(plant_type):
				out.append(plant_type)
	return out


## 撞车的让路规则：**peer id 大的一方让**
## 抽成 static 是为了让探针能直接验这条规则（它不看任何节点状态，两端按同一条算，结论必然一致）
static func must_yield(my_peer_id: int, rival_peer_id: int) -> bool:
	return my_peer_id > rival_peer_id


## 撞车的处理：同一张卡两边都挑了 → **peer id 大的一方让**
func _resolve_conflicts(from_peer_id: int, mine_then: Array[Dictionary]) -> void:
	if _session == null or not must_yield(_session.local_peer_id, from_peer_id):
		return
	for one in _others[from_peer_id]:
		if not (one is Dictionary):
			continue
		if not _has_same_card(mine_then, one):
			continue
		_give_up_card(one)


## 让出一张卡：直接照着"玩家点了一下这张卡"的做法把它取消掉（不用再照抄一遍卡槽内部的移动逻辑）
func _give_up_card(card_data: Dictionary) -> void:
	var battle := _battle_slot()
	if battle == null:
		return
	for card: Card in battle.curr_cards:
		if card == null or card.card_reference == null:
			continue
		if card.card_reference.to_dict() != card_data:
			continue
		var name_of_card := str(card.card_plant_type)
		card._on_button_pressed()
		_notify("已让出重复的卡 %s（对面 peer %d 先挑的）" % [name_of_card, _priority_peer_of(card_data)])
		Log.info("联机模组: 卡 %s 被对面先挑走了，这一端自动取消选择" % name_of_card)
		return


func _priority_peer_of(card_data: Dictionary) -> int:
	for peer_id in _others:
		for one in _others[peer_id]:
			if one == card_data:
				return peer_id
	return 0
#endregion


#region 卡槽分块
## 本机卡槽**已经换成合并卡表**了吗（没换之前"卡槽第几格"没有意义）
func is_shared_ready() -> bool:
	return _shared_ready


## 卡槽第 [param index] 格是不是落在 [param peer_id] 那一块里（房主验种植时用）
##
## ★ 这是"卡属于这个人的块"那一句判定：不属于 ⇒ 这一笔种植不认。
func owns_index(peer_id: int, index: int) -> bool:
	return NetplaySlotLayout.owns_index(_ranges, peer_id, index)


## 某人那块在合并卡表里的范围（没有就返回空字典）
func range_of(peer_id: int) -> Dictionary:
	return NetplaySlotLayout.range_of(_ranges, peer_id)


## 选卡收工那一刻（**离开选卡阶段**）：房主拼合并卡表，客户端换成那一份
func _on_choose_phase_end() -> void:
	if _session == null:
		return
	Log.info("联机模组: 选卡收工（当前阶段=%d）" % int(_main_game.main_game_progress))
	if _session.is_host():
		_compose_shared_slot()
	else:
		_apply_shared_slot()
		## ★ 收工这一刻合并卡表可能**还没到**（客户端的过渡可能比房主先走完）——
		##   没拿到就**回头向房主要一次**（房主那边留着这份，随时能重发）。
		if not _shared_ready:
			_ask_for_layout_refresh()


## 客户端：向房主再要一次合并卡表（最多要几次、隔多久）
func _ask_for_layout_refresh() -> void:
	if _session == null or not _session.is_client():
		return
	if _shared_ready:
		return
	if _refresh_asks >= 5:
		return
	var now := Time.get_ticks_msec()
	if _refresh_asks > 0 and now - _last_refresh_ask < 1500:
		return
	_refresh_asks += 1
	_last_refresh_ask = now
	Log.info("联机模组: 还没拿到合并卡表，向房主再要一次（第 %d 次）" % _refresh_asks)
	_session.request_slot_layout_refresh()


## 房主：客户端来要合并卡表 ⇒ 把留着的那一份再发一次
func _on_slot_layout_refresh_requested() -> void:
	if _session == null or not _session.is_host():
		return
	if _composed_layout.is_empty():
		## 还没拼出来（客户端收工得比房主还早）⇒ 拼完自然会发一次
		return
	Log.info("联机模组: 客户端要合并卡表，重发一次")
	_session.request_slot_layout(_composed_layout)


## 房主：把各人选的卡按块顺序拼成一份，换进自己的卡槽，并把方案下发
##
## ★ 这一步之后"**所有卡与冷却都在房主这里**"才真正成立：
##   房主的卡槽里摆着屋里所有人那几块卡（冷却也长在房主那些卡上），
##   客户端照同一份摆好 —— 两端"卡槽第几格"指的是同一张卡。
func _compose_shared_slot() -> void:
	var slot := _battle_slot()
	if slot == null or _session == null or not _session.is_host():
		Log.warn("联机模组: 这一局没法分块（没有出战卡槽？传送带关就是这样）")
		return
	var peers := _player_peer_ids()
	var capacity := slot.cards_placeholder.size()
	var plan := NetplaySlotLayout.plan_of(peers, capacity)
	var own := _local_references()
	var blocks: Array = []
	for peer_id in peers:
		var refs: Array[ResourceCardReference] = own \
			if peer_id == int(_session.local_peer_id) else _references_of(_others.get(peer_id, []))
		## 每块最多放它那份宽度：超出的（有人多选了）这一局不认
		var width := int(plan.get(peer_id, 0))
		if refs.size() > width:
			Log.warn("联机模组: 玩家 %d 选了 %d 张，超过他那块的 %d 张 —— 多出来的这一局不认"
				% [peer_id, refs.size(), width])
			refs = _limit_refs(refs, width)
		blocks.append({"peer_id": peer_id, "refs": refs})
	var composed := NetplaySlotLayout.compose(blocks)
	## 房主自己的卡槽换成这一份
	slot.set_cards(composed["refs"])
	_ranges = composed["ranges"]
	_shared_ready = true
	_widths = plan
	## 只显示**房主自己那一块**（合并卡表是 10 槽，房主眼前只摆他那 5 槽）
	_apply_visible_range(slot, _ranges, int(_session.local_peer_id))
	## ★ 这一份**留着**：客户端收工时若还没拿到（谁的过渡先走完谁先到），
	##   会**回头来要一次** —— 房主随时能重发（见 `_on_slot_layout_refresh_requested()`）。
	_composed_layout = {
		"capacity": capacity,
		"widths": plan,
		"refs": _dicts_of(composed["refs"]),
		"ranges": _ranges,
	}
	_session.request_slot_layout(_composed_layout)
	Log.info("联机模组: 卡槽已分块（%d 人 / %d 格）：%s"
		% [peers.size(), capacity, str(_ranges)])


## 客户端：把自己的卡槽换成房主下发的**合并卡表**
func _apply_shared_slot() -> void:
	if _layout.is_empty() or not _layout.has("ranges"):
		return
	var slot := _battle_slot()
	if slot == null:
		return
	var raw: Array = _layout.get("refs", [])
	var refs := _references_of(raw)
	if refs.size() != raw.size():
		## 认不出来的那些（比如那株植物没跟着进包）⇒ 这一局的卡槽对不齐，
		## 宁可这一局不种（不认），也不能拿着错位的下标去种
		Log.warn("联机模组: 合并卡表里有 %d 张认不出来 —— 卡槽对不齐，这一局先不种"
			% (raw.size() - refs.size()))
		return
	slot.set_cards(refs)
	_ranges = _layout.get("ranges", {})
	_shared_ready = true
	## 只显示**本机自己那一块**（房主那侧是合并卡表 10 槽，本机眼前只摆自己那 5 槽）
	_apply_visible_range(slot, _ranges, int(_session.local_peer_id))
	Log.info("联机模组: 本机卡槽已换成合并卡表（%d 张）" % refs.size())


## 只显示 [param peer_id] 那一块（区间之外那几张卡**照样在槽里、照样走冷却**，只是看不见、点不到）
##
## ★ 这一步就是"**两人都显示自己那几槽，服务器那边却是整副卡槽**"的落点：
##   合并卡表是**整副**（比如 10 槽），每个人眼前只摆**自己那一段**（比如 5 槽），
##   但"卡槽第几格"始终是**整副**的口径 ⇒ 房主验归属时不会错位。
func _apply_visible_range(slot: CardSlotBattle, ranges: Dictionary, peer_id: int) -> void:
	var block: Dictionary = ranges.get(peer_id, {})
	if block.is_empty():
		## 我这一块一张都没有（这一局我没选卡）⇒ 眼前一格都不摆
		slot.set_visible_range(0, 0)
		return
	slot.set_visible_range(int(block.get("start", 0)), int(block.get("count", 0)))


## 房主：把这一局的分块方案（每人那块能放几张）发下去
##
## ★ 什么时候发：进关那一刻（客户端要靠它限住自己选几张）与屋里有人进 / 出时
##   （人数变了 ⇒ 每块的宽度也变了）。
## 房主：卡槽**建好之后**（或格数变了）把方案发出去
##
## ★ 为什么不能只在 `setup()` 里发一次：卡槽控制器（`card_manager.init_manager()`）
##   可能比模组装配**晚一步**才建好 —— 那一刻卡槽一张都没有，"容量"算出来是 0，
##   客户端的选卡张数上限就成错的（限成 0 = 一张都不能选）。
func _ensure_plan() -> void:
	if _session == null or not _session.is_host() or not _session.is_linked():
		return
	var slot := _battle_slot()
	if slot == null:
		return
	var capacity := slot.cards_placeholder.size()
	if capacity <= 0 or capacity == _plan_capacity:
		return
	_send_plan()


func _send_plan() -> void:
	if _session == null or not _session.is_host() or not _session.is_linked():
		return
	var slot := _battle_slot()
	if slot == null:
		return
	_plan_capacity = slot.cards_placeholder.size()
	if slot == null:
		return
	var peers := _player_peer_ids()
	var capacity := slot.cards_placeholder.size()
	_widths = NetplaySlotLayout.plan_of(peers, capacity)
	_apply_select_cap()
	_session.request_slot_layout({"capacity": capacity, "widths": _widths})


## 选卡张数上限：联机时按"我这一块能放几张"限（单机没人改 ⇒ 照旧按整副卡槽算）
##
## ⚠️ 宽度会变（屋里有人进 / 出 ⇒ 人数变了 ⇒ 每块宽度也变了），
##   所以这里不是"限一次就完事"，而是**每次都照最新的宽度再落一遍**。
func _apply_select_cap() -> void:
	if _widths.is_empty() or _session == null:
		return
	var slot := _battle_slot()
	if slot == null:
		return
	var width := int(_widths.get(int(_session.local_peer_id), 0))
	if width <= 0:
		return
	if _cap_applied and slot.max_choosed_card_num == width:
		return
	slot.max_choosed_card_num = width
	_cap_applied = true


## 这一局参与的人：房主自己排第一，其余按 peer id 升序
##
## ★ 为什么房主排第一：房主占**第 0 块**，合并卡表的头一段就是他的卡 ——
##   房主是事实来源，他的卡也该最先摆上卡槽。
func _player_peer_ids() -> Array:
	var out: Array = []
	if _session == null:
		return out
	out.append(int(_session.local_peer_id))
	var others: Array = _session.waiting_peer_ids()
	others.sort()
	for peer_id in others:
		out.append(int(peer_id))
	return out


## 本机出战卡槽里那些卡的身份（按槽位顺序）
func _local_references() -> Array[ResourceCardReference]:
	var out: Array[ResourceCardReference] = []
	var battle := _battle_slot()
	if battle == null:
		return out
	for card: Card in battle.curr_cards:
		## ⚠️ 不拿 `is_valid()` 过滤：那个只认**内置**角色（运行期热注册的模组角色不在里面），
		##   过滤掉会让模组自己的卡从合并卡表里消失 ⇒ 两端"第几格"对不上
		if card == null or card.card_reference == null or card.card_reference.content_id == &"":
			continue
		out.append(card.card_reference)
	return out


## 对面某人选了哪些卡（身份）
func _references_of(selections: Array) -> Array[ResourceCardReference]:
	var out: Array[ResourceCardReference] = []
	for one in selections:
		if not (one is Dictionary):
			continue
		var reference := ResourceCardReference.from_dict(one)
		if reference == null or reference.content_id == &"":
			continue
		out.append(reference)
	return out


## 只留前 [param count] 张（超出的那几张这一局不认）
static func _limit_refs(refs: Array[ResourceCardReference], count: int) -> Array[ResourceCardReference]:
	var out: Array[ResourceCardReference] = []
	for i in range(mini(refs.size(), count)):
		out.append(refs[i])
	return out


## 身份列表 → 可直接进 RPC 的字典列表
static func _dicts_of(refs: Array) -> Array:
	var out: Array = []
	for one in refs:
		var reference := one as ResourceCardReference
		if reference == null:
			continue
		out.append(reference.to_dict())
	return out
#endregion


#region 小工具
func _in_choose_phase() -> bool:
	if _main_game == null or not is_instance_valid(_main_game):
		return false
	var progress := _main_game.main_game_progress
	return progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD \
		or progress == MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD


func _battle_slot() -> CardSlotBattle:
	if _main_game == null or not is_instance_valid(_main_game):
		return null
	if _main_game.card_manager == null:
		return null
	var battle: CardSlotBattle = _main_game.card_manager.card_slot_battle
	return battle if is_instance_valid(battle) else null


func _candidates() -> CardSlotCandidate:
	if _main_game == null or not is_instance_valid(_main_game) or _main_game.card_manager == null:
		return null
	var norm: CardSlotNorm = _main_game.card_manager.card_slot_norm
	if not is_instance_valid(norm):
		return null
	var candidates: CardSlotCandidate = norm.card_slot_candidate
	return candidates if is_instance_valid(candidates) else null


## 这条数据是不是植物卡；不是（僵尸 / 僵王）就返回 Null
## 模仿者是"同一张卡换个壳"（`content_id` 就是被模仿的那株植物），按同一张算
func _plant_type_of(card_data: Dictionary) -> StringName:
	if int(card_data.get("card_type", 0)) != ResourceCardReference.CardType.Plant:
		return PlantIds.NULL
	## content_id 在两端都是字符串 id（快照按 PackedStringArray 传），不认老编号
	return card_data.get("content_id", PlantIds.NULL)


func _has_same_card(mine: Array[Dictionary], card_data: Dictionary) -> bool:
	for one in mine:
		if one == card_data:
			return true
	return false




func _notify(text: String) -> void:
	if _notice.is_valid():
		_notice.call(text)
#endregion
