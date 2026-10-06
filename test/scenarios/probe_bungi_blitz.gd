extends RefCounted
## 探针：蹦极闪电战（冒险模式 5-5 传送带关）
##
## 蹦极闪电战的规则：**不直接出怪**，僵尸全部由蹦极僵尸空投进场
##   正常波次 -> 空投僵尸的蹦极僵尸 Z026BungiDrop 把僵尸吊到场上再放下
##   大波     -> 本波照常空投，另外来一批**偷植物**的蹦极僵尸 Z021Bungi
##
## 覆盖：
##   1. 关卡资源：传送带卡池 = 花盆34 / 南瓜头31 / 大嘴花7 / 樱桃炸弹3；
##      空投归关卡脚本 adventure_05_05_bungi_blitz.gd（本体没有 is_bungi_blitz 开关）
##   2. 正常波次：出的是空投蹦极僵尸，僵尸落在场内（不是从场地边缘走进来）
##   3. 落地闭环：被吊的僵尸本体归位、能走、空投蹦极不偷植物、放下后自己离场
##   4. 大波：额外来偷植物的蹦极僵尸，偷完植物自己消失
##   5. 未开启的关卡（5-1）：照常从场地边缘出怪，不出现空投蹦极僵尸
##
## 机器可读汇总：最后一行 [BUNGIBLITZ] result=PASS|FAIL failed=<n>

const LEVEL_05_05 := "res://src/levels/mode_adventure/adventure_05_05.gd"
const LEVEL_05_01 := "res://src/levels/mode_adventure/adventure_05_01.gd"
## 5-5 传送带卡池（原版冒险 5-5 的四种发牌植物）
const EXPECT_POOL: Array = [
	CharacterRegistry.PlantType.P034FlowerPot,
	CharacterRegistry.PlantType.P031Pumpkin,
	CharacterRegistry.PlantType.P007Chomper,
	CharacterRegistry.PlantType.P003CherryBomb,
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 蹦极闪电战 ==========")

	_check_level_para(a)
	if not await _boot(a, LEVEL_05_05):
		_finish(a)
		return

	var blitz: Adventure0505BungiBlitz = _blitz_manager()
	if blitz == null:
		_check(a, "关卡脚本建出了蹦极闪电战管理器", false, "Adventure0505BungiBlitz 为空")
		_finish(a)
		return
	_check(a, "关卡脚本建出了蹦极闪电战管理器", true, blitz.get_path())
	_check(a, "管理器挂在关卡脚本这一侧（本体没有常驻节点）",
		Global.main_game.zombie_manager.get_node_or_null("BungiBlitzManager") == null,
		"本体残留节点=%s" % str(Global.main_game.zombie_manager.get_node_or_null("BungiBlitzManager")))

	await _check_drop_wave(a)
	await _check_big_wave_steal(a)
	await _check_norm_level(a)
	await _check_auto_wave(a)

	_finish(a)


#region 关卡资源

func _check_level_para(a) -> void:
	var para: ResourceLevelData = (load(LEVEL_05_05) as GDScript).new()
	if para == null:
		_check(a, "5-5 关卡资源可加载", false, LEVEL_05_05)
		return
	_check(a, "5-5 是传送带关", para.card_mode == ConstLevelData.E_CardMode.ConveyorBelt,
		"card_mode=%d" % para.card_mode)
	var pool: Array = para.conveyor_weights.filter(
		func(w): return w.card_reference.card_type == ResourceCardReference.CardType.Plant
	).map(func(w): return w.card_reference.content_id)
	pool.sort()
	var expect: Array = EXPECT_POOL.duplicate()
	expect.sort()
	_check(a, "5-5 传送带卡池 = 花盆/南瓜头/大嘴花/樱桃炸弹", pool == expect, "卡池=%s" % str(pool))
	_check(a, "5-5 大波保留偷植物的蹦极僵尸（is_bungi）", para.is_bungi, "is_bungi=%s" % str(para.is_bungi))

#endregion


#region 实机

func _boot(a, level: String) -> bool:
	var para: Resource = (load(level) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败: " + level)
		return false
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameRoof]
	)
	await a.wait(2.0)
	if Global.main_game == null:
		a.log("!! Global.main_game 为空")
		return false
	## 传送带关不进选卡阶段；万一进了就手动开始，避免关卡永远停在选卡
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.main_game_start()
	await a.wait(3.0)
	return Global.main_game != null and Global.main_game.zombie_manager != null


