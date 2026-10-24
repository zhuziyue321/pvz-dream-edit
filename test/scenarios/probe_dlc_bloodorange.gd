extends RefCounted
## 探针：DLC 模组的血橙（BloodOrange，即炸植物）
##
## 无头可跑，只动内存。校验：
##   1. 装上模组 → 注册表里有场景 / 150 阳光 / 30 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后
##   3. 图鉴：模组自己登记的那条「血橙」（150 阳光 / 即炸）
##   4. 种进草地：动画节点在、两段 DLC 动画都在、当前播 `BloodOrange_idle` 且在跑、没有再叠缩放
##   5. 摆放：整株尺寸在爆炸植物的量级，底边贴地（与本体樱桃炸弹同一套口径）
##   6. 爆炸零件：`Area2DBomb`（遮罩 2052 / 250×200）、`CanAttackStatusComponent`、引信计时器、
##      `bomb_value = 1800`
##   7. 进白天关摆僵尸：本行 + 上下相邻两行被炸死、隔两行存活、这株植物炸完即消失
##   8. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

var _failed := 0

const BLOOD_ORANGE := &"dlc_bloodorange"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画里的两段
const ALL_ANIMS: Array[String] = ["BloodOrange_idle", "BloodOrange_explode"]
const STATE_IDLE := &"BloodOrange_idle"
const STATE_EXPLODE := &"BloodOrange_explode"

