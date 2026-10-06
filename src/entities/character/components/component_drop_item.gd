extends ComponentNormBase
class_name DropItemComponent
## 掉落战利品组件,可以掉落金币\硬币\钻石\花园植物\巧克力

@export_group("掉落相关")
## 可以掉落坐标X范围,若x在该范围内可以掉落(僵尸逃跑\魅惑离开当前页面)
@export var can_drop_x_range :Vector2 = Vector2(0, 900)
## 掉落金币的概率
@export var drop_coin_rate := 0.3
## 掉落银币、金币、钻石的比例（要求和为1）
@export var drop_coin_silver_glod_diamond_rate := [0.5,0.4,0.1]
## 掉落花园植物概率
@export var drop_garden_plant_rate := 0.004
## 掉落巧克力概率
## 待核实: 原版只说"杀了僵尸随机掉巧克力",没给具体概率;这里取 2%
## (参考同组件的花园植物 0.4% —— 巧克力比禅境花园植物常见,但也没到金币 30% 那种量级)
@export var drop_chocolate_rate := 0.02
## 掉落生产的偏移y值
@export var correct_y:float=100
## 金币移动的目标位置与初始位置的y的范围
@export var target_move_y_range:Vector2 = Vector2(80, 90)

#region 僵尸掉落
## 掉落金银钻
func drop_coin():
	if not is_enabling:
		return
	if global_position.x > can_drop_x_range.y or global_position.x < can_drop_x_range.x:
		return

	var r = randf()
	if r < drop_coin_rate:

		EventBus.push_event("create_coin", [
			drop_coin_silver_glod_diamond_rate,\
			Vector2(clamp(global_position.x, 0, get_viewport().get_visible_rect().size.x),\
			clamp(global_position.y-correct_y, 0, get_viewport().get_visible_rect().size.y)),
			Vector2(randf_range(-50, 50), randf_range(target_move_y_range.x, target_move_y_range.y))
		])

## 掉落花园植物(花园未解锁时不掉,见 ConstUnlockLevel.GARDEN_UNLOCK_ADVENTURE_LEVEL)
func drop_garden_plant():
	if not is_enabling:
		return
	if not Global.global_game_state.is_garden_unlocked():
		return
	var r = randf()
	if r < drop_garden_plant_rate:
		EventBus.push_event("create_garden_plant", [
			Vector2(clamp(global_position.x, 0, get_viewport().get_visible_rect().size.x),\
			clamp(global_position.y-50, 0, get_viewport().get_visible_rect().size.y))
		])

## 掉落巧克力(原版:巧克力只从僵尸身上来,而且买了蜗牛之后才开始掉)
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Chocolate)
##   "Randomly from killing zombies"、
##   "Chocolate will not appear until the player purchases Stinky the Snail"、
##   "Once ten pieces of chocolate have been amassed, no more chocolate will appear"
## 口径: 一代 PC;上限按本仓库消耗型工具统一的 ConstShop.TOOL_MAX_OWN_NUM
func drop_chocolate():
	if not is_enabling:
		return
	## 没买蜗牛一块都不掉:巧克力是喂蜗牛的,没蜗牛时掉了也没用
	if not Global.global_game_state.is_garden_tool_bought(GardenManager.E_GardenTool.Snail):
		return
	## 库存已满不再掉(原版: 攒够上限后就不再出现)
	if Global.global_game_state.get_garden_tool_num(
			GardenManager.E_GardenTool.Chocolate) >= ConstShop.TOOL_MAX_OWN_NUM:
		return
	if global_position.x > can_drop_x_range.y or global_position.x < can_drop_x_range.x:
		return

	var r = randf()
	if r < drop_chocolate_rate:
		EventBus.push_event("create_chocolate", [
			Vector2(clamp(global_position.x, 0, get_viewport().get_visible_rect().size.x),\
			clamp(global_position.y-correct_y, 0, get_viewport().get_visible_rect().size.y))
		])

#endregion

