extends "res://src/mods/mod_base.gd"
## 僵尸卡：发僵尸卡牌 + 换上 PVZ2 的僵尸卡槽 / 僵尸卡面 / 脑光
##
## ## 为什么是模组（而不是本体功能）
##
##   · 原版 PVZ1 的常规关卡没有「在关卡里直接放下僵尸」这件事，所以本体那条僵尸卡通道是
##     **关着**的（`ConstFeatureSwitch.ZOMBIE_CARD_ENABLED = false`；只有控制台「调试模式」
##     会临时打开）。
##   · 「我是僵尸」关卡恰恰要靠僵尸卡开局 —— 没有它那关发不出牌、也判不了负
##     （没有僵尸卡时 `MgMLoseManager.get_min_zombie_sun_cost()` 返回 0 = 不判负）。
##   · 打开那个总开关是**全局**的：普通关卡的选卡界面也会冒出僵尸页，玩家能在正常关里放僵尸。
##     所以本模组不去动总开关，只在需要僵尸卡的关卡里**直接把僵尸卡发进出战卡槽**。
##
## ## 生效范围（两类关卡，别的关卡一行代码都不走）
##
##   1. `game_para.is_zombie_mode` 的关卡（「我是僵尸」）—— 发僵尸卡 + 换全套 PVZ2 外观：
##      出战卡槽底图 / 僵尸卡卡面 / 选卡界面背景 / 脑光 / 脑子阳光
##   2. **玩家对战**关卡（`game_mode == ChooseLevelPlayerBattle`，见玩家对战模组）——
##      **12 槽合一**：本体的出战卡槽配成 12 格（前 6 格植物 / 后 6 格僵尸与僵王，
##      分块与分池走卡槽的通用口子），右上只摆一条**反转银行视图**
##      （PVZ2 `ZombieSeedBank` 水平翻转，脑子计数在右）当占位格 6~11 的宿主；
##      选卡时贴一条选僵尸卡面板，一张没选发默认六张（见 `zombie_card_settings.gd`）。
##
## 素材来自本机那份 PVZ2 DLC（`../PVZ_DLC/_unpacked/images/`），随模组一起分发。

## 基类只有框架那一份（绝对路径）：`user://` 下不能用 `extends ModBase`
const ModBase := preload("res://src/mods/mod_base.gd")

const Settings := preload("zombie_card_settings.gd")
const ZombieCardWiring := preload("zombie_card_wiring.gd")
const ZombieCardPvpWiring := preload("zombie_card_pvp_wiring.gd")
const TombstoneScene := preload("vsgravestone/plant_vsgravestone.tscn")
const TombstoneCondition := preload("vsgravestone/condition_zombie_side_plant.gd")

## 产脑光墓碑（运行期植物，数值见 `zombie_card_settings.gd`）
var _tombstone_kit: PlantRuntimeKit
## 墓碑的种植条件（落位资格跟僵尸走，见 `condition_zombie_side_plant.gd`）
var _tombstone_condition: ResourcePlantCondition


## 模组 id（登记在 `ModIds`，与 `ModManager.MOD_SCRIPT_PATHS` 一一对应）
func get_mod_id() -> StringName:
	return ModIds.ZOMBIE_CARD


## 模组显示名（原叫「僵尸卡（我是僵尸）」，玩家对战也用它之后去掉后缀）
func get_mod_name() -> String:
	return "僵尸卡"


## 模组说明：一句话写清它改了什么、为什么不属于原版
func get_mod_description() -> String:
	return "「我是僵尸」关卡发僵尸卡牌并换上 PVZ2 的僵尸卡槽 / 卡面 / 脑光；" \
		+ "「玩家对战」关卡把出战卡槽配成 12 格（前 6 植物 / 后 6 僵尸，分池花阳光与脑子），" \
		+ "选卡时贴着植物待选区选僵尸卡，右上摆反转的银行视图。" \
		+ "另把 DLC 对战墓碑接成 **产脑光墓碑**（50 脑光，对战选卡面板末尾那格；" \
		+ "种下去像向日葵一样周期性给僵尸方入账脑子）。"


## 分类：改写规则（改的是「僵尸卡能不能用」这条既有规则）+ 新增单位（产脑光墓碑）
func get_mod_categories() -> Array[StringName]:
	return [ModCategory.OVERRIDE_RULE, ModCategory.ADD_UNIT]


