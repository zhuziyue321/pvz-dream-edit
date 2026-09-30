extends Goods
class_name GoodsPlantCard
## 商店出售的植物卡片(紫卡与模仿者)
## 这些植物不会通过通关冒险模式直接解锁,只能等商店上架后花钱购买
## 上架关卡见 ConstPlantUnlock.PURPLE_CARD_CAN_BUY_LEVEL,售价见 ConstPlantUnlock.PURPLE_CARD_PRICE

## 售卖的植物类型(紫卡或模仿者)
@export var plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null


func _ready() -> void:
	price = ConstPlantUnlock.get_shop_plant_price(plant_type)
	## 没有配置戴夫对话时,用植物名自动生成一句
	if dialog_detail == null:
		dialog_detail = _create_dialog_detail()
	super()
	_refresh_goods_state()
	judge_can_get_goods()
	_create_icon()


## 该商品当前是否上架(需通关对应关卡)
func is_on_sale() -> bool:
	if plant_type == CharacterRegistry.PlantType.Null:
		return false
	if not ConstPlantUnlock.is_shop_plant(plant_type):
		return false
	return Global.global_game_state.is_purple_card_can_buy(plant_type)


## 刷新商品状态:未上架则隐藏,已拥有则标记为已拥有且不可再购买
func _refresh_goods_state() -> void:
	if not is_on_sale():
		visible = false
		return
	visible = true
	if Global.global_game_state.is_plant_unlocked(plant_type):
		is_have_goods = false
		is_not_have_goods_label.text = "已拥有"
	is_not_have_goods_label.visible = not is_have_goods


## 生成该植物对应的戴夫对话
func _create_dialog_detail() -> CrazyDaveDialogDetailResource:
	var plant_name: String = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)
	var detail := CrazyDaveDialogDetailResource.new()
	detail.text = str("这是") + plant_name + str("，带上它准没错！")
	return detail


## 生成植物图标(复用植物卡片的静态形象)
func _create_icon() -> void:
	var card: Card = AllCards.all_plant_card_prefabs.get(plant_type)
	if card == null or not is_instance_valid(card.character_static):
		return
	var icon: Node2D = card.character_static.duplicate()
	icon.position = Vector2(33, 34)
	add_child(icon)
	icon.z_index = -1


## 获得该商品:解锁该植物
func get_one_goods():
	if Global.global_game_state.unlock_plant(plant_type):
		Global.save_service.save_now()
		Log.debug(str("购买植物卡片:") + str(Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)))
	else:
		Log.warn("购买植物卡片失败:该植物已经拥有")
	_refresh_goods_state()
	judge_can_get_goods()
