extends Goods
class_name GoodsPlantCard
## 商店出售的植物卡片(紫卡与模仿者)
## 这些植物不会通过通关冒险模式直接解锁,只能等商店上架后花钱购买
## 上架关卡见 ConstPlantUnlock.PURPLE_CARD_CAN_BUY_LEVEL,售价见 ConstPlantUnlock.PURPLE_CARD_PRICE

## 售卖的植物类型(紫卡或模仿者)
@export var plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null

## 各商品的戴夫话术(鼠标移到商品上时戴夫念这一句)
## 数据来源: data/strings/lawn_strings.txt 的 CRAZY_DAVE_2000~2008
## 口径: 原版一代 PC;紫卡的话术是"种在某某植物上升级成某某"的用法说明,模仿者是 CRAZY_DAVE_2008
const PLANT_CARD_DIALOG_TEXT: Dictionary = {
	CharacterRegistry.PlantType.P041GatlingPea:
		"把这些种在你的双重射手上，把它变成机枪射手！机枪射手一次能射出4颗豌豆！",
	CharacterRegistry.PlantType.P042TwinSunFlower:
		"把这些种在你的向日葵上，把它变成双胞向日葵！双胞向日葵提供的阳光是向日葵的2倍！",
	CharacterRegistry.PlantType.P043GloomShroom:
		"把这些种在你的大喷菇上，把它变成多嘴小蘑菇！它能在小范围内做迅速的攻击！",
	CharacterRegistry.PlantType.P044Cattail:
		"把这些种在你的莲叶上，把它变成猫尾草！猫尾草能攻击任何一条线路，而且能打下气球僵尸！",
	CharacterRegistry.PlantType.P045WinterMelon:
		"把这些种在你的西瓜投手上，把它变成冰西瓜！冰西瓜有很高的攻击力，而且能让被击中的僵尸慢下来！",
	CharacterRegistry.PlantType.P046GoldMagnet:
		"把这些种在你的磁力菇上，把它变成吸金菇！吸金菇会帮助你收集金币和钻石！",
	CharacterRegistry.PlantType.P047SpikeRock:
		"把这些种在你的地刺上，把它变成钢地刺！钢地刺有着2倍的攻击力，且非常耐用！",
	CharacterRegistry.PlantType.P048CobCannon:
		"把这些种在你的玉米投手上，把它变成玉米加农炮！点击一个玉米加农炮，发动致命的攻击！",
	CharacterRegistry.PlantType.P999Imitater:
		"这个变身茄子让你在游戏中拥有两个相同的植物！",
}

## 话术表里没有的植物(理论上不会走到)退回用植物名拼一句
const TEXT_PLANT_FALLBACK := "这是%s，带上它准没错！"

## 种子包样式的商品图标:直接复制出战卡槽那张 Card 场景(底图 + 植物静态形象 + 阳光花费),
## 与卡槽 / 掉落种子包同一套渲染,不再手工拼底图和花费文字
## 卡片本身 50x70,容器已按 67x68 的商品格居中
@onready var seed_packet_icon: Control = $SeedPacketIcon


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


## 生成该植物对应的戴夫对话:优先用原版话术表里的那一句
func _create_dialog_detail() -> CrazyDaveDialogDetailResource:
	var detail := CrazyDaveDialogDetailResource.new()
	detail.text = str(PLANT_CARD_DIALOG_TEXT.get(plant_type, ""))
	if detail.text.is_empty():
		var plant_name: String = Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)
		detail.text = TEXT_PLANT_FALLBACK % plant_name
	return detail


## 生成种子包样式的商品图标:整张卡片当图标,与出战卡槽里看到的完全一致
func _create_icon() -> void:
	var card := _get_card_prefab()
	if card == null:
		return
	var icon_card: Card = card.duplicate()
	seed_packet_icon.add_child(icon_card)
	icon_card.position = Vector2.ZERO
	## 图标只作展示:卡片内部的 Button / Cost 会吃掉鼠标事件挡住商品按钮,整棵子树都不接事件
	_set_mouse_filter_recursive(icon_card, Control.MOUSE_FILTER_IGNORE)
	## 没有阳光花费的植物(如模仿者)不显示花费文本
	icon_card.cost.visible = icon_card.sun_cost > 0


## 递归设置鼠标过滤:Control 的 MOUSE_FILTER_IGNORE 只作用于自己,子节点要逐个设才不挡点击
## 参数名不叫 mouse_filter: Control 已有同名属性,同名会触发 SHADOWED_VARIABLE_BASE_CLASS 警告
func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)


## 取该植物对应的卡片 prefab
## 模仿者不在 AllCards 的选卡字典里(原因见 AllCards.imitater_card 的注释),单独取它的卡片
func _get_card_prefab() -> Card:
	var card: Card = AllCards.all_plant_card_prefabs.get(plant_type)
	if card != null:
		return card
	if plant_type == CharacterRegistry.PlantType.P999Imitater:
		return AllCards.imitater_card
	return null


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
