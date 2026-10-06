extends ResourceLevelTimelineEvent
class_name LevelTimelineEventWaitDigPlant
## 等玩家用铲子铲掉植物
##
## 判据是「草坪上的植物**比等待开始时少了几株**」（见 LevelWaitCondition.count_lawn_plants），
## is_dig_all 勾上就是「铲光为止」（原版 1-5：铲光草坪才轮到保龄球）。
## 铲一株就用掉一把铲子，铲下一株要玩家重新去拿 —— 那是玩家自己的事，本事件只数数量。

## 要铲掉几株才算过
@export var count: int = 1
## 勾上 = 等到草坪上一株植物都不剩（忽略 count）
@export var is_dig_all: bool = false


func run(main_game: MainGameManager) -> void:
	if is_dig_all:
		await wait_until(main_game,
			func() -> bool: return LevelWaitCondition.count_lawn_plants(main_game) <= 0)
		return
	var need_num := maxi(1, count)
	var start_num := LevelWaitCondition.count_lawn_plants(main_game)
	await wait_until(main_game, func() -> bool:
		return start_num - LevelWaitCondition.count_lawn_plants(main_game) >= need_num)
