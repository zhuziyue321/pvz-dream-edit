extends ResourceLevelTimelineEvent
class_name LevelTimelineEventWaitBattleStart
## 布阵阶段：先放开玩家的手（能拿卡 / 能种植），右下角放一个「开始战斗！」按钮，
## 玩家点它本事件才结束（下一个事件通常是「开战」）
##
## 原版迷你游戏「坚不可摧」(Last Stand)：开局给一大笔阳光，玩家把防线种满之后自己点按钮开打。
## 本阶段**不开战**：不出怪、不天降阳光，玩家想布多久就布多久
## （出怪 / 天降阳光都是「开战」事件的事，见 MainGameManager.main_game_start）。
## 没有参数

## 布阵阶段的提示文本（原版是按钮上的字，这里再补一句给没注意到按钮的玩家）
const ADVICE_BUILD_PHASE := "先把防线种好，再点击右下角的「开始战斗！」"


func run(main_game: MainGameManager) -> void:
	## 先允许操作：出战卡槽进场、玩家能种植物（判据见 MainGameManager.allow_lawn_operation）
	await main_game.allow_lawn_operation()
	if not is_instance_valid(main_game):
		return

	var button: LetsRockButton = SceneRegistry.LETS_ROCK_BUTTON.instantiate()
	main_game.canvas_layer_ui.add_child(button)
	var advice_ui: TutorialAdviceUI = SceneRegistry.TUTORIAL_ADVICE.instantiate()
	main_game.canvas_layer_ui.add_child(advice_ui)
	advice_ui.show_advice(ADVICE_BUILD_PHASE)

	## 轮询等玩家点按钮：不用 await button.pressed —— 关卡中途被销毁时那个 await 永远不返回，
	## 而 wait_until 会在 MainGameManager 失效的那一刻自己退出（见 ResourceLevelTimelineEvent）
	await wait_until(main_game,
		func(): return not is_instance_valid(button) or button.player_pressed, 0.0)

	if is_instance_valid(advice_ui):
		advice_ui.queue_free()
	if is_instance_valid(button):
		button.queue_free()
