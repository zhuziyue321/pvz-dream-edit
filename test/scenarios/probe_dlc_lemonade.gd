extends RefCounted
## 探针：DLC 模组的「柠檬榴弹」（Lemon-nade，200 阳光的一次性三连炸植物）
##
## 无头可跑。校验：
##   1. 注册：装上模组 → 场景 / 200 阳光 / 50 秒冷却 / 普通陆生条件 / 已解锁 / 非紫卡 / 无前置
##   2. 卡位：追加在普通植物之后
##   3. 图鉴：模组自己登记的那条「柠檬榴弹」（200 阳光 / 连炸三次）
##   4. 结构：DLC 动画播放器 + 四段动画 + 动画根未叠缩放 + 摆放落在格线附近
##   5. 战斗零件：炸弹伤害 900、引信计时器在、可攻击状态掩码在
##   6. 引爆：本行与上一行各摆一只僵尸 → 种下柠檬榴弹 → 连炸三次 → 僵尸全灭、本株消失
##   7. 关掉模组 → 注册 / 解锁 / 卡位 / 图鉴一并撤掉
##
## ⚠️ 三条踩过的坑（照 `probe_zhaoxiao_cherry.gd`）：
##   1. 别用 1-1（教程关会推进流程、放教程僵尸、几秒内判负收摊，之后引用全失效）—— 用 1-10。
##   2. 进关后先 `MainGameHome.disable_home()`：探针要摆僵尸，任何一只进房子都会收摊。
##   3. 僵尸一生出来就立刻挪进场（出生点可能超 x 上限 1000，波次一刷新就清场外僵尸）。
##
## 机器可读汇总：最后一行 [DLC] result=PASS|FAIL failed=<n> checks=<n>

## 柠檬榴弹的植物 id（模组自己起的字符串 id）
const LEMONADE := &"dlc_lemonade"
## 普通陆生植物（拿来对照卡位顺序）
const PEA_SHOOTER := PlantIds.PEA_SHOOTER_SINGLE
## DLC 动画场景里的四段
const ALL_ANIMS: Array[String] = [
	"Lemonade_idle", "Lemonade_explode", "Lemonade_explode2", "Lemonade_explode3",
]
const STATE_IDLE := &"Lemonade_idle"
## 见文件头坑 1：不用教程关
const LEVEL := "res://src/levels/mode_adventure/adventure_01_10.gd"
## 柠檬榴弹种哪一格
const BOMB_ROW := 2
const BOMB_COL := 1

