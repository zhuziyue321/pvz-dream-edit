extends "../mod_base.gd"
## 模组「更多的防具」：原版的桶只有铁桶一种，本模组按 Minecraft 的矿石阶梯再加三种 ——
## **铜桶 / 钻石桶 / 下界合金桶**，各配一只戴桶的僵尸（铜桶会氧化变脆、下界合金最硬）。
##
## ★ 为什么是模组：这三个盔甲原版没有，属于同人加的。整条链路都在本模组里 ——
##   本体（`zombie_info_data.gd` / `zombie_bucket.tscn` / 出怪系统）**不认识它们**，
##   关掉模组 = 不注册、不进出怪表，一只都不会出现。
##
## 装了什么（三步）：
##   1. `install()`（启动一次）：往 `CharacterRegistry` **热注册**三只僵尸
##      （本体复用 `zombie_bucket.tscn`，脚本换掉贴图与防具血量，见 `OreBucketZombieBase`），
##      并给每只插一张**僵尸卡**（`ZombieRuntimeKit`：插卡 + 取卡面 + 进已解锁名单）——
##      想在选卡界面里亲手放一只铜桶，就靠这三张卡；
##   2. `on_level_para_ready()`（每局一次）：把这三只加进本关的 `zombie_refresh_types` ——
##      自然出怪只认这一张表，不加进去就是「注册了却永远不出场」；
##      同时补一次「已解锁」（读档会照存档重建那份名单，只装一次的话一读档卡就又暗了）。
##
## ★ 僵尸卡页本身只在「僵尸卡可用」时生成：总开关（`ConstFeatureSwitch.ZOMBIE_CARD_ENABLED`）
##   关着的时候，去控制台打开「调试模式」即可（判据是 `GlobalGameState.is_zombie_card_enabled()`）——
##   本模组只负责「有这三张卡」，那条通道是本体自己的。
##
## 关联：[模组机制](../../../docs/参考存档/模组机制.md) ｜ [防具](../../../docs/参考存档/防具.md) ｜
##       ZombieRuntimeRecipe ｜ OreBucketZombieBase

## 本体：铁桶僵尸的场景（桶精灵 / 铁器节点 / 掉落物 / 破损外观整套现成）
## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录 / 上级的文件一律 preload 成常量再引用，不能写 `extends Xxx` / `var x: Xxx`
const ModBase := preload("../mod_base.gd")
## 下面三个常量取的是**脚本上的常量**（`ARMOR_MAX_HP`，给模组页面写说明用），
## 与再下面的 `SCRIPT_*`（喂给 `CharacterRegistry` 的配方）指向同一批文件，不是重复登记
const ZombieCopperBucket := preload("zombie_copper_bucket.gd")
const ZombieDiamondBucket := preload("zombie_diamond_bucket.gd")
const ZombieNetheriteBucket := preload("zombie_netherite_bucket.gd")
## 铜桶那层防具（易伤 / 氧化的数值在它身上，给模组页面写说明用）
const ArmorCopperBucket := preload("armor_copper_bucket.gd")
## 钻石桶那层防具（受击 20 次触发变身 —— 数值给模组页面写说明用）
const ArmorDiamondBucket := preload("armor_diamond_bucket.gd")
## 下界合金桶那层防具（50% 减伤的数值在它身上）
const ArmorNetheriteBucket := preload("armor_netherite_bucket.gd")

const BASE_SCENE := preload("res://src/entities/character/zombie/zombie_bucket.tscn")

const SCRIPT_COPPER := preload("zombie_copper_bucket.gd")
const SCRIPT_DIAMOND := preload("zombie_diamond_bucket.gd")
const SCRIPT_NETHERITE := preload("zombie_netherite_bucket.gd")

## 三只僵尸的自然出怪参数（口径照 `zombie_info_data.gd`：铁桶 战力 4 / 权重 3000 / 阳光 125）
## 铜桶（血量同铁桶，靠氧化变脆 → 战力略低）；钻石与下界合金更硬 → 战力更高、出得更少
const COPPER_POWER := 3
const COPPER_WEIGHT := 1600
const COPPER_SUN_COST := 100
const DIAMOND_POWER := 6
const DIAMOND_WEIGHT := 1200
const DIAMOND_SUN_COST := 175
const NETHERITE_POWER := 8
const NETHERITE_WEIGHT := 700
const NETHERITE_SUN_COST := 225

