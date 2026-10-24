extends Control
## 正常卡槽
class_name CardSlotNorm

## 临时卡片存放节点，避免卡片被挡住
@onready var temporary_card: Control = $TemporaryCard
## 待选卡槽
@onready var card_slot_candidate: CardSlotCandidate = $CardSlotCandidate
## 出战卡槽节点
@onready var card_slot_battle: CardSlotBattle = $CardSlotBattle


## 初始化出战卡槽，管理器调用
func init_card_slot_norm(game_para:ResourceLevelData):
	card_slot_battle.init_card_slot_battle(game_para.get_max_choosed_card_num(), game_para.start_sun)

	## 本关禁选的植物（原版迷你游戏「坚不可摧」：阳光生产 / 免费植物）：待选区里就不出现
	## 必须在卡片生成完之后设置（_ready 里已经把全部卡片建好了），设置早了没有容器可改
	for plant_type: StringName in game_para.banned_plant_types_in_choose_card:
		card_slot_candidate.set_plant_card_banned(plant_type, true)

	for i in card_slot_candidate.all_card_candidate_containers_plant:
		var card:Card = card_slot_candidate.all_card_candidate_containers_plant[i].card
		card.signal_card_click.connect(_on_card_click.bind(card))
	for i in card_slot_candidate.all_card_candidate_containers_zombie:
		var card:Card = card_slot_candidate.all_card_candidate_containers_zombie[i].card
		card.signal_card_click.connect(_on_card_click.bind(card))
	for i in card_slot_candidate.all_card_candidate_containers_plant_imitater:
		var card:Card = card_slot_candidate.all_card_candidate_containers_plant_imitater[i].card
		card.signal_card_click.connect(_on_imitater_card_click.bind(card))

	## 初始化预选卡
	if not game_para.prechosen_cards.is_empty():
		init_pre_choosed_card(game_para.prechosen_cards)

# 重选上次卡片
## 存档条目为 {card_type, content_id, is_imitater}（见 ResourceCardReference.to_dict）。
func _on_re_card_button_pressed() -> void:
	Global.save_service.load_selected_cards()
	for card_type_data:Dictionary in Global.global_game_state.selected_cards:
		var curr_card_type:ResourceCardReference.CardType = card_type_data.get("card_type", ResourceCardReference.CardType.Null) as ResourceCardReference.CardType
		## content_id 就是字符串 id：老存档里的数字编号已在读档时转好（见 save_service），
		## 这里不再二次兜底 —— 上游漏转的话这里应该直接露出空卡，而不是被静默映射掉
		var is_imitater_data:bool = bool(card_type_data.get("is_imitater", false))
		match curr_card_type:
			ResourceCardReference.CardType.Plant:
				var plant_type: StringName = card_type_data.get("content_id", PlantIds.NULL)
				## 这一株现在还有没有卡位：模仿者按设计没有（见 AllCards.imitater_card）；
				## 没登记进任何一页选卡的追加类植物也没有（见 AllCards.register_plant_choose_page）——
				## 条目可能是模组还开着的时候存下来的，点之前先判一次容器。
				var plant_card_id: int = AllCards.plant_card_ids.get(plant_type, -1)
				var plant_containers: Dictionary[int, CardCandidateContainer] = {}
				if is_imitater_data:
					plant_containers = card_slot_candidate.all_card_candidate_containers_plant_imitater
				else:
					plant_containers = card_slot_candidate.all_card_candidate_containers_plant
				if not plant_containers.has(plant_card_id):
					continue
				var plant_container: CardCandidateContainer = plant_containers[plant_card_id]
				## 如果是模仿者
				if is_imitater_data:
					## 未选择模仿者时
					if not card_slot_candidate.card_imitater.is_be_choosed_imitater:
						plant_container.card._on_button_pressed()
				else:
					if not plant_container.card.is_choosed_pre_card:
						plant_container.card._on_button_pressed()
			ResourceCardReference.CardType.Zombie, ResourceCardReference.CardType.ZombieBoss:
				## 僵王卡与普通僵尸卡只差「content_id 查哪张 id 表」，查出来的 card_id 同属一个空间，
				## 后面按同一份待选容器点即可（僵王不再有自己的候选页）
				var enemy_card_id:int = _resolve_enemy_card_id(curr_card_type, card_type_data.get("content_id", ZombieIds.NULL))
				## 没有卡位（没开僵尸卡 / 没这一张 / 容器整个没生成）就直接跳过
				if not card_slot_candidate.all_card_candidate_containers_zombie.has(enemy_card_id):
					continue
				if not card_slot_candidate.all_card_candidate_containers_zombie[enemy_card_id].card.is_choosed_pre_card:
					card_slot_candidate.all_card_candidate_containers_zombie[enemy_card_id].card._on_button_pressed()



