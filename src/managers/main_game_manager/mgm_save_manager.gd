extends MainGameSubManager
class_name MgmSaveManager
## 主游戏的「存档 / 读档 / 全局关卡数据」子管理器
## （原 MainGameManager 的 `#region 存档` 与 `#region 更新全局关卡数据` 两块，
##   见 docs/参考存档/重构拆分方案.md 的 B2）
##
## 谁在用它：
##   MainGameManager       —— 多轮切轮存档、进关读档、失败与通关时重置本关存档
##   主游戏菜单「重新开始」  —— re_main_game()（src/ui/ui_main_game_menu/main_game_menu_option_dialog.gd）
##   自动测试探针           —— update_level_state_data_success()

func init_manager() -> void:
	## 存档是按需调用的，没有需要在初始化阶段完成的事
	pass


#region 存档
## 读档系统只能从空白场景读档

## 存档
func save_game_main_game():
	var save_game_data_main_game:ResourceSaveGameMainGame = ResourceSaveGameMainGame.new()
	save_game_data_main_game.curr_game_round = main_game.curr_game_round
	## 植物数据
	save_game_data_main_game.plant_cell_manager_data = main_game.plant_cell_manager.get_save_game_data_plant_cell_manager()
	## 僵尸, gema_para 自动更新该值
	save_game_data_main_game.curr_max_wave = main_game.zombie_manager.zombie_wave_manager.max_wave
	save_game_data_main_game.curr_wave = main_game.zombie_manager.zombie_wave_manager.curr_wave
	## 天降阳光
	save_game_data_main_game.day_sun_curr_sun_sum_value = main_game.day_suns_manager.curr_sun_sum_value
	## 植物卡槽数据
	save_game_data_main_game.card_manager_data = main_game.card_manager.get_save_game_data_card_manager()
	## 小推车数据
	save_game_data_main_game.lawn_mover_manager_data = main_game.game_item_manager.gim_lawn_mover.get_save_game_data_lawn_mover_manager()

	var path = game_para.get_save_game_path()
	var err = ResourceSaver.save(save_game_data_main_game, path)
	if err != OK:
		Log.error("关卡数据存档失败:%s, 错误代码 %d" % [path, err])
	else:
		Log.debug(str("关卡数据存档成功：") + str(path))
		update_level_state_data_multi_round_data(true)


## 重置当前主游戏 多轮关卡存档,多轮关卡数据
func re_main_game():
	## 删除存档(若有存档会删除,没有就跳过)
	game_para.delete_game_data()
	## 更新当前关卡数据
	update_level_state_data_multi_round_data(false)


## 读档
func load_game_main_game():
	if game_para.save_game_data_main_game != null:
		main_game.curr_game_round = game_para.save_game_data_main_game.curr_game_round
		var save_game_data_main_game:ResourceSaveGameMainGame = game_para.save_game_data_main_game
		## 罐子模式每批都从空草坪重新开始，没有可恢复的植物进度，跳过读盘
		if not game_para.is_pot_mode:
			main_game.plant_cell_manager.load_game_data_plant_cell_manager(save_game_data_main_game.plant_cell_manager_data)
		## 天降阳光
		main_game.day_suns_manager.curr_sun_sum_value = save_game_data_main_game.day_sun_curr_sun_sum_value
		## 植物卡槽数据
		main_game.card_manager.load_game_data_card_manager(save_game_data_main_game.card_manager_data)
#endregion


#region 更新全局关卡数据
## 更新当前关卡数据 (完成)
func update_level_state_data_success():
	## 更新全局关卡数据
	var curr_level_state_data:Dictionary = Global.global_game_state.curr_all_level_state_data.get(game_para.save_game_name, {})
	curr_level_state_data["IsSuccess"] = true
	Global.global_game_state.curr_all_level_state_data[game_para.save_game_name] = curr_level_state_data
	## 冒险模式通关后解锁该关对应的植物
	unlock_plant_on_level_success()
	unlock_item_on_level_success()
	## 钉耙:本关放下了钉耙就消耗一次使用次数(原版: 没踩到也算用掉)
	main_game.game_item_manager.gim_rake.consume_rake_use_on_level_success()
	Global.save_service.save_now()


## 通关冒险模式关卡后,解锁该关对应的植物
func unlock_plant_on_level_success() -> void:
	## Global 是自动加载节点(无 class_name),不能用 := 推断,这里显式声明类型
	var adventure_level: int = Global.global_game_state.get_adventure_level_on_save_game_name(game_para.save_game_name)
	if adventure_level <= 0:
		return
	var new_unlock: Array[CharacterRegistry.PlantType] = Global.global_game_state.unlock_plant_on_adventure_level(adventure_level)
	for plant_type:CharacterRegistry.PlantType in new_unlock:
		Log.debug(str("通关解锁新植物: ") + str(Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)))


## 通关冒险模式关卡后,检查本关是否让玩家拿到新道具(目前只有铲子: 通关 1-4)
## 必须在 update_level_state_data_success 写进 IsSuccess 之后调用,因为解锁进度是从通关进度推导的
func unlock_item_on_level_success() -> void:
	var adventure_level: int = Global.global_game_state.get_adventure_level_on_save_game_name(game_para.save_game_name)
	if adventure_level != ConstUnlockLevel.SHOVEL_UNLOCK_ADVENTURE_LEVEL:
		return
	if not Global.global_game_state.is_shovel_unlocked():
		return
	Log.debug(str("通关") + str(ConstUnlockLevel.get_adventure_level_name(adventure_level)) + str(" 获得新道具: 铲子"))


## 更新当前关卡数据 (多轮游戏)
func update_level_state_data_multi_round_data(is_have_multi_round_data:=true):
	## 更新全局关卡数据
	var curr_level_state_data:Dictionary = Global.global_game_state.curr_all_level_state_data.get(game_para.save_game_name, {})
	curr_level_state_data["IsHaveMultiRoundSaveGameData"] = is_have_multi_round_data
	curr_level_state_data["CurrGameRound"] = main_game.curr_game_round
	Global.global_game_state.curr_all_level_state_data[game_para.save_game_name] = curr_level_state_data
	Global.save_service.save_now()
#endregion
