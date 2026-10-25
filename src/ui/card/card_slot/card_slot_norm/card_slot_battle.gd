extends PanelContainer
## 出战卡槽
class_name CardSlotBattle

@onready var curr_sun_value: Label = $SunLabelControl/CurrSunValue
@onready var card_placeholder_ori: TextureRect = $CardUiList/CardPlaceholder_ori
@onready var card_ui_list: HBoxContainer = $CardUiList
@onready var marker_2d_sun_target: Marker2D = %Marker2DSunTarget

## 出战卡槽占位节点
var cards_placeholder:Array = []
## 出战卡片
var curr_cards : Array[Card]
## 出战卡槽**最多能选几张**（0 = 按占位数量算）
##
## ★ 联机时按「卡槽分块」给每人一份：卡槽按人数切成若干块，每人只能在自己那块里选，
##   合起来的张数才不会超过卡槽格数（见 `get_max_choosed()`）。
##   单机没人改这一项 ⇒ 照旧按占位数量算（选卡界面的上限就取这里）。
var max_choosed_card_num: int = 0
## 出战卡槽**只显示这一段**（`visible_start` = 从第几张开始显示，-1 = 从头；
## `visible_count` = 显示几张，-1 = 一直到末尾）
##
## ★ 联机时卡槽按人数分块（见联机模组的卡槽分块）：房主那一侧摆着**合并卡表**
##   （10 槽），但每个玩家只该看见**自己那一块**（5 槽）——
##   可见区间就是"我那块"，区间之外那几张**照样存在、照样走冷却**（卡与冷却都在房主那里），
##   只是不显示、也点不到。
## 单机没人改这一项 ⇒ 照旧全都显示。
var visible_start: int = -1
var visible_count: int = -1
## 卡槽分块（可选）：卡类型 → 块号。空 = 不分块，整槽一条 dense 队（照旧）。
##
## ★ 分块后整槽仍是**一个存储**（卡与冷却都在本槽，「卡槽第几格」仍是整槽口径，
##   见 `index_of_card`）；只是每类卡只进**自己那块**的第一个空位：
##   块 k 占一段连续占位格（起点 = 前面各块宽之和，宽 = `block_sizes[k]`），
##   取消时只清自己那格、其余卡不挪窝 —— 两块的卡互不挤占。
##   例：`{CardType.Zombie: 1, CardType.ZombieBoss: 1}` + `block_sizes = [6, 6]`
##   ⇒ 前 6 格给植物卡、后 6 格给僵尸 / 僵王卡（左右两条银行各摆各的）。
var card_type_blocks: Dictionary = {}
## 各块宽（下标 = 块号）；`card_type_blocks` 为空时不读
var block_sizes: Array[int] = []
## 出战卡槽发不发数字快捷键（false = 整槽不占 1~0，只许鼠标点）
var shortcuts_enabled := true
## 每张卡判「够不够」用哪个池（不接 = 全用 `sun_value`，照旧）。
## 参数是卡，返回该卡所在池的当前值 —— 分币制的槽（植物花阳光 / 僵尸花脑子）
## 由装配方接上；接了之后 `sun_value` 变化也只按各卡**自己的池**重判。
var currency_of_card: Callable = Callable()
## 用卡之后从哪个池扣（不接 = 扣 `sun_value`，照旧）。参数是卡，由接的方自己扣；
## 扣完之后的冷却照旧由 `card_use_end` 统一走。
var on_card_cost: Callable = Callable()
## 阳光值
var sun_value:
	set(value):
		sun_value = value
		curr_sun_value.text = str(value)

		for card in curr_cards:
			if card == null:
				continue
			card.judge_sun_enough(_pool_for(card))

func _ready() -> void:
	Global.config_service.signal_change_disappear_spare_card_placeholder.connect(judge_disappear_add_card_bar)
	EventBus.subscribe(ConstEventName.TEST_CHANGE_SUN_VALUE, func(value): sun_value = value)
	EventBus.subscribe(ConstEventName.ADD_SUN_VALUE, func(value): sun_value+=value)
	EventBus.subscribe(ConstEventName.UPDATE_CARD_PURPLE_SUN_COST, update_card_purple_sun_cost)


