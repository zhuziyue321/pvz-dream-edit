extends RefCounted
## 探针：迷你游戏第 11 关「斗转星移」(Portal Combat) 的传送门机制
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_portal_combat
##
## 覆盖（见 minigame_11_portal_combat.gd 与 docs/参考存档/斗转星移传送门.md）：
##   1. PortalManager 挂进主场景，四扇门（两方两圆）生成、落位在草坪上、按行配对分居左右半区
##   2. 僵尸进门：挪到配对门处、换行（lane / 父节点 / all_zombies_2d 都跟着走）、方向不变
##   3. 子弹进门：挪到配对门处、换行、z_index / 射程基准重置
##   4. 传送门到点随机换位（等一次 reshuffle 间隔）
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
	_check(a, "关卡参数打开传送门", para.is_portal_combat and para.portal_reshuffle_interval > 0.0,
		"is_portal_combat=%s interval=%s" % [str(para.is_portal_combat), str(para.portal_reshuffle_interval)])

	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)
	var mg = Global.main_game
	if mg == null:
		a.log("!! Global.main_game 为空")
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
	a.log("STEP1 四扇门：两方两圆，落位在草坪上，每对分居左右半区")
	_check(a, "门型 = 方/方/圆/圆（两对同型配对）",
		doors[0].portal_type == Portal.E_PortalType.Square and doors[1].portal_type == Portal.E_PortalType.Square
		and doors[2].portal_type == Portal.E_PortalType.Circle and doors[3].portal_type == Portal.E_PortalType.Circle)
	var map: ResourceMapData = para.map_data
	var lawn_left := map.col_x[0]
	var lawn_right := map.col_x[map.get_col_num() - 1] + map.col_width[map.get_col_num() - 1]
	var ground_ys: Array[float] = []
	for row_i in range(map.get_row_num()):
		ground_ys.append(map.rows[row_i].zombie_create_global_pos.y)
	var pos_ok := true
	var pos_detail := ""
	for i in range(4):
		var door: Portal = doors[i]
		var p: Vector2 = door.global_position
		var on_lawn := p.x >= lawn_left and p.x <= lawn_right
		var lane_ok := door.lane >= 0 and door.lane < map.get_row_num()
		var y_ok := ground_ys.has(p.y + pm.DOOR_CENTER_ABOVE_GROUND)
		if not (on_lawn and lane_ok and y_ok):
			pos_ok = false
			pos_detail += " 门%d(x=%.0f,y=%.0f,lane=%d)不在草坪上" % [i, p.x, p.y, door.lane]
	_check(a, "每扇门都落在草坪范围内、行号合法、中心悬在行地面上方", pos_ok, pos_detail)
	var pairs_split := true
	for pair_i in range(2):
		var left_door: Portal = doors[pair_i * 2]
		var right_door: Portal = doors[pair_i * 2 + 1]
		var mid := lawn_left + (lawn_right - lawn_left) / 2.0
		if not (left_door.global_position.x < mid and right_door.global_position.x > mid):
			pairs_split = false
	_check(a, "每对门一扇在左半区、一扇在右半区", pairs_split)

	# ------------------------------------------------ STEP2 僵尸传送
	## 选卡阶段场上没有僵尸（开战还没开始），造一只普僵按到入口门口
	a.log("STEP2 僵尸进门：传到配对门处并换行，方向不变")
	var entry: Portal = doors[0]
	var exit_door: Portal = doors[1]
	var zm = mg.zombie_manager
	var lane_y: float = zm.all_zombie_rows[entry.lane].zombie_create_position.global_position.y
	var zombie: Zombie000Base = zm.create_norm_zombie(
		CharacterRegistry.ZombieType.Z001Norm,
		zm.all_zombie_rows[entry.lane],
		{
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: entry.lane,
			Zombie000Base.E_ZInitAttr.CurrWave: 1,
		},
		Vector2(entry.global_position.x, lane_y)
	)
	await a.wait(0.3)
	if not is_instance_valid(zombie):
		_check(a, "测试僵尸还在场上", false)
	else:
		## 先查出口记忆：僵尸走得慢但不能拖太久，走出门判定范围记忆就会被清（预期行为）
		_check(a, "记下了出口门（离开范围前不再触发传送）",
			pm._exit_memory.has(zombie.get_instance_id()))
	await a.wait(1.2)
	if not is_instance_valid(zombie):
		_check(a, "测试僵尸还在场上", false)
	else:
		var exit_y: float = zm.all_zombie_rows[exit_door.lane].zombie_create_position.global_position.y
		_check(a, "僵尸换到了出口门那一行", zombie.lane == exit_door.lane,
			"%d -> %d" % [entry.lane, zombie.lane])
		_check(a, "僵尸落点在出口门旁（方向不变继续走）",
			absf(zombie.global_position.x - (exit_door.global_position.x - pm.EXIT_OFFSET)) <= 30.0,
			"x=%.0f 期望≈%.0f" % [zombie.global_position.x, exit_door.global_position.x - pm.EXIT_OFFSET])
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
		BulletRegistry.BulletType.Bullet001Pea).instantiate()
	bullet.init_bullet({
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: true,
		Bullet000NormBase.E_InitParasAttr.BulletLane: entry.lane,
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(entry.global_position),
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.LEFT,
		Bullet000NormBase.E_InitParasAttr.BulletCamp: CharacterRegistry.CharacterType.Plant,
	})
	bullets.add_child(bullet)
	## 传送发生在第一个物理帧，等太久子弹已经飞出门区（300px/s），断言要赶在飞远之前
	await a.wait(0.05)
	if not is_instance_valid(bullet):
		_check(a, "测试子弹还在场上", false)
	else:
		_check(a, "子弹换到了出口门那一行", bullet.lane == exit_door.lane,
			"%d -> %d" % [entry.lane, bullet.lane])
		_check(a, "子弹出生点被重置到出口门中心（射程从门重新起算）",
			bullet.start_pos.distance_to(bullets.to_local(exit_door.global_position)) <= 5.0,
			"start_pos=%s 期望≈%s" % [str(bullet.start_pos), str(bullets.to_local(exit_door.global_position))])
		_check(a, "子弹正从出口门继续向左飞",
			bullet.global_position.x < bullets.to_local(exit_door.global_position).x
			and absf(bullet.global_position.y - exit_door.global_position.y) <= 2.0,
			"实际 %s" % str(bullet.global_position))
		_check(a, "方向没变（还是向左）", bullet.direction == Vector2.LEFT)
		_check(a, "z_index 按新行更新", bullet.z_index == bullet.lane * 50 + 45,
			"实际 %d" % bullet.z_index)
		## 再飞 1 秒确认没有被「超过最大射程」销毁
		await a.wait(1.0)
		_check(a, "传送后子弹照常飞（没被当超程销毁）", is_instance_valid(bullet))
	if is_instance_valid(bullet):
		bullet.queue_free()
		await a.wait(0.5)

	# ------------------------------------------------ STEP4 定期换位
	a.log("STEP4 传送门到点换位（间隔 %.0f 秒）" % para.portal_reshuffle_interval)
	var before: Array[Vector2] = []
	for door: Portal in doors:
		before.append(door.global_position)
	## 换位间隔 + 淡出淡入动画的余量
	await a.wait(para.portal_reshuffle_interval + 3.0)
	var moved_num := 0
	for i in range(4):
		if is_instance_valid(doors[i]) and doors[i].global_position.distance_to(before[i]) > 1.0:
			moved_num += 1
	_check(a, "到点后门的位置变了", moved_num >= 2, "%d/4 扇挪动了" % moved_num)

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