## 「这三只进不进自然出怪」在**模组存档文件**里的键名（`[more_armor]` 段；与开关同一份文件）
const SETTING_KEY_SPAWN_ENABLED := "spawn_enabled"
## 默认**进**：装这个模组就是为了在关卡里遇到它们
const SPAWN_ENABLED_DEFAULT := true
## 模组页面里这一组条目的分组名（只出现在模组页面，不进控制台）
const PANEL_CATEGORY := "更多的防具"

## 已注册成功的僵尸类型（进本关出怪表 / 卸载时撤销都用这份；编号由注册表自动分配）
var _registered_types: Array[StringName] = []
## 三张僵尸卡的「装 / 卸」（`ZombieRuntimeKit`：一个管一只）
var _card_kits: Array[ZombieRuntimeKit] = []


## 这三只是否加入自然出怪（模组页面里的开关，值落在模组存档文件本模组那一段）
static func is_spawn_enabled() -> bool:
	return bool(ModManager.get_mod_value(
			ModIds.MORE_ARMOR, SETTING_KEY_SPAWN_ENABLED, SPAWN_ENABLED_DEFAULT))


func get_mod_id() -> StringName:
	return ModIds.MORE_ARMOR


func get_mod_name() -> String:
	return "更多的防具"


func get_mod_description() -> String:
	return "加三种矿石桶（铜桶 / 钻石桶 / 下界合金桶）与各一只戴桶的僵尸；原版只有铁桶"


## 启动：热注册三只矿石桶僵尸（编号由注册表从 9001 起自动分配，不占内置僵尸的号段）
func install() -> void:
	if Global == null or Global.character_registry == null:
		Log.error("更多的防具：注册表不可用，三只矿石桶僵尸没注册上")
		return
	_register(SCRIPT_COPPER, &"ZombieCopperBucket", COPPER_POWER, COPPER_WEIGHT, COPPER_SUN_COST)
	_register(SCRIPT_DIAMOND, &"ZombieDiamondBucket", DIAMOND_POWER, DIAMOND_WEIGHT, DIAMOND_SUN_COST)
	_register(SCRIPT_NETHERITE, &"ZombieNetheriteBucket", NETHERITE_POWER, NETHERITE_WEIGHT, NETHERITE_SUN_COST)


## 关开关：撤掉三张卡、把三只从注册表里撤销（下一局不再出场，待选区里也不再有它们）
func uninstall() -> void:
	## 先摘卡再注销僵尸：重排卡号时要按类型查冷却与阳光（见 `ZombieRuntimeKit`）
	for kit in _card_kits:
		kit.uninstall()
	_card_kits.clear()
	if Global == null or Global.character_registry == null:
		return
	for zombie_type in _registered_types:
		Global.character_registry.unregister_runtime_zombie(zombie_type)
	_registered_types.clear()


## 每局：把三只加进本关的出怪表（**改关卡数据的唯一时机就在这里**，晚了出怪池已按旧表建好）
func on_level_para_ready(main_game: MainGameManager) -> void:
	## 每局补一次解锁：读档会照存档重建 `curr_zombie`（见 `ZombieRuntimeKit.unlock`）
	## 这一句要在「加出怪表」之前：那一段是开关关掉就直接返回的
	for kit in _card_kits:
		kit.unlock()
	if not is_spawn_enabled():
		return
	if main_game == null or main_game.game_para == null:
		return
	var added_count := 0
	for zombie_type in _registered_types:
		if main_game.game_para.zombie_refresh_types.has(zombie_type):
			continue
		main_game.game_para.zombie_refresh_types.append(zombie_type)
		added_count += 1
	if added_count > 0:
		Log.info("更多的防具：本关出怪表已加入 %d 种矿石桶僵尸" % added_count)


func get_mod_categories() -> Array[StringName]:
	return [ModCategory.ADD_UNIT]


