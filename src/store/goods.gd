extends Control
class_name Goods
## 商品
@export_group("商品属性")
## 商品价格
@export var price :int = 0
## 是否还有该商品
@export var is_have_goods:bool = true
@onready var is_not_have_goods_label: Label = $VBoxContainer/PanelContainer/IsNotHaveGoodsLabel

## 价格标签
@onready var price_tag_label: Label = $VBoxContainer/PriceTag/Label
@onready var button: Button = $VBoxContainer/PanelContainer/Button

@export_group("戴夫交流相关")
## 该商品的戴夫对话细节描述
@export var dialog_detail:CrazyDaveDialogDetailResource
var curr_dialog_detail:CrazyDaveDialogDetailResource
var original_dialog_text :String

## 花园类商品在"花园还没解锁"时,戴夫对话的前缀提示
## 原版:蘑菇园 / 水族馆 / 智慧树 / 金盏花幼苗都属于 Zen Garden 段,
## 没有花园就没有这些东西的安放之处,与僵尸掉落花园植物用同一套口径
## (见 ConstUnlockLevel.GARDEN_UNLOCK_ADVENTURE_LEVEL)
const GARDEN_LOCK_TIP := "**通关冒险模式 %s 解锁花园后才能买这个**\n"

## 查看商品信号
signal look_goods_signal
## 取消查看商品信号
signal look_end_goods_signal
## 点击当前商品信号
signal signal_pressed_this_goods

func _ready() -> void:
	price_tag_label.text = "$" + GlobalUtils.format_number_with_commas(price)
	is_not_have_goods_label.visible = not is_have_goods
	curr_dialog_detail = dialog_detail.duplicate(true)
	judge_can_get_goods()
	## 连接金币改变信号
	Global.global_game_state.coin_value_changed.connect(func(_new_value: int): judge_can_get_goods())

## 判断是否卖的起,是否有商品
func judge_can_get_goods():
	## 如果当前金币买不起
	if Global.global_game_state.coin_value < price:
		curr_dialog_detail.text = "**你现在还卖不起这个商品**\n" + dialog_detail.text
		button.disabled = true
	else:
		curr_dialog_detail.text = dialog_detail.text
		button.disabled = false

	## 如果没有该商品
	if not is_have_goods:
		button.disabled = true

## 花园类商品统一的"花园未解锁"门槛
## 用法: 子类在 judge_can_get_goods() 里先 super.judge_can_get_goods() 再调这里
## 花园未解锁时禁用按钮并把戴夫提示换成"解锁花园后才能买",返回是否已解锁
func apply_garden_unlock_lock() -> bool:
	if Global.global_game_state.is_garden_unlocked():
		return true
	button.disabled = true
	curr_dialog_detail.text = GARDEN_LOCK_TIP % ConstUnlockLevel.get_adventure_level_name(
		ConstUnlockLevel.GARDEN_UNLOCK_ADVENTURE_LEVEL) + dialog_detail.text
	return false

## 鼠标进入
func _on_mouse_entered() -> void:
	look_goods_signal.emit(curr_dialog_detail)

## 鼠标移出
func _on_mouse_exited() -> void:
	look_end_goods_signal.emit()

## 点击商品
func _on_button_pressed() -> void:
	## 连接时将自身绑定了
	signal_pressed_this_goods.emit()

## 确认购买该商品
func comfirm_get_this_goods():
	## 已售罄(原版商店里除卡槽扩充外都是一次性商品)或买不起时都不扣钱
	## 正常情况下按钮已被禁用走不到这里,这里只是兜底,避免重复购买同一件商品
	if not is_have_goods:
		Log.debug("该商品已售罄，不应该出现该语句，因为按钮已经被禁用")
		return
	if Global.global_game_state.coin_value < price:
		Log.debug("买不起，不应该出现该语句，因为按钮已经被禁用")
		return
	else:
		Global.global_game_state.coin_value -= price
		get_one_goods()

## 获得该商品的作用，子类重写
func get_one_goods():
	pass
