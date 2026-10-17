extends TextureRect
## 待选卡槽
class_name CardSlotCandidate

## 所有卡片页面的父节点
@onready var all_card_page: Control = $AllCardPage
## 卡片Grid
@onready var grid_container_plant: GridContainer = $AllCardPage/GridContainerPlant
@onready var grid_container_zombie: GridContainer = $AllCardPage/GridContainerZombie

## 所有的备选卡片
## 僵尸与僵王**共用这一份容器**：两者同属一个连续 card_id 空间（见 AllCards.rebuild），
## 选卡层因此把僵王当普通僵尸处理 —— 共用同一批候选页、同一套卡位换算，不再单开一页
var all_card_candidate_containers_plant:Dictionary[int, CardCandidateContainer] = {}
var all_card_candidate_containers_zombie:Dictionary[int, CardCandidateContainer] = {}

## 所有的卡片页面列表
var all_card_page_array:Array[GridContainer] =[]
## 当前页
var curr_page := 0
## 可以显示的页面
var all_show_page:Array[GridContainer] =[]
## 当前页码显示
@onready var label_page: Label = $LabelPage


## 模仿者卡槽对应的父节点
@onready var all_imitater_card: Control = %AllImitaterCard
## 模仿者卡片页面的父节点
@onready var all_card_page_imitater: Control = $AllImitaterCard/Panel/AllCardPageImitater
## 模仿者卡片Grid
@onready var grid_container_plant_imitater: GridContainer = $AllImitaterCard/Panel/AllCardPageImitater/GridContainerPlantImitater


## 所有的模仿者备选卡片
var all_card_candidate_containers_plant_imitater:Dictionary[int, CardCandidateContainer] = {}
## 模仿者卡片背景
@onready var imitater_bg: TextureRect = $ImitaterBG
## 模仿者卡片
@onready var card_imitater: CardImitater = $ImitaterBG/CardImitater
## 所有的模仿者卡片页面列表
var all_card_page_array_imitater:Array[GridContainer] =[]
## 当前模仿者卡片页
var curr_page_imitater := 0
## 可以显示的页面
var all_show_page_imitater:Array[GridContainer] =[]

func _ready() -> void:
	## 卡位内容一律取自数据层快照（跨关卡持久，见 AllCards.get_seed_chooser_catalog）：
	## 本节点只负责排页、点亮与交互，不再自己算顺序。
	var catalog: CardSeedChooserCatalog = AllCards.get_seed_chooser_catalog()
	_init_card_slot_candidate_plant(catalog)
	## 僵尸候选卡页：快照里已经按 GlobalGameState.is_zombie_card_enabled() 定过要不要敌方页
	## （判据见 ConstFeatureSwitch.ZOMBIE_CARD_ENABLED）。场景里的模板 GridContainerZombie
	## 默认 visible=false，不生成页就不会露出空白页。
	if catalog.has_enemy_page:
		_init_card_slot_candidate_zombie(catalog)
	_init_card_slot_candidate_imitater(catalog)

	_init_card_page()

	curr_page_imitater = 0
	all_card_page_array_imitater[0].visible = true

	card_imitater.signal_card_click.connect(imitater_card_slot_appear)
	## 模仿者在商店购买后才开放(见 ConstPlantUnlock.PURPLE_CARD_PRICE)
	imitater_bg.visible = Global.global_game_state.is_plant_unlocked(PlantIds.IMITATER)

## 初始化卡片页面，计算可以显示的页面
func _init_card_page():
	for card_page:GridContainer in all_card_page_array:
		var all_card_selected_placeholder = card_page.get_children()
		for card_selected_placeholder in all_card_selected_placeholder:
			if card_selected_placeholder.get_child_count() == 0:
				continue
			var card_candidate_container :CardCandidateContainer = card_selected_placeholder.get_child(0)
			if card_candidate_container.visible:
				all_show_page.append(card_page)
				break

	curr_page = 0
	all_show_page[0].visible = true

	label_page.text = str(1) + "/" + str(all_show_page.size())

	for card_page:GridContainer in all_card_page_array_imitater:
		var all_card_selected_placeholder = card_page.get_children()
		for card_selected_placeholder in all_card_selected_placeholder:
			if card_selected_placeholder.get_child_count() == 0:
				continue
			var card_candidate_container :CardCandidateContainer = card_selected_placeholder.get_child(0)
			if card_candidate_container.visible:
				all_show_page_imitater.append(card_page)
				break

