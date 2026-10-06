extends Goods
class_name GoodsWallNutFirstAid
## 商店出售的坚果包扎术(Wall-nut First Aid)
## 原版: $2000 买断,永久生效 —— 关卡里手持坚果 / 高坚果 / 南瓜头卡片,
## 直接补种在"已经掉手或裂开"的同种植物上,不用先铲掉旧的(见 PlantCell.get_first_aid_plant)
## 售价 ConstShop.WALL_NUT_FIRST_AID_PRICE;上架条件: 通关冒险模式(与模仿者同一页)


func _ready() -> void:
	price = ConstShop.WALL_NUT_FIRST_AID_PRICE
	## 没有配置戴夫对话时,用一句默认话术兜底
	if dialog_detail == null:
		dialog_detail = _create_dialog_detail()
	super()
	_refresh_goods_state()
	judge_can_get_goods()


## 刷新商品状态:没通关冒险模式不上架,买过就是"已拥有"(原版一次性买断)
func _refresh_goods_state() -> void:
	visible = is_on_sale()
	if Global.global_game_state.is_wall_nut_first_aid_owned():
		is_have_goods = false
		is_not_have_goods_label.text = "已拥有"
	is_not_have_goods_label.visible = not is_have_goods


## 是否已上架:原版通关冒险模式后才卖(5-10,见 ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL),
## 与模仿者摆在同一行,比这一页的紫卡晚
func is_on_sale() -> bool:
	return Global.global_game_state.get_max_success_adventure_level() \
		>= ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL


## 生成兜底的戴夫对话(原版 CRAZY_DAVE_2033,见 data/strings/lawn_strings.txt)
func _create_dialog_detail() -> CrazyDaveDialogDetailResource:
	var detail := CrazyDaveDialogDetailResource.new()
	detail.text = "坚果愈合术可以让你受伤的坚果焕然一新，对高坚果和南瓜头同样有效！"
	return detail


## 获得该商品:买断坚果包扎术
func get_one_goods():
	if Global.global_game_state.buy_wall_nut_first_aid():
		Global.save_service.save_now()
		Log.debug("购买坚果包扎术")
	else:
		Log.warn("购买坚果包扎术失败:已经买过")
	_refresh_goods_state()
	judge_can_get_goods()
