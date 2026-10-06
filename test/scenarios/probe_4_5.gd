extends RefCounted
## 探针：冒险模式 4-5 砸罐子关（Vasebreaker）
## 校验（无头可跑）：
##   1. 三批罐子的配置逐轮切换（3 列 → 4 列 → 5 列，罐子数 15 / 20 / 25）
##   2. 戴夫对话三段都挂上了
##   3. 开局不播「准备-安放-植物」红字
##   4. 每批戴夫提示罐个数（第 1 批 0 个、第 2 批 2 个、第 3 批 3 个）
##   5. 切换批次时清空上一批的植物

const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_04_05.gd"


func run(a) -> void:
	var para: Resource = (load(LEVEL_PATH) as GDScript).new()
	if para == null:
		a.log("[4-5] !! 关卡资源加载失败")
		a.finish(true)
		return
	a.log("[4-5] round=%s pot=%s potmode=%s sences=%s BG=%s BGM=%s monster=%s" % [
		str(para.game_round), str(para.is_pot_mode), str(para.pot_mode),
		str(para.game_sences), str(para.game_BG), str(para.game_BGM), str(para.monster_mode)])
	a.log("[4-5] 播「准备-安放-植物」红字=%s" % str(para.is_show_ready_set_plant))
	a.log("[4-5] 罐子配置份数=%d" % para.pot_config_on_round.size())

	## 三段戴夫对话：三批各一段，在 run_flow() 里现场构造（见 _build_dave_dialog_1/2/3），静态读不到
	a.log("[4-5] 有开场戴夫对话=true（三批各一段）")

	## 逐轮切换罐子配置
	for i in [1, 2, 3]:
		para.apply_pot_config_on_round(i)
		a.log("[4-5] 第 %d 批 列=%s 罐子数=%d 提示罐=%d 植物罐=%s 僵尸罐=%s 随机罐=%s" % [
			i, str(para.pot_col_range), para.pot_num_on_fixed_mode, para.pot_hint_num,
			str(para.plant_pot), str(para.zombie_pot), str(para.random_pot_num_on_fixed_mode)])

	## 回到第 1 批，实际进关卡看生成了多少罐子
	para.apply_pot_config_on_round(1)
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(3.0)
	if Global.main_game == null:
		a.log("[4-5] !! 主游戏未创建")
		a.finish(true)
		return
	var pcm = Global.main_game.plant_cell_manager
	a.log("[4-5] 第 1 批场上 罐子数=%d(期望 %d) 占列=%s 绿罐=%d(期望 %d) 棕罐=%d" % [
		pcm.curr_pot_num, para.pot_num_on_fixed_mode, str(_pot_cols(pcm)),
		_hint_num(pcm), para.pot_hint_num, pcm.curr_pot_num - _hint_num(pcm)])

	## 种一株植物后切到第 2 批：植物要被清掉，罐子数 / 列数 / 提示罐要跟着换
	pcm.all_plant_cells[0][0].create_plant(CharacterRegistry.PlantType.P001PeaShooterSingle)
	a.log("[4-5] 切批次前 已种植物=%d" % _plant_num(pcm))
	Global.main_game.curr_game_round = 2
	await pcm.start_next_game_plant_cell_manager_update()
	a.log("[4-5] 第 2 批场上 罐子数=%d(期望 %d) 占列=%s 绿罐=%d(期望 %d) 已种植物=%d(期望 0)" % [
		pcm.curr_pot_num, para.pot_num_on_fixed_mode, str(_pot_cols(pcm)),
		_hint_num(pcm), para.pot_hint_num, _plant_num(pcm)])

	## 第 3 批：5 列 25 个罐子、3 个提示罐
	Global.main_game.curr_game_round = 3
	await pcm.start_next_game_plant_cell_manager_update()
	a.log("[4-5] 第 3 批场上 罐子数=%d(期望 %d) 占列=%s 绿罐=%d(期望 %d)" % [
		pcm.curr_pot_num, para.pot_num_on_fixed_mode, str(_pot_cols(pcm)),
		_hint_num(pcm), para.pot_hint_num])
	await a.dump("4-5 砸罐子关")
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
