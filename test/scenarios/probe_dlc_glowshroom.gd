extends RefCounted
## 探针：DLC 模组的光照蘑菇（GlowShroom，夜里的光源辅助菇）
##
## 无头可跑，只动内存。校验：
##   1. 装上模组 → 注册表里有场景 / 50 阳光 / 30 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后
##   3. 图鉴：模组自己登记的那条「光照蘑菇」（50 阳光 / 白天睡觉）
##   4. 种进**夜晚关**：动画节点在、五段 DLC 动画都在、当前播 `GlowShroom_idle` 且在跑、没有再叠缩放
##   5. 摆放：整株尺寸与本体阳光菇同量级，底边与阳光菇对齐
##   6. 睡觉标记：`SleepComponent.is_sleep_in_day = true`；夜晚关里 `is_sleeping = false`
##   7. 光域：`DetectComponent` 不按行过滤、5x5 格 = 380×425、mask 命中僵尸受击框层；
##      照明光 = 路灯花那张 `LanternShine.png` 按原版当粒子撒（自转 + 闪烁）；
##      帽顶小呼吸光 = 动画自带的 BigGlow；粒子铺满同一块照明区
##   8. 掉落链路：域内僵尸被登记进名单 → 触发死亡回调 → `kill_drop_count` +1 且场上多一颗阳光
##   9. 到点离场：触发到点回调 → 死亡但不立刻消失 → 播 `GlowShroom_end` → 播完释放
##   10. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

var _failed := 0

const GLOW_SHROOM := &"dlc_glowshroom"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的五段
const ALL_ANIMS: Array[String] = [
	"GlowShroom_idle", "GlowShroom_sleep", "GlowShroom_blink",
	"GlowShroom_face", "GlowShroom_end",
]
const STATE_IDLE := &"GlowShroom_idle"
const STATE_SLEEP := &"GlowShroom_sleep"

## 对齐基准：本体阳光菇（同为蘑菇，同一套 reanim → Godot 动画的画布口径）
const NATIVE_SUN_SHROOM_SCENE := "res://src/entities/character/plant/plant_sun_shroom.tscn"
## 必须是夜晚关：白天蘑菇睡着，击杀掉落会被 `is_sleeping` 挡住
const LEVEL := "res://src/levels/mode_adventure/adventure_02_01.gd"

