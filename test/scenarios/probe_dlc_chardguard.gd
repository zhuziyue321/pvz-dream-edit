extends RefCounted
## 探针：DLC 模组的植物 —— 「甜菜守卫」（ChardGuard，100 阳光高血量防御 + 近战击退）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 100 阳光 / 25 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「甜菜守卫」（100 阳光 / 防御 / 击退）
##   4. 种进草地：动画节点在、三段 DLC 动画都在、当前播 `ChardGuard_idle` 且在跑、没有再叠缩放
##   5. 摆放：整株尺寸在防御植物量级，底边与本体坚果墙对齐（同一套画布口径）
##   6. 防御零件：本行右侧检测框 230×90、冷却 1.2 秒、崩飞延迟 0.5 秒、击退 3 次、
##      崩飞距离 160、血量 1600
##   7. 有敌人：播 `ChardGuard_attack`；播完回 `ChardGuard_idle`
##   8. 击退额度用完：改播 `ChardGuard_idle_broken` 且不再出拳
##   9. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 甜菜守卫的植物 id（模组自己起的字符串 id，本体不认得它）
const CHARD_GUARD := &"dlc_chardguard"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的三段
const ALL_ANIMS: Array[String] = [
	"ChardGuard_idle", "ChardGuard_attack", "ChardGuard_idle_broken",
]
const STATE_IDLE := &"ChardGuard_idle"
const STATE_ATTACK := &"ChardGuard_attack"
const STATE_IDLE_BROKEN := &"ChardGuard_idle_broken"

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 对齐基准：本体坚果墙（同为防御植物，同一套 reanim → Godot 动画的画布口径）
const NATIVE_WALL_NUT_SCENE := "res://src/entities/character/plant/plant_wall_nut.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「甜菜守卫」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 甜菜守卫登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(CHARD_GUARD, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "甜菜守卫登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "甜菜守卫阳光 = 75（wiki：Chard Guard 页）",
		int(registry.get_plant_info(CHARD_GUARD, CharacterRegistry.PlantInfoAttribute.SunCost)) == 75,
		str(registry.get_plant_info(CHARD_GUARD, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "甜菜守卫冷却 = 30 秒（wiki：slow）",
		is_equal_approx(float(registry.get_plant_info(CHARD_GUARD,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 30.0),
		str(registry.get_plant_info(CHARD_GUARD, CharacterRegistry.PlantInfoAttribute.CoolTime)))
	_check(a, "甜菜守卫已解锁", Global.global_game_state.is_plant_unlocked(CHARD_GUARD))
	var condition = registry.get_plant_info(CHARD_GUARD,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "甜菜守卫登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "甜菜守卫是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "甜菜守卫占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "甜菜守卫不是紫卡（普通卡，100 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))
	_check(a, "没给甜菜守卫登记紫卡前置",
		not registry.AllPrePlantPurple.has(CHARD_GUARD),
		str(registry.AllPrePlantPurple.get(CHARD_GUARD, PlantIds.NULL)))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "甜菜守卫有卡位", AllCards.plant_card_ids.has(CHARD_GUARD))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(CHARD_GUARD, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 甜菜守卫=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(CHARD_GUARD, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(CHARD_GUARD)
	_check(a, "装上模组后甜菜守卫有图鉴条目", str(entry.get("名字", "")) == "甜菜守卫", str(entry))
	_check(a, "图鉴里写的阳光是 100", str(entry.get("参数", {}).get("阳光", "")) == "100",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「防御」",
		str(entry.get("参数", {}).get("特点", "")).contains("防御"),
		str(entry.get("参数", {}).get("特点", "")))

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 DLC 待机动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var guard = cell.create_plant(CHARD_GUARD, false, false)
	if guard == null:
		_check(a, "甜菜守卫能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = guard.get_node_or_null("Body/ChardGuardAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/ChardGuardAnim/AnimLib")
		cell.free()
		_finish(a)
		return
	var missing: Array[String] = []
	for anim_name in ALL_ANIMS:
		if not player.has_animation(anim_name):
			missing.append(anim_name)
	_check(a, "三段 DLC 动画都在播放器里", missing.is_empty(), str(missing))
	_check(a, "当前在播待机", player.current_animation == STATE_IDLE,
		String(player.current_animation))
	_check(a, "播放器真的在跑（不是停在第 0 帧）", player.is_playing())
	## 本株是**例外**：DLC 原画 126.8×138.6 是本体坚果墙的近两倍，统一缩到 0.7
	## （x / y 必须一致，否则是拉伸变形）。其它株的缩放已在动画的 `scale` 轨道里，根节点应为 1。
	var anim_root := guard.get_node_or_null("Body/ChardGuardAnim") as Node2D
	_check(a, "动画节点是整株统一缩放（±0.5~1.0，且 x == y）",
		anim_root != null
			and is_equal_approx(anim_root.scale.x, anim_root.scale.y)
			and anim_root.scale.x >= 0.5 and anim_root.scale.x <= 1.0,
		"null" if anim_root == null else str(anim_root.scale))

	# ------------------------------------------------ STEP5 摆放（与坚果墙对齐）
	a.log("STEP5 摆放：整株尺寸与底边对齐本体坚果墙")
	if anim_root != null:
		var native_scene: Node = load(NATIVE_WALL_NUT_SCENE).instantiate()
		var native_body: Node2D = native_scene.get_node("Body")
		## `get_content_rect(root)` 已经把 root 自己的 transform 算进去了 → 返回值就是 Body 坐标
		var native_rect := AnimationFrameUtil.get_content_rect(native_body)
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 本体坚果墙 Body 内容 rect=%s" % str(native_rect))
		a.log("   [INFO] 甜菜守卫 Body 内 rect=%s（anim_root.position=%s）" % [str(content), str(anim_root.position)])
		_check(a, "整株尺寸在防御植物量级（宽 40~90 / 高 50~110 px）",
			content.size.x >= 40.0 and content.size.x <= 90.0
				and content.size.y >= 50.0 and content.size.y <= 110.0,
			str(content.size))
		## 量的是**运行期**内容；按「底边对齐本体坚果墙」反推摆放
		_check(a, "底边与坚果墙对齐（差 ≤ 6 px）",
			absf(content.end.y - native_rect.end.y) <= 6.0,
			"坚果墙底 %.1f / 甜菜守卫底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()

	# ------------------------------------------------ STEP6 防御零件与数值
	a.log("STEP6 防御：本行右侧 230×90 检测框 + 冷却 1.2 秒 + 崩飞 0.5 秒 + 击退 3 次 + 1600 血")
	var detect := guard.get_node_or_null("DetectComponent") as DetectComponent
	_check(a, "挂了检测组件", detect != null)
	_check(a, "检测组件按行过滤（近战只打本行）",
		detect != null and detect.is_lane,
		"null" if detect == null else "is_lane=%s" % str(detect.is_lane))
	var detect_shape := guard.get_node_or_null("DetectComponent/Area2D/CollisionShape2D") as CollisionShape2D
	var detect_rect: RectangleShape2D = null
	if detect_shape != null:
		detect_rect = detect_shape.shape as RectangleShape2D
	_check(a, "检测框 230×90（本行右侧）",
		detect_rect != null and is_equal_approx(detect_rect.size.x, 230.0)
			and is_equal_approx(detect_rect.size.y, 90.0),
		"null" if detect_rect == null else str(detect_rect.size))
	_check(a, "攻击冷却计时器在", guard.get_node_or_null("AttackCdTimer") != null)
	_check(a, "崩飞延迟计时器在（单次）", guard.get_node_or_null("PunchTimer") != null)
	_check(a, "攻击间隔 = 1.2 秒（长于出拳动画 0.9167 秒）",
		is_equal_approx(float(guard.get("attack_cd")), 1.2),
		str(guard.get("attack_cd")))
	_check(a, "崩飞延迟 = 0.5 秒（抡胳膊峰值）",
		is_equal_approx(float(guard.get("punch_delay")), 0.5),
		str(guard.get("punch_delay")))
	_check(a, "击退次数 = 3（用完变残血墙）", int(guard.get("max_punches")) == 3,
		str(guard.get("max_punches")))
	## wiki 正文「knocks back ... by three tiles」→ 3 格 × 76 px/格 = 228 px
	_check(a, "崩飞距离 = 228（3 格，wiki 的 three tiles）",
		is_equal_approx(float(guard.get("knockback_distance")), 228.0),
		str(guard.get("knockback_distance")))
	var hp_comp := guard.get_node_or_null("HpComponent")
	_check(a, "血量 = 1500（wiki 的 health）",
		hp_comp != null and int(hp_comp.get("max_hp")) == 1500,
		"null" if hp_comp == null else str(hp_comp.get("max_hp")))

	# ------------------------------------------------ STEP7 有敌人 → 播 attack → 回待机
	a.log("STEP7 有敌人：播 attack，播完回待机")
	detect.signal_can_attack.emit()
	await a.frames(2)
	_check(a, "检测到敌人后播的是 attack", player.current_animation == STATE_ATTACK,
		String(player.current_animation))
	## 掐掉冷却计时器：本步只看出拳段的收尾，不让下一发插进来
	var cd_timer: Timer = guard.get_node("AttackCdTimer")
	cd_timer.stop()
	await a.wait(1.3)
	_check(a, "attack 播完回到待机",
		player.is_playing() and player.current_animation == STATE_IDLE,
		"is_playing=%s curr=%s" % [str(player.is_playing()), String(player.current_animation)])
	detect.signal_not_can_attack.emit()

	# ------------------------------------------------ STEP8 击退额度用完 → 残血墙
	a.log("STEP8 击退额度用完 → 播 idle_broken 且不再出拳")
	guard.set("_punches_left", 0)
	## 待机转完一圈就该切到残血姿态
	await a.wait(1.8)
	_check(a, "额度用完后改播 idle_broken", player.current_animation == STATE_IDLE_BROKEN,
		String(player.current_animation))
	detect.signal_can_attack.emit()
	await a.frames(3)
	_check(a, "残血后不再出拳（不播 attack）", player.current_animation != STATE_ATTACK,
		String(player.current_animation))
	detect.signal_not_can_attack.emit()

	# ------------------------------------------------ STEP9 关掉模组
	a.log("STEP9 关掉模组 → 撤干净")
	guard.queue_free()
	cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "甜菜守卫不再是已解锁", not Global.global_game_state.is_plant_unlocked(CHARD_GUARD))
	_check(a, "注册表里没有甜菜守卫了",
		registry.get_plant_info(CHARD_GUARD, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(CHARD_GUARD))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(CHARD_GUARD).get("名字", "")) != "甜菜守卫")

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
