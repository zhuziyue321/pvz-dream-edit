extends ResourceLevelTimelineEvent
class_name LevelTimelineEventSystemPlant
## 系统种植植物：不经过玩家操作，由系统直接在指定格子种下植物
##
## 用于关卡中途补种 / 摆造型（比如某批开打前系统送一排坚果、砸罐子关摆一排植物当障碍），
## 也用于开局就有的植物（屋顶铺花盆、1-5 教程要铲掉的那几株豌豆射手）——
## 关卡脚本在 run_flow() 里 `await system_plant(...)` 走的就是这条事件。
##
## `plants` 每项的 `plant_cell_pos` 从 1 开始，0 表示整行 / 整列：
##   (0,0) 满屏 / (0,y) 第 y 列 / (x,0) 第 x 行 / (x,y) 第 x 行第 y 列
## 种法见 PlantCellManager.system_plant_one。

## 要种下的植物：系统种，不消耗阳光、不需要卡片、不走手牌
@export var plants: Array[SystemPlantResource] = []


func run(main_game: MainGameManager) -> void:
	for plant_data in plants:
		main_game.plant_cell_manager.system_plant_one(plant_data)
	## 稍等一下，让种出来的植物在画面上出现之后再走下一个事件
	await wait_seconds(main_game, 0.05)
