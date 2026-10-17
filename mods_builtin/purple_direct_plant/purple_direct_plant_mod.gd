extends "../mod_base.gd"
## 模组「紫卡直接种植」：紫卡（升级植物）**不必先种基座植物**，可以直接种在空地上
##
## ★ 为什么是模组：原版紫卡只能种在它的基座植物上（机枪射手要种在双发豌豆上、
##   玉米加农炮要种在两株玉米投手上），"直接种在空地上"是原版没有的玩法。
##   所以整条链路都在本模组里：关掉 = 不装载，判定回到原版那一套。
##
## ★ 代价（惩罚）：没种在基座上时，那一格要付
##   **紫卡自己的价格 + 基座植物的阳光 + 惩罚阳光（默认 50）**；
##   种在基座上（原版那样）价格一分不变。
##   价格是**跟着鼠标走的**：手上拿着紫卡时，指到空地上卡面就变成惩罚价，
##   指回基座上（或放下卡片）就变回标准价 —— 点下去扣的就是卡面那个数。
##
## 装了什么（`install()` 里一次性装好，全局生效）：
##   1. 给每一张紫卡**换一份种植条件资源**（`set_runtime_plant_condition()`）——
##      判定写在方法里，改字段改不动，只能整份换；关掉模组时按 `_origin_conditions` 换回来；
##   2. 订阅 `HAND_CARD_TAKE` / `HAND_CARD_RELEASE` 记住"手上那张卡"（改价要用）。
##
## 本体这边只多了一个**通用口子** `CharacterRegistry.set_runtime_plant_condition()`
## （与 `register_runtime_zombie()` 同一思路：运行期换判据，撤得掉），
## 本体不认识本模组，也没有任何 `if 紫卡直接种植` 的分支。
##
## 关联：[模组机制](../../docs/参考存档/模组机制.md) ｜ PurpleDirectPlantRule ｜
##       ResourcePlantCondition ｜ CharacterRegistry.AllPrePlantPurple

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录 / 上级的文件一律 preload 成常量再引用，不能写 `extends Xxx` / `var x: Xxx`
const ModBase := preload("../mod_base.gd")
const Rule := preload("purple_direct_plant_rule.gd")
const ConditionPurpleDirect := preload("condition_purple_direct.gd")
const ConditionPurpleDirectCobCannon := preload("condition_purple_direct_cob_cannon.gd")

## 模组页面里这一组条目的分组名（只出现在模组页面，不进控制台）
const PANEL_CATEGORY := "紫卡直接种植"

## 被换掉的**原版**条件资源（紫卡类型 → 原条件）：关掉模组时照这份换回去
var _origin_conditions: Dictionary = {}


func get_mod_id() -> StringName:
	return ModIds.PURPLE_DIRECT_PLANT


func get_mod_name() -> String:
	return "紫卡直接种植"


func get_mod_description() -> String:
	return "紫卡不必先种基座植物，可直接种在空地；代价是多付「基座植物的阳光 + 50」（原版紫卡只能种在基座上）"


#region 生命周期
## 启动（开关打开时跑一次）：换掉全部紫卡的种植条件资源
func install() -> void:
	if Global == null or Global.character_registry == null:
		Log.error("紫卡直接种植：注册表不可用，本模组不装")
		return
	EventBus.subscribe(ConstEventName.HAND_CARD_TAKE, Rule.on_card_take)
	EventBus.subscribe(ConstEventName.HAND_CARD_RELEASE, Rule.on_card_release)
	for purple_type in Global.character_registry.AllPrePlantPurple:
		_replace_condition(purple_type)
	Log.info("紫卡直接种植：已换掉 %d 张紫卡的种植条件（惩罚阳光 %d）" % [
		_origin_conditions.size(), Rule.get_penalty_sun()])


## 关开关：换回原版条件资源，并撤掉两个事件订阅
func uninstall() -> void:
	EventBus.unsubscribe(ConstEventName.HAND_CARD_TAKE, Rule.on_card_take)
	EventBus.unsubscribe(ConstEventName.HAND_CARD_RELEASE, Rule.on_card_release)
	Rule.curr_card = null
	if Global == null or Global.character_registry == null:
		_origin_conditions.clear()
		return
	for purple_type in _origin_conditions:
		Global.character_registry.clear_runtime_plant_condition(purple_type)
	_origin_conditions.clear()
#endregion


#region 换条件资源
func _replace_condition(purple_type: StringName) -> void:
	var origin = Global.character_registry.get_plant_info(
			purple_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if origin == null:
		Log.warn("紫卡直接种植：%s 没有种植条件资源，跳过" % str(purple_type))
		return
	var condition := _create_condition(origin)
	if condition == null:
		return
	Global.character_registry.set_runtime_plant_condition(purple_type, condition)
	_origin_conditions[purple_type] = origin


## 造一份"允许无基座种植"的条件资源：字段照抄原版那一份，只换判定方法
## 玉米加农炮是「特殊紫卡」，判据在另一支（`judge_special_plants_condition`），
## 所以要用它自己那个子类，否则两株玉米投手那条路会丢掉
func _create_condition(origin: ResourcePlantCondition) -> ResourcePlantCondition:
	var condition: ResourcePlantCondition
	if origin is ResourcePlantConditionCobCannon:
		condition = ConditionPurpleDirectCobCannon.new()
	else:
		condition = ConditionPurpleDirect.new()
	condition.plant_condition = origin.plant_condition
	condition.place_plant_in_cell = origin.place_plant_in_cell
	condition.is_special_plants = origin.is_special_plants
	condition.is_purple_card = origin.is_purple_card
	return condition
#endregion


func get_mod_categories() -> Array[StringName]:
	return [ModCategory.OVERRIDE_RULE]


#region 模组页面
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"规则：紫卡可以直接种在空地上，不用先种它的基座植物（机枪射手不必先种双发豌豆、玉米加农炮不必先种两株玉米投手）"))
	box.add_child(ModBase.create_detail_label(
		"代价：没种在基座上时，那一格付「紫卡原价 + 基座植物的阳光 + 下面的惩罚阳光」；种在基座上价格不变，与原版一致"))
	box.add_child(ModBase.create_detail_label(
		"看价：手上拿着紫卡时，指到空地上卡面就显示惩罚价，指回基座上或放下卡片就变回标准价 —— 点下去扣的就是卡面那个数"))
	box.add_child(ModBase.create_detail_label(
		"玉米加农炮：没种在两株玉米投手上时，要求后轮两格都空着（它自己会占住后轮那一格）"))

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


## 惩罚阳光那一条（**只喂给模组页面**，不往控制台登记）
func _build_panel_entries() -> Array[ConsoleEntry]:
	return [
		ConsoleEntry.create_slider(&"purple_direct_plant_penalty_sun", "惩罚阳光",
				Rule.PENALTY_SUN_MIN, Rule.PENALTY_SUN_MAX, Rule.PENALTY_SUN_STEP)
			.set_category(PANEL_CATEGORY)
			.set_tooltip("没种在基座上时，除了基座植物本身的阳光之外还要多付多少（0 = 只收基座植物的阳光，不额外罚）")
			.bind(_get_penalty_sun, Rule.set_penalty_sun),
	]


func _get_penalty_sun() -> Variant:
	return Rule.get_penalty_sun()
#endregion
