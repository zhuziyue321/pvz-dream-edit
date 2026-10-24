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

## 原版商店的 "Coming Soon" 状态文案：商品已上架但暂不可买（未通关冒险的金盏花幼苗、
## 没买智慧树的树肥料、没买任一花园背景时的独轮车），戴夫提示"即将推出"
const COMING_SOON_TIP := "**敬请期待（还没到出售的时候）**\n"

## 商品在货架上是否可见（原版 IsItemUnavailable 的反面）
## 未上架的商品**不画，但格子留着** —— 用 modulate 透明 + 关掉鼠标，而不是 visible=false，
## 否则父级 HBoxContainer 会把后面的商品往左挤，与原版固定 8 格的"洞位"观感不符
var _is_on_shelf := true

## 请求商店弹一条消息（标题, 正文）。由 StoreManager 统一弹窗，商品自己不建 UI
signal request_message(title: String, body: String)
## 请求商店弹一个「是 / 否」确认（标题, 正文）。由 StoreManager 统一弹窗
signal request_confirm(title: String, body: String)
## 请求戴夫念一句台词（不弹窗，只走气泡，如原版买下坚果包扎术后的 CRAZY_DAVE_3400）
signal request_dave_text(text: String)

## 是否已通关冒险模式（首次完成 5-10）；原版 ZEN2 页与部分商品 Coming Soon 判定据此
static func is_adventure_finished() -> bool:
	return Global.global_game_state.get_max_success_adventure_level() >= ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL

## 查看商品信号
signal look_goods_signal
## 取消查看商品信号
signal look_end_goods_signal
## 点击当前商品信号
signal signal_pressed_this_goods

func _ready() -> void:
	price_tag_label.text = "$" + GlobalUtils.format_number_with_commas(price)
	is_not_have_goods_label.text = ConstShop.TEXT_SOLD_OUT
	is_not_have_goods_label.visible = not is_have_goods
	curr_dialog_detail = dialog_detail.duplicate(true)
	judge_can_get_goods()
	## 连接金币改变信号
	Global.global_game_state.coin_value_changed.connect(func(_new_value: int): judge_can_get_goods())

## 买得起吗（原版 CanAffordItem：点击时判，买不起走「金币不足」弹窗，不预先禁用按钮）
func can_afford() -> bool:
	return Global.global_game_state.coin_value >= price

## 判断是否卖的起,是否有商品
## 与原版一致：买不起**不禁用**按钮（点击后由 StoreManager 弹「金币不足」），
## 只有售罄 / 未上架 / 各类门槛才禁用
func judge_can_get_goods():
	button.disabled = not is_have_goods
	if not _is_on_shelf:
		button.disabled = true
	curr_dialog_detail.text = dialog_detail.text

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

## 该商品现在是否摆在货架上（原版 IsItemUnavailable 的反面）
## 没上架的商品 `visible` 仍是 true（保留格位），所以判定请用这个，不要看 visible
func is_on_shelf() -> bool:
	return _is_on_shelf


## 商品上架 / 下架：下架时**保留格子**（透明 + 按钮禁用），与原版"洞位"一致
## 只改根节点 mouse_filter（悬停提示挂在根上），不去动按钮内部节点的过滤 —— 按钮已经 disabled，
## 递归改子节点反而会把 Button 自己的内部 Label 变成拦截点击的节点
func set_goods_on_shelf(on_shelf: bool) -> void:
	_is_on_shelf = on_shelf
	modulate.a = 1.0 if on_shelf else 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP if on_shelf else Control.MOUSE_FILTER_IGNORE
	if on_shelf:
		judge_can_get_goods()
	else:
		button.disabled = true

## 鼠标进入：戴夫念该商品的台词 + 商品提亮（原版悬停高亮）
func _on_mouse_entered() -> void:
	self_modulate = Color(1.25, 1.25, 1.25)
	look_goods_signal.emit(curr_dialog_detail)

## 鼠标移出
func _on_mouse_exited() -> void:
	self_modulate = Color(1, 1, 1)
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
		return
	if Global.global_game_state.coin_value < price:
		return
	else:
		Global.global_game_state.coin_value -= price
		get_one_goods()

## 获得该商品的作用，**子类必须重写**
##
## 基类留空 = 漏重写就是「玩家付了钱拿不到东西」且零报错
## （`comfirm_get_this_goods()` 已经扣完钱才走到这里）。
## 约定：业务动作做完后调用 `_finish_goods_granted()` 收尾，
## 不要每个子类各写一遍「落盘 → 刷新售罄态 → 重判能否购买」。
func get_one_goods():
	pass


## 刷新售罄态（子类重写；基类留空，没有售罄概念的商品不需要）
func _refresh_goods_state() -> void:
	pass


## 购买收尾：成功则落盘，然后刷新售罄态并重新判定能否购买
## [param is_save] 购买成功传 true（默认）；失败分支传 false（失败没有新状态要存）
func _finish_goods_granted(is_save: bool = true) -> void:
	if is_save:
		Global.save_service.save_now()
	_refresh_goods_state()
	judge_can_get_goods()


## 递归设置鼠标过滤：Control 的 MOUSE_FILTER_IGNORE 只作用于自己，子节点要逐个设才不挡点击
## 参数名不叫 mouse_filter: Control 已有同名属性,同名会触发 SHADOWED_VARIABLE_BASE_CLASS 警告
## [param filter] 一般是 STOP(默认，商品可交互) / IGNORE(未上架，整件商品不接事件)
func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)
