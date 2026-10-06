extends RefCounted
## 探针：冒险模式 4-5 砸罐子关「不按批次存档 / 读档」
## 校验（无头可跑）：
##   1. 伪造一份「第 3 批已经打完」的存档后进关，轮次仍是 1、场上是第 1 批（3 列 15 罐）
##   2. 进关时历史存档文件被清掉（选关界面的「第 N 轮」标记也一起清）
##   3. 切到第 2 批时不写新的存档文件（下次进关不会跳批）

const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_04_05.gd"


func run(a) -> void:
	var para: Resource = (load(LEVEL_PATH) as GDScript).new()
	if para == null:
		a.log("[4-5-save] !! 关卡资源加载失败")
		a.finish(true)
		return
	para.save_game_name = "101_3_0035"
	Global.game_para = para
	## autopilot 的用户目录是临时目录、没有登录用户，先造一个用户和存档目录出来
	Global.user_manager.set_current_user("1")
	DirAccess.make_dir_recursive_absolute("user://1/main_game_saves_data")

	## 伪造一份「第 3 批已经打完」的存档
	var save := ResourceSaveGameMainGame.new()
	save.curr_game_round = 3
	var path: String = para.get_save_game_path()
	var err := ResourceSaver.save(save, path)
	a.log("[4-5-save] 存档路径=%s 伪造结果=%d 存在=%s" % [path, err, str(ResourceLoader.exists(path))])

	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(5.0)
	if Global.main_game == null:
		a.log("[4-5-save] !! 主游戏未创建")
		a.finish(true)
		return
	var pcm = Global.main_game.plant_cell_manager
	a.log("[4-5-save] 进关后 轮次=%d(期望 1) 罐子数=%d(期望 %d) 占列=%s(期望 3 列) 存档仍存在=%s(期望 false)" % [
		Global.main_game.curr_game_round, pcm.curr_pot_num, para.pot_num_on_fixed_mode,
		str(_pot_cols(pcm)), str(ResourceLoader.exists(path))])

	## 切到第 2 批：不写存档
	Global.main_game.curr_game_round = 2
	await pcm.start_next_game_plant_cell_manager_update()
	a.log("[4-5-save] 切到第 2 批后 罐子数=%d(期望 %d) 存档存在=%s(期望 false)" % [
		pcm.curr_pot_num, para.pot_num_on_fixed_mode, str(ResourceLoader.exists(path))])
	await a.dump("4-5 不按批次存档")
	a.finish(true)


## 场上罐子占了哪些列
func _pot_cols(pcm) -> Array:
	var cols: Array = []
	for row in pcm.all_plant_cells:
		for cell in row:
			if is_instance_valid(cell.pot):
				var col: int = cell.row_col.y
				if not cols.has(col):
					cols.append(col)
	cols.sort()
	return cols