## 取消所有已选卡片
func _on_cancal_card_button_pressed() -> void:
	for i in range(card_slot_battle.curr_cards.size()-1, -1, -1):
		card_slot_battle.curr_cards[i]._on_button_pressed()

## 开始游戏按钮
func _on_texture_button_pressed() -> void:
	## 卡槽正常选卡结束开始游戏
	EventBus.push_event(ConstEventName.CARD_SLOT_NORM_START_GAME)
	#card_disconnect_click_in_choose()
	## 保存上次选卡
	save_choosed_cards()

## 保存当前出战卡槽的选卡结果，供「重选上次卡片」使用
## 跳过选卡阶段时（卡槽被系统自动填满）同样需要调用，保证存档里的上次选卡正确
func save_choosed_cards() -> void:
	Global.global_game_state.selected_cards.clear()
	for card:Card in card_slot_battle.curr_cards:
		## 身份统一写成 {card_type, content_id, is_imitater},僵王卡与普通卡走同一份编码
		if card.card_reference == null or not card.card_reference.is_valid():
			Log.warn("error:当前卡牌没有合法身份,已跳过保存")
			continue
		Global.global_game_state.selected_cards.append(card.card_reference.to_dict())

	Global.save_service.save_selected_cards()

## 初始化系统预选卡
## 从 AllCards 复制一张新卡,隐藏 card_slot_candidate 里对应的待选卡
## [param references] 植物 / 普通僵尸 / 僵王共用一份列表,逐个入槽
func init_pre_choosed_card(references: Array[ResourceCardReference]):
	for card_reference in references:
		if len(card_slot_battle.cards_placeholder) <= len(card_slot_battle.curr_cards):
			Log.warn("预选卡数量超过卡槽占位数，多余的系统预选卡已跳过")
			break
		if card_reference == null or not card_reference.is_valid() or not AllCards.is_battle_card(card_reference):
			Log.warn("预选卡：跳过未注册或不可出战的引用")
			continue
		## 僵尸卡片不可用时僵尸预选失效：待选区根本没有僵尸卡容器
		## （总开关关 + 没开调试模式；开了调试模式则解谜「我是僵尸」这类关卡恢复发牌）
		## 僵王卡与僵尸卡同一条通道（共用一个编号空间），不可用条件也一致
		if (card_reference.card_type == ResourceCardReference.CardType.Zombie \
			or card_reference.card_type == ResourceCardReference.CardType.ZombieBoss) \
			and not Global.global_game_state.is_zombie_card_enabled():
			continue
		var candidate: CardCandidateContainer = _get_candidate_container(card_reference)
		if candidate == null:
			continue
		candidate.card.visible = false
		candidate.card.is_choosed_pre_card = true
		var card: Card = AllCards.create_card(card_reference, Card.CardContext.Selection)
		if card == null:
			continue

		card_slot_battle.curr_cards.append(card)
		pre_choosed_card(card, card_slot_battle.cards_placeholder[len(card_slot_battle.curr_cards)-1])
	## 预选卡断开鼠标点击信号
	card_disconnect_click_in_choose()


