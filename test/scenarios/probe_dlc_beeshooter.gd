extends RefCounted
## 探针：DLC 模组的第九株植物 —— 「蜜蜂射手」（BeeShooter，100 阳光直线射手）
##
## 无头可跑，只动内存（开关写进 autopilot 那份临时 user 目录）。校验：
##   1. 装上模组 → 注册表里有场景 / 100 阳光 / 7.5 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「蜜蜂射手」（100 阳光 / 直线射手）
##   4. 种进草地：两层动画播放器都在（待机层 `full_idle`、开火层 `shooting_overlay`）、
##      当前播 `BeeShooter_full_idle` 且在跑、动画根节点没有再叠缩放
##   5. 摆放：整株尺寸在本体豌豆射手的量级，底边与豌豆射手对齐（同一套画布口径）
##   6. 射手零件：本行检测框铺满整行（800 px）、冷却 2.1 秒、出弹延迟 0.5 秒、一只蜜蜂 20
##   7. 蜜蜂：继承本体直线弹基类，移动组件是直线，贴图 / 伤害 / 速度 / 缩放对上
##   8. 有敌人：开火层播 `BeeShooter_shooting_overlay`，待机层不回退；2 秒后开火层停住
##   9. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 蜜蜂射手的植物 id（模组自己起的字符串 id，本体不认得它）
const BEE_SHOOTER := &"dlc_beeshooter"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE

## 待机层动画（完整姿态：身体 + 头 + 嘴）
const STATE_IDLE := &"BeeShooter_full_idle"
## 开火层动画（头部 / 嘴覆盖）
const STATE_SHOOTING := &"BeeShooter_shooting_overlay"

