extends RefCounted
## 探针：模组「招笑版」里的**傻豆射手**（豌豆射手 → 打傻豆攒怒气、满怒放大招）
##
## ① 改名：装模组前图鉴里叫「豌豆射手」，装上叫「傻豆射手」
## ② 每局安装：进一个白天关，种一株豌豆射手 → 身上挂一个观察者；
##    射击组件的发射点被**腾空**（它自己造不出本体豌豆了）
## ③ 手动打一发：场上多一颗**傻豆**、怒气 +0.2、整株被染红一点、这一发**没有**造出本体子弹
## ④ 傻豆**没有碰撞箱**：不是 `Bullet000Base`，子树里也没有 `Area2D`（视觉重合也不掉血）
## ⑤ 「掉地上」那种：本行前方摆一只僵尸（比「一只都没有时的默认飞行距离」更远）→
##    它**掉在僵尸前面一段**（掉落点离僵尸受击框前缘约 `SHADOU_FALL_GAP`，明显超过默认飞行距离
##    ⇒ 是被僵尸拦下的），落到**本行地面**上；落地那一下这颗傻豆消失、原地播一次
##    **「豌豆命中」特效**（本体 pea 那套：组 `zhaoxiao_pea_hit`）
## ⑥ 「射偏」那种：方向是**算出来的**，量它**实际飞的线**离僵尸受击框边缘只有一点点
##    （大于豌豆半径 ⇒ 打不中；又远小于「飞得老远」⇒ 恰好擦过去）；偏上、偏下都验一遍
## ⑦ 攒满怒气 → 自动放大招：怒气**匀速**往下走；这段时间场上出现**普通豌豆**
##    （`BulletIds.PEA`：速度落在设置区间内、角度在 ±设定角度内）
## ⑧ 大招走完：怒气归零、贴图回到原色
## ⑨ 关掉模组：名字还回去
##
## 机器可读汇总：最后一行 [ZHAOXIAO_SHADOU] result=PASS|FAIL failed=<n>

const Settings := preload("res://mods_builtin/zhaoxiao/zhaoxiao_settings.gd")
const Shadou := preload("res://mods_builtin/zhaoxiao/zhaoxiao_shadou.gd")
const PeashooterWatcher := preload("res://mods_builtin/zhaoxiao/zhaoxiao_peashooter.gd")

const LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"
## 种哪一格（行、列）
const PLANT_ROW := 2
const PLANT_COL := 1
## 判定「擦到了但没打中」的下限：豌豆自己的碰撞圆半径（本体 `bullet_norm_base.tscn` 的
## `CircleShape2D` 是默认半径 10）+ 一点余量。低于这个数就真会打中
const PEA_HIT_RADIUS := 12.0

