extends ResourceLevelTimelineEvent
class_name LevelTimelineEventWaitPlant
## 等玩家种下几株植物
##
## 判据是「草坪上这种植物的数量**比等待开始时多了几株**」（见 LevelWaitCondition.count_lawn_plants）：
## 记基准数再数差值，所以场上本来就有植物也不影响（1-5 那种预置植物的关卡照样能等）。
##
## plant_type 留 Null = 种什么都算过了；写上就是「非这种植物不算」。
## timeout > 0 时是**限时等待**：时限内种下了才往下走，到点还没动手也往下走 ——
## 结果在 is_planted 里（关卡流程据此决定要不要补一句教学，见 LevelScriptBase.wait_plant_timeout）。

## 指定要种的植物；留 Null 表示任意植物
@export var plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null
## 要种几株才算过（同一种植物可以连种几株）
@export var count: int = 1
## 最多等几秒；0 = 一直等到玩家种下为止
@export var timeout: float = 0.0

## 等待结果：true = 玩家种下了；false = 超时或关卡已经没了（给了 timeout 才看这一项）
var is_planted := false


func run(main_game: MainGameManager) -> void:
	is_planted = false
	var need_num := maxi(1, count)
	var start_num := LevelWaitCondition.count_lawn_plants(main_game, plant_type)
	var is_done := func() -> bool:
		return LevelWaitCondition.count_lawn_plants(main_game, plant_type) >= start_num + need_num
	if timeout > 0.0:
		is_planted = await _wait_timeout(main_game, is_done, timeout)
		return
	await wait_until(main_game, is_done)
	is_planted = true


## 限时等一个条件：成立返回 true，到点 / 关卡没了返回 false
func _wait_timeout(main_game: MainGameManager, condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			return true
		await wait_seconds(main_game, POLL_STEP)
		if not is_instance_valid(main_game):
			return false
		waited += POLL_STEP
	return condition.call()
