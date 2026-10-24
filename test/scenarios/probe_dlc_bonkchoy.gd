extends RefCounted
## 探针：DLC 模组的第三株植物 —— 「拳击白菜」（BonkChoy，150 阳光近战出拳）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 150 阳光 / 7.5 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「拳击白菜」（150 阳光 / 近战 / 上勾拳）
##   4. 种进草地：动画节点在、五段 DLC 动画都在、当前播 `BonkChoy_idle` 且在跑、没有再叠缩放
##   5. 摆放：整株尺寸在卷心菜投手量级，底边与本体卷心菜投手对齐（同一套画布口径）
##   6. 近战零件：本行检测框 240×80、冷却 0.36 秒、直拳 20 / 上勾拳 40、攻击间隔 0.36 秒
##   7. 有敌人：播 `BonkChoy_shooting`（或能斩杀时 `BonkChoy_uppercut`）；播完回待机
##   8. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 拳击白菜的植物 id（模组自己起的字符串 id，本体不认得它）
const BONK_CHOY := &"dlc_bonkchoy"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的五段
const ALL_ANIMS: Array[String] = [
	"BonkChoy_idle", "BonkChoy_shooting", "BonkChoy_uppercut",
	"BonkChoy_blink", "BonkChoy_face",
]
const STATE_IDLE := &"BonkChoy_idle"
const STATE_SHOOTING := &"BonkChoy_shooting"
const STATE_UPPERCUT := &"BonkChoy_uppercut"

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 对齐基准：本体卷心菜投手（同为白菜类，同一套 reanim → Godot 动画的画布口径）
const NATIVE_CABBAGE_SCENE := "res://src/entities/character/plant/plant_cabbage_pult.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「拳击白菜」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 拳击白菜登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(BONK_CHOY, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "拳击白菜登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "拳击白菜阳光 = 150（模组取值）",
		int(registry.get_plant_info(BONK_CHOY, CharacterRegistry.PlantInfoAttribute.SunCost)) == 150,
		str(registry.get_plant_info(BONK_CHOY, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "拳击白菜冷却 = 7.5 秒（模组取值）",
		is_equal_approx(float(registry.get_plant_info(BONK_CHOY,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 7.5))
	_check(a, "拳击白菜已解锁", Global.global_game_state.is_plant_unlocked(BONK_CHOY))
	var condition = registry.get_plant_info(BONK_CHOY,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "拳击白菜登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "拳击白菜是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "拳击白菜占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "拳击白菜不是紫卡（普通卡，150 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))
	_check(a, "没给拳击白菜登记紫卡前置",
		not registry.AllPrePlantPurple.has(BONK_CHOY),
		str(registry.AllPrePlantPurple.get(BONK_CHOY, PlantIds.NULL)))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "拳击白菜有卡位", AllCards.plant_card_ids.has(BONK_CHOY))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(BONK_CHOY, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 拳击白菜=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(BONK_CHOY, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(BONK_CHOY)
	_check(a, "装上模组后拳击白菜有图鉴条目", str(entry.get("名字", "")) == "拳击白菜", str(entry))
	_check(a, "图鉴里写的阳光是 150", str(entry.get("参数", {}).get("阳光", "")) == "150",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「近战」",
		str(entry.get("参数", {}).get("特点", "")).contains("近战"),
		str(entry.get("参数", {}).get("特点", "")))

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 DLC 待机动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var choy = cell.create_plant(BONK_CHOY, false, false)
	if choy == null:
		_check(a, "拳击白菜能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = choy.get_node_or_null("Body/BonkChoyAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/BonkChoyAnim/AnimLib")
		cell.free()
		_finish(a)
		return
	var missing: Array[String] = []
	for anim_name in ALL_ANIMS:
		if not player.has_animation(anim_name):
			missing.append(anim_name)
	_check(a, "五段 DLC 动画都在播放器里", missing.is_empty(), str(missing))
	_check(a, "当前在播待机", player.current_animation == STATE_IDLE,
		String(player.current_animation))
	_check(a, "播放器真的在跑（不是停在第 0 帧）", player.is_playing())
	## 原版缩放已经在动画的 `scale` 轨道里，动画根节点再叠一层就整株缩小
	var anim_root := choy.get_node_or_null("Body/BonkChoyAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))

	# ------------------------------------------------ STEP5 摆放（与卷心菜投手对齐）
	a.log("STEP5 摆放：整株尺寸与底边对齐本体卷心菜投手")
	if anim_root != null:
		var native_scene: Node = load(NATIVE_CABBAGE_SCENE).instantiate()
		var native_body: Node2D = native_scene.get_node("Body")
		## `get_content_rect(root)` 已经把 root 自己的 transform 算进去了 → 返回值就是 Body 坐标
		var native_rect := AnimationFrameUtil.get_content_rect(native_body)
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 本体卷心菜投手 Body 内容 rect=%s" % str(native_rect))
		a.log("   [INFO] 拳击白菜 Body 内 rect=%s（anim_root.position=%s）" % [str(content), str(anim_root.position)])
		_check(a, "整株尺寸在白菜量级（宽 40~90 / 高 40~100 px）",
			content.size.x >= 40.0 and content.size.x <= 90.0
				and content.size.y >= 40.0 and content.size.y <= 100.0,
			str(content.size))
		## 量的是**运行期**内容；按「底边对齐本体卷心菜投手」反推摆放
		_check(a, "底边与卷心菜投手对齐（差 ≤ 4 px）",
			absf(content.end.y - native_rect.end.y) <= 4.0,
			"卷心菜底 %.1f / 拳击白菜底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()

	# ------------------------------------------------ STEP6 近战零件与数值
	a.log("STEP6 近战：本行 240×80 检测框 + 冷却 0.36 秒 + 直拳 20 / 上勾拳 40")
	var detect := choy.get_node_or_null("DetectComponent") as DetectComponent
	_check(a, "挂了检测组件", detect != null)
	_check(a, "检测组件按行过滤（近战只打本行）",
		detect != null and detect.is_lane,
		"null" if detect == null else "is_lane=%s" % str(detect.is_lane))
	var detect_shape := choy.get_node_or_null("DetectComponent/Area2D/CollisionShape2D") as CollisionShape2D
	var detect_rect: RectangleShape2D = null
	if detect_shape != null:
		detect_rect = detect_shape.shape as RectangleShape2D
	_check(a, "检测框 240×80（本行左右两格）",
		detect_rect != null and is_equal_approx(detect_rect.size.x, 240.0)
			and is_equal_approx(detect_rect.size.y, 80.0),
		"null" if detect_rect == null else str(detect_rect.size))
	_check(a, "攻击冷却计时器在", choy.get_node_or_null("AttackCdTimer") != null)
	## wiki `firerate = 0.36`：动作段（0.833 / 0.917 秒）比它还长，靠 `JAB_ANIM_SPEED`
	## 那层加速把动作压进一个出手间隔里（见 `bonkchoy_plant.gd` 的常量注释）
	_check(a, "攻击间隔 = 0.36 秒（wiki 的 firerate）",
		is_equal_approx(float(choy.get("attack_cd")), 0.36),
		str(choy.get("attack_cd")))
	_check(a, "直拳伤害 = 20（wiki 的 damage）", int(choy.get("jab_damage")) == 20,
		str(choy.get("jab_damage")))
	_check(a, "上勾拳伤害 = 40（wiki 没这一档，模组自定取直拳 2 倍）",
		int(choy.get("uppercut_damage")) == 40,
		str(choy.get("uppercut_damage")))

	# ------------------------------------------------ STEP7 有敌人 → 播出拳动画 → 回待机
	a.log("STEP7 有敌人：播 shooting，播完回待机")
	detect.signal_can_attack.emit()
	await a.frames(2)
	var playing_attack := player.current_animation == STATE_SHOOTING or player.current_animation == STATE_UPPERCUT
	_check(a, "检测到敌人后播出拳动画（shooting / uppercut）", playing_attack,
		String(player.current_animation))
	## 掐掉冷却计时器：本步只看出拳段的收尾，不让下一拳插进来
	var cd_timer: Timer = choy.get_node("AttackCdTimer")
	cd_timer.stop()
	await a.wait(1.2)
	_check(a, "出拳播完回到待机",
		player.is_playing() and player.current_animation == STATE_IDLE,
		"is_playing=%s curr=%s" % [str(player.is_playing()), String(player.current_animation)])
	detect.signal_not_can_attack.emit()

	# ------------------------------------------------ STEP8 关掉模组
	a.log("STEP8 关掉模组 → 撤干净")
	choy.queue_free()
	cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "拳击白菜不再是已解锁", not Global.global_game_state.is_plant_unlocked(BONK_CHOY))
	_check(a, "注册表里没有拳击白菜了",
		registry.get_plant_info(BONK_CHOY, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(BONK_CHOY))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(BONK_CHOY).get("名字", "")) != "拳击白菜")

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