var _failed := 0
## 跑过的断言条数（收尾报出来：整段没跑到时 failed 仍是 0，但条数会掉）
var _checks := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：模组「招笑版」· 傻豆射手 ==========")

	# ------------------------------------------------ STEP1 装上模组之前
	a.log("STEP1 模组关着时，图鉴里叫「豌豆射手」")
	_check(a, "图鉴名字 = 豌豆射手", _almanac_name() == "豌豆射手", _almanac_name())

	# ------------------------------------------------ STEP2 装上 → 改名
	a.log("STEP2 装上模组 → 名字变成「傻豆射手」")
	ModManager.set_mod_enabled(ModIds.ZHAOXIAO, true)
	_check(a, "图鉴名字 = 傻豆射手", _almanac_name() == "傻豆射手", _almanac_name())

	# ------------------------------------------------ STEP3 进关种一株
	a.log("STEP3 进一个白天关，种下一株豌豆射手")
	var para = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)
	var mg = GameContext.curr_main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "GameContext.curr_main_game 为空")
		_finish(a)
		return
	var manager: PlantCellManager = mg.plant_cell_manager
	var plant: Plant000Base = _plant(manager, PLANT_ROW, PLANT_COL, PlantIds.PEA_SHOOTER_SINGLE)
	if plant == null:
		_check(a, "傻豆射手种得下", false, "格子不可用")
		_finish(a)
		return
	## 观察者节点上的方法要动态调，这里一律用**无类型**变量接（见 check_scripts.ps1 的 KNOWN LIMITATION 2）
	var watcher = plant.get_node_or_null(PeashooterWatcher.NODE_PATH)
	_check(a, "这一株挂上了观察者", watcher != null)
	var attack: AttackComponentBulletBase = \
		plant.get_node_or_null(^"AttackComponent") as AttackComponentBulletBase
	if watcher == null or attack == null:
		_check(a, "观察者与射击组件都在", false, "节点缺失")
		_finish(a)
		return
	## 关掉这一株**真实**的攻击循环：本探针只按自己的节奏手动触发，不然它会自己出弹、
	## 自己攒怒气，随时把大招提前惹出来，断言就飘了
	attack.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	_check(a, "射击组件的发射点被腾空（本体不再自己造豌豆）",
		attack.markers_2d_bullet.is_empty(), "还剩 %d 个" % attack.markers_2d_bullet.size())

	# ------------------------------------------------ STEP4 手动打一发
	a.log("STEP4 手动打一发：多一颗傻豆、攒怒气、整株泛红，且**没有**造出本体子弹")
	var peas_before := _count_bullets(mg)
	var shadou_count_before := _shadou_list(mg).size()
	watcher.on_shoot_bullet()
	await a.wait(0.1)
	var shadou_list := _shadou_list(mg)
	_check(a, "场上多了一颗傻豆", shadou_list.size() == shadou_count_before + 1,
		"%d → %d" % [shadou_count_before, shadou_list.size()])
	_check(a, "怒气 = %.2f" % Settings.ANGER_PER_SHOT,
		is_equal_approx(float(watcher.get_anger()), Settings.ANGER_PER_SHOT),
		str(watcher.get_anger()))
	_check(a, "这一发**没有**造出本体子弹（发射点确实被接管了）",
		_count_bullets(mg) == peas_before, "%d → %d" % [peas_before, _count_bullets(mg)])
	var tinted: Color = plant.body.base_color
	_check(a, "整株被染红了一点（底色不再是纯白，红的通道最大）",
		tinted != Color.WHITE and tinted.r > tinted.g and tinted.r >= tinted.b,
		str(tinted))
	_check(a, "傻豆不是子弹类（没有损伤判定那套）", not (shadou_list[0] is Bullet000Base)
		if not shadou_list.is_empty() else false)

	# ------------------------------------------------ STEP5 没有碰撞箱
	a.log("STEP5 傻豆**没有碰撞箱**：子树里一个 Area2D 都没有")
	var first_shadou: Node2D = shadou_list[0] if not shadou_list.is_empty() else null
	_check(a, "傻豆身上有豌豆贴图（看起来像正常豌豆）",
		first_shadou != null and first_shadou.get_node_or_null(Shadou.SPRITE_PATH) != null)
	_check(a, "傻豆子树里没有 Area2D（也就没有碰撞箱）",
		first_shadou != null and not _has_area_2d(first_shadou))

	# ------------------------------------------------ STEP6 掉地上那种
	a.log("STEP6 「掉地上」那种：掉在僵尸**前面一段**，落地那一下播「豌豆命中」特效")
	## 先清场再摆自己的僵尸，免得刚刷出来的那些把「前面那只」抢走
	## （最后一波时清场会直接结算关卡，那样就别清了）
	if not mg.zombie_manager.is_end_wave:
		mg.zombie_manager.death_all_zombie()
	await a.wait(1.0)
	var zombie := _spawn_zombie(mg, PLANT_ROW)
	if zombie == null:
		_check(a, "本行摆得下一只僵尸", false, "wave_create_zombie 返回空")
	else:
		await a.wait(0.5)
		var drop_shadou: Node2D = watcher.spawn_shadou(Shadou.E_Kind.DropToGround)
		_check(a, "造出了一颗「掉地上」的傻豆", drop_shadou != null)
		if drop_shadou != null:
			await _check_drop_to_ground(a, mg, drop_shadou, zombie)

	# ------------------------------------------------ STEP7 射偏那种
	a.log("STEP7 「射偏」那种：方向是算出来的 —— **恰好擦过**僵尸，打不中")
	var miss_zombie := _nearest_zombie_ahead(mg)
	if miss_zombie == null:
		_check(a, "本行前面有僵尸可擦（不然「恰好」无从谈起）", false, "本行没有僵尸")
	else:
		var box := _hurt_box_rect(miss_zombie)
		_check(a, "读得到僵尸的受击框", box.size != Vector2.ZERO, str(box))
		if box.size != Vector2.ZERO:
			await _check_shoot_off_miss(a, watcher, -1.0, box, true)
			await _check_shoot_off_miss(a, watcher, 1.0, box, false)

	# ------------------------------------------------ STEP8 攒满怒气 → 大招
	a.log("STEP8 连着打满怒气 → 自动放大招：怒气匀速降、场上冒出普通豌豆")
	## 上一发已经攒了 0.2，这里再补到满
	var shots_to_full := int(ceil(Settings.ANGER_MAX / Settings.ANGER_PER_SHOT)) - 1
	for _i in range(shots_to_full):
		watcher.on_shoot_bullet()
	## ⚠️ 这里**不能**先 await 再看怒气：大招一开，怒气每帧都在往下走，
	## 等一帧就已经不是满值了。刚打完这一串就是满值。
	_check(a, "怒气满了（%.2f）" % Settings.ANGER_MAX,
		is_equal_approx(float(watcher.get_anger()), Settings.ANGER_MAX), str(watcher.get_anger()))
	_check(a, "自动进了大招", bool(watcher.is_in_ultimate()))
	var anger_t0 := float(watcher.get_anger())
	await a.wait(0.6)
	var anger_t1 := float(watcher.get_anger())
	_check(a, "大招期间怒气在下降", anger_t1 < anger_t0 - 0.05,
		"%.2f → %.2f" % [anger_t0, anger_t1])
	## 匀速：0.6 秒该降 0.6 / ULTIMATE_TIME
	var expected_rate := Settings.ANGER_MAX / Settings.ULTIMATE_TIME
	var real_rate := (anger_t0 - anger_t1) / 0.6
	_check(a, "降的速度是匀速的（约 %.2f / 秒）" % expected_rate,
		absf(real_rate - expected_rate) < expected_rate * 0.35,
		"实测 %.2f / 秒" % real_rate)
	var ultimate_peas := _bullet_list(mg)
	_check(a, "大招散射出了普通豌豆", ultimate_peas.size() > 0, "场上 %d 颗" % ultimate_peas.size())
	var pea_ok := true
	var angle_ok := true
	var pea_detail := ""
	for bullet in ultimate_peas:
		var norm_bullet: Bullet000NormBase = bullet as Bullet000NormBase
		if norm_bullet == null:
			continue
		if norm_bullet.bullet_type != BulletIds.PEA:
			pea_ok = false
			pea_detail = "类型 %s" % str(norm_bullet.bullet_type)
		if norm_bullet.speed < Settings.ULTIMATE_SPEED_RANGE.x - 0.5 \
				or norm_bullet.speed > Settings.ULTIMATE_SPEED_RANGE.y + 0.5:
			pea_ok = false
			pea_detail = "速度 %.1f" % norm_bullet.speed
		if absf(rad_to_deg(norm_bullet.direction.angle())) > Settings.ULTIMATE_ANGLE_DEG + 1.0:
			angle_ok = false
			pea_detail = "角度 %.1f°" % rad_to_deg(norm_bullet.direction.angle())
	_check(a, "散射的都是**普通豌豆**（类型对、速度落在设置区间内）", pea_ok, pea_detail)
	_check(a, "散射角度都在 ±%.0f 度之内" % Settings.ULTIMATE_ANGLE_DEG, angle_ok, pea_detail)

	# ------------------------------------------------ STEP9 大招走完
	a.log("STEP9 大招走完：怒气归零、贴图回到原色")
	await a.wait(Settings.ULTIMATE_TIME + 0.5)
	_check(a, "大招结束了", not bool(watcher.is_in_ultimate()))
	_check(a, "怒气归零", is_zero_approx(float(watcher.get_anger())), str(watcher.get_anger()))
	_check(a, "贴图回到原色（底色回到纯白）", plant.body.base_color == Color.WHITE,
		str(plant.body.base_color))

	# ------------------------------------------------ STEP10 关掉模组
	a.log("STEP10 关掉模组 → 名字还回去")
	ModManager.set_mod_enabled(ModIds.ZHAOXIAO, false)
	_check(a, "图鉴名字回到豌豆射手", _almanac_name() == "豌豆射手", _almanac_name())
	## 开关是**持久化**的，跑完必须存回去，别把后面的探针带歪
	ModManager.save_mods()
	_finish(a)


