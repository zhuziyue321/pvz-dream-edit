extends RefCounted
## 探针：DLC 模组的「电击蘑菇」（VoltShroom，100 阳光周围 3×3 放电 AOE）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 100 阳光 / 7.5 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「电击蘑菇」（100 阳光 / 白天睡觉）
##   4. 种进草地：动画节点在、五段 DLC 动画都在、当前播 `VoltShroom_idle` 且在跑、没有再叠缩放
##   5. 摆放：整株尺寸在蘑菇量级，底边与本体小喷菇对齐（同一套画布口径）
##   6. 零件与数值：跨行 AOE 检测框（`is_lane=false`）228×260、冷却 7.5 秒、一次放电 400、白天睡觉
##   7. 有敌人：走「蓄电 charge → 放电 shooting → 收尾 fin → 回待机」这条链
##   8. 睡眠信号：进睡眠换 sleep 姿势，醒来回待机
##   9. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 电击蘑菇的植物 id（模组自己起的字符串 id，本体不认得它）
const VOLT_SHROOM := &"dlc_voltshroom"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的五段
const ALL_ANIMS: Array[String] = [
	"VoltShroom_idle", "VoltShroom_charge", "VoltShroom_shooting",
	"VoltShroom_fin", "VoltShroom_sleep",
]
const STATE_IDLE := &"VoltShroom_idle"
const STATE_CHARGE := &"VoltShroom_charge"
const STATE_SHOOTING := &"VoltShroom_shooting"
const STATE_SLEEP := &"VoltShroom_sleep"

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 对齐基准：本体小喷菇（同为蘑菇，同一套 reanim → Godot 动画的画布口径）
const NATIVE_PUFF_SCENE := "res://src/entities/character/plant/plant_puff.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「电击蘑菇」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 电击蘑菇登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(VOLT_SHROOM, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "电击蘑菇登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "电击蘑菇阳光 = 225（wiki：Volt-shroom 页）",
		int(registry.get_plant_info(VOLT_SHROOM, CharacterRegistry.PlantInfoAttribute.SunCost)) == 225,
		str(registry.get_plant_info(VOLT_SHROOM, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "电击蘑菇冷却 = 7.5 秒（模组取值）",
		is_equal_approx(float(registry.get_plant_info(VOLT_SHROOM,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 7.5))
	_check(a, "电击蘑菇已解锁", Global.global_game_state.is_plant_unlocked(VOLT_SHROOM))
	var condition = registry.get_plant_info(VOLT_SHROOM,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "电击蘑菇登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "电击蘑菇是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "电击蘑菇占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "电击蘑菇不是紫卡（普通卡，100 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))
	_check(a, "没给电击蘑菇登记紫卡前置",
		not registry.AllPrePlantPurple.has(VOLT_SHROOM),
		str(registry.AllPrePlantPurple.get(VOLT_SHROOM, PlantIds.NULL)))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "电击蘑菇有卡位", AllCards.plant_card_ids.has(VOLT_SHROOM))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(VOLT_SHROOM, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 电击菇=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(VOLT_SHROOM, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(VOLT_SHROOM)
	_check(a, "装上模组后电击蘑菇有图鉴条目", str(entry.get("名字", "")) == "电击蘑菇", str(entry))
	_check(a, "图鉴里写的阳光是 100", str(entry.get("参数", {}).get("阳光", "")) == "100",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「白天睡觉」",
		str(entry.get("参数", {}).get("特点", "")).contains("白天睡觉"),
		str(entry.get("参数", {}).get("特点", "")))

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 DLC 待机动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var shroom = cell.create_plant(VOLT_SHROOM, false, false)
	if shroom == null:
		_check(a, "电击蘑菇能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = shroom.get_node_or_null("Body/VoltShroomAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/VoltShroomAnim/AnimLib")
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
	var anim_root := shroom.get_node_or_null("Body/VoltShroomAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))

	# ------------------------------------------------ STEP5 摆放（与小喷菇对齐）
	a.log("STEP5 摆放：整株尺寸与底边对齐本体小喷菇")
	if anim_root != null:
		var native_scene: Node = load(NATIVE_PUFF_SCENE).instantiate()
		var native_body: Node2D = native_scene.get_node("Body")
		## `get_content_rect(root)` 已经把 root 自己的 transform 算进去了 → 返回值就是 Body 坐标
		var native_rect := AnimationFrameUtil.get_content_rect(native_body)
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 本体小喷菇 Body 内容 rect=%s" % str(native_rect))
		a.log("   [INFO] 电击蘑菇 Body 内 rect=%s（anim_root.position=%s）" % [str(content), str(anim_root.position)])
		## 电击蘑菇带个笼子，比小喷菇大一圈：宽 45~90 / 高 40~90 px
		_check(a, "整株尺寸在蘑菇量级（宽 45~90 / 高 40~90 px）",
			content.size.x >= 45.0 and content.size.x <= 90.0
				and content.size.y >= 40.0 and content.size.y <= 90.0,
			str(content.size))
		_check(a, "底边与小喷菇对齐（差 ≤ 4 px）",
			absf(content.end.y - native_rect.end.y) <= 4.0,
			"小喷菇底 %.1f / 电击菇底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()

	# ------------------------------------------------ STEP6 放电零件与数值
	a.log("STEP6 AOE：跨行检测框 380×260（3×5）+ 持续放电 40 总伤害/秒（均分）+ 白天睡觉")
	var detect := shroom.get_node_or_null("DetectComponent") as DetectComponent
	_check(a, "挂了检测组件", detect != null)
	## 电击蘑菇打周围一圈（含上下行）→ 不按行过滤
	_check(a, "检测组件**不**按行过滤（周围 AOE 跨行）",
		detect != null and not detect.is_lane,
		"null" if detect == null else "is_lane=%s" % str(detect.is_lane))
	var detect_shape := shroom.get_node_or_null("DetectComponent/Area2D/CollisionShape2D") as CollisionShape2D
	var detect_rect: RectangleShape2D = null
	if detect_shape != null:
		detect_rect = detect_shape.shape as RectangleShape2D
	## wiki `range = 3x5` → 3 行 × 5 列：5 格 ≈ 380 px 宽、3 行 ≈ 260 px 高
	_check(a, "检测框 380×260（3 行 × 5 列）",
		detect_rect != null and is_equal_approx(detect_rect.size.x, 380.0)
			and is_equal_approx(detect_rect.size.y, 260.0),
		"null" if detect_rect == null else str(detect_rect.size))
	_check(a, "攻击冷却计时器在", shroom.get_node_or_null("AttackCdTimer") != null)
	## wiki `firerate = Constant`：有目标就一轮接一轮地放，默认不额外等冷却
	_check(a, "持续放电：默认不起冷却（attack_cd = 0）",
		is_equal_approx(float(shroom.get("attack_cd")), 0.0),
		str(shroom.get("attack_cd")))
	## wiki `damage = potent (~40 DPS for one target), divides between several zombies`
	_check(a, "放电总输出 = 40/秒（范围内**均分**）",
		is_equal_approx(float(shroom.get("discharge_dps")), 40.0),
		str(shroom.get("discharge_dps")))
	_check(a, "标了白天睡觉（蘑菇）",
		bool(shroom.get_node("SleepComponent").get("is_sleep_in_day")))
	_check(a, "睡觉时停索敌（检测组件在 sleep_influence_components 里）",
		shroom.get_node("SleepComponent").get("sleep_influence_components").has(detect))

	# ------------------------------------------------ STEP7 有敌人 → 蓄电 → 放电 → 收尾 → 待机
	a.log("STEP7 有敌人：走 蓄电→放电→收尾 这条链，播完回待机")
	detect.signal_can_attack.emit()
	await a.frames(2)
	_check(a, "检测到敌人后先蓄电（charge）", player.current_animation == STATE_CHARGE,
		String(player.current_animation))
	## charge 0.667s 播完 → 自动接放电（shooting）并结算伤害
	await a.wait(0.8)
	_check(a, "蓄电播完接放电（shooting）", player.current_animation == STATE_SHOOTING,
		String(player.current_animation))
	## wiki `firerate = Constant`：收尾播完**立刻接下一轮**蓄电 —— 有目标就连着放，不等冷却
	await a.wait(0.9)
	_check(a, "持续放电：收尾播完直接接下一轮蓄电",
		player.current_animation == STATE_CHARGE,
		"curr=%s" % String(player.current_animation))
	## 目标清空后才停手回待机
	detect.signal_not_can_attack.emit()
	await a.wait(1.6)
	_check(a, "目标清空后回到待机",
		player.is_playing() and player.current_animation == STATE_IDLE,
		"is_playing=%s curr=%s" % [str(player.is_playing()), String(player.current_animation)])

	# ------------------------------------------------ STEP8 睡眠信号换姿势
	a.log("STEP8 睡眠：进睡眠换 sleep 姿势，醒来回待机")
	var sleep: SleepComponent = shroom.get_node("SleepComponent")
	sleep.start_sleep()
	await a.frames(2)
	_check(a, "睡着时播 VoltShroom_sleep", player.current_animation == STATE_SLEEP,
		String(player.current_animation))
	sleep.end_sleep()
	await a.frames(2)
	_check(a, "醒来回待机", player.current_animation == STATE_IDLE,
		String(player.current_animation))

	# ------------------------------------------------ STEP9 关掉模组
	a.log("STEP9 关掉模组 → 撤干净")
	shroom.queue_free()
	cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "电击蘑菇不再是已解锁", not Global.global_game_state.is_plant_unlocked(VOLT_SHROOM))
	_check(a, "注册表里没有电击蘑菇了",
		registry.get_plant_info(VOLT_SHROOM, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(VOLT_SHROOM))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(VOLT_SHROOM).get("名字", "")) != "电击蘑菇")

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
