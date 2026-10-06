extends ResourceLevelTimelineEvent
class_name LevelTimelineEventChooseCard
## 选卡：等玩家点「开始游戏」
## 玩家没有选卡权时（卡槽被锁死 / 被预选卡填满）等价于直接点了开始，立刻结束本事件
## 没有参数

func run(main_game: MainGameManager) -> void:
	main_game.is_timeline_waiting_choose_card = true
	await main_game.enter_choose_card_progress()
	## 还在等（玩家没点开始）就等到选卡面板收完的通知
	if main_game.is_timeline_waiting_choose_card:
		await main_game.signal_choose_card_finished
	main_game.is_timeline_waiting_choose_card = false
