extends ResourceLevelTimelineEvent
class_name LevelTimelineEventReadySetPlant
## 「准备…安放…植物」红字（见 MainGameManager.ready_set_plant）
## 默认排在开战之前；砸罐子关不生成这个事件（罐子摆好就能直接砸）
## 没有参数

func run(main_game: MainGameManager) -> void:
	await main_game.ready_set_plant()
