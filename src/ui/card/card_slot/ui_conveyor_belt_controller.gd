extends Node
class_name ConveyorBeltController
## 传送带控制器
##
## 管三件事：
##   1. 建 / 启动传送带，出卡间隔（按秒或按倍率）；
##   2. **出卡权重**：底表是关卡数据给的 `conveyor_weights`，运行期可以被「权重规则」
##      （ConveyorWeightRule）按场上情况上下调整 —— 每次出卡前重算一次；
##   3. **查询传送带里有什么卡**：种类、某一种的数量、卡片数组。
##
## 常规卡槽归 `CardSlotController` 管，两者可以同时存在（卡槽在上、传送带在下）。
## 见 docs/参考存档/卡槽与传送带.md

## 所属卡片管理器
var card_manager: CardManager
var card_slot_root: CardSlotRoot
var card_slot_container: PanelContainer

## 传送带节点
var card_slot_conveyor_belt: CardSlotConveyorBelt
## 是否已经启动（教程关会晚一步启动，避免重复启动）
var is_started := false
## 同时有常规卡槽时：传送带**不再挪进卡槽容器** —— 那个容器会把子控件铺满同一个矩形，
## 两条卡槽会叠在一起；留在卡槽根节点上才能按各自的 position 摆成「卡槽在上、传送带在下」
var keep_out_of_container := false

#region 权重
## 关卡数据给的初始权重（**只读底表**，不改写关卡资源里的条目）
var _base_weights: Array[ResourceCardWeight] = []
## 运行期直接指定的权重：键 = `ResourceCardReference.get_template_key()`，值 = 权重
var _weight_overrides: Dictionary = {}
## 运行期按倍率缩放的权重：键同上，值 = 倍率（乘在初始权重上）
var _weight_scales: Dictionary = {}
## 权重规则：每次出卡前按场上情况调整权重
var _rules: Array[ConveyorWeightRule] = []
#endregion


## 由 CardManager 在 init_manager() 里调用，先于 create()
func setup(manager: CardManager) -> void:
	card_manager = manager
	card_slot_root = manager.card_slot_root
	card_slot_container = manager.card_slot_container


## 建传送带；关卡数据里没有传送带时直接返回 false
func create() -> bool:
	if card_manager == null or not card_manager.game_para.has_conveyor_belt():
		return false
	var game_para := card_manager.game_para
	card_slot_conveyor_belt = load("res://src/ui/card/card_slot/card_slot_conveyor_belt.tscn").instantiate()
	card_slot_root.add_child(card_slot_conveyor_belt)
	## 底表只留引用副本：关卡资源上的权重条目是共享资源，改它会污染关卡数据
	for entry: ResourceCardWeight in game_para.conveyor_weights:
		if entry == null or entry.card_reference == null:
			continue
		_base_weights.append(ResourceCardWeight.create(entry.card_reference.copy_reference(), entry.weight))
	## init 内部会 `await process_frame` 再出第一张卡，这里不 await，信号来得及连上
	card_slot_conveyor_belt.init_card_slot_conveyor_belt(game_para)
	card_slot_conveyor_belt.signal_before_create_card.connect(_on_before_create_card)
	## 传送带是第二组卡：快捷键接在常规卡槽后面（卡槽在上、传送带在下）
	card_slot_root.second_cards = card_slot_conveyor_belt.curr_cards
	return true


## 本关有没有传送带
func has_conveyor_belt() -> bool:
	return card_slot_conveyor_belt != null


#region 启动与出卡间隔
## 传送带出现并开始运转（由「开战」调用，可重复调用；见 CardManager.start_conveyor_belt）
func start() -> void:
	if not has_conveyor_belt() or is_started:
		return
	is_started = true
	await card_slot_conveyor_belt.move_card_slot_conveyor_belt(true)
	if not keep_out_of_container:
		card_slot_conveyor_belt.reparent(card_slot_container)
	card_slot_conveyor_belt.start_conveyor_belt()


## 直接指定出卡间隔（秒）
func set_card_interval(interval: float) -> void:
	if has_conveyor_belt():
		card_slot_conveyor_belt.set_create_card_interval(interval)


## 按倍率调整出卡间隔：1 = 关卡原始间隔，0.5 = 间隔减半（出卡速度翻倍）
func set_card_interval_scale(scale: float) -> void:
	if has_conveyor_belt():
		card_slot_conveyor_belt.set_create_card_interval_scale(scale)


## 传送带出现时停在的 y：默认 0（独占一条）；
## 同时有常规卡槽时由 CardManager 下移一个卡槽的高度（卡槽在上、传送带在下）
func set_appear_pos_y(pos_y: float) -> void:
	if has_conveyor_belt():
		card_slot_conveyor_belt.set_appear_pos_y(pos_y)
