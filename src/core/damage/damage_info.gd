extends RefCounted
class_name DamageInfo
## 一次伤害的**完整描述**（纯数据，不含任何结算逻辑）= 一个「效果包」。
##
## 一次伤害从"想打"到"生效"要走三段，本类只负责把第一段的信息带全：
##
##   ① 伤害方写包        ② 受击方加工包          ③ 系统应用包
##   ├ 子弹 / 炸弹 / 僵尸 ──> 目标.process_damage() ──> DamageSystem 按 effects 逐项施加
##   └ 往 effects 里塞效果   （特殊效果在这里翻译）    （通用效果在这里生效）
##
## **包里只有一样东西：一张字典 `effects`**（key 见 `ConstDamage.EFFECT_*` 与 `ConstDamage.KEY_*`）：
##   · 发起方往里塞"我要施加什么"（伤害 / 减速 / 冰冻 / 地刺标记…）；
##   · 受击方在加工阶段**消费**系统不认的那些"特殊效果"（`EFFECT_CALTROP` 一类）；
##   · 系统在应用阶段**只处理自己认得的"通用效果"**（`EFFECT_DAMAGE` / `EFFECT_SLOW` …）。
##
## 为什么要塞进字典而不是用一撮具名字段：
## 加具名字段每多一种效果就要动一次本类 + 全仓所有调用点，而且「这个角色会不会被
## 冰冻」这种**只对一种角色有意义**的东西一进本类，本类就开始认识具体角色了。
## 字典把"效果名"变成数据，加一种效果 = 加一个常量 + 加一个处理函数，**谁都不用改**。
##
## ── 具名字段 = 代理访问器 ──────────────────────────────────────────────
##
## `amount` / `mode` / `cause` / `target` / `attacker` / `source` / `is_instant_kill`
## / `is_drop_on_death` / `is_drop_2` / `trigger_sfx` / `is_armor_absorbed` / `final_amount`
## **全是 `effects` 的代理** —— 读写的其实是 `effects[ConstDamage.KEY_*]`
## （伤害值特殊一点，走 `EFFECT_DAMAGE`，见下面 `amount` 的注释）。
##
## 为什么不全删掉具名字段、只留一张字典：全仓几十处 `info.amount = x` / `info.attacker = self`
## / `be_attacked_bullet(20, ...)` 不该为了重构一起改。做成代理后**字典是唯一真源**：
## 既不会出现两处各存一份而漂移，也让"一次伤害到底带哪些信息"在下面一眼看全。
##
## 字典里的 key 分两档，靠前缀区分：
##   · `ConstDamage.EFFECT_*` —— **效果**（系统 / 受击方会去消费它）；
##   · `ConstDamage.KEY_*`（值带 `meta_` 前缀）—— **元信息**：谁打谁、怎么算这类上下文，
##     没人消费它，只是随包走一段路（见 `ConstDamage` 的「元信息 key」段）。
##
## 用法（推荐走静态工厂 + 链式补效果）：
## [codeblock]
## var info := DamageInfo.create(zombie, 20, ConstDamage.E_DamageMode.Real, ConstDamage.E_DamageCause.Bullet)
## info.attacker = plant                                   ## 谁打的
## info.source = self                                      ## 伤害载体（那一发子弹）
## info.set_effect(ConstDamage.EFFECT_SLOW, {time = 5.0, factor = 0.5})   ## 附带减速
## DamageSystem.apply(info)
##
## ## 想"必死"就开秒杀，别再把伤害值抬到血量上限（见 is_instant_kill 的注释）
## var kill := DamageInfo.create(zombie, 0, ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Crush)
## kill.is_instant_kill = true
## [/codeblock]
##
## ⚠️ 类型说明：`target` / `attacker` / `source` 一律声明为 `Node` 而不是具体角色类型。
## 一是避免与角色基类形成 class_name 循环引用，二是它们都可能在本类存活期间被 `queue_free()`
## （典型的：子弹命中后自己删自己），声明成具体类型反而让人误以为一定有效。
## 用之前一律先 `is_instance_valid()`。

## **包本体**：本次伤害的全部内容，key 分两档：
##   · `ConstDamage.EFFECT_*` —— 效果（系统 / 受击方会去消费它）；
##   · `ConstDamage.KEY_*` —— 元信息（谁打谁、怎么算，只是随包走一段）。
##
## 系统只消费自己认得的通用效果，其余的是发起方写给受击方的"便条"，
## 由 `Character000Base.process_damage()` 在加工阶段翻译。**允许包里一个通用效果都没有**
## （纯控制包 / 纯元信息包），那时系统照样跑完整条链路，只是不掉血。
var effects: Dictionary = {}


#region 元信息：以下具名字段全是 `effects` 的**代理访问器**
##
## 具名字段存在的唯一理由：不必为了"把信息收进字典"就去改全仓几十处调用点。
## `info.mode = x` 与 `info.effects[ConstDamage.KEY_MODE] = x` **完全等价**，
## 但前者读起来是"一次伤害的模式"，后者读起来是"一次字典写入" —— 留着前者更好读。
##
## ⚠️ 两项纪律：
##   · **不要在包里手写 `meta_*` 字符串**，一律走 `ConstDamage.KEY_*` 常量或本段具名字段；
##   · 同一项**不要一会儿用具名字段、一会儿用 `effects[...]`**，挑一种写到底。

