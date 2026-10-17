extends RefCounted
## 明日方舟模组的**战斗规则共享契约**（谁都要读、自己谁也不依赖，故单独一份防止 `preload` 成环，
## 照 `hammer_settings.gd` / `glove_settings.gd` 的拆法）：
##   · 伤害类型标记（物理 / 法术）—— 发起方写进 `DamageInfo.effects` 的一张 meta 便签
##   · 防御力 / 法术抗性数值表（按植物 / 僵尸类型）+ 单实例覆盖
##   · 两条减免公式（物理扣防御力点、法术按法抗百分比）
##
## 入口 `arknights_mod.gd`（伤害修饰器）与将来的干员 / 技能脚本都从这里取常量、读数值，
## 引用方各自 `const ArknightsStats := preload("arknights_stats.gd")` 即可，互不成环。
##
## ⚠️ 这里**不写** `class_name`：`user://` 下的脚本不注册全局类（实测 Godot 4.6.2，
## 见 [模组机制](../../docs/参考存档/模组机制.md) §四 的规矩清单）。

#region 伤害类型（物理 / 法术）
##
## 伤害类型是**随包的元信息便签**：不新增系统效果、不进结算分支，只是让模组的伤害修饰器
## 在 ②-c 读它、决定用哪套减免公式。key 带 `meta_` 前缀，与 `ConstDamage.KEY_*` 的
## 元信息口径一致（没人消费、只随包走一段路；写法照 `ModBase.modify_damage()` 文档里的示例）。
##
## **未标记 = 物理**：原版的子弹 / 啃食 / 爆炸 / 碾压一概不写这个便签，于是天然全部走
## 「扣防御力」那一套 —— 模组因此不需要改动本体任何一处调用点。

## 伤害类型便签在 `DamageInfo.effects` 里的 key
const KEY_DMG_TYPE := &"meta_dmg_type"
## 物理伤害：减免量 = 目标防御力（点，减法）
const TYPE_PHYSICAL := &"physical"
## 法术伤害：减免量 = 目标法术抗性（百分比，乘法）
const TYPE_SPELL := &"spell"
#endregion


#region 防御力 / 法术抗性
##
## **数值填在这里**：按角色类型给默认值；没填 / 删掉 = 0（= 没有这条属性，伤害一点不减）。
## 单个实例要临时的数（干员升级、技能 buff 一类）用 `set_instance_defense()` /
## `set_instance_spell_resist()` 覆盖，优先级高于本表。
##
## 填法（照抄一行，id 取 `PlantIds` / `ZombieIds` 常量表）：
##   PlantIds.PLANT_NAME: {"defense": 10, "spell_resist": 20.0},
##   ZombieIds.ZOMBIE_NAME: {"defense": 5, "spell_resist": 0.0},
## · defense：物理伤害固定少这么多点（int；不会把伤害减成负数）
## · spell_resist：法术伤害减免百分比（float，0~100；20.0 = 少挨两成）

## 每种植物的默认防御力 / 法术抗性（key = `PlantIds` 常量；留空 = 默认 0）
const PLANT_STATS: Dictionary = {
	## 填法：PlantIds.PLANT_NAME: {"defense": 0, "spell_resist": 0.0},
}
## 每种僵尸的默认防御力 / 法术抗性（key = `ZombieIds` 常量；留空 = 默认 0）
const ZOMBIE_STATS: Dictionary = {
	## 填法：ZombieIds.ZOMBIE_NAME: {"defense": 0, "spell_resist": 0.0},
}
## 没配数值时的默认防御力（点）
const DEFAULT_DEFENSE := 0
## 没配数值时的默认法术抗性（百分比）
const DEFAULT_SPELL_RESIST := 0.0

## 单实例覆盖写在角色本体的 `mod_custom_effects` 容器里 —— 那是本体给模组留的通用口子
## （`Character000Base.mod_custom_effects`：角色只负责持有，不消费；键名带模组前缀，
## 避免与别的模组互相覆盖，见该字段的约定注释）
const KEY_INSTANCE_DEFENSE := &"arknights_defense"
const KEY_INSTANCE_SPELL_RESIST := &"arknights_spell_resist"
#endregion


#region 伤害类型标记（发起方用）

## 给一次攻击标记伤害类型：在 `apply_damage()` / `DamageSystem.apply()` **之前**调
## [param info] 本次伤害的包；[param damage_type] `TYPE_PHYSICAL` / `TYPE_SPELL`
## [return] 传回去的 `info`（方便链式）
static func mark_attack(info: DamageInfo, damage_type: StringName) -> DamageInfo:
	if info != null:
		info.set_effect(KEY_DMG_TYPE, damage_type)
	return info