## 取某身份在待选区的容器;类别未开放或没有卡位时返回 null
func _get_candidate_container(card_reference: ResourceCardReference) -> CardCandidateContainer:
	match card_reference.card_type:
		ResourceCardReference.CardType.Plant:
			return card_slot_candidate.all_card_candidate_containers_plant.get(
				AllCards.plant_card_ids[card_reference.content_id], null)
		ResourceCardReference.CardType.Zombie, ResourceCardReference.CardType.ZombieBoss:
			return _get_enemy_candidate_container(card_reference.card_type, card_reference.content_id)
	return null

## 敌方卡（普通僵尸 / 僵王）共用的容器查询：两者只用不同的 id 表把 content_id 换成 card_id，
## 得到的是同一个连续编号空间里的下标 ⇒ 查同一份待选容器。没有卡位返回 null。
func _get_enemy_candidate_container(card_type: ResourceCardReference.CardType,
		content_id: StringName) -> CardCandidateContainer:
	var card_id := _resolve_enemy_card_id(card_type, content_id)
	if card_id < 0:
		return null
	return card_slot_candidate.all_card_candidate_containers_zombie.get(card_id, null)

## 把 content_id 换成待选区的 card_id（查 ZombieIds 还是 ZombieBossIds 由类别决定）；
## 僵尸卡没开放、或这种敌人没有卡位时返回 -1。
func _resolve_enemy_card_id(card_type: ResourceCardReference.CardType, content_id: StringName) -> int:
	if not Global.global_game_state.is_zombie_card_enabled():
		return -1
	if card_type == ResourceCardReference.CardType.Zombie:
		return AllCards.zombie_card_ids.get(content_id, -1)
	return AllCards.boss_card_ids.get(content_id, -1)

## 游戏选卡阶段时，卡片被点击
func _on_card_click(card:Card):
	## 非选卡阶段直接返回
	if GameContext.curr_main_game.main_game_progress != MainGameManager.E_MainGameProgress.CHOOSE_CARD\
		and GameContext.curr_main_game.main_game_progress != MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD:
		return
	## 本关禁选的卡（待选区整张不出现）：「重选上次卡片」是直接模拟点击的，绕过了界面，
	## 上次带过向日葵也不该在这一关被重新选进来
	if is_instance_valid(card.card_candidate_container) and card.card_candidate_container.is_banned:
		return
	SoundManager.play_other_SFX("tap")
	# 如果card被选择，取消选取，后面的card向前移动
	if card.is_choosed_pre_card:
		card.is_choosed_pre_card = false
		var card_idx = card_slot_battle.curr_cards.find(card)
		card_slot_battle.curr_cards.erase(card)
		for i in range(card_idx, card_slot_battle.curr_cards.size()):
			move_card_to(card_slot_battle.curr_cards[i], card_slot_battle.cards_placeholder[i])
		move_card_to(card, card.card_candidate_container)

	## 如果没被选取，放在最后一位
	else:
		## ★ 上限取 `get_max_choosed()`：联机时卡槽按人数分块（每人一块），
		##   这里限的是"我这一块能放几张"，不是整副卡槽的格数
		if card_slot_battle.curr_cards.size() >= card_slot_battle.get_max_choosed():
			SoundManager.play_other_SFX("buzzer")
			return
		else:
			card.is_choosed_pre_card = true
			card_slot_battle.curr_cards.append(card)
			move_card_to(card, card_slot_battle.cards_placeholder[card_slot_battle.curr_cards.size()-1])