## 伤害值：**代理**到 `effects[ConstDamage.EFFECT_DAMAGE]`，老代码 `info.amount` 照用不改。
##
## 它走的是**效果**那条 key 而不是元信息：伤害本身就是系统认领的一种通用效果
## （见 `DamageSystem._apply_effect_damage()`），只是因为最高频才留了具名字段。
##
## 负数一律按 0 处理（见 `DamageSystem._apply_effect_damage()`），不会倒扣血。
var amount: int:
	get:
		return effects.get(ConstDamage.EFFECT_DAMAGE, 0)
	set(damage_amount):
		effects[ConstDamage.EFFECT_DAMAGE] = damage_amount

## 是否秒杀：**不看伤害值、不看伤害模式，直接把目标清空到死**。
##
## 为什么不用「把 `amount` 抬到血量上限、再走 `E_DamageMode.Real`」那一招（旧写法）：
##   · 它仍然要过一遍防具的吸收规则 —— 碰上减伤 / 固定吸收的防具（模组里那几种矿石桶）
##     就打不死了；写的人本意是"必死"，结果却取决于防具表配了什么；
##   · `Real` 模式只跳过**二类**防具，一类防具照样吃伤害，语义对不上"无视一切"；
##   · 伤害值要在 ② 加工阶段读一次血量，读到的是**加工那一刻**的血，
##     到 ③ 真正结算时可能已经变了（残血流失、另一发子弹先落地）。
##
## 秒杀把这个意图变成一个独立开关：结算层直接清空（含**全部防具**与本体），**必然致死**。
## 它**不是绕过管线** —— 加工阶段、修饰器链、死亡流程、亡语、掉落、伤害事件照常走一遍，
## 只是不再拿 `amount` 当"要扣多少"来用。
##
## ⚠️ 修饰器与受击方的 `process_damage()` 都可以把它改回 false —— 那是"免疫秒杀"的标准写法。
##
## ⚠️ 秒杀仍然需要一个伤害效果（`create()` 一定会带上），`amount` 写 0 也无妨：
## 系统靠 `EFFECT_DAMAGE` 认领这次结算，靠 `is_instant_kill` 决定怎么扣。
var is_instant_kill: bool:
	get:
		return effects.get(ConstDamage.KEY_INSTANT_KILL, false)
	set(is_instant_kill_value):
		effects[ConstDamage.KEY_INSTANT_KILL] = is_instant_kill_value

## 伤害模式：决定三层血怎么分（见 `ConstDamage.E_DamageMode`）
##
## 它是**伤害效果的分配方式**而不是独立效果，所以仍是元信息里的一员
## （改它不需要走 `set_effect()`，也不会被系统当成效果去施加）。
## 「秒杀」不是模式（它压根不看伤害值），是上面的 `is_instant_kill`。
var mode: ConstDamage.E_DamageMode:
	get:
		return effects.get(ConstDamage.KEY_MODE, ConstDamage.E_DamageMode.Norm)
	set(damage_mode):
		effects[ConstDamage.KEY_MODE] = damage_mode

## 伤害来源：只做语义标记，不参与结算分支（见 `ConstDamage.E_DamageCause`）
var cause: ConstDamage.E_DamageCause:
	get:
		return effects.get(ConstDamage.KEY_CAUSE, ConstDamage.E_DamageCause.Unknown)
	set(damage_cause):
		effects[ConstDamage.KEY_CAUSE] = damage_cause

## 受击者（**必填**，为空时 `DamageSystem.apply()` 直接返回未生效的结果）
var target: Node:
	get:
		return effects.get(ConstDamage.KEY_TARGET)
	set(target_node):
		effects[ConstDamage.KEY_TARGET] = target_node

## 发起者：僵尸啃植物时是那只僵尸，植物打僵尸时是那棵植物；天降 / 脚本伤害为 null
var attacker: Node:
	get:
		return effects.get(ConstDamage.KEY_ATTACKER)
	set(attacker_node):
		effects[ConstDamage.KEY_ATTACKER] = attacker_node

## 伤害载体：子弹节点 / 炸弹组件等，主要用于排查与联机对齐"哪一发打的"
var source: Node:
	get:
		return effects.get(ConstDamage.KEY_SOURCE)
	set(source_node):
		effects[ConstDamage.KEY_SOURCE] = source_node

## 死亡时是否有掉落（透传给 `HpComponent` 的 signal_hp_loss）
var is_drop_on_death: bool:
	get:
		return effects.get(ConstDamage.KEY_DROP_ON_DEATH, true)
	set(is_drop_on_death_value):
		effects[ConstDamage.KEY_DROP_ON_DEATH] = is_drop_on_death_value

