extends "../mod_base.gd"
## 模组「明日方舟」：把《明日方舟》的战斗数值规则搬进本作 —— 原版没有这些概念，做成模组
##
## 三块功能（默认数值全为 0 / 不注册精英副本时，开着也是原版体验；关掉模组则整套规则消失）：
##   1. **防御力 / 法术抗性**：按植物 / 僵尸类型配默认值（`arknights_stats.gd` 的两张表），
##      或按单实例临时覆盖（`set_instance_defense()` 一类，写进本体给模组留的
##      `Character000Base.mod_custom_effects` 容器）。
##   2. **攻击分物理 / 法术两类**：伤害类型是随包的便签
##      （`effects[ArknightsStats.KEY_DMG_TYPE]`），发起方 `mark_attack()` 写、修饰器读；
##      **未标记 = 物理** —— 原版的子弹 / 啃食 / 爆炸 / 碾压因此天然全走物理，本体一行不用改。
##   3. **精英化**（`arknights_elite.gd`）：每种内置植物登记一个**精英副本**（运行期植物，
##      复用原版场景，血量 / 伤害 / 防御 / 法抗按精英 profile 加强，阳光 / 冷却打折）；
##      **普通关**里精英副本在选卡列表里**原位顶掉**原版（`AllCards.set_plant_choose_replacement`，
##      不是追加一张新卡）、场上实例按精英数值结算；
##      **特殊关**（`is_general_level()` 判据 + `LEVELS_USE_ORIGINAL` 注明名单）整局用原版植物。
##
## 伤害修饰器（`modify_damage()`，框架在 `install()` 之后自动注册进 `DamageSystem` 修饰器链）：
##   · 物理：`amount = max(0, amount - 目标防御力)`
##   · 法术：`amount = round(amount × (100 - 目标法抗%) / 100)`（法抗夹 0~100）
##
## ⚠️ 减免发生在修饰器链（②-c），**排在防具吸收之后**：只影响打本体那部分，
##    防具那一层照旧（口径见 ../../docs/参考存档/伤害系统.md §10 的警告）。
## ⚠️ 秒杀（`is_instant_kill`）不看防御 / 法抗 —— 与「秒杀不过防具吸收规则」同口径。
##
## 跨文件引用：`user://` 下脚本的 `class_name` 不注册全局类（实测 Godot 4.6.2），
## 一律 preload 成常量再引用，不能写 `extends Xxx` / `var x: Xxx`
const ModBase := preload("../mod_base.gd")
const ArknightsStats := preload("arknights_stats.gd")
const ArknightsElite := preload("arknights_elite.gd")

## 每株精英副本一个 Kit（登记 + 插卡 + 卡面 + 解锁；卸的时候反向全撤）
var _elite_kits: Array[PlantRuntimeKit] = []


func get_mod_id() -> StringName:
	return ModIds.ARKNIGHTS


func get_mod_name() -> String:
	return "明日方舟"


func get_mod_description() -> String:
	return ("给全场角色加入「防御力 / 法术抗性」并把伤害分成物理 / 法术两类；"
		+ "每种植物还有精英副本（血量伤害加强、阳光冷却打折），普通关用精英版代替原版植物，"
		+ "特殊关用原版（未标记伤害按物理算；默认数值全 0，原版体验不变）")


func get_mod_categories() -> Array[StringName]:
	return [ModCategory.OVERRIDE_RULE]