#region 「掉地上」那一段
## 盯着那颗傻豆：应当在**僵尸前面一段**转成掉落 → 落到**本行地面** → 消失并播一次「豌豆命中」特效
func _check_drop_to_ground(a, mg, shadou: Node2D, zombie: Zombie000Base) -> void:
	var start := shadou.global_position
	var ground_y: float = mg.get_row_base_global_y(PLANT_ROW)
	## 地面总在出生点下面（万一算出来比出生点还高，傻豆那边退让到「至少落下 24 像素」，这里照做）
	var expected_land_y := maxf(ground_y, start.y + 24.0)
	var fell_at_x := 0.0
	var fell := false
	var lowest_y := start.y
	## 掉落那一刻离僵尸受击框**前缘**还有多远（这是「掉在僵尸前面」的硬指标）
	var gap_to_front_edge := -1.0
	var effect_seen := false
	var effect_position := Vector2.ZERO
	var effect_node: Node = null
	for _i in range(140):
		if is_instance_valid(shadou):
			var pos: Vector2 = shadou.global_position
			lowest_y = maxf(lowest_y, pos.y)
			if not fell and pos.y > start.y + 4.0:
				fell = true
				fell_at_x = pos.x
				gap_to_front_edge = _front_edge_x(zombie) - fell_at_x
		## 脚下一块：这一帧「豌豆命中」特效在不在（它只活很短一会儿，得每帧看）
		var effects := _pea_hit_list(mg)
		if not effects.is_empty():
			effect_seen = true
			var effect := effects[0] as Node2D
			if is_instance_valid(effect):
				effect_position = effect.global_position
				effect_node = effect
		if fell and effect_seen and not is_instance_valid(shadou):
			break
		await a.wait(0.05)
	_check(a, "飞到僵尸前头转成了下落", fell)
	_check(a, "确实往下掉了一段（不是平着飞过去的）", lowest_y - start.y > 20.0,
		"Δy = %.1f" % (lowest_y - start.y))
	_check(a, "落点贴到了本行地面（地面 y = %.1f）" % ground_y,
		lowest_y >= expected_land_y - 30.0 and lowest_y <= expected_land_y + 1.0,
		"最低采样 y = %.1f（起点 %.1f）" % [lowest_y, start.y])
	_check(a, "掉完之后这颗傻豆就消失了", not is_instance_valid(shadou))
	_check(a, "落地那一下播了「豌豆命中」特效（组 %s）" % str(Shadou.PEA_HIT_GROUP), effect_seen)
	_check(a, "特效就播在掉落点上",
		effect_seen and absf(effect_position.x - fell_at_x) < 40.0
		and absf(effect_position.y - expected_land_y) < 26.0,
		"特效 %.0f,%.0f vs 落点 %.0f,%.0f" % [effect_position.x, effect_position.y,
			fell_at_x, expected_land_y])
	## 「命中**动画**」得真的在动：本体那套只显示溅射贴图的第一帧，
	## 模组把它自带的那几帧走了一遍（贴图是 4 帧的横条）
	if is_instance_valid(effect_node):
		var splats := effect_node.get_node_or_null(^"Splats") as Sprite2D
		_check(a, "命中特效里带着溅射贴图", splats != null)
		if splats != null:
			await a.wait(0.3)
			if is_instance_valid(splats):
				_check(a, "溅射贴图走到了最后一帧（命中动画真的在播）",
					splats.frame == splats.hframes - 1,
					"frame = %d / %d" % [splats.frame, splats.hframes - 1])
	if fell:
		## 「更靠前」：掉落点离僵尸受击框**前缘**还留着 `SHADOU_FALL_GAP` 这个量级的一段
		## （探针是在开始下落的**几帧后**才采到的，所以实测会略小于设定值）
		_check(a, "掉在僵尸**前面**一段（前缘还差 %.0f 像素上下）" % Settings.SHADOU_FALL_GAP,
			gap_to_front_edge > Settings.SHADOU_FALL_GAP * 0.4
			and gap_to_front_edge < Settings.SHADOU_FALL_GAP + 40.0,
			"实测差 %.1f 像素" % gap_to_front_edge)
		## 掉落点**明显超过**「前面一只僵尸都没有时的默认飞行距离」——
		## 说明它是被僵尸拦下来的，而不是飞远了才自己掉
		_check(a, "掉落点超过了「无僵尸时的默认飞行距离 %.0f」（说明是被僵尸拦下的）"
			% Settings.SHADOU_FALL_DISTANCE,
			fell_at_x - start.x > Settings.SHADOU_FALL_DISTANCE + 40.0,
			"掉了 %.1f 像素" % (fell_at_x - start.x))
