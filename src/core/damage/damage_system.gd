extends Node
## 伤害管线：**全场唯一**的伤害入口（autoload 单例 `DamageSystem`）。
##
## ⚠️ 本文件**刻意不写 `class_name`**：脚本一旦声明 class_name，全局标识符 `DamageSystem`
## 就会被**类**占用（Godot 会报 "Class X hides an autoload singleton"），
## 于是 `DamageSystem.apply(...)` 会被当成"调用静态方法"而编译失败。
## 不声明 class_name 时，`DamageSystem` 指向 autoload 实例，调用实例方法才成立
## （与 `EventBus.push_event()` 的写法一致）。
## 需要类型标注的场合请用基类 `Node`，不要为了写类型把它变回 class_name。
##
## ── 三段式：一次伤害 = 一个「效果包」走完三段 ──────────────────────────────
##
##   ① 伤害方写包        ② 受击方加工包           ③ 系统应用包
##   ├ 子弹 / 炸弹 / 僵尸 ──> ②-a 防具链（外层先说话，就地吸收本层伤害） ──> 本类按 effects 逐项施加
##   └ DamageInfo.effects     ②-b 目标.process_damage()   （通用效果在这里生效）
##                            ②-c 修饰器链
##
## **包的本体是一张字典**（`DamageInfo.effects`，key 见 `ConstDamage.EFFECT_*`）：
##
##   · **通用效果**（伤害 / 减速 / 冰冻 / 黄油）由本类在 ③ 认领并施加，
##     所有角色一视同仁。加一种 = `ConstDamage` 加个常量 + `_register_effect_handlers()`
##     登记一个处理函数，**发起方与受击方一行都不用改**。
##   · **特殊效果**（如 `EFFECT_CALTROP`）本类**不认也不碰** —— 那是发起方写给
##     受击方看的便条，由受击方在 ② 自己消费、自己翻译成后果
##     （洗冰车 / 投石车翻译成"秒杀"、巨人翻译成"无视"、其余不认识就当没看见）。
##     ② 里翻译便条的有**两方**，按"谁在外面谁先说话"的顺序：
##     **先**受击方身上的每一层防具（`ArmorComponent.process_damage()`，外层 → 内层），
##     **再**受击方本体（`Character000Base.process_damage()`）。两层都能改包或整包取消。
##
##     ⚠️ 防具链那一步**顺手把防具自己的血扣了**（吸收不再单独放在 ③）：每层把
##     `info.amount` 改写成"走完本层还剩多少"，所以到 ③ 时 `info.amount` 已经是"剩下的"。
##
## 为什么特殊效果不让系统认：一旦系统要处理"地刺扎"，它就得认识"洗冰车",
## 硬约束 §1-8 明令禁止本体认识具体玩法。**谁的规则谁自己翻译**，系统只管通用那部分。
##
## 本类刻意**不做**这几件事，职责边界说清楚免得以后往里塞：
##   · 不判敌我 —— 那是 `BulletCampConfig.is_enemy()` 与 `CanAttackStatusComponent` 的活，
##     发生在"决定打不打得到"的阶段，进了管线就说明**已经决定要打了**；
##   · 不算伤害数值 —— 数值由发起方给（子弹的 `attack_value`、炸弹的 `bomb_value`…），
##     管线只负责在结算前给**防具链、受击方与修饰器**各一次改写机会；
##   · 不处理死亡表现 —— 死亡由血量组件的 `signal_hp_component_death` 驱动，管线只回一个
##     `DamageResult` 告诉发起方"这次打死了没有"。
##
## 联机：客户端的伤害由主机随快照下发（见 `mods_builtin/netplay/netplay_state_sync.gd`），
## 因此 push 出去的 `DAMAGE_APPLIED` 事件是**观测用**的，订阅方不要在里面再改血量。

## 是否广播伤害事件（调试 / 性能排查时可以关掉）
@export var is_broadcast_event: bool = true