const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"
## 模组自己的蜜蜂（本体直线弹基类 + DLC 贴图）
const BEE_SCENE_PATH := "res://mods_builtin/dlc/beeshooter/bullet_beeshooter_bee.tscn"
## 对齐基准：本体豌豆射手（这株的茎 / 叶就是豌豆的部件，同一套 reanim → Godot 动画的画布口径）
const NATIVE_PEA_SCENE := "res://src/entities/character/plant/plant_pea_shooter_single.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「蜜蜂射手」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 蜜蜂射手登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(BEE_SHOOTER, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "蜜蜂射手登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "蜜蜂射手阳光 = 100（wiki：Plants 总表）",
		int(registry.get_plant_info(BEE_SHOOTER, CharacterRegistry.PlantInfoAttribute.SunCost)) == 100,
		str(registry.get_plant_info(BEE_SHOOTER, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "蜜蜂射手冷却 = 7.5 秒（取豌豆口径的 fast）",
		is_equal_approx(float(registry.get_plant_info(BEE_SHOOTER,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 7.5))
	_check(a, "蜜蜂射手已解锁", Global.global_game_state.is_plant_unlocked(BEE_SHOOTER))
	var condition = registry.get_plant_info(BEE_SHOOTER,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "蜜蜂射手登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "蜜蜂射手是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "蜜蜂射手占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "蜜蜂射手不是紫卡（普通卡，100 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))
	_check(a, "没给蜜蜂射手登记紫卡前置",
		not registry.AllPrePlantPurple.has(BEE_SHOOTER),
		str(registry.AllPrePlantPurple.get(BEE_SHOOTER, PlantIds.NULL)))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "蜜蜂射手有卡位", AllCards.plant_card_ids.has(BEE_SHOOTER))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(BEE_SHOOTER, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 蜜蜂=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(BEE_SHOOTER, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(BEE_SHOOTER)
	_check(a, "装上模组后蜜蜂射手有图鉴条目", str(entry.get("名字", "")) == "蜜蜂射手", str(entry))
	_check(a, "图鉴里写的阳光是 100", str(entry.get("参数", {}).get("阳光", "")) == "100",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「直线射手」",
		str(entry.get("参数", {}).get("特点", "")).contains("直线射手"),
		str(entry.get("参数", {}).get("特点", "")))

	# ------------------------------------------------ STEP4 种下去 + 动画
	a.log("STEP4 种进草地 → 播 DLC 待机动画")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	await a.frames(1)
	var bee = cell.create_plant(BEE_SHOOTER, false, false)
	if bee == null:
		_check(a, "蜜蜂射手能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = bee.get_node_or_null("Body/BeeShooterAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 待机播放器", false, "取不到 Body/BeeShooterAnim/AnimLib")
		cell.free()
		_finish(a)
		return
	var shoot_layer: AnimationPlayer = bee.get_node_or_null("Body/BeeShooterAnim/ShootLayer")
	_check(a, "待机层有完整姿态动画", player.has_animation(STATE_IDLE), str(player.get_animation_list()))
	_check(a, "开火覆盖层在且装了开火动画",
		shoot_layer != null and shoot_layer.has_animation(STATE_SHOOTING),
		"null" if shoot_layer == null else str(shoot_layer.get_animation_list()))
	_check(a, "当前在播待机", player.current_animation == STATE_IDLE,
		String(player.current_animation))
	_check(a, "待机播放器真的在跑（不是停在第 0 帧）", player.is_playing())
	## 原版缩放已经在动画的 `scale` 轨道里，动画根节点再叠一层就整株缩小
	var anim_root := bee.get_node_or_null("Body/BeeShooterAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))

	# ------------------------------------------------ STEP5 摆放（与豌豆射手对齐）
	a.log("STEP5 摆放：整株尺寸与底边对齐本体豌豆射手")
	if anim_root != null:
		## `full_idle` 是单次动画，前 0.25 秒整组 `visible=false`、头部贴图由 texture 轨道
		## 播到中途才塞进来 —— 直接量第 0 帧只会量到半截。先 seek 到中段再量
		player.seek(1.5, true)
		player.advance(0.0)
		await a.frames(2)
		var native_scene: Node = load(NATIVE_PEA_SCENE).instantiate()
		var native_body: Node2D = native_scene.get_node("Body")
		## `get_content_rect(root)` 已经把 root 自己的 transform 算进去了 → 返回值就是 Body 坐标
		var native_rect := AnimationFrameUtil.get_content_rect(native_body)
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 本体豌豆射手 Body 内容 rect=%s" % str(native_rect))
		a.log("   [INFO] 蜜蜂射手 Body 内 rect=%s" % str(content))
		_check(a, "整株尺寸在豌豆射手的量级（宽 50~95 / 高 60~105 px）",
			content.size.x >= 50.0 and content.size.x <= 95.0
				and content.size.y >= 60.0 and content.size.y <= 105.0,
			str(content.size))
		## 对齐口径：底边差 ≤ 4 px（与本体豌豆射手同底）
		_check(a, "底边与豌豆射手对齐（差 ≤ 4 px）",
			absf(content.end.y - native_rect.end.y) <= 4.0,
			"豌豆底 %.1f / 蜜蜂底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()

	# ------------------------------------------------ STEP6 射手零件与数值
	a.log("STEP6 射手：双向检测框（左右各 400 px）+ 冷却 1.5 秒 + 出弹延迟 0.5 秒 + 20 伤害")
	var detect := bee.get_node_or_null("DetectComponent") as DetectComponent
	_check(a, "挂了检测组件", detect != null)
	_check(a, "检测组件按行过滤（直线射手只打本行）",
		detect != null and detect.is_lane,
		"null" if detect == null else "is_lane=%s" % str(detect.is_lane))
	var detect_shape := bee.get_node_or_null("DetectComponent/Area2D/CollisionShape2D") as CollisionShape2D
	var detect_rect: RectangleShape2D = null
	if detect_shape != null:
		detect_rect = detect_shape.shape as RectangleShape2D
	## wiki `range = Forward and backward`：框以植物为中心左右各铺 400 px（总宽 800），
	## 出弹方向由脚本按「离自己最近的那只在哪一侧」决定
	_check(a, "检测框双向铺开（左右各 400 px，总宽 800）",
		detect_rect != null and is_equal_approx(detect_rect.size.x, 800.0),
		"null" if detect_rect == null else str(detect_rect.size))
	_check(a, "检测框以自己为中心（形状居中，左右都覆盖）",
		detect_shape != null and is_equal_approx(detect_shape.position.x, 0.0),
		"null" if detect_shape == null else str(detect_shape.position))
	_check(a, "冷却计时器在", bee.get_node_or_null("AttackCdTimer") != null)
	_check(a, "出弹延迟计时器在", bee.get_node_or_null("ShootTimer") != null)
	## wiki `firerate = 1.5`：开火动画 2.0 秒比它还长，靠 `SHOOT_ANIM_SPEED` 那层加速
	## 把开火压进一个攻击间隔里（见 `beeshooter_plant.gd` 的常量注释）
	_check(a, "攻击间隔 = 1.5 秒（wiki 的 firerate）",
		is_equal_approx(float(bee.get("attack_cd")), 1.5),
		str(bee.get("attack_cd")))
	_check(a, "出弹延迟 = 0.5 秒（嘴收到最高的第 6 帧）",
		is_equal_approx(float(bee.get("shoot_delay")), 0.5),
		str(bee.get("shoot_delay")))
	_check(a, "一只蜜蜂 = 20 伤害", int(bee.get("bullet_damage")) == 20,
		str(bee.get("bullet_damage")))

	# ------------------------------------------------ STEP7 蜜蜂场景
	a.log("STEP7 蜜蜂：继承本体直线弹基类，移动组件是直线，数值 / 贴图对上")
	var bee_scene: PackedScene = load(BEE_SCENE_PATH)
	if bee_scene == null:
		_check(a, "蜜蜂场景能加载", false, BEE_SCENE_PATH)
	else:
		var bullet: Bullet000Base = bee_scene.instantiate() as Bullet000Base
		_check(a, "蜜蜂是直线子弹（BulletLinear000Base）",
			bullet is BulletLinear000Base, "" if bullet == null else bullet.get_script().resource_path)
		if bullet != null:
			_check(a, "蜜蜂伤害 = 20", int(bullet.get("attack_value")) == 20,
				str(bullet.get("attack_value")))
			_check(a, "蜜蜂速度 = 300（与本体豌豆一致）", is_equal_approx(float(bullet.get("speed")), 300.0),
				str(bullet.get("speed")))
			var movement := bullet.get_node_or_null("MovementComponent")
			_check(a, "移动组件是直线（BulletMovementLinear）",
				movement is BulletMovementLinear,
				"null" if movement == null else movement.get_script().resource_path)
			var bee_body := bullet.get_node_or_null("Body/BulletBody") as Sprite2D
			_check(a, "蜜蜂有贴图（DLC 的 beeshooter_bee）",
				bee_body != null and bee_body.texture != null)
			_check(a, "蜜蜂缩到豌豆量级（0.4，≈24 px）",
				bee_body != null and bee_body.scale.is_equal_approx(Vector2(0.4, 0.4)),
				"null" if bee_body == null else str(bee_body.scale))
			bullet.free()

	# ------------------------------------------------ STEP8 有敌人 → 开火层播覆盖动画
	a.log("STEP8 有敌人：开火层播覆盖动画，待机层不回退")
	detect.signal_can_attack.emit()
	await a.frames(2)
	_check(a, "检测到敌人后开火层播 shooting 覆盖动画",
		shoot_layer != null and shoot_layer.current_animation == STATE_SHOOTING,
		"null" if shoot_layer == null else String(shoot_layer.current_animation))
	_check(a, "待机层继续在播 full_idle（不切走）",
		player.current_animation == STATE_IDLE and player.is_playing(),
		String(player.current_animation))
	## 掐掉冷却计时器：本步只看出弹段的收尾，不让下一发插进来
	var cd_timer: Timer = bee.get_node("AttackCdTimer")
	cd_timer.stop()
	## 开火动画 2.0 秒，等它自然播完
	await a.wait(2.4)
	_check(a, "开火层播完停住（不再占着头部）",
		shoot_layer != null and not shoot_layer.is_playing())
	detect.signal_not_can_attack.emit()

	# ------------------------------------------------ STEP9 关掉模组
	a.log("STEP9 关掉模组 → 撤干净")
	bee.queue_free()
	cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "蜜蜂射手不再是已解锁", not Global.global_game_state.is_plant_unlocked(BEE_SHOOTER))
	_check(a, "注册表里没有蜜蜂射手了",
		registry.get_plant_info(BEE_SHOOTER, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(BEE_SHOOTER))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(BEE_SHOOTER).get("名字", "")) != "蜜蜂射手")

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
