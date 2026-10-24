extends RefCounted
## 探针：DLC 模组的新植物 —— 「芦荟」（AloeVera，50 阳光 / 3×3 范围治疗 / 不攻击）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 50 阳光 / 7.5 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「芦荟」（50 阳光 / 3×3 / 治疗 30 / 不叠加）
##   4. 种进草地：动画节点在、四段 DLC 动画都在、当前播 `AloeVera_idle` 且在跑、没有再叠缩放
##   5. 摆放：整株尺寸在花草量级，底边与本体向日葵对齐（同一套画布口径）
##   6. 治疗零件：范围 Area2D 只听植物受击框层（mask=2）、3×3 尺寸 228×285、
##      治疗间隔 3.0 秒、单次治疗 30
##   7. 行为：旁边格子放一株受伤植物 → 播 `AloeVera_heal`、目标回血 30；播完回待机
##   8. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 芦荟的植物 id（模组自己起的字符串 id，本体不认得它）
const ALOE := &"dlc_aloe"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的四段
const ALL_ANIMS: Array[String] = [
	"AloeVera_idle", "AloeVera_heal", "AloeVera_blink", "AloeVera_face",
]
const STATE_IDLE := &"AloeVera_idle"
const STATE_HEAL := &"AloeVera_heal"

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 对齐基准：本体向日葵（同为直立的陆生花草，同一套 reanim → Godot 动画的画布口径）
const NATIVE_SUN_FLOWER_SCENE := "res://src/entities/character/plant/plant_sun_flower.tscn"
## 拿来当「受伤的邻居」的植物（血厚，方便观察 30 点回血）
const NEIGHBOR_PLANT := PlantIds.WALL_NUT


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「芦荟」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 芦荟登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(ALOE, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "芦荟登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "芦荟阳光 = 50（wiki）",
		int(registry.get_plant_info(ALOE, CharacterRegistry.PlantInfoAttribute.SunCost)) == 50,
		str(registry.get_plant_info(ALOE, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "芦荟冷却 = 7.5 秒（wiki fast）",
		is_equal_approx(float(registry.get_plant_info(ALOE,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 7.5),
		str(registry.get_plant_info(ALOE, CharacterRegistry.PlantInfoAttribute.CoolTime)))
	_check(a, "芦荟已解锁", Global.global_game_state.is_plant_unlocked(ALOE))
	var condition = registry.get_plant_info(ALOE,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "芦荟登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "芦荟是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "芦荟占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "芦荟不是紫卡",
		not condition.is_purple_card, str(condition.is_purple_card))
	_check(a, "没给芦荟登记紫卡前置",
		not registry.AllPrePlantPurple.has(ALOE),
		str(registry.AllPrePlantPurple.get(ALOE, PlantIds.NULL)))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "芦荟有卡位", AllCards.plant_card_ids.has(ALOE))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(ALOE, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 芦荟=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(ALOE, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(ALOE)
	_check(a, "装上模组后芦荟有图鉴条目", str(entry.get("名字", "")) == "芦荟", str(entry))
	_check(a, "图鉴里写的阳光是 50", str(entry.get("参数", {}).get("阳光", "")) == "50",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「不叠加」",
		str(entry.get("参数", {}).get("特点", "")).contains("不叠加"),
		str(entry.get("参数", {}).get("特点", "")))
	_check(a, "图鉴里写了 3×3 范围",
		str(entry.get("参数", {}).get("范围", "")).contains("3×3"),
		str(entry.get("参数", {}).get("范围", "")))

	# ------------------------------------------------ STEP3.5 卡面
	a.log("STEP3.5 卡面：待机帧的内容中心落在卡面挂点")
	var face := AnimationFrameUtil.create_frame_node(plant_scene, &"AloeVera_idle", 0)
	if face == null:
		_check(a, "能取到卡面帧", false, "null")
	else:
		## 与 `dlc_mod.gd` 的 ALOE_CARD_FACE_SCALE / POSITION 保持一致
		face.scale = Vector2(0.5, 0.5)
		face.position = Vector2(0.0, 18.7)
		var card_rect := AnimationFrameUtil.get_content_rect(face)
		_check(a, "卡面内容中心落在挂点（±4 px）",
			absf(card_rect.get_center().x) <= 4.0 and absf(card_rect.get_center().y) <= 4.0,
			str(card_rect.get_center()))
		face.free()

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 DLC 待机动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var aloe = cell.create_plant(ALOE, false, false)
	if aloe == null:
		_check(a, "芦荟能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = aloe.get_node_or_null("Body/AloeVeraAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/AloeVeraAnim/AnimLib")
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
	## 原版缩放已经在动画的 `scale` 轨道里，动画根节点再叠一层就整株缩小
	var anim_root := aloe.get_node_or_null("Body/AloeVeraAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))

	# ------------------------------------------------ STEP5 摆放（与向日葵对齐）
	a.log("STEP5 摆放：整株尺寸与底边对齐本体向日葵")
	if anim_root != null:
		var native_scene: Node = load(NATIVE_SUN_FLOWER_SCENE).instantiate()
		var native_body: Node2D = native_scene.get_node("Body")
		## `get_content_rect(root)` 已经把 root 自己的 transform 算进去了 → 返回值就是 Body 坐标
		var native_rect := AnimationFrameUtil.get_content_rect(native_body)
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 本体向日葵 Body 内容 rect=%s" % str(native_rect))
		a.log("   [INFO] 芦荟 Body 内 rect=%s（anim_root.position=%s）" % [str(content), str(anim_root.position)])
		_check(a, "整株尺寸在花草量级（宽 40~100 / 高 30~110 px）",
			content.size.x >= 40.0 and content.size.x <= 100.0
				and content.size.y >= 30.0 and content.size.y <= 110.0,
			str(content.size))
		## 量的是**运行期**内容；按「底边对齐本体向日葵」反推摆放
		_check(a, "底边与向日葵对齐（差 ≤ 6 px）",
			absf(content.end.y - native_rect.end.y) <= 6.0,
			"向日葵底 %.1f / 芦荟底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()

	# ------------------------------------------------ STEP6 治疗零件与数值
	a.log("STEP6 治疗：3×3 范围（mask=2 / 228×285）+ 间隔 3 秒 + 单次 30")
	var heal_component := aloe.get_node_or_null("HealAreaComponent")
	_check(a, "挂了治疗范围组件", heal_component != null)
	var heal_area := aloe.get_node_or_null("HealAreaComponent/Area2D") as Area2D
	_check(a, "治疗范围是 Area2D 且开着 monitoring",
		heal_area != null and heal_area.monitoring,
		"null" if heal_area == null else "monitoring=%s" % str(heal_area.monitoring))
	_check(a, "治疗范围只听植物受击框层（mask=2）",
		heal_area != null and heal_area.collision_mask == 2,
		"null" if heal_area == null else "mask=%d" % heal_area.collision_mask)
	_check(a, "治疗范围自身不占任何碰撞层（layer=0）",
		heal_area != null and heal_area.collision_layer == 0,
		"null" if heal_area == null else "layer=%d" % heal_area.collision_layer)
	var heal_shape := aloe.get_node_or_null("HealAreaComponent/Area2D/CollisionShape2D") as CollisionShape2D
	var heal_rect: RectangleShape2D = null
	if heal_shape != null:
		heal_rect = heal_shape.shape as RectangleShape2D
	_check(a, "治疗范围 228×285（3 格宽 × 3 行高）",
		heal_rect != null and is_equal_approx(heal_rect.size.x, 228.0)
			and is_equal_approx(heal_rect.size.y, 285.0),
		"null" if heal_rect == null else str(heal_rect.size))
	_check(a, "治疗间隔计时器在", aloe.get_node_or_null("HealCdTimer") != null)
	_check(a, "治疗间隔 = 3.0 秒（wiki）",
		is_equal_approx(float(aloe.get("heal_interval")), 3.0),
		str(aloe.get("heal_interval")))
	_check(a, "单次治疗量 = 30（模组取值）",
		int(aloe.get("heal_amount")) == 30, str(aloe.get("heal_amount")))

	# ------------------------------------------------ STEP7 行为：隔壁受伤植物被治好
	a.log("STEP7 行为：旁边格子的受伤植物回血 30，芦荟播 heal 动画")
	## 第二个格子放到「右一格 + 下一行」，仍在芦荟 3×3 范围内
	var neighbor_cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	neighbor_cell.position = Vector2(76, 95)
	a.get_tree().root.add_child(neighbor_cell)
	await a.frames(1)
	var neighbor = neighbor_cell.create_plant(NEIGHBOR_PLANT, false, false)
	if neighbor == null:
		_check(a, "能放下邻居植物", false, "create_plant 返回 null")
		neighbor_cell.free()
	else:
		await a.frames(2)
		var neighbor_hp: HpComponent = neighbor.hp_component
		var before_hp := neighbor_hp.max_hp - 500
		neighbor_hp.curr_hp = before_hp
		## 等物理帧把两个受击框算进治疗范围 → 组件发 can_heal → 立刻治一轮
		await a.frames(4)
		_check(a, "受伤的邻居被回血 +30",
			neighbor_hp.curr_hp == before_hp + 30,
			"before=%d after=%d" % [before_hp, neighbor_hp.curr_hp])
		_check(a, "治疗时播 AloeVera_heal", player.current_animation == STATE_HEAL,
			String(player.current_animation))
		## 掐掉冷却计时器：本步只看治疗段的收尾，不让下一轮插进来
		var cd_timer: Timer = aloe.get_node("HealCdTimer")
		cd_timer.stop()
		await a.wait(1.4)
		_check(a, "治疗播完回到待机",
			player.is_playing() and player.current_animation == STATE_IDLE,
			"is_playing=%s curr=%s" % [str(player.is_playing()), String(player.current_animation)])
		neighbor.queue_free()
	neighbor_cell.free()

	# ------------------------------------------------ STEP8 关掉模组
	a.log("STEP8 关掉模组 → 撤干净")
	aloe.queue_free()
	cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "芦荟不再是已解锁", not Global.global_game_state.is_plant_unlocked(ALOE))
	_check(a, "注册表里没有芦荟了",
		registry.get_plant_info(ALOE, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(ALOE))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(ALOE).get("名字", "")) != "芦荟")

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
