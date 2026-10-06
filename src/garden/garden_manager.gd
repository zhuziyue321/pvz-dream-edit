extends Node2D
class_name GardenManager

@export var bgm:AudioStream

## 花园背景种类
enum E_GardenBgType{
	GreenHouse,		## 阳光房
	MushroomGraden,	## 蘑菇花园
	Aquarium,		## 水族馆
	TreeBg,			## 智慧树(商店买断后才拥有,原版是"从水族馆再往后翻一页",见 ConstTreeOfWisdom)
}
## 植物成长状态
enum E_GrowthStage {
	Sprout,
	Small,
	Medium,
	Large,
	Perfect,		## 当前植物处于完美状态
}
## 需要的物品
enum E_NeedItem{
	Null,			## 不需要
	WateringCan,	## 水壶
	Fertilizer,		## 肥料
	BugSpray,		## 杀虫剂
	Phonograph,		## 留声机
}

## 禅境花园工具(商店第三页出售,见 ConstShop 与 src/store/goods_garden_tool.gd)
## 基础水壶是戴夫随花园一起送的,不在这里;黄金水壶是它的升级件(买断,一次浇 4 株)
## 肥料 / 杀虫剂是消耗品(一份 5 个,用一次少一个,持有上限 ConstShop.TOOL_MAX_OWN_NUM),其余买断
enum E_GardenTool{
	GoldWateringCan,	## 黄金水壶
	Fertilizer,		## 肥料
	BugSpray,		## 杀虫剂
	Phonograph,		## 留声机
	GardeningGlove,		## 园艺手套
	Chocolate,		## 巧克力(喂蜗牛,吃了爬得快)
	Snail,			## 蜗牛(买断,买了才出现在花园里捡钱)
	TreeFood,		## 树肥料(喂智慧树,一袋长高一英尺,买下智慧树后才显示,见 ConstTreeOfWisdom)
}

## 当前花园背景页
@export var curr_bg_type:E_GardenBgType=E_GardenBgType.GreenHouse
@export var curr_page:=0
@onready var page_info_label: Label = $CanvasLayer/Next/Label
@onready var page_info_label2: Label = $CanvasLayer/Next/Label2
@onready var num_new_plant_no_plant_cell: Label = $CanvasLayer/NumNewPlantNoPlantCell

@onready var store_enter_key: PVZButtonBase = $CanvasLayer/StoreEnterKey

## 当前背景页的节点
var curr_bg_page_node :GardenBgPage

## ui按钮和对应的物品
@onready var item_buttons: Array[UiItemButton] = [
	$CanvasLayer/PanelUI/HBoxContainer/GardenItemButton,
	$CanvasLayer/PanelUI/HBoxContainer/GardenItemButton2,
	$CanvasLayer/PanelUI/HBoxContainer/GardenItemButton3,
	$CanvasLayer/PanelUI/HBoxContainer/GardenItemButton4,
	$CanvasLayer/PanelUI/HBoxContainer/GardenItemButton5,
	$CanvasLayer/PanelUI/HBoxContainer/GardenItemButton6,
	$CanvasLayer/PanelUI/HBoxContainer/GardenItemButton7,
	$CanvasLayer/PanelUI/HBoxContainer/GardenItemButton8,
	$CanvasLayer/PanelUI/HBoxContainer/GardenItemButton9
]

@onready var items: Array[ItemBase] = [
	$CanvasLayer/Items/WateringCan,
	$CanvasLayer/Items/Fertilizer,
	$CanvasLayer/Items/BugSpray,
	$CanvasLayer/Items/Phonograph,
	$CanvasLayer/Items/Chocolate,
	$CanvasLayer/Items/Glove,
	$CanvasLayer/Items/MoneySign,
	$CanvasLayer/Items/WheelBarrow,
	$CanvasLayer/Items/TreeFood
]

## 水壶，基础款 / 黄金款共用一个节点，外观与作用范围在 refresh_visual() 里切换
@onready var watering_can: WateringCan = $CanvasLayer/Items/WateringCan
## 手套，与水族馆背景植物格子信号连接
@onready var glove: GardenGlove = $CanvasLayer/Items/Glove
## 巧克力，喂给蜗牛吃（见 Chocolate.use_it）
@onready var chocolate: Chocolate = $CanvasLayer/Items/Chocolate
## 蜗牛所在的层，在花园背景之上、UI 之下
@onready var stinky_layer: Node2D = $StinkyLayer
## 花园里掉落的钱的父节点，蜗牛照着它找钱
@onready var drop_coin_parent: Node2D = $CanvasLayerDrop/AllDropCoin
## 花园里的蜗牛，商店买断后才创建，且只在初始花园(阳光房)露面（见 _init_stinky / _refresh_stinky_visible）
var stinky: Stinky
## 独轮车，与水族馆背景植物格子信号连接
@onready var wheel_barrow: WheelBarrow = $CanvasLayer/Items/WheelBarrow
## 树肥料，拖到智慧树的树根上给它施肥（见 TreeFood.use_it）
@onready var tree_food: TreeFood = $CanvasLayer/Items/TreeFood
## 商店场景画布
@onready var canvas_layer_store: CanvasLayer = $CanvasLayerStore
## 当前背景页上的智慧树；只有智慧树页才是树，别的页为 null（见 _refresh_tree_of_wisdom）
var tree_of_wisdom: TreeOfWisdom