## 蹦极闪电战管理器归关卡脚本所有：从 game_para（= adventure_05_05.gd 实例）上取
func _blitz_manager() -> Adventure0505BungiBlitz:
	if Global.main_game == null or Global.main_game.game_para == null:
		return null
	## game_para 静态类型是 ResourceLevelData，这里按名字取（不是脚本关时取到 null）
	var blitz = Global.main_game.game_para.get("bungi_blitz")
	return blitz if is_instance_valid(blitz) else null


## 正常波次：僵尸由空投蹦极僵尸送进场
func _check_drop_wave(a) -> void:
	var zm = Global.main_game.zombie_manager
	var spawn_x: float = zm.all_zombie_rows[0].zombie_create_position.global_position.x

	zm.zombie_wave_manager.start_next_wave()
	await a.wait(1.0)

	var drop_num: int = _num(zm, true)
	var steal_num: int = _num(zm, false)
	_check(a, "正常波次生成了空投蹦极僵尸", drop_num > 0, "空投蹦极=%d" % drop_num)
	_check(a, "正常波次没有偷植物的蹦极僵尸", steal_num == 0, "偷植物蹦极=%d" % steal_num)

	var ground: Array = _ground_zombies(zm)
	_check(a, "本波有僵尸进场", not ground.is_empty(), "地面僵尸=%d" % ground.size())
	var edge_num := 0
	for z: Zombie000Base in ground:
		if z.global_position.x >= spawn_x - 60:
			edge_num += 1
	_check(a, "没有直接从场地边缘出怪（僵尸都落在场内）", edge_num == 0,
		"贴边僵尸=%d 生成点x=%.0f" % [edge_num, spawn_x])

	if ground.is_empty():
		return
	## 手动刷的这一波就够了，停掉刷新计时器，免得下一波插进来干扰判定
	zm.zombie_wave_manager.zombie_wave_refresh_manager.wave_norm_refresh_timer.stop()
	zm.zombie_wave_manager.zombie_wave_refresh_manager.wave_min_time_timer.stop()
	var drop_bungi: Zombie026BungiDrop = first_drop_bungi(zm)
	_check(a, "空投蹦极僵尸没有靶子", drop_bungi != null and not drop_bungi.bungee_target.visible,
		"靶子可见=%s" % str(drop_bungi.bungee_target.visible if drop_bungi != null else "?"))
	## 蹦极自己的贴图（含绳子）整体下移 10px，挂点 / 落点不动
	var body2: Sprite2D = drop_bungi.get_node_or_null("Body/BodyCorrect/Zombie_bungi_body2")
	_check(a, "蹦极的贴图整体下移了 10px", body2 != null and is_equal_approx(body2.offset.y, 10.0),
		"body2 贴图偏移=%s" % ("节点不存在" if body2 == null else str(body2.offset.y)))
	var carry: Zombie000Base = ground[0]
	var x_before: float = carry.global_position.x
	## 吊着的时候本体跟着绳子挂在半空、不能被打也不能走
	_check(a, "落地前僵尸本体挂在空投蹦极的绳子上",
		carry.body.global_position.y < carry.global_position.y - 200,
		"本体y=%.0f 地面y=%.0f" % [carry.body.global_position.y, carry.global_position.y])

	## 空投流程：降落 2 秒 + 起飞约 1 秒
	## （普通蹦极在降落前后各有一段 2 秒的等待，空投这两段都是 0；也没有单独的落地动画）
	## 边等边盯绳子：偷植物的蹦极会把植物本体塞进 BungiContainer，空投的那只不会
	var is_steal := false
	var anim_nodes: Array = []
	var enter_delay := -1.0
	var grab_delay := -1.0
	var first_seen := 0
	var raise_at := 0
	var not_hold_pose := ""
	var hurt_enabled := false
	var hang_x := -9999.0
	var carry_z_orig := -9999
	var carry_under := false
	## 怀里的僵尸在下落过程中该是一动不动的：画面采样只该出现一种，动画速度该是 0
	var carry_pose_set: Dictionary = {}
	var carry_anim_running := false
	## 图层：身体 < 怀里僵尸 < 抱着的「手 / 小臂」
	var carry_layering_checked := false
	var carry_layering_bad := ""
	## 降落过程中的高度采样，用来校验是不是「y 随时间正比例」的直线
	var curve_y: Array = []
	## 降落终点的几何关系：本体停在半空的高度 + 容器相对本体的偏移 = 0 时，
	## 绳子末端才会正好停在地面上
	var land_ok := true
	var land_text := ""
	## 全程应当只有一张画面：每次采样都把所有部件的位置记下来，理应只出现一种组合
	var snap_set: Dictionary = {}
	## 起飞只有 1 秒左右，采样要密一点才抓得到
	for i in range(56):
		await a.wait(0.25)
		if is_instance_valid(drop_bungi):
			if first_seen == 0:
				first_seen = Time.get_ticks_msec()
				enter_delay = float(drop_bungi.drop_start_delay)
				grab_delay = float(drop_bungi.grab_start_delay)
			if drop_bungi.bungi_container.get_child_count() > 0:
				is_steal = true
			## 它只是投放动画，受击框全程禁用才不会被索敌
			if drop_bungi.hurt_box_component.is_enabling:
				hurt_enabled = true
			## 怀里的僵尸：记下挂着时的横坐标，并检查它的图层在蹦极之上
			var carry_now: Zombie000Base = drop_bungi.carry_zombie
			if is_instance_valid(carry_now):
				hang_x = carry_now.body.global_position.x
				carry_z_orig = drop_bungi.carry_z_index
				if carry_now.z_index <= drop_bungi.z_index:
					carry_under = true
				## 挂在绳子上时：整只僵尸的部件画面不该变（不迈腿），动画速度该是 0
				carry_pose_set[pose_snapshot(carry_now)] = true
				if anim_speed_scale(carry_now) > 0.001:
					carry_anim_running = true
				## 被抱着的僵尸要夹在「身体」与「手 / 小臂」之间
				carry_layering_checked = true
				var bad := check_carry_layering(drop_bungi, carry_now)
				if bad != "" and carry_layering_bad == "":
					carry_layering_bad = bad
			var state := record_anim_node(drop_bungi, anim_nodes)
			if state == "Zombie_bungi_drop" or state == "Zombie_bungi_idle":
				curve_y.append(drop_bungi.bungi_container.global_position.y)
			## 每一帧的画面：本体下所有部件的可见 / 位移 / 转角拼成一串，理应全程只有一种
			snap_set[pose_snapshot(drop_bungi)] = state
			## 容器相对本体的纯偏移（减掉降落位移），和 landing_offset_y 互为相反数才对得上
			var container_dy := (drop_bungi.bungi_container.global_position.y
				- drop_bungi.global_position.y - drop_bungi.body_correct.position.y)
			if absf(drop_bungi.landing_offset_y + container_dy) > 0.5:
				land_ok = false
				land_text = "landing_offset_y=%.1f 容器相对本体偏移=%.1f" % [
					drop_bungi.landing_offset_y, container_dy]
			if state == "":
				continue
			if state == "Zombie_bungi_raise" and raise_at == 0:
				raise_at = Time.get_ticks_msec()
			## 全程都该是抱着姿态，没有松手之类的动画
			var pose := pose_text(drop_bungi)
			if pose != "抱着" and not_hold_pose == "":
				not_hold_pose = "%s 时是 %s" % [state, pose]
	var to_raise := 999.0 if raise_at == 0 else (raise_at - first_seen) / 1000.0
	_check(a, "空投蹦极没有前摇（进场就开始降落）", is_zero_approx(enter_delay),
		"前摇=%.2fs" % enter_delay)
	_check(a, "空投蹦极没有后摇（落地就起飞）", is_zero_approx(grab_delay),
		"后摇=%.2fs" % grab_delay)
	_check(a, "空投蹦极很快就进入起飞", to_raise < 3.5, "进场到起飞=%.1fs" % to_raise)
	_check(a, "空投蹦极全程都是抱着姿态（没有松手动画）", not_hold_pose == "",
		"不是抱着姿态的时候=%s" % not_hold_pose)
	_check(a, "空投蹦极全程不被索敌（受击框一直禁用）", not hurt_enabled,
		"受击框被启用过=%s" % str(hurt_enabled))
	_check(a, "空投蹦极僵尸不偷植物（绳子上只挂僵尸，没有植物）", not is_steal,
		"绳子上挂过植物=%s" % str(is_steal))
	_check(a, "怀里的僵尸盖在蹦极图层之上", not carry_under, "被蹦极挡住过=%s" % str(carry_under))
	_check(a, "怀里的僵尸下落时不动（部件画面全程不变）", carry_pose_set.size() <= 1,
		"出现过的画面数=%d" % carry_pose_set.size())
	_check(a, "怀里的僵尸下落时动画停住（不会在半空里迈腿）", not carry_anim_running,
		"挂着时动画速度跑起来过=%s" % str(carry_anim_running))
	_check(a, "被抱着的僵尸夹在身体与手 / 小臂中间", carry_layering_checked and carry_layering_bad == "",
		carry_layering_bad if carry_layering_bad != "" else "没采到挂着的僵尸")
	_check(a, "每帧画面都相同（整段只有一张静态图）", snap_set.size() == 1,
		"出现过的画面数=%d" % snap_set.size())
	_check(a, "降落终点让绳子末端正好停在地面（落脚点对齐）", land_ok, land_text)
	## 等间隔采样的落差应当一致——y 随时间正比例，且不缓冲
	var step_bad := ""
	if curve_y.size() >= 4:
		var s0 := float(curve_y[1]) - float(curve_y[0])
		var s1 := float(curve_y[2]) - float(curve_y[1])
		var s2 := float(curve_y[3]) - float(curve_y[2])
		var step_avg := (s0 + s1 + s2) / 3.0
		for s in [s0, s1, s2]:
			if step_avg <= 0 or absf(s - step_avg) > step_avg * 0.2:
				step_bad = "每段落差=%s" % str([s0, s1, s2].map(func(v): return snappedf(v, 1)))
	else:
		step_bad = "只采到 %d 个高度点" % curve_y.size()
	_check(a, "降落是匀速直线（y 随时间正比例、没有缓冲）", step_bad == "", step_bad)
	_check(a, "空投蹦极不放「抓取」动画", not anim_nodes.has("Zombie_bungi_grab"),
		"播过的动画=%s" % str(anim_nodes))
	_check(a, "空投蹦极不放「释放」之类的松手动画", not anim_nodes.has("Zombie_bungi_release"),
		"播过的动画=%s" % str(anim_nodes))
	_check(a, "空投蹦极放下僵尸后离场", _num(zm, true) == 0, "残留空投蹦极=%d" % _num(zm, true))
	if is_instance_valid(carry):
		_check(a, "被空投的僵尸本体落回地面",
			absf(carry.body.global_position.y - carry.global_position.y) < 2,
			"本体y=%.0f 地面y=%.0f" % [carry.body.global_position.y, carry.global_position.y])
		_check(a, "被空投的僵尸落地后能走", carry.global_position.x < x_before - 5,
			"落地x=%.0f 现在x=%.0f" % [x_before, carry.global_position.x])
		## 落地后僵尸会自己走，所以拿「挂着时的横坐标」和进场的落点比
		_check(a, "落地不横向跳（挂点与落点对齐）", absf(hang_x - x_before) < 2,
			"挂着时x=%.0f 落点x=%.0f" % [hang_x, x_before])
		_check(a, "落地后怀中僵尸的图层还原", carry.z_index == carry_z_orig,
			"落地后z=%d 原本z=%d" % [carry.z_index, carry_z_orig])
		_check(a, "落地后怀中僵尸的动画解冻", anim_speed_scale(carry) > 0.001,
			"落地后动画速度=%.3f" % anim_speed_scale(carry))
	## 被空投下来的僵尸会正常吃植物，这里只看蹦极僵尸自己有没有偷


