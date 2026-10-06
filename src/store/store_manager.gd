extends Control
class_name StoreManager

@onready var crazy_dave: CrazyDave = $CrazyDave
## 商店里戴夫说的话都在本场景 CrazyDave 节点的 dialog_resource 上(见 store.tscn),来源:
##   开场白: 原版拿到车钥匙后开张的两句 —— data/strings/lawn_strings.txt 的 CRAZY_DAVE_303 / 304
##   挂机时的随机台词: 原版"在商店里发呆戴夫会随机说这四句" —— CRAZY_DAVE_2015~2018
##   (原版口径见 PVZ Wiki Crazy Dave's Twiddydinkies 的 Trivia 段)
## 要改这两处文案,改 store.tscn 里的 dialog_detail_list / dialog_detail_long_time_idle_list
@export var all_goods :Array[Goods]
@onready var confirm_goods: ConfirmGoods = $ConfirmGoods

## 植物卡片(紫卡与模仿者)商品场景
const GOODS_PLANT_CARD_SCENE := preload("res://src/store/goods_plant_card.tscn")

## 货架的每一行(每行 ConstShop.SHOP_ROW_SLOT_NUM = 4 格,两行凑成一页 8 格)
## 页的分法见 pages: 第一页 = 道具行 + 第一批紫卡行;第二页 = 第二批紫卡行 + 模仿者行;
## 第三页 = 植物盆行(3 盆 + 黄金水壶) + 花园工具行(肥料 / 杀虫剂 / 留声机 / 园艺手套);
## 第四页 = 禅境花园行(蘑菇园 / 水族馆 / 蜗牛 / 智慧树) + 树肥料
@onready var row_tools: HBoxContainer = $Bg/Car2/Panel/RowTools
@onready var row_upgrade_first: HBoxContainer = $Bg/Car2/Panel/RowUpgradeFirst
@onready var row_upgrade_second: HBoxContainer = $Bg/Car2/Panel/RowUpgradeSecond
@onready var row_upgrade_third: HBoxContainer = $Bg/Car2/Panel/RowUpgradeThird
@onready var row_garden_sprout: HBoxContainer = $Bg/Car2/Panel/RowGardenSprout
@onready var row_garden_tools: HBoxContainer = $Bg/Car2/Panel/RowGardenTools
@onready var row_garden: HBoxContainer = $Bg/Car2/Panel/RowGarden
@onready var row_tree_food: HBoxContainer = $Bg/Car2/Panel/RowTreeFood

## 坚果包扎术:与模仿者同一行的静态商品(它不是植物卡片,不走 PLANT_CARD_ROWS 动态生成)
## 原版货架顺序是"模仿者 → 坚果包扎术",而模仿者商品是运行期生成、排在静态商品前面的,
## 所以生成完紫卡 / 模仿者商品后要把它挪到行尾(见 _ready)
@onready var goods_wall_nut_first_aid: Goods = $Bg/Car2/Panel/RowUpgradeThird/GoodsWallNutFirstAid

## 黄金水壶:排在第三页第一行的第 4 格(前三格是植物盆,盆是运行期复制出来的,见 _fill_sprout_slots)
@onready var goods_gold_watering_can: Goods = $Bg/Car2/Panel/RowGardenSprout/GoodsGoldWateringCan

## 翻页按钮(只有一页时隐藏)
@onready var prev_page_button: TextureButton = $Bg/Car2/PrevPageButton
@onready var next_page_button: TextureButton = $Bg/Car2/NextPageButton2

## 紫卡与模仿者的落位:下表第 i 项写在 plant_card_rows[i] 这一行,顺序即行内槽位顺序
## 上架关卡见 ConstPlantUnlock.PURPLE_CARD_CAN_BUY_LEVEL
const PLANT_CARD_ROWS: Array[Array] = [
	[CharacterRegistry.PlantType.P041GatlingPea,
	 CharacterRegistry.PlantType.P042TwinSunFlower,
	 CharacterRegistry.PlantType.P043GloomShroom,
	 CharacterRegistry.PlantType.P044Cattail,],		## 3-4 / 4-4 上架序(机枪、双子、忧郁菇、猫尾草)
	[CharacterRegistry.PlantType.P047SpikeRock,
	 CharacterRegistry.PlantType.P046GoldMagnet,
	 CharacterRegistry.PlantType.P045WinterMelon,
	 CharacterRegistry.PlantType.P048CobCannon,],	## 5-1 / 通关后上架序(地刺王、吸金磁、冰西瓜、玉米加农炮)
	[CharacterRegistry.PlantType.P999Imitater,],	## 模仿者;同行还有坚果包扎术,它不是植物卡片,直接摆在场景里(见 goods_wall_nut_first_aid)
]

## 每一页 = [第一行, 第二行];第二行暂缺时装 null(这一页就只摆一行)
var pages: Array[Array] = []
## 紫卡商品往哪一行塞(与 PLANT_CARD_ROWS 一一对应)
var plant_card_rows: Array[Control] = []
## 当前已上架的页(还没到上架关卡的页不存在,不参与翻页)
var valid_pages: Array[Array] = []
## 当前页在 valid_pages 中的下标
var curr_page := 0

