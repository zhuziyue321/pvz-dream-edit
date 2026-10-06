extends MainGameSubManager
class_name CardManager

@onready var card_slot_root: CardSlotRoot = %CardSlotRoot
@onready var card_slot_container: PanelContainer = %CardSlotContainer
@onready var canvas_layer_card_slot_front: CanvasLayer = %CanvasLayerCardSlotFront

## 常规卡槽控制器（选卡 / 出战卡槽）：出战卡由玩家选卡决定
var card_slot_controller: CardSlotController
## 传送带控制器（出卡权重 / 出卡间隔 / 查询带上的卡）
var conveyor_controller: ConveyorBeltController

## 下面三个是控制器里的实例，留着给外部（教程 / 结算）照旧读；本管理器不再直接操作它们
## 常规卡槽
var card_slot_norm: CardSlotNorm
var card_slot_battle:CardSlotBattle
## 传送带卡槽
var card_slot_conveyor_belt: CardSlotConveyorBelt
## 传送带是否已启动（教程关会晚一步启动，避免重复启动）
var is_conveyor_belt_started := false

var card_mode:ConstLevelData.E_CardMode

## 传送带出卡间隔倍率：1 = 关卡原始间隔，0.5 = 间隔减半（出卡速度翻倍）
## 关卡脚本可在任意阶段设置：传送带已建好当场生效，还没建好则在 init_manager() 里补一次
var conveyor_card_interval_scale :float = 1.0
## 传送带出卡间隔（秒）；正数时按秒直接覆盖，优先于上面的倍率；非正数表示只用倍率
var conveyor_card_interval :float = 0.0

## 当前临时卡片
var curr_temp_cards:Array[Card]
## 当前手持的临时卡片
var curr_temp_card_in_hm:Card
## 手持物：卡片从手上放回卡槽（临时卡片等待该信号）
signal signal_hand_card_release(card:Card)

func _ready():
	EventBus.subscribe("hand_card_release", _on_hand_card_release)
	EventBus.subscribe("hand_card_take", _on_hand_card_take)

## 当手持物拿到新卡片时
func _on_hand_card_take(curr_card:Card):
	curr_temp_card_in_hm = curr_card
	for temp_card in curr_temp_cards:
		temp_card.mouse_filter_stop()

## 当手持物清除当前手持卡片数据时
func _on_hand_card_release(curr_card:Card):
	## 卡片已经离手，清掉记录：不清的话 clear_all_temp_cards() 会一直把它当「手上的卡」跳过
	if curr_temp_card_in_hm == curr_card:
		curr_temp_card_in_hm = null
	signal_hand_card_release.emit(curr_card)
	for temp_card in curr_temp_cards:
		temp_card.mouse_filter_start()

func init_manager() -> void:
	self.card_mode = game_para.card_mode
	## 两个控制器都建：关卡要哪个就由控制器自己判断（create() 内部按关卡数据决定），
	## 卡槽模式 Both 时两个都会建出来 —— 卡槽在上、传送带在下
	card_slot_controller = CardSlotController.new()
	card_slot_controller.name = "CardSlotController"
	add_child(card_slot_controller)
	card_slot_controller.setup(self)
	card_slot_controller.create()

	conveyor_controller = ConveyorBeltController.new()
	conveyor_controller.name = "ConveyorBeltController"
	add_child(conveyor_controller)
	conveyor_controller.setup(self)
	conveyor_controller.create()

	## 外部（教程 / 结算）照旧读这几个字段
	card_slot_norm = card_slot_controller.card_slot_norm
	card_slot_battle = card_slot_controller.card_slot_battle
	card_slot_conveyor_belt = conveyor_controller.card_slot_conveyor_belt
	## 建好之后补一次：关卡在 run_flow 之前设过的间隔在这里生效
	_apply_conveyor_card_interval()

#region 传送带出卡 / 权重
## 挂一条传送带权重规则（每次出卡前按场上情况调权重，见 ConveyorWeightRule）
func add_conveyor_weight_rule(rule: ConveyorWeightRule) -> void:
	if conveyor_controller == null:
		Log.warn("CardManager：传送带控制器还没建好，权重规则已忽略（本关没有传送带？）")
		return
	conveyor_controller.add_weight_rule(rule)


## 查询传送带上的植物种类（去重）；没有传送带时返回空数组
func get_conveyor_card_plant_types() -> Array[CharacterRegistry.PlantType]:
	if conveyor_controller == null:
		return []
	return conveyor_controller.get_card_plant_types()


## 查询传送带上某种植物的张数
func count_conveyor_card(plant_type: CharacterRegistry.PlantType) -> int:
	if conveyor_controller == null:
		return 0
	return conveyor_controller.count_card(plant_type)