## 已注册的修饰器（**按优先级降序**维护，注册时排一次即可）
var _modifiers: Array[DamageModifier] = []
## 通用效果的处理函数表：效果名（`ConstDamage.EFFECT_*`）→ `Callable`
var _effect_handlers: Dictionary = {}
## 嵌套深度：修饰器 / 加工里误调 `apply()` 时的保护（见 `_run_modifiers`）
var _nested_depth: int = 0
## 嵌套超限时只报一次，避免每帧刷屏
var _is_warned_nested := false


func _ready() -> void:
	_register_effect_handlers()


## 结算一次伤害。**全仓唯一的伤害入口**。
## [param info] 效果包（见 `DamageInfo`；`target` 为空时返回一个未生效的结果，不报错）
## [return] 结算结果（见 `DamageResult`）
func apply(info: DamageInfo) -> DamageResult:
	if info == null or not is_instance_valid(info.target):
		return DamageResult.canceled(ConstDamage.E_CancelReason.NoTarget)

	var character := info.target as Character000Base
	if character == null or not is_instance_valid(character.hp_component):
		## 走到这里说明调用方把伤害打到了一个没有血量组件的角色上（或是组件还没 ready）。
		## 静默放过的后果是"这个技能打人没伤害"，比报错难查得多，所以这里必须喊一声。
		Log.error("伤害系统：目标 %s 没有可用的血量组件，本次伤害丢弃。%s"
			% [str(info.target.name), info.to_debug_string()])
		return DamageResult.canceled(ConstDamage.E_CancelReason.NoHpComponent)

	var hp_component := character.hp_component
	var was_death := hp_component.is_death
	var hp_before: int = hp_component.get_all_hp()

	## ②-a 防具链加工包：先问身上每一层防具（二类 → 一类 → 更内层）。
	## 防具是"挨打最外层"，所以它比本体先拿到包；顺序由这里保证，不靠角色子类自觉。
	## **吸收也在这一步完成**：每层扣自己的血并把 `info.amount` 改成"剩下的"，③ 只打本体。
	##
	## ⚠️ 取消要带上血量快照：更外层的防具可能**已经扣了血**，按"没生效"返回会把掉血丢掉。
	if not character.process_damage_armors(info):
		return _canceled_after_processing(ConstDamage.E_CancelReason.Armor, hp_component, hp_before)

	## ②-b 受击方加工包：特殊效果在这里被翻译成具体后果
	if not character.process_damage(info):
		return _canceled_after_processing(ConstDamage.E_CancelReason.Target, hp_component, hp_before)

	## ②-c 修饰器链加工：挂组件就能改伤害 / 免疫，不用动任何角色脚本
	if not _run_modifiers(info):
		return _canceled_after_processing(ConstDamage.E_CancelReason.Modifier, hp_component, hp_before)

	## ③ 系统应用包：只处理自己认得的通用效果
	var applied_effects := _apply_effects(info, character)
	if applied_effects.is_empty():
		## 包里一个通用效果都没有 —— 要么 key 拼错（静默失效最难查），
		## 要么是个纯控制包但受击方已经死了 / 伤害被加工成 0。
		if info.has_effect(ConstDamage.EFFECT_DAMAGE) and info.amount <= 0:
			return _canceled_after_processing(ConstDamage.E_CancelReason.ZeroAmount, hp_component, hp_before)
		return _canceled_after_processing(ConstDamage.E_CancelReason.NoEffect, hp_component, hp_before)

	var hp_after: int = hp_component.get_all_hp()
	var result := DamageResult.applied(hp_before, hp_after, hp_component.is_death and not was_death)
	result.applied_effects = applied_effects

	## 先判有没有订阅方：`push_event()` 每次都要查签名表逐项校验 payload、还要广播
	## `event_pushed`，然后才发现没人听；而伤害是高频事件（每发子弹 / 每次啃食都走一次）。
	## `DAMAGE_APPLIED` 当前 0 个订阅方 —— 跳过它等价于原来"发下去但没人接"，
	## 唯一差别是开 `enable_history` 时看不到这条（调试时才需要，可临时订一下事件）。
	if is_broadcast_event and EventBus.has_signal(ConstEventName.DAMAGE_APPLIED):
		EventBus.push_event(ConstEventName.DAMAGE_APPLIED, [info, result])

	return result


