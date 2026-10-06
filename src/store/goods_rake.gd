extends Goods
class_name GoodsRake
## 商店出售的钉耙(Garden Rake)
##
## 原版一代 PC: 钉耙在「防御道具」段出售,$200 买一次管三关(lasts for three levels),
## 用完(三关打完)才能再买;关卡开局自动放一把到草坪上,踩到的僵尸吃 1800 点伤害。
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Garden_Rake)


func _ready() -> void:
	price = ConstShop.RAKE_PRICE
	## 没有配置戴夫对话时,用一句默认话术兜底
	if dialog_detail == null:
		dialog_detail = _create_dialog_detail()
	super()
	_refresh_goods_state()
	judge_can_get_goods()


## 生成兜底的戴夫对话(原版 CRAZY_DAVE_2028,见 data/strings/lawn_strings.txt;
## 原版把 Garden Rake 译作"干草叉",本仓库的商品名是钉耙)
func _create_dialog_detail() -> CrazyDaveDialogDetailResource:
	var detail := CrazyDaveDialogDetailResource.new()
	detail.text = "这把干草叉能击倒最快碰到它的那只僵尸！可以使用三关！"
	return detail


## 刷新商品状态:手上还有钉耙(剩余关数 > 0)时不可再买,三关用完后自动恢复出售
func _refresh_goods_state() -> void:
	is_have_goods = not Global.global_game_state.is_rake_owned()
	if not is_have_goods:
		is_not_have_goods_label.text = "已拥有"
	is_not_have_goods_label.visible = not is_have_goods


## 获得该商品:买一次钉耙,可用关数置为 ConstShop.RAKE_USE_NUM_PER_BUY
func get_one_goods():
	if Global.global_game_state.buy_rake():
		Global.save_service.save_now()
		Log.debug(str("购买钉耙,可用关数:") + str(Global.global_game_state.get_rake_use_num()))
	else:
		Log.warn("购买钉耙失败:手上还有钉耙没用完")
	_refresh_goods_state()
	judge_can_get_goods()