## 大波：额外来一批偷植物的蹦极僵尸
func _check_big_wave_steal(a) -> void:
	var zm = Global.main_game.zombie_manager
	var plant_before: int = Global.main_game.plant_cell_manager.get_cell_have_plant().size()
	if plant_before <= 0:
		_check(a, "大波时场上有植物可偷（5-5 预置花盆）", false, "有植物的格子=0")
		return
	zm.zombie_wave_manager.zombie_wave_create_manager.spawn_special_zombie_in_big_wave(false)
	await a.wait(1.0)
	var steal_num: int = _num(zm, false)
	_check(a, "大波额外生成偷植物的蹦极僵尸", steal_num > 0, "偷植物蹦极=%d" % steal_num)
	await a.wait(15.0)
	_check(a, "偷植物的蹦极僵尸偷完自己消失", _num(zm, false) == 0, "残留=%d" % _num(zm, false))
	_check(a, "大波的蹦极僵尸真的偷走了植物",
		Global.main_game.plant_cell_manager.get_cell_have_plant().size() < plant_before,
		"偷前=%d 偷后=%d" % [plant_before, Global.main_game.plant_cell_manager.get_cell_have_plant().size()])


## 没开闪电战的关卡：照常从场地边缘出怪
func _check_norm_level(a) -> void:
	if not await _boot(a, LEVEL_05_01):
		return
	var zm = Global.main_game.zombie_manager
	var blitz := _blitz_manager()
	_check(a, "未开启的关卡：关卡脚本没有建空投管理器", blitz == null,
		"管理器=%s" % str(blitz))
	var spawn_x: float = zm.all_zombie_rows[0].zombie_create_position.global_position.x
	zm.zombie_wave_manager.start_next_wave()
	await a.wait(1.0)
	_check(a, "未开启的关卡：不出现空投蹦极僵尸", _num(zm, true) == 0, "空投蹦极=%d" % _num(zm, true))
	var ground: Array = _ground_zombies(zm)
	_check(a, "未开启的关卡：僵尸照常进场", not ground.is_empty(), "地面僵尸=%d" % ground.size())
	var edge_num := 0
	for z: Zombie000Base in ground:
		if z.global_position.x >= spawn_x - 60:
			edge_num += 1
	_check(a, "未开启的关卡：僵尸从场地边缘走进来", edge_num == ground.size(),
		"贴边僵尸=%d 总僵尸=%d" % [edge_num, ground.size()])


