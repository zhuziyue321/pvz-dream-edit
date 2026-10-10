extends PanelContainer
class_name CardSlotConveyorBelt
"""
先根据植物和僵尸的权重,随机选取生成植物还是生成僵尸
在使用随机池生成对应的卡片
"""

@onready var conveyor_belt_gear: ConveyorBeltGear = $ConveyorBeltGear
@onready var new_card_area: Panel = $NewCardArea
@onready var create_new_card_timer: Timer = $CreateNewCardTimer

var curr_cards :Array[Card] = []

@export_group("传送带参数")
## 最大卡片数量，固定10个
@export var num_card_max :int = 10
## 每张卡片最终目标位置x,从0开始隔50像素个，ready函数中自动生成
var all_card_pos_x_target :Array[float] = []
## 卡片移动速度
@export var conveyor_velocity :float = 30
## 卡片生成时间间隔（秒）；关卡初始化时按出卡倍率重算，运行期可由外部接口再改
@export var create_new_card_cd :float = 5
## 出卡间隔基准值（秒）：关卡初始化算出来的原始间隔，倍率接口按此基准重算，避免多次调用叠加
var base_create_card_interval :float = 0.0
## 当前出卡间隔倍率：1 为关卡原始间隔，0.5 表示间隔减半（出卡速度翻倍）
var create_card_interval_scale :float = 1.0

#region 随机生成卡片相关
@onready var card_random_pool: CardRandomPool = $CardRandomPool
## 按顺序出现的卡片身份;键为生成序号,未指定的序号走随机池
var conveyor_order:Dictionary[int, ResourceCardReference] = {}
## 当前生成的卡片总数量
var all_num_card :int = 0
#endregion

## 是否正在运行中
var is_working:= false
## 创建新卡片倍率
var create_new_card_speed:float
## 卡片种植完成后信号，计时器判断是否重启
signal signal_card_end
## 每次生成卡片前发出（参数为本次的生成序号）：
## 传送带控制器借此按场上情况重算权重，**本节点不认识任何权重规则**
signal signal_before_create_card(index:int)
## 本机出了一张卡（参数：这一张的身份 + 生成序号）—— 通用观测口，
## 谁想"知道刚出了哪一张"就连它（联机的主机据此把这一张下发下去）
signal card_created(reference:ResourceCardReference, index:int)

## 出卡闸门（通用问询口，不带联机字样）：返回 false = 这一次不许本地出卡
##
## 默认恒为空 Callable（照旧出）。联机客户端由模组占住：出哪一张由主机下发，
## 不能按自己本地的随机池抽（两端抽出来的不是同一张，客户端这一张就点不动了）。
var create_card_gate: Callable = Callable()

## 出现时停在的 y / 收起时滑到的 y
## 同时有常规卡槽时由控制器把出现位置下移一个卡槽的高度（卡槽在上、传送带在下）
var appear_pos_y := 0.0
var hide_pos_y := -100.0


#region 初始化

func _ready() -> void:
	_init_card_position_x()

## 初始化传送带卡片最终位置
func _init_card_position_x():
	for i in range(num_card_max):
		all_card_pos_x_target.append(0 + i * 50)
	Log.debug(str("传送带每张卡片的位置：") + str(all_card_pos_x_target))

## 管理器初始化调用
func init_card_slot_conveyor_belt(game_para:ResourceLevelData):
	Log.debug("传送带卡槽初始化随机卡片生成器")
	card_random_pool.init_card_random_pool(game_para.conveyor_weights)

	self.conveyor_order = game_para.conveyor_order
	self.create_new_card_speed = game_para.create_new_card_speed
	## 修改倍率；关卡资源把倍率填成 0 会让除法溢出（Timer.wait_time 拿到 inf），这里按 1 兜底
	if not is_finite(create_new_card_speed) or create_new_card_speed <= 0.0:
		Log.warn("传送带卡槽：出卡速度倍率 %s 非法，按 1 处理" % str(create_new_card_speed))
		create_new_card_speed = 1.0
	base_create_card_interval = create_new_card_cd / create_new_card_speed
	set_create_card_interval(base_create_card_interval)

	await get_tree().process_frame
	## 初始化后生成一个卡片
	_create_new_card()

#endregion

#region 出卡间隔

## 直接指定出卡间隔（秒），运行期随时可改；必须是正数，非法值只告警并忽略本次设置。[br]
## 计时中的计时器会按新间隔重开：Godot 改 wait_time 不会替已经跑起来的 Timer 重算流逝进度，
## 「卡已满停下等 signal_card_end」的那一段本来就没在计时，不受影响。
func set_create_card_interval(interval: float) -> void:
	if not is_finite(interval) or interval <= 0.0:
		Log.warn("传送带卡槽：出卡间隔必须是正数，收到 %s，本次设置已忽略" % str(interval))
		return
	create_new_card_cd = interval
	if not is_instance_valid(create_new_card_timer):
		return
	var is_timing: bool = not create_new_card_timer.is_stopped()
	create_new_card_timer.wait_time = create_new_card_cd
	if is_timing:
		create_new_card_timer.stop()
		create_new_card_timer.start()

