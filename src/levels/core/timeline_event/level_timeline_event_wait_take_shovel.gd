extends ResourceLevelTimelineEvent
class_name LevelTimelineEventWaitTakeShovel
## 等玩家把铲子拿在手上（原版 1-5 铲子教学第一步）
##
## 铲子没有「拿起」事件，只能按帧问手持物类型（见 LevelWaitCondition.is_holding_shovel）。
## 玩家手上已经拿着铲子时立刻往下走。
## 没有参数

func run(main_game: MainGameManager) -> void:
	await wait_until(main_game, func() -> bool:
		return LevelWaitCondition.is_holding_shovel(main_game))
