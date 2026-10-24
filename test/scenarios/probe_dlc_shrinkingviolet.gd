extends RefCounted
## 探针：DLC 模组的植物 —— 「缩小紫罗兰」（ShrinkingViolet，0 阳光一次性控制植物）
##
## 无头可跑，端到端（真开一局 1-1、摆僵尸、种紫罗兰、看僵尸被缩小再恢复）。校验：
##   1. 装上模组 → 注册表里有场景 / 0 阳光 / 7.5 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后、待选区里有卡位
##   3. 图鉴：模组自己登记的那条「缩小紫罗兰」（0 阳光 / 一次性）
##   4. 种进草地：动画节点在、两段 DLC 动画都在、没有再叠缩放
##   5. 摆放：整株尺寸在小体型花草的量级，底边落在原点附近（同一套画布口径，INFO 打印实测 rect）
##   6. 种下即绽放：当前播 `ShrinkingViolet_bloom`（不是待机）
##   7. 缩小周围 3×3 的僵尸：场上僵尸 `body.scale` 缩到约 0.5、啃食攻击值约减半
##   8. 绽放完自身被消耗掉（一次即走），而僵尸**仍保持缩小**（效果挂在僵尸身上）
##   9. 缩小到点：僵尸缩放与啃食攻击值自行恢复
##  10. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLCSHRINK] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 缩小紫罗兰的植物 id（模组自己起的字符串 id，本体不认得它）
const SHRINKING_VIOLET := &"dlc_shrinkingviolet"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## 关卡：1-1（草地，最朴素的一张图）
const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_01_01.gd"
const ProbeUtil := preload("res://test/scenarios/probe_util.gd")
## 种植格场景（照投掷蘑菇探针：new 一个格子挂到树根，直接 create_plant）
const PLANT_CELL_SCENE := "res://src/ui/plant_cell.tscn"

