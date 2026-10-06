extends Goods
class_name GoodsGardenTree
## 商店出售的智慧树(原版售价见 ConstShop.TREE_OF_WISDOM_PRICE)
## 原版一代 PC:买一次即 Sold Out,不能重复购买
## (见 ConstShop.GARDEN_BG_PRICE 上方的来源注释)
## 买下后花园里多出"智慧树"这一页(水族馆往后翻一页),并拿到戴夫白送的几袋树肥料:
## 见 GlobalGameState.buy_tree_of_wisdom 与 src/garden/bg_03_tree_of_wisdom.tscn


func _ready() -> void:
	price = ConstShop.TREE_OF_WISDOM_PRICE
	super()
	_refresh_goods_state()
	judge_can_get_goods()


## 智慧树是否已购买过
func is_bought() -> bool:
	return Global.global_game_state.is_tree_of_wisdom_bought()


## 花园未解锁时不可购买,与金盏花幼苗 / 蘑菇园 / 水族馆同一套口径
## (见 Goods.apply_garden_unlock_lock)
func judge_can_get_goods():
	super.judge_can_get_goods()
	apply_garden_unlock_lock()


## 刷新商品状态:已购买则标记为售罄且不可再购买
func _refresh_goods_state() -> void:
	if is_bought():
		is_have_goods = false
	is_not_have_goods_label.visible = not is_have_goods


## 获得该商品的作用，子类重写
## 买下后:解锁花园里的智慧树页 + 拿到戴夫白送的树肥料(见 ConstTreeOfWisdom.TREE_FOOD_START_NUM)
func get_one_goods():
	Global.global_game_state.buy_tree_of_wisdom()
	Global.save_service.save_now()
	Log.debug("购买智慧树,戴夫送了 %d 袋树肥料" % ConstTreeOfWisdom.TREE_FOOD_START_NUM)
	_refresh_goods_state()
	judge_can_get_goods()
