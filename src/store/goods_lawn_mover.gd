extends Goods
class_name GoodsLawnMover
## 商店出售的水路小推车(泳池清洁车)与屋顶小推车(屋顶清洁车)
## 原版一代 PC:两者都在「防御道具」段出售,买一次即 Sold Out,之后所有泳池/屋顶关卡都自带该车
## 普通草坪小推车是免费配发的,不在商店出售(见 GIM_LawnMover.is_lane_can_have_mover)

## 当前商品对应的小推车类型(GIM_LawnMover.E_LawnMoverType.PoolCleaner / RoofCleaner)
@export var lawn_mover_type: GIM_LawnMover.E_LawnMoverType = GIM_LawnMover.E_LawnMoverType.PoolCleaner


func _ready() -> void:
	price = ConstShop.get_cleaner_price(lawn_mover_type)
	## 没有配置戴夫对话时,用一句默认话术兜底
	if dialog_detail == null:
		dialog_detail = _create_dialog_detail()
	super()
	_refresh_goods_state()
	judge_can_get_goods()


## 生成兜底的戴夫对话
## 数据来源: data/strings/lawn_strings.txt 的 CRAZY_DAVE_2026(池塘清洁车) / 2027(屋顶推车)
func _create_dialog_detail() -> CrazyDaveDialogDetailResource:
	var detail := CrazyDaveDialogDetailResource.new()
	match lawn_mover_type:
		GIM_LawnMover.E_LawnMoverType.PoolCleaner:
			detail.text = "这辆池塘清洁车，能用来提高池塘的防御等级！"
		GIM_LawnMover.E_LawnMoverType.RoofCleaner:
			detail.text = "这辆屋顶推车，能加强屋顶的防御等级！"
		_:
			detail.text = "这台小推车能保护你的草坪！"
	return detail


## 该清洁车当前是否已上架(需通关对应关卡,见 ConstShop.CLEANER_SHOP_LEVEL)
func is_on_sale() -> bool:
	return Global.global_game_state.get_max_success_adventure_level() \
		>= ConstShop.get_cleaner_shop_level(lawn_mover_type)


## 刷新商品状态:未上架则隐藏,已购买则标记为售罄且不可再购买
func _refresh_goods_state() -> void:
	if not is_on_sale():
		visible = false
		return
	visible = true
	if Global.global_game_state.is_lawn_mover_bought(lawn_mover_type):
		is_have_goods = false
		is_not_have_goods_label.text = "已拥有"
	is_not_have_goods_label.visible = not is_have_goods


## 获得该商品:购买一次小推车解锁
func get_one_goods():
	if Global.global_game_state.buy_lawn_mover(lawn_mover_type):
		Global.save_service.save_now()
		Log.debug(str("购买小推车,类型:") + str(int(lawn_mover_type)))
	else:
		Log.warn("购买小推车失败:该类型已购买或不需要购买")
	_refresh_goods_state()
	judge_can_get_goods()
