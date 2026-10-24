extends "res://src/mods/mod_base.gd"
## 模组「生态版」：把**原版已有的数值**改成同人口径（不改玩法，不加内容）
##
## ★ 为什么是模组：仓库的目标是复刻原版，原版数值是多少就该是多少。
##   「豌豆射手便宜一点 / 寒冰菇伤害高一点 / 向日葵照着光多产一点」都是同人调整，
##   所以做成模组：关掉 = 不装载 = 数值与行为回到原版，本体里不留一句分支。
##
## ★ 与另外几个模组的区别：手套 / 锤子 / 水盆是「加东西」，本模组是「改数」——
##   它不加植物、不加卡、不加玩法，只把原版那些数挪一挪。
##
## ★ 分层（改一条只动对应的那一层）：
##   `eco_settings.gd`         —— 数值表：**新值 + 原版值**成对放，改数只改这里
##   `eco_plant_patcher.gd`    —— 改注册表 / 子弹（装一次，全局生效）：阳光、仙人掌穿透
##   `eco_wiring.gd`           —— 改植物实例（每局接一次）：光照、寒冰菇伤害、机枪连发、
##                                卷心菜索敌行、吸金磁吸铁器、向日葵按光照产光
##   `eco_mod.gd`（本文件）     —— 入口：装 / 卸 + 每局接线 + 模组页面上的清单
##
## ★ 本体为此留的通用口子（都不是为生态版开的，默认行为零变化）：
##   `CharacterRegistry.set_runtime_plant_stat()` / `BulletRegistry.set_runtime_bullet_stat()`
##   / `PlantCell.light_level` / `PlantCellManager.get_plant_cell_cross()`
##   / `DetectComponent.add_extra_ray_area()` / `AttackComponentBulletBase.burst_extra_num`
##   / `MagnetComponent.max_iron`
##
## 装载时机与写法见 [模组机制](../../docs/参考存档/模组机制.md)：
##   开关与设置都在 `user://<用户名>/mod_config.ini` 的 `[eco]` 段，默认关闭。

## `user://` 下脚本的 class_name 不注册成全局类（实测 Godot 4.6.2），
## 上级目录与同目录的文件一律 preload 成常量再引用（见 `mods_builtin/README.md`）
const ModBase := preload("res://src/mods/mod_base.gd")
const Settings := preload("eco_settings.gd")
const EcoPlantPatcher := preload("eco_plant_patcher.gd")
const EcoWiring := preload("eco_wiring.gd")


func get_mod_id() -> StringName:
	return ModIds.ECO


func get_mod_name() -> String:
	return "生态版"


func get_mod_description() -> String:
	return "只调整原版已有的数值（阳光 / 伤害 / 连发 / 索敌 / 光照），不加任何玩法；关掉就回到原版"


#region 生命周期
## 启动时装一次：改注册表与子弹那几条（全局生效）
func install() -> void:
	EcoPlantPatcher.apply()


## 关掉模组：数值还原成原版，表里一个字都不留
func uninstall() -> void:
	EcoPlantPatcher.restore()


## 每局装一次：接格子的种植信号（照明范围随种植变化）+ 改植物实例上的组件
func install_to_main_game(_main_game: MainGameManager) -> void:
	EcoWiring.install(_main_game)
#endregion


func get_mod_categories() -> Array[StringName]:
	return [ModCategory.OVERRIDE_RULE]


## 本模组**依赖**「紫卡直接种植」：打开生态版时会把它一并打开（框架递归补开，带环保护，
## 见 `ModBase.get_mod_dependencies()` 与 [模组机制](../../docs/参考存档/模组机制.md) §2.3）。
##
## ★ 为什么依赖：生态版唯一改到的**紫卡**是吸金磁（50 → 150；它自己是紫卡、基座是磁力菇），
##   而紫卡直种的价 = 「紫卡自己的价格 + 基座植物的阳光 + 惩罚阳光」，两项都照注册表**现读**
##   （`purple_direct_plant_rule.gd` 的 `get_standard_sun_cost()` / `get_base_plant_sun_cost()`）。
##   两个模组是**同一套经济口径**：开着生态版，就该按生态版的价直种紫卡；
##   缺了紫卡直种，150 阳光的吸金磁依旧只能先种磁力菇，这条调价在新的经济里没有出口。
func get_mod_dependencies() -> Array[StringName]:
	return [ModIds.PURPLE_DIRECT_PLANT]


## 模组页面右侧：一行一条，写清「原版多少 → 现在多少」
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"作用：把原版已有的数值换成下面这份同人口径，玩法一个都没加 —— 关掉本模组立刻回到原版"))
	box.add_child(ModBase.create_detail_label(
		"生效时机：阳光 / 子弹改完当场生效；植物实例那几条（连发、索敌、光照）在**下一局**生效"))

	for line in _lines():
		box.add_child(ModBase.create_detail_label("· " + line))
	return box


## 页面上的清单（与 `eco_settings.gd` 是一对：那边存数，这边写给人看）
func _lines() -> Array[String]:
	return [
		"豌豆射手阳光 %d → %d" % [Settings.VANILLA_SUN_PEA_SHOOTER, Settings.SUN_PEA_SHOOTER],
		"咖啡豆阳光 %d → %d" % [Settings.VANILLA_SUN_COFFEE_BEAN, Settings.SUN_COFFEE_BEAN],
		"吸金磁阳光 %d → %d" % [Settings.VANILLA_SUN_GOLD_MAGNET, Settings.SUN_GOLD_MAGNET],
		"格子新增光照等级：火炬树桩给十字四格各 +%d，路灯花给周围八格各 +%d"
			% [Settings.LIGHT_TORCH_WOOD, Settings.LIGHT_PLANTERN],
		"向日葵每级光照多产 %d 阳光（原版恒产 %d）"
			% [Settings.SUN_PER_LIGHT_LEVEL, Settings.VANILLA_SUN_FLOWER_VALUE],
		"寒冰菇伤害 %d → %d" % [Settings.VANILLA_ICE_SHROOM_DAMAGE, Settings.ICE_SHROOM_DAMAGE],
		"机枪射手一次 %d 发 → %d 发"
			% [Settings.VANILLA_GATLING_BURST_NUM, Settings.GATLING_BURST_NUM],
		"仙人掌子弹最多打 %d 个僵尸（原版 %d 个，命中即销毁）"
			% [Settings.CACTUS_PIERCE_NUM, Settings.VANILLA_CACTUS_PIERCE_NUM],
		"卷心菜投手索敌 %d 行（原版只打本行）" % Settings.CABBAGE_LANE_NUM,
		"吸金磁能吸铁器，一次最多 %d 件（原版吸金磁不吸铁器）" % Settings.GOLD_MAGNET_IRON_NUM,
	]
