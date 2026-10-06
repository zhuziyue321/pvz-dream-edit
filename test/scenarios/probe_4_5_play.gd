extends RefCounted
## 探针：冒险模式 4-5 砸罐子关（Vasebreaker）实机冒烟
## 走一遍「戴夫开场对话 → 砸光第 1 批（3 列 x 5 行 = 15 个罐子）→ 戴夫再摆第 2 批」，
## 校验：罐子里开出来的东西符合该批配置、切换批次清空场地与卡片、第 2 批有 2 个戴夫提示罐。

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
	a.log("[4-5] 第 1 批罐子数=%d 占列=%s 提示罐=%d" % [
		pcm.curr_pot_num, str(_pot_cols(pcm)), _hint_num(pcm)])

	## 戴夫开场对话 3 句：点够次数让他讲完离场
	for i in range(4):
		var clicked: bool = await a.click_first("DaveDialogMousePressPanel")
		if not clicked:
			break
		await a.wait(1.0)
	await a.wait(2.0)
	await a.dump("戴夫开场对话结束")

	## 砸光第 1 批（3 列 x 5 行）
	for row in range(5):
		for col in [8, 7, 6]:
			await a.click_plant_cell(row, col)
			await a.wait(0.25)
	await a.wait(1.0)
	a.log("[4-5] 砸光后 罐子数=%d 阶段=%d 临时卡片=%d" % [
		pcm.curr_pot_num, Global.main_game.main_game_progress,
		Global.main_game.card_manager.curr_temp_cards.size()])
	await a.dump("砸光第 1 批罐子")

	## 走一次「下一批罐子」：戴夫先说话，再摆上第 2 批
	EventBus.push_event("start_next_round_game")
	await a.wait(3.0)
	for i in range(7):
		var clicked2: bool = await a.click_first("DaveDialogMousePressPanel")
		if not clicked2:
			break
		await a.wait(1.0)
	await a.wait(3.0)
	a.log("[4-5] 轮次=%d 第 2 批罐子数=%d 占列=%s 提示罐=%d 临时卡片=%d 已种植物=%d" % [
		Global.main_game.curr_game_round, pcm.curr_pot_num, str(_pot_cols(pcm)), _hint_num(pcm),
		Global.main_game.card_manager.curr_temp_cards.size(), _plant_num(pcm)])
	await a.dump("第 2 批罐子")
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


## 场上绿色植物罐（戴夫提示罐）的个数
func _hint_num(pcm) -> int:
	var num := 0
	for row in pcm.all_plant_cells:
		for cell in row:
			if is_instance_valid(cell.pot) and cell.pot.pot_type == ScaryPot.E_PotType.Plant:
				num += 1
	return num


## 场上已经种下植物的格子数
func _plant_num(pcm) -> int:
	var num := 0
	for row in pcm.all_plant_cells:
		for cell in row:
			if cell.get_curr_plant_num() > 0:
				num += 1
	return num
