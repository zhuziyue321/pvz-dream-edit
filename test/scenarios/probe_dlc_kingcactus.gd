extends RefCounted
## 探针：DLC 模组的第一个植物本体 —— 「环轨仙人掌」（美术资源名 KingCactus，紫卡）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 阳光 / 冷却 / 种植条件（普通陆生、占 Norm 位），且已解锁；
##      条件资源标成紫卡、`AllPrePlantPurple` 登记了本体仙人掌当基座
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「环轨仙人掌」
##   4. 种进草地：动画节点与 `AnimLib` 在，四段 DLC 动画都在，当前播 `KingCactus_idle` 且在跑
##   5. 射手零件：**全屏检测框**（不按行过滤 + 比屏幕大）、冷却计时器、出刺延迟计时器、数值对上
##   6. 八方向齐射：一轮 8 根、每 45° 一根；轴向加速度相邻两轮相反（+1 / -1 交替）
##   7. 尖刺轨迹：径向匀加速；**速度方向按恒定角速度旋转**，符号为 +1 往下弯、-1 往上弯
##   8. 有敌人：播 `KingCactus_shooting`；播完回 `KingCactus_idle`（不停在出刺最后一帧）
##   9. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 国王仙人掌的植物 id（模组自己起的字符串 id，本体不认得它）
const KING_CACTUS := &"dlc_kingcactus"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的四段
const ALL_ANIMS: Array[String] = [
	"KingCactus_idle", "KingCactus_shooting", "KingCactus_blink", "KingCactus_face",
]
const STATE_IDLE := &"KingCactus_idle"
const STATE_SHOOTING := &"KingCactus_shooting"

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 模组自己的尖刺（径向 + 轴向匀加速）
const SPIKE_SCENE_PATH := "res://mods_builtin/dlc/kingcactus/kingcactus_spike.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「环轨仙人掌」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 环轨仙人掌登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(KING_CACTUS, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "国王仙人掌登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "环轨仙人掌阳光 = 225（紫卡）",
		registry.get_plant_info(KING_CACTUS, CharacterRegistry.PlantInfoAttribute.SunCost) == 225)
	_check(a, "环轨仙人掌冷却 = 50 秒（wiki：very slow，紫卡大件）",
		registry.get_plant_info(KING_CACTUS, CharacterRegistry.PlantInfoAttribute.CoolTime) == 50.0)
	_check(a, "国王仙人掌已解锁", Global.global_game_state.is_plant_unlocked(KING_CACTUS))
	var condition = registry.get_plant_info(KING_CACTUS,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "国王仙人掌登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "国王仙人掌是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "环轨仙人掌占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	## 紫卡（升级卡）：判定在条件资源里（卡片 `_ready()` 读的就是它）
	_check(a, "条件资源标成紫卡（卡面换紫底 + 只能种在基座上）",
		condition.is_purple_card, str(condition.is_purple_card))
	_check(a, "紫卡前置植物 = 本体仙人掌（AllPrePlantPurple 由 PlantRuntimeKit 登记）",
		registry.AllPrePlantPurple.get(KING_CACTUS, PlantIds.NULL) == PlantIds.CACTUS,
		str(registry.AllPrePlantPurple.get(KING_CACTUS, PlantIds.NULL)))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "国王仙人掌有卡位", AllCards.plant_card_ids.has(KING_CACTUS))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(KING_CACTUS, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 仙人掌=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(KING_CACTUS, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	_check(a, "装上模组后环轨仙人掌有图鉴条目",
		str(Global.global_read_data.get_extra_almanac_entry(KING_CACTUS).get("名字", "")) == "环轨仙人掌",
		str(Global.global_read_data.get_extra_almanac_entry(KING_CACTUS)))

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 DLC 待机动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var cactus = cell.create_plant(KING_CACTUS, false, false)
	if cactus == null:
		_check(a, "国王仙人掌能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = cactus.get_node_or_null("Body/KingCactusAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/KingCactusAnim/AnimLib")
		cell.free()
		_finish(a)
		return
	var missing: Array[String] = []
	for anim_name in ALL_ANIMS:
		if not player.has_animation(anim_name):
			missing.append(anim_name)
	_check(a, "四段 DLC 动画都在播放器里", missing.is_empty(), str(missing))
	_check(a, "当前在播待机", player.current_animation == STATE_IDLE,
		String(player.current_animation))
	_check(a, "播放器真的在跑（不是停在第 0 帧）", player.is_playing())
	## 原版缩放已经在动画的 `scale` 轨道里（部件 0.762，与本体仙人掌的 0.8 同量级），
	## 动画根节点再叠一层就是「整株缩小」—— 曾踩过（加了 0.7）
	var anim_root := cactus.get_node_or_null("Body/KingCactusAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))
	if anim_root != null:
		## 对齐基准：本体仙人掌（同为「一丛刺座 + 花」的立绘）在格子里站哪
		var native_scene: Node = load("res://src/entities/character/plant/plant_cactus.tscn").instantiate()
		var native_body: Node2D = native_scene.get_node("Body")
		var native_rect := AnimationFrameUtil.get_content_rect(native_body)
		## `get_content_rect(root)` 已经把 root 自己的 transform 算进去了 → 返回值就是 Body 坐标
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 本体仙人掌 Body 内容 rect=%s" % str(native_rect))
		a.log("   [INFO] 国王仙人掌 Body 内 rect=%s" % str(content))
		## 本体仙人掌底部 +6.9；按反馈有意再下压，允许比它低 10~25 px
		_check(a, "整株贴地（底部比本体仙人掌低 10~25 px）",
			content.end.y >= native_rect.end.y + 10.0 and content.end.y <= native_rect.end.y + 25.0,
			"本体底 %.1f / 国王底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()
		_check(a, "整株尺寸在本体仙人掌的量级（宽 70~100 / 高 70~110 px）",
			content.size.x >= 70.0 and content.size.x <= 100.0
				and content.size.y >= 70.0 and content.size.y <= 110.0,
			str(content.size))

	# ------------------------------------------------ STEP5 射手零件与数值
	a.log("STEP5 射手：全屏检测框 + 冷却计时器 + 出刺延迟 + 数值（20 伤害 / 1.4 秒）")
	var detect := cactus.get_node_or_null("DetectComponent") as DetectComponent
	_check(a, "挂了检测组件", detect != null)
	_check(a, "检测组件不按行过滤（全屏索敌的前提）",
		detect != null and not detect.is_lane,
		"null" if detect == null else "is_lane=%s" % str(detect.is_lane))
	var detect_shape := cactus.get_node_or_null("DetectComponent/Area2D/CollisionShape2D") as CollisionShape2D
	var detect_rect: RectangleShape2D = null
	if detect_shape != null:
		detect_rect = detect_shape.shape as RectangleShape2D
	## 视口 800×600：框必须比屏幕大，植物种在角落也要罩住整场
	_check(a, "检测框覆盖整屏（宽 ≥ 1600 / 高 ≥ 1200）",
		detect_rect != null and detect_rect.size.x >= 1600.0 and detect_rect.size.y >= 1200.0,
		"null" if detect_rect == null else str(detect_rect.size))
	_check(a, "冷却计时器在", cactus.get_node_or_null("AttackCdTimer") != null)
	_check(a, "出刺延迟计时器在", cactus.get_node_or_null("ShootTimer") != null)
	_check(a, "攻击间隔 = 1.6 秒（长于开火动画 1.42 秒，不会被 CD 打断）",
		is_equal_approx(float(cactus.get("attack_cd")), 1.6),
		str(cactus.get("attack_cd")))
	_check(a, "出刺延迟 = 1.0 秒（开火动画最矮的第 12 帧）",
		is_equal_approx(float(cactus.get("shoot_delay")), 1.0),
		str(cactus.get("shoot_delay")))
	_check(a, "一根刺 = 20 伤害", int(cactus.get("bullet_damage")) == 20,
		str(cactus.get("bullet_damage")))

	# ------------------------------------------------ STEP6 八方向齐射 + 轴向加速度交替
	a.log("STEP6 八方向齐射：8 根 / 每 45° 一根；轴向加速度相邻两轮相反")
	var directions: Array[Vector2] = cactus.get_spray_directions()
	_check(a, "一轮正好 8 根", directions.size() == 8, str(directions.size()))
	_check(a, "第一根朝右（Vector2.RIGHT）",
		directions.size() > 0 and directions[0].is_equal_approx(Vector2.RIGHT),
		"" if directions.is_empty() else str(directions[0]))
	_check(a, "第二根朝右上 45°",
		directions.size() > 1 and directions[1].is_equal_approx(Vector2.RIGHT.rotated(PI / 4.0)),
		"" if directions.size() < 2 else str(directions[1]))
	_check(a, "第五根朝左（Vector2.LEFT，对向也打）",
		directions.size() > 4 and directions[4].is_equal_approx(Vector2.LEFT),
		"" if directions.size() < 5 else str(directions[4]))
	var evenly_spaced := true
	for i in range(directions.size()):
		var next_dir: Vector2 = directions[(i + 1) % directions.size()]
		if not is_equal_approx(directions[i].angle_to(next_dir), PI / 4.0):
			evenly_spaced = false
	_check(a, "相邻两根的夹角都是 45°", evenly_spaced)
	_check(a, "第一轮轴向加速度朝 +1", cactus.get_next_axial_sign() == 1.0,
		str(cactus.get_next_axial_sign()))
	cactus.set("_volley_index", 1)
	_check(a, "第二轮翻成 -1", cactus.get_next_axial_sign() == -1.0,
		str(cactus.get_next_axial_sign()))
	cactus.set("_volley_index", 2)
	_check(a, "第三轮又翻回 +1", cactus.get_next_axial_sign() == 1.0,
		str(cactus.get_next_axial_sign()))

	# ------------------------------------------------ STEP7 尖刺轨迹：径向匀加速 + 恒定角速度
	a.log("STEP7 尖刺轨迹：径向匀加速；速度方向按恒定角速度转，符号相反则往另一边弯")
	var spike_scene: PackedScene = load(SPIKE_SCENE_PATH)
	if spike_scene == null:
		_check(a, "尖刺场景能加载", false, SPIKE_SCENE_PATH)
	else:
		var spike_up := _spawn_test_spike(a, spike_scene, 1.0)
		var spike_down := _spawn_test_spike(a, spike_scene, -1.0)
		if spike_up != null:
			## 刚出手：方向还是发射方向（转向是在飞行中按角速度累积的）
			var velocity_start: Vector2 = spike_up.get("_velocity")
			_check(a, "刚出手时方向还是发射方向（转角 0）",
				is_zero_approx(velocity_start.angle()), str(velocity_start.angle()))
		await a.wait(0.5)
		if spike_up != null and spike_down != null:
			var velocity: Vector2 = spike_up.get("_velocity")
			var omega := float(spike_up.get("angular_speed"))
			var elapsed := float(spike_up.get("_elapsed"))
			var turned := absf(velocity.angle())
			_check(a, "转过的角度 = 角速度(%s) × 飞行时间(%s)" % [str(omega), str(elapsed)],
				absf(turned - omega * elapsed) < 0.05,
				"%s vs %s" % [str(turned), str(omega * elapsed)])
			_check(a, "速度大小在涨（径向加速，已超过初速 %s）" % str(spike_up.speed),
				velocity.length() > spike_up.speed, str(velocity.length()))
			_check(a, "轴向 +1：轨迹往下弯（y 明显为正）", spike_up.position.y > 5.0,
				str(spike_up.position))
			_check(a, "轴向 -1：轨迹往上弯（y 明显为负）", spike_down.position.y < -5.0,
				str(spike_down.position))
			_check(a, "两根的轴向弯法相反", signf(spike_up.position.y) != signf(spike_down.position.y),
				"%s vs %s" % [str(spike_up.position.y), str(spike_down.position.y)])
			_check(a, "横向（没有轴向分量时不该有的）位移极小：主运动仍是径向",
				absf(spike_up.position.x) > absf(spike_up.position.y),
				"%s" % str(spike_up.position))
		if spike_up != null:
			spike_up.queue_free()
		if spike_down != null:
			spike_down.queue_free()
		await a.frames(1)

	# ------------------------------------------------ STEP8 有敌人 → 播 shooting → 回待机
	a.log("STEP8 有敌人：播 shooting，播完回待机")
	detect.signal_can_attack.emit()
	await a.frames(2)
	_check(a, "检测到敌人后播的是 shooting", player.current_animation == STATE_SHOOTING,
		String(player.current_animation))
	## 掐掉冷却计时器：本步只看出刺段的收尾，不让下一发插进来
	var cd_timer: Timer = cactus.get_node("AttackCdTimer")
	cd_timer.stop()
	await a.wait(1.8)
	_check(a, "shooting 播完回到待机",
		player.is_playing() and player.current_animation == STATE_IDLE,
		"is_playing=%s curr=%s" % [str(player.is_playing()), String(player.current_animation)])
	detect.signal_not_can_attack.emit()

	# ------------------------------------------------ STEP9 关掉模组
	a.log("STEP9 关掉模组 → 撤干净")
	cactus.queue_free()
	cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "环轨仙人掌不再是已解锁", not Global.global_game_state.is_plant_unlocked(KING_CACTUS))
	_check(a, "注册表里没有环轨仙人掌了",
		registry.get_plant_info(KING_CACTUS, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(KING_CACTUS))
	_check(a, "紫卡前置植物的登记也擦掉了（否则裸索引会指到不存在的植物）",
		not registry.AllPrePlantPurple.has(KING_CACTUS),
		str(registry.AllPrePlantPurple.get(KING_CACTUS, PlantIds.NULL)))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(KING_CACTUS).get("名字", "")) != "环轨仙人掌")

	_finish(a)


## 造一颗只用来量轨迹的尖刺：朝右发射，只给轴向符号（不接 `main_game`，不需要真关卡）
func _spawn_test_spike(a, scene: PackedScene, axial_sign: float) -> Bullet000Base:
	var spike := scene.instantiate() as Bullet000Base
	if spike == null:
		return null
	spike.set(&"axial_sign", axial_sign)
	var paras: Dictionary = {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: false,
		Bullet000NormBase.E_InitParasAttr.BulletLane: 0,
		Bullet000NormBase.E_InitParasAttr.Position: Vector2.ZERO,
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.RIGHT,
	}
	spike.init_bullet(paras)
	a.get_tree().root.add_child(spike)
	return spike


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
