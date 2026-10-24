extends RefCounted
## 探针：DLC 模组的「增幅鹅河菊」（Ampliflower，200 阳光范围增益）
##
## 无头可跑，只动内存。校验：
##   1. 装上模组 → 注册表里有场景 / 200 阳光 / 30 秒冷却 / 普通陆生条件，已解锁，且**不是紫卡**
##   2. 卡片：追加在普通植物之后
##   3. 图鉴：模组自己登记的那条「增幅鹅河菊」（200 阳光 / 支援 / 增幅）
##   4. 启动白天关，拿得到植物格子管理器
##   5. 种下增幅鹅河菊：动画节点在、四段 DLC 动画都在、当前播 `Ampliflower_idle` 且在跑、没有再叠缩放；
##      摆放尺寸在花的量级（跑 `get_content_rect()` 打印 INFO 供校准）
##   6. 零件与数值：`BoostScanTimer` / `CheerTimer` 在、都在跑；`boost_factor = 2.0` /
##      `boost_scan_interval = 0.1` / `cheer_interval = 5.0`
##   7. 光环生效：相邻格（3×3 内）的豌豆射手被加上 `Ampliflower` 倍率 ≈ 2.0；隔两格（3×3 外）的没有
##   8. 本株移除 → 相邻豌豆的 `Ampliflower` 倍率恢复成 1.0
##   9. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n>

## 机器可读汇总用的失败计数
var _failed := 0

## 增幅鹅河菊的植物 id（模组自己起的字符串 id，本体不认得它）
const AMPLIFLOWER := &"dlc_ampliflower"
## 普通陆生植物（拿来对照卡位顺序 + 当被增幅的邻居）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的四段
const ALL_ANIMS: Array[String] = ["Ampliflower_idle", "Ampliflower_cheer", "Ampliflower_blink", "Ampliflower_face"]
const STATE_IDLE := &"Ampliflower_idle"