## 初始化出战卡槽，管理器调用
func init_card_slot_battle(max_choosed_card_num:int, sun:int):
	self.sun_value = sun
	for _i in range(max_choosed_card_num):
		var cloned_card_placeholder = card_placeholder_ori.duplicate()
		card_ui_list.add_child(cloned_card_placeholder)

	card_placeholder_ori.free()		## 立即删除掉该节点，下面获取卡槽占位节点
	cards_placeholder = card_ui_list.get_children()
	## 更新阳光收集位置
	EventBus.push_event(ConstEventName.UPDATE_MARKER_2D_SUN_TARGET, marker_2d_sun_target)

	return cards_placeholder

## 出战卡槽补一格(夜晚关卡开场戴夫卖出卡槽扩充后调用,让本关立刻用上新卡槽)
## 模板节点 card_placeholder_ori 在 init_card_slot_battle() 里已被释放,只能从现有占位复制
func add_one_card_placeholder() -> void:
	if cards_placeholder.is_empty():
		Log.warn("出战卡槽没有占位节点,无法补一格卡槽")
		return
	var cloned_card_placeholder = cards_placeholder[0].duplicate()
	card_ui_list.add_child(cloned_card_placeholder)
	cards_placeholder = card_ui_list.get_children()

#region 选卡上限与卡位
## 选卡阶段最多能选几张（`max_choosed_card_num` 为 0 时按占位数量算）
##
## ★ 为什么要有这一项：联机时**卡槽按人数分块**（每人一块，见联机模组的卡槽分块），
##   选卡界面的上限必须跟着每人那块的宽度走 —— 否则两个人各选满一整槽，
##   合起来就超过卡槽格数了（房主那边根本摆不下）。
func get_max_choosed() -> int:
	if max_choosed_card_num > 0:
		return mini(max_choosed_card_num, cards_placeholder.size())
	return cards_placeholder.size()


#region 分块与卡位（`card_type_blocks` 为空时全部按不分块的旧口径走）
## 卡属于哪一块（不分块 / 字典没登记的类型都算第 0 块）
func block_of_card(card: Card) -> int:
	if card == null or card_type_blocks.is_empty():
		return 0
	return int(card_type_blocks.get(card.card_type, 0))


## 第 [param block] 块的起始占位下标
func block_begin(block: int) -> int:
	var begin := 0
	for i in mini(block, block_sizes.size()):
		begin += block_sizes[i]
	return begin


## 第 [param block] 块的宽（块号越界按 0 算）
func block_width(block: int) -> int:
	return block_sizes[block] if block >= 0 and block < block_sizes.size() else 0


## 该块里第一个空位（没有空位 = 这块满了，返回 -1）
func free_index_in_block(block: int) -> int:
	var begin := block_begin(block)
	for i in range(begin, begin + block_width(block)):
		if i >= curr_cards.size() or curr_cards[i] == null:
			return i
	return -1


## 该块已经放了几张
func count_cards_in_block(block: int) -> int:
	var n := 0
	var begin := block_begin(block)
	for i in range(begin, mini(begin + block_width(block), curr_cards.size())):
		if curr_cards[i] != null:
			n += 1
	return n


## 把卡放进第 [param index] 格（中部长出的空位补 null）
func put_card_at(card: Card, index: int) -> void:
	while curr_cards.size() <= index:
		curr_cards.append(null)
	curr_cards[index] = card


## 把卡从槽里拿出来：只清自己那格，其余卡**不前移**（分块时各块独立，
## 空位留在原地）。返回它原来的下标（不在槽里返回 -1）
func take_out_card(card: Card) -> int:
	var index := index_of_card(card)
	if index != -1:
		curr_cards[index] = null
	return index


## 这张卡判「够不够」用的池（不接 `currency_of_card` 时全部用 sun_value）
func _pool_for(card: Card) -> int:
	return currency_of_card.call(card) if currency_of_card.is_valid() else sun_value
#endregion


## 某张卡在出战卡槽里的下标（不在卡槽里返回 -1）
##
## ★ 这是「卡在卡槽中的位置」的**唯一口径**：种植时上报这一条，
##   联机那侧就能按"卡槽第几格"认人（卡与冷却都在房主那里），不必比对卡的完整身份。
func index_of_card(card: Card) -> int:
	if card == null or not is_instance_valid(card):
		return -1
	return curr_cards.find(card)