## 记录蹦极僵尸的动画状态机播到过哪几态，返回当前态
func record_anim_node(zombie: Zombie021Bungi, out: Array) -> String:
	var tree: AnimationTree = zombie.get_node_or_null("AnimationTree")
	if tree == null:
		return ""
	var playback = tree.get("parameters/StateMachine/playback")
	if playback == null:
		return ""
	var node_name := String(playback.get_current_node())
	if node_name != "" and not out.has(node_name):
		out.append(node_name)
	return node_name


## 当前是「抱着」姿态（body2 可见）还是「空手」姿态（普通身体可见）
func pose_text(zombie: Zombie021Bungi) -> String:
	var body := zombie.get_node_or_null("Body/BodyCorrect/Zombie_bungi_body")
	var body2 := zombie.get_node_or_null("Body/BodyCorrect/Zombie_bungi_body2")
	if body == null or body2 == null:
		return "?"
	if body2.visible and not body.visible:
		return "抱着"
	if body.visible and not body2.visible:
		return "空手"
	return "body=%s body2=%s" % [str(body.visible), str(body2.visible)]


## 当前这一帧长什么样：把本体下所有部件的可见 / 位移 / 转角 / 缩放拼成一串，
## 画面要是每帧都一样，整段采样下来就只该得到这一串
func pose_snapshot(zombie: Node) -> String:
	var body_correct: Node2D = zombie.get_node_or_null("Body/BodyCorrect")
	if body_correct == null:
		return "?"
	var parts := ""
	for part in body_correct.get_children():
		if not (part is Node2D):
			continue
		parts += "%s|%s|%s|%s|%s;" % [part.name, str(part.visible), str(part.position),
			str(part.rotation), str(part.scale)]
	return parts


