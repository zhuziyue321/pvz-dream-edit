extends Control
class_name StoreManager

@onready var crazy_dave: CrazyDave = $CrazyDave
@export var all_goods :Array[Goods]
@onready var confirm_goods: ConfirmGoods = $ConfirmGoods

## 植物卡片(紫卡与模仿者)商品场景
const GOODS_PLANT_CARD_SCENE := preload("res://scenes/store/goods_plant_card.tscn")
## 植物卡片商品挂载的父节点
@onready var plant_card_goods_container: GridContainer = $Bg/Car2/Panel/PlantCardGoodsContainer
## 花园商品页的节点
@onready var all_garden_goods_parent: Array[Node] = [
	$Bg/Car2/Panel/HBoxContainer,
	$Bg/Car2/Panel/HBoxContainer2,
]

## 当前商品页:0 = 花园商品,1 = 植物卡片
var curr_page := 0

## 离开商店页信号
signal siganl_exit_store

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.save_service.save_now()
	_create_plant_card_goods()
	_show_page(0)
	for goods in all_goods:
		goods.look_goods_signal.connect(crazy_dave.external_trigger_dialog)
		goods.look_end_goods_signal.connect(crazy_dave.external_trigger_dialog_end)
		## 确认购买页面
		goods.signal_pressed_this_goods.connect(confirm_goods.appear_canvas_layer.bind(goods))
	Log.debug(str("商店已扩展次数:") + str(Global.global_game_state.get_shop_expand_stage()))

## 生成商店出售的植物卡片商品(紫卡与模仿者)
func _create_plant_card_goods() -> void:
	for plant_type in ConstPlantUnlock.get_all_shop_plant_types():
		var goods: GoodsPlantCard = GOODS_PLANT_CARD_SCENE.instantiate()
		goods.plant_type = plant_type
		plant_card_goods_container.add_child(goods)
		all_goods.append(goods)

## 切换商品页
func _show_page(page:int) -> void:
	curr_page = posmod(page, 2)
	var is_garden_page := curr_page == 0
	for node in all_garden_goods_parent:
		node.visible = is_garden_page
	plant_card_goods_container.visible = not is_garden_page

func _on_prev_page_button_pressed() -> void:
	_show_page(curr_page - 1)

func _on_next_page_button_pressed() -> void:
	_show_page(curr_page + 1)

## 离开商店
func _on_store_main_menu_button_pressed() -> void:
	siganl_exit_store.emit()
	Global.save_service.save_now()
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])
	else:
		queue_free()