#region 精英副本的装 / 卸
## 全局安装（游戏启动，只调一次）：给每种内置植物登记一个精英副本
##
## 精英副本 = 运行期植物（复用原版场景：动画 / 组件 / 表现与原版完全一致），
## 差异全在**数据与数值**：id / 名字带后缀、阳光冷却打折、实例层加血加伤加法抗。
## 卡面借原版植物的脸（`card_face_fallback_plant`）—— 美术就是原版那一套，不做第二套。
func install() -> void:
	for plant_type: StringName in ArknightsElite.elite_target_types():
		var recipe := _build_elite_recipe(plant_type)
		if recipe == null:
			continue
		var kit := PlantRuntimeKit.new()
		if not kit.install(recipe):
			## 登记失败只跳过这一株，别让整包模组起不来
			Log.error("明日方舟：%s 的精英副本登记失败，已跳过" % str(plant_type))
			continue
		## **不调 `make_selectable()`**：精英副本不是「再进选卡界面的新植物」，而是
		## 「原版那一格的替换者」—— 靠 `on_level_para_ready()` 里的 `set_plant_choose_replacement()`
		## 在原位出场。调了它等于在列表末尾多占一格（见 `AllCards` 的两张表）
		_elite_kits.append(kit)
		## 种子包（卡面）上贴同一枚标记：卡面就是本体精灵树的缩小图片，场上有了它也得有
		ArknightsElite.mark_card(recipe.plant_type)
		## 种植条件整份换成原版的副本（配方只带「地形位 + 位置」，紫卡的基座判定在条件资源里，
		## 不换的话精英紫卡会变成能种在空地上）
		var orig_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
				plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
		if orig_condition != null:
			Global.character_registry.set_runtime_plant_condition(
					recipe.plant_type, orig_condition.duplicate())
	Log.info("明日方舟：已登记 %d 个植物精英副本" % _elite_kits.size())


## 卸载：撤掉选卡原位替换 + 卸掉全部精英副本（Kit 反向摘卡 / 退可选列表 / 清注册表 / 撤解锁），
## 顺手清掉我们替它们换的种植条件覆盖
func uninstall() -> void:
	for kit: PlantRuntimeKit in _elite_kits:
		var elite_type: StringName = kit.recipe.plant_type if kit.recipe != null else PlantIds.NULL
		## 只撤自己登记的那几行替换（别的模组也可能用同一张表）
		if elite_type != PlantIds.NULL:
			AllCards.clear_plant_choose_replacement(ArknightsElite.original_type_of(elite_type))
		kit.uninstall()
		if elite_type != PlantIds.NULL:
			Global.character_registry.clear_runtime_plant_condition(elite_type)
	_elite_kits.clear()
	ArknightsElite.elite_level_active = false


## 一株原版植物的精英副本配方：复用原版场景，阳光 / 冷却按精英 profile 折算
func _build_elite_recipe(plant_type: StringName) -> PlantRuntimeRecipe:
	var plant_scene: Variant = Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	if plant_scene == null:
		return null
	var buffs := ArknightsElite.buffs_of(plant_type)
	var orig_sun: Variant = Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.SunCost)
	var orig_cool: Variant = Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.CoolTime)
	var orig_name: Variant = Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)

	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = ArknightsElite.elite_id_of(plant_type)
	recipe.plant_name = StringName(str(orig_name) + ArknightsElite.NAME_SUFFIX)
	recipe.plant_scene = plant_scene as PackedScene
	recipe.sun_cost = maxi(1, roundi(int(orig_sun) * float(buffs[&"sun_mult"])))
	recipe.cool_time = maxf(0.5, float(orig_cool) * float(buffs[&"cool_mult"]))
	var orig_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if orig_condition != null:
		recipe.condition_bits = orig_condition.plant_condition
		recipe.place_in_cell = orig_condition.place_plant_in_cell
	## 卡面：不取帧（动画名逐株不同、也没必要），直接借原版植物那张卡的脸 ——
	## Kit 在帧末画卡面，取不到就照 `card_face_fallback_plant` 借
	recipe.card_face_anim = &""
	recipe.card_face_fallback_plant = plant_type
	return recipe
#endregion