## 模组页面右侧：现在做到了哪一步
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label("「我是僵尸」：发僵尸卡牌 + PVZ2 卡槽 / 卡面 / 脑光 / 脑子阳光"))
	box.add_child(ModBase.create_detail_label("「玩家对战」：出战卡槽 12 格合一（前 6 植物 / 后 6 僵尸，分池花阳光与脑子）"))
	box.add_child(ModBase.create_detail_label("「玩家对战」：右上反转银行当僵尸占位格的外观宿主；选卡时植物待选区右面贴选僵尸卡面板"))
	box.add_child(ModBase.create_detail_label("产脑光墓碑：50 脑光（对战选卡面板末尾），行为类似向日葵、周期给僵尸方入账脑子，冷却 7.5 秒"))
	return box


## 全局安装：把产脑光墓碑注册成运行期植物（登记 + 卡片 + 卡面 + 解锁都在 Kit 里）
##
## ★ 故意**不登记选卡页**（`register_plant_choose_page`）：它不走植物选卡界面，
##   只由接线在「我是僵尸」关卡里直接发进出战卡槽（见 `zombie_card_wiring.gd`）。
func install() -> void:
	## 幂等：已经装着就不再装第二份 —— 重复 install 会「卡牌身份重复注册」，
	## 而且旧那份卡摘不掉（卸载只认当前 Kit 手里那张），目录里会留一具空卡
	if _tombstone_kit != null and _tombstone_kit.is_installed():
		Log.warn("僵尸卡模组：产脑光墓碑已装着，跳过重复 install")
		return
	_tombstone_kit = PlantRuntimeKit.new()
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = Settings.TOMBSTONE_PLANT_ID
	recipe.plant_name = &"VSGravestone"
	recipe.plant_scene = TombstoneScene
	recipe.cool_time = Settings.TOMBSTONE_COOL_TIME
	recipe.sun_cost = Settings.TOMBSTONE_SUN_COST
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	recipe.card_face_anim = &"VSGravestone_idle"
	recipe.card_face_fallback_plant = PlantIds.SUN_FLOWER
	if not _tombstone_kit.install(recipe):
		Log.error("僵尸卡模组：产脑光墓碑注册失败（id 撞车或配方不合法）")
		_tombstone_kit = null
		return
	## 换上「跟僵尸同一套落位资格」的种植条件：我是僵尸关里全场格子都带
	## 「禁种」标记（红线关的植物禁放），默认条件下墓碑卡一格都放不下去
	_tombstone_condition = TombstoneCondition.new()
	Global.character_registry.set_runtime_plant_condition(
		Settings.TOMBSTONE_PLANT_ID, _tombstone_condition)


## 卸载：摘卡 → 撤种植条件 → 清注册表 → 撤解锁（选卡页没登记过，无需撤）
func uninstall() -> void:
	if _tombstone_kit != null:
		_tombstone_kit.uninstall()
		_tombstone_kit = null
	if _tombstone_condition != null:
		Global.character_registry.clear_runtime_plant_condition(Settings.TOMBSTONE_PLANT_ID)
		_tombstone_condition = null


## 全局存档重读完：解锁会被存档覆盖，补一次
func on_session_reloaded() -> void:
	if _tombstone_kit != null:
		_tombstone_kit.unlock()


## 每局接线：按关卡类型选装（两类之外的关卡不装任何东西）
func install_to_main_game(main_game: MainGameManager) -> void:
	if main_game == null or main_game.game_para == null:
		return
	if main_game.game_para.is_zombie_mode:
		## 「我是僵尸」：发僵尸卡 + 全套 PVZ2 外观（原样）
		var wiring = ZombieCardWiring.new()
		wiring.name = "ZombieCardWiring"
		main_game.add_child(wiring)
		wiring.setup(main_game)
	elif main_game.game_para.game_mode == MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle:
		## 「玩家对战」：只装右上的反向僵尸卡槽（脑光 / 脑子阳光不装 —— 场上没有脑子）
		var pvp_wiring = ZombieCardPvpWiring.new()
		pvp_wiring.name = "ZombieCardPvpWiring"
		main_game.add_child(pvp_wiring)
		pvp_wiring.setup(main_game)
