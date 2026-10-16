extends RefCounted
## 模组「原版平衡」里**改注册表 / 改子弹**的那几条（一次改写，全局生效）
##
## 与 `balance_wiring.gd` 的分工：
##   本文件管「数据层」—— 植物阳光（`CharacterRegistry` 的数值覆盖表）与
##   子弹属性（`BulletRegistry` 的覆盖表，造子弹时当场写），装一次就够；
##   `balance_wiring.gd` 管「每局实例」—— 植物种下之后才有的组件（寒冰菇爆炸伤害、
##   机枪连发、卷心菜检测区、吸金磁的吸铁组件、向日葵按光照产光）。
##
## ★ 两条表都是本体的**通用覆盖口子**（本体不认识本模组，见它们的注释），
##   撤得掉：`restore()` 把覆盖清掉，数值回到原版。

const Settings := preload("balance_settings.gd")

## 阳光：走 `CharacterRegistry.set_runtime_plant_stat()`
## （`PlantInfoData.PLANT_INFO` 是 const 表，Godot 4.4 起常量字典**只读**，改不动）
const SUN_OVERRIDES: Array[Dictionary] = [
	{"id": PlantIds.PEA_SHOOTER_SINGLE, "value": Settings.SUN_PEA_SHOOTER},
	{"id": PlantIds.COFFEE_BEAN, "value": Settings.SUN_COFFEE_BEAN},
	{"id": PlantIds.GOLD_MAGNET, "value": Settings.SUN_GOLD_MAGNET},
]


## 按设置把数值覆盖写进注册表（幂等：每次都照常量重写一遍）
static func apply() -> void:
	var registry := Global.character_registry
	for override in SUN_OVERRIDES:
		registry.set_runtime_plant_stat(
			override["id"], CharacterRegistry.PlantInfoAttribute.SunCost, override["value"])
	## 仙人掌子弹：原版命中一次就销毁（`max_attack_num = 1`），改成能穿 3 个
	Global.bullet_registry.set_runtime_bullet_stat(
		BulletIds.CACTUS, &"max_attack_num", Settings.CACTUS_PIERCE_NUM)
	## 卡模板上的阳光是 `rebuild()` 时照注册表重读的（见 `all_cards.gd`），不重排卡面还是老数值
	AllCards.rebuild()


## 撤掉全部覆盖：数值回到原版，表里一个字都不留
static func restore() -> void:
	var registry := Global.character_registry
	for override in SUN_OVERRIDES:
		registry.clear_runtime_plant_stats(override["id"])
	Global.bullet_registry.clear_runtime_bullet_stats(BulletIds.CACTUS)
	AllCards.rebuild()
