extends ResourceLevelTimelineEvent
class_name LevelTimelineEventDaveDialog
## 戴夫对话：播一段戴夫对话，戴夫离场才算本事件结束
##
## **说什么是流程的事** —— run_flow() 里 `await dave_dialog(对话)` 现场给
## （关卡脚本把对话放在流程里构造，不再往 crazy_dave_dialog 字段上赋值）。
## 没传时才回落到关卡资源上「本轮」的对话（第 1 轮 `crazy_dave_dialog`，
## 第 2 轮起 `crazy_dave_dialog_next_round`，见 get_crazy_dave_dialog_on_round），
## 老 .tres 关卡照旧。
## 本轮没配对话就直接结束本事件（戴夫不来）；「只播一次」的跳过判定见
## MainGameManager.is_skip_level_dave_dialog。

## 流程现场指定的对话（dave_dialog(对话)）；留空时取关卡资源上本轮的对话
var dialog_resource: CrazyDaveDialogResource


func run(main_game: MainGameManager) -> void:
	var dialog := dialog_resource
	if dialog == null:
		dialog = main_game.game_para.get_crazy_dave_dialog_on_round(main_game.curr_game_round)
	if dialog == null:
		return
	if main_game.is_skip_level_dave_dialog():
		return
	await main_game.play_crazy_dave_dialog(dialog)