## 商店出售的花园工具 -> 花园里的道具节点
## 没在商店买过的工具,按钮与道具一起藏起来(见 _refresh_garden_tool_visible)
@onready var garden_tool_items: Dictionary = {
	E_GardenTool.Fertilizer: $CanvasLayer/Items/Fertilizer,
	E_GardenTool.BugSpray: $CanvasLayer/Items/BugSpray,
	E_GardenTool.Phonograph: $CanvasLayer/Items/Phonograph,
	E_GardenTool.GardeningGlove: $CanvasLayer/Items/Glove,
	E_GardenTool.Chocolate: $CanvasLayer/Items/Chocolate,
	E_GardenTool.TreeFood: $CanvasLayer/Items/TreeFood,
}


## 当前物品
var curr_item


## 每种背景一页的植物格子数量(与对应 bg_XX 场景 GardenPlantCellAll 下的格子实例数一致)
## 用静态常量表达,是为了让"花园是否已满"能在不实例化花园场景时判定(商店的金盏花幼苗要用)
const PLANT_CELL_NUM_PER_PAGE: Dictionary = {
	E_GardenBgType.GreenHouse: 32,
	E_GardenBgType.MushroomGraden: 8,
	E_GardenBgType.Aquarium: 8,
	E_GardenBgType.TreeBg: 0,  ## 智慧树页不放植物格子,见 bg_03_tree_of_wisdom.tscn
}

## 该背景一页的植物格子数量
static func get_plant_cell_num_per_page(bg_type: E_GardenBgType) -> int:
	return int(PLANT_CELL_NUM_PER_PAGE.get(bg_type, 0))

## 阳光房场景
const BgPageScenes = {
	E_GardenBgType.GreenHouse:    preload("res://src/garden/bg_00_greenhouse.tscn"),
	E_GardenBgType.MushroomGraden:preload("res://src/garden/bg_01_mushroom_garden.tscn"),
	E_GardenBgType.Aquarium:      preload("res://src/garden/bg_02_aquarium.tscn"),
	E_GardenBgType.TreeBg:        preload("res://src/garden/bg_03_tree_of_wisdom.tscn")
}

var curr_bg := []

func _ready() -> void:
	## bgm
	SoundManager.play_bgm(bgm)

	## 连接ui物品信号
	for i in range(item_buttons.size()):
		var item_button:UiItemButton = item_buttons[i]
		var item:ItemBase = items[i]
		item_button.ui_item_button_signal.connect(on_button_ui_item.bind(item))

		item.item_button = item_button
		item.is_clone = false

	## 独轮车植物数据
	var wheel_barrow_plant_data = Global.global_game_state.garden_data.get("WheelBarrow", {})
	if wheel_barrow_plant_data:
		wheel_barrow.init_from_data(wheel_barrow_plant_data)

	## 商店里没买过的花园工具不上工具栏
	_refresh_garden_tool_visible()

	## 商店买过的蜗牛在花园里待着
	_init_stinky()

	## 初始化第一类的第一页
	init_new_page()

	store_enter_key.pressed.connect(_on_store_enter_key_pressed)

func init_new_page():
	## 商店还没买的背景(蘑菇园 / 水族馆)页数为 0,不能进
	_fix_curr_bg_type_if_not_owned()
	## 背景种类
	var curr_bg_data = Global.global_game_state.garden_data.get("第"+str(curr_bg_type)+"类背景", {})
	## 当前背景种类的页码数据
	var curr_bg_page_data = curr_bg_data.get("第"+str(curr_page)+"页", {})

	curr_bg_page_node = BgPageScenes[curr_bg_type].instantiate()
	add_child(curr_bg_page_node)
	## 初始化当前背景，获取其空闲植物格子
	var empty_plant_cells:Array[Node] = curr_bg_page_node.init_curr_gb_page(curr_bg_page_data, curr_page)

	## 温室背景
	if curr_bg_type == 0:
		## 新增植物数量和空闲格子的数量的最小值
		for i in range(min(Global.global_game_state.curr_num_new_garden_plant, empty_plant_cells.size())):
			var empty_plant_cell:PlantCellGarden =  empty_plant_cells[i]
			empty_plant_cell.init_new_plant_cell()
			Global.global_game_state.curr_num_new_garden_plant -= 1
		num_new_plant_no_plant_cell.text = "待放置植物数量:" + str(Global.global_game_state.curr_num_new_garden_plant)

	_update_page_info_labels()
	## 智慧树只在智慧树页,翻到别的页要把树肥料的引用清掉(见 _refresh_tree_of_wisdom)
	_refresh_tree_of_wisdom()
	## 蜗牛只跟着初始花园走,换背景要当场收起来(见 _refresh_stinky_visible)
	_refresh_stinky_visible()