#endregion


#region 权重
## 挂一条权重规则；规则在每次出卡前被问一次，可以反复调整权重
func add_weight_rule(rule: ConveyorWeightRule) -> void:
	if rule == null:
		return
	rule.controller = self
	_rules.append(rule)
	refresh_weights()


## 当前挂了几条权重规则
func get_weight_rule_num() -> int:
	return _rules.size()


## 直接指定某张卡的权重（0 = 本次不参与抽取）；覆盖倍率设置
func set_card_weight(card_reference: ResourceCardReference, weight: int) -> void:
	if card_reference == null:
		return
	_weight_overrides[card_reference.get_template_key()] = maxi(0, weight)


## 按倍率调整某张卡的权重（乘在关卡给的初始权重上）
func set_card_weight_scale(card_reference: ResourceCardReference, scale: float) -> void:
	if card_reference == null:
		return
	_weight_scales[card_reference.get_template_key()] = maxf(0.0, scale)


## 直接指定某种植物的权重（0 = 本次不参与抽取）
func set_plant_weight(plant_type: CharacterRegistry.PlantType, weight: int) -> void:
	set_card_weight(ResourceCardReference.create(ResourceCardReference.CardType.Plant, plant_type), weight)


## 按倍率调整某种植物的权重（乘在关卡给的初始权重上）
func set_plant_weight_scale(plant_type: CharacterRegistry.PlantType, scale: float) -> void:
	set_card_weight_scale(ResourceCardReference.create(ResourceCardReference.CardType.Plant, plant_type), scale)


## 清掉所有运行期调整，回到关卡给的初始权重
func reset_weights() -> void:
	_weight_overrides.clear()
	_weight_scales.clear()


## 当前生效权重（初始权重 + 倍率 / 直接指定的调整）
func get_current_weight(card_reference: ResourceCardReference) -> int:
	if card_reference == null:
		return 0
	var key: Vector2i = card_reference.get_template_key()
	if _weight_overrides.has(key):
		return int(_weight_overrides[key])
	var weight: int = 0
	for entry: ResourceCardWeight in _base_weights:
		if entry.card_reference.get_template_key() == key:
			weight = entry.weight
			break
	if _weight_scales.has(key):
		weight = int(round(weight * float(_weight_scales[key])))
	return maxi(0, weight)


## 某种植物当前的生效权重（关卡没配这种卡就是 0）
func get_plant_weight(plant_type: CharacterRegistry.PlantType) -> int:
	return get_current_weight(ResourceCardReference.create(ResourceCardReference.CardType.Plant, plant_type))


## 重算权重并推给传送带：先回到初始权重，再让每条规则各调一次
## 每次出卡前都会走一遍（传送带里卡的数量变了，规则可能要跟着变）
func refresh_weights() -> void:
	if not has_conveyor_belt():
		return
	reset_weights()
	for rule: ConveyorWeightRule in _rules:
		rule.apply_weights(self)
	card_slot_conveyor_belt.set_card_weights(_build_effective_weights())


## 按当前调整结果造一份新的权重表（不改动 _base_weights）
func _build_effective_weights() -> Array[ResourceCardWeight]:
	var weights: Array[ResourceCardWeight] = []
	for entry: ResourceCardWeight in _base_weights:
		weights.append(ResourceCardWeight.create(
			entry.card_reference.copy_reference(), get_current_weight(entry.card_reference)))
	return weights


## 传送带每次出卡前发话：按场上情况把权重重算一遍再抽
func _on_before_create_card(_index: int) -> void:
	refresh_weights()
#endregion


#region 查询传送带内的卡片
## 传送带上的卡片（按槽位顺序，最右是刚进来的那张）
func get_cards() -> Array[Card]:
	if not has_conveyor_belt():
		return []
	return card_slot_conveyor_belt.curr_cards


## 传送带上的植物种类（去重，按传送带上的先后顺序）
func get_card_plant_types() -> Array[CharacterRegistry.PlantType]:
	var plant_types: Array[CharacterRegistry.PlantType] = []
	for card: Card in get_cards():
		var plant_type := card.card_plant_type
		if plant_type == CharacterRegistry.PlantType.Null or plant_types.has(plant_type):
			continue
		plant_types.append(plant_type)
	return plant_types


## 传送带上某种植物的张数
func count_card(plant_type: CharacterRegistry.PlantType) -> int:
	var num := 0
	for card: Card in get_cards():
		if card.card_plant_type == plant_type:
			num += 1
	return num


## 传送带上的卡片总数
func count_all_card() -> int:
	return get_cards().size()
#endregion
