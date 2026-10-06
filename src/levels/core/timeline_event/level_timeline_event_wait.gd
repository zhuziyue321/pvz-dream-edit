extends ResourceLevelTimelineEvent
class_name LevelTimelineEventWait
## 纯等待固定秒数（走场景树计时器，游戏暂停时一起停）
##
## 参数：
##   wait_time —— 等待秒数

@export var wait_time: float = 1.0


func run(main_game: MainGameManager) -> void:
	await wait_seconds(main_game, wait_time)