#region 每局：按关卡类型决定这一局用精英版还是原版
## 关卡数据就绪的那一刻（`MainGameManager._ready()` 里、子管理器建之前）：
## 判「普通关 / 特殊关」→ 置位本局旗标 + 改选卡禁单 + 同步精英副本的解锁状态
func on_level_para_ready(main_game: MainGameManager) -> void:
	if main_game == null or main_game.game_para == null:
		return
	var para := main_game.game_para
	ArknightsElite.elite_level_active = ArknightsElite.is_general_level(para)

	if ArknightsElite.elite_level_active:
		## 普通关：精英副本**原位顶掉**原版在选卡列表里的那一格
		## （`set_plant_choose_replacement`：不是往列表末尾多加一张，见 `AllCards` 那张表）。
		## 待选区的页数 / 位置因此和原版一模一样，只是每格里换成了精英卡。
		## 解锁按「原版解锁了才解锁」同步 —— 进度跟着原版走，不会提前送卡
		for plant_type: StringName in ArknightsElite.elite_target_types():
			var elite_type := ArknightsElite.elite_id_of(plant_type)
			## 登记失败（这一株的副本没装上 / 没卡位）就整株保持原样：
			## 这时**不能**再禁原版，否则这一株在选卡列表里彻底消失
			if not AllCards.set_plant_choose_replacement(plant_type, elite_type):
				continue
			## 本关自己禁掉的植物（关卡数据写的），连它的精英副本一起禁
			if para.banned_plant_types_in_choose_card.has(plant_type):
				_ban_in_choose_card(para, elite_type)
			## 原版植物照样进禁单：选卡列表里它已经没有格子了（不影响显示），
			## 但「冒险模式全锁 / 前 N 槽随机」是按 curr_plant 抽的，不剔掉会抽出原版占位
			_ban_in_choose_card(para, plant_type)
			if Global.global_game_state.is_plant_unlocked(plant_type):
				Global.global_game_state.unlock_plant(elite_type)
			else:
				Global.global_game_state.lock_plant(elite_type)
	else:
		## 特殊关：撤掉原位替换（原版植物回到自己那一格）+
		## 精英副本整张禁选 + 撤解锁（连「上次选卡」里的残留条目一起清，
		## 不然重选上次卡片会点到不存在的卡位）
		## 只撤自己的那几行替换：别的模组也可能往那张表里登记
		for kit: PlantRuntimeKit in _elite_kits:
			if kit.recipe == null:
				continue
			AllCards.clear_plant_choose_replacement(
					ArknightsElite.original_type_of(kit.recipe.plant_type))
			_ban_in_choose_card(para, kit.recipe.plant_type)
			Global.global_game_state.lock_plant(kit.recipe.plant_type)


## 往关卡的选卡禁单里加一个类型（去重；关卡自己可能已经写了禁单）
func _ban_in_choose_card(para, plant_type: StringName) -> void:
	if para.banned_plant_types_in_choose_card.has(plant_type):
		return
	para.banned_plant_types_in_choose_card.append(plant_type)
#endregion


#region 每局：实例层加成接线
## 把这一局所有格子的「种下植物」信号接到精英加成上（照 `eco_wiring.gd` 的接线法）
func install_to_main_game(main_game: MainGameManager) -> void:
	if not ArknightsElite.elite_level_active:
		return
	if main_game == null:
		return
	var manager: PlantCellManager = main_game.plant_cell_manager
	if manager == null:
		return
	for row in manager.all_plant_cells:
		for cell: PlantCell in row:
			if cell == null:
				continue
			if not cell.signal_plant_create.is_connected(_on_plant_created):
				cell.signal_plant_create.connect(_on_plant_created)
	## 读档预种植 / 关卡开场布阵的植物在接线前就已经在场上，补刷一遍
	_apply_buffs_to_all(manager)


## 种植信号：新种下的植物按精英 profile 加强（幂等，标记在实例自己的容器上）
func _on_plant_created(_cell: PlantCell, _plant_type: StringName) -> void:
	var main_game := GameContext.curr_main_game
	if main_game == null:
		return
	var manager: PlantCellManager = main_game.plant_cell_manager
	if manager == null:
		return
	_apply_buffs_to_all(manager)


## 全场刷一遍（只处理没加过成加的：改一遍全部的成本可以忽略，且天然幂等）
func _apply_buffs_to_all(manager: PlantCellManager) -> void:
	for row in manager.all_plant_cells:
		for cell: PlantCell in row:
			if cell == null:
				continue
			for place: CharacterRegistry.PlacePlantInCell in cell.plant_in_cell:
				var plant: Variant = cell.plant_in_cell[place]
				if plant != null:
					ArknightsElite.apply_instance_buffs(plant)
