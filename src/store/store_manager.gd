extends Control
class_name StoreManager

@onready var crazy_dave: CrazyDave = $CrazyDave
## 商店里戴夫说的话都在本场景 CrazyDave 节点的 dialog_resource 上(见 store.tscn),来源:
##   开场白: 原版拿到车钥匙后开张的两句 —— data/strings/lawn_strings.txt 的 CRAZY_DAVE_303 / 304
##   挂机时的随机台词: 原版"在商店里发呆戴夫会随机说这四句" —— CRAZY_DAVE_2015~2018
##   (原版口径见 PVZ Wiki Crazy Dave's Twiddydinkies 的 Trivia 段)
## 要改这两处文案,改 store.tscn 里的 dialog_detail_list / dialog_detail_long_time_idle_list
## 另外进店时的"专属开场"(3-4 的车钥匙 / 5-1 的 3100)由 pending_intro_lines 追加在最前面
## (见 apply_pending_intro_lines 与 MGM_RewardManager 的跳商店分支)
@export var all_goods :Array[Goods]
@onready var confirm_goods: ConfirmGoods = $ConfirmGoods
## 通用弹窗:金币不足 / 更多卡片槽 / 拜访智慧树(见 store_dialog.gd)
@onready var store_dialog: StoreDialog = $StoreDialog

## 植物卡片(紫卡与模仿者)商品场景
var GOODS_PLANT_CARD_SCENE := AssetRegistry.get_scene("res://src/store/goods_plant_card.tscn")

## 货架的每一行(每行 ConstShop.SHOP_ROW_SLOT_NUM = 4 格,两行凑成一页 8 格)
## 页的分法见 pages: 第一页 = 道具行 + 第一批紫卡行;第二页 = 第二批紫卡行 + 模仿者行;
## 第三页 = 植物盆行(3 盆 + 黄金水壶) + 花园工具行(肥料 / 杀虫剂 / 留声机 / 园艺手套);
## 第四页 = 禅境花园行(蘑菇园 / 水族馆 / 独轮车 / 蜗牛) + 智慧树 / 树肥料
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

## 翻页按钮(只有一页时**置灰**而不是隐藏,与原版一致)
@onready var prev_page_button: TextureButton = $Bg/Car2/PrevPageButton
@onready var next_page_button: TextureButton = $Bg/Car2/NextPageButton2
## 页码文字 "X / Y页"(原版 [STORE_PAGE]);只有一页时隐藏
@onready var page_label: Label = $Bg/Car2/PageLabel
## 开箱 / 关箱两张车图(原版 IMAGE_STORE_CARCLOSED / IMAGE_STORE_CAR + HATCHBACKOPEN)
@onready var car_closed: TextureRect = $Bg/CarClosed
@onready var car2: TextureRect = $Bg/Car2
## 招牌(原版开场从上往下滑入)
@onready var store_sign: TextureRect = $Bg/StoreSign
## 夜间商店背景(原版 IsNight() 时换成 Store_BackgroundNight)
@onready var night_bg: TextureRect = $Bg/NightBg

## 紫卡与模仿者的落位:下表第 i 项写在 plant_card_rows[i] 这一行,顺序即行内槽位顺序
## 上架关卡见 ConstPlantUnlock.PURPLE_CARD_CAN_BUY_LEVEL
const PLANT_CARD_ROWS: Array[Array] = [
	[PlantIds.GATLING_PEA,
	 PlantIds.TWIN_SUN_FLOWER,
	 PlantIds.GLOOM_SHROOM,
	 PlantIds.CATTAIL,],		## 3-4 / 4-4 上架序(机枪、双子、忧郁菇、猫尾草)
	[PlantIds.SPIKE_ROCK,
	 PlantIds.GOLD_MAGNET,
	 PlantIds.WINTER_MELON,
	 PlantIds.COB_CANNON,],	## 5-1 / 通关后上架序(地刺王、吸金磁、冰西瓜、玉米加农炮)
	[PlantIds.IMITATER,],	## 模仿者;同行还有坚果包扎术,它不是植物卡片,直接摆在场景里(见 goods_wall_nut_first_aid)
]

## 每一页 = [第一行, 第二行];第二行暂缺时装 null(这一页就只摆一行)
var pages: Array[Array] = []
## 紫卡商品往哪一行塞(与 PLANT_CARD_ROWS 一一对应)
var plant_card_rows: Array[Control] = []
## 当前已上架的页(还没到上架关卡的页不存在,不参与翻页)
var valid_pages: Array[Array] = []
## 当前页在 valid_pages 中的下标
var curr_page := 0

## 进场动画 / 翻页动画期间锁住货架与翻页按钮(原版 mStoreTime < 120 与 mHatchTimer 同理)
var _is_busy := true
## 翻页关箱 / 开箱各占的时间(秒)
const PAGE_FLIP_TIME := 0.2
## 进场：招牌滑入 + 开箱，之后才开始接点击(对齐原版前 120 tick 不可操作)
const INTRO_SIGN_TIME := 0.6
const INTRO_HATCH_DELAY := 0.4
const INTRO_AFTER_OPEN_TIME := 0.5

