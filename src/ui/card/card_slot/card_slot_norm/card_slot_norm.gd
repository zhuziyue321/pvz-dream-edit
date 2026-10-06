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
	for plant_type:CharacterRegistry.PlantType in game_para.banned_plant_types_in_choose_card:
		card_slot_candidate.set_plant_card_banned(plant_type, true)

	for i in card_slot_candidate.all_card_candidate_containers_plant:
		var card:Card = card_slot_candidate.all_card_candidate_containers_plant[i].card
		card.signal_card_click.connect(_on_card_click.bind(card))
	for i in card_slot_candidate.all_card_candidate_containers_zombie:
		var card:Card = card_slot_candidate.all_card_candidate_containers_zombie[i].card
		card.signal_card_click.connect(_on_card_click.bind(card))
	for i in card_slot_candidate.all_card_candidate_containers_boss:
		var card:Card = card_slot_candidate.all_card_candidate_containers_boss[i].card
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
		var content_id:int = int(card_type_data.get("content_id", 0))
		var is_imitater_data:bool = bool(card_type_data.get("is_imitater", false))
		match curr_card_type:
			ResourceCardReference.CardType.Plant:
				var plant_type:CharacterRegistry.PlantType = content_id as CharacterRegistry.PlantType
				if not AllCards.plant_card_ids.has(plant_type):
					continue
				var plant_card_id:int = AllCards.plant_card_ids[plant_type]
				## 如果是模仿者
				if is_imitater_data:
					## 未选择模仿者时
					if not card_slot_candidate.card_imitater.is_be_choosed_imitater:
						card_slot_candidate.all_card_candidate_containers_plant_imitater[plant_card_id].card._on_button_pressed()
				else:
					if not card_slot_candidate.all_card_candidate_containers_plant[plant_card_id].card.is_choosed_pre_card:
						card_slot_candidate.all_card_candidate_containers_plant[plant_card_id].card._on_button_pressed()
			ResourceCardReference.CardType.Zombie:
				## 僵尸卡片隐藏时（ZOMBIE_CARD_ENABLED=false）跳过：待选卡槽里根本没有僵尸卡容器
				if not ConstFeatureSwitch.ZOMBIE_CARD_ENABLED:
					continue
				var zombie_type:CharacterRegistry.ZombieType = content_id as CharacterRegistry.ZombieType
				if not AllCards.zombie_card_ids.has(zombie_type):
					continue
				var zombie_card_id:int = AllCards.zombie_card_ids[zombie_type]
				if not card_slot_candidate.all_card_candidate_containers_zombie[zombie_card_id].card.is_choosed_pre_card:
					card_slot_candidate.all_card_candidate_containers_zombie[zombie_card_id].card._on_button_pressed()
			ResourceCardReference.CardType.ZombieBoss:
				## 僵王卡同样只在僵尸卡开启时出现
				if not ConstFeatureSwitch.ZOMBIE_CARD_ENABLED:
					continue
				var boss_type:CharacterRegistry.ZombieBossType = content_id as CharacterRegistry.ZombieBossType
				if not AllCards.boss_card_ids.has(boss_type):
					continue
				var boss_card_id:int = AllCards.boss_card_ids[boss_type]
				if not card_slot_candidate.all_card_candidate_containers_boss.has(boss_card_id):
					continue
				if not card_slot_candidate.all_card_candidate_containers_boss[boss_card_id].card.is_choosed_pre_card:
					card_slot_candidate.all_card_candidate_containers_boss[boss_card_id].card._on_button_pressed()



## 取消所有已选卡片
func _on_cancal_card_button_pressed() -> void:
	for i in range(card_slot_battle.curr_cards.size()-1, -1, -1):
		card_slot_battle.curr_cards[i]._on_button_pressed()

## 开始游戏按钮
func _on_texture_button_pressed() -> void:
	## 卡槽正常选卡结束开始游戏
	EventBus.push_event("card_slot_norm_start_game")
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
		## 僵尸卡片隐藏时（ZOMBIE_CARD_ENABLED=false）僵尸预选失效：待选区根本没有僵尸卡容器
		if card_reference.card_type == ResourceCardReference.CardType.Zombie \
			and not ConstFeatureSwitch.ZOMBIE_CARD_ENABLED:
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
		ResourceCardReference.CardType.Zombie:
			return card_slot_candidate.all_card_candidate_containers_zombie.get(
				AllCards.zombie_card_ids[card_reference.content_id], null)
		ResourceCardReference.CardType.ZombieBoss:
			return card_slot_candidate.all_card_candidate_containers_boss.get(
				AllCards.boss_card_ids[card_reference.content_id], null)
	return null

## 游戏选卡阶段时，卡片被点击
func _on_card_click(card:Card):
	## 非选卡阶段直接返回
	if Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.CHOOSE_CARD\
		and Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD:
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
		if card_slot_battle.curr_cards.size() >= card_slot_battle.cards_placeholder.size():
			SoundManager.play_other_SFX("buzzer")
			return
		else:
			card.is_choosed_pre_card = true
			card_slot_battle.curr_cards.append(card)
			move_card_to(card, card_slot_battle.cards_placeholder[card_slot_battle.curr_cards.size()-1])

## 游戏选卡阶段时，模仿者卡片被点击
func _on_imitater_card_click(card:Card):
	## 非选卡阶段直接返回
	if Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.CHOOSE_CARD\
		and Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD:
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
		if card_slot_battle.curr_cards.size() >= card_slot_battle.cards_placeholder.size():
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
	if Global.main_game.game_para.is_pot_mode:
		if card.card_plant_type != CharacterRegistry.PlantType.Null:
			if Global.global_read_data.zero_cd_plnat_card_type_on_pot_mode.has(card.card_plant_type):
				card.card_change_cool_time(0)
		## 僵尸卡牌都无冷却
		elif card.card_zombie_type != CharacterRegistry.ZombieType.Null:
			card.card_change_cool_time(0)

### 预选卡隐藏对应待选卡槽的卡片(植物)
#func disappear_card_slot_candidate_plant(plant_type):
	#card_slot_candidate.all_card_candidate_containers_plant[AllCards.plant_card_ids[plant_type]].card.visible = false
	#
### 预选卡隐藏对应待选卡槽的卡片(僵尸)
#func disappear_card_slot_candidate_zombie(zombie_type):
	#card_slot_candidate.all_card_candidate_containers_zombie[AllCards.zombie_card_ids[zombie_type]].card.visible = false

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

