extends ResourceLevelTimelineEvent
class_name LevelTimelineEventLawnMover
## 初始化小推车（关卡流程里排在「准备…安放…植物」之前）
##
## 做什么：按地图数据 / 存档给每行生成推车 —— 推车**出生在屏幕外左侧**，
## 再按**从下到上**的顺序依次发车开到位（见 GIM_LawnMover.init_or_replenish_lawn_movers / play_appear_animation）
##
## **不阻塞流程**：事件发完车就返回，不去等最后一辆到位（推车是在「准备…安放…植物」
## 那几秒里自己开进来的）；结束条件 —— 立刻
## 本关没开推车（is_lawn_mover = false）时直接 return
## 没有参数

func run(main_game: MainGameManager) -> void:
	var gim := main_game.game_item_manager.gim_lawn_mover
	if gim == null or not main_game.game_para.is_lawn_mover:
		return
	gim.init_or_replenish_lawn_movers()
	## 只发车、不等车：推车在后面自己开进来，流程继续走「准备…安放…植物」
	gim.play_appear_animation()
	
