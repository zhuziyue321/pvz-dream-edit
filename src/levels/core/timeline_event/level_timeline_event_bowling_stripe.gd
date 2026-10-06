extends ResourceLevelTimelineEvent
class_name LevelTimelineEventBowlingStripe
## 保龄球红线出现（坚果保龄球关）
## 没有参数

func run(main_game: MainGameManager) -> void:
	main_game.game_item_manager.gim_other.show_bowling_stripe()