## 初始化生成植物待选卡槽：卡位顺序取数据层快照，容器从池里取（跨关卡复用）
func _init_card_slot_candidate_plant(catalog: CardSeedChooserCatalog):
	## 页数由植物总数算出来（见 _create_card_pages）
	var all_placeholder_of_page := _create_card_pages(grid_container_plant, all_card_page,
		all_card_page_array, catalog.plants.size())
	if all_placeholder_of_page.is_empty():
		return
	## 每一页的卡片数量
	var num_card_every_page: int = all_placeholder_of_page[0].size()
	for i:int in catalog.plants.size():
		## 源卡（AllCards 常驻节点）→ 池里同身份的候选容器（没有才新建）
		var source_card: Card = catalog.plants[i]
		var card_candidate_container: CardCandidateContainer = \
			SceneRegistry.acquire_candidate_container(source_card, false)
		## 页下标 = i / 每页格数，这里要的就是整除取整（页数由 _create_card_pages 按卡片总数算出来）
		@warning_ignore("integer_division")
		card_candidate_container.reparent(
			all_placeholder_of_page[i / num_card_every_page][i % num_card_every_page], false)
		## 容器仍按 card_id 登记：禁选、预选、"重选上次卡片"都按 card_id 找卡位
		all_card_candidate_containers_plant[source_card.card_id] = card_candidate_container

		card_candidate_container.visible = false

	for plant_type: StringName in Global.global_game_state.curr_plant:
		## 已解锁名单里可能有没有卡位的植物，两类都要跳过（跳过即「它不在待选区」）：
		## · 模仿者在商店购买后会进 curr_plant，但按设计不进 all_plant_card_prefabs
		##   （见 AllCards.imitater_card 注释）；
		## · 注册了却没登记进「可选植物列表」的追加类植物（见 AllCards.add_selectable_plant）
		##   压根没造卡位 —— 照 plant_card_ids 取下标会取到一个不存在的键。
		var plant_card_id: int = AllCards.plant_card_ids.get(plant_type, -1)
		if not all_card_candidate_containers_plant.has(plant_card_id):
			continue
		all_card_candidate_containers_plant[plant_card_id].visible = true


	grid_container_plant.queue_free()

## 初始化生成僵尸待选卡槽(**僵王按普通僵尸一起排**,不再单开一页)
##
## 为什么能合并:`AllCards.rebuild()` 里僵王的 card_id 接在最后一张僵尸卡之后,
## 两者同属一个连续编号空间,`get_enemy_cards_in_choose_order()` 把两份 concat 成一条,
## 走与植物同一套 `_create_card_pages()` 排页 —— 僵王自然落在僵尸页剩下的格子里,
## 不会再出现"整页只有一张僵王"的情况。
## ⚠️ 每页 48 格、当前 27 张僵尸卡 + 1 张僵王卡 ⇒ 它们现在同在第 1 页。
func _init_card_slot_candidate_zombie(catalog: CardSeedChooserCatalog):
	## 敌方牌表顺序:普通僵尸在前,僵王紧接其后（快照里已经拼好）
	var enemy_cards: Array[Card] = catalog.enemies
	var all_placeholder_of_page := _create_card_pages(grid_container_zombie, all_card_page,
		all_card_page_array, enemy_cards.size())
	if all_placeholder_of_page.is_empty():
		return
	## 每一页的卡片数量
	var num_card_every_page: int = all_placeholder_of_page[0].size()
	for i:int in enemy_cards.size():
		var source_card: Card = enemy_cards[i]
		var card_candidate_container: CardCandidateContainer = \
			SceneRegistry.acquire_candidate_container(source_card, false)
		## 页下标 = i / 每页格数，这里要的就是整除取整（页数由 _create_card_pages 按卡片总数算出来）
		@warning_ignore("integer_division")
		card_candidate_container.reparent(
			all_placeholder_of_page[i / num_card_every_page][i % num_card_every_page], false)
		## 容器仍按 card_id 登记：禁选、预选、"重选上次卡片"都按 card_id 找卡位
		all_card_candidate_containers_zombie[source_card.card_id] = card_candidate_container

		card_candidate_container.visible = false

	## 解锁名单仍是两份（ curr_zombie / curr_zombie_boss ）：它们的 id 各查各的表，
	## 查出来的 card_id 已在同一个空间里，所以都直接到同一份容器上点亮
	for zombie_type: StringName in Global.global_game_state.curr_zombie:
		## 没有卡位的僵尸类型直接跳过
		if not AllCards.zombie_card_ids.has(zombie_type):
			continue
		all_card_candidate_containers_zombie[AllCards.zombie_card_ids[zombie_type]].visible = true

	for boss_type: StringName in Global.global_game_state.curr_zombie_boss:
		## 没有卡位的僵王直接跳过
		if not AllCards.boss_card_ids.has(boss_type):
			continue
		all_card_candidate_containers_zombie[AllCards.boss_card_ids[boss_type]].visible = true

	grid_container_zombie.queue_free()