var _failed := 0
var _checks := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：DLC 植物「柠檬榴弹」（模组 dlc）==========")
	var registry := Global.character_registry

	# ------------------------------------------------ STEP1 注册
	a.log("STEP1 装上模组 → 柠檬榴弹登记进注册表")
	ModManager.set_mod_enabled(ModIds.DLC, true)
	await a.frames(2)
	var plant_scene = registry.get_plant_info(LEMONADE, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	_check(a, "柠檬榴弹登记了场景", plant_scene != null,
		"null" if plant_scene == null else plant_scene.resource_path)
	_check(a, "柠檬榴弹阳光 = 200（wiki：200）",
		int(registry.get_plant_info(LEMONADE, CharacterRegistry.PlantInfoAttribute.SunCost)) == 200,
		str(registry.get_plant_info(LEMONADE, CharacterRegistry.PlantInfoAttribute.SunCost)))
	_check(a, "柠檬榴弹冷却 = 50 秒（wiki：very slow）",
		is_equal_approx(float(registry.get_plant_info(LEMONADE,
			CharacterRegistry.PlantInfoAttribute.CoolTime)), 50.0))
	_check(a, "柠檬榴弹已解锁", Global.global_game_state.is_plant_unlocked(LEMONADE))
	var condition = registry.get_plant_info(LEMONADE,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if condition == null:
		_check(a, "柠檬榴弹登记了种植条件", false, "null")
		_finish(a)
		return
	_check(a, "柠檬榴弹是普通陆生植物（2 草地 + 4 花盆 + 16 睡莲 = 22）",
		condition.plant_condition == 22, str(condition.plant_condition))
	_check(a, "柠檬榴弹占普通位（Norm）",
		condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Norm,
		str(condition.place_plant_in_cell))
	_check(a, "柠檬榴弹不是紫卡（普通卡，200 阳光直接种）",
		not condition.is_purple_card, str(condition.is_purple_card))

	# ------------------------------------------------ STEP2 卡位
	a.log("STEP2 卡片：追加在普通植物之后")
	_check(a, "柠檬榴弹有卡位", AllCards.plant_card_ids.has(LEMONADE))
	_check(a, "卡排在豌豆射手之后（模组新增一律追加）",
		int(AllCards.plant_card_ids.get(LEMONADE, -1)) > int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
		"豌豆=%d 柠檬=%d" % [int(AllCards.plant_card_ids.get(PEA_SHOOTER, -1)),
			int(AllCards.plant_card_ids.get(LEMONADE, -1))])

	# ------------------------------------------------ STEP3 图鉴
	a.log("STEP3 图鉴：模组自己登记的那条")
	var entry: Dictionary = Global.global_read_data.get_extra_almanac_entry(LEMONADE)
	_check(a, "装上模组后柠檬榴弹有图鉴条目", str(entry.get("名字", "")) == "柠檬榴弹", str(entry))
	_check(a, "图鉴里写的阳光是 200", str(entry.get("参数", {}).get("阳光", "")) == "200",
		str(entry.get("参数", {}).get("阳光", "")))
	_check(a, "图鉴里写了「连炸三次」",
		str(entry.get("参数", {}).get("特点", "")).contains("连炸三次"),
		str(entry.get("参数", {}).get("特点", "")))

	# ------------------------------------------------ STEP4 进关
	a.log("STEP4 进一个白天关（1-10），关掉房子，摆两只僵尸")
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
	_check(a, "找得到房子并把它关掉（探针不跑失败流程）", home != null, "没找到 MainGameHome")
	if home != null:
		home.disable_home()
	var manager: PlantCellManager = mg.plant_cell_manager
	var bomb_cell: PlantCell = manager.all_plant_cells[BOMB_ROW][BOMB_COL]
	if bomb_cell == null:
		_check(a, "柠檬榴弹那一格拿得到", false, "格子为空")
		_finish(a)
		return

	# ------------------------------------------------ STEP5 摆僵尸 + 结构
	a.log("STEP5 摆两只僵尸（本行 + 上一行），再种柠檬榴弹并查结构 / 摆放")
	var near_a := _spawn_zombie(mg, BOMB_ROW)
	var near_b := _spawn_zombie(mg, BOMB_ROW - 1)
	_check(a, "两只僵尸都摆得下", near_a != null and near_b != null)
	if near_a == null or near_b == null:
		_finish(a)
		return
	## ⚠️ 立刻挪进场（坑 3）；摆在格子右侧一点，落在 250×200 爆炸框内
	_place_at(near_a, bomb_cell.global_position + Vector2(40.0, -25.0))
	_place_at(near_b, bomb_cell.global_position + Vector2(70.0, -25.0))
	await a.wait(0.5)
	if not _still_running(mg, near_a, near_b):
		_check(a, "等到两只僵尸站稳（引用还在）", false, "引用已释放")
		_finish(a)
		return
	_place_at(near_a, bomb_cell.global_position + Vector2(40.0, -25.0))
	_place_at(near_b, bomb_cell.global_position + Vector2(70.0, -25.0))
	await a.frames(1)

	var lemon: Plant000Base = _plant(manager, BOMB_ROW, BOMB_COL, LEMONADE)
	_check(a, "柠檬榴弹种得下", lemon != null, "null" if lemon == null else str(lemon))
	if lemon == null:
		_finish(a)
		return
	## 种下即点引信（fuse≈0.6 秒）：结构检查必须在这之前做完（frames 级，同步）
	await a.frames(2)
	var player: AnimationPlayer = lemon.get_node_or_null("Body/LemonadeAnim/AnimLib")
	if player == null:
		_check(a, "身上有 DLC 动画播放器", false, "取不到 Body/LemonadeAnim/AnimLib")
	else:
		var missing: Array[String] = []
		for anim_name in ALL_ANIMS:
			if not player.has_animation(anim_name):
				missing.append(anim_name)
		_check(a, "四段 DLC 动画都在播放器里", missing.is_empty(), str(missing))
		_check(a, "引信期间在播待机", player.current_animation == STATE_IDLE,
			String(player.current_animation))
	var anim_root := lemon.get_node_or_null("Body/LemonadeAnim") as Node2D
	_check(a, "动画节点没有再叠一层缩放",
		anim_root != null and anim_root.scale.is_equal_approx(Vector2.ONE),
		"null" if anim_root == null else str(anim_root.scale))
	## 摆放：整株落在格线附近（内容底边 ≈ 0，整株偏高瘦）
	if anim_root != null:
		var content := AnimationFrameUtil.get_content_rect(anim_root)
		a.log("   [INFO] 柠檬榴弹 Body 内 rect=%s" % str(content))
		_check(a, "整株尺寸在偏高瘦的量级（宽 40~80 / 高 70~110 px）",
			content.size.x >= 40.0 and content.size.x <= 80.0
				and content.size.y >= 70.0 and content.size.y <= 110.0,
			str(content.size))
		_check(a, "底边落在格线附近（|底边| ≤ 14 px，坐在地上不悬空）",
			absf(content.end.y) <= 14.0, "底边 %.1f" % content.end.y)
	## 战斗零件
	_check(a, "炸弹伤害 = 900（wiki：900）", int(lemon.get("bomb_damage")) == 900,
		str(lemon.get("bomb_damage")))
	_check(a, "引信 / 步进计时器在", lemon.get_node_or_null("ActionTimer") != null)
	_check(a, "挂了可攻击状态掩码组件", lemon.get_node_or_null("CanAttackStatusComponent") != null)

	# ------------------------------------------------ STEP6 引爆 → 僵尸全灭 + 本株消失
	a.log("STEP6 引信到点连炸三次 → 两只僵尸全灭、柠檬榴弹消失")
	## fuse 0.6 + 两段间隔 0.28×2 + 收尾 1.0 ≈ 2.2 秒，留足余量
	await a.wait(3.0)
	_check(a, "本行那只僵尸被炸死", not _alive(near_a),
		"hp=%d is_death=%s valid=%s" % [_hp(near_a), str(_is_death(near_a)), str(is_instance_valid(near_a))])
	_check(a, "上一行那只僵尸也被炸死（3×3 覆盖上下各一行）", not _alive(near_b),
		"hp=%d is_death=%s valid=%s" % [_hp(near_b), str(_is_death(near_b)), str(is_instance_valid(near_b))])
	_check(a, "柠檬榴弹用完已消失", not is_instance_valid(lemon))

	# ------------------------------------------------ STEP7 关掉模组
	a.log("STEP7 关掉模组 → 撤干净")
	if is_instance_valid(lemon):
		lemon.queue_free()
	await a.frames(2)
	ModManager.set_mod_enabled(ModIds.DLC, false)
	await a.frames(1)
	_check(a, "柠檬榴弹不再是已解锁", not Global.global_game_state.is_plant_unlocked(LEMONADE))
	_check(a, "注册表里没有柠檬榴弹了",
		registry.get_plant_info(LEMONADE, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null)
	_check(a, "卡位撤掉了", not AllCards.plant_card_ids.has(LEMONADE))
	_check(a, "图鉴条目也撤掉",
		str(Global.global_read_data.get_extra_almanac_entry(LEMONADE).get("名字", "")) != "柠檬榴弹")

	_finish(a)


#region 小工具（照 probe_zhaoxiao_cherry.gd）
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


func _place_at(character, global_pos: Vector2) -> void:
	if is_instance_valid(character):
		character.global_position = global_pos


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


func _is_death(character) -> bool:
	return is_instance_valid(character) and bool(character.is_death)


## 僵尸还活着吗（引用没了 / 已标死亡都算「不活」）
func _alive(character) -> bool:
	return is_instance_valid(character) and not bool(character.is_death)
#endregion


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	_checks += 1
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[DLC] result=%s failed=%d checks=%d"
		% ["PASS" if _failed == 0 else "FAIL", _failed, _checks])
	a.finish(true)
