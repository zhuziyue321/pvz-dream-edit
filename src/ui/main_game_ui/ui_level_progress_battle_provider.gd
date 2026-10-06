extends LevelProgressProvider
class_name LevelProgressBattleProvider
## 默认数据源：进度条 = 战斗进度（波次走到第几波 + 本波走过多久）
##
## 战斗进度的本体在出怪侧（波次管理器，或关卡注入的出怪器 —— 见 ZombieManager 的「波次进度」区），
## 这里只做转发：出怪侧算好百分比，本源每帧读一次，进度条节点一概不碰。


func get_progress() -> float:
	var zombie_manager := _zombie_manager()
	if zombie_manager == null:
		return 0.0
	return zombie_manager.get_battle_progress()


func is_bar_visible() -> bool:
	var zombie_manager := _zombie_manager()
	if zombie_manager == null:
		return false
	return zombie_manager.is_battle_started()


func get_flag_num() -> int:
	var zombie_manager := _zombie_manager()
	if zombie_manager == null:
		return 0
	return zombie_manager.get_battle_flag_num()


func take_flag_raise_index() -> int:
	var zombie_manager := _zombie_manager()
	if zombie_manager == null:
		return -1
	return zombie_manager.take_battle_flag_raise_index()


func take_flag_reset() -> bool:
	var zombie_manager := _zombie_manager()
	if zombie_manager == null:
		return false
	return zombie_manager.take_battle_flag_reset()


func _zombie_manager() -> ZombieManager:
	if controller == null or not is_instance_valid(controller.main_game):
		return null
	return controller.main_game.zombie_manager
