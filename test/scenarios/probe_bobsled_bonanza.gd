extends RefCounted
## 探针：迷你游戏第 13 关「全面冻结」(Bobsled Bonanza) 的冰面机制
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_bobsled_bonanza
##
## 覆盖（本关的三件事，见 minigame_13_bobsled_bonanza.gd）：
##   0. 进关即有冰 —— 选卡阶段（还没点「开始游戏」）四条地面行的冰面就已经铺好（关开始就生成）
##   1. 开局冰道 —— 四条地面行各一条冰、水面两条行没冰，每行从最右列往左盖 4 格
##   2. 冰面不可种植 —— 盖住的格子 can_common_plant=false，没盖住的照常能种
##   3. 雪橇队只在有冰的行出（ZombieWaveCreateManager.select_bobsled_spawn_row）
##   4. 融冰 —— 火爆辣椒融掉一行后该行不再出雪橇队，全图没冰时一律改出洗冰车
##   5. 复冰 —— 洗冰车往前开会把这一行的冰铺回来
## 机器可读汇总：最后一行 [BOBSLED] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_minigame/minigame_13_bobsled_bonanza.gd"
const ProbeUtil := preload("res://test/scenarios/probe_util.gd")

## 与关卡脚本的 PRESET_ICE_ROAD_CELL_NUM 对齐
const COVER_CELL_NUM := 4

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 全面冻结（迷你游戏 13）==========")

	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		a.log("!! 关卡加载失败: " + LEVEL)
		_finish(a)
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)
	var mg = Global.main_game
	if mg == null:
		a.log("!! Global.main_game 为空")
		_finish(a)
		return
	var zm = mg.zombie_manager
	var wcm = zm.zombie_wave_manager.zombie_wave_create_manager

	var land_lanes: Array[int] = []
	var pool_lanes: Array[int] = []
	for lane in range(zm.all_zombie_rows.size()):
		if zm.all_zombie_rows[lane].zombie_row_type == CharacterRegistry.ZombieRowType.Land:
			land_lanes.append(lane)
		else:
			pool_lanes.append(lane)

	# ------------------------------------------------ STEP0 冰道在关卡最开始就生成
	a.log("STEP0 进关即有冰：选卡阶段（还没点开始）冰面已经铺好")
	var ice_lanes_on_init: Array[int] = []
	for lane in range(zm.all_ice_roads.size()):
		if not zm.all_ice_roads[lane].is_empty():
			ice_lanes_on_init.append(lane)
	_check(a, "选卡之前冰面已经铺好（关卡最开始就生成，见 init_level_items）",
		ice_lanes_on_init == land_lanes, "有冰的行=%s 地面行=%s" % [str(ice_lanes_on_init), str(land_lanes)])

	## 流程停在选卡上，替玩家按「开始游戏」，冰道在进关时就已经铺好了（见 STEP0）
	await ProbeUtil.click_start(a)
	await ProbeUtil.wait_lawn_mowers(a, 20.0)
	await a.wait(1.0)

	# ------------------------------------------------ STEP1 关卡数据：45 秒开场 + 四面旗帜
	a.log("STEP1 关卡数据：开场延迟按原版写死")
	_check(a, "第一波延迟是原版的 45 秒", para.first_wave_delay == 45.0, str(para.first_wave_delay))

	# ------------------------------------------------ STEP2 开局冰道的分布
	a.log("STEP2 开局冰道：四条地面行有冰，水面两条没冰")
	a.log("  地面行=%s 水面行=%s" % [str(land_lanes), str(pool_lanes)])
	var ice_lanes: Array[int] = []
	for lane in range(zm.all_ice_roads.size()):
		if zm.all_ice_roads[lane].size() > 0:
			ice_lanes.append(lane)
		a.log("  行%d 冰道条数=%d" % [lane, zm.all_ice_roads[lane].size()])
	_check(a, "每条地面行都有 1 条冰道，水面行没有冰",
		ice_lanes == land_lanes, "有冰的行=%s 地面行=%s" % [str(ice_lanes), str(land_lanes)])

	# ------------------------------------------------ STEP3 冰面盖住 4 格且不能种植
	a.log("STEP3 每条冰道盖住最右 %d 格，盖住的格子不能种植" % COVER_CELL_NUM)
	var all_cells: Array = mg.plant_cell_manager.all_plant_cells
	for lane in land_lanes:
		var lane_cells: Array = all_cells[lane]
		var covered: Array[int] = []
		for c in range(lane_cells.size()):
			if lane_cells[c].curr_ice_roads.size() > 0:
				covered.append(c)
		var expect: Array[int] = []
		for c in range(lane_cells.size() - COVER_CELL_NUM, lane_cells.size()):
			expect.append(c)
		_check(a, "行%d 冰面盖住的是最右 %d 格" % [lane, COVER_CELL_NUM], covered == expect,
			"实际=%s 期望=%s" % [str(covered), str(expect)])
		var covered_ok := true
		for c in covered:
			if lane_cells[c].can_common_plant:
				covered_ok = false
		_check(a, "行%d 冰面上的格子不能种植" % lane, covered_ok)
		var free_ok := true
		for c in range(lane_cells.size()):
			if covered.has(c):
				continue
			if not lane_cells[c].can_common_plant:
				free_ok = false
		_check(a, "行%d 没被冰盖住的格子照常能种植" % lane, free_ok)

	# ------------------------------------------------ STEP4 有冰时出的是雪橇队，且落在有冰的行
	a.log("STEP4 本关出怪表只剩雪橇队时：出的全是雪橇队，且全落在有冰的行")
	var wave_zombies: Array = _spawn_a_wave(a, zm, wcm)
	_check(a, "有冰时刷出来的是雪橇队", _all_of_type(wave_zombies, Zombie014Bobsled),
		"实际=%s" % _type_names(wave_zombies))
	var bob_lanes_ok := true
	for z: Zombie000Base in wave_zombies:
		if not z is Zombie014Bobsled:
			continue
		if zm.all_ice_roads[z.lane].is_empty():
			bob_lanes_ok = false
	_check(a, "雪橇队全出生在有冰的行", bob_lanes_ok)

	# ------------------------------------------------ STEP5 融掉一行：该行不再出雪橇队
	a.log("STEP5 火爆辣椒融掉第 %d 行：这一行不再出雪橇队" % land_lanes[0])
	var melt_lane: int = land_lanes[0]
	EventBus.push_event("jalapeno_bomb_item_lane", [melt_lane])
	await a.wait(0.3)
	_check(a, "融冰后该行冰道清空", zm.all_ice_roads[melt_lane].is_empty())
	var melt_cell_ok := true
	for c in range(all_cells[melt_lane].size()):
		if not all_cells[melt_lane][c].can_common_plant:
			melt_cell_ok = false
	_check(a, "融冰后该行所有格子恢复能种植", melt_cell_ok)
	var lanes_after_melt: Array[int] = []
	for i in range(30):
		lanes_after_melt.append(wcm.select_bobsled_spawn_row())
	_check(a, "融掉的行不再被选作雪橇队的出怪行",
		not lanes_after_melt.has(melt_lane) and not lanes_after_melt.has(-1),
		"实际选到的行=%s" % str(lanes_after_melt))

	# ------------------------------------------------ STEP6 全图融冰：一律改出洗冰车
	a.log("STEP6 四条地面行全融掉：雪橇队出不来，改出洗冰车")
	for lane in land_lanes:
		EventBus.push_event("jalapeno_bomb_item_lane", [lane])
	await a.wait(0.3)
	_check(a, "全图无冰时 select_bobsled_spawn_row 返回 -1", wcm.select_bobsled_spawn_row() == -1)
	var zamboni_wave: Array = _spawn_a_wave(a, zm, wcm)
	_check(a, "全图无冰时刷出来的是洗冰车（不是雪橇队）",
		_all_of_type(zamboni_wave, Zombie013Zamboni), "实际=%s" % _type_names(zamboni_wave))

	# ------------------------------------------------ STEP7 洗冰车把冰铺回来
	a.log("STEP7 洗冰车往前开：这一行的冰面重新铺回来")
	var zamboni: Zombie013Zamboni = zm.create_norm_zombie(
		CharacterRegistry.ZombieType.Z013Zamboni,
		zm.all_zombie_rows[melt_lane],
		{
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: melt_lane,
			Zombie000Base.E_ZInitAttr.CurrWave: 1,
		},
		zm.all_zombie_rows[melt_lane].zombie_create_position.global_position)
	if zamboni == null or zamboni.ice_road == null:
		_check(a, "生成洗冰车并拿到它的冰道", false, "洗冰车=%s" % str(zamboni))
	else:
		## left_x 的初值是 0（还没推进过），要先让车开一步拿到基准，再比推进量
		await a.wait(1.0)
		var ice_left_x: float = zamboni.ice_road.left_x
		await a.wait(2.0)
		_check(a, "洗冰车开过后这一行又有冰了", not zm.all_ice_roads[melt_lane].is_empty())
		_check(a, "洗冰车把冰面往左推进（left_x 变小）", zamboni.ice_road.left_x < ice_left_x,
			"%.1f -> %.1f" % [ice_left_x, zamboni.ice_road.left_x])
		_check(a, "复冰后雪橇队又能在这一行出", wcm.select_bobsled_spawn_row() == melt_lane)

	# ------------------------------------------------ STEP8 波数：四面旗帜 40 波
	## max_wave 是「开战」事件写到关卡数据上的（此时流程还没跑到那里的话读到的还是默认值），
	## 放最后再看：本关流程最后一步就是 start_battle(40, ...)
	a.log("STEP8 波数：四面旗帜 = 40 波")
	_check(a, "四面旗帜 = 40 波", para.max_wave == 40, str(para.max_wave))

	_finish(a)


## 把本关出怪表临时改成「只有雪橇队」并刷一波，返回这一波真的生成的僵尸
func _spawn_a_wave(a, zm, wcm) -> Array:
	zm.zombie_refresh_types = [CharacterRegistry.ZombieType.Z014Bobsled]
	wcm.update_zombie_refresh_types()
	var zombies: Array = wcm.create_curr_wave_all_zombies(1, false)
	a.log("  本波生成 %d 只：%s" % [zombies.size(), _type_names(zombies)])
	return zombies


func _all_of_type(zombies: Array, script_type) -> bool:
	if zombies.is_empty():
		return false
	for z in zombies:
		if not is_instance_of(z, script_type):
			return false
	return true


func _type_names(zombies: Array) -> String:
	var names: Array[String] = []
	for z in zombies:
		var script: Script = z.get_script()
		names.append(script.get_global_name() if script != null else z.get_class())
	return str(names)


func _check(a, title: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("  [%s] %s %s" % ["PASS" if ok else "FAIL", title, detail])


func _finish(a) -> void:
	a.log("[BOBSLED] result=%s failed=%d" % ["FAIL" if _failed > 0 else "PASS", _failed])
	a.quit_game()
