extends Node

## 游戏暂停因素
##
## ⚠️ **本类与 `process_mode = PROCESS_MODE_ALWAYS` 是互补关系，不是两套重复的暂停机制**
## （U-12 曾误判成「TreePauseManager 形同虚设 + 25 个文件各写各的」，核实后不成立）：
##   - **本类管整棵树**：任一因素为真 → `get_tree().paused = true`，全场停。
##     调用方共 10 处，集中在菜单 / 游戏结束 / 重新选卡三个因素上
##     （`main_game_menu_option_dialog` `mgm_lose_manager` `main_game_manager`
##      `zombiquarium_manager` `zm_boss_registry` `mgm_reward_manager`）。
##   - **`process_mode = ALWAYS` 全仓只有 5 处，且每一处都是「全场暂停时仍要跑」的豁免**：
##     相机、卡槽（重新选卡时要能操作）、联机准备按钮、调试通道
##     —— 见 `main_game_manager.gd:589`、`mgm_lose_manager.gd:57`、
##     `netplay_ready_flow.gd:51`、`debug_channel.gd:67`。
## 所以别把两者当成「该统一成一套」的东西：一个负责停全场，一个负责把个别节点摘出去。
enum E_PauseFactor {
	Menu,			## 菜单
	GameOver,		## 游戏结束
	ReChooseCard,	## 重新选卡
}

var curr_pause_factor: Dictionary = {}

func _update_pause_state() -> void:
	get_tree().paused = curr_pause_factor.values().any(func(v): return v)
	if get_tree().paused:
		Log.debug("暂停游戏")
	else:
		Log.debug("继续游戏")

## 开始场景树暂停
func start_tree_pause(pause_factor: E_PauseFactor) -> void:
	curr_pause_factor[pause_factor] = true
	_update_pause_state()

## 结束场景树暂停
func end_tree_pause(pause_factor: E_PauseFactor) -> void:
	curr_pause_factor[pause_factor] = false
	_update_pause_state()

## 清除所有暂停因素
func end_tree_pause_clear_all_pause_factors() -> void:
	curr_pause_factor.clear()
	_update_pause_state()
