extends RefCounted
## 探针：DLC 模组的第三株植物 —— 「飓衣甘蓝」（Hurrikale，一次性飓风控制植物）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 100 阳光 / 30 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后
##   3. 图鉴：模组自己登记的那条「飓衣甘蓝」（冰冻 + 击退）
##   4. 种进草地：动画节点在、三段 DLC 动画都在、当前播 `Hurrikale_idle` 且在跑、没有再叠缩放
##   5. 摆放：把动画节点 position 临时归零，量**本地**包围盒（打印出来供校正确认），
##      并核对整株尺寸在本体豌豆射手的量级、底边与豌豆射手对齐
##   6. 飓风零件：起手 0.4 秒 / 冰冻 4 秒 / 减速 6 秒 / 击退 3 格（228 px）
##   7. 起手到点 → 播 `Hurrikale_blow`；播完 → 这一株**自行撤掉**（一次性植物腾出格子）
##   8. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 飓衣甘蓝的植物 id（模组自己起的字符串 id，本体不认得它）
const HURRIKALE := &"dlc_hurrikale"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的三段
const ALL_ANIMS: Array[String] = [
	"Hurrikale_idle", "Hurrikale_blow", "Hurrikale_loop",
]
const STATE_IDLE := &"Hurrikale_idle"
const STATE_BLOW := &"Hurrikale_blow"

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 对齐基准：本体豌豆射手（同为陆生植物，同一套 reanim → Godot 动画的画布口径）
const NATIVE_PEA_SCENE := "res://src/entities/character/plant/plant_pea_shooter_single.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「飓衣甘蓝」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 飓衣甘蓝登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(HURRIKALE, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "飓衣甘蓝登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "飓衣甘蓝阳光 = 100",
		int(registry.get_plant_info(HURRIKALE, CharacterRegistry.PlantInfoAttribute.SunCost)) == 100,
		str(registry.get_plant_info(HURRIKALE, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "飓衣甘蓝冷却 = 30 秒",
		is_equal_approx(float(registry.get_plant_info(HURRIKALE,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 30.0))
	_check(a, "飓衣甘蓝已解锁", Global.global_game_state.is_plant_unlocked(HURRIKALE))
	var condition = registry.get_plant_info(HURRIKALE,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "飓衣甘蓝登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "飓衣甘蓝是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "飓衣甘蓝占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "飓衣甘蓝不是紫卡（普通卡，100 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "飓衣甘蓝有卡位", AllCards.plant_card_ids.has(HURRIKALE))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(HURRIKALE, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 飓衣=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(HURRIKALE, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(HURRIKALE)
	_check(a, "装上模组后飓衣甘蓝有图鉴条目", str(entry.get("名字", "")) == "飓衣甘蓝", str(entry))
	_check(a, "图鉴里写的阳光是 100", str(entry.get("参数", {}).get("阳光", "")) == "100",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「冰冻」", str(entry.get("参数", {})).contains("冰冻"),
		str(entry.get("参数", {})))
	_check(a, "图鉴里写了「击退」", str(entry.get("参数", {})).contains("击退"),
		str(entry.get("参数", {})))

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 DLC 待机动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var kale = cell.create_plant(HURRIKALE, false, false)
	if kale == null:
		_check(a, "飓衣甘蓝能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(1)
	var player: AnimationPlayer = kale.get_node_or_null("Body/HurrikaleAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/HurrikaleAnim/AnimLib")
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
	var anim_root := kale.get_node_or_null("Body/HurrikaleAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))

	# ------------------------------------------------ STEP5 摆放（本地包围盒 + 与豌豆射手对齐）
	a.log("STEP5 摆放：本地包围盒（打印供校正） + 底边对齐本体豌豆射手")
	if anim_root != null:
		var native_scene: Node = load(NATIVE_PEA_SCENE).instantiate()
		var native_body: Node2D = native_scene.get_node("Body")
		var native_rect := AnimationFrameUtil.get_content_rect(native_body)
		## 本地包围盒：把动画节点 position 临时归零再量（get_content_rect 已含 root 自身变换），
		## 这样拿到的是「不含摆放偏移」的画布内容 rect，用来反推正确的 position
		var saved_pos: Vector2 = anim_root.position
		anim_root.position = Vector2.ZERO
		var local_rect := AnimationFrameUtil.get_content_rect(anim_root)
		anim_root.position = saved_pos
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 本地(未摆放)内容 rect=%s" % str(local_rect))
		a.log("   [INFO] 当前摆放后 Body 内 rect=%s" % str(content))
		a.log("   [INFO] 本体豌豆射手 Body 内容 rect=%s" % str(native_rect))
		a.log("   [INFO] 建议 position：中心x=%.1f 底边y=%.1f" %
			[-(local_rect.position.x + local_rect.size.x * 0.5), -(local_rect.position.y + local_rect.size.y)])
		_check(a, "整株尺寸在飓衣甘蓝的量级（大株：宽 150~200 / 高 150~190 px）",
			content.size.x >= 150.0 and content.size.x <= 200.0
				and content.size.y >= 150.0 and content.size.y <= 190.0,
			str(content.size))
		_check(a, "底边与豌豆射手对齐（差 ≤ 8 px）",
			absf(content.end.y - native_rect.end.y) <= 8.0,
			"豌豆底 %.1f / 飓衣底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()

	# ------------------------------------------------ STEP6 飓风零件与数值
	a.log("STEP6 飓风零件：起手 0.4 秒 + 冰冻 4 秒 + 减速 6 秒 + 击退 3 格")
	_check(a, "有起手计时器", kale.get_node_or_null("WindupTimer") != null)
	_check(a, "起手时长 = 0.4 秒", is_equal_approx(float(kale.get("windup_time")), 0.4),
		str(kale.get("windup_time")))
	_check(a, "冰冻时长 = 4 秒", is_equal_approx(float(kale.get("freeze_time")), 4.0),
		str(kale.get("freeze_time")))
	_check(a, "减速时长 = 6 秒", is_equal_approx(float(kale.get("decelerate_time")), 6.0),
		str(kale.get("decelerate_time")))
	_check(a, "击退 3 格（= 228 px）", is_equal_approx(float(kale.get("push_back_cells")), 3.0),
		str(kale.get("push_back_cells")))
	_check(a, "不造成伤害（攻击力 0，冰冻走 damage=0）", int(kale.get("attack_value")) == 0,
		str(kale.get("attack_value")))

	# ------------------------------------------------ STEP7 起手到点 → 播 blow → 播完自撤
	a.log("STEP7 起手到点播 blow，播完这一株自行撤掉（一次性植物）")
	await a.wait(0.6)
	_check(a, "起手结束后播的是 Hurrikale_blow", player.current_animation == STATE_BLOW,
		String(player.current_animation))
	## blow 2.8333 秒 + 余量；探针里没有主场景（get_main_game() 为空），效果安全跳过，
	## 但 blow 仍会播完、plant 仍会自行消失
	await a.wait(3.6)
	_check(a, "吹完风后这一株被撤掉（腾出格子）", not is_instance_valid(kale),
		"is_valid=%s" % str(is_instance_valid(kale)))

	# ------------------------------------------------ STEP8 关掉模组
	a.log("STEP8 关掉模组 → 撤干净")
	if is_instance_valid(cell):
		cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "飓衣甘蓝不再是已解锁", not Global.global_game_state.is_plant_unlocked(HURRIKALE))
	_check(a, "注册表里没有飓衣甘蓝了",
		registry.get_plant_info(HURRIKALE, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(HURRIKALE))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(HURRIKALE).get("名字", "")) != "飓衣甘蓝")

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