#region 传送带出卡间隔
## 按倍率调整传送带出卡间隔：1 恢复关卡原始间隔，0.5 表示间隔减半（出卡速度翻倍）。[br]
## 非传送带关卡或传送带尚未创建时只记录数值，等 init_manager() 补上；非法值告警并忽略。
func set_conveyor_card_interval_scale(scale: float) -> void:
	if not is_finite(scale) or scale <= 0.0:
		Log.warn("CardManager：传送带出卡间隔倍率必须是正数，收到 %s，本次设置已忽略" % str(scale))
		return
	conveyor_card_interval_scale = scale
	_apply_conveyor_card_interval()

## 直接指定传送带出卡间隔（秒）；正数才生效，优先于倍率设置。[br]
## 与倍率接口同一套延迟生效机制：传送带还没建好就先记着。
func set_conveyor_card_interval(interval: float) -> void:
	if not is_finite(interval) or interval <= 0.0:
		Log.warn("CardManager：传送带出卡间隔必须是正数，收到 %s，本次设置已忽略" % str(interval))
		return
	conveyor_card_interval = interval
	_apply_conveyor_card_interval()

## 把管理器这边记录的间隔设置落到传送带上；间隔按秒优先，其次才是倍率
func _apply_conveyor_card_interval() -> void:
	if conveyor_controller == null or not conveyor_controller.has_conveyor_belt():
		return
	if conveyor_card_interval > 0.0:
		conveyor_controller.set_card_interval(conveyor_card_interval)
	else:
		conveyor_controller.set_card_interval_scale(conveyor_card_interval_scale)
#endregion

## 出战卡槽补一格:夜晚关卡开场戴夫卖出卡槽扩充后,本关的卡槽数要当场 +1
## (戴夫对话发生在 init_manager() 之后,出战卡槽占位已经按旧卡槽数建好了)
func add_one_battle_card_placeholder() -> void:
	card_slot_controller.add_one_battle_card_placeholder()

## 开始下一轮游戏更新卡片管理器
func start_next_game_card_manager_update():
	## 铲子（手持物）界面由 HandManager 依据主游戏阶段统一刷新，这里不再直接改显隐
	card_slot_controller.start_next_game_update()
	## 罐子模式没有出战卡槽，卡片全是罐子里开出来的临时卡片：
	## 切换批次时上一批没用完的卡片一起清掉（原版冒险 4-5 每批重新开始）
	if game_para.is_pot_mode:
		clear_all_temp_cards()


## 卡槽出现(选卡)
func card_slot_appear_choose():
	card_slot_controller.appear_choose()

## 卡槽出现（主游戏阶段开始）
func card_slot_update_main_game():
	await card_slot_controller.update_main_game()
	## 同时有卡槽和传送带时：卡槽在上，传送带压到卡槽下面（按出战卡槽的实际高度）
	## 传送带也不挪进卡槽容器了：那个容器会把子控件铺满同一个矩形，两条卡槽会叠在一起
	if conveyor_controller.has_conveyor_belt() and card_slot_controller.has_card_slot():
		conveyor_controller.keep_out_of_container = true
		conveyor_controller.set_appear_pos_y(card_slot_controller.get_slot_height())
	## 传送带不在这里启动：它跟着「开战」走（见 main_game_start / start_conveyor_belt）——
	## 教学排在开战之前的关卡（1-5）会先调一次「允许操作」，那时传送带还不该出现
	## 铲子（手持物）界面由 HandManager 依据关卡参数与主游戏阶段统一刷新

## 待选卡槽卡槽消失
## 传送带这类关卡没有普通卡槽(card_slot_norm 为 null),
## 选卡阶段被跳过后(见 ResourceLevelData.is_no_choose_permission)这里要能空转,
## 否则「选卡」事件会在这里报错,关卡再也走不到开战
func card_slot_disappear_choose():
	await card_slot_controller.disappear_choose()


## 传送带出现并开始运转（由「开战」启动，可重复调用；见 MainGameManager.main_game_start）
func start_conveyor_belt() -> void:
	if not conveyor_controller.has_conveyor_belt() or is_conveyor_belt_started:
		return
	is_conveyor_belt_started = true
	await conveyor_controller.start()

#region 临时卡片
enum E_TempCardParaAttr{
	PlantType,
	ZombieType,
	CardReference,	## 卡牌身份引用，优先于上面的植物/僵尸编号
	GlobalPos,
	ExistTime,	## 存在时间，若没有，则永久存在
}

## 通用接口：往卡片前景层挂一个节点（临时卡片就挂在这一层）
## **只做挂载，不含任何玩法判断** —— 挂什么、什么时候挂、什么时候起停由关卡脚本自己决定
## （一关专属的发卡器不该进通用管理器，见 docs/项目规范.md §1-8）
func add_card_front_node(node:Node) -> void:
	canvas_layer_card_slot_front.add_child(node)