## 是否播放受击音效（残血流失一类的"非受击"掉血要关掉）
var trigger_sfx: bool:
	get:
		return effects.get(ConstDamage.KEY_SFX, true)
	set(is_trigger_sfx):
		effects[ConstDamage.KEY_SFX] = is_trigger_sfx

## 掉落的额外条件（透传给 `HpComponent`，两个条件都满足才掉）
var is_drop_2: bool:
	get:
		return effects.get(ConstDamage.KEY_DROP_2, true)
	set(is_drop_2_value):
		effects[ConstDamage.KEY_DROP_2] = is_drop_2_value

## 结算后的实际伤害值（加工阶段改过之后的值），由 `DamageSystem` 回填
var final_amount: int:
	get:
		return effects.get(ConstDamage.KEY_FINAL_AMOUNT, 0)
	set(final_amount_value):
		effects[ConstDamage.KEY_FINAL_AMOUNT] = final_amount_value

## 本次伤害有没有被防具吸收掉血（**②-a 由 `ArmorComponent.process_damage()` 置位**）。
##
## 吸收在 ②-a 就地扣血并把 `info.amount` 削成"走完防具剩下的"；削到 0 时 ③ 光看 `amount`
## 分不清「压根没伤害」还是「全被防具吃了」—— 后者仍要当作"打到了"走完 ③ 末端
## （防具的掉血信号 / 音效 / 血条刷新都在 `hp_loss()` 里）。
var is_armor_absorbed: bool:
	get:
		return effects.get(ConstDamage.KEY_ARMOR_ABSORBED, false)
	set(is_armor_absorbed_value):
		effects[ConstDamage.KEY_ARMOR_ABSORBED] = is_armor_absorbed_value
#endregion


## 工厂：创建一次伤害（默认带一个伤害效果）。必填项走参数，其余用 `with_*` 链式补。
static func create(
	target_node: Node,
	damage_amount: int,
	damage_mode: ConstDamage.E_DamageMode = ConstDamage.E_DamageMode.Norm,
	damage_cause: ConstDamage.E_DamageCause = ConstDamage.E_DamageCause.Unknown
) -> DamageInfo:
	var info := DamageInfo.new()
	info.target = target_node
	info.amount = damage_amount
	info.mode = damage_mode
	info.cause = damage_cause
	return info


#region 效果读写
## 塞一个效果（链式）。已存在则覆盖。
## [param effect_name] 效果名（见 `ConstDamage.EFFECT_*`）
## [param value] 效果参数，格式由该效果的处理函数约定（见常量注释）
func set_effect(effect_name: StringName, value: Variant) -> DamageInfo:
	effects[effect_name] = value
	return self


## 取一个效果的参数；没有返回 `default`（**不会**自动往字典里塞默认值）
func get_effect(effect_name: StringName, default_value: Variant = null) -> Variant:
	return effects.get(effect_name, default_value)


## 包里有没有这个效果（**不看值**：值为 0 / false 也算有）
func has_effect(effect_name: StringName) -> bool:
	return effects.has(effect_name)


## 移除一个效果（链式）。
##
## 受击方在加工阶段**否决**一个效果的标准写法：巨人被地刺扎时 `remove_effect(EFFECT_CALTROP)`，
## 比「把值改成 null 再让处理函数判空」干净 —— 移除后 `has_effect()` 直接是 false。
func remove_effect(effect_name: StringName) -> DamageInfo:
	effects.erase(effect_name)
	return self
#endregion


## 指定发起者（链式）
func with_attacker(attacker_node: Node) -> DamageInfo:
	attacker = attacker_node
	return self


## 指定伤害载体（链式）
func with_source(source_node: Node) -> DamageInfo:
	source = source_node
	return self


## 一次性指定掉落相关开关（链式）
func with_drop(is_drop_on_death_value: bool, is_drop_2_value: bool = true) -> DamageInfo:
	is_drop_on_death = is_drop_on_death_value
	is_drop_2 = is_drop_2_value
	return self


## 指定是否播受击音效（链式）
func with_sfx(is_trigger_sfx: bool) -> DamageInfo:
	trigger_sfx = is_trigger_sfx
	return self


## 指定是否秒杀（链式；默认开 —— `with_instant_kill()` 就是要秒杀）
func with_instant_kill(is_instant_kill_value: bool = true) -> DamageInfo:
	is_instant_kill = is_instant_kill_value
	return self


## 目标是否还有效（结算前 / 结算后都可能被 free，用之前判一下）
func is_target_valid() -> bool:
	return is_instance_valid(target)


## 调试用：一行说清这次伤害（含包里的全部**效果**，元信息不重复打印 —— 它已经在前面的字段里了）
func to_debug_string() -> String:
	var effect_names: Array[StringName] = []
	for key: StringName in effects.keys():
		if not ConstDamage.META_KEYS.has(key):
			effect_names.append(key)
	return "DamageInfo(amount=%d, final=%d, kill=%s, mode=%d, cause=%d, effects=%s, target=%s, attacker=%s)" % [
		amount, final_amount, str(is_instant_kill), mode, cause, str(effect_names),
		str(target.name) if is_target_valid() else "null",
		str(attacker.name) if is_instance_valid(attacker) else "null",
	]
