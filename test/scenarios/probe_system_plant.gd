extends RefCounted
## 探针：时间轴「系统种植植物」事件（LevelTimelineEventSystemPlant）
## 覆盖：
##   1. 事件脚本能实例化，事件类型与中文名在 ConstLevelData 里注册过
##   2. 进 1-1 后跑一次这个事件：指定格子长出配置的植物（单格语义）
##   3. plant_cell_pos 的整行语义（y=0）：整行都种上
##   4. 越界坐标被跳过，不报错
## 机器可读汇总：最后一行 [SYSTEMPLANT] result=PASS|FAIL failed=<n>

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：系统种植植物事件 ==========")

	# ------------------------------------------------ STEP1 事件脚本本身
	var event := LevelTimelineEventSystemPlant.new()
	_check(a, "事件脚本可实例化", event != null)
	## 一种事件 = 一个脚本，事件的身份就是脚本类名（不再有集中的事件类型枚举）
	var script: Script = event.get_script()
	_check(a, "事件身份 = 脚本类名 LevelTimelineEventSystemPlant",
		str(script.get_global_name()) == "LevelTimelineEventSystemPlant",
		"实际=%s" % str(script.get_global_name()))

	# ------------------------------------------------ STEP2 进 1-1
	var state = Global.global_game_state
	state.curr_plant.assign([CharacterRegistry.PlantType.P001PeaShooterSingle])
	state.curr_all_level_state_data = {}
	if not await _goto_level(a):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	if not await _wait_main_game(a, 40.0):
		a.log("!! 没进到 MAIN_GAME 阶段")
		_finish(a)
		return
	await a.wait(1.0)

	var mg = Global.main_game
	var pcm = mg.plant_cell_manager
	a.log("  场地 %d 行 x %d 列" % [pcm.all_plant_cells.size(), pcm.all_plant_cells[0].size()])

	# ------------------------------------------------ STEP3 配一次事件并跑
	var single := SystemPlantResource.new()
	single.plant_type = CharacterRegistry.PlantType.P002SunFlower
	single.plant_cell_pos = Vector2i(1, 1)			## 第 1 行第 1 列
	var whole_row := SystemPlantResource.new()
	whole_row.plant_type = CharacterRegistry.PlantType.P004WallNut
	whole_row.plant_cell_pos = Vector2i(2, 0)		## 第 2 行整行
	var out_of_range := SystemPlantResource.new()	## 越界：应当被跳过
	out_of_range.plant_type = CharacterRegistry.PlantType.P001PeaShooterSingle
	out_of_range.plant_cell_pos = Vector2i(99, 99)
	var plants: Array[SystemPlantResource] = [single, whole_row, out_of_range]
	event.plants = plants
	await event.run(mg)

	# ------------------------------------------------ STEP4 检查种出来的东西
	var cell_00: PlantCell = pcm.all_plant_cells[0][0]
	var plant_00 = cell_00.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	_check(a, "第1行第1列长出植物", plant_00 != null and is_instance_valid(plant_00))
	if plant_00 != null and is_instance_valid(plant_00):
		_check(a, "第1行第1列是向日葵", plant_00.plant_type == CharacterRegistry.PlantType.P002SunFlower,
			"实际类型=%d" % plant_00.plant_type)

	var row_2: Array = pcm.all_plant_cells[1]
	var row_ok := true
	for c in row_2:
		var p = (c as PlantCell).get_plant(CharacterRegistry.PlacePlantInCell.Norm)
		if p == null or not is_instance_valid(p) or p.plant_type != CharacterRegistry.PlantType.P004WallNut:
			row_ok = false
	_check(a, "第2行整行都是坚果", row_ok, "第2行 %d 格" % row_2.size())

	_finish(a)


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[SYSTEMPLANT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 等主游戏进入 MAIN_GAME 阶段
func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null and Global.main_game.main_game_progress == 3:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


func _goto_level(a) -> bool:
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)
	await a.click_first("Menu/Button1")
	if not await a.wait_scene("choose_level", 12.0):
		return false
	var gcl: Node = a.get_node_or_null("/root/ChooseLevel/AllPage/GridContainer")
	if gcl == null:
		return false
	await a.press_first("ChooseLevelButton/TextureButton")
	return await a.wait_scene("main_game", 10.0)