## 模组页面右侧：三种矿石桶的血量 + 要不要进自然出怪
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"三种矿石桶（都是铁器，磁力菇能吸走；数字是这一层防具的血量，铁桶是 1100）："))
	box.add_child(ModBase.create_detail_label(
		"　铜桶 %d —— 与铁桶一样厚，但会随时间氧化变脆：易伤最高 ×%.1f，%d 秒氧化到底"
		% [ZombieCopperBucket.ARMOR_MAX_HP, ArmorCopperBucket.MAX_DAMAGE_RATE,
			int(ArmorCopperBucket.OXIDIZE_FULL_TIME)]))
	box.add_child(ModBase.create_detail_label(
		"　　　易伤只对本层防具生效（放大出来的伤害不啃本体），桶会一路氧化成铜锈色"))
	box.add_child(ModBase.create_detail_label(
		"　钻石桶 %d —— 跟铁桶一模一样（血量、破损三段、贴图换色），唯一的特殊是"
		% ZombieDiamondBucket.ARMOR_MAX_HP))
	box.add_child(ModBase.create_detail_label(
		"　　　**挨打 %d 次后变下界合金桶**（防具换成下界合金那层、贴图也换；上限与当前血量都沿用）"
		% ArmorDiamondBucket.TRANSFORM_HIT_COUNT))
	box.add_child(ModBase.create_detail_label(
		"　下界合金桶 %d —— 跟铁桶一样厚，但**本层防具 50%% 减伤**（打到本层的伤害先打个折再扣血，"
		% ZombieNetheriteBucket.ARMOR_MAX_HP))
	box.add_child(ModBase.create_detail_label(
		"　　　实际能挡 ≈ %.0f；贴图四张，破损分四段；钻石桶变身后也是这个样子" % (
		ZombieNetheriteBucket.ARMOR_MAX_HP / (1.0 - ArmorNetheriteBucket.DAMAGE_REDUCTION))))
	box.add_child(ModBase.create_detail_label(
		"它们走僵尸热注册（编号 9001 起），本体不认识；关掉本模组就是一只都不出现。"))
	box.add_child(ModBase.create_detail_label(
		"想在选卡界面里亲手放一只：控制台 → 调试 → 打开「调试模式」，选卡界面的僵尸卡页里就有这三张"
		+ "（卡面就是那只僵尸自己，桶的颜色与血条一致）；放着不管它们也会照出怪表自己出场。"))

	var builder := ConsoleEntryControl.new()
	for item in _build_panel_entries():
		var entry := item as ConsoleEntry
		if entry == null:
			continue
		var control := builder.create_control(entry)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(control)
	box.set_meta(ModBase.DETAIL_REFRESH_META, func() -> void:
		builder.refresh()
	)
	return box


## 「进不进自然出怪」那一条（**只喂给模组页面**，不往控制台登记）
func _build_panel_entries() -> Array[ConsoleEntry]:
	return [
		ConsoleEntry.create_toggle(&"more_armor_spawn_enabled", "加入本关出怪表")
			.set_category(PANEL_CATEGORY)
			.set_tooltip("开 = 每一关的自然出怪表里都加上这三只；关 = 它们注册了但不出场（下一局生效）")
			.bind(_get_spawn_enabled, _set_spawn_enabled),
	]


func _get_spawn_enabled() -> Variant:
	return is_spawn_enabled()


func _set_spawn_enabled(value: Variant) -> void:
	ModManager.set_mod_value(ModIds.MORE_ARMOR, SETTING_KEY_SPAWN_ENABLED, bool(value))


## 热注册一只矿石桶僵尸：本体是铁桶僵尸，脚本负责换贴图与改血量
func _register(zombie_script: Script, zombie_name: StringName,
		spawn_power: int, spawn_weight: int, sun_cost: int) -> void:
	var recipe := ZombieRuntimeRecipe.new()
	recipe.base_scene = BASE_SCENE
	recipe.zombie_script = zombie_script
	recipe.zombie_name = zombie_name
	## 与铁桶一致：水陆两栖
	recipe.row_type = CharacterRegistry.ZombieRowType.Both
	recipe.spawn_power = spawn_power
	recipe.spawn_weight = spawn_weight
	recipe.sun_cost = sun_cost
	if not Global.character_registry.register_runtime_zombie(recipe):
		Log.error("更多的防具：热注册 %s 失败" % zombie_name)
		return
	_registered_types.append(recipe.zombie_type)
	## 顺手插一张僵尸卡：想在选卡界面里亲手放一只，就靠这张卡
	## （那页只在「僵尸卡可用」时出现：控制台打开「调试模式」即可，见类注释）
	var kit := ZombieRuntimeKit.new()
	if kit.install(recipe.zombie_type):
		_card_kits.append(kit)
