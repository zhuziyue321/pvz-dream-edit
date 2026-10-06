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
	var card_reference: ResourceCardReference = seed_rain_order.get(all_num_card, null)
	if card_reference == null:
		card_reference = card_random_pool.get_random_reference()
	if card_reference == null:
		Log.error("种子雨卡槽：第 %d 张卡片没有可用身份，本次生成已跳过" % all_num_card)
		return
	var temp_card_para:Dictionary = {}
	temp_card_para[CardManager.E_TempCardParaAttr.CardReference] = card_reference
	temp_card_para[CardManager.E_TempCardParaAttr.GlobalPos] = Vector2(randf_range(card_area_x_range.x, card_area_x_range.y),randf_range(card_area_y_range.x, card_area_y_range.y))
	temp_card_para[CardManager.E_TempCardParaAttr.ExistTime] = card_exist_time_norm
	var new_card = Global.main_game.card_manager.create_temp_card(temp_card_para)

	seed_rain_card_update(new_card)
	all_num_card += 1

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

