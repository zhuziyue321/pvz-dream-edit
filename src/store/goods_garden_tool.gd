extends Goods
class_name GoodsGardenTool
## 商店第三页(工具)与第四页第二行第一格(树肥料)出售的禅境花园工具
## 买断型(黄金水壶 / 留声机 / 园艺手套): 买一次即"已拥有",售罄
##   (见 ConstShop.ONE_TIME_GARDEN_TOOL_PRICE)
## 消耗型(肥料 / 杀虫剂 / 树肥料): 一份 ConstShop.get_garden_tool_num_per_buy() 个,可重复购买;
##   持有满 ConstShop.get_tool_max_own_num() 时禁售,戴夫提示先去花园里用掉一些
## 花园未解锁(未通关 5-5)时不可购买,与金盏花幼苗同一套口径(Goods.apply_garden_unlock_lock)
## 花园侧的可用性门控见 GardenManager._refresh_garden_tool_visible

## 本商品卖的是哪件工具
@export var garden_tool: GardenManager.E_GardenTool = GardenManager.E_GardenTool.Fertilizer

## 各工具的商品图标(原版图标就在 assets/image/garden 下,不必另配商店图)
const TOOL_ICON: Dictionary = {
	GardenManager.E_GardenTool.GoldWateringCan: preload("res://assets/image/garden/WateringCanGold.png"),
	GardenManager.E_GardenTool.Fertilizer: preload("res://assets/image/garden/Fertilizer.png"),
	GardenManager.E_GardenTool.BugSpray: preload("res://assets/image/garden/bug_spray.png"),
	GardenManager.E_GardenTool.Phonograph: preload("res://assets/image/garden/Phonograph.png"),
	GardenManager.E_GardenTool.GardeningGlove: preload("res://assets/image/garden/Zen_GardenGlove.png"),
	GardenManager.E_GardenTool.Chocolate: preload("res://assets/image/garden/chocolate.png"),
	GardenManager.E_GardenTool.Snail: preload("res://assets/reanim/Stinky_shell.png"),
	GardenManager.E_GardenTool.TreeFood: preload("res://assets/image/garden/TreeFood.png"),
}

## 少数工具的图标不用单张贴图,而是「取动画的某一帧」渲染出来(见 AnimationFrameUtil)
## 目前只有蜗牛:TOOL_ICON 里的 Stinky_shell 只是个壳,没有身体 / 触角 / 尾巴,
## 取 Stinky_idle 的一帧才是完整一只蜗牛
## 没配进来的工具照旧用 TOOL_ICON 的贴图
const FRAME_ICON_SCENE: Dictionary = {
	GardenManager.E_GardenTool.Snail: preload("res://src/garden/stinky.tscn"),
}
## 与 FRAME_ICON_SCENE 一一对应:取哪个动画的第几帧
const FRAME_ICON_ANIM: Dictionary = {
	GardenManager.E_GardenTool.Snail: &"Stinky_idle",
}
## 取帧图标四周的留白(像素)
const FRAME_ICON_MARGIN := 2.0

## 各工具的戴夫话术(场景里没配 dialog_detail 时的兜底,与 GoodsWallNutFirstAid 同一套做法)
## 数据来源: data/strings/lawn_strings.txt 的 CRAZY_DAVE_2019~2023
## 口径: 原版一代 PC
const TOOL_DIALOG_TEXT: Dictionary = {
	GardenManager.E_GardenTool.GoldWateringCan:
		"黄金水壶，能让你一次最多浇灌四盆植物。",
	GardenManager.E_GardenTool.Fertilizer:
		"你花园里的植物需要施肥！",
	GardenManager.E_GardenTool.BugSpray:
		"花园里的植物们需要时不时的喷喷杀虫剂！这能让它们整天都开心！",
	GardenManager.E_GardenTool.Phonograph:
		"这台唱片机能为花园的植物播放音乐！这会让它们整天都保持好心情！",
	GardenManager.E_GardenTool.GardeningGlove:
		"园艺手套可以移动你花园里的花盆！",
	GardenManager.E_GardenTool.Chocolate:
		"巧克力！把它喂给蜗牛吃，蜗牛就会跑得飞快！",
	GardenManager.E_GardenTool.Snail:
		"这只蜗牛能帮你捡起花园里的钱！不过它老爱打瞌睡，记得点它一下！",
	## 原版 [CRAZY_DAVE_2031]
	GardenManager.E_GardenTool.TreeFood:
		"为你的智慧树购买一些树肥料吧，这可以使他长的又茂盛又高大！",
}

