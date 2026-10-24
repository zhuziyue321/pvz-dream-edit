extends RefCounted
## 探针：DLC 模组的第八株植物 —— 「橡木弓箭手」（OakArcher，200 阳光本行直线射手）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 200 阳光 / 7.5 秒冷却 / 普通陆生条件，已解锁，且不是紫卡
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「橡木弓箭手」（200 阳光）
##   4. 种进草地：动画节点在、三段 DLC 动画都在、当前播 `OakArcher_idle` 且在跑、没有再叠缩放
##   5. 摆放：整株尺寸在射手量级，底边与本体豌豆射手对齐（同一套画布口径）
##   6. 射手零件：本行检测框覆盖 9 格（684 px）、冷却 4.25 秒、出箭延迟 0.17 秒、一支箭 80
##   7. 箭矢：继承本体 cactus 直线子弹，贴图 / 伤害 / 速度对上
##   8. 有敌人：播 `OakArcher_shooting`；播完回 `OakArcher_idle`
##   9. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 橡木弓箭手的植物 id（模组自己起的字符串 id，本体不认得它）
const OAK_ARCHER := &"dlc_oakarcher"
## 普通陆生植物（拿来对照卡位顺序 / 摆放底边）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里挂进 AnimLib 的三段
const ALL_ANIMS: Array[String] = [
	"OakArcher_idle", "OakArcher_shooting", "OakArcher_blink",
]
const STATE_IDLE := &"OakArcher_idle"
const STATE_SHOOTING := &"OakArcher_shooting"

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 模组自己的箭（本体 cactus 直线子弹 + DLC 贴图）
const ARROW_SCENE_PATH := "res://mods_builtin/dlc/oakarcher/bullet_oakarcher_arrow.tscn"
## 对齐基准：本体豌豆射手（同为直线射手，同一套 reanim → Godot 动画的画布口径）
const NATIVE_PEA_SCENE := "res://src/entities/character/plant/plant_pea_shooter_single.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「橡木弓箭手」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 橡木弓箭手登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(OAK_ARCHER, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "橡木弓箭手登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "橡木弓箭手阳光 = 200（wiki：200）",
		int(registry.get_plant_info(OAK_ARCHER, CharacterRegistry.PlantInfoAttribute.SunCost)) == 200,
		str(registry.get_plant_info(OAK_ARCHER, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "橡木弓箭手冷却 = 7.5 秒（wiki：fast）",
		is_equal_approx(float(registry.get_plant_info(OAK_ARCHER,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 7.5))
	_check(a, "橡木弓箭手已解锁", Global.global_game_state.is_plant_unlocked(OAK_ARCHER))
	var condition = registry.get_plant_info(OAK_ARCHER,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "橡木弓箭手登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "橡木弓箭手是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "橡木弓箭手占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "橡木弓箭手不是紫卡（普通卡，200 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))
	_check(a, "没给橡木弓箭手登记紫卡前置",
		not registry.AllPrePlantPurple.has(OAK_ARCHER),
		str(registry.AllPrePlantPurple.get(OAK_ARCHER, PlantIds.NULL)))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "橡木弓箭手有卡位", AllCards.plant_card_ids.has(OAK_ARCHER))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(OAK_ARCHER, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 橡木弓=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(OAK_ARCHER, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(OAK_ARCHER)
	_check(a, "装上模组后橡木弓箭手有图鉴条目", str(entry.get("名字", "")) == "橡木弓箭手", str(entry))
	_check(a, "图鉴里写的阳光是 200", str(entry.get("参数", {}).get("阳光", "")) == "200",
		str(entry.get("参数", {}).get("阳光", "")))

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 DLC 待机动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var archer = cell.create_plant(OAK_ARCHER, false, false)
	if archer == null:
		_check(a, "橡木弓箭手能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = archer.get_node_or_null("Body/OakArcherAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/OakArcherAnim/AnimLib")
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
	## 原版缩放已经在动画的 `scale` 轨道里（这株部件是 0.93），动画根节点再叠一层就整株缩小
	var anim_root := archer.get_node_or_null("Body/OakArcherAnim") as Node2D
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
		a.log("   [INFO] 橡木弓箭手 Body 内 rect=%s" % str(content))
		_check(a, "整株尺寸在射手的量级（宽 110~180 / 高 90~150 px）",
			content.size.x >= 110.0 and content.size.x <= 180.0
				and content.size.y >= 90.0 and content.size.y <= 150.0,
			str(content.size))
		## ⚠️ 这条量的是**运行期**内容（arrow2 / arm_back / eyebrows 的贴图由动画 texture 轨道塞进来，
		## 场景里没有 texture）—— 只按场景文件量包围盒会漏它们
		_check(a, "底边与豌豆射手对齐（差 ≤ 14 px）",
			absf(content.end.y - native_rect.end.y) <= 14.0,
			"豌豆底 %.1f / 橡木弓底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()

	# ------------------------------------------------ STEP6 射手零件与数值
	a.log("STEP6 射手：本行 9 格检测框 + 冷却 4.25 秒 + 出箭延迟 0.17 秒 + 80 伤害")
	var detect := archer.get_node_or_null("DetectComponent") as DetectComponent
	_check(a, "挂了检测组件", detect != null)
	_check(a, "检测组件按行过滤（射手只打本行）",
		detect != null and detect.is_lane,
		"null" if detect == null else "is_lane=%s" % str(detect.is_lane))
	var detect_shape := archer.get_node_or_null("DetectComponent/Area2D/CollisionShape2D") as CollisionShape2D
	var detect_rect: RectangleShape2D = null
	if detect_shape != null:
		detect_rect = detect_shape.shape as RectangleShape2D
	## wiki 的射程是「1x9」：9 格 = 76 × 9 = 684 px
	_check(a, "检测框正好铺 9 格（684 px）",
		detect_rect != null and is_equal_approx(detect_rect.size.x, 684.0),
		"null" if detect_rect == null else str(detect_rect.size))
	_check(a, "冷却计时器在", archer.get_node_or_null("AttackCdTimer") != null)
	_check(a, "出箭延迟计时器在", archer.get_node_or_null("ShootTimer") != null)
	_check(a, "攻击间隔 = 4.25 秒（wiki，长于开火动画 0.92 秒）",
		is_equal_approx(float(archer.get("attack_cd")), 4.25),
		str(archer.get("attack_cd")))
	_check(a, "出箭延迟 = 0.17 秒（持弓手 rotation 拉满那一帧）",
		is_equal_approx(float(archer.get("shoot_delay")), 0.17),
		str(archer.get("shoot_delay")))
	_check(a, "一支箭 = 80 伤害", int(archer.get("bullet_damage")) == 80,
		str(archer.get("bullet_damage")))
	var marker := archer.get_node_or_null("Body/Marker2D") as Node2D
	_check(a, "箭矢出生点在右侧偏上（Marker2D 在 Body 下、x>0、y<0）",
		marker != null and marker.position.x > 0.0 and marker.position.y < 0.0,
		"null" if marker == null else str(marker.position))

	# ------------------------------------------------ STEP7 箭矢场景
	a.log("STEP7 箭矢：继承本体 cactus 直线子弹，贴图 / 伤害 / 速度对上")
	var arrow_scene: PackedScene = load(ARROW_SCENE_PATH)
	if arrow_scene == null:
		_check(a, "箭矢场景能加载", false, ARROW_SCENE_PATH)
	else:
		## 不入树：只核字段（直线子弹不像抛物线那样依赖主场景）
		var arrow: Bullet000Base = arrow_scene.instantiate() as Bullet000Base
		_check(a, "箭矢是直线子弹（BulletLinear000Base）",
			arrow is BulletLinear000Base, "" if arrow == null else arrow.get_script().resource_path)
		if arrow != null:
			_check(a, "箭矢伤害 = 80", int(arrow.get("attack_value")) == 80,
				str(arrow.get("attack_value")))
			_check(a, "箭矢速度 = 260", is_equal_approx(float(arrow.get("speed")), 260.0),
				str(arrow.get("speed")))
			var arrow_body := arrow.get_node_or_null("Body/BulletBody") as Sprite2D
			_check(a, "箭矢有贴图（DLC 的 oak_archer_arrow）",
				arrow_body != null and arrow_body.texture != null)
			_check(a, "箭矢缩到细长箭型（0.6）",
				arrow_body != null and arrow_body.scale.is_equal_approx(Vector2(0.6, 0.6)),
				"null" if arrow_body == null else str(arrow_body.scale))
			arrow.free()

	# ------------------------------------------------ STEP8 有敌人 → 播 shooting → 回待机
	a.log("STEP8 有敌人：播 shooting，播完回待机")
	detect.signal_can_attack.emit()
	await a.frames(2)
	_check(a, "检测到敌人后播的是 shooting", player.current_animation == STATE_SHOOTING,
		String(player.current_animation))
	## 掐掉冷却计时器：本步只看出箭段的收尾，不让下一发插进来
	var cd_timer: Timer = archer.get_node("AttackCdTimer")
	cd_timer.stop()
	await a.wait(1.2)
	_check(a, "shooting 播完回到待机",
		player.is_playing() and player.current_animation == STATE_IDLE,
		"is_playing=%s curr=%s" % [str(player.is_playing()), String(player.current_animation)])
	detect.signal_not_can_attack.emit()

	# ------------------------------------------------ STEP9 关掉模组
	a.log("STEP9 关掉模组 → 撤干净")
	archer.queue_free()
	cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "橡木弓箭手不再是已解锁", not Global.global_game_state.is_plant_unlocked(OAK_ARCHER))
	_check(a, "注册表里没有橡木弓箭手了",
		registry.get_plant_info(OAK_ARCHER, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(OAK_ARCHER))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(OAK_ARCHER).get("名字", "")) != "橡木弓箭手")

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
