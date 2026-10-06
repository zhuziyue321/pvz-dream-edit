extends ResourceLevelTimelineEvent
class_name LevelTimelineEventAllowOperation
## 允许操作：放开玩家的手 —— 能点卡槽里的卡片、能种植、能收阳光、能拿铲子
##
## 它只做「放行」，**不开战**：这一刻还不出怪、不天降阳光、不生成墓碑
## （那些是「开战」事件的事，见 LevelTimelineEventStartBattle）。
## 教学要让玩家先动手，就用它把「能操作」排在「开打」之前
## （原版 1-1 的教学整段都发生在开打之前）。
##
## 实现上就是推进到 MAIN_GAME 阶段 + 放出出战卡槽，判据见 MainGameManager.allow_lawn_operation。
## 没有参数

func run(main_game: MainGameManager) -> void:
	await main_game.allow_lawn_operation()