## 挂着时的图层顺序：身体 < 怀里僵尸 < 抱着的「手 / 小臂」（后两者要压住同行的僵尸，
## 手 / 小臂用的是绝对 z，所以直接拿它的 z_index 和僵尸的「行 z + 自身 z」比）
## 返回空串表示顺序正确，否则返回原因
func check_carry_layering(bungi: Zombie026BungiDrop, carry: Zombie000Base) -> String:
	var row := carry.get_parent() as CanvasItem
	var row_z: int = row.z_index if row != null else 0
	var body_z: int = row_z + bungi.z_index
	var carry_z: int = row_z + carry.z_index
	if carry_z <= body_z:
		return "怀里僵尸z=%d 没盖住身体z=%d" % [carry_z, body_z]
	for path in Zombie026BungiDrop.CARRY_FRONT_PART_PATHS:
		var part: CanvasItem = bungi.get_node_or_null(path)
		if part == null:
			return "缺少抱姿部位节点 %s" % str(path)
		if part.z_as_relative:
			return "%s 用的是相对 z，压不住同行的僵尸" % str(path)
		if part.z_index <= carry_z:
			return "%s z=%d 没盖住怀里僵尸z=%d" % [str(path), part.z_index, carry_z]
	return ""


## 当前动画播放速度：AnimationTree 走 TimeScale，只有 AnimationPlayer 的角色走 speed_scale
## （僵尸两者都有，先读树；速度为 0 表示动画停住）
func anim_speed_scale(zombie: Zombie000Base) -> float:
	var tree: AnimationTree = zombie.get_node_or_null("AnimationTree")
	if tree != null:
		return float(tree.get("parameters/TimeScale/scale"))
	var player: AnimationPlayer = zombie.get_node_or_null("AnimationPlayer")
	if player != null:
		return player.speed_scale
	return -1.0


