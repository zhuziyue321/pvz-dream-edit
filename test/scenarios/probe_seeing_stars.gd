extends RefCounted
## 探针：迷你游戏第 7 关「观星」(Seeing Stars)
## 覆盖：
##   ① 关卡数据：4 面旗帜（40 波）/ 杨桃是预选卡（没解锁也进卡槽）
##   ② 星星轮廓：13 个轮廓点、绘制层节点已挂上
##   ③ 进度条口径：观星数据源（进度 = 已种轮廓点 / 总数）、不画旗帜、开战才显示
##   ④ 种植限制：轮廓点上只能种杨桃 / 南瓜头（豌豆射手种不进去）；
##      轮廓点之外不能种杨桃（豌豆射手照常能种）
##   ⑤ 通关判定：轮廓点全种满杨桃 → 出奖杯（不是靠打完波次）
##   ⑥ 规则全在关卡脚本上：star_cells / is_all_star_cells_planted() 都从脚本取
## 机器可读汇总：最后一行 [SEESTARS] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_minigame/minigame_07_seeing_stars.gd"
## 默认大星星的轮廓点个数（与 minigame_07_seeing_stars.STAR_CELLS 一致）
const STAR_CELL_NUM := 13
const MAX_FLAG := 4

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 观星（Seeing Stars） ==========")

	## 玩家**没有**杨桃（原版 4-6 才解锁）：预选卡必须照样把它塞进出战卡槽，不然本关永远打不完
	var state = Global.global_game_state
	state.curr_plant.assign([
		CharacterRegistry.PlantType.P001PeaShooterSingle,
		CharacterRegistry.PlantType.P004WallNut,
	])

	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)

	var mg := Global.main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "Global.main_game 为空")
		_finish(a)
		return

	# ------------------------------------------------ STEP1 关卡数据
	a.log("STEP1 关卡数据")
	var level_script := mg.game_para as LevelScriptBase
	if level_script == null:
		_check(a, "拿到关卡脚本实例", false, str(mg.game_para))
		_finish(a)
		return
	_check(a, "总波数 = 40（4 面旗帜）", mg.game_para.max_wave == MAX_FLAG * 10, str(mg.game_para.max_wave))
	_check(a, "旗帜上限 = " + str(MAX_FLAG), level_script.MAX_FLAG == MAX_FLAG,
		str(level_script.MAX_FLAG))

	# ------------------------------------------------ STEP2 星星轮廓
	a.log("STEP2 星星轮廓")
	var star_cells: Array[PlantCell] = level_script.star_cells
	_check(a, "轮廓点个数 = " + str(STAR_CELL_NUM), star_cells.size() == STAR_CELL_NUM,
		str(star_cells.size()))
	## 留一份节点引用：STEP7 要验「关卡结束后它真的被释放了」
	var overlay_node: CellStarOverlay = level_script.star_overlay
	_check(a, "星星绘制层已挂上", level_script.star_overlay != null
		and is_instance_valid(level_script.star_overlay), str(level_script.star_overlay))
	_check(a, "开场时还没种满", not level_script.is_all_star_cells_planted())
	## 轮廓点上是「半透明的杨桃虚影」而不是星星贴图：每格一棵，且都挂进了场景树
	var ghost_num := 0
	var visible_ghost_num := 0
	for ghost: Node2D in level_script.star_overlay.ghosts:
		if not is_instance_valid(ghost):
			continue
		ghost_num += 1
		if ghost.is_inside_tree() and ghost.modulate.a > 0.0:
			visible_ghost_num += 1
	_check(a, "轮廓点数 = 虚影数 = " + str(STAR_CELL_NUM),
		ghost_num == STAR_CELL_NUM and ghost_num == star_cells.size(), str(ghost_num))
	_check(a, "每个虚影都挂进树且半透明", visible_ghost_num == STAR_CELL_NUM, str(visible_ghost_num))

	# ------------------------------------------------ STEP2.5 进度条口径
	a.log("STEP2.5 进度条口径（进度 = 已种轮廓点 / 轮廓点总数）")
	var provider: LevelProgressProvider = mg.level_progress_controller.provider
	_check(a, "数据源是观星口径", provider is SeeingStarsProgressProvider, str(provider))
	if provider == null:
		_finish(a)
		return
	## 进度条被种植进度占满，波次（4 面旗帜的倒计时）不画在上面
	_check(a, "进度条不画旗帜", provider.get_flag_num() == 0, str(provider.get_flag_num()))
	_check(a, "不升旗", provider.take_flag_raise_index() == -1, str(provider.take_flag_raise_index()))
	_check(a, "开局进度 0%（一个轮廓点都还没种）", is_zero_approx(provider.get_progress()),
		str(provider.get_progress()))
	_check(a, "开战前进度条不显示", not provider.is_bar_visible())

	# ------------------------------------------------ STEP3 种植限制
	a.log("STEP3 种植限制")
	var star_cell: PlantCell = star_cells[0]
	var other_cell: PlantCell = _find_cell_outside_stars(mg, star_cells)
	if other_cell == null:
		_check(a, "找到一个非轮廓格子", false, "null")
		_finish(a)
		return
	_check(a, "轮廓点上能种杨桃", _can_plant(star_cell, CharacterRegistry.PlantType.P030StarFruit))
	_check(a, "轮廓点上能种南瓜头", _can_plant(star_cell, CharacterRegistry.PlantType.P031Pumpkin))
	_check(a, "轮廓点上不能种豌豆射手",
		not _can_plant(star_cell, CharacterRegistry.PlantType.P001PeaShooterSingle))
	_check(a, "轮廓点外不能种杨桃",
		not _can_plant(other_cell, CharacterRegistry.PlantType.P030StarFruit))
	_check(a, "轮廓点外能种豌豆射手",
		_can_plant(other_cell, CharacterRegistry.PlantType.P001PeaShooterSingle))

	# ------------------------------------------------ STEP4 选卡：杨桃是预选卡
	a.log("STEP4 选卡")
	if not await _wait_progress(a, mg, MainGameManager.E_MainGameProgress.CHOOSE_CARD, 30.0):
		_finish(a)
		return
	_check(a, "出战卡槽里有杨桃（预选卡）",
		_has_card(mg, CharacterRegistry.PlantType.P030StarFruit))
	mg.card_manager.card_slot_norm._on_texture_button_pressed()

	if not await _wait_progress(a, mg, MainGameManager.E_MainGameProgress.MAIN_GAME, 30.0):
		_finish(a)
		return

	# ------------------------------------------------ STEP5 种满通关
	a.log("STEP5 把所有轮廓点种上杨桃")
	var wave_manager = mg.zombie_manager.zombie_wave_manager
	_check(a, "开战了但还没到最后一波（通关不看波次）", wave_manager.curr_wave < mg.game_para.max_wave - 1,
		str(wave_manager.curr_wave))
	## 进度条沿用战斗口径的显示时机：开第一波之后才显示（进 MAIN_GAME 那一刻还没开波）
	var waited_bar := 0.0
	while waited_bar < 40.0 and not provider.is_bar_visible():
		await a.wait(0.5)
		waited_bar += 0.5
	_check(a, "开打后进度条显示", provider.is_bar_visible(), str(waited_bar) + " 秒仍未开第一波")
	## 先种一个看进度条是不是跟着涨（口径 = 已种轮廓点 / 总数）
	star_cells[0].create_plant(CharacterRegistry.PlantType.P030StarFruit)
	var one_progress := 100.0 / float(STAR_CELL_NUM)
	_check(a, "种 1 个轮廓点 → 进度 = 1/" + str(STAR_CELL_NUM),
		absf(provider.get_progress() - one_progress) < 0.01, str(provider.get_progress()))
	for plant_cell: PlantCell in star_cells:
		plant_cell.create_plant(CharacterRegistry.PlantType.P030StarFruit)
	_check(a, "全种上 → 进度 100%", is_equal_approx(provider.get_progress(), 100.0),
		str(provider.get_progress()))
	await a.wait(3.0)
	_check(a, "种满后轮廓判定为真", level_script.is_all_star_cells_planted())
	_check(a, "种满后进入 GAME_OVER（掉奖杯结算）",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER, str(mg.main_game_progress))

	# ------------------------------------------------ STEP6 旗帜计数（超时判负的判据）
	## 通关流程已经走完，轮询循环已退出，这里改 curr_wave 不会再触发判负
	a.log("STEP6 旗帜计数（第 N 面旗帜升起 = 超时判负的判据）")
	wave_manager.curr_wave = 0
	_check(a, "第 0 波 = 0 面旗帜", level_script._get_passed_flag_num(mg) == 0,
		str(level_script._get_passed_flag_num(mg)))
	wave_manager.curr_wave = 9
	_check(a, "第 9 波 = 1 面旗帜", level_script._get_passed_flag_num(mg) == 1,
		str(level_script._get_passed_flag_num(mg)))
	wave_manager.curr_wave = 38
	_check(a, "第 38 波 = 3 面旗帜", level_script._get_passed_flag_num(mg) == 3,
		str(level_script._get_passed_flag_num(mg)))
	wave_manager.curr_wave = 39
	_check(a, "第 39 波 = 4 面旗帜（此时没种满就判负）", level_script._get_passed_flag_num(mg) == MAX_FLAG,
		str(level_script._get_passed_flag_num(mg)))

	# ------------------------------------------------ STEP7 关卡结束后的清理（幂等）
	a.log("STEP7 绘制层清理（关卡结束 + 可重复调用）")
	_check(a, "run_flow 结束后关卡脚本不再持有绘制层", level_script.star_overlay == null,
		str(level_script.star_overlay))
	await a.wait(0.5)
	_check(a, "绘制层节点已被释放", not is_instance_valid(overlay_node), str(overlay_node))
	## 幂等：再调两次不该报错（重进关 / 关卡结束各调一次就靠这个）
	level_script._free_star_overlay()
	level_script._free_star_overlay()
	_check(a, "重复调用清理不报错、仍为空", level_script.star_overlay == null,
		str(level_script.star_overlay))

	_finish(a)


#region 工具
## 找一个不在星星轮廓上的格子（拿整张草坪第一个不在轮廓里的）
func _find_cell_outside_stars(mg, star_cells: Array[PlantCell]) -> PlantCell:
	for plant_cells_row in mg.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in plant_cells_row:
			if not star_cells.has(plant_cell):
				return plant_cell
	return null


## 这一格能不能种 plant_type（走的是玩家持卡时的同一条判定）
func _can_plant(plant_cell: PlantCell, plant_type: CharacterRegistry.PlantType) -> bool:
	var cond: ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	return cond.judge_is_can_plant(plant_cell, plant_type)


func _has_card(mg, plant_type: CharacterRegistry.PlantType) -> bool:
	for card: Card in mg.card_manager.card_slot_battle.curr_cards:
		if card.card_plant_type == plant_type:
			return true
	return false


## 等主游戏推进到某个阶段
func _wait_progress(a, mg, progress, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if mg.main_game_progress == progress:
			return true
		await a.wait(0.5)
		waited += 0.5
	_check(a, "等到阶段 " + str(progress), false, "当前阶段=" + str(mg.main_game_progress))
	return false


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[SEESTARS] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