## 按倍率调整出卡间隔：1 恢复关卡原始间隔，0.5 表示间隔减半（出卡速度翻倍）。[br]
## 基准取关卡初始化算出的原始间隔，所以反复调用同一个倍率不会叠加；
## 还没走过 init 的实例（编辑器直接跑场景）回退到当前 create_new_card_cd。
func set_create_card_interval_scale(interval_scale: float) -> void:
	if not is_finite(interval_scale) or interval_scale <= 0.0:
		Log.warn("传送带卡槽：出卡间隔倍率必须是正数，收到 %s，本次设置已忽略" % str(interval_scale))
		return
	create_card_interval_scale = interval_scale
	var base_interval: float = base_create_card_interval if base_create_card_interval > 0.0 else create_new_card_cd
	set_create_card_interval(base_interval * interval_scale)

#endregion

func _process(delta: float) -> void:
	if is_working:
		## 更新卡片位置
		for i in curr_cards.size():
			if curr_cards[i].position.x > all_card_pos_x_target[i]:
				curr_cards[i].position.x-= delta * conveyor_velocity
			elif curr_cards[i].position.x == all_card_pos_x_target[i]:
				continue
			else:
				curr_cards[i].position.x = all_card_pos_x_target[i]

#region 卡片生成相关
## 卡片种植完成后
func card_use_end(card:Card):
	curr_cards.erase(card)
	card.queue_free()
	signal_card_end.emit()

func _on_create_new_card_timer_timeout() -> void:
	_create_new_card() # Replace with function body.

## 重设抽取用的权重表（传送带控制器按规则算好之后推进来；可以随时改）
func set_card_weights(weights: Array[ResourceCardWeight]) -> void:
	if not is_instance_valid(card_random_pool):
		return
	card_random_pool.init_card_random_pool(weights)


## 生成一张新卡片
func _create_new_card():
	## 闸门：被占住时（联机客户端等主机下发）这一次直接不出
	if create_card_gate.is_valid() and not bool(create_card_gate.call()):
		return
	if curr_cards.size() >= num_card_max:
		create_new_card_timer.stop()
		await signal_card_end
		create_new_card_timer.start()
	## 出卡前先让控制器把权重按场上情况重算一遍（僵王战会按空花盆 / 带上花盆数调权重）
	signal_before_create_card.emit(all_num_card)
	## 关卡指定了这一张就照关卡的来（固定顺序），否则走随机池
	var card_reference := conveyor_order.get(all_num_card, null) as ResourceCardReference
	if card_reference == null:
		card_reference = card_random_pool.get_random_reference()
	spawn_card_by_reference(card_reference)


## 按指定身份出一张卡（通用槽位）：**不经过闸门**、也不走随机池
## —— 给"已经知道该出哪一张"的调用方（联机客户端照主机下发的那一张重建，见 NetplayCardSpawnSync）
func spawn_card_by_reference(card_reference: ResourceCardReference) -> Card:
	if card_reference == null:
		Log.error("传送带卡槽：第 %d 张卡片没有可用身份，本次生成已跳过" % all_num_card)
		return null
	var new_card_prefabs: Card = AllCards.get_template(card_reference)
	if new_card_prefabs == null:
		Log.error("传送带卡槽：第 %d 张卡片没有可用模板，本次生成已跳过" % all_num_card)
		return null
	var new_card := new_card_prefabs.duplicate() as Card
	## 副本默认与源卡共享身份资源,先换成独立引用
	new_card.make_reference_unique()
	new_card_area.add_child(new_card)
	new_card.card_init_conveyor_belt()
	new_card.position = Vector2(new_card_area.size.x, 0)
	curr_cards.append(new_card)
	new_card.signal_card_use_end.connect(card_use_end.bind(new_card))
	var card_bg: TextureRect = new_card.get_node("CardBg")
	card_bg.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED

	card_created.emit(card_reference, all_num_card)
	all_num_card += 1
	return new_card

#endregion

#region 传送带开始与结束
## 开始传送带
func start_conveyor_belt():
	is_working = true
	conveyor_belt_gear.start_gear()
	create_new_card_timer.start()

## 传送带出现时停在的 y（同时有常规卡槽时要下移一个卡槽的高度，见 ConveyorBeltController）
func set_appear_pos_y(pos_y: float) -> void:
	appear_pos_y = pos_y
	## 已经出现过的话当场生效（还没出现时移动动画会用到新值）
	if is_working:
		position.y = appear_pos_y


## 移动卡槽（出现或隐藏）
func move_card_slot_conveyor_belt(is_appeal:bool):
	var tween = create_tween()
	if is_appeal:
		tween.tween_property(self, "position:y", appear_pos_y, 0.2)

	else:
		tween.tween_property(self, "position:y", hide_pos_y, 0.2)
	await tween.finished

#endregion