## 出战卡槽**只显示** [param start] 起 [param count] 张（-1 / -1 = 恢复成全都显示）
##
## ★ 联机分块用：房主那一侧是合并卡表（10 槽），每个玩家只显示**自己那一块**。
##   区间之外那几张卡**照样在槽里**（冷却照走、照样占着"第几格"），
##   只是看不见、点不到 —— 所以房主那边"卡槽第几格"仍然是**整副合并卡表**的口径。
func set_visible_range(start: int, count: int) -> void:
	visible_start = start if start >= 0 else -1
	visible_count = count if count >= 0 else -1
	judge_disappear_add_card_bar()
	main_game_refresh_card()


## 可见区间的起点（没有限制 ⇒ 0）
func visible_begin() -> int:
	return visible_start if visible_start > 0 else 0


## 第 [param index] 张卡在不**可见区间**里
func is_index_visible(index: int) -> bool:
	if visible_start < 0 and visible_count < 0:
		return true
	var begin := visible_begin()
	if visible_count < 0:
		return index >= begin
	return index >= begin and index < begin + visible_count
#endregion

## 主游戏刷新卡片
func main_game_refresh_card():
	update_card_purple_sun_cost()
	for i in range(curr_cards.size()):
		var card:Card = curr_cards[i]
		if card == null:
			continue
		card.judge_sun_enough(_pool_for(card))
		## 快捷键按**可见序号**给（分块时看不见的那几张不占快捷键）；
		## 整槽关掉快捷键时（对战这种）全部只许鼠标点
		if not shortcuts_enabled:
			card.set_shortcut_disappear()
		elif is_index_visible(i):
			card.set_shortcut((i - visible_begin() + 1) % 10)
		else:
			card.set_shortcut_disappear()
		if not card.signal_card_use_end.is_connected(card_use_end.bind(card)):
			card.signal_card_use_end.connect(card_use_end.bind(card))
	judge_disappear_add_card_bar()

## 把出战卡槽**整体换成**这几张卡：按身份比对，缺的照模板补、多的退回去，顺序照 [param references]
##
## ★ 为什么要"按身份复用"而不是"整批重建"：身份没变的那一张要**留在原位** ——
##   它此刻的冷却遮罩 / 位置 / 点击状态都长在节点上，整批重建会让卡槽白闪一下，
##   正在跑的冷却也被打断（重造出来的卡是从 0 冷却开始的，等于白送一次）。
## ⚠️ 与 `init_pre_choosed_card()` 的区别：那是**开局**往空卡槽里塞（在 `CardSlotNorm` 里），
##   这是**开打之后**的整体替换（关卡脚本中途加 / 撤一张）。
func set_cards(references: Array[ResourceCardReference]) -> void:
	## 旧的那批先整份留着：挑得出来的复用，挑剩下的就是"这一轮已经不要的"
	var old_cards: Array[Card] = curr_cards.duplicate()
	var new_cards: Array[Card] = []
	for reference in references:
		if reference == null or not reference.is_valid():
			continue
		var card := _take_same_card(old_cards, reference)
		if card == null:
			card = AllCards.create_card(reference, Card.CardContext.Battle)
			if card == null:
				continue
		new_cards.append(card)
	for old_card in old_cards:
		_release_card(old_card)

	if card_type_blocks.is_empty():
		## 不分块：照旧一条 dense 队
		curr_cards = new_cards
	else:
		## 分块：各类卡进自己那块的第一个空位（原有空位不动，别的块不受影响）
		for card in new_cards:
			var free_index := free_index_in_block(block_of_card(card))
			if free_index == -1:
				_release_card(card)
				continue
			put_card_at(card, free_index)
	## 卡槽不够就补占位（主机那一侧可能已经买过卡槽扩充）
	while cards_placeholder.size() < curr_cards.size():
		add_one_card_placeholder()
	for i in range(curr_cards.size()):
		var card: Card = curr_cards[i]
		if card == null:
			continue
		var holder: CanvasItem = cards_placeholder[i]
		## ⚠️ `reparent()` 要求调用者**已经在树里**；而 `AllCards.create_card()` 造出来的是棵
		## 孤儿（只有从 `old_cards` 里复用出来的才带着父节点）。对新造的卡直接 `reparent()`
		## 会报 "Node needs a parent to be reparented" ⇒ 这一张**永远进不了树** ⇒ `@onready`
		## 全部停在 null，紧接着的刷新 / 读冷却（`_cool_mask`）全是 "on a base object of type 'Nil'"。
		if card.get_parent() != holder:
			if card.get_parent() == null:
				holder.add_child(card)
			else:
				card.reparent(holder)
		card.position = Vector2.ZERO
		card.visible = true
	main_game_refresh_card()


