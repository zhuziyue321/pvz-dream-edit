extends Node
## 联机选卡协商：**联机时才装**的一枚节点（由 `NetplayMod.install_to_main_game()` 现场挂到本局上）
##
## 为什么单开一个文件：要做的事是"盯着玩家选卡 + 跟对面商量"，跟连线本身（会话）不是一回事，
##  跟模组的装配也不是一回事。会话只管把消息送到，`NetplayMod` 只管装配 —— 各管一件事。
##
## 三件事：
##   1. 本机选了什么 —— 边了就广播出去（用全量快照，不面向 increment，丢包也不拆歪）
##   2. 对面选走的卡 —— 在本机待选区**留在原处压暗（变黑）**，点不动（这就是"不能选重复"）
##   3. 撞车（几乎同一刻选了同一张）—— **peer id 大的一方让**，自动取消掉自己那张，
##      两端用同一条规则算，结果必然一致，不需要再额外问一句谁让
##
## 为什么是"各自主张 + 事后置灰"，不是"房主发牌"：卡自带**各自的存档**（解锁的植物不一样），
## 房主手里不一定有我想要的那张，也不一定有我已经解锁的那张。

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


func _exit_tree() -> void:
	## 节点随本局一起没（见 `ModBase`：随场景灭）。离开前要把**协商压暗**的那些卡还原：
	## 换一局时卡槽界面会重建，本节点加的状态不跟着走，留着也没用；
	## 更重要的是别让"这一局的变黑"被误当成下一局的实际状态。
	_restore_taken_visuals()


func _process(_delta: float) -> void:
	if _session == null or _main_game == null:
		return
	if not _in_choose_phase():
		## 选卡已经结束（进入 PREPARE 打起来了）：压暗没有意义了，清掉
		if _was_in_choose:
			_was_in_choose = false
			_restore_taken_visuals()
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
