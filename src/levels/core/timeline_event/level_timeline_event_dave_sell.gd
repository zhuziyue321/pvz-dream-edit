extends ResourceLevelTimelineEvent
class_name LevelTimelineEventDaveSell
## 戴夫推销卡槽扩充（冒险模式商店解锁前，见 DaveSellManager）
## 没有参数：非冒险模式这个事件什么都不做（DaveSellManager 自己会判断）

func run(main_game: MainGameManager) -> void:
	if main_game.dave_sell_manager == null:
		main_game.init_dave_sell_manager()
	await main_game.dave_sell_manager.start_sell_flow()