## 对齐基准：本体樱桃炸弹（同为红色圆形爆炸植物）
const NATIVE_CHERRY_SCENE := "res://src/entities/character/plant/plant_cherry_bomb.tscn"
## 进白天关摆僵尸用（见文件头坑：不用教程关）
const LEVEL := "res://src/levels/mode_adventure/adventure_01_10.gd"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「血橙」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组 → 登记
	a.log("STEP1 装上模组 → 血橙登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(BLOOD_ORANGE, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	if plant_scene == null:
		## 模组没加载成功时（例如并发编辑导致 dlc_mod.gd 暂不能解析）早退，
		## 别让下面的 int(get_plant_info(...)) 抛错把整条探针静默中断
		_check(a, "血橙登记了场景", false, "null（DLC 模组是否加载成功？）")
		_finish(a)
		return
	_check(a, "血橙登记了场景", true, plant_scene.resource_path)
	_check(a, "血橙阳光 = 75（wiki：半价樱桃）",
		int(registry.get_plant_info(BLOOD_ORANGE, CharacterRegistry.PlantInfoAttribute.SunCost)) == 75,
		str(registry.get_plant_info(BLOOD_ORANGE, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "血橙冷却 = 50 秒（wiki：very slow）",
		is_equal_approx(float(registry.get_plant_info(BLOOD_ORANGE,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 50.0),
		str(registry.get_plant_info(BLOOD_ORANGE, CharacterRegistry.PlantInfoAttribute.CoolTime)))
	_check(a, "血橙已解锁", Global.global_game_state.is_plant_unlocked(BLOOD_ORANGE))
	var condition = registry.get_plant_info(BLOOD_ORANGE,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "血橙登记了种植条件", false, "null")
		_finish(a)
		return
	## wiki `Fly = Yes`：陆生那套 + 裸水（8）+ 裸屋顶（32）→ 屋顶 / 泳池的裸地都能直接种
	_check(a, "血橙是飞行植物（2 草地 + 4 花盆 + 16 睡莲 + 8 裸水 + 32 裸屋顶 = 62）",
		condition.plant_condition == 62, str(condition.plant_condition))
	_check(a, "血橙占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "血橙不是紫卡（普通卡，75 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "血橙有卡位", AllCards.plant_card_ids.has(BLOOD_ORANGE))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(BLOOD_ORANGE, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 血橙=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(BLOOD_ORANGE, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(BLOOD_ORANGE)
	_check(a, "装上模组后血橙有图鉴条目", str(entry.get("名字", "")) == "血橙", str(entry))
	_check(a, "图鉴里写的阳光是 150", str(entry.get("参数", {}).get("阳光", "")) == "150",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「即炸」",
		str(entry.get("参数", {}).get("特点", "")).contains("即炸"),
		str(entry.get("参数", {}).get("特点", "")))

	# ------------------------------------------------ STEP4 进关 + 摆僵尸
	a.log("STEP4 进白天关，把两只范围内僵尸 + 两只范围外僵尸摆好")
	var para = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)
	var mg = GameContext.curr_main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "GameContext.curr_main_game 为空")
		_finish(a)
		return
	await a.wait(1.0)
	var home := _find_home(mg.get_tree().current_scene)
	if home != null:
		home.disable_home()
	var manager: PlantCellManager = mg.plant_cell_manager
	## 血橙种在 (row 2, col 2)。
	## ⚠️ 僵尸行号与格子行号是同一套（lane2 的僵尸 y≈363，格子 row2 的植物 y=358，2026-10-18 实测）。
	##   踩过的坑：旧版 `_place_at()` 把僵尸 y 强行写成「格子 y-25」，僵尸再被 lane 校正，
	##   结果样本整体错一行，「相邻行」测成了「隔两行」——现在只挪 x，y 完全交给 lane。
	var BOMB_ROW := 2
	var BOMB_COL := 2
	var BOMB_LANE := BOMB_ROW
	var bomb_cell: PlantCell = manager.all_plant_cells[BOMB_ROW][BOMB_COL]
	if bomb_cell == null or not bomb_cell.can_common_plant:
		_check(a, "血橙那一格拿得到且可种", false, "格子不可用")
		_finish(a)
		return
	var near_a := _spawn_zombie(mg, BOMB_LANE)          ## 本行
	var near_b := _spawn_zombie(mg, BOMB_LANE - 1)      ## 相邻上一行（3×3 覆盖）
	var near_c := _spawn_zombie(mg, BOMB_LANE + 1)      ## 相邻下一行（3×3 覆盖）
	var far_d := _spawn_zombie(mg, BOMB_LANE - 2)       ## 隔两行（范围外）
	_check(a, "四只僵尸都摆得下", near_a != null and near_b != null and near_c != null and far_d != null)
	if near_a == null or near_b == null or near_c == null or far_d == null:
		_finish(a)
		return
	## ⚠️ 立刻挪进场（僵尸一出生可能在场外，会被「刷新清场」清掉）。
	##   只挪 x：y 由僵尸自己的 lane 决定，硬改会被行走逻辑拉回去
	var spawn_x := bomb_cell.global_position.x + 60.0
	_place_at(near_a, spawn_x)
	_place_at(near_b, spawn_x)
	_place_at(near_c, spawn_x)
	_place_at(far_d, spawn_x)
	await a.wait(0.8)
	if not _still_running(mg, near_a, near_b) or not is_instance_valid(near_c) or not is_instance_valid(far_d):
		_check(a, "等到四只僵尸站稳（引用还在）", false, "有引用被释放")
		_finish(a)
		return
	## 再各归位一次（走了一步）
	_place_at(near_a, spawn_x)
	_place_at(near_b, spawn_x)
	var hp_far_d_before := _hp(far_d)

	# ------------------------------------------------ STEP5 种下血橙 + 动画 + 零件 + 摆放
	a.log("STEP5 种下血橙 → 播 DLC 待机动画、检查爆炸零件与摆放")
	var orange: Plant000Base = _plant(manager, BOMB_ROW, BOMB_COL, BLOOD_ORANGE)
	_check(a, "血橙种得下", orange != null, "格子不可用")
	if orange == null:
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = orange.get_node_or_null("Body/BloodOrangeAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/BloodOrangeAnim/AnimLib")
		_finish(a)
		return
	var missing: Array[String] = []
	for anim_name in ALL_ANIMS:
		if not player.has_animation(anim_name):
			missing.append(anim_name)
	_check(a, "两段 DLC 动画都在播放器里", missing.is_empty(), str(missing))
	_check(a, "当前在播待机", player.current_animation == STATE_IDLE, String(player.current_animation))
	_check(a, "播放器真的在跑（不是停在第 0 帧）", player.is_playing())
	var anim_root := orange.get_node_or_null("Body/BloodOrangeAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))
	if anim_root != null:
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 血橙 Body 内 rect=%s（宽 %.1f 高 %.1f）" % [str(content), content.size.x, content.size.y])
		var native_scene: Node = load(NATIVE_CHERRY_SCENE).instantiate()
		var native_rect := AnimationFrameUtil.get_content_rect(native_scene.get_node("Body"))
		a.log("   [INFO] 本体樱桃炸弹 Body 内容 rect=%s" % str(native_rect))
		_check(a, "整株尺寸在爆炸植物的量级（宽 50~90 / 高 50~90 px）",
			content.size.x >= 50.0 and content.size.x <= 90.0
				and content.size.y >= 50.0 and content.size.y <= 90.0,
			str(content.size))
		native_scene.free()
	## 爆炸零件
	var area_bomb := orange.get_node_or_null("Area2DBomb") as Area2D
	_check(a, "挂了爆炸检测框 Area2DBomb", area_bomb != null)
	_check(a, "爆炸框遮罩 = 2052（命中僵尸受击框）",
		area_bomb != null and area_bomb.collision_mask == 2052,
		"null" if area_bomb == null else str(area_bomb.collision_mask))
	var bomb_shape := orange.get_node_or_null("Area2DBomb/CollisionShape2D") as CollisionShape2D
	var bomb_rect: RectangleShape2D = bomb_shape.shape as RectangleShape2D if bomb_shape != null else null
	_check(a, "爆炸框是 250×200（≈3×3）",
		bomb_rect != null and is_equal_approx(bomb_rect.size.x, 250.0) and is_equal_approx(bomb_rect.size.y, 200.0),
		"null" if bomb_rect == null else str(bomb_rect.size))
	_check(a, "挂了可攻击状态组件",
		orange.get_node_or_null("CanAttackStatusComponent") != null)
	var fuse_timer: Timer = orange.get_node_or_null("FuseTimer")
	_check(a, "引信计时器在（一次性）", fuse_timer != null and fuse_timer.one_shot)
	## wiki `damage = 900`：正好是樱桃炸弹 1800 的一半（正文称它是「半价、半伤的樱桃炸弹」）
	_check(a, "爆炸伤害 = 900（wiki；樱桃炸弹的一半）", int(orange.get("bomb_value")) == 900, str(orange.get("bomb_value")))
	## wiki `special = inflicts the Blood Moon effect to zombies`：没被炸死的僵尸会被加速
	_check(a, "血月副作用：加速倍率 1.5 / 持续 10 秒（wiki 未给数值，模组自定）",
		is_equal_approx(float(orange.get("blood_moon_factor")), 1.5)
			and is_equal_approx(float(orange.get("blood_moon_duration")), 10.0),
		"%s / %s" % [str(orange.get("blood_moon_factor")), str(orange.get("blood_moon_duration"))])
	## 断言的是**导出值**：计时器的 wait_time 会被关卡速度折算（`_on_update_speed` 里
	## `wait_time = fuse_time / speed_product`），拿它跟 1.0 比会因关卡速度抖动而误报
	_check(a, "引信时长 = 1.0 秒（长于 idle 0.667 秒）",
		is_equal_approx(float(orange.get("fuse_time")), 1.0)
			and fuse_timer != null and fuse_timer.wait_time > 0.3,
		"fuse_time=%s wait_time=%s" % [str(orange.get("fuse_time")),
			"null" if fuse_timer == null else str(fuse_timer.wait_time)])

	# ------------------------------------------------ STEP6 等引爆：范围内炸死、范围外存活、植物消失
	a.log("STEP6 引信到点 → 引爆：范围内炸死 / 范围外存活 / 这株消失")
	## 诊断用：引爆前把植物 / 爆炸框 / 四只僵尸的实际位置打出来（定位「炸错行」用）
	a.log("   [INFO] orange=%s bomb_area=%s near_a(lane%d)=%s near_b(lane%d)=%s near_c(lane%d)=%s far_d(lane%d)=%s" % [
		str(orange.global_position), str(orange.get_node("Area2DBomb").global_position),
		BOMB_LANE, str(near_a.global_position),
		BOMB_LANE - 1, str(near_b.global_position),
		BOMB_LANE + 1, str(near_c.global_position),
		BOMB_LANE - 2, str(far_d.global_position)])
	await a.wait(2.8)
	_check(a, "本行僵尸被炸死", _is_dead(near_a),
		"hp=%d" % _hp(near_a))
	_check(a, "相邻上一行僵尸也被炸死（3×3 覆盖上一行）", _is_dead(near_b),
		"hp=%d" % _hp(near_b))
	_check(a, "相邻下一行僵尸也被炸死（3×3 覆盖下一行）", _is_dead(near_c),
		"hp=%d" % _hp(near_c))
	_check(a, "隔两行的僵尸存活（范围外）",
		is_instance_valid(far_d) and _hp(far_d) == hp_far_d_before,
		"hp %d → %d" % [hp_far_d_before, _hp(far_d)])
	_check(a, "血橙炸完即消失（不在树里 / 已死）",
		not is_instance_valid(orange) or orange.is_death or not orange.is_inside_tree(),
		"valid=%s is_death=%s" % [str(is_instance_valid(orange)),
			str(orange.is_death if is_instance_valid(orange) else "n/a")])

	# ------------------------------------------------ STEP7 关掉模组
	a.log("STEP7 关掉模组 → 撤干净")
	if is_instance_valid(near_a): near_a.queue_free()
	if is_instance_valid(near_b): near_b.queue_free()
	if is_instance_valid(near_c): near_c.queue_free()
	if is_instance_valid(far_d): far_d.queue_free()
	if is_instance_valid(orange): orange.queue_free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "血橙不再是已解锁", not Global.global_game_state.is_plant_unlocked(BLOOD_ORANGE))
	_check(a, "注册表里没有血橙了",
		registry.get_plant_info(BLOOD_ORANGE, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(BLOOD_ORANGE))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(BLOOD_ORANGE).get("名字", "")) != "血橙")

	_finish(a)


#region 小工具
func _plant(manager, row: int, col: int, plant_type: StringName) -> Plant000Base:
	var cell: PlantCell = manager.all_plant_cells[row][col]
	if cell == null or not cell.can_common_plant:
		return null
	var plant := cell.create_plant(plant_type)
	return plant if is_instance_valid(plant) else null


func _spawn_zombie(mg, lane: int) -> Zombie000Base:
	var create_manager = mg.zombie_manager.zombie_wave_manager.zombie_wave_create_manager
	if create_manager == null:
		return null
	var zombie: Zombie000Base = create_manager.wave_create_zombie(ZombieIds.NORM, lane, 0)
	return zombie if is_instance_valid(zombie) else null


## 只挪 x：僵尸的 y 由自己的 lane 决定，硬改会被行走逻辑拉回去
func _place_at(character, x_pos: float) -> void:
	if is_instance_valid(character):
		character.global_position = Vector2(x_pos, character.global_position.y)


func _find_home(node) -> MainGameHome:
	if node is MainGameHome:
		return node
	for child in node.get_children():
		var found := _find_home(child)
		if found != null:
			return found
	return null


func _still_running(mg, a_ref, b_ref = null) -> bool:
	if not is_instance_valid(mg) or not is_instance_valid(a_ref):
		return false
	return b_ref == null or is_instance_valid(b_ref)


func _hp(character) -> int:
	if not is_instance_valid(character) or character.hp_component == null:
		return 0
	return int(character.hp_component.curr_hp)


## 僵尸是否已死（节点已释放 / 血量见底 / 已置死亡位都算）
func _is_dead(zombie) -> bool:
	if not is_instance_valid(zombie):
		return true
	if bool(zombie.get("is_death")):
		return true
	return _hp(zombie) <= 0
#endregion


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
