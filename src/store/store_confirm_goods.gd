extends Control
class_name ConfirmGoods
## 确认是否购买商品

@onready var pvz_button_yes: PVZButtonBase = $Panel/HBoxContainer/PVZButtonYes
@onready var pvz_button_no: PVZButtonBase = $Panel/HBoxContainer/PVZButtonNo

## 当前商品节点
var curr_goods_node:Goods

## 关闭时必发：商店用它恢复戴夫的挂机计时（原版弹窗期间 mWaitForDialog 冻结一切）
signal closed

func _ready() -> void:
	pvz_button_yes.pressed.connect(_on_pvz_button_yes_pressed)
	pvz_button_no.pressed.connect(_on_pvz_button_no_pressed)


## 出现该界面确认购买商品
func appear_canvas_layer(curr_goods:Goods):
	curr_goods_node = curr_goods
	visible = true


## 确认购买
func _on_pvz_button_yes_pressed() -> void:
	curr_goods_node.comfirm_get_this_goods()
	curr_goods_node = null
	visible = false
	closed.emit()

## 取消购买
func _on_pvz_button_no_pressed() -> void:
	curr_goods_node = null
	visible = false
	closed.emit()


## 外部关闭(ESC 键，见 StoreManager._unhandled_key_input)
func close() -> void:
	curr_goods_node = null
	visible = false
	closed.emit()
