extends RefCounted
## 探针 RELOAD_PLANTS：同一局连续读档，场上的植物会不会残留 / 丢失（对应 docs/TODO清单.md 的 L-27）
##
## 【为什么要有这一条】
##   `plant_cell_manager.load_game_data_plant_cell_manager()` 里原本有一段
##   `clear_all_plant_cell_data()` + 两个 `await process_frame`，后来被注释掉了，
##   旁边还留着「若是等待一帧，一局游戏多次读档测试时稳定触发某次植物未删除，不知道为什么」。
##   也就是说：**当初那个 bug 的成因没搞清，补丁撤了，bug 是否还在没人验证过**。
##   本探针只回答一个问题：同一局连续读档 N 次，场上的植物会不会多出来 / 少掉。
##
## 【判定口径】
##   种 M 株 → 取一次存档快照（内存对象，不落盘）→ 连续读档 3 次 →
##   每次统计「场上活着的植物数」，必须恒等于 M。
##     多了 = 上一次读档的植物没被删干净（就是注释里那个 bug）
##     少了 = 读档把不该清空的植物清掉了
##
## 【已知边界】
##   · 只覆盖「普通植物 × 前院白天」；墓碑 / 罐子 / 睡莲等特殊格子未覆盖。
##   · 读档走 `load_game_data_plant_cell_manager()`（游戏内同一个读档入口），不碰存档文件。
##   · 不证明外观 / 动画正确，只证明「数量对得上」。⚠️ 这是必要条件，不是充分条件。
##
## 【机器可读汇总】最后一行 `[RELOAD] result=PASS|FAIL failed=<n>`
##
## 【⚠️ 写了检查必须自证它拦得住】
##   把 `plant_cell.load_game_data_plant_cell(...)` 临时改成空实现 → 第二次读档起场上植物数会变 0，
##   本探针必须 FAIL。改完记得还原。

const LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"
const PLANT: StringName = PlantIds.PEA_SHOOTER_SINGLE
## 连续读档次数（>1 才有意义：注释里的 bug 是「一局多次读档」才触发）
const RELOAD_TIMES := 3
## 每种一行，各找该行最右的空格
const LANES: Array[int] = [0, 1, 2]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE RELOAD_PLANTS 连续读档不残留 ==========")
	if not await _boot(a):
		_finish(a)
		return
	var mgr = GameContext.curr_main_game.plant_cell_manager
	var planted := _plant_all(a, mgr)
	if planted <= 0:
		_finish(a)
		return
	await a.wait(0.5)
	var expected := _count_alive(mgr)
	_check(a, "种下后场上植物数 = %d" % planted, expected == planted, "实际=%d" % expected)

	## 取一次内存快照；后面每次都读这一份，模拟「同一局反复读同一个档」
	var snapshot = mgr.get_save_game_data_plant_cell_manager()
	_check(a, "取到植物格子存档快照", snapshot != null,
		"null" if snapshot == null else "格子数据=%d" % snapshot.all_plant_cells_datas.size())
	if snapshot == null:
		_finish(a)
		return

	for i in range(RELOAD_TIMES):
		mgr.load_game_data_plant_cell_manager(snapshot)
		## 给 queue_free 留出落地时间（被注释掉的那段补丁原本就是等两帧）
		await a.wait(0.5)
		var alive := _count_alive(mgr)
		_check(a, "第 %d 次读档后植物数 = %d" % [i + 1, expected], alive == expected,
			"实际=%d（多于期望=没删干净，少于期望=读档丢植物）" % alive)
	_finish(a)


#region 关卡准备

func _boot(a) -> bool:
	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡资源可加载", false, LEVEL)
		return false
	Global.game_para = para
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.MainGameFront)
	)
	await a.wait(2.0)
	if GameContext.curr_main_game == null:
		_check(a, "主游戏已就绪", false, "curr_main_game 为空")
		return false
	if GameContext.curr_main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		GameContext.curr_main_game.main_game_start()
	var waited := 0.0
	while GameContext.curr_main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME \
			and waited < 30.0:
		await a.wait(1.0)
		waited += 1.0
	var ok: bool = GameContext.curr_main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME
	_check(a, "进入主游戏阶段", ok, "progress=%d 等待=%.1fs" % [GameContext.curr_main_game.main_game_progress, waited])
	return ok


## 每行挑最右的空格子种一株；返回实际种下的株数
func _plant_all(a, mgr) -> int:
	if mgr == null:
		_check(a, "植物格子管理器可用", false, "plant_cell_manager 为空")
		return 0
	var planted := 0
	var all: Array = mgr.all_plant_cells
	for lane in LANES:
		if all.size() <= lane:
			continue
		var best: PlantCell = null
		for cell in all[lane]:
			if not is_instance_valid(cell):
				continue
			if not _is_cell_free(cell):
				continue
			if best == null or (cell as PlantCell).row_col.y > best.row_col.y:
				best = cell
		if best == null:
			a.log("  [诊断] 第 %d 行没有空格子，跳过" % lane)
			continue
		var plant: Plant000Base = best.create_plant(PLANT)
		if plant != null and is_instance_valid(plant):
			planted += 1
	_check(a, "至少种下一株植物", planted > 0, "实际=%d" % planted)
	return planted

#endregion


#region 统计与断言

## 格子是不是空的：不能用 `plant_in_cell.is_empty()` —— 那个字典在场景里就预置了全部槽位键
## （值恒为 null），任何格子都不是 empty。按槽位走安全读取口 `PlantCell.get_plant()`（见规范细则 S-06）
func _is_cell_free(cell: PlantCell) -> bool:
	for place in _all_places():
		if is_instance_valid(cell.get_plant(place)):
			return false
	return true


## 场上还活着多少株植物（按槽位遍历，与 `_is_cell_free()` 同口径）
func _count_alive(mgr) -> int:
	var n := 0
	for row in mgr.all_plant_cells:
		for cell in row:
			if not is_instance_valid(cell):
				continue
			for place in _all_places():
				if is_instance_valid(cell.get_plant(place)):
					n += 1
	return n


func _all_places() -> Array:
	return [
		CharacterRegistry.PlacePlantInCell.Norm,
		CharacterRegistry.PlacePlantInCell.Shell,
		CharacterRegistry.PlacePlantInCell.Down,
		CharacterRegistry.PlacePlantInCell.Float,
		CharacterRegistry.PlacePlantInCell.Imitater,
	]


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[RELOAD] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()

#endregion
