extends RefCounted
## 探针：冒险模式 4-5 砸罐子关（Vasebreaker）**完整流程**（带窗口跑）
## 走真实胜利条件：砸光本批罐子 → 打光僵尸 → 戴夫说话 → 摆下一批，连打三批。
## 校验：每批的罐子数 / 占列 / 绿罐个数（第 1 批 0、第 2 批 2、第 3 批 3），
## 以及切完轮次后第 1 批的配置没有被后面几批顶掉（重玩时第 1 批还是 3 列 15 罐）。

const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_04_05.gd"


func run(a) -> void:
	var para: Resource = (load(LEVEL_PATH) as GDScript).new()
	if para == null:
		a.log("[4-5] !! 关卡资源加载失败")
		a.finish(true)
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(5.0)
	if Global.main_game == null:
		a.log("[4-5] !! 主游戏未创建")
		a.finish(true)
		return
	var pcm = Global.main_game.plant_cell_manager

	## 开场戴夫对话
	for i in range(4):
		if not await a.click_first("DaveDialogMousePressPanel"):
			break
		await a.wait(1.0)
	await a.wait(2.0)
	_log_batch(a, pcm, 1)

	## 连打三批
	for round_i in [2, 3]:
		await _break_all_pots(a, pcm)
		EventBus.push_event("test_death_all_zombie")
		await a.wait(5.0)
		## 戴夫「再给你一批」的对话
		for i in range(8):
			if not await a.click_first("DaveDialogMousePressPanel"):
				break
			await a.wait(1.0)
		await a.wait(3.0)
		_log_batch(a, pcm, round_i)

	await a.dump("三批罐子打完")
	a.finish(true)


## 砸光场上所有罐子
func _break_all_pots(a, pcm) -> void:
	for row in range(pcm.all_plant_cells.size()):
		for col in range(pcm.all_plant_cells[row].size()):
			var cell = pcm.all_plant_cells[row][col]
			if is_instance_valid(cell.pot):
				await a.click_plant_cell(row, col)
				await a.wait(0.15)


## 打印本批罐子的实际情况，并顺带验一遍「第 1 批配置没被污染」
func _log_batch(a, pcm, round_i: int) -> void:
	var green := 0
	var brown := 0
	for row in pcm.all_plant_cells:
		for cell in row:
			if not is_instance_valid(cell.pot):
				continue
			if cell.pot.pot_type == ScaryPot.E_PotType.Plant:
				green += 1
			else:
				brown += 1
	a.log("[4-5] 第 %d 批 轮次=%d 罐子数=%d 占列=%s 绿罐=%d 棕罐=%d" % [
		round_i, Global.main_game.curr_game_round, pcm.curr_pot_num, str(_pot_cols(pcm)), green, brown])
	## 切到第 2 / 3 批之后，第 1 批的配置必须还是 3 列 15 罐 0 提示
	var para = Global.main_game.game_para
	para.init_para()
	a.log("[4-5]   重算第 1 批配置：列=%s 罐子数=%d 提示罐=%d" % [
		str(para.pot_col_range), para.pot_num_on_fixed_mode, para.pot_hint_num])
	if round_i < 3:
		para.apply_pot_config_on_round(Global.main_game.curr_game_round)


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
