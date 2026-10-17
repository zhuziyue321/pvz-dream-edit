extends RefCounted
## 探针：模组「明日方舟」的**精英化**机制
##
## 验五块：
##   ① id 映射与目标清单：每株内置（非排除）植物都有精英副本，副本都登记进注册表 / 卡片目录；
##      副本**不自己占选卡列表的一格**（靠原位替换出场，见 `AllCards.set_plant_choose_replacement`）
##   ② 普通关判据：合成的关卡数据里，冒险+ Norm = 普通关；传送带 / 保龄球 / 砸罐子 / 我是僵尸 /
##      僵王 / 迷你模式 / 注明名单 = 特殊关
##   ③ 普通关（adventure_01_01）：原版植物**原位换成**精英副本（列表里每株只占一格，原版不在列表里）；
##      原版植物进了选卡禁单、精英副本没进；精英副本跟随原版解锁；
##      场上植物按精英数值结算（豌豆 300→600 血、子弹 20→30 伤、+15 防御 / +15% 法抗）
##   ④ 特殊关（adventure_01_05）：原位替换撤掉、精英副本进了选卡禁单、原版植物没进；flag 置回 false；
##      场上植物不动数值（豌豆仍是 300 血、组件不写伤害覆盖）
##   ⑤ 收尾：关模组 + 存存档，别把开关状态带给后面的探针
##
## 机器可读汇总：最后一行 [ARKNIGHTS_ELITE] result=PASS|FAIL failed=<n>

const ELITE_PATH := "res://mods_builtin/arknights/arknights_elite.gd"
const GENERAL_LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"
const SPECIAL_LEVEL := "res://src/levels/mode_adventure/adventure_01_05.gd"