## 从 [param pool] 里取出身份相同的那一张（**取出** = 顺手从 pool 里移除，
## 免得它留在池子里被后面的 `_release_card()` 当成"撤掉的卡"给退回去）
func _take_same_card(pool: Array[Card], reference: ResourceCardReference) -> Card:
	for i in range(pool.size()):
		var card: Card = pool[i]
		if card == null or not is_instance_valid(card):
			continue
		if _same_identity(card, reference):
			pool.remove_at(i)
			return card
	return null


## 两张卡是不是同一张（**含模仿修饰**：模仿者与普通版是两张不同的卡）
static func _same_identity(card: Card, reference: ResourceCardReference) -> bool:
	if card.card_reference == null or not card.card_reference.is_valid():
		return false
	return card.card_reference.get_selection_key() == reference.get_selection_key()


## 撤掉一张卡：玩家自己挑的那一张**退回待选区**（就当他取消了选择），
## 系统预选 / 现场造出来的那一张直接回收
##
## ⚠️ 为什么不能直接 `queue_free()`：多轮关卡第二轮还要重新选卡，而玩家挑的那一张
##   本来就是**待选区容器里那一个节点**（选卡时只是把它挪进了占位里）—— free 掉之后
##   容器里只剩一个已释放的实例，第二轮点它会直接报错。
func _release_card(card: Card) -> void:
	if card == null or not is_instance_valid(card):
		return
	var container := card.card_candidate_container
	if not is_instance_valid(container):
		card.queue_free()
		return
	card.is_choosed_pre_card = false
	card.reparent(container)
	card.position = Vector2.ZERO


## 开始下一轮出战卡槽更新数据
func start_next_game_card_slot_battle_update():
	for i in range(curr_cards.size()):
		var card:Card = curr_cards[i]
		if card == null:
			continue
		## 卡牌冷却结束,可以点击
		card.set_card_cool_end()
		card.card_ready()
		card.set_shortcut_disappear()
		if card.signal_card_use_end.is_connected(card_use_end.bind(card)):
			card.signal_card_use_end.disconnect(card_use_end.bind(card))

## 卡片种植后信号调用函数
func card_use_end(card:Card):
	## 减少阳光，卡片冷却（分币制的槽由 on_card_cost 自己扣对应的池）
	if on_card_cost.is_valid():
		on_card_cost.call(card)
	else:
		sun_value = sun_value - card.sun_cost
	card.card_cool()

#region 控制台相关
## 是否显示多余卡槽
##
## ★ 现在还要叠一层"**可见区间**"：联机分块时，区间之外的槽位**整格不显示**
##   （那一格的卡也一起看不见、点不到 —— 卡本身还在槽里，冷却照走）。
func judge_disappear_add_card_bar():
	for i in range(cards_placeholder.size()):
		cards_placeholder[i].visible = _placeholder_should_show(i)


## 第 [param index] 个占位格该不该显示
func _placeholder_should_show(index: int) -> bool:
	## 可见区间之外 ⇒ 不显示
	if not is_index_visible(index):
		return false
	## 分块的槽（左右两条固定银行的摆法）：空位照样显示 ——
	## 银行宽是固定的，收走空格会把剩下的卡挤到一起、跟底图对不上
	if not card_type_blocks.is_empty():
		return true
	## 在游戏进行阶段
	if GameContext.curr_main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		if Global.config_service.disappear_spare_card_Placeholder:
			## 放不下卡的空槽位不显示
			return index < curr_cards.size()
	return true

#endregion

## 等待一帧(阳光减少)后 更新当前卡片的紫卡价格,每次植物种植或死亡时调用
func update_card_purple_sun_cost():
	await get_tree().process_frame
	for card:Card in curr_cards:
		if card == null or not card.is_purple_card:
			continue
		if GameContext.curr_main_game.plant_cell_manager.curr_plant_num.has(card.card_plant_type):
			card.sun_cost = Global.character_registry.get_plant_info(card.card_plant_type, CharacterRegistry.PlantInfoAttribute.SunCost) + 50 * GameContext.curr_main_game.plant_cell_manager.curr_plant_num[card.card_plant_type]
			card.judge_sun_enough(sun_value)
