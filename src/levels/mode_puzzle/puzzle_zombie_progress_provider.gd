extends LevelProgressProvider
class_name PuzzleZombieProgressProvider
## 我是僵尸（解谜模式「僵尸公敌」10 关共用）的关卡进度条数据源：
## **进度条 = 已吃脑子数 / 5**（原版 `I_ZOMBIE_WINNING_SCORE` = 5，原版就在进度条位置显示这个计数）。
##
## 吃脑子本体在 `GIM_Brain`（每行 1 个脑子，被啃死 +1，无尽切轮重建时清零），
## 这里每帧读一次换算成百分比；分母 = 本轮脑子总数（场上存活 + 已吃，正常就是 5）。
## 本关没有波次 → 不画旗帜；只有开战进入主游戏阶段才显示，
## 开场铺红线前与通关 / 判负结算后都藏起来，不留一条孤儿进度条（口径同僵尸迷阵）。
## 10 关共用一份 → 按硬约束 §1-8 上浮成数据源类，与关卡脚本同目录。

## 文字里的名目（原版 `Board::DrawProgressMeter` 的 `[BRAINS]`，data/strings/lawn_strings.txt）
const PROGRESS_TEXT_BRAINS := "吃掉的脑子"


func get_progress() -> float:
	var brain := _gim_brain()
	if brain == null:
		return 0.0
	var total: int = brain.eaten_brain_num + brain.curr_brain_num
	if total <= 0:
		return 0.0
	return clampf(float(brain.eaten_brain_num) / float(total) * 100.0, 0.0, 100.0)


## 原版 `Board::DrawProgressMeter`：进度条正中画「{已吃}/{总数} [BRAINS]」
## （`Challenge.cpp:4563 IZombieScoreBrain` 计数，[BRAINS] = 「吃掉的脑子」）
func get_progress_text() -> String:
	var brain := _gim_brain()
	if brain == null:
		return ""
	return "%d/%d %s" % [brain.eaten_brain_num, brain.eaten_brain_num + brain.curr_brain_num, PROGRESS_TEXT_BRAINS]


func is_bar_visible() -> bool:
	if controller == null or not is_instance_valid(controller.main_game):
		return false
	return controller.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME


## 本关没有波次 → 进度条上不画旗帜
func get_flag_num() -> int:
	return 0


func _gim_brain() -> GIM_Brain:
	if controller == null or not is_instance_valid(controller.main_game):
		return null
	return controller.main_game.game_item_manager.gim_brain
