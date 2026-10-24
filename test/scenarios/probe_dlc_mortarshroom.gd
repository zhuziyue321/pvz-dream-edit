extends RefCounted
## 探针：DLC 模组的第三株抛射植物 —— 「臼炮蘑菇」（MortarShroom，75 阳光抛射溅射投手）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 75 阳光 / 7.5 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「臼炮蘑菇」（75 阳光 / 白天睡觉）
##   4. 种进草地：动画节点在、三段 DLC 动画都在、当前播 `MortarShroom_idle` 且在跑、没有再叠缩放
##   5. 摆放：整株尺寸在本体小喷菇的量级，底边与小喷菇对齐（同一套画布口径）
##   6. 投手零件：本行检测框覆盖约 6 格（480 px，左边缘压到自己脚下 —— **没有近身盲点**）、
##      冷却 6 秒、出弹延迟 0.45 秒、直接命中 40、白天睡觉标记
##   7. 炮弹：继承本体抛物线基类，贴图 / 伤害 / 速度 / 抛物线高度 / 溅射组件对上
##   8. 有敌人：播 `MortarShroom_shooting`；播完回 `MortarShroom_idle`
##   9. 睡眠信号：进睡眠换 `MortarShroom_sleep`，醒来回待机
##  10. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 臼炮蘑菇的植物 id（模组自己起的字符串 id，本体不认得它）
const MORTAR_SHROOM := &"dlc_mortarshroom"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的三段
const ALL_ANIMS: Array[String] = [
	"MortarShroom_idle", "MortarShroom_shooting", "MortarShroom_sleep",
]
const STATE_IDLE := &"MortarShroom_idle"
const STATE_SHOOTING := &"MortarShroom_shooting"
const STATE_SLEEP := &"MortarShroom_sleep"

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 模组自己的炮弹（本体抛物线基类 + DLC 贴图 + 溅射组件）
const SHELL_SCENE_PATH := "res://mods_builtin/dlc/mortarshroom/bullet_mortarshroom_shell.tscn"
## 对齐基准：本体小喷菇（同为蘑菇，同一套 reanim → Godot 动画的画布口径）
const NATIVE_PUFF_SCENE := "res://src/entities/character/plant/plant_puff.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「臼炮蘑菇」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 臼炮蘑菇登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(MORTAR_SHROOM, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "臼炮蘑菇登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	var sun_cost = registry.get_plant_info(MORTAR_SHROOM, CharacterRegistry.PlantInfoAttribute.SunCost)
	_check(a, "臼炮蘑菇阳光 = 75（wiki：75）",
		sun_cost != null and int(sun_cost) == 75,
		str(sun_cost))
	var cool_time = registry.get_plant_info(MORTAR_SHROOM, CharacterRegistry.PlantInfoAttribute.CoolTime)
	_check(a, "臼炮蘑菇冷却 = 7.5 秒（wiki：fast）",
		cool_time != null and is_equal_approx(float(cool_time), 7.5),
		str(cool_time))
	_check(a, "臼炮蘑菇已解锁", Global.global_game_state.is_plant_unlocked(MORTAR_SHROOM))
	var condition = registry.get_plant_info(MORTAR_SHROOM,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "臼炮蘑菇登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "臼炮蘑菇是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "臼炮蘑菇占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "臼炮蘑菇不是紫卡（普通卡，75 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))
	_check(a, "没给臼炮蘑菇登记紫卡前置",
		not registry.AllPrePlantPurple.has(MORTAR_SHROOM),
		str(registry.AllPrePlantPurple.get(MORTAR_SHROOM, PlantIds.NULL)))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "臼炮蘑菇有卡位", AllCards.plant_card_ids.has(MORTAR_SHROOM))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(MORTAR_SHROOM, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 臼炮菇=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(MORTAR_SHROOM, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(MORTAR_SHROOM)
	_check(a, "装上模组后臼炮蘑菇有图鉴条目", str(entry.get("名字", "")) == "臼炮蘑菇", str(entry))
	_check(a, "图鉴里写的阳光是 75", str(entry.get("参数", {}).get("阳光", "")) == "75",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「白天睡觉」",
		str(entry.get("参数", {}).get("特点", "")).contains("白天睡觉"),
		str(entry.get("参数", {}).get("特点", "")))

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 DLC 待机动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var shroom = cell.create_plant(MORTAR_SHROOM, false, false)
	if shroom == null:
		_check(a, "臼炮蘑菇能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = shroom.get_node_or_null("Body/MortarShroomAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/MortarShroomAnim/AnimLib")
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
	## 原版缩放已经在动画的 `scale` 轨道里，动画根节点再叠一层就整株缩小
	var anim_root := shroom.get_node_or_null("Body/MortarShroomAnim") as Node2D
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
		a.log("   [INFO] 臼炮蘑菇 Body 内 rect=%s" % str(content))
		_check(a, "整株尺寸在蘑菇的量级（宽 35~90 / 高 25~90 px）",
			content.size.x >= 35.0 and content.size.x <= 90.0
				and content.size.y >= 25.0 and content.size.y <= 90.0,
			str(content.size))
		## 这条量的是**运行期**内容，摆放要与小喷菇底边落在同一高度
		_check(a, "底边与小喷菇对齐（差 ≤ 4 px）",
			absf(content.end.y - native_rect.end.y) <= 4.0,
			"小喷菇底 %.1f / 臼炮菇底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()

	# ------------------------------------------------ STEP6 投手零件与数值
	a.log("STEP6 投手：本行 6 格检测框（**无近身盲点**）+ 冷却 6 秒 + 出弹延迟 0.45 秒 + 40 伤害 + 白天睡觉")
	var detect := shroom.get_node_or_null("DetectComponent") as DetectComponent
	_check(a, "挂了检测组件", detect != null)
	_check(a, "检测组件按行过滤（投手只打本行）",
		detect != null and detect.is_lane,
		"null" if detect == null else "is_lane=%s" % str(detect.is_lane))
	var detect_shape := shroom.get_node_or_null("DetectComponent/Area2D/CollisionShape2D") as CollisionShape2D
	var detect_rect: RectangleShape2D = null
	if detect_shape != null:
		detect_rect = detect_shape.shape as RectangleShape2D
	## wiki 的射程是「Lobbed」：约 6 格 = 76 × 6 = 456 px（外加脚下 20 px 兜底 = 480）
	_check(a, "检测框铺约 6 格（480 px）",
		detect_rect != null and is_equal_approx(detect_rect.size.x, 480.0),
		"null" if detect_rect == null else str(detect_rect.size))
	## **没有**近身盲点：左边缘压在自己脚下再往左 20 px（中心 220 → 覆盖 -20 .. 460）
	_check(a, "近身不是盲点：检测框中心在 220 px",
		detect_shape != null and is_equal_approx(detect_shape.position.x, 220.0),
		"null" if detect_shape == null else str(detect_shape.position))
	## 这条才是真正防回归的：左边缘必须 ≤ 0，否则贴脸的僵尸又进不了框
	_check(a, "近身真能打到：框的左边缘 ≤ 自己脚下（不是 +114 那种盲点）",
		detect_shape != null and detect_rect != null
			and (detect_shape.position.x - detect_rect.size.x * 0.5) <= 0.0,
		"左边缘=%s" % ("null" if detect_shape == null or detect_rect == null
			else str(detect_shape.position.x - detect_rect.size.x * 0.5)))
	_check(a, "冷却计时器在", shroom.get_node_or_null("AttackCdTimer") != null)
	_check(a, "出弹延迟计时器在", shroom.get_node_or_null("ShootTimer") != null)
	_check(a, "攻击间隔 = 6 秒（wiki 的 1/4x，长于开火动画 1.42 秒）",
		is_equal_approx(float(shroom.get("attack_cd")), 6.0),
		str(shroom.get("attack_cd")))
	_check(a, "出弹延迟 = 0.45 秒（≈0.32 × 开火动画时长）",
		is_equal_approx(float(shroom.get("shoot_delay")), 0.45),
		str(shroom.get("shoot_delay")))
	_check(a, "直接命中 = 40 伤害", int(shroom.get("bullet_damage")) == 40,
		str(shroom.get("bullet_damage")))
	_check(a, "标了白天睡觉（蘑菇）",
		bool(shroom.get_node("SleepComponent").get("is_sleep_in_day")))
	_check(a, "睡觉时停索敌（检测组件在 sleep_influence_components 里）",
		shroom.get_node("SleepComponent").get("sleep_influence_components").has(detect))
	_check(a, "炮弹出生点在臼炮口上方（Marker2D 在 Body 下、y < 0）",
		shroom.get_node_or_null("Body/Marker2D") != null
			and (shroom.get_node("Body/Marker2D") as Node2D).position.y < 0.0,
		"" if shroom.get_node_or_null("Body/Marker2D") == null
			else str((shroom.get_node("Body/Marker2D") as Node2D).position))

	# ------------------------------------------------ STEP7 炮弹场景
	a.log("STEP7 炮弹：继承本体抛物线基类，贴图 / 伤害 / 速度 / 抛物线高度 / 溅射组件对上")
	var shell_scene: PackedScene = load(SHELL_SCENE_PATH)
	if shell_scene == null:
		_check(a, "炮弹场景能加载", false, SHELL_SCENE_PATH)
	else:
		## 不入树：抛物线 `_ready()` 要读主场景（斜坡 / 行基准 y），空场景里没有主游戏
		var shell: Bullet000Base = shell_scene.instantiate() as Bullet000Base
		_check(a, "炮弹是抛物线子弹（Bullet000ParabolaBase）",
			shell is Bullet000ParabolaBase, "" if shell == null else shell.get_script().resource_path)
		if shell != null:
			_check(a, "炮弹直接命中伤害 = 40", int(shell.get("attack_value")) == 40,
				str(shell.get("attack_value")))
			_check(a, "炮弹速度 = 500", is_equal_approx(float(shell.get("speed")), 500.0),
				str(shell.get("speed")))
			var movement := shell.get_node_or_null("MovementComponent") as BulletMovementParabola
			_check(a, "移动组件是抛物线", movement != null)
			_check(a, "抛物线高度 = -350（臼炮抛得比孢子高、比西瓜低）",
				movement != null and is_equal_approx(movement.parabola_height, -350.0),
				"null" if movement == null else str(movement.parabola_height))
			var shell_body := shell.get_node_or_null("Body/BulletBody") as Sprite2D
			_check(a, "炮弹用自己的贴图（mortarshroom_shell.png，不再借投掷蘑菇的孢子）",
				shell_body != null and shell_body.texture != null
				and str(shell_body.texture.resource_path).ends_with("mortarshroom_shell.png"),
				"null" if shell_body == null or shell_body.texture == null
				else str(shell_body.texture.resource_path))
			_check(a, "炮弹缩到 0.9（32 px 的壳 ≈ 29 px，比孢子重一档）",
				shell_body != null and shell_body.scale.is_equal_approx(Vector2(0.9, 0.9)),
				"null" if shell_body == null else str(shell_body.scale))
			var spatter := shell.get_node_or_null("SpatterComponent") as Node2D
			_check(a, "挂了溅射组件（落地 AoE，迷你西瓜投手式）", spatter != null)
			_check(a, "溅射总量 = 60",
				spatter != null and int(spatter.get("sum_attack_value")) == 60,
				"null" if spatter == null else str(spatter.get("sum_attack_value")))
			shell.free()

	# ------------------------------------------------ STEP8 有敌人 → 播 shooting → 回待机
	a.log("STEP8 有敌人：播 shooting，播完回待机")
	detect.signal_can_attack.emit()
	await a.frames(2)
	_check(a, "检测到敌人后播的是 shooting", player.current_animation == STATE_SHOOTING,
		String(player.current_animation))
	## 掐掉冷却计时器：本步只看出弹段的收尾，不让下一发插进来
	var cd_timer: Timer = shroom.get_node("AttackCdTimer")
	cd_timer.stop()
	await a.wait(1.9)
	_check(a, "shooting 播完回到待机",
		player.is_playing() and player.current_animation == STATE_IDLE,
		"is_playing=%s curr=%s" % [str(player.is_playing()), String(player.current_animation)])
	detect.signal_not_can_attack.emit()

	# ------------------------------------------------ STEP9 睡眠信号换姿势
	a.log("STEP9 睡眠：进睡眠换 sleep 姿势，醒来回待机")
	var sleep: SleepComponent = shroom.get_node("SleepComponent")
	sleep.start_sleep()
	await a.frames(2)
	_check(a, "睡着时播 MortarShroom_sleep", player.current_animation == STATE_SLEEP,
		String(player.current_animation))
	sleep.end_sleep()
	await a.frames(2)
	_check(a, "醒来回待机", player.current_animation == STATE_IDLE,
		String(player.current_animation))

	# ------------------------------------------------ STEP10 关掉模组
	a.log("STEP10 关掉模组 → 撤干净")
	shroom.queue_free()
	cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "臼炮蘑菇不再是已解锁", not Global.global_game_state.is_plant_unlocked(MORTAR_SHROOM))
	_check(a, "注册表里没有臼炮蘑菇了",
		registry.get_plant_info(MORTAR_SHROOM, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(MORTAR_SHROOM))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(MORTAR_SHROOM).get("名字", "")) != "臼炮蘑菇")

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