## 加工 / 结算阶段的取消
##
## 与 `DamageResult.canceled()` 的差别：这里**带上血量快照**。防具的吸收与取消都发生在 ②-a
## （见 `ArmorComponent.process_damage()`），更外层的防具可能已经扣了血 —— 只报"没生效"
## 会让调用方看到的 `hp_loss` 变成 0，与真实掉血不符（见 `DamageResult.canceled_with_hp()`）。
func _canceled_after_processing(
	reason: ConstDamage.E_CancelReason, hp_component: HpComponent, hp_before: int
) -> DamageResult:
	return DamageResult.canceled_with_hp(reason, hp_before, hp_component.get_all_hp())


#region 修饰器注册
## 注册一个修饰器（注册后按 priority 降序重排一次）
func register_modifier(modifier: DamageModifier) -> void:
	if modifier == null or _modifiers.has(modifier):
		return
	_modifiers.append(modifier)
	_sort_modifiers()


## 注销一个修饰器（修饰器所属角色被 free 前请调，否则列表里会留一个失效引用）
func unregister_modifier(modifier: DamageModifier) -> void:
	if modifier == null:
		return
	_modifiers.erase(modifier)


## 清空所有修饰器（切关 / 重开一局时用，避免跨关残留）
func clear_modifiers() -> void:
	_modifiers.clear()


## 当前注册的修饰器数量（调试用）
func get_modifier_count() -> int:
	return _modifiers.size()


## 当前登记的通用效果数量（调试用：确认某效果有没有接上）
func get_effect_handler_count() -> int:
	return _effect_handlers.size()
#endregion


#region 内部：通用效果的登记与施加
## 登记所有通用效果的处理函数。
##
## **加一种通用效果就改这里 + `ConstDamage` 各加一行**，其余代码不用动。
## 处理函数签名：`func(info: DamageInfo, target: Character000Base) -> bool`
## 返回 true = 这个效果真的施加了（会写进 `DamageResult.applied_effects`）。
func _register_effect_handlers() -> void:
	_effect_handlers[ConstDamage.EFFECT_DAMAGE] = _apply_effect_damage
	_effect_handlers[ConstDamage.EFFECT_FREEZE] = _apply_effect_freeze
	_effect_handlers[ConstDamage.EFFECT_SLOW] = _apply_effect_slow
	_effect_handlers[ConstDamage.EFFECT_BUTTER] = _apply_effect_butter


## 效果的应用顺序：伤害先结（打死了就不再上控制），控制类随后。
##
## 字典的遍历顺序不保证稳定，而"先掉血还是先减速"是有区别的 —— 这里显式定序。
const EFFECT_APPLY_ORDER: Array[StringName] = [
	ConstDamage.EFFECT_DAMAGE,
	ConstDamage.EFFECT_FREEZE,
	ConstDamage.EFFECT_SLOW,
	ConstDamage.EFFECT_BUTTER,
]


## ③ 按固定顺序把包里**系统认得**的通用效果逐个施加。
## [return] 真正施加了的效果名列表（一个都没有 = 这次没生效）
func _apply_effects(info: DamageInfo, target: Character000Base) -> Array[StringName]:
	var applied: Array[StringName] = []
	for effect_name: StringName in EFFECT_APPLY_ORDER:
		if not info.has_effect(effect_name):
			continue
		## 已经死了就不再上控制类效果：给死人挂减速 / 冰块的后果是
		## 计时器回调里去改一个已经 queue_free 的节点
		if effect_name != ConstDamage.EFFECT_DAMAGE and target.is_death:
			continue
		var handler: Callable = _effect_handlers.get(effect_name)
		if handler.is_valid() and handler.call(info, target):
			applied.append(effect_name)
	return applied