## DLC 动画场景里的两段
const ALL_ANIMS: Array[String] = ["ShrinkingViolet_idle", "ShrinkingViolet_bloom"]
const STATE_IDLE := &"ShrinkingViolet_idle"
const STATE_BLOOM := &"ShrinkingViolet_bloom"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「缩小紫罗兰」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组
	a.log("STEP1 装上模组 → 缩小紫罗兰登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(SHRINKING_VIOLET, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "缩小紫罗兰登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	## 注意：注册缺失时 get_plant_info 返回 null，`int(null)` / `float(null)` 会直接抛运行时错误
	## （会导致整条探针中断、被看门狗拖到超时）——所以先判空再取数。
	var sun_cost = registry.get_plant_info(SHRINKING_VIOLET, CharacterRegistry.PlantInfoAttribute.SunCost)
	var cool_time = registry.get_plant_info(SHRINKING_VIOLET, CharacterRegistry.PlantInfoAttribute.CoolTime)
	_check(a, "缩小紫罗兰阳光 = 100（wiki：不是免费卡）",
		sun_cost != null and int(sun_cost) == 100,
		"null" if sun_cost == null else str(sun_cost))
	_check(a, "缩小紫罗兰冷却 = 30 秒（wiki：slow）",
		cool_time != null and is_equal_approx(float(cool_time), 30.0),
		"null" if cool_time == null else str(cool_time))
	_check(a, "缩小紫罗兰已解锁", Global.global_game_state.is_plant_unlocked(SHRINKING_VIOLET))
	var condition = registry.get_plant_info(SHRINKING_VIOLET,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "缩小紫罗兰登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "缩小紫罗兰是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "缩小紫罗兰占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "缩小紫罗兰不是紫卡（普通卡，100 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))
	_check(a, "没给缩小紫罗兰登记紫卡前置",
		not registry.AllPrePlantPurple.has(SHRINKING_VIOLET))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "缩小紫罗兰有卡位", AllCards.plant_card_ids.has(SHRINKING_VIOLET))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(SHRINKING_VIOLET, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 紫罗兰=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(SHRINKING_VIOLET, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(SHRINKING_VIOLET)
	_check(a, "装上模组后缩小紫罗兰有图鉴条目", str(entry.get("名字", "")) == "缩小紫罗兰", str(entry))
	_check(a, "图鉴里写的阳光是 0", str(entry.get("参数", {}).get("阳光", "")) == "0",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「一次性」",
		str(entry.get("参数", {}).get("特点", "")).contains("一次性"),
		str(entry.get("参数", {}).get("特点", "")))

	# ------------------------------------------------ STEP4 开一局 1-1，摆一只僵尸
	a.log("STEP4 开一局 1-1 → 摆一只普通僵尸上场")
	var para: Resource = (load(LEVEL_PATH) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败: " + LEVEL_PATH)
		_finish(a)
		return
	Global.game_para = para
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.MainGameFront)
	)
	await a.wait(3.0)
	if GameContext.curr_main_game == null:
		a.log("!! 主游戏未创建")
		_finish(a)
		return
	await ProbeUtil.click_start(a)
	var zm = GameContext.curr_main_game.zombie_manager
	if zm == null:
		a.log("!! 僵尸管理器不可用")
		_finish(a)
		return
	zm.zombie_wave_manager.zombie_wave_create_manager.wave_create_zombie(ZombieIds.NORM, 0, 1)
	await a.wait(1.0)
	var zombie: Zombie000Base = null
	for z in zm.all_zombies_1d:
		if is_instance_valid(z):
			zombie = z
			break
	if zombie == null:
		_check(a, "摆得出僵尸用于缩小验证", false, "all_zombies_1d 为空")
		_finish(a)
		return
	_check(a, "场上有僵尸可缩", true, "行%d" % zombie.lane)

	## 基线要在**种下紫罗兰之前**采集：这株是一次性、种下即生效，`ready_norm()` 会把缩小
	## 同步施加上去；种下之后再读，读到的就已经是「缩小后」的值了。
	var z_body := zombie.get_node_or_null("Body") as Node2D
	var z_attack := zombie.get_node_or_null("AttackComponent") as AttackComponentZombieNorm
	var scale_before: Vector2 = z_body.scale if z_body != null else Vector2.ONE
	var atk_before: int = z_attack.curr_attack_value_per_sec if z_attack != null else -1
	a.log("   [INFO] 种下前僵尸：body.scale=%s，啃食攻击值=%d" % [str(scale_before), atk_before])

	# ------------------------------------------------ STEP5 种下紫罗兰 → 绽放 + 缩小
	a.log("STEP5 种下缩小紫罗兰 → 绽放并缩小周围 3×3 的僵尸")
	var cell: PlantCell = load(PLANT_CELL_SCENE).instantiate()
	a.get_tree().root.add_child(cell)
	## 射程已从「全场」改成 wiki 的 3×3：把格子摆到僵尸身边，才落得进射程
	cell.global_position = zombie.global_position + Vector2(40.0, 0.0)
	await a.frames(1)
	var violet = cell.create_plant(SHRINKING_VIOLET, false, false)
	if violet == null:
		_check(a, "缩小紫罗兰能种进草地", false, "create_plant 返回 null")
		cell.free()
		_finish(a)
		return
	await a.frames(2)

	## 4. 动画节点 / 两段动画 / 没叠缩放
	var player: AnimationPlayer = violet.get_node_or_null("Body/ShrinkingVioletAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/ShrinkingVioletAnim/AnimLib")
		_finish(a)
		return
	var missing: Array[String] = []
	for anim_name in ALL_ANIMS:
		if not player.has_animation(anim_name):
			missing.append(anim_name)
	_check(a, "两段 DLC 动画都在播放器里", missing.is_empty(), str(missing))
	var anim_root := violet.get_node_or_null("Body/ShrinkingVioletAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))

	## 5. 摆放：实测内容 rect（INFO），尺寸在小体型花草量级、底边落在原点附近（贴地）
	var content := AnimationFrameUtil.get_content_rect(anim_root)
	a.log("   [INFO] 缩小紫罗兰 Body 内 rect=%s（size=%s）" % [str(content), str(content.size)])
	_check(a, "整株尺寸在小体型花草量级（宽 35~95 / 高 40~110 px）",
		content.size.x >= 35.0 and content.size.x <= 95.0
			and content.size.y >= 40.0 and content.size.y <= 110.0,
		str(content.size))
	_check(a, "底边落在原点附近（贴地，-10~+40 px）",
		content.end.y >= -10.0 and content.end.y <= 40.0,
		"底边 y=%.1f" % content.end.y)

	## 6. 种下即绽放（不是待机）
	_check(a, "种下后立刻播 bloom（不是待机）", player.current_animation == STATE_BLOOM,
		String(player.current_animation))

	## 7. 缩小全场僵尸：scale 缩到约 0.5、啃食攻击值约减半
	## 缩小补间 0.25s，等它走完
	await a.wait(0.6)
	_check(a, "僵尸被缩小（body.scale ≈ 原来的 0.5）",
		z_body != null and absf(z_body.scale.x - scale_before.x * 0.5) <= 0.06,
		"前 %s → 后 %s" % [str(scale_before), "null" if z_body == null else str(z_body.scale)])
	## 直接看攻击组件里的 Shrink 因子（比只看换算出的数值稳：速度因子变动也会改数值）
	var shrink_factor_after: float = -1.0
	if z_attack != null:
		shrink_factor_after = float(z_attack.attack_value_factor.get(
			AttackComponentZombieNorm.E_AttackValueFactor.Shrink, -1.0))
	_check(a, "僵尸被施加 Shrink 伤害因子 0.5",
		z_attack != null and is_equal_approx(shrink_factor_after, 0.5), str(shrink_factor_after))
	_check(a, "僵尸啃食攻击值约减半",
		z_attack != null and atk_before > 0
			and absf(float(z_attack.curr_attack_value_per_sec) - float(atk_before) * 0.5) <= 2.0,
		"前 %d → 后 %d" % [atk_before, -1 if z_attack == null else z_attack.curr_attack_value_per_sec])

	# ------------------------------------------------ STEP6 绽放完自身消失，但僵尸仍缩着
	a.log("STEP6 绽放完 → 紫罗兰自身消失，僵尸仍保持缩小")
	## bloom 长 4.083s；等到绽放结束（紫罗兰应被消耗掉）
	await a.wait(4.0)
	_check(a, "绽放结束后紫罗兰被消耗掉（节点已释放）", not is_instance_valid(violet),
		"still valid" if is_instance_valid(violet) else "freed")
	_check(a, "紫罗兰消失后僵尸仍缩着（效果挂在僵尸身上，不随植物消失）",
		z_body != null and absf(z_body.scale.x - scale_before.x * 0.5) <= 0.06,
		"null" if z_body == null else str(z_body.scale))

	# ------------------------------------------------ STEP7 缩小到点自行恢复
	a.log("STEP7 缩小持续 5 秒到点 → 僵尸缩放与攻击值恢复")
	## 缩小计时 5s（从种下算起），再留点余量给恢复补间
	await a.wait(1.5)
	_check(a, "到点后僵尸缩放恢复",
		z_body != null and absf(z_body.scale.x - scale_before.x) <= 0.06,
		"null" if z_body == null else str(z_body.scale))
	var shrink_factor_restored: float = -1.0
	if z_attack != null:
		shrink_factor_restored = float(z_attack.attack_value_factor.get(
			AttackComponentZombieNorm.E_AttackValueFactor.Shrink, -1.0))
	_check(a, "到点后 Shrink 伤害因子恢复为 1.0",
		z_attack != null and is_equal_approx(shrink_factor_restored, 1.0), str(shrink_factor_restored))
	_check(a, "到点后僵尸啃食攻击值恢复",
		z_attack != null and absf(float(z_attack.curr_attack_value_per_sec) - float(atk_before)) <= 5.0,
		"前 %d → 后 %d" % [atk_before, -1 if z_attack == null else z_attack.curr_attack_value_per_sec])

	# ------------------------------------------------ STEP8 关掉模组
	a.log("STEP8 关掉模组 → 撤干净")
	if is_instance_valid(cell):
		cell.free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "缩小紫罗兰不再是已解锁", not Global.global_game_state.is_plant_unlocked(SHRINKING_VIOLET))
	_check(a, "注册表里没有缩小紫罗兰了",
		registry.get_plant_info(SHRINKING_VIOLET, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(SHRINKING_VIOLET))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(SHRINKING_VIOLET).get("名字", "")) != "缩小紫罗兰")

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLCSHRINK] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