## 种植坐标
const ROW := 2
const COL := 2


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「光照蘑菇」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组 → 登记
	a.log("STEP1 装上模组 → 光照蘑菇登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(GLOW_SHROOM, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	if plant_scene == null:
		## 模组没加载成功时早退，别让下面的 int(get_plant_info(...)) 抛错把整条探针静默中断
		_check(a, "光照蘑菇登记了场景", false, "null（DLC 模组是否加载成功？）")
		_finish(a)
		return
	_check(a, "光照蘑菇登记了场景", true, plant_scene.resource_path)
	_check(a, "光照蘑菇阳光 = 50（wiki：50）",
		int(registry.get_plant_info(GLOW_SHROOM,
			CharacterRegistry.PlantInfoAttribute.SunCost)) == 50,
		str(registry.get_plant_info(GLOW_SHROOM, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "光照蘑菇冷却 = 30 秒（wiki：slow）",
		is_equal_approx(float(registry.get_plant_info(GLOW_SHROOM,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 30.0),
		str(registry.get_plant_info(GLOW_SHROOM, CharacterRegistry.PlantInfoAttribute.CoolTime)))
	_check(a, "光照蘑菇已解锁", Global.global_game_state.is_plant_unlocked(GLOW_SHROOM))
	var condition = registry.get_plant_info(GLOW_SHROOM,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "光照蘑菇登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "光照蘑菇是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "光照蘑菇占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "光照蘑菇不是紫卡（普通卡，50 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "光照蘑菇有卡位", AllCards.plant_card_ids.has(GLOW_SHROOM))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(GLOW_SHROOM, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 光照菇=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(GLOW_SHROOM, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(GLOW_SHROOM)
	_check(a, "装上模组后光照蘑菇有图鉴条目", str(entry.get("名字", "")) == "光照蘑菇", str(entry))
	_check(a, "图鉴里写的阳光是 50", str(entry.get("参数", {}).get("阳光", "")) == "50",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了白天睡觉",
		str(entry.get("参数", {}).get("特点", "")).contains("睡"),
		str(entry.get("参数", {}).get("特点", "")))

	# ------------------------------------------------ STEP4 进夜晚关 + 种植
	a.log("STEP4 进夜晚关 → 种下光照蘑菇")
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
	var manager: PlantCellManager = mg.plant_cell_manager
	var cell: PlantCell = manager.all_plant_cells[ROW][COL]
	if cell == null or not cell.can_common_plant:
		_check(a, "光照蘑菇那一格拿得到且可种", false, "格子不可用")
		_finish(a)
		return
	var glow: Plant000Base = cell.create_plant(GLOW_SHROOM)
	_check(a, "光照蘑菇种得下", glow != null, "格子不可用")
	if glow == null:
		_finish(a)
		return
	await a.frames(3)

	var player: AnimationPlayer = glow.get_node_or_null("Body/GlowShroomAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/GlowShroomAnim/AnimLib")
		_finish(a)
		return
	var missing: Array[String] = []
	for anim_name in ALL_ANIMS:
		if not player.has_animation(anim_name):
			missing.append(anim_name)
	_check(a, "五段 DLC 动画都在播放器里", missing.is_empty(), str(missing))
	_check(a, "当前在播待机", player.current_animation == STATE_IDLE, String(player.current_animation))
	_check(a, "播放器真的在跑（不是停在第 0 帧）", player.is_playing())
	var anim_root := glow.get_node_or_null("Body/GlowShroomAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))

	# ------------------------------------------------ STEP5 摆放（与阳光菇对齐）
	a.log("STEP5 摆放：整株尺寸与底边对齐本体阳光菇")
	if anim_root != null:
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 光照蘑菇 Body 内 rect=%s（宽 %.1f 高 %.1f）" % [
			str(content), content.size.x, content.size.y])
		var native_scene: Node = load(NATIVE_SUN_SHROOM_SCENE).instantiate()
		var native_rect := AnimationFrameUtil.get_content_rect(native_scene.get_node("Body"))
		a.log("   [INFO] 本体阳光菇 Body 内容 rect=%s" % str(native_rect))
		## 阳光菇只有 37.6×36.8，光照蘑菇是它的两倍（DLC 原画如此），所以不比「同尺寸」，
		## 只守「还是一株植物的量级」（不超过一格宽的 1.4 倍 / 一格高）
		_check(a, "整株尺寸在一株植物的量级（宽 40~110 / 高 40~110 px）",
			content.size.x >= 40.0 and content.size.x <= 110.0
				and content.size.y >= 40.0 and content.size.y <= 110.0,
			"光照菇 %.1f×%.1f（阳光菇 %.1f×%.1f）" % [content.size.x, content.size.y,
				native_rect.size.x, native_rect.size.y])
		_check(a, "底边与阳光菇对齐（差 ≤ 8 px）",
			absf(content.end.y - native_rect.end.y) <= 8.0,
			"阳光菇底 %.1f / 光照菇底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()

	# ------------------------------------------------ STEP6 睡觉标记
	a.log("STEP6 睡觉：白天睡觉标记在，夜晚关里醒着")
	var sleep_component = glow.get_node_or_null("SleepComponent")
	_check(a, "挂了 SleepComponent", sleep_component != null)
	_check(a, "SleepComponent 标了白天睡觉",
		sleep_component != null and bool(sleep_component.is_sleep_in_day),
		"null" if sleep_component == null else str(sleep_component.is_sleep_in_day))
	_check(a, "夜晚关里没有在睡（否则不会掉阳光）", not glow.is_sleeping,
		str(glow.is_sleeping))

	# ------------------------------------------------ STEP7 光域
	a.log("STEP7 光域：不按行过滤 + 2400×1600 + mask 命中僵尸受击框")
	## 临时植物（wiki `single use`）：先验存活时长，再把它拉长 —— 后面的步骤要等僵尸死、
	## 捡掉落的阳光，别让它在探针跑到一半时自己消失（10 秒是给正常关卡用的）
	_check(a, "临时植物：存活时长 = 10 秒（wiki 只写 temporary，时长模组自定）",
		is_equal_approx(float(glow.get("life_time")), 10.0), str(glow.get("life_time")))
	glow.set("life_time", 9999.0)
	var detect = glow.get_node_or_null("DetectComponent")
	var aura_area := glow.get_node_or_null("DetectComponent/Area2D") as Area2D
	var aura_shape := glow.get_node_or_null("DetectComponent/Area2D/CollisionShape2D") as CollisionShape2D
	var aura_rect: RectangleShape2D = aura_shape.shape as RectangleShape2D if aura_shape != null else null
	_check(a, "DetectComponent 不按行过滤（跨行的方形光域）",
		detect != null and not bool(detect.is_lane),
		"null" if detect == null else str(detect.is_lane))
	_check(a, "光域 = 5x5 格（5 列 × 76 = 380、5 行 × 85 = 425）",
		aura_rect != null and is_equal_approx(aura_rect.size.x, 380.0)
			and is_equal_approx(aura_rect.size.y, 425.0),
		"null" if aura_rect == null else str(aura_rect.size))
	_check(a, "光域 mask = 4（僵尸受击框层）",
		aura_area != null and aura_area.collision_mask == 4,
		"null" if aura_area == null else str(aura_area.collision_mask))
	## 照明光：路灯花同款 —— `LanternShine.png` 当**粒子**撒（原版那圈光就是发射器转出来的，
	## 整张贴只会是一坨 X 形星芒），正在发射
	var shine := glow.get_node_or_null("LanternShine") as GPUParticles2D
	_check(a, "照明光 = 路灯花那张 LanternShine.png（按原版当粒子撒，正在发射）",
		shine != null and shine.texture != null
			and shine.texture.resource_path.contains("LanternShine") and shine.emitting,
		"null" if shine == null else "%s emitting=%s" % [
			shine.texture.resource_path if shine.texture != null else "null",
			str(shine.emitting)])
	## 蘑菇帽上那团小呼吸光是动画自带的 BigGlow，与照明光各管一摊
	var idle_anim := player.get_animation(STATE_IDLE) as Animation
	var sleep_anim := player.get_animation(STATE_SLEEP) as Animation
	_check(a, "帽顶小呼吸光（动画自带 BigGlow）：待机可见、睡眠隐藏",
		_big_glow_visible(idle_anim) and not _big_glow_visible(sleep_anim),
		"idle=%s sleep=%s" % [str(_big_glow_visible(idle_anim)), str(_big_glow_visible(sleep_anim))])
	## 光晕里升起的粒子：DLC 粒子图 glow_particle1，铺满同一块被照亮的地方
	var particles := glow.get_node_or_null("GlowParticles") as GPUParticles2D
	_check(a, "光晕里有上升粒子（DLC 粒子图 glow_particle1，正在发射）",
		particles != null and particles.texture != null
			and particles.texture.resource_path.contains("glow_particle1") and particles.emitting,
		"null" if particles == null else "%s emitting=%s" % [
			particles.texture.resource_path if particles.texture != null else "null",
			str(particles.emitting)])

	# ------------------------------------------------ STEP8 击杀掉落链路
	a.log("STEP8 域内僵尸被击败 → 掉一颗小阳光")
	var create_manager = mg.zombie_manager.zombie_wave_manager.zombie_wave_create_manager
	var zombie: Zombie000Base = null
	if create_manager != null:
		zombie = create_manager.wave_create_zombie(ZombieIds.NORM, ROW, 0)
	_check(a, "造得出一只僵尸", zombie != null)
	if zombie != null:
		## 立刻挪进场（出生点可能在场外，会被刷新清场掉）
		zombie.global_position = manager.all_plant_cells[ROW][COL].global_position + Vector2(60.0, -25.0)
		## 等物理帧让 Area2D 进 / 出信号把僵尸登记进名单
		await a.frames(10)
		var tracked: Array = glow.get("_tracked_zombies")
		_check(a, "僵尸进了光域名单", tracked != null and tracked.has(zombie),
			"tracked=%d" % (0 if tracked == null else tracked.size()))
		var suns_before: int = mg.suns.get_child_count()
		var drops_before := int(glow.get("kill_drop_count"))
		## 直接触发「域内僵尸死亡」回调：只验掉落链路，不跑一整套死亡动画
		glow.call("_on_tracked_zombie_died", zombie)
		await a.frames(2)
		_check(a, "击杀计数 +1", int(glow.get("kill_drop_count")) == drops_before + 1,
			"%d → %d" % [drops_before, int(glow.get("kill_drop_count"))])
		_check(a, "场上多了一颗阳光", mg.suns.get_child_count() == suns_before + 1,
			"%d → %d" % [suns_before, mg.suns.get_child_count()])
		zombie.queue_free()

	# ------------------------------------------------ STEP9 到点离场
	a.log("STEP9 存活时长到点 → 播离场动画，播完才消失")
	## 先把那只僵尸撤掉，别让它在下面这几秒里把菇啃死，干扰判断
	if zombie != null and is_instance_valid(zombie):
		zombie.queue_free()
	## 与 `_on_life_timer_timeout` 同一条链：直接触发它，省去等 10 秒
	glow.call("_on_life_timer_timeout")
	await a.frames(3)
	_check(a, "进入死亡且不再立刻消失（要等离场动画）",
		is_instance_valid(glow) and bool(glow.is_death)
			and not glow.is_queued_for_deletion(),
		"valid=%s is_death=%s" % [str(is_instance_valid(glow)),
			"?" if not is_instance_valid(glow) else str(glow.is_death)])
	_check(a, "正在播离场动画 GlowShroom_end",
		is_instance_valid(glow) and player.current_animation == "GlowShroom_end",
		"?" if not is_instance_valid(glow) else String(player.current_animation))
	await a.wait(2.0)
	_check(a, "离场动画播完已释放", not is_instance_valid(glow))

	# ------------------------------------------------ STEP10 关掉模组
	a.log("STEP10 关掉模组 → 撤干净")
	if is_instance_valid(glow):
		glow.queue_free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "光照蘑菇不再是已解锁", not Global.global_game_state.is_plant_unlocked(GLOW_SHROOM))
	_check(a, "注册表里没有光照蘑菇了",
		registry.get_plant_info(GLOW_SHROOM, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(GLOW_SHROOM))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(GLOW_SHROOM).get("名字", "")) != "光照蘑菇")

	_finish(a)


## 取某段 DLC 动画里 `GlowShroom_BigGlow:visible` 轨道的第 0 个键值
## （这株的「光晕」就是动画自带那张 BigGlow，靠这段轨道自己开关，脚本不再摆第二张）
func _big_glow_visible(anim: Animation) -> bool:
	if anim == null:
		return false
	for i in anim.get_track_count():
		if anim.track_get_path(i) == NodePath("GlowShroom_BigGlow:visible"):
			return bool(anim.track_get_key_value(i, 0))
	return false


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