## 启动白天关用（照血橙探针的口径；1-10 是标准 5×9 草坪）
const LEVEL := "res://src/levels/mode_adventure/adventure_01_10.gd"
## 对齐基准：本体向日葵（同为花，同一套画布口径）
const NATIVE_SUN_FLOWER_SCENE := "res://src/entities/character/plant/plant_sun_flower.tscn"
## 增幅鹅河菊种在 (row 2, col 2)：3×3 覆盖 row 1~3 / col 1~3
const AMP_ROW := 2
const AMP_COL := 2
## 相邻（3×3 内）：本行右边一格 (row 2, col 3)
const NEAR_ROW := 2
const NEAR_COL := 3
## 隔两格（3×3 外）：本行 (row 2, col 5)
const FAR_ROW := 2
const FAR_COL := 5


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「增幅鹅河菊」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 装模组 → 登记
	a.log("STEP1 装上模组 → 增幅鹅河菊登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(AMPLIFLOWER, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	if plant_scene == null:
		## 模组没加载成功时（例如并发编辑导致 dlc_mod.gd 暂不能解析）早退，
		## 别让下面的 int(get_plant_info(...)) 抛错把整条探针静默中断
		_check(a, "增幅鹅河菊登记了场景", false, "null（DLC 模组是否加载成功？）")
		_finish(a)
		return
	_check(a, "增幅鹅河菊登记了场景", true, plant_scene.resource_path)
	_check(a, "增幅鹅河菊阳光 = 200（照 wiki）",
		int(registry.get_plant_info(AMPLIFLOWER, CharacterRegistry.PlantInfoAttribute.SunCost)) == 200,
		str(registry.get_plant_info(AMPLIFLOWER, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "增幅鹅河菊冷却 = 30 秒（照 wiki，slow）",
		is_equal_approx(float(registry.get_plant_info(AMPLIFLOWER,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 30.0),
		str(registry.get_plant_info(AMPLIFLOWER, CharacterRegistry.PlantInfoAttribute.CoolTime)))
	_check(a, "增幅鹅河菊已解锁", Global.global_game_state.is_plant_unlocked(AMPLIFLOWER))
	var condition = registry.get_plant_info(AMPLIFLOWER,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "增幅鹅河菊登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "增幅鹅河菊是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "增幅鹅河菊占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "增幅鹅河菊不是紫卡（普通卡，200 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "增幅鹅河菊有卡位", AllCards.plant_card_ids.has(AMPLIFLOWER))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(AMPLIFLOWER, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 增幅鹅河菊=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(AMPLIFLOWER, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(AMPLIFLOWER)
	_check(a, "装上模组后增幅鹅河菊有图鉴条目", str(entry.get("名字", "")) == "增幅鹅河菊", str(entry))
	_check(a, "图鉴里写的阳光是 200", str(entry.get("参数", {}).get("阳光", "")) == "200",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「增幅」相关特点",
		str(entry.get("参数", {}).get("特点", "")).contains("增幅")
			or str(entry.get("参数", {}).get("效果", "")).contains("增"),
		"特点=%s 效果=%s" % [str(entry.get("参数", {}).get("特点", "")), str(entry.get("参数", {}).get("效果", ""))])

	# ------------------------------------------------ STEP4 启动白天关
	a.log("STEP4 启动白天关，拿植物格子管理器")
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
	if manager == null or manager.all_plant_cells.is_empty():
		_check(a, "拿得到植物格子管理器", false, "manager 空")
		_finish(a)
		return

	# ------------------------------------------------ STEP5 种增幅鹅河菊 + 相邻/远端豌豆 + 动画/零件/摆放
	a.log("STEP5 种下增幅鹅河菊 + 相邻/远端豌豆射手，检查动画 / 零件 / 摆放")
	var amp: Plant000Base = _plant(manager, AMP_ROW, AMP_COL, AMPLIFLOWER)
	_check(a, "增幅鹅河菊种得下", amp != null, "格子不可用")
	if amp == null:
		_finish(a)
		return
	await a.frames(2)
	var player: AnimationPlayer = amp.get_node_or_null("Body/AmpliflowerAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/AmpliflowerAnim/AnimLib")
		_finish(a)
		return
	var missing: Array[String] = []
	for anim_name in ALL_ANIMS:
		if not player.has_animation(anim_name):
			missing.append(anim_name)
	_check(a, "四段 DLC 动画都在播放器里", missing.is_empty(), str(missing))
	_check(a, "当前在播待机", player.current_animation == STATE_IDLE, String(player.current_animation))
	_check(a, "播放器真的在跑（不是停在第 0 帧）", player.is_playing())
	var anim_root := amp.get_node_or_null("Body/AmpliflowerAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))
	if anim_root != null:
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 增幅鹅河菊 Body 内 rect=%s（宽 %.1f 高 %.1f，anim_root.position=%s）"
			% [str(content), content.size.x, content.size.y, str(anim_root.position)])
		## 花体型：宽高给个宽松区间，具体底边对齐跑完看 INFO 再回填 position
		_check(a, "整株尺寸在花的量级（宽 40~110 / 高 40~110 px）",
			content.size.x >= 40.0 and content.size.x <= 110.0
				and content.size.y >= 40.0 and content.size.y <= 110.0,
			str(content.size))
		## 本体向日葵对照：量它 Body 的内容 rect，取其底边作为「贴地」基准
		var native_scene: Node = load(NATIVE_SUN_FLOWER_SCENE).instantiate()
		var native_body: Node2D = native_scene.get_node("Body")
		var native_rect := AnimationFrameUtil.get_content_rect(native_body)
		a.log("   [INFO] 本体向日葵 Body 内容 rect=%s（底边 %.1f）" % [str(native_rect), native_rect.end.y])
		a.log("   [INFO] 增幅鹅河菊 底边 %.1f（差 %+.1f，正 = 更靠下）" % [content.end.y, content.end.y - native_rect.end.y])
		_check(a, "底边与本体向日葵对齐（差 ≤ 4 px）",
			absf(content.end.y - native_rect.end.y) <= 4.0,
			"向日葵底 %.1f / 增幅鹅河菊底 %.1f" % [native_rect.end.y, content.end.y])
		native_scene.free()
	## 零件与数值
	_check(a, "光环扫描计时器在", amp.get_node_or_null("BoostScanTimer") != null)
	_check(a, "增幅演出计时器在", amp.get_node_or_null("CheerTimer") != null)
	var scan_timer: Timer = amp.get_node_or_null("BoostScanTimer")
	var cheer_timer: Timer = amp.get_node_or_null("CheerTimer")
	_check(a, "扫描计时器在跑（光环工作中）", scan_timer != null and not scan_timer.is_stopped(),
		"null" if scan_timer == null else "stopped=%s" % str(scan_timer.is_stopped()))
	_check(a, "增幅倍率 = 2.0（wiki 未给，模组自选）",
		is_equal_approx(float(amp.get("boost_factor")), 2.0), str(amp.get("boost_factor")))
	_check(a, "扫描间隔 = 0.1 秒",
		scan_timer != null and is_equal_approx(float(scan_timer.wait_time), 0.1),
		"null" if scan_timer == null else str(scan_timer.wait_time))
	_check(a, "一次增幅持续 = 4.25 秒（wiki：for 4.25 seconds at a time）",
		is_equal_approx(float(amp.get("boost_duration")), 4.25), str(amp.get("boost_duration")))
	_check(a, "演出间隔 = 8.0 秒（长于 cheer 4.33 秒；间隔 wiki 未给，模组自定）",
		cheer_timer != null and is_equal_approx(float(cheer_timer.wait_time), 8.0),
		"null" if cheer_timer == null else str(cheer_timer.wait_time))

	# ------------------------------------------------ STEP6 光环：相邻被增幅 / 远端不被增幅 / 移除后恢复
	a.log("STEP6 光环：相邻格豌豆被加 Ampliflower≈2.0、隔两格不加、移除增幅鹅河菊后恢复 1.0")
	## 增益是**间歇**的（wiki：一次 4.25 秒），先等一次 cheer 把窗口开起来再验
	var window_open := false
	for _i in range(120):
		if bool(amp.get("_boost_active")):
			window_open = true
			break
		await a.wait(0.1)
	_check(a, "等到一次 cheer 把增益窗口打开（间歇生效，不是常驻）", window_open,
		"等 12 秒仍未开窗口")
	var near: Plant000Base = _plant(manager, NEAR_ROW, NEAR_COL, PEA_SHOOTER)
	var far: Plant000Base = _plant(manager, FAR_ROW, FAR_COL, PEA_SHOOTER)
	_check(a, "相邻 / 远端豌豆都种得下", near != null and far != null,
		"near=%s far=%s" % [str(near != null), str(far != null)])
	if near == null or far == null:
		_finish(a)
		return
	## 等几轮扫描（扫描间隔 0.1 秒）让光环把邻居加上
	await a.wait(0.5)
	_check(a, "相邻（3×3 内）豌豆被增幅：Ampliflower 倍率 ≈ 2.0",
		is_equal_approx(_amp_factor(near), 2.0), "near Ampliflower=%s" % str(_amp_factor(near)))
	_check(a, "隔两格（3×3 外）豌豆不被增幅：没有 Ampliflower 倍率",
		_amp_factor(far) < 0.0, "far Ampliflower=%s" % str(_amp_factor(far)))
	## 移除增幅鹅河菊 → 邻居的倍率应恢复成 1.0（不是残留 2.0）
	amp.queue_free()
	await a.wait(0.3)
	_check(a, "移除增幅鹅河菊后，相邻豌豆的 Ampliflower 倍率恢复成 1.0",
		is_equal_approx(_amp_factor(near), 1.0), "near Ampliflower=%s" % str(_amp_factor(near)))

	# ------------------------------------------------ STEP7 关掉模组
	a.log("STEP7 关掉模组 → 撤干净")
	if is_instance_valid(near): near.queue_free()
	if is_instance_valid(far): far.queue_free()
	if is_instance_valid(amp): amp.queue_free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "增幅鹅河菊不再是已解锁", not Global.global_game_state.is_plant_unlocked(AMPLIFLOWER))
	_check(a, "注册表里没有增幅鹅河菊了",
		registry.get_plant_info(AMPLIFLOWER, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(AMPLIFLOWER))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(AMPLIFLOWER).get("名字", "")) != "增幅鹅河菊")

	_finish(a)


#region 小工具
func _plant(manager, row: int, col: int, plant_type: StringName) -> Plant000Base:
	var cell: PlantCell = manager.all_plant_cells[row][col]
	if cell == null or not cell.can_common_plant:
		return null
	var plant := cell.create_plant(plant_type)
	return plant if is_instance_valid(plant) else null


## 读一株植物当前的 `Ampliflower` 倍率来源值；没被增幅过返回 -1（便于和 1.0 区分）
func _amp_factor(plant) -> float:
	if not is_instance_valid(plant):
		return -1.0
	var factors = plant.get("influence_speed_factors")
	if factors == null or not factors.has(Character000Base.E_Influence_Speed_Factor.Ampliflower):
		return -1.0
	return float(factors.get(Character000Base.E_Influence_Speed_Factor.Ampliflower))


func _find_home(node) -> MainGameHome:
	if node is MainGameHome:
		return node
	for child in node.get_children():
		var found := _find_home(child)
		if found != null:
			return found
	return null
#endregion


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