## 【通用效果】伤害：交给血量组件做三层血分配。
## 负数一律按 0 处理：伤害值算错（溢出 / 配置填负）时不该倒扣血。
##
## `amount` 为 0 仍要放行的情况有两种，别把它们当成"没生效"：
##   · **秒杀**（`info.is_instant_kill`）—— 伤害值不参与"该扣多少"，血量组件走"直接清空"那条路；
##   · **被防具吃光**（`info.is_armor_absorbed`）—— 吸收已在 ②-a 就地扣了防具的血，
##     这一趟 ③ 是为了把防具的掉血信号 / 受击音效 / 血条刷新（都在 `hp_loss()` 末端）走完。
func _apply_effect_damage(info: DamageInfo, target: Character000Base) -> bool:
	if info.amount <= 0 and not info.is_instant_kill and not info.is_armor_absorbed:
		return false
	info.final_amount = info.amount
	## 真正的结算在角色侧：子类想改结算行为就重写 `take_damage()`
	target.take_damage(info)
	return true


## 【通用效果】完全冰冻：值为 Dictionary { time:float, after_slow:float }
func _apply_effect_freeze(info: DamageInfo, target: Character000Base) -> bool:
	var param: Variant = info.get_effect(ConstDamage.EFFECT_FREEZE)
	if param is not Dictionary:
		Log.error("伤害系统：freeze 效果的参数应是 Dictionary{time,after_slow}，收到 %s。%s"
			% [str(param), info.to_debug_string()])
		return false
	var freeze_time: float = param.get("time", 0.0)
	var after_slow: float = param.get("after_slow", 0.0)
	if freeze_time <= 0.0:
		return false
	## 第三个参数 damage 显式传 0（只冻不打）：本系统里伤害是包里独立的 `EFFECT_DAMAGE`，
	## 再让它顺手打一次就成了双重结算。
	target.be_ice_freeze(freeze_time, after_slow, 0)
	return true


## 【通用效果】减速：值为 Dictionary { time:float, factor:float }
func _apply_effect_slow(info: DamageInfo, target: Character000Base) -> bool:
	var param: Variant = info.get_effect(ConstDamage.EFFECT_SLOW)
	if param is not Dictionary:
		Log.error("伤害系统：slow 效果的参数应是 Dictionary{time,factor}，收到 %s。%s"
			% [str(param), info.to_debug_string()])
		return false
	var slow_time: float = param.get("time", 0.0)
	var slow_factor: float = param.get("factor", 0.5)
	if slow_time <= 0.0:
		return false
	target.be_slow(slow_time, slow_factor)
	return true


## 【通用效果】黄油定身：值为 float（秒）。只有僵尸认（见 `Zombie000Base.be_butter`）
func _apply_effect_butter(info: DamageInfo, target: Character000Base) -> bool:
	var butter_time: float = info.get_effect(ConstDamage.EFFECT_BUTTER, 0.0)
	if butter_time <= 0.0:
		return false
	## 植物没有黄油糊脸这回事，静默跳过（不是错误，别刷日志）
	if target is Zombie000Base:
		(target as Zombie000Base).be_butter(butter_time)
		return true
	return false
#endregion


#region 内部
## 跑一遍修饰器链：返回 false 表示这次伤害被取消
##
## 重入保护：修饰器里再调 `apply()` 是**设计错误**（会造成无限递归），
## 这里不让它崩，改成跳过修饰器直接结算 —— 至少不会栈溢出。
func _run_modifiers(info: DamageInfo) -> bool:
	if _nested_depth > 0:
		if not _is_warned_nested:
			_is_warned_nested = true
			Log.error("伤害系统：检测到嵌套结算（修饰器里又调了 apply），本次跳过修饰器。"
				+ "修饰器只应该改 DamageInfo，不要自己触发伤害。")
		return true

	_nested_depth += 1
	var is_continue := true
	for modifier in _modifiers:
		if modifier == null or not modifier.is_active:
			continue
		if not modifier.modify(info):
			is_continue = false
			break
	_nested_depth -= 1
	return is_continue


## 按优先级降序排（注册 / 注销时调用，热路径上不排）
func _sort_modifiers() -> void:
	_modifiers.sort_custom(func(a: DamageModifier, b: DamageModifier): return a.priority > b.priority)
#endregion
