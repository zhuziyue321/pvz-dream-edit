extends ResourceLevelTimelineEvent
class_name LevelTimelineEventWaitSunEnough
## 等玩家的阳光攒到 sun_value
##
## 开局就给了那么多阳光时立刻往下走（不该逼玩家白等一轮收阳光）。
## 判据是出战卡槽当前的阳光数（见 LevelWaitCondition.get_sun_value）；
## 传送带关没有出战卡槽，判据恒为 0 —— 那种关卡别用本事件。

## 要攒到的阳光数（够买一株豌豆射手 = 100）
@export var sun_value: int = 100


func run(main_game: MainGameManager) -> void:
	await wait_until(main_game, func() -> bool:
		return LevelWaitCondition.get_sun_value(main_game) >= sun_value)