#endregion


#region 伤害类型 + 减免修饰器
## 模组伤害修饰器（②-c，被 `DamageSystem` 对每一次伤害调；`ModManager` 在 `install()` 之后
## 自动把它注册进修饰器链，卸载时自动摘，模组不要自己调 `DamageSystem`）
func modify_damage(info: DamageInfo) -> bool:
	var target := info.target
	if not ArknightsStats.is_character(target):
		return true
	## 秒杀不看数值减免（它本来就不看防具吸收规则）
	if info.is_instant_kill:
		return true
	if ArknightsStats.is_spell_attack(info):
		info.amount = ArknightsStats.reduce_spell(
				info.amount, ArknightsStats.get_spell_resist(target))
	else:
		## 原版伤害与没标记的新攻击都走这支：扣目标防御力点
		info.amount = ArknightsStats.reduce_physical(
				info.amount, ArknightsStats.get_defense(target))
	return true
#endregion


## 模组页面右侧：三条战斗规则 + 精英化怎么配（只读说明，没有任何可调项 ——
## 防御 / 法抗 / 精英数值是角色数据不是全局开关，改它属于改模组配置）
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
			"伤害分两类：物理 / 法术。未标记的伤害（原版的子弹 / 啃食 / 爆炸等）一律按物理处理。"))
	box.add_child(ModBase.create_detail_label(
			"物理伤害：少挨「目标防御力」点（减到 0 为止）。"))
	box.add_child(ModBase.create_detail_label(
			"法术伤害：按「目标法术抗性」百分比减免（四舍五入，法抗 0~100，100 = 免疫）。"))
	box.add_child(ModBase.create_detail_label(
			"秒杀（is_instant_kill）不看防御 / 法抗；减免发生在防具吸收之后，只影响打本体那部分。"))
	box.add_child(ModBase.create_detail_label(
			"配数值：mods_builtin/arknights/arknights_stats.gd 的 PLANT_STATS / ZOMBIE_STATS，"
			+ "按 PlantIds / ZombieIds 填 defense / spell_resist；没填 = 0（原版体验）。"))
	box.add_child(ModBase.create_detail_label(
			"已配数值：植物 %d 种、僵尸 %d 种（其余默认 0）。" % [
				ArknightsStats.PLANT_STATS.size(), ArknightsStats.ZOMBIE_STATS.size()]))
	## ⚠️ `%` 比 `+` 绑得紧：整段拼完再加括号，否则格式化只作用在最后一段上（多出来的参数会报错）
	box.add_child(ModBase.create_detail_label(
			("精英化：每种植物有精英副本（血量 ×%.1f、伤害 ×%.1f、阳光 ×%.1f、冷却 ×%.1f、"
			+ "防御 +%d、法抗 +%.0f%%）；普通关选卡界面在原位把原版换成精英副本（不多出一张卡），"
			+ "场上按精英数值结算。") % [
				ArknightsElite.HP_MULT, ArknightsElite.DAMAGE_MULT, ArknightsElite.SUN_MULT,
				ArknightsElite.COOL_MULT, ArknightsElite.DEFENSE_ADD, ArknightsElite.SPELL_RESIST_ADD]))
	box.add_child(ModBase.create_detail_label(
			"普通关里每张精英种子包的植物右下角有一枚蓝色「精英化」图标（模组目录的 elite_icon.png）"
			+ "—— 卡面借的是原版植物的脸，靠它区分精英卡；场上植物本身不加图标。"))
	box.add_child(ModBase.create_detail_label(
			"特殊关（传送带 / 砸罐子 / 我是僵尸 / 僵王 / 锤僵尸 / 迷你游戏 / 生存…"
			+ "以及注明名单 LEVELS_USE_ORIGINAL）整局用原版植物。"))
	box.add_child(ModBase.create_detail_label(
			"已登记精英副本：%d 株（数值 / 排除名单 / 普通关判据见 arknights_elite.gd）。" % _elite_kits.size()))
	return box
