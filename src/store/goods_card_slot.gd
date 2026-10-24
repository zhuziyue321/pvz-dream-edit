extends Goods
class_name GoodsCardSlot
## 商店出售的卡槽扩充(种子包扩充)
## 每购买一次,存档的出战卡槽数 +1,直到 ConstShop.MAX_CARD_SLOT_NUM
## 出战卡槽数一律取存档值(见 GlobalGameState.get_card_slot_num);
## 关卡资源写了非 0 的 max_choosed_card_num 时覆盖存档值,这类关卡不受购买影响
## 见 ResourceLevelData.get_max_choosed_card_num()
## 售价按已购买次数分档(原版 750 / 5000 / 20000 / 80000),与 2-2 开场戴夫推销共用
## ConstShop.CARD_SLOT_UPGRADE_PRICES

## 卡槽扩充的戴夫话术模板:目标卡槽数
## 原版每一档各一句(7 / 8 / 9 / 10 槽),见 data/strings/lawn_strings.txt 的 CRAZY_DAVE_2011~2014;
## 买哪一档就念哪一句,只能运行期生成,场景里配的静态台词不适用
const TEXT_CARD_SLOT := "增加的卡片槽，将让你在每关可选%d种植物！"

## 商品图标上的槽数文字(原版 [STORE_UPGRADE_SLOTS] "{SLOTS}\n卡片槽"，见 lawn_strings.txt)
const TEXT_SLOT_ON_ICON := "%d\n卡片槽"

## 商品图标上的槽数文字节点(场景里配在 StoreIcon 上；没有这个节点时只跳过文字)
@onready var slot_count_label: Label = get_node_or_null("SlotCountLabel") as Label


func _ready() -> void:
	dialog_detail = _create_dialog_detail()
	super()
	_refresh_goods_state()
	judge_can_get_goods()


## 刷新商品状态:按当前已购买次数取价,已达卡槽上限则标记为已售出且不可再购买
func _refresh_goods_state() -> void:
	price = maxi(0, ConstShop.get_card_slot_upgrade_price(Global.global_game_state.get_card_slot_upgrade_num()))
	price_tag_label.text = "$" + GlobalUtils.format_number_with_commas(price)
	if Global.global_game_state.is_card_slot_upgrade_max():
		is_have_goods = false
	else:
		is_have_goods = true
	is_not_have_goods_label.visible = not is_have_goods
	_update_slot_count_label()


## 刷新图标上的槽数:原版画的是"买下之后能有几个槽"(purchases + 7)
func _update_slot_count_label() -> void:
	if slot_count_label == null:
		return
	var next_slot_num: int = mini(Global.global_game_state.get_card_slot_num() + 1,
		ConstShop.MAX_CARD_SLOT_NUM)
	slot_count_label.text = TEXT_SLOT_ON_ICON % next_slot_num


## 生成当前档位的戴夫对话:目标是"买到第几个卡槽"
## 已满级时不再往上加,免得念出 11 槽(原版满级只显示 Sold Out)
func _create_dialog_detail() -> CrazyDaveDialogDetailResource:
	var next_slot_num: int = mini(Global.global_game_state.get_card_slot_num() + 1,
		ConstShop.MAX_CARD_SLOT_NUM)
	var detail := CrazyDaveDialogDetailResource.new()
	detail.text = TEXT_CARD_SLOT % next_slot_num
	return detail


## 获得该商品:购买一次卡槽扩充
## 注意：这里**不用**基类 `_finish_goods_granted()` —— 收尾中间要重建戴夫台词（档位变了），
## 顺序是「落盘 → 刷新售罄态 → 换台词 → 重判能否购买」，插不进那个模板。
func get_one_goods():
	var is_success: bool = Global.global_game_state.add_card_slot_upgrade()
	if is_success:
		Global.save_service.save_now()
	else:
		Log.warn("购买卡槽扩充失败:已达卡槽上限")
	_refresh_goods_state()
	## 档位变了,台词跟着换到下一档(7 槽 -> 8 槽),再刷买得起买不起
	dialog_detail = _create_dialog_detail()
	judge_can_get_goods()
	## 原版买完弹「更多卡片槽！」(MORE_SLOTS / NOW_YOU_CAN_CHOOSE_X_SEEDS)
	if is_success:
		request_message.emit("更多卡片槽！",
			"现在你可以在每个关卡选择%d植物种子了！" % Global.global_game_state.get_card_slot_num())