## 进店时要追加在原版开场白(303/304)前面的专属台词
## 由通关结算写(见 MGM_RewardManager)：3-4 车钥匙(CRAZY_DAVE_301/302)、5-1 新货(3100)
## 场景切换前赋值，StoreManager._ready() 消费一次后清空(静态：切场景不经过调用方)
static var pending_intro_lines: Array[String] = []

## 离开商店页信号
signal siganl_exit_store

## 返回按钮上的文字节点（从花园里打开时原版写 "Back to game"）
@onready var back_button_label: Label = $Bg/StoreMainMenuButton/Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.save_service.save_now()
	pages = [
		[row_tools, row_upgrade_first],		## 第一页: 道具 / 第一批紫卡
		[row_upgrade_second, row_upgrade_third],	## 第二页: 第二批紫卡 / 模仿者
		[row_garden_sprout, row_garden_tools],	## 第三页: 植物盆 + 黄金水壶 / 花园工具
		[row_garden, row_tree_food],		## 第四页: 蘑菇园 / 水族馆 / 独轮车 / 蜗牛 + 智慧树 / 树肥料
	]
	plant_card_rows = [row_upgrade_first, row_upgrade_second, row_upgrade_third]
	_create_plant_card_goods()
	_fill_sprout_slots()
	## 原版货架顺序:模仿者在前、坚果包扎术在后(见 goods_wall_nut_first_aid 的注释)
	row_upgrade_third.move_child(goods_wall_nut_first_aid, -1)
	_refresh_valid_pages()
	_apply_page(0)
	_wire_goods_signals()
	apply_pending_intro_lines()
	_update_night_variant()
	_update_back_button_text()
	store_dialog.confirmed.connect(_on_dialog_confirmed)
	_play_intro_animation()


## 生成商店出售的植物卡片商品(紫卡与模仿者),按 PLANT_CARD_ROWS 落到对应的行
func _create_plant_card_goods() -> void:
	for row_index in PLANT_CARD_ROWS.size():
		var row: Control = plant_card_rows[row_index]
		for plant_type in PLANT_CARD_ROWS[row_index]:
			var goods: GoodsPlantCard = GOODS_PLANT_CARD_SCENE.instantiate()
			goods.plant_type = plant_type
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


## 把货架 / 戴夫 / 弹窗都接上：
##   · 鼠标悬停 → 戴夫念该商品的台词(原版 UpdateMouse 里的 SetBubbleText)
##   · 点击     → 买得起弹确认框，买不起弹「金币不足」(原版 PurchaseItem 的两个分支)
##   · 买完     → 商品自己发 request_message / request_confirm / request_dave_text
func _wire_goods_signals() -> void:
	for goods in all_goods:
		goods.look_goods_signal.connect(crazy_dave.external_trigger_dialog)
		goods.look_end_goods_signal.connect(crazy_dave.external_trigger_dialog_end)
		goods.signal_pressed_this_goods.connect(_on_goods_pressed.bind(goods))
		goods.request_message.connect(_on_goods_message)
		goods.request_confirm.connect(_on_goods_confirm)
		goods.request_dave_text.connect(_on_goods_dave_text)


func _on_goods_pressed(goods: Goods) -> void:
	if _is_busy or store_dialog.is_open() or confirm_goods.visible:
		return
	if not goods.is_have_goods:
		return
	## 原版：买不起先弹「金币不足」，不是把按钮禁用掉
	if not goods.can_afford():
		store_dialog.appear_message("金币不足", "你现在还无法购买这一物品。打倒更多僵尸，挣更多的钱吧！")
		return
	confirm_goods.appear_canvas_layer(goods)


func _on_goods_message(title: String, body: String) -> void:
	store_dialog.appear_message(title, body)


## 商品请求「是 / 否」确认；目前只有智慧树的「拜访智慧树？」
var _pending_confirm := ""
func _on_goods_confirm(title: String, body: String) -> void:
	_pending_confirm = "visit_tree"
	store_dialog.appear_confirm(title, body)


func _on_dialog_confirmed() -> void:
	var action := _pending_confirm
	_pending_confirm = ""
	if action == "visit_tree":
		_goto_tree_of_wisdom()


## 原版买下智慧树后 mGoToTreeNow：直接进花园的智慧树页(见 GardenManager.pending_open_bg_type)
func _goto_tree_of_wisdom() -> void:
	GardenManager.pending_open_bg_type = GardenManager.E_GardenBgType.TreeBg
	siganl_exit_store.emit()
	if get_tree().current_scene == self:
		GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.Garden))
	else:
		## 从花园里打开的商店：把主场景换成花园(会重进一次，页面按 pending 落到智慧树)
		GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.Garden))


## 买完特殊商品后戴夫额外念一句(原版 CRAZY_DAVE_3400 那种)
func _on_goods_dave_text(text: String) -> void:
	if not crazy_dave.start_long_time_dave:
		return
	var detail := CrazyDaveDialogDetailResource.new()
	detail.text = text
	crazy_dave.external_trigger_dialog(detail)
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(crazy_dave):
		crazy_dave.external_trigger_dialog_end()