## 游戏选卡阶段时，模仿者卡片被点击
func _on_imitater_card_click(card:Card):
	## 非选卡阶段直接返回
	if GameContext.curr_main_game.main_game_progress != MainGameManager.E_MainGameProgress.CHOOSE_CARD\
		and GameContext.curr_main_game.main_game_progress != MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD:
		return
	## 同上：被本关禁掉的植物，它的模仿者版本一样选不进来
	if is_instance_valid(card.card_candidate_container) and card.card_candidate_container.is_banned:
		return
	SoundManager.play_other_SFX("tap")
	# 如果card被选择，取消选取，后面的card向前移动
	if card.is_choosed_pre_card:
		card.is_choosed_pre_card = false
		var card_idx = card_slot_battle.curr_cards.find(card)
		card_slot_battle.curr_cards.erase(card)
		for i in range(card_idx, card_slot_battle.curr_cards.size()):
			move_card_to(card_slot_battle.curr_cards[i], card_slot_battle.cards_placeholder[i])
		await move_card_to(card, card_slot_candidate.card_imitater)
		card.reparent(card.card_candidate_container, false)
		card_slot_candidate.imitater_be_choosed_cancel()

	## 如果没被选取，放在最后一位
	else:
		## ★ 上限取 `get_max_choosed()`：联机时卡槽按人数分块（每人一块），
		##   这里限的是"我这一块能放几张"，不是整副卡槽的格数
		if card_slot_battle.curr_cards.size() >= card_slot_battle.get_max_choosed():
			SoundManager.play_other_SFX("buzzer")
			card_slot_candidate.imitater_card_slot_disappear()
			return
		else:
			card.is_choosed_pre_card = true
			card_slot_battle.curr_cards.append(card)
			card.reparent(card_slot_candidate.card_imitater, false)
			move_card_to(card, card_slot_battle.cards_placeholder[card_slot_battle.curr_cards.size()-1])
			card_slot_candidate.imitater_be_choosed()


## 移动card到目标点位置
func move_card_to(card: Card, target_parent: CanvasItem) -> void:
	card.button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.reparent(temporary_card)

	var tween = create_tween()
	tween.tween_property(card, "global_position", target_parent.global_position, 0.2) # 时间可以改短点

	await tween.finished
	card.reparent(target_parent)

	card.button.mouse_filter = Control.MOUSE_FILTER_PASS

## 选卡结束后，卡片断开连接，游戏开始后修改点击信号连接
func card_disconnect_click_in_choose():
	for card in card_slot_battle.curr_cards:
		if card.signal_card_click.is_connected(_on_card_click.bind(card)):
			card.signal_card_click.disconnect(_on_card_click.bind(card))

## 系统预选卡
func pre_choosed_card(card: Card, target_parent: CanvasItem) -> void:
	target_parent.add_child(card)
	card.position = Vector2.ZERO
	#card.card_change_cool_time(0)

	## 罐子模式下系统预选卡无冷却
	if GameContext.curr_main_game.game_para.is_pot_mode:
		if card.card_plant_type != PlantIds.NULL:
			if Global.global_read_data.zero_cd_plnat_card_type_on_pot_mode.has(card.card_plant_type):
				card.card_change_cool_time(0)
		## 僵尸卡牌都无冷却
		elif card.card_zombie_type != ZombieIds.NULL:
			card.card_change_cool_time(0)


## 关卡销毁前把待选卡容器整批还回池：下一关直接复用，不再重新 duplicate / 实例化
## （池在 autoload 上，跨关卡存活；见 `docs/参考存档/卡片与选卡流程.md`）
func _exit_tree() -> void:
	SceneRegistry.recall_candidate_containers()

## 移动卡槽（出现或隐藏）
func move_card_slot_candidate(is_appeal:bool):
	var tween = create_tween()
	if is_appeal:
		tween.tween_property(card_slot_candidate, "position",Vector2(0, 89.0), 0.2) # 时间可以改短点
	else:
		tween.tween_property(card_slot_candidate, "position",Vector2(0, 615.0), 0.2) # 时间可以改短点

	await tween.finished

## 移动待选卡槽（出现或隐藏）
func move_card_slot_battle(is_appeal:bool, appeal_time:= 0.2):
	var tween = create_tween()
	if is_appeal:
		tween.tween_property(card_slot_battle, "position",Vector2(0, 0), appeal_time)
	else:
		tween.tween_property(card_slot_battle, "position",Vector2(0, -100.0), appeal_time)
	await tween.finished
