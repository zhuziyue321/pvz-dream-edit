extends ResourceLevelTimelineEvent
class_name LevelTimelineEventSpawnSun
## 生成一颗阳光：从天上掉下来，落地的那一刻起才能被点
##
## 教学要靠它给玩家东西收（原版 1-1：先掉一颗阳光，教玩家点阳光）。
## 关卡自己的天降阳光是「开战」事件里启动的定时器，本事件掉的是单独一颗，跟那个定时器无关。
## 没有参数

func run(main_game: MainGameManager) -> void:
	if main_game.day_suns_manager == null:
		return
	main_game.day_suns_manager.spawn_sun()
	## 阳光从天上掉下来要点时间，先看它落地再往下走（否则箭头会指空）
	await wait_seconds(main_game, 0.5)