## 创建临时卡片
## 身份可以用 [member E_TempCardParaAttr.CardReference] 直接给出，也可以沿用旧的植物/僵尸编号。
func create_temp_card(temp_card_para:Dictionary) -> Card:
	var card_reference: ResourceCardReference = temp_card_para.get(E_TempCardParaAttr.CardReference, null) as ResourceCardReference
	if card_reference == null:
		if temp_card_para.has(E_TempCardParaAttr.PlantType) and temp_card_para[E_TempCardParaAttr.PlantType] != CharacterRegistry.PlantType.Null:
			card_reference = ResourceCardReference.create(ResourceCardReference.CardType.Plant,
				temp_card_para[E_TempCardParaAttr.PlantType])
		elif temp_card_para.has(E_TempCardParaAttr.ZombieType) and temp_card_para[E_TempCardParaAttr.ZombieType] != CharacterRegistry.ZombieType.Null:
			card_reference = ResourceCardReference.create(ResourceCardReference.CardType.Zombie,
				temp_card_para[E_TempCardParaAttr.ZombieType])
	if card_reference == null:
		Log.warn("error: 没有卡片类型")
		return
	var new_card_prefabs:Card = AllCards.get_template(card_reference)
	if new_card_prefabs == null:
		Log.warn("error: 卡牌类型未注册：" + str(card_reference.to_dict()))
		return
	var temp_card = new_card_prefabs.duplicate()
	## 副本默认与源卡共享身份资源,先换成独立引用
	temp_card.make_reference_unique()
	curr_temp_cards.append(temp_card)
	canvas_layer_card_slot_front.add_child(temp_card)
	temp_card.global_position = temp_card_para.get(E_TempCardParaAttr.GlobalPos, Vector2(100, 100))
	temp_card.signal_card_use_end.connect(card_use_end.bind(temp_card))

	if temp_card_para.has(E_TempCardParaAttr.ExistTime):
		temp_card_add_exist_timer(temp_card, temp_card_para[E_TempCardParaAttr.ExistTime])

	return temp_card

## 按卡牌身份创建临时卡；[param exist_time] 为负数表示永久存在。
## 支持已注册的植物、普通僵尸和僵王，非法引用或未注册模板返回 null。
func create_temp_card_by_reference(card_reference: ResourceCardReference, global_pos: Vector2, exist_time: float = -1.0) -> Card:
	var para: Dictionary = {
		E_TempCardParaAttr.CardReference: card_reference,
		E_TempCardParaAttr.GlobalPos: global_pos,
	}
	if exist_time >= 0.0:
		para[E_TempCardParaAttr.ExistTime] = exist_time
	return create_temp_card(para)

func temp_card_add_exist_timer(temp_card:Card, temp_card_exist_time:float):
	var temp_card_timer:Timer = Timer.new()
	temp_card_timer.autostart = false
	temp_card_timer.one_shot = true
	temp_card_timer.timeout.connect(_on_temp_card_timer_timeout.bind(temp_card))
	temp_card.add_child(temp_card_timer)
	temp_card_timer.start(temp_card_exist_time)

func _on_temp_card_timer_timeout(temp_card:Card):
	temp_card.card_blink_start()
	## 五秒闪烁后消失
	await get_tree().create_timer(5.0, false).timeout
	if curr_temp_card_in_hm == temp_card:
		await signal_hand_card_release
	## 如果还未被使用
	if is_instance_valid(temp_card):
		card_use_end(temp_card)

func card_use_end(card:Card):
	if not card.is_queued_for_deletion():
		curr_temp_cards.erase(card)
		card.queue_free()

## 清除所有临时卡片（砸罐子关切换批次时用：上一批开出来的卡片不带到下一批）
## 切换批次前主游戏进度已经离开 MAIN_GAME，手持物会先 drop_hand() 把手上的卡放掉，
## （hand_card_release 事件里 curr_temp_card_in_hm 会清空），这里才能整批清掉
func clear_all_temp_cards():
	for temp_card in curr_temp_cards.duplicate():
		card_use_end(temp_card)

#endregion

#region 存档
func get_save_game_data_card_manager()->Dictionary:
	var save_game_data_card_manager:Dictionary = {}
	if card_slot_controller.has_card_slot():
		save_game_data_card_manager["curr_sun_value"] = card_slot_controller.get_sun_value()
	return save_game_data_card_manager

func load_game_data_card_manager(save_game_data_card_manager:Dictionary):
	if card_slot_controller.has_card_slot():
		card_slot_controller.set_sun_value(int(save_game_data_card_manager.get("curr_sun_value", game_para.start_sun)))

#endregion