## 豌豆射手的原版数值（基类场景默认值：`plant_base.tscn` 的 max_hp、`bullet_norm_base` 的 attack_value）
const PEA_HP_VANILLA := 300
const PEA_DAMAGE_VANILLA := 20

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：明日方舟·精英化 ==========")
	var Elite = load(ELITE_PATH)
	_check(a, "精英规则脚本可加载", Elite != null, ELITE_PATH)
	if Elite == null:
		_finish(a)
		return

	# ------------------------------------------------ ① id 映射
	var pea_elite: StringName = Elite.elite_id_of(PlantIds.PEA_SHOOTER_SINGLE)
	_check(a, "精英 id = 前缀 + 原版 id",
		pea_elite == StringName("arknights_elite_" + str(PlantIds.PEA_SHOOTER_SINGLE)), str(pea_elite))
	_check(a, "原版 id 反查", Elite.original_type_of(pea_elite) == PlantIds.PEA_SHOOTER_SINGLE)
	_check(a, "非精英 id 反查为空", Elite.original_type_of(PlantIds.PEA_SHOOTER_SINGLE) == PlantIds.NULL)

	# ------------------------------------------------ ② 普通关判据（合成关卡数据）
	var plain := ResourceLevelData.new()
	plain.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "adventure_01_01")
	_check(a, "冒险 + Norm = 普通关", Elite.is_general_level(plain))
	var conveyor := ResourceLevelData.new()
	conveyor.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "adventure_01_05")
	conveyor.card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	_check(a, "传送带关 = 特殊关", not Elite.is_general_level(conveyor))
	var bowling := ResourceLevelData.new()
	bowling.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "adventure_01_05")
	bowling.is_bowling_stripe = true
	_check(a, "保龄球关 = 特殊关", not Elite.is_general_level(bowling))
	var pot := ResourceLevelData.new()
	pot.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "adventure_04_05")
	pot.is_pot_mode = true
	_check(a, "砸罐子关 = 特殊关", not Elite.is_general_level(pot))
	var zombie_mode := ResourceLevelData.new()
	zombie_mode.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "puzzle_zombie_01")
	zombie_mode.is_zombie_mode = true
	_check(a, "我是僵尸关 = 特殊关", not Elite.is_general_level(zombie_mode))
	var boss := ResourceLevelData.new()
	boss.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "adventure_05_10")
	boss.boss_type = ZombieBossIds.DOCTOR
	_check(a, "僵王关 = 特殊关", not Elite.is_general_level(boss))
	var minigame := ResourceLevelData.new()
	minigame.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelMiniGame, 0, "minigame_02_bowling")
	_check(a, "迷你游戏 = 特殊关", not Elite.is_general_level(minigame))
	var noted := ResourceLevelData.new()
	noted.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, "adventure_05_05")
	_check(a, "注明名单（蹦极闪电战）= 特殊关", not Elite.is_general_level(noted))

	# ------------------------------------------------ 开模组 → 登记精英副本
	ModManager.set_mod_enabled(ModIds.ARKNIGHTS, true)
	## Kit 的卡面是帧末画的，等一拍
	await a.wait(1.0)
	var targets: Array = Elite.elite_target_types()
	var registered := 0
	for target: StringName in targets:
		if Global.character_registry.is_runtime_plant(Elite.elite_id_of(target)):
			registered += 1
	_check(a, "每株原版植物都登记了精英副本", registered == targets.size(),
		"%d/%d" % [registered, targets.size()])
	_check(a, "排除名单里的植物没有副本",
		not Global.character_registry.is_runtime_plant(Elite.elite_id_of(PlantIds.IMITATER)))
	_check(a, "精英卡插进了卡片目录",
		AllCards.plant_card_ids.has(pea_elite), str(pea_elite))
	## 精英副本**不自己占列表的一格**：它只在「原位替换」生效时出场（见 STEP2）
	var choose_order: Array = AllCards.get_plant_types_in_choose_order()
	_check(a, "精英副本没在选卡列表里多占格子（靠原位替换出场）",
		not choose_order.has(pea_elite), str(choose_order.size()))
	## 卡面口径：精英卡的卡面是**借**原版卡的脸（配方没配取帧动画），借来的必须是
	## 「CharacterStatic 下的那株植物」而不是源卡的 CharacterStatic 整块 ——
	## 后者带着卡内挂点 (24,30)，叠在新卡自己的挂点下就是两倍偏移（种子包贴图偏移）
	var orig_card: Card = AllCards.all_plant_card_prefabs.get(PlantIds.PEA_SHOOTER_SINGLE, null)
	var elite_card: Card = AllCards.all_plant_card_prefabs.get(pea_elite, null)
	var orig_face: Node2D = null
	var elite_face: Node2D = null
	if orig_card != null and is_instance_valid(orig_card.character_static):
		orig_face = orig_card.character_static.get_child(0) as Node2D
	if elite_card != null and is_instance_valid(elite_card.character_static):
		elite_face = elite_card.character_static.get_child(0) as Node2D
	_check(a, "精英卡面只有一层（没把源卡的挂点整块搬过来）",
		orig_face != null and elite_face != null and str(elite_face.name).begins_with("Plant"),
		"null" if elite_face == null else str(elite_face.name))
	_check(a, "精英卡面的缩放与落点和原版卡面一致",
		orig_face != null and elite_face != null
			and elite_face.position == orig_face.position and elite_face.scale == orig_face.scale,
		"null" if (orig_face == null or elite_face == null)
			else "%s / %s" % [str(elite_face.position), str(elite_face.scale)])
	## 种子包（卡面）上的金色标记：卡面就是本体精灵树的缩小图片，标记挂在卡面那株植物下
	## （跟着 0.5 一起缩，落在植物右下角），因此整卡 duplicate 到待选区候选格时也带着
	var card_mark: Node = null
	if elite_face != null:
		card_mark = elite_face.get_node_or_null(^"EliteMark")
	_check(a, "种子包卡面贴了「精英化」标记（挂在卡面植物下）",
		card_mark is Sprite2D and (card_mark as Sprite2D).texture != null,
		"null" if card_mark == null else str(card_mark.name))
	_check(a, "卡面标记落在植物右下角、染蓝色",
		card_mark is Sprite2D and (card_mark as Sprite2D).position == Elite.ICON_POSITION
			and (card_mark as Sprite2D).modulate == Elite.ICON_COLOR,
		"null" if card_mark == null
			else "%s / %s" % [str((card_mark as Sprite2D).position), str((card_mark as Sprite2D).modulate)])
	var recipe_ok := true
	var elite_sun: Variant = Global.character_registry.get_plant_info(
		pea_elite, CharacterRegistry.PlantInfoAttribute.SunCost)
	var elite_cool: Variant = Global.character_registry.get_plant_info(
		pea_elite, CharacterRegistry.PlantInfoAttribute.CoolTime)
	_check(a, "精英副本阳光打折（100 → 80）", elite_sun != null and int(elite_sun) == 80, str(elite_sun))
	_check(a, "精英副本冷却打折（7.5 → 6.0）", elite_cool != null and is_equal_approx(float(elite_cool), 6.0), str(elite_cool))
	recipe_ok = recipe_ok and elite_sun != null
	if not recipe_ok:
		Log.warn("明日方舟探针：精英副本属性读取异常")

	# ------------------------------------------------ ③ 普通关
	a.log("STEP2 普通关（adventure_01_01）：精英版代替原版")
	var mg := await _boot_level(a, GENERAL_LEVEL, "adventure_01_01")
	if mg == null:
		_check(a, "已进入主游戏（普通关）", false, "GameContext.curr_main_game 为空")
		_finish(a)
		return
	var para: ResourceLevelData = mg.game_para
	_check(a, "普通关判定为精英局", Elite.elite_level_active)
	var banned: Array = para.banned_plant_types_in_choose_card
	_check(a, "原版植物进了选卡禁单", banned.has(PlantIds.PEA_SHOOTER_SINGLE))
	_check(a, "精英副本不在禁单里", not banned.has(pea_elite))
	## 选卡列表里是**原位替换**而不是追加：原植物那一格换成精英卡，列表长度不涨
	_check(a, "登记了原位替换（原版 → 精英）",
		AllCards.get_plant_choose_replacement(PlantIds.PEA_SHOOTER_SINGLE) == pea_elite,
		str(AllCards.get_plant_choose_replacement(PlantIds.PEA_SHOOTER_SINGLE)))
	var level_order: Array = AllCards.get_plant_types_in_choose_order()
	_check(a, "原版植物不在选卡列表里（被顶掉了）",
		not level_order.has(PlantIds.PEA_SHOOTER_SINGLE), str(level_order.size()))
	_check(a, "精英副本只出现一次（不再追加一份）",
		level_order.count(pea_elite) == 1, str(level_order.count(pea_elite)))
	## 「替换而不是添加」的判据：每一株植物在列表里**最多占一格** —— 要么原版、要么精英，不会两个都在。
	## 常规植物必须正好一格；调试模式专属那几株（反向双发等）没开调试模式时本来就不在列表里，
	## 放宽成「不超过一格」（开了调试模式则正好换成精英一格）
	var both_in := 0
	var missing := 0
	for target: StringName in targets:
		var slots: int = int(level_order.has(target)) + int(level_order.has(Elite.elite_id_of(target)))
		if slots > 1:
			both_in += 1
		elif slots < 1 and not AllCards.is_appended_plant(target):
			missing += 1
	_check(a, "原版与精英不会同时占格（替换不是追加）", both_in == 0,
		"重复 %d 株 / 共 %d 株" % [both_in, targets.size()])
	_check(a, "常规植物在列表里仍在（换成精英后占着那一格）", missing == 0,
		"缺 %d 株 / 共 %d 株" % [missing, targets.size()])
	var pea_unlocked: bool = Global.global_game_state.is_plant_unlocked(PlantIds.PEA_SHOOTER_SINGLE)
	_check(a, "精英副本跟随原版解锁状态",
		Global.global_game_state.is_plant_unlocked(pea_elite) == pea_unlocked,
		"原版解锁=%s" % str(pea_unlocked))
	var pea := _plant(mg, 2, 2, PlantIds.PEA_SHOOTER_SINGLE)
	if pea == null:
		_check(a, "普通关种得出豌豆射手", false, "格子不可用")
	else:
		_check(a, "种出来的是原版 id 的植物（系统预选 / 重选上次卡片路）", pea.plant_type == PlantIds.PEA_SHOOTER_SINGLE)
		_check(a, "血量按精英加强（%d → 600）" % PEA_HP_VANILLA,
			pea.hp_component.max_hp == 600, str(pea.hp_component.max_hp))
		var attack: AttackComponentBulletBase = pea.get_node_or_null(^"AttackComponent") as AttackComponentBulletBase
		if attack == null:
			_check(a, "拿得到豌豆的攻击组件", false, "null")
		else:
			_check(a, "子弹伤害按精英加强（%d → 30）" % PEA_DAMAGE_VANILLA,
				attack.attack_value_bullet == 30, str(attack.attack_value_bullet))
		var elite_pea := _plant(mg, 2, 3, pea_elite)
		if elite_pea == null:
			_check(a, "普通关种得出精英豌豆", false, "格子不可用 / 精英未解锁")
		else:
			_check(a, "精英豌豆血量也加强（600）",
				elite_pea.hp_component.max_hp == 600, str(elite_pea.hp_component.max_hp))
			var elite_attack: AttackComponentBulletBase = elite_pea.get_node_or_null(^"AttackComponent") as AttackComponentBulletBase
			_check(a, "精英豌豆伤害也只加一次（不叠乘）",
				elite_attack != null and elite_attack.attack_value_bullet == 30,
				"null" if elite_attack == null else str(elite_attack.attack_value_bullet))
	var Stats = load("res://mods_builtin/arknights/arknights_stats.gd")
	if pea != null:
		_check(a, "精英加成附送 +15 防御", Stats.get_defense(pea) == 15, str(Stats.get_defense(pea)))
		_check(a, "精英加成附送 +15% 法抗", is_equal_approx(Stats.get_spell_resist(pea), 15.0), str(Stats.get_spell_resist(pea)))
		## 标记**只在种子包上**：场上植物不加图标（需求：2026-10-17 收窄到种子包）
		_check(a, "场上植物不带标记（标记只在种子包上）",
			pea.get_node_or_null(^"EliteMark") == null)

	# ------------------------------------------------ ④ 特殊关
	a.log("STEP3 特殊关（adventure_01_05）：整局用原版植物")
	mg = await _boot_level(a, SPECIAL_LEVEL, "adventure_01_05")
	if mg == null:
		_check(a, "已进入主游戏（特殊关）", false, "GameContext.curr_main_game 为空")
		_finish(a)
		return
	para = mg.game_para
	_check(a, "特殊关判定为非精英局", not Elite.elite_level_active)
	banned = para.banned_plant_types_in_choose_card
	_check(a, "精英副本进了选卡禁单", banned.has(pea_elite))
	_check(a, "原版植物不在禁单里", not banned.has(PlantIds.PEA_SHOOTER_SINGLE))
	_check(a, "原位替换撤掉了（原版植物回到自己那一格）",
		AllCards.get_plant_choose_replacement(PlantIds.PEA_SHOOTER_SINGLE) == PlantIds.NULL,
		str(AllCards.get_plant_choose_replacement(PlantIds.PEA_SHOOTER_SINGLE)))
	var special_pea := _plant(mg, 2, 2, PlantIds.PEA_SHOOTER_SINGLE)
	if special_pea == null:
		_check(a, "特殊关种得出豌豆射手", false, "格子不可用")
	else:
		_check(a, "血量不动（仍 %d）" % PEA_HP_VANILLA,
			special_pea.hp_component.max_hp == PEA_HP_VANILLA, str(special_pea.hp_component.max_hp))
		var special_attack: AttackComponentBulletBase = special_pea.get_node_or_null(^"AttackComponent") as AttackComponentBulletBase
		if special_attack == null:
			_check(a, "特殊关攻击组件不写伤害覆盖", false, "null")
		else:
			_check(a, "伤害不动（attack_value_bullet 仍 -1）",
				special_attack.attack_value_bullet == -1, str(special_attack.attack_value_bullet))
		_check(a, "特殊关（原版局）场上也不贴标记", special_pea.get_node_or_null(^"EliteMark") == null)

	# ------------------------------------------------ ⑤ 收尾
	ModManager.set_mod_enabled(ModIds.ARKNIGHTS, false)
	ModManager.save_mods()
	_finish(a)


#region 小工具
## 进一个关（照 probe_balance_mod.gd 的进关法；set_choose_level 模拟选关场景写 game_mode）
func _boot_level(a, level_path: String, level_id: String) -> MainGameManager:
	var para: ResourceLevelData = (load(level_path) as GDScript).new()
	if para == null:
		return null
	para.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelAdventure, 0, level_id)
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(4.0)
	return GameContext.curr_main_game


## 在指定格子种一株，返回那株植物（格子不可种 / 种不出来返回 null）
func _plant(mg, row: int, col: int, plant_type: StringName) -> Plant000Base:
	if mg == null or mg.plant_cell_manager == null:
		return null
	var rows: Array = mg.plant_cell_manager.all_plant_cells
	if row >= rows.size():
		return null
	var cells: Array = rows[row]
	if col >= cells.size():
		return null
	var cell: PlantCell = cells[col]
	if cell == null or not cell.can_common_plant:
		return null
	var plant := cell.create_plant(plant_type)
	return plant if is_instance_valid(plant) else null
#endregion


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[ARKNIGHTS_ELITE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