## 消耗型工具持有已满时的戴夫对话前缀提示
const TOOL_NUM_FULL_TIP := "**你手上已经有 %d 个了，先去花园里用掉一些吧**\n"

@onready var store_icon: TextureRect = $StoreIcon


func _ready() -> void:
	price = ConstShop.get_garden_tool_price(garden_tool)
	store_icon.texture = TOOL_ICON.get(garden_tool, null)
	## 配了"取动画某一帧"的工具,图标换成渲染出来的那一帧(渲染完成前先用 TOOL_ICON 兜底)
	_render_frame_icon()
	## 没有配置戴夫对话时,用该工具的默认话术兜底
	if dialog_detail == null:
		dialog_detail = _create_dialog_detail()
	super()
	_refresh_goods_state()
	judge_can_get_goods()


## 本商品配了「取动画某一帧当图标」时,把图标换成渲染出来的那一帧
## 内部 await 离屏渲染两帧,不阻塞 _ready;取帧失败就继续用 TOOL_ICON 的兜底贴图
func _render_frame_icon() -> void:
	var scene := FRAME_ICON_SCENE.get(garden_tool, null) as PackedScene
	if scene == null:
		return
	var anim_name: StringName = FRAME_ICON_ANIM.get(garden_tool, &"")
	var tex := await AnimationFrameUtil.create_frame_texture(
			scene, anim_name, 0, store_icon.size, FRAME_ICON_MARGIN)
	if tex == null or not is_instance_valid(store_icon):
		return
	store_icon.texture = tex


## 花园未解锁不可购买;消耗型持有已满时也禁售
func judge_can_get_goods():
	super.judge_can_get_goods()
	if not apply_garden_unlock_lock():
		return
	if _is_tool_num_full():
		button.disabled = true
		curr_dialog_detail.text = TOOL_NUM_FULL_TIP % ConstShop.get_tool_max_own_num(garden_tool) \
			+ dialog_detail.text


## 买断型已买过则售罄("已拥有");消耗型永远有货,靠持有上限禁售
func _refresh_goods_state() -> void:
	if Global.global_game_state.is_garden_tool_bought(garden_tool):
		is_have_goods = false
		is_not_have_goods_label.text = "已拥有"
	is_not_have_goods_label.visible = not is_have_goods


## 消耗型工具是否已持有满(买断型永远不满)
func _is_tool_num_full() -> bool:
	if not GlobalGameState.is_consumable_garden_tool(garden_tool):
		return false
	return Global.global_game_state.get_garden_tool_num(garden_tool) \
		>= ConstShop.get_tool_max_own_num(garden_tool)


## 生成兜底的戴夫对话
func _create_dialog_detail() -> CrazyDaveDialogDetailResource:
	var detail := CrazyDaveDialogDetailResource.new()
	detail.text = TOOL_DIALOG_TEXT.get(garden_tool, "这可是好东西！")
	return detail


## 获得该商品:买断型记入已拥有,消耗型加一份库存
func get_one_goods():
	if GlobalGameState.is_consumable_garden_tool(garden_tool):
		Global.global_game_state.add_garden_tool_num(
			garden_tool, ConstShop.get_garden_tool_num_per_buy(garden_tool))
	else:
		Global.global_game_state.buy_garden_tool(garden_tool)
	Global.save_service.save_now()
	_refresh_goods_state()
	judge_can_get_goods()
