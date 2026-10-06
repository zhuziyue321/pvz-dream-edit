extends Goods
class_name GoodsGardenBg
## 商店出售的禅境花园背景(蘑菇园 / 水族馆)
## 原版一代 PC:这类商品买一次即 Sold Out,不能重复购买
## (见 ConstShop.GARDEN_BG_PRICE 的来源注释)
## 阳光房(GreenHouse)是玩家默认就有的花园,原版商店不出售,已从商店移除
##
## 语义:购买 = 解锁该背景(页数 0 -> 1),不是"给已有背景再加一页"。
## 未拥有时花园里根本不出现该背景(见 GardenManager._on_next_pressed 跳过未拥有背景),
## 这样 $30000 才是真的"买到"了蘑菇园 / 水族馆。

## 当前商品的背景
@export var curr_goods_garden_bg :GardenManager.E_GardenBgType


func _ready() -> void:
	price = ConstShop.get_garden_bg_price(curr_goods_garden_bg)
	super()
	_refresh_goods_state()
	judge_can_get_goods()


## 花园未解锁时不可购买,与金盏花幼苗同一套口径(见 Goods.apply_garden_unlock_lock)
func judge_can_get_goods():
	super.judge_can_get_goods()
	apply_garden_unlock_lock()


## 刷新商品状态:已拥有该背景则标记为售罄且不可再购买
func _refresh_goods_state() -> void:
	if Global.global_game_state.is_garden_bg_owned(curr_goods_garden_bg):
		is_have_goods = false
	is_not_have_goods_label.visible = not is_have_goods


## 获得该商品:解锁该花园背景
func get_one_goods():
	if Global.global_game_state.buy_garden_bg(curr_goods_garden_bg):
		Global.save_service.save_now()
		Log.debug(str("购买花园背景,当前页数:") + str(
			Global.global_game_state.get_garden_bg_page_num(curr_goods_garden_bg)))
	else:
		Log.warn("购买花园背景失败:该背景已拥有")
	_refresh_goods_state()
	judge_can_get_goods()
