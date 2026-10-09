extends Control
class_name CardSlotRoot

## 卡片（常规卡槽那一组；快捷键从这里开始数）
var curr_cards:Array[Card]
## 第二组卡片（传送带）：同时有卡槽和传送带时，快捷键接在 curr_cards 后面
## （卡槽在上、传送带在下，数字键先数卡槽再数传送带）
var second_cards:Array[Card] = []
## 铲子
@onready var ui_shovel: UIShovel = %UIShovel

## 快捷键
@warning_ignore("unused_parameter")
func _unhandled_key_input(event: InputEvent) -> void:
	## 铲子快捷键
	if Input.is_action_just_pressed("ShortcutKeys_Shovel"):
		if ui_shovel.visible:
			ui_shovel._on_button_pressed()
		return
	## 卡片快捷键
	## （手套的 G 键不在本体里：手套是模组，快捷键由模组自己的卡槽按钮收，见 GloveMod）
	for i in range(1,11):
		## 卡片快捷键
		if Input.is_action_just_pressed("ShortcutKeys_Card" + str(int(i))):
			## 0-9
			var card: Card = _get_card_by_index(i - 1)
			if card == null:
				return
			card._on_button_pressed()


## 按下标取卡：先数常规卡槽，再数传送带（两组同时存在时传送带接在后面）
func _get_card_by_index(index:int) -> Card:
	if index >= 0 and index < curr_cards.size():
		return curr_cards[index]
	var second_index := index - curr_cards.size()
	if second_index >= 0 and second_index < second_cards.size():
		return second_cards[second_index]
	return null