## 离开商店页信号
signal siganl_exit_store

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.save_service.save_now()
	pages = [
		[row_tools, row_upgrade_first],		## 第一页: 道具 / 第一批紫卡
		[row_upgrade_second, row_upgrade_third],	## 第二页: 第二批紫卡 / 模仿者
		[row_garden_sprout, row_garden_tools],	## 第三页: 植物盆 + 黄金水壶 / 花园工具
		[row_garden, row_tree_food],		## 第四页: 蘑菇园 / 水族馆 / 蜗牛 / 智慧树 + 树肥料
	]
	plant_card_rows = [row_upgrade_first, row_upgrade_second, row_upgrade_third]
	_create_plant_card_goods()
	_fill_sprout_slots()
	## 原版货架顺序:模仿者在前、坚果包扎术在后(见 goods_wall_nut_first_aid 的注释)
	row_upgrade_third.move_child(goods_wall_nut_first_aid, -1)
	_refresh_valid_pages()
	_show_page(0)
	for goods in all_goods:
		goods.look_goods_signal.connect(crazy_dave.external_trigger_dialog)
		goods.look_end_goods_signal.connect(crazy_dave.external_trigger_dialog_end)
		## 确认购买页面
		goods.signal_pressed_this_goods.connect(confirm_goods.appear_canvas_layer.bind(goods))
	Log.debug(str("商店已扩展次数:") + str(Global.global_game_state.get_shop_expand_stage()))

## 生成商店出售的植物卡片商品(紫卡与模仿者),按 PLANT_CARD_ROWS 落到对应的行
func _create_plant_card_goods() -> void:
	for row_index in PLANT_CARD_ROWS.size():
		var row: Control = plant_card_rows[row_index]
		for plant_type in PLANT_CARD_ROWS[row_index]:
			var goods: GoodsPlantCard = GOODS_PLANT_CARD_SCENE.instantiate()
			goods.plant_type = plant_type as CharacterRegistry.PlantType
			row.add_child(goods)

## 植物盆摆满 3 个:原版货架前 3 格都是盆(金盏花幼苗每天限购 3 个,
## 见 ConstShop.MARIGOLD_SPROUT_DAILY_LIMIT),场景里只放了 1 个,剩下的直接复制补齐
## 每个盆按槽位序号各自判定"当天是否已买过"(见 GoodsGardenSrpout.slot_index),
## 所以复制时要给每个副本编上不同的槽位序号
## 复制出来的盆会排在黄金水壶后面,所以补完要把黄金水壶挪回行尾(第 4 格)
func _fill_sprout_slots() -> void:
	var sprout := row_garden_sprout.get_child(0) as GoodsGardenSrpout
	sprout.slot_index = 0
	var sprout_num := 1
	while sprout_num < ConstShop.MARIGOLD_SPROUT_DAILY_LIMIT:
		var new_sprout := sprout.duplicate() as GoodsGardenSrpout
		new_sprout.slot_index = sprout_num
		row_garden_sprout.add_child(new_sprout)
		sprout_num += 1
	row_garden_sprout.move_child(goods_gold_watering_can, -1)

## 重算已上架的页与商品清单:页数由 ConstShop.PAGE_SHOP_LEVEL 决定
func _refresh_valid_pages() -> void:
	valid_pages.clear()
	all_goods.clear()
	var max_level: int = Global.global_game_state.get_max_success_adventure_level()
	for page_index in pages.size():
		var rows: Array = pages[page_index]
		for row in rows:
			if row == null:
				continue
			for child in row.get_children():
				if child is Goods:
					all_goods.append(child)
		if max_level >= ConstShop.get_page_shop_level(page_index):
			valid_pages.append(rows)

## 当前页数
func get_page_num() -> int:
	return valid_pages.size()

## 切换商品页:一次翻一页(8 格 = 上下两行)
func _show_page(page:int) -> void:
	if valid_pages.is_empty():
		return
	curr_page = posmod(page, valid_pages.size())
	var curr_rows: Array = valid_pages[curr_page]
	for rows in pages:
		for row in rows:
			if row != null:
				row.visible = (rows == curr_rows)
	_update_page_button_visible()

## 只有一页时翻页按钮没意义,直接隐藏
func _update_page_button_visible() -> void:
	var is_multi_page: bool = valid_pages.size() > 1
	prev_page_button.visible = is_multi_page
	next_page_button.visible = is_multi_page

func _on_prev_page_button_pressed() -> void:
	_show_page(curr_page - 1)

func _on_next_page_button_pressed() -> void:
	_show_page(curr_page + 1)

## 离开商店
func _on_store_main_menu_button_pressed() -> void:
	siganl_exit_store.emit()
	Global.save_service.save_now()
	if get_tree().current_scene == self:
		GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])
	else:
		queue_free()