## 当前背景还没在商店买到时,切到第一个已拥有Z的背景(页数为 0 的背景不该渲染)
func _fix_curr_bg_type_if_not_owned() -> void:
	if Global.global_game_state.is_garden_bg_owned(curr_bg_type):
		return
	var owned_bg_types: Array[E_GardenBgType] = Global.global_game_state.get_owned_garden_bg_types()
	curr_bg_type = owned_bg_types[0] if not owned_bg_types.is_empty() else E_GardenBgType.GreenHouse
	curr_page = 0


## 下一个已拥有的花园背景(商店没买的跳过),回到起点时取第一个已拥有的
func _get_next_owned_bg_type() -> E_GardenBgType:
	var owned_bg_types: Array[E_GardenBgType] = Global.global_game_state.get_owned_garden_bg_types()
	if owned_bg_types.is_empty():
		return E_GardenBgType.GreenHouse
	var index: int = owned_bg_types.find(curr_bg_type)
	return owned_bg_types[(index + 1) % owned_bg_types.size()]


## 刷新页码与背景种类显示
## 背景种类只统计已拥有的背景:没买的蘑菇园 / 水族馆不该出现在 "N/3" 里
func _update_page_info_labels() -> void:
	page_info_label.text = str(curr_page + 1) + "/" + str(
		Global.global_game_state.get_garden_bg_page_num(curr_bg_type))
	var owned_bg_types: Array[E_GardenBgType] = Global.global_game_state.get_owned_garden_bg_types()
	page_info_label2.text = str(owned_bg_types.find(curr_bg_type) + 1) + "/" + str(owned_bg_types.size())


## 从商店返回后更新
func _update_back_from_store():
	## 可能刚买了黄金水壶,水壶要换成黄金款
	watering_can.refresh_visual()
	## 可能刚买了蜗牛(巧克力要靠它才有意义,所以蜗牛先建,再由下面的刷新决定巧克力上不上工具栏)
	_init_stinky()
	## 可能刚买了花园工具(手套 / 肥料 / 杀虫剂 / 留声机 / 巧克力),工具栏要当场补上,
	## 否则要退回主菜单重进花园(那时才走 _ready)才看得见
	_refresh_garden_tool_visible()
	## 如果有新植物(可能刚买了蘑菇园 / 水族馆 / 金盏花幼苗)
	init_new_page()
	num_new_plant_no_plant_cell.text = "待放置植物数量:" + str(Global.global_game_state.curr_num_new_garden_plant)


##更新当前页花园数据
func save_curr_page_data():
	var curr_bg_page_data:Dictionary = {}
	for i in range(curr_bg_page_node.all_plant_cells.size()):
		var plant_cell :PlantCellGarden = curr_bg_page_node.all_plant_cells[i]
		curr_bg_page_data["第" + str(i) + "个植物格子"] = plant_cell.get_curr_plant_cell_data()

	## 若当前类背景数据还未初始化
	if "第"+str(curr_bg_type)+"类背景" not in Global.global_game_state.garden_data:
		Global.global_game_state.garden_data["第"+str(curr_bg_type)+"类背景"] = {}
	Global.global_game_state.garden_data["第"+str(curr_bg_type)+"类背景"]["第"+str(curr_page)+"页"] = curr_bg_page_data
	## 独轮车信息
	Global.global_game_state.garden_data["WheelBarrow"] = wheel_barrow.choosed_plant_data
	Global.save_service.save_now()

#region 按钮信号连接函数

## 点击商店页
func _on_store_enter_key_pressed():
	## 先保存当前页数据
	save_curr_page_data()
	## 删除上一页的节点
	curr_bg_page_node.queue_free()

	SoundManager.play_other_SFX("tap")
	## 商店场景添加为子节点
	var store_node:StoreManager = load(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Store]).instantiate()
	canvas_layer_store.add_child(store_node)
	store_node.siganl_exit_store.connect(_update_back_from_store)