#endregion


#region 「射偏」那一段
## 造一颗射偏的傻豆，量它**实际飞出来的那条直线**离僵尸受击框有多远：
## 必须「擦得到但擦不中」—— 离框边大于豌豆半径（真会打中），又远小于「飞得老远」
func _check_shoot_off_miss(a, watcher, off_sign: float, box: Rect2, is_up: bool) -> void:
	var side := "偏上（擦头顶）" if is_up else "偏下（贴脚底）"
	var shadou: Node2D = watcher.spawn_shadou(Shadou.E_Kind.ShootOff, off_sign)
	_check(a, "造出了一颗%s的傻豆" % side, shadou != null)
	if shadou == null:
		return
	var p0: Vector2 = shadou.global_position
	await a.wait(0.3)
	if not is_instance_valid(shadou):
		_check(a, "%s：还在飞" % side, false, "0.3 秒内就没了")
		return
	var p1: Vector2 = shadou.global_position
	var step := p1 - p0
	_check(a, "%s：往右飞出去了" % side, step.x > 40.0, "Δx = %.1f" % step.x)
	if absf(step.x) < 1.0:
		return
	## 傻豆飞的是直线：按实测这一段的斜率把它推到僵尸受击框那个 x 上，看离框边还有多远
	var slope := step.y / step.x
	var y_at_box := p1.y + slope * (box.get_center().x - p1.x)
	var clearance := box.position.y - y_at_box
	if not is_up:
		clearance = y_at_box - box.end.y
	_check(a, "%s：从框外擦过去（打不中，离框边 > 豌豆半径 %.0f）" % [side, PEA_HIT_RADIUS],
		clearance > PEA_HIT_RADIUS, "离框边 %.1f 像素" % clearance)
	_check(a, "%s：是**恰好**（不是飞得老远）" % side, clearance < 45.0,
		"离框边 %.1f 像素" % clearance)
	## 偏哪边也得对得上：偏上 = 越飞越往上（Godot 的 y 轴朝下，所以偏上是负的）
	var going_up := step.y < 0.0
	_check(a, "%s：方向确实是往%s偏的" % [side, "上" if is_up else "下"],
		going_up if is_up else not going_up, "Δy = %.1f" % step.y)
