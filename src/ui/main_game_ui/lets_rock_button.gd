extends PVZButtonBase
class_name LetsRockButton
## 「开始战斗！」按钮 —— 原版迷你游戏「坚不可摧」(Last Stand) 布阵阶段专用
##
## 布阵阶段玩家可以随便种，种好了点这个按钮才出怪（流程见 LevelTimelineEventWaitBattleStart）。
## 按钮由该事件挂到 MainGameManager.canvas_layer_ui 下，点完即 queue_free。
## 文案取自原版 lawn_strings 的 [LETS_ROCK_BUTTON]「开始战斗！」。

## 玩家是否已经点过本按钮
## 事件脚本轮询这个字段，不用 await pressed：关卡中途被销毁时 await 会永远挂着，
## 而 wait_until 会在 MainGameManager 失效的那一刻自己退出（见 ResourceLevelTimelineEvent）。
## 注意：不能叫 is_pressed，BaseButton 已有同名方法，会触发 SHADOWED_VARIABLE_BASE_CLASS 警告。
var player_pressed := false


func _ready() -> void:
	super._ready()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	player_pressed = true
	SoundManager.play_other_SFX(&"gravebutton")
