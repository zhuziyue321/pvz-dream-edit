extends Node
class_name GIM_Other

@onready var game_item_manager: GameItemManager = %GameItemManager

## 放置在背景的游戏物品
@onready var game_items_in_bg: Node2D = %GameItemsInBg
@onready var canvas_layer_temp: CanvasLayer = %CanvasLayerTemp

#region 场景预制体
## 保龄球红线
var WALLNUT_BOWLING_STRIPE = load("res://src/items/mini_game/wallnut_bowling_stripe.tscn")
#endregion

#region 道具
var wallnut_bowling_stripe:WallnutBowlingStripe
#endregion

func init_other_item():
	if game_item_manager.game_para.is_bowling_stripe:
		wallnut_bowling_stripe = WALLNUT_BOWLING_STRIPE.instantiate()
		game_items_in_bg.add_child(wallnut_bowling_stripe)
		wallnut_bowling_stripe.init_item(game_item_manager.game_para.plant_cell_col_j, game_item_manager.game_para.plant_cell_can_use)

	## 关卡脚本自带的专属物品（观星的星星轮廓这类）：由脚本自己在 init_level_items() 里
	## 建好并挂到背景层，本文件不认识任何具体玩法 —— 加新玩法不用再来这里加分支
	## （时机说明见 LevelScriptBase.init_level_items：格子已建好、玩家还动手不了）
	var level_script := game_item_manager.game_para as LevelScriptBase
	if level_script != null:
		level_script.init_level_items(game_item_manager.main_game, game_items_in_bg)


## 把保龄球红线画出来（本关没有红线时什么都不做）
## 正常时机是戴夫念到「我们去玩保龄球！」的那一句（WallnutBowlingStripe.SHOW_STRIPE_EVENT）；
## 没有这段对话的场合（小游戏保龄球关、重玩 1-5 时教程与对话都跳过）由主游戏在预览僵尸前兜底调用
func show_bowling_stripe() -> void:
	if wallnut_bowling_stripe == null:
		return
	wallnut_bowling_stripe.show_stripe()