## 跳转到下一页背景
func _on_next_pressed() -> void:
	## 先保存当前页数据
	save_curr_page_data()

	## 播放音效
	SoundManager.play_other_SFX("tap")
	## 更新页面和种类:翻到本背景最后一页之后,跳到下一个已拥有的背景
	## (商店没买的蘑菇园 / 水族馆页数为 0,直接跳过)
	curr_page += 1
	if curr_page >= Global.global_game_state.get_garden_bg_page_num(curr_bg_type):
		curr_page = 0
		curr_bg_type = _get_next_owned_bg_type()

	## 删除上一页的节点，初始化新页
	curr_bg_page_node.queue_free()
	init_new_page()

## 点击ui物品按钮时，ui物品按钮在_ready()中信号连接该函数
func on_button_ui_item(item:ItemBase):

	## 播放音效
	SoundManager.play_other_SFX("tap2")
	curr_item = item
	item.activete_it()


## 商店里的花园工具:买了才上工具栏,没买的按钮与道具一起藏起来
## 原版口径:花园工具要一件件在商店买;基础水壶是戴夫送的永远可用,
## 黄金水壶是买断的升级件,买了才能一次浇 4 株(见 WateringCan.use_it)
## 双向刷新:买入后要能把工具"显示出来"(从商店回来 / 买了蜗牛后巧克力可用),不只是"藏起来"
func _refresh_garden_tool_visible() -> void:
	## 水壶不在上表(永远可用),但要按"是否已买黄金水壶"刷新成基础款 / 黄金款
	watering_can.refresh_visual()
	for tool_type in garden_tool_items:
		var item: ItemBase = garden_tool_items[tool_type]
		var is_available := _is_garden_tool_available(tool_type as E_GardenTool)
		if is_instance_valid(item.item_button):
			item.item_button.visible = is_available
		## 道具本体的显隐是"激活态"(见 ItemBase.activete_it / deactivate_it),
		## 这里只在用不了时强制收起,不能反过来把它显示成"已激活"
		if not is_available:
			item.visible = false


## 该花园工具现在能不能上工具栏
## 与 GlobalGameState.is_garden_tool_available 的差别:巧克力是喂蜗牛的,没买蜗牛就没有用;
## 树肥料是喂智慧树的,没买智慧树就没有用
func _is_garden_tool_available(tool_type: E_GardenTool) -> bool:
	if not Global.global_game_state.is_garden_tool_available(tool_type):
		return false
	if tool_type == E_GardenTool.Chocolate:
		return _is_stinky_owned()
	if tool_type == E_GardenTool.TreeFood:
		return _is_tree_of_wisdom_owned()
	return true


## 蜗牛是否已在商店买断
func _is_stinky_owned() -> bool:
	return Global.global_game_state.is_garden_tool_bought(E_GardenTool.Snail)


## 智慧树是否已在商店买断
func _is_tree_of_wisdom_owned() -> bool:
	return Global.global_game_state.is_tree_of_wisdom_bought()


## 智慧树的引用跟着当前背景页走:只有智慧树页才有树,别的页给 null(树肥料拖下去无处可用)
func _refresh_tree_of_wisdom() -> void:
	tree_of_wisdom = curr_bg_page_node as TreeOfWisdom
	tree_food.tree_of_wisdom = tree_of_wisdom


## 蜗牛:商店买断后才在初始花园(阳光房)里出现,之后一直在(翻页 / 进出商店都不重建)
func _init_stinky() -> void:
	if stinky != null:
		return
	if not _is_stinky_owned():
		return
	stinky = SceneRegistry.STINKY.instantiate()
	stinky_layer.add_child(stinky)
	## 蜗牛自己不去抓父节点,找钱的范围由花园注入
	stinky.drop_coin_parent = drop_coin_parent
	chocolate.stinky = stinky
	_refresh_garden_tool_visible()
	_refresh_stinky_visible()


## 蜗牛只在初始花园(阳光房)露面:翻到蘑菇园 / 水族馆就藏起来,翻回来还是原来那只
## 藏起来时连 _process 一起停:不爬也不捡钱(GardenManager._input 与 Chocolate 的命中判定
## 也跟着失效,见 Stinky.is_hit),免得在别的花园里隔空把钱吃掉
func _refresh_stinky_visible() -> void:
	if stinky == null:
		return
	var is_show: bool = curr_bg_type == E_GardenBgType.GreenHouse
	stinky.visible = is_show
	stinky.set_process(is_show)
	if not is_show:
		## 离场就睡下:锁着的钱放掉,翻回来时从头醒
		stinky.sleep()


## 点蜗牛把它叫醒(手上拿着道具时不抢这一次点击,巧克力自己会去喂)
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if stinky == null or not stinky.is_hit(get_global_mouse_position()):
		return
	if curr_item != null and curr_item.is_activate:
		return
	stinky.wake_up()

## 返回菜单按钮
func _on_return_start_menu_pressed() -> void:
	save_curr_page_data()
	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])

#endregion
