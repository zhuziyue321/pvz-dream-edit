extends Control
class_name CardSlotSeedRain

@onready var card_random_pool: CardRandomPool = $CardRandomPool
@onready var create_new_card_timer: Timer = $CreateNewCardTimer

## 卡片范围
@export var card_area_x_range:Vector2 = Vector2(100,700)
@export var card_area_y_range:Vector2 = Vector2(100,500)
## 按顺序出现的卡片身份;键为生成序号,未指定的序号走随机池
@export var seed_rain_order:Dictionary[int, ResourceCardReference] = {}
## 创建卡片的时间
@export var card_create_cd_range:Vector2 = Vector2(3,5)
## 卡片正常存在时间,存在时间结束后闪烁5秒后消失
@export var card_exist_time_norm:float = 10.0
## 当前生成的卡片总数量
var all_num_card :int = 0
## 本机掉了一张卡（参数：这一张的身份 + 生成序号）—— 通用观测口，
## 谁想"知道刚掉了哪一张"就连它（联机的主机据此把这一张连落点一起下发下去）
signal card_created(reference:ResourceCardReference, index:int)

## 出卡闸门（通用问询口，不带联机字样）：返回 false = 这一次不许本地掉卡
##
## 默认恒为空 Callable（照旧掉）。联机客户端由模组占住：掉哪一张、掉在哪儿由主机下发
## （两端的随机池与落点都是各跑各的，抽出来的不是同一张，客户端这一张就点不动了）。
var create_card_gate: Callable = Callable()

## 管理器初始化调用
func init_card_slot_seed_rain(game_para:ResourceLevelData):
	Log.debug("种子雨卡槽初始化随机卡片生成器")
	card_random_pool.init_card_random_pool(game_para.seed_rain_weights)

	self.seed_rain_order = game_para.seed_rain_order

func _on_create_new_card_timer_timeout() -> void:
	_create_new_card()
	create_new_card_timer.start(randf_range(card_create_cd_range.x, card_create_cd_range.y))

## 生成一张新卡片
func _create_new_card():
	## 闸门：被占住时（联机客户端等主机下发）这一次直接不掉
	if create_card_gate.is_valid() and not bool(create_card_gate.call()):
		return
	var card_reference: ResourceCardReference = seed_rain_order.get(all_num_card, null)
	if card_reference == null:
		card_reference = card_random_pool.get_random_reference()
	## 落点也是随机的：主机摇好之后跟这一张一起下发，两端才掉在同一个地方
	var pos := Vector2(
		randf_range(card_area_x_range.x, card_area_x_range.y),
		randf_range(card_area_y_range.x, card_area_y_range.y)
	)
	spawn_card_by_reference(card_reference, pos)


## 按指定身份 + 指定落点掉一张卡（通用槽位）：**不经过闸门**、也不走随机池
## —— 给"已经知道该掉哪一张、掉在哪儿"的调用方（联机客户端照主机下发的那一张重建）
func spawn_card_by_reference(card_reference: ResourceCardReference, pos: Vector2) -> Card:
	if card_reference == null:
		Log.error("种子雨卡槽：第 %d 张卡片没有可用身份，本次生成已跳过" % all_num_card)
		return null
	var temp_card_para:Dictionary = {}
	temp_card_para[CardManager.E_TempCardParaAttr.CardReference] = card_reference
	temp_card_para[CardManager.E_TempCardParaAttr.GlobalPos] = pos
	temp_card_para[CardManager.E_TempCardParaAttr.ExistTime] = card_exist_time_norm
	var new_card := GameContext.curr_main_game.card_manager.create_temp_card(temp_card_para) as Card

	seed_rain_card_update(new_card)
	card_created.emit(card_reference, all_num_card)
	all_num_card += 1
	return new_card

## 种子雨卡片更新: 缓慢下落,时间限制
func seed_rain_card_update(seed_rain_card:Card):
	var tween:Tween = seed_rain_card.create_tween()
	tween.tween_property(seed_rain_card, ^"position:y", seed_rain_card.position.y+30, 1.0)

## 开始种子雨
func start_seed_rain():
	if create_new_card_timer.paused:
		create_new_card_timer.paused = false
	if create_new_card_timer.is_stopped():
		create_new_card_timer.start(randf_range(card_create_cd_range.x, card_create_cd_range.y))

func pause_seed_rain():
	create_new_card_timer.paused = true

