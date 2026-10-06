extends ResourceLevelTimelineEvent
class_name LevelTimelineEventWaitTakeCard
## 等玩家把一张卡捡到手上（点了卡槽 / 传送带上的某张卡）
##
## plant_type 留 Null = 捡哪张都算；写上就是「非这张不可」（原版 1-1：捡起豌豆射手的种子包）。
## **玩家手上已经有这张卡时立刻往下走**，不该逼玩家白捡一次。
##
## 判定靠 EventBus "hand_card_take"（拿卡是瞬间动作，按帧轮询会漏）：
## 玩家点了卡 → HandComponentCharacter 推事件 → 本事件立刻放行。

## 指定要捡的植物；留 Null 表示任意卡
@export var plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null

var _is_taken := false


func run(main_game: MainGameManager) -> void:
	_is_taken = false
	if LevelWaitCondition.is_holding_card(main_game, plant_type):
		return
	EventBus.subscribe("hand_card_take", _on_hand_card_take)
	await wait_until(main_game, func(): return _is_taken)
	EventBus.unsubscribe("hand_card_take", _on_hand_card_take)


func _on_hand_card_take(card: Card) -> void:
	if plant_type != CharacterRegistry.PlantType.Null \
			and (card == null or card.card_plant_type != plant_type):
		return
	_is_taken = true
