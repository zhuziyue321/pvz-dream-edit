extends ResourceLevelTimelineEvent
class_name LevelTimelineEventWaitCollectSun
## 等玩家点掉一颗阳光
##
## 判定靠 EventBus "add_sun_value"（点阳光是瞬间动作），不靠「阳光数变多了」——
## 同一个事件里卡槽也在加数值，用数值判定会被别的加阳光途径误触发
## （例如小游戏每波送阳光，见 minigame_16_last_stand）。
## 没有参数

var _is_collected := false


func run(main_game: MainGameManager) -> void:
	_is_collected = false
	EventBus.subscribe("add_sun_value", _on_add_sun_value)
	await wait_until(main_game, func(): return _is_collected)
	EventBus.unsubscribe("add_sun_value", _on_add_sun_value)


func _on_add_sun_value(_sun_value: int) -> void:
	_is_collected = true
