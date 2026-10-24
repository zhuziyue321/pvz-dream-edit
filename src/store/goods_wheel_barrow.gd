extends Goods
class_name GoodsWheelBarrow
## 商店出售的「独轮车」(Wheel Barrow)
##
## 原版一代 PC 口径(见 PvZ-Portable StoreScreen::IsComingSoon / GetItemCost / PurchaseItem):
##   · 摆在禅境花园页(ZEN2)第 3 格;
##   · **买了蘑菇园或水族馆之前是 Coming Soon**，两个都没有时只显示"即将推出"，买不了;
##   · 只要拥有了任一花园背景，它就可以花 $20 买下 —— 但买下什么都不发生
##     (原版 Zen Garden 没有实装"用独轮车搬花盆"，PurchaseItem 只是把 purchases 置 1 → Sold Out);
##   · 买完即 Sold Out，不能重复购买。
## 项目金币口径 ×10，故售价 $200(见 ConstShop.WHEEL_BARROW_PRICE)。


func _ready() -> void:
	price = ConstShop.WHEEL_BARROW_PRICE
	super()
	_refresh_goods_state()
	judge_can_get_goods()


## 是否已拥有任一商店出售的花园背景(蘑菇园 / 水族馆)
## 原版 IsComingSoon(WHEEL_BARROW) = 两个都没买
func has_garden_bg() -> bool:
	return Global.global_game_state.is_garden_bg_owned(GardenManager.E_GardenBgType.MushroomGraden) \
		or Global.global_game_state.is_garden_bg_owned(GardenManager.E_GardenBgType.Aquarium)


## 刷新商品状态:未拥有任何花园背景为 Coming Soon(不可买)；买过则售出
func _refresh_goods_state() -> void:
	if Global.global_game_state.is_wheel_barrow_owned():
		is_have_goods = false
	is_not_have_goods_label.visible = not is_have_goods


## 原版:没买蘑菇园 / 水族馆时 Coming Soon(红字提示 + 不可买)；买过则不可再买
func judge_can_get_goods() -> void:
	super.judge_can_get_goods()
	if not has_garden_bg():
		button.disabled = true
		curr_dialog_detail.text = COMING_SOON_TIP + (dialog_detail.text if dialog_detail != null else "")


## 获得该商品:原版只是把购买标记置 1，没有任何实际效果
func get_one_goods():
	if Global.global_game_state.buy_wheel_barrow():
		_finish_goods_granted()
	else:
		Log.warn("购买独轮车失败:已经买过")
		_finish_goods_granted(false)