## 场上第一只空投蹦极僵尸
func first_drop_bungi(zm) -> Zombie026BungiDrop:
	for z in zm.all_zombies_1d:
		if is_instance_valid(z) and z is Zombie026BungiDrop:
			return z
	return null


## 不手动刷波，让关卡自己跑：确认波次真的会一波波推进
func _check_auto_wave(a) -> void:
	if not await _boot(a, LEVEL_05_05):
		return
	var zm = Global.main_game.zombie_manager
	## 5-5 的 first_wave_delay 是 20 秒，再等几波（最短波长 6 秒）
	var max_drop := 0
	for i in range(100):
		await a.wait(0.6)
		max_drop = maxi(max_drop, _num(zm, true))
		if zm.zombie_wave_manager.curr_wave >= 2 and max_drop > 0:
			break
	_check(a, "关卡自己刷波：波次推进正常", zm.zombie_wave_manager.curr_wave >= 1,
		"当前波次=%d" % zm.zombie_wave_manager.curr_wave)
	_check(a, "关卡自己刷波：僵尸是空投进来的", max_drop > 0, "出现过空投蹦极=%d" % max_drop)


## 空投蹦极僵尸 / 偷植物蹦极僵尸 的数量
## [is_drop] true 数空投的 Z026BungiDrop，false 数偷植物的 Z021Bungi（不含 Z026 子类）
func _num(zm, is_drop: bool) -> int:
	var num := 0
	for z in zm.all_zombies_1d:
		if not is_instance_valid(z):
			continue
		if is_drop:
			if z is Zombie026BungiDrop:
				num += 1
		## Z026 是 Z021 的子类，偷植物的那只要把子类排除掉
		elif z is Zombie021Bungi and not (z is Zombie026BungiDrop):
			num += 1
	return num


## 场上除了两种蹦极僵尸以外的僵尸（被空投的 / 走进来的）
func _ground_zombies(zm) -> Array:
	var res: Array = []
	for z in zm.all_zombies_1d:
		if is_instance_valid(z) and not (z is Zombie021Bungi):
			res.append(z)
	return res

#endregion


#region 工具

func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[BUNGIBLITZ] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()

#endregion
