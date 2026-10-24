extends RefCounted
## 探针：迷你游戏第 11 关「斗转星移」(Portal Combat) 的传送门机制
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_portal_combat
##
## 覆盖（见 minigame_11_portal_combat.gd 与 docs/参考存档/斗转星移传送门.md）：
##   1. PortalManager 挂进主场景，按原版固定位置生成四扇门（方方圆圆）
##   2. 僵尸进门：落到配对门的格左缘、换行（lane / 父节点 / all_zombies_2d 都跟着走）、方向不变
##   3. 子弹进门：落到配对门格中心 +20、换行、射程基准重置
##   4. 换位：随机挑一扇门挪到合法候选格（候选规则照原版 MoveAPortal）
##   5. 出怪行权重（照原版 PortalCombatRowSpawnWeight）
## 机器可读汇总：最后一行 [PORTAL] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_minigame/minigame_11_portal_combat.gd"
const ProbeUtil := preload("res://test/scenarios/probe_util.gd")

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 斗转星移（迷你游戏 11）==========")

	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		a.log("!! 关卡加载失败: " + LEVEL)
		_finish(a)
		return
	_check(a, "关卡参数打开传送门", para.is_portal_combat,
		"is_portal_combat=%s" % str(para.is_portal_combat))
	_check(a, "原版本关是传送带关（不选卡）",
		para.card_mode == ConstLevelData.E_CardMode.ConveyorBelt and not para.can_choosed_card,
		"card_mode=%s can_choosed_card=%s" % [str(para.card_mode), str(para.can_choosed_card)])
	_check(a, "传送带卡池是原版的 6 种", para.conveyor_weights.size() == 6,
		"实际 %d 种" % para.conveyor_weights.size())

	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)
	var mg = GameContext.curr_main_game
	if mg == null:
		a.log("!! GameContext.curr_main_game 为空")
		_finish(a)
		return

	var pm = mg.get_node_or_null("Manager/PortalManager")
	_check(a, "主场景里挂了 PortalManager", pm != null, str(pm))
	if pm == null:
		_finish(a)
		return
	var doors: Array = pm._doors
	_check(a, "四扇门都生成了", doors.size() == 4, "实际 %d" % doors.size())
	if doors.size() != 4:
		_finish(a)
		return

	# ------------------------------------------------ STEP1 门的样子与落位
	a.log("STEP1 四扇门：按原版固定位置生成（方(2,0)/方(9,1)/圆(9,3)/圆(2,4)）")
	_check(a, "门型 = 方/方/圆/圆（两对同型配对）",
		doors[0].portal_type == Portal.E_PortalType.Square and doors[1].portal_type == Portal.E_PortalType.Square
		and doors[2].portal_type == Portal.E_PortalType.Circle and doors[3].portal_type == Portal.E_PortalType.Circle)
	var expect_cells := [Vector2i(2, 0), Vector2i(9, 1), Vector2i(9, 3), Vector2i(2, 4)]
	var cell_ok := true
	var cell_detail := ""
	for i in range(4):
		var door: Portal = doors[i]
		var want: Vector2i = expect_cells[i]
		if door.grid_x != want.x or door.lane != want.y:
			cell_ok = false
			cell_detail += " 门%d 在(%d,%d)，原版是(%d,%d)" % [i, door.grid_x, door.lane, want.x, want.y]
	_check(a, "四扇门都在原版写死的格子上", cell_ok, cell_detail)
	## 配对 = 同类型的另一扇
	var pair_ok := true
	for i in range(4):
		var partner = pm._other_portal(doors[i])
		if partner == null or partner.portal_type != doors[i].portal_type:
			pair_ok = false
	_check(a, "每扇门都能按「同类型」找到搭档", pair_ok)
	## 门都挂在草坪范围内、悬在行地面上方
	var map: ResourceMapData = para.map_data
	var lawn_left: float = map.col_x[0]
	var lawn_right: float = map.col_x[map.get_col_num() - 1] + map.col_width[map.get_col_num() - 1]
	var pos_ok := true
	var pos_detail := ""
	for i in range(4):
		var door: Portal = doors[i]
		var p: Vector2 = door.global_position
		var on_lawn := p.x >= lawn_left and p.x <= lawn_right
		var lane_ok := door.lane >= 0 and door.lane < map.get_row_num()
		var ground_y: float = map.rows[door.lane].zombie_create_global_pos.y
		var above_ground := p.y < ground_y
		if not (on_lawn and lane_ok and above_ground):
			pos_ok = false
			pos_detail += " 门%d(x=%.0f,y=%.0f,lane=%d)不在草坪上/不在行地面上方" % [i, p.x, p.y, door.lane]
	_check(a, "每扇门都落在草坪范围内、行号合法、悬在行地面上方", pos_ok, pos_detail)

	# ------------------------------------------------ STEP2 僵尸传送
	a.log("STEP2 僵尸进门：传到配对门处并换行，方向不变")
	var entry: Portal = doors[0]
	var exit_door: Portal = pm._other_portal(entry)
	var zm = mg.zombie_manager
	var lane_y: float = zm.all_zombie_rows[entry.lane].zombie_create_position.global_position.y
	## 站在入口门的判定窗口正中间（原版判定是「碰撞盒中心落在窗口里」）
	var entry_judge_x: float = pm._cell_center_x(entry.grid_x, entry.lane) + pm.ZOMBIE_JUDGE_OFFSET
	var zombie: Zombie000Base = zm.create_norm_zombie(
		ZombieIds.NORM,
		zm.all_zombie_rows[entry.lane],
		{
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: entry.lane,
			Zombie000Base.E_ZInitAttr.CurrWave: 1,
		},
		Vector2(entry_judge_x, lane_y)
	)
	await a.wait(0.3)
	if not is_instance_valid(zombie):
		_check(a, "测试僵尸还在场上", false)
	else:
		_check(a, "记下了出口门（同一列的门不会立刻把它吸回去）",
			pm._exit_memory.has(zombie.get_instance_id()))
	await a.wait(1.2)
	if not is_instance_valid(zombie):
		_check(a, "测试僵尸还在场上", false)
	else:
		var exit_y: float = zm.all_zombie_rows[exit_door.lane].zombie_create_position.global_position.y
		## 原版落点：碰撞盒中心落到出口格左缘（仓库僵尸原点即受击框中心）
		var expect_x: float = pm._cell_left_x(exit_door.grid_x, exit_door.lane)
		_check(a, "僵尸换到了出口门那一行", zombie.lane == exit_door.lane,
			"%d -> %d" % [entry.lane, zombie.lane])
		## 断言时僵尸已经又走了一小段（传送后方向不变，继续朝房子走），
		## 所以容差给到「传送点 ± 走过的距离」，并要求它没有往回走
		_check(a, "僵尸落点在出口格左缘附近（方向不变继续走）",
			zombie.global_position.x <= expect_x + 4.0 and zombie.global_position.x >= expect_x - 45.0,
			"x=%.0f 期望≈%.0f（传送后会继续走）" % [zombie.global_position.x, expect_x])
		_check(a, "僵尸 y 对齐新行地面", absf(zombie.global_position.y - exit_y) <= 2.0,
			"y=%.0f 期望=%.0f" % [zombie.global_position.y, exit_y])
		_check(a, "僵尸父节点换到了新行", zombie.get_parent() == zm.all_zombie_rows[exit_door.lane])
		_check(a, "all_zombies_2d 里也挪到了新行", zm.all_zombies_2d[exit_door.lane].has(zombie))
		_check(a, "方向没被翻转（direction_x_root 仍为 1）", zombie.direction_x_root == 1)
		zombie.queue_free()
		await a.wait(0.5)

	# ------------------------------------------------ STEP3 子弹传送
	a.log("STEP3 子弹进门：传到配对门处并换行，方向不变")
	var bullets: Node2D = mg.bullets
	var bullet: Bullet000NormBase = Global.bullet_registry.get_bullet_scenes(
		BulletIds.PEA).instantiate()
	## 子弹的判定窗口中心比僵尸窗口靠右 30px（原版 gridX*80+55 vs +25）
	var bullet_judge_x: float = pm._cell_center_x(entry.grid_x, entry.lane) + pm.BULLET_JUDGE_OFFSET
	bullet.init_bullet({
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: true,
		Bullet000NormBase.E_InitParasAttr.BulletLane: entry.lane,
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(Vector2(bullet_judge_x, lane_y)),
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.LEFT,
		Bullet000NormBase.E_InitParasAttr.BulletCamp: CharacterRegistry.CharacterType.Plant,
	})
	bullets.add_child(bullet)
	## 传送发生在第一个物理帧，等太久子弹已经飞出门区（300px/s），断言要赶在飞远之前
	await a.wait(0.05)
	if not is_instance_valid(bullet):
		_check(a, "测试子弹还在场上", false)
	else:
		## 原版出口落点 = 出口格中心 +20；y 跟着出口行走（原版 mY += 行差）
		var expect_bullet_x: float = pm._cell_center_x(exit_door.grid_x, exit_door.lane) + pm.BULLET_EXIT_OFFSET
		var expect_bullet_y: float = pm._lane_ground_y(exit_door.lane)
		_check(a, "子弹换到了出口门那一行", bullet.lane == exit_door.lane,
			"%d -> %d" % [entry.lane, bullet.lane])
		_check(a, "子弹出生点被重置到出口落点（射程从门重新起算）",
			bullet.start_pos.distance_to(bullets.to_local(Vector2(expect_bullet_x, expect_bullet_y))) <= 5.0,
			"start_pos=%s 期望≈%s" % [str(bullet.start_pos),
				str(bullets.to_local(Vector2(expect_bullet_x, expect_bullet_y)))])
		_check(a, "方向没变（还是向左）", bullet.direction == Vector2.LEFT)
		_check(a, "z_index 按新行更新", bullet.z_index == bullet.lane * 50 + 45,
			"实际 %d" % bullet.z_index)
		## 再飞 1 秒确认没有被「超过最大射程」销毁
		await a.wait(1.0)
		_check(a, "传送后子弹照常飞（没被当超程销毁）", is_instance_valid(bullet))
	if is_instance_valid(bullet):
		bullet.queue_free()
		await a.wait(0.5)

	# ------------------------------------------------ STEP4 换位
	a.log("STEP4 换位：随机挑一扇门挪到合法候选格（原版 MoveAPortal）")
	var before_cells: Array[Vector2i] = []
	for door: Portal in pm._doors:
		before_cells.append(Vector2i(door.grid_x, door.lane))
	pm._move_a_portal()
	await a.wait(0.5)
	var after_doors: Array = pm._doors
	_check(a, "换位后仍然是四扇打开的门", after_doors.size() == 4, "实际 %d" % after_doors.size())
	var moved := false
	var move_ok := true
	var move_detail := ""
	for door: Portal in after_doors:
		var cell := Vector2i(door.grid_x, door.lane)
		if before_cells.has(cell):
			continue
		moved = true
		## 候选规则：该格原来没有门、且与搭档门的列和行都不同
		var partner = pm._other_portal(door)
		if partner == null:
			move_ok = false
			move_detail += " 新门找不到搭档"
			continue
		if door.grid_x == partner.grid_x or door.lane == partner.lane:
			move_ok = false
			move_detail += " 新门(%d,%d) 与搭档(%d,%d) 同列或同行" % [
				door.grid_x, door.lane, partner.grid_x, partner.lane]
	_check(a, "有一扇门挪到了新格子", moved, move_detail)
	_check(a, "新落点满足原版候选规则（与搭档不同列也不同行）", move_ok, move_detail)

	# ------------------------------------------------ STEP5 出怪行权重
	a.log("STEP5 出怪行权重（原版 PortalCombatRowSpawnWeight）")
	var weights: Array[float] = pm.get_row_spawn_weights()
	_check(a, "每行都有权重", weights.size() == map.get_row_num(),
		"实际 %d 行权重 / 地图 %d 行" % [weights.size(), map.get_row_num()])
	var weight_ok := true
	var weight_detail := ""
	for w in weights:
		if not (is_equal_approx(w, 0.01) or is_equal_approx(w, 0.2) or is_equal_approx(w, 1.0)):
			weight_ok = false
			weight_detail += " 出现非原版权重 %.3f" % w
	_check(a, "权重只有原版的三个取值（0.01 / 0.2 / 1.0）", weight_ok, weight_detail)

	_finish(a)


func _check(a, name: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [PASS] " + name)
	else:
		_failed += 1
		a.log("  [FAIL] " + name + ("  (" + detail + ")" if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	if _failed == 0:
		a.log("[PORTAL] result=PASS")
	else:
		a.log("[PORTAL] result=FAIL failed=%d" % _failed)
	a.quit_game()