## 这次伤害是不是法术（**未标记按物理**，与原版伤害的口径一致）
static func is_spell_attack(info: DamageInfo) -> bool:
	if info == null:
		return false
	return info.get_effect(KEY_DMG_TYPE, TYPE_PHYSICAL) == TYPE_SPELL
#endregion


#region 防御力 / 法术抗性的读与写

## 是不是可挂战斗数值的角色（植物 / 僵尸）；别的节点（子弹、特效…）一律按默认值
static func is_character(target: Node) -> bool:
	return target != null and is_instance_valid(target) and target is Character000Base


## 目标防御力（点）：**单实例覆盖 > 类型表 > 默认值**
static func get_defense(target: Node) -> int:
	if not is_character(target):
		return DEFAULT_DEFENSE
	var char := target as Character000Base
	var override: Variant = char.mod_custom_effects.get(KEY_INSTANCE_DEFENSE)
	if override != null:
		return maxi(0, int(override))
	return maxi(0, int(_stat_of(char).get("defense", DEFAULT_DEFENSE)))


## 目标法术抗性（百分比，夹在 0~100）：**单实例覆盖 > 类型表 > 默认值**
static func get_spell_resist(target: Node) -> float:
	if not is_character(target):
		return DEFAULT_SPELL_RESIST
	var char := target as Character000Base
	var override: Variant = char.mod_custom_effects.get(KEY_INSTANCE_SPELL_RESIST)
	if override != null:
		return clampf(float(override), 0.0, 100.0)
	return clampf(float(_stat_of(char).get("spell_resist", DEFAULT_SPELL_RESIST)), 0.0, 100.0)


## 单实例覆盖防御力（临时 buff / 干员自己的数值）；传 null 取消覆盖
static func set_instance_defense(target: Node, defense_value) -> void:
	if not is_character(target):
		return
	var char := target as Character000Base
	if defense_value == null:
		char.mod_custom_effects.erase(KEY_INSTANCE_DEFENSE)
		return
	char.mod_custom_effects[KEY_INSTANCE_DEFENSE] = maxi(0, int(defense_value))


## 单实例覆盖法术抗性（0~100）；传 null 取消覆盖
static func set_instance_spell_resist(target: Node, spell_resist_value) -> void:
	if not is_character(target):
		return
	var char := target as Character000Base
	if spell_resist_value == null:
		char.mod_custom_effects.erase(KEY_INSTANCE_SPELL_RESIST)
		return
	char.mod_custom_effects[KEY_INSTANCE_SPELL_RESIST] = clampf(float(spell_resist_value), 0.0, 100.0)


## 清掉单实例覆盖（效果结束时调；类型表里的默认值不受影响）
static func clear_instance_stats(target: Node) -> void:
	if not is_character(target):
		return
	var char := target as Character000Base
	char.mod_custom_effects.erase(KEY_INSTANCE_DEFENSE)
	char.mod_custom_effects.erase(KEY_INSTANCE_SPELL_RESIST)
#endregion


#region 减免公式（模组伤害修饰器用；单独拿出来便于单测与复用）

## 物理减免：少挨「防御力」点，减到 0 为止（不会倒扣）
static func reduce_physical(amount: int, defense: int) -> int:
	return maxi(0, int(amount) - maxi(0, int(defense)))


## 法术减免：按百分比少挨（四舍五入；抗性夹 0~100，100 = 免疫，0 = 不减）
static func reduce_spell(amount: int, spell_resist_percent: float) -> int:
	var resist := clampf(float(spell_resist_percent), 0.0, 100.0)
	return maxi(0, int(round(float(amount) * (100.0 - resist) / 100.0)))
#endregion


## 该角色在类型表里的那一行（没有配过 = 空字典，读出来全是默认值）
##
## ⚠️ `plant_type` / `zombie_type` 是各自子类的字段、不在 `Character000Base` 上，
##    这里走 `Object.get()` 动态取（静态写 `char.zombie_type` 在 Godot 4.6 下是编译错误）
static func _stat_of(char: Character000Base) -> Dictionary:
	var table := PLANT_STATS
	var type_id: Variant = char.get("plant_type")
	if char is Zombie000Base:
		table = ZOMBIE_STATS
		type_id = char.get("zombie_type")
	var stat: Variant = table.get(type_id)
	return stat as Dictionary if stat != null else {}
