extends Goods
class_name GoodsGardenSrpout

## 本商品在植物盆行里的槽位序号(0 ~ ConstShop.MARIGOLD_SPROUT_DAILY_LIMIT - 1)
## 每个盆槽位当天只能买一次,各槽位独立按序号记录购买日期
## (见 ConstShop.MARIGOLD_SPROUT_SLOT_BUY_DATE_KEY),序号由 StoreManager._fill_sprout_slots 编好
@export var slot_index: int = 0

## 本槽位当天已买过时的戴夫对话前缀提示(每个盆槽位一天只能买一次)
const DAILY_LIMIT_TIP := "**这个今天已经卖掉了，明天再来吧**\n"
## 花园满了时的戴夫对话前缀提示(原版: "Not available if the Zen Garden is full")
const GARDEN_FULL_TIP := "**花园已经满了，卖掉几株再来买**\n"


func _ready() -> void:
	price = ConstShop.MARIGOLD_SPROUT_PRICE
	super()


## 花园未解锁(未通关冒险 5-5)时不可购买,与僵尸掉落花园植物同一套口径
## (见 ConstUnlockLevel.GARDEN_UNLOCK_ADVENTURE_LEVEL)
## 每个盆槽位当天买过一次后即售罄,跨自然日重置;且花园没有空位时不卖(卖掉植物后才恢复)
func judge_can_get_goods():
	## 植物盆不是一次性商品,售罄态只跟着"本槽位当天是否买过"走,所以要双向刷新
	var is_sold_out_today := is_bought_today()
	is_have_goods = not is_sold_out_today
	is_not_have_goods_label.visible = is_sold_out_today
	super.judge_can_get_goods()
	if is_sold_out_today:
		curr_dialog_detail.text = DAILY_LIMIT_TIP + dialog_detail.text
		return
	if not apply_garden_unlock_lock():
		return
	if not Global.global_game_state.has_empty_garden_cell():
		button.disabled = true
		curr_dialog_detail.text = GARDEN_FULL_TIP + dialog_detail.text
		return


## 本槽位今天是否已经买过(存档里记录的日期不是今天则视为没买过)
func is_bought_today() -> bool:
	var slot_buy_date := get_slot_buy_date_dict()
	return str(slot_buy_date.get(str(slot_index), "")) == GlobalUtils.get_today_date_string()


## garden_data 里"每个盆槽位最近一次购买的日期"字典(键为槽位序号字符串,值为日期字符串)
## 存档里没有这个字典(老存档 / 首次购买)时返回空字典
func get_slot_buy_date_dict() -> Dictionary:
	var garden_data: Dictionary = Global.global_game_state.garden_data
	var slot_buy_date: Variant = garden_data.get(ConstShop.MARIGOLD_SPROUT_SLOT_BUY_DATE_KEY)
	if slot_buy_date is Dictionary:
		return slot_buy_date as Dictionary
	return {}


## 获得该商品的作用，子类重写
func get_one_goods():
	Global.global_game_state.curr_num_new_garden_plant += 1
	## 记录本槽位当天的购买日期,用于"每个盆一天只能买一次"的限购
	var garden_data: Dictionary = Global.global_game_state.garden_data
	var slot_buy_date := get_slot_buy_date_dict()
	slot_buy_date[str(slot_index)] = GlobalUtils.get_today_date_string()
	garden_data[ConstShop.MARIGOLD_SPROUT_SLOT_BUY_DATE_KEY] = slot_buy_date
	Global.save_service.save_now()
	judge_can_get_goods()
