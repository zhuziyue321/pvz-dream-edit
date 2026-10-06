extends Sprite2D
class_name WallnutBowlingStripe
## 坚果保龄球红线：红线右边不能种植物（原版保龄球关的规则）
##
## 出场时机不是关卡一初始化，而是戴夫念到「我们去玩保龄球！」的那一句
## （原版 1-5：戴夫介绍保龄球惊喜的同时红线才画出来）：
##   1-5 开局草坪上有豌豆射手、玩家还在铲草，红线先画出来会很突兀。
## 台词触发走事件总线（CrazyDaveDialogDetailResource.on_talk_event = SHOW_STRIPE_EVENT），
## 没有戴夫对话的关卡（小游戏保龄球关、重玩 1-5）由 MainGameManager 在预览僵尸前兜底显示。
## 注意：红线的「禁种 / 禁僵尸」标记在 init_item() 里就全部打好，与本节点的显隐无关。

## 戴夫台词触发红线出现的事件名
const SHOW_STRIPE_EVENT := "show_bowling_stripe"

var plant_cell_manager:PlantCellManager

func init_item(plant_cell_col_j:int=2, plant_cell_can_use:Dictionary = {}):
	## 确定红线位置
	var target_plant_cell:PlantCell= Global.main_game.plant_cell_manager.all_plant_cells[0][plant_cell_col_j]
	var target_global_pos_x:float = target_plant_cell.global_position.x
	var target_global_pos_y:float = target_plant_cell.global_position.y

	## 如果存在屋顶斜面
	if is_instance_valid(Global.main_game.main_game_slope):
		scale.y = 0.88
		## 后面一格，屋顶时确定y
		if Global.main_game.plant_cell_manager.all_plant_cells[0].get(plant_cell_col_j + 1):
			target_global_pos_y = Global.main_game.plant_cell_manager.all_plant_cells[0][plant_cell_col_j + 1].global_position.y

	global_position = Vector2(target_global_pos_x + target_plant_cell.size.x - 11, target_global_pos_y)


	for plant_cells_row in Global.main_game.plant_cell_manager.all_plant_cells:
		## 左边不可以种植
		if not plant_cell_can_use["left_can_plant"]:
			for j in range(plant_cell_col_j + 1):
				var plant_cell:PlantCell = plant_cells_row[j]
				plant_cell.set_bowling_no_plant()
		## 右边不可以种植
		if not plant_cell_can_use["right_can_plant"]:
			for j in range(plant_cell_col_j + 1, plant_cells_row.size()):
				var plant_cell:PlantCell = plant_cells_row[j]
				plant_cell.set_bowling_no_plant()

		## 左边不可以僵尸
		if not plant_cell_can_use["left_can_zombie"]:
			for j in range(plant_cell_col_j + 1):
				var plant_cell:PlantCell = plant_cells_row[j]
				plant_cell.set_bowling_no_zombie()
		## 右边不可以僵尸
		if not plant_cell_can_use["right_can_zombie"]:
			for j in range(plant_cell_col_j + 1, plant_cells_row.size()):
				var plant_cell:PlantCell = plant_cells_row[j]
				plant_cell.set_bowling_no_zombie()

	## 先藏着，等戴夫念到保龄球那句（或主游戏兜底）再画出来
	visible = false
	EventBus.subscribe(SHOW_STRIPE_EVENT, show_stripe)


## 把红线画出来（可重复调用：已经画出来了就什么都不做）
func show_stripe() -> void:
	if visible:
		return
	visible = true


func _exit_tree() -> void:
	if EventBus.has_signal(SHOW_STRIPE_EVENT):
		EventBus.unsubscribe(SHOW_STRIPE_EVENT, show_stripe)
