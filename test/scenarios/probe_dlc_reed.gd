extends RefCounted
## 探针：DLC 模组的第四株植物 —— 「闪电芦苇」（Reed，125 阳光短距链状闪电）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 125 阳光 / 5 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「闪电芦苇」（125 阳光 / 链状闪电）
##   4. 种进草地：动画节点在、五段 DLC 动画都在、当前播 `Reed_idle` 且在跑、没有再叠缩放
##   5. 摆放：整株尺寸在细长芦苇量级，底边与本体豌豆射手对齐（同一套画布口径）
##   6. 零件与数值：本行检测框 380×140、冷却 1.1 秒、一段 15、连锁上限 3、跳距 130
##   7. 有敌人：播 `Reed_attack`；播完回待机；闪电特效场景可用
##   8. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 闪电芦苇的植物 id（模组自己起的字符串 id，本体不认得它）
const REED := &"dlc_reed"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的五段
const ALL_ANIMS: Array[String] = [
	"Reed_idle", "Reed_attack", "Reed_idle_charged",
	"Reed_blink", "Reed_face",
]
const STATE_IDLE := &"Reed_idle"
const STATE_ATTACK := &"Reed_attack"

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 对齐基准：本体豌豆射手（同为直立陆生植物，同一套 reanim → Godot 动画的画布口径）
const NATIVE_PEA_SCENE := "res://src/entities/character/plant/plant_pea_shooter_single.tscn"
## 闪电特效场景（模组自己的纯 draw_line 特效）
const REED_FX_SCENE := "res://mods_builtin/dlc/reed/reed_lightning.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「闪电芦苇」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 闪电芦苇登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(REED, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "闪电芦苇登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	if plant_scene == null:
		## 场景都没登记上（多半是 dlc 模组没加载起来）：后续检查全无意义，直接收尾
		_finish(a)
		return
	var reed_sun = registry.get_plant_info(REED, CharacterRegistry.PlantInfoAttribute.SunCost)
	_check(a, "闪电芦苇阳光 = 125（模组取值）",
		reed_sun != null and int(reed_sun) == 125, str(reed_sun))
	var reed_cool = registry.get_plant_info(REED, CharacterRegistry.PlantInfoAttribute.CoolTime)
	_check(a, "闪电芦苇冷却 = 7.5 秒（wiki：fast）",
		reed_cool != null and is_equal_approx(float(reed_cool), 7.5), str(reed_cool))
	_check(a, "闪电芦苇已解锁", Global.global_game_state.is_plant_unlocked(REED))
	var condition = registry.get_plant_info(REED,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "闪电芦苇登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "闪电芦苇是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "闪电芦苇占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "闪电芦苇不是紫卡（普通卡，125 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))
	_check(a, "没给闪电芦苇登记紫卡前置",
		not registry.AllPrePlantPurple.has(REED),
		str(registry.AllPrePlantPurple.get(REED, PlantIds.NULL)))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "闪电芦苇有卡位", AllCards.plant_card_ids.has(REED))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(REED, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 闪电芦苇=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(REED, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(REED)
	_check(a, "装上模组后闪电芦苇有图鉴条目", str(entry.get("名字", "")) == "闪电芦苇", str(entry))
	_check(a, "图鉴里写的阳光是 125", str(entry.get("参数", {}).get("阳光", "")) == "125",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「链状」",
		str(entry.get("参数", {}).get("特点", "")).contains("链状"),
		str(entry.get("参数", {}).get("特点", "")))

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 DLC 待机动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var reed = cell.create_plant(REED, false, false)
	if reed == null:
		_check(a, "闪电芦苇能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = reed.get_node_or_null("Body/ReedAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/ReedAnim/AnimLib")
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
	var anim_root := reed.get_node_or_null("Body/ReedAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))

	# ------------------------------------------------ STEP5 摆放（与豌豆射手对齐）
	a.log("STEP5 摆放：整株尺寸与底边对齐本体豌豆射手")
	if anim_root != null:
		var native_scene: Node = load(NATIVE_PEA_SCENE).instantiate()
		var native_body: Node2D = native_scene.get_node("Body")
		## `get_content_rect(root)` 已经把 root 自己的 transform 算进去了 → 返回值就是 Body 坐标
		var native_rect := AnimationFrameUtil.get_content_rect(native_body)
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 本体豌豆射手 Body 内容 rect=%s" % str(native_rect))
		a.log("   [INFO] 闪电芦苇 Body 内 rect=%s（anim_root.position=%s）" % [str(content), str(anim_root.position)])
		_check(a, "整株尺寸在细长芦苇量级（宽 25~90 / 高 50~130 px）",
			content.size.x >= 25.0 and content.size.x <= 90.0
				and content.size.y >= 50.0 and content.size.y <= 130.0,
			str(content.size))
		## 量的是**运行期**内容；按「底边对齐本体豌豆射手」反推摆放
		_check(a, "底边与豌豆射手对齐（差 ≤ 4 px）",
			absf(content.end.y - native_rect.end.y) <= 4.0,
			"豌豆底 %.1f / 闪电芦苇底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()

	# ------------------------------------------------ STEP6 零件与数值
	a.log("STEP6 链状闪电零件与数值")
	var detect := reed.get_node_or_null("DetectComponent") as DetectComponent
	_check(a, "挂了检测组件", detect != null)
	## wiki `range = Three lanes` → 索敌跨三行，所以**不**按行过滤
	_check(a, "检测组件**不**按行过滤（wiki：Three lanes，跨三行）",
		detect != null and not detect.is_lane,
		"null" if detect == null else "is_lane=%s" % str(detect.is_lane))
	var detect_shape := reed.get_node_or_null("DetectComponent/Area2D/CollisionShape2D") as CollisionShape2D
	var detect_rect: RectangleShape2D = null
	if detect_shape != null:
		detect_rect = detect_shape.shape as RectangleShape2D
	## 高 260 px ≈ 三行（与 voltshroom 跨行同一口径：一行 ≈ 85 px）
	_check(a, "检测框 380×260（跨三行）",
		detect_rect != null and is_equal_approx(detect_rect.size.x, 380.0)
			and is_equal_approx(detect_rect.size.y, 260.0),
		"null" if detect_rect == null else str(detect_rect.size))
	_check(a, "攻击冷却计时器在", reed.get_node_or_null("AttackCdTimer") != null)
	_check(a, "落雷计时器在（one_shot）",
		reed.get_node_or_null("ShootTimer") != null)
	_check(a, "攻击间隔 = 1.5 秒（wiki 的 firerate；长于开火动画 0.71 秒）",
		is_equal_approx(float(reed.get("attack_cd")), 1.5),
		str(reed.get("attack_cd")))
	_check(a, "每段伤害 = 10（wiki 的 damage）", int(reed.get("bullet_damage")) == 10,
		str(reed.get("bullet_damage")))
	_check(a, "连锁上限 = 3（首发 + 连锁 2）", int(reed.get("max_chain")) == 3,
		str(reed.get("max_chain")))
	_check(a, "相邻跳距 = 130 px",
		is_equal_approx(float(reed.get("chain_range")), 130.0),
		str(reed.get("chain_range")))

	# ------------------------------------------------ STEP7 有敌人 → 播 attack → 回待机
	a.log("STEP7 有敌人：播 attack，播完回待机")
	detect.signal_can_attack.emit()
	await a.frames(2)
	_check(a, "检测到敌人后播开火动画（attack）",
		player.current_animation == STATE_ATTACK,
		String(player.current_animation))
	## 掐掉冷却计时器：本步只看开火段的收尾，不让下一次放电插进来
	var cd_timer: Timer = reed.get_node("AttackCdTimer")
	cd_timer.stop()
	await a.wait(1.2)
	_check(a, "开火播完回到待机",
		player.is_playing() and player.current_animation == STATE_IDLE,
		"is_playing=%s curr=%s" % [str(player.is_playing()), String(player.current_animation)])
	detect.signal_not_can_attack.emit()

	# 闪电特效场景可用（纯 draw_line，无贴图）
	_check(a, "闪电特效场景存在",
		ResourceLoader.exists(REED_FX_SCENE), REED_FX_SCENE)
	if ResourceLoader.exists(REED_FX_SCENE):
		var fx: Node = load(REED_FX_SCENE).instantiate()
		_check(a, "闪电特效是个 Node2D", fx is Node2D, fx.get_class())
		_check(a, "闪电特效有 points 输入", fx != null and fx.get("points") != null,
			"null" if fx == null else "有 points")
		fx.free()

	# ------------------------------------------------ STEP8 关掉模组
	a.log("STEP8 关掉模组 → 撤干净")
	reed.queue_free()
	cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "闪电芦苇不再是已解锁", not Global.global_game_state.is_plant_unlocked(REED))
	_check(a, "注册表里没有闪电芦苇了",
		registry.get_plant_info(REED, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(REED))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(REED).get("名字", "")) != "闪电芦苇")

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