## 初始化生成模仿者待选卡槽：与普通植物页共用同一份顺序快照
func _init_card_slot_candidate_imitater(catalog: CardSeedChooserCatalog):
	var all_placeholder_of_page := _create_card_pages(grid_container_plant_imitater, all_card_page_imitater,
		all_card_page_array_imitater, catalog.plants.size())
	if all_placeholder_of_page.is_empty():
		return
	## 每一页的卡片数量
	var num_card_every_page: int = all_placeholder_of_page[0].size()
	for i:int in catalog.plants.size():
		## 模仿者版是**另一份池条目**（键带 :imitater）：独立身份引用与灰底材质都由池创建时设置
		var source_card: Card = catalog.plants[i]
		var card_candidate_container: CardCandidateContainer = \
			SceneRegistry.acquire_candidate_container(source_card, true)
		## 页下标 = i / 每页格数，这里要的就是整除取整（页数由 _create_card_pages 按卡片总数算出来）
		@warning_ignore("integer_division")
		card_candidate_container.reparent(
			all_placeholder_of_page[i / num_card_every_page][i % num_card_every_page], false)
		all_card_candidate_containers_plant_imitater[source_card.card_id] = card_candidate_container

		card_candidate_container.visible = false

	for plant_type: StringName in Global.global_game_state.curr_plant:
		## 同上：没有卡位的植物（含模仿者自己、没进「可选植物列表」的追加类）在模仿者页也没有卡位
		var plant_card_id: int = AllCards.plant_card_ids.get(plant_type, -1)
		if not all_card_candidate_containers_plant_imitater.has(plant_card_id):
			continue
		all_card_candidate_containers_plant_imitater[plant_card_id].visible = true

	grid_container_plant_imitater.queue_free()


## 造出装得下 num_card 张卡所需的全部页面：**页数 = ceil(卡片总数 / 每页格数)**
##
## 为什么页数要按总数先算出来再建页：待选区有几页是「总共有几张卡」决定的，
## 多一张卡（模组加的、调试模式开的）就多一页；不能等循环里填满了才顺带建下一页 ——
## 那样新卡插在中间时会把后面的普通植物整页挤走。
## 页面一律先隐藏，由 `_init_card_page()` 按「这一页有没有已解锁的卡」决定哪几页真正显示。
## 返回「每一页的占位节点列表」，空数组表示没有卡位（模板一个占位都没有 / 没有卡）。
func _create_card_pages(grid_template: GridContainer, page_parent: Control,
		page_array: Array[GridContainer], num_card: int) -> Array[Array]:
	var all_placeholder_of_page: Array[Array] = []
	var num_card_every_page: int = grid_template.get_child_count()
	if num_card <= 0 or num_card_every_page <= 0:
		return all_placeholder_of_page
	if grid_template.get_parent() == page_parent:
		page_parent.remove_child(grid_template)
	var page_num: int = ceili(float(num_card) / float(num_card_every_page))
	for _page_index in range(page_num):
		var new_grid_container: GridContainer = grid_template.duplicate()
		page_parent.add_child(new_grid_container)
		page_array.append(new_grid_container)
		new_grid_container.visible = false
		all_placeholder_of_page.append(new_grid_container.get_children())
	return all_placeholder_of_page


## 把一种植物（连同它在模仿者页里的那一版）设为禁选 / 解除禁选
## 原版迷你游戏「坚不可摧」禁掉阳光生产类与免费植物：它们出现在待选区也选不了，索性不出现。
## 模仿者页的下标与普通页一样按被模仿植物的 card_id 走，所以两页一起改
func set_plant_card_banned(plant_type: StringName, is_banned: bool) -> void:
	if not AllCards.plant_card_ids.has(plant_type):
		return
	var card_id: int = AllCards.plant_card_ids[plant_type]
	if all_card_candidate_containers_plant.has(card_id):
		all_card_candidate_containers_plant[card_id].set_banned(is_banned)
	if all_card_candidate_containers_plant_imitater.has(card_id):
		all_card_candidate_containers_plant_imitater[card_id].set_banned(is_banned)


## 上一页
func _on_last_page_button_pressed() -> void:
	change_page(-1)

## 下一页
func _on_next_page_button_pressed() -> void:
	change_page(1)


func change_page(change_num:int= 1):
	all_show_page[curr_page].visible = false
	curr_page += change_num
	curr_page %= all_show_page.size()
	all_show_page[curr_page].visible = true

	label_page.text = str(curr_page + 1) + "/" + str(all_show_page.size())


## 模仿者卡槽出现
func imitater_card_slot_appear():
	all_imitater_card.visible = true

## 模仿者卡槽隐藏
func imitater_card_slot_disappear():
	all_imitater_card.visible = false

## 模仿者卡片被选中时
func imitater_be_choosed() -> void:
	imitater_card_slot_disappear()
	card_imitater.imitater_card_be_choosed()

## 模仿者卡片被选中取消时
func imitater_be_choosed_cancel() -> void:
	card_imitater.imitater_card_be_choosed_cancal()



#region 模仿者页面翻页
func _on_imitater_last_page_button_pressed() -> void:
	change_page_imitater(-1)


func _on_imitater_next_page_button_pressed() -> void:
	change_page_imitater(1)


func change_page_imitater(change_num:int= 1):
	all_show_page_imitater[curr_page_imitater].visible = false
	curr_page_imitater += change_num
	curr_page_imitater %= all_show_page_imitater.size()
	all_show_page_imitater[curr_page_imitater].visible = true
#endregion
