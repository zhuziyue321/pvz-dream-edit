extends ResourceLevelTimelineEvent
class_name LevelTimelineEventClearField
## 清场：清掉上一批的残留（植物 / 没砸开的罐子），再按本轮配置摆出新的一批
## 多轮砸罐子关每批的罐子配置不一样（原版冒险 4-5：3 / 4 / 5 列），切配置也在这步里
## （见 PlantCellManager.start_next_game_plant_cell_manager_update）
## 没有参数

func run(main_game: MainGameManager) -> void:
	await main_game.plant_cell_manager.start_next_game_plant_cell_manager_update()
	main_game.game_item_manager.start_next_game_game_item_manager_update()