#endregion


#region 小工具
## 图鉴里豌豆射手那一条的「名字」（界面到处读的就是这一处）
func _almanac_name() -> String:
	var read_data := Global.global_read_data
	read_data.ensure_almanac_loaded()
	var all_plant_data: Dictionary = read_data.data_almanac.get("Plant", {})
	var entry: Dictionary = all_plant_data.get(Settings.PEASHOOTER_ALMANAC_KEY, {})
	return String(entry.get("名字", ""))


## 在指定格子种一株，返回那株植物（格子不可种 / 种不出来返回 null）
func _plant(manager, row: int, col: int, plant_type: StringName) -> Plant000Base:
	var cell: PlantCell = manager.all_plant_cells[row][col]
	if cell == null or not cell.can_common_plant:
		return null
	var plant := cell.create_plant(plant_type)
	return plant if is_instance_valid(plant) else null


## 摆一只普通僵尸到指定行（位置由调用方接着摆；返回空 = 摆不出来）
func _spawn_zombie(mg, lane: int) -> Zombie000Base:
	var create_manager = mg.zombie_manager.zombie_wave_manager.zombie_wave_create_manager
	if create_manager == null:
		return null
	var zombie: Zombie000Base = create_manager.wave_create_zombie(ZombieIds.NORM, lane, 0)
	return zombie if is_instance_valid(zombie) else null


