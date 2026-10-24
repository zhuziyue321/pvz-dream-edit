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
## 原版 Board.cpp 的掉落表是万分比：aPottedPlantChance = 12（冒险重打 24 / 无尽生存 3），
## 这里取基础档 12/10000 = 0.12%
@export var drop_garden_plant_rate := 0.0012
## 掉落巧克力概率
## 原版同一张表：aChocolateChance = aPottedPlantChance + 36（冒险重打 +72 / 无尽 +9），
## 这里取基础档 (12+36)/10000 = 0.48%
@export var drop_chocolate_rate := 0.0048
## 巧克力攒到多少块以后僵尸不再掉（原版 CanDropChocolate：购买记录 >= 1000 + 10）
const CHOCOLATE_DROP_MAX_OWN_NUM := 10
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
		EventBus.push_event(ConstEventName.CREATE_COIN, [
			drop_coin_silver_glod_diamond_rate,\
			_get_clamp_drop_position(correct_y),
			Vector2(randf_range(-50, 50), randf_range(target_move_y_range.x, target_move_y_range.y))
		])

## 掉落花园植物
## 原版 CanDropPottedPlantLoot：**通关冒险模式** + 花园还有空位，两条都满足才掉
## （只是解锁花园 5-4 还不够，原版要 HasFinishedAdventure）
func drop_garden_plant():
	if not is_enabling:
		return
	if not Goods.is_adventure_finished():
		return
	if not Global.global_game_state.has_empty_garden_cell():
		return
	var r = randf()
	if r < drop_garden_plant_rate:
		EventBus.push_event(ConstEventName.CREATE_GARDEN_PLANT, [_get_clamp_drop_position()])

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
	## 原版 CanDropChocolate：玩家手上攒到 10 块巧克力之后**僵尸就不再掉**（商店还能买，
	## 商店侧持有上限仍是 ConstShop.TOOL_MAX_OWN_NUM = 20，两者是两回事）
	if Global.global_game_state.get_garden_tool_num(
			GardenManager.E_GardenTool.Chocolate) >= CHOCOLATE_DROP_MAX_OWN_NUM:
		return
	if global_position.x > can_drop_x_range.y or global_position.x < can_drop_x_range.x:
		return

	var r = randf()
	if r < drop_chocolate_rate:
		EventBus.push_event(ConstEventName.CREATE_CHOCOLATE, [_get_clamp_drop_position(correct_y)])


## 掉落位置收进**看得见的范围内**（僵尸死在画面边缘时，掉出来的东西得点得着）
## 换算本身在 `DropPositionUtil`（与 DropItemManager 共用一份）：
## 以前这里直接拿视口尺寸去夹 —— 那是**视口**坐标，画布一偏移就夹错位置
func _get_clamp_drop_position(y_offset := DropPositionUtil.DROP_Y_LIFT) -> Vector2:
	return DropPositionUtil.clamp_drop_position(self, global_position - Vector2(0, y_offset))

#endregion