## 追加进店专属开场(消费一次)。原始 resource 是只读导出，复制一份再改
func apply_pending_intro_lines() -> void:
	if pending_intro_lines.is_empty():
		return
	var base_res: CrazyDaveDialogResource = crazy_dave.dialog_resource
	if base_res == null:
		pending_intro_lines.clear()
		return
	var new_res: CrazyDaveDialogResource = base_res.duplicate(true)
	var lines: Array[CrazyDaveDialogDetailResource] = []
	for text in pending_intro_lines:
		var detail := CrazyDaveDialogDetailResource.new()
		detail.text = text
		lines.append(detail)
	for detail in new_res.dialog_detail_list:
		lines.append(detail)
	new_res.dialog_detail_list = lines
	crazy_dave.dialog_resource = new_res
	pending_intro_lines.clear()


## 夜间商店：原版 StoreScreen::Draw 按 mApp->IsNight() 换 Store_BackgroundNight
## 本仓库没有"当前 Board"这一层，用当前关卡背景近似(主菜单里没有关卡时按白天)
func _update_night_variant() -> void:
	var is_night := false
	var para: Variant = Global.game_para
	if para != null:
		var bg: int = int(para.get("game_BG"))
		is_night = bg == ConstLevelData.GameBg.FrontNight \
			or bg == ConstLevelData.GameBg.Boss \
			or bg == ConstLevelData.GameBg.MoonRoof
	night_bg.visible = is_night


## 进场演出：招牌滑入 → 开箱 → 解锁交互(原版开场 120 tick 不可点)
func _play_intro_animation() -> void:
	_is_busy = true
	car2.visible = false
	car_closed.visible = true
	page_label.visible = false
	_update_page_button_state()

	var sign_target: Vector2 = store_sign.position
	store_sign.position = sign_target + Vector2(0, -180)
	var tween := create_tween()
	tween.tween_property(store_sign, "position", sign_target, INTRO_SIGN_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(INTRO_HATCH_DELAY).timeout
	car_closed.visible = false
	car2.visible = true
	await get_tree().create_timer(INTRO_AFTER_OPEN_TIME).timeout
	_is_busy = false
	_apply_page(curr_page)


## 返回按钮文字：独立成场景时回主菜单（"返回"），从花园里打开时回花园（原版 "Back to game"）
func _update_back_button_text() -> void:
	if back_button_label == null:
		return
	back_button_label.text = "返回" if get_tree().current_scene == self else "返回游戏"


## 一次性把当前页摆出来(不做动画)：行显隐 + 页码 + 翻页按钮状态
func _apply_page(page: int) -> void:
	if valid_pages.is_empty():
		return
	curr_page = posmod(page, valid_pages.size())
	var curr_rows: Array = valid_pages[curr_page]
	for rows in pages:
		for row in rows:
			if row != null:
				row.visible = (rows == curr_rows)
	_update_page_button_state()


## 立即切到某页（不做关箱 / 开箱动画）：探针与调试用，玩家点翻页走 _flip_page()
func _show_page(page: int) -> void:
	_apply_page(page)


## 翻页：原版先关箱(mHatchTimer=50)再换页、再开箱，期间锁交互
func _flip_page(delta: int) -> void:
	if _is_busy or valid_pages.size() <= 1:
		return
	_is_busy = true
	_update_page_button_state()
	car2.visible = false
	car_closed.visible = true
	await get_tree().create_timer(PAGE_FLIP_TIME).timeout
	_apply_page(curr_page + delta)
	car_closed.visible = false
	car2.visible = true
	await get_tree().create_timer(PAGE_FLIP_TIME).timeout
	_is_busy = false
	_update_page_button_state()


## 翻页按钮：只有一页时置灰(原版 SetDisabled)，页码只有多页时才显示
func _update_page_button_state() -> void:
	var is_multi_page: bool = valid_pages.size() > 1
	prev_page_button.disabled = not is_multi_page or _is_busy
	next_page_button.disabled = not is_multi_page or _is_busy
	page_label.visible = is_multi_page
	if is_multi_page:
		page_label.text = "%d / %d页" % [curr_page + 1, valid_pages.size()]

func _on_prev_page_button_pressed() -> void:
	_flip_page(-1)

func _on_next_page_button_pressed() -> void:
	_flip_page(1)


## ESC 退出商店(原版 StoreScreen::KeyDown)
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_ESCAPE:
		return
	if store_dialog.is_open():
		store_dialog.hide_dialog()
		return
	if confirm_goods.visible:
		confirm_goods.close()
		return
	if _is_busy:
		return
	_on_store_main_menu_button_pressed()


## 离开商店
func _on_store_main_menu_button_pressed() -> void:
	siganl_exit_store.emit()
	Global.save_service.save_now()
	if get_tree().current_scene == self:
		GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.StartMenu))
	else:
		queue_free()