## 本行最靠前的、非魅惑非空中的僵尸（「前面那只」的探针口径，与模组那边一致）
func _nearest_zombie_ahead(mg) -> Zombie000Base:
	if mg.zombie_manager == null or PLANT_ROW >= mg.zombie_manager.all_zombies_2d.size():
		return null
	var rows: Array = mg.zombie_manager.all_zombies_2d[PLANT_ROW]
	var nearest: Zombie000Base = null
	for i in range(rows.size()):
		var zombie: Zombie000Base = rows[i]
		if not is_instance_valid(zombie) or zombie.is_hypno:
			continue
		if zombie.curr_be_attack_status == Zombie000Base.E_BeAttackStatusZombie.IsSky:
			continue
		if nearest == null or zombie.global_position.x < nearest.global_position.x:
			nearest = zombie
	return nearest


## 僵尸受击框**前缘**（朝左走时面对豌豆的那一侧）的世界坐标 x；
## 读不到形状就退回僵尸原点（模组那边也是这么兜的）
func _front_edge_x(zombie: Zombie000Base) -> float:
	var box := _hurt_box_rect(zombie)
	if box.size == Vector2.ZERO:
		return zombie.global_position.x if is_instance_valid(zombie) else 0.0
	return box.position.x


## 僵尸**真实受击框**（`HurtBoxComponent/HurtBoxReal` 下那个碰撞形状）在世界坐标里的矩形
func _hurt_box_rect(zombie: Zombie000Base) -> Rect2:
	if not is_instance_valid(zombie):
		return Rect2()
	var component: HurtBoxComponent = zombie.hurt_box_component
	if component == null or not is_instance_valid(component.hurt_box_real):
		return Rect2()
	var shape_node: CollisionShape2D = null
	for child in component.hurt_box_real.get_children():
		shape_node = child as CollisionShape2D
		if shape_node != null:
			break
	if shape_node == null or shape_node.shape == null:
		return Rect2()
	var half_size := Vector2.ZERO
	var shape := shape_node.shape
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		half_size = Vector2(capsule.radius, capsule.height * 0.5)
	elif shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		half_size = rectangle.size * 0.5
	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		half_size = Vector2(circle.radius, circle.radius)
	else:
		return Rect2()
	if half_size.y <= 0.0:
		return Rect2()
	var center := shape_node.global_position
	return Rect2(center - half_size, half_size * 2.0)


## 场上现存的「豌豆命中」特效（按组名找，再滤掉这一帧刚被释放的）
func _pea_hit_list(mg) -> Array:
	var list: Array = []
	for node in mg.get_tree().get_nodes_in_group(Shadou.PEA_HIT_GROUP):
		if is_instance_valid(node):
			list.append(node)
	return list


## 场上现存的傻豆（按组名找，再滤掉这一帧刚被释放的）
func _shadou_list(mg) -> Array:
	var list: Array = []
	for node in mg.get_tree().get_nodes_in_group(Shadou.GROUP):
		if is_instance_valid(node):
			list.append(node)
	return list


## 子弹父节点下现存的真子弹（`Bullet000Base`）
func _bullet_list(mg) -> Array:
	var list: Array = []
	if mg.bullets == null:
		return list
	for child in mg.bullets.get_children():
		var bullet := child as Bullet000Base
		if bullet != null and is_instance_valid(bullet):
			list.append(bullet)
	return list


func _count_bullets(mg) -> int:
	return _bullet_list(mg).size()


## 子树里有没有 Area2D（傻豆必须一个都没有 = 没有碰撞箱）
func _has_area_2d(node: Node) -> bool:
	for child in node.get_children():
		if child is Area2D:
			return true
		if _has_area_2d(child):
			return true
	return false
#endregion


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	_checks += 1
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


## ⚠️ 除了 failed，还把**跑过的断言条数**报出来：
## 探针里某一段因为脚本报错（比如接口参数对不上）整段没跑到时，failed 仍然是 0（假绿），
## 但条数会掉下来 —— 与上一次跑的数一比就看出来了。
func _finish(a) -> void:
	a.log("")
	a.log("[ZHAOXIAO_SHADOU] result=%s failed=%d checks=%d"
		% ["PASS" if _failed == 0 else "FAIL", _failed, _checks])
	a.finish(true)
