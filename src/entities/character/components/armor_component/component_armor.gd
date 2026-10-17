extends ComponentNormBase
class_name ArmorComponent
## 防具组件：一层「先于本体、按类别顺序被扣」的额外血量（防具的组件化重写版）
##
## 为什么改成组件（重写前的样子：`HpComponentZombie` 上的 `max_hp_armor1/2` 两个固定槽位
## + `HpStageChangeComponent` 上的 `body_change_armor1/2` 两个换皮数组）：
##   · 一个角色**最多一层一类 + 一层二类**，"同一个僵尸戴两个路障"只能去血量表里再开一列；
##   · 防具自带的特殊效果（铁门挡减速、气球浮空、报纸破防暴走…）无处安放，只能散在
##     各个僵尸子类里 `if zombie_type == ...`，而游戏本体不该认识任何具体僵尸（硬约束 §1-8）；
##   · 防具的「血量 / 外观 / 掉落 / 音效」四份状态分居两个组件，改一处要两边对表。
## 改成组件之后：
##   · 想戴几层就挂几个节点，**同类可以叠加**（`absorb_priority` 决定同类中谁先挨打）；
##   · 血量、破损外观、掉落、受击音效全在本组件里，宿主不复制一份（K-01）；
##   · **防具存在时的特殊效果由防具组件自己定义** —— 重写 `process_damage()`（② 加工阶段：
##     既**吸收本层的伤害**，也决定这张包要不要继续往下走）、`on_armor_equip()` /
##     `on_armor_break()` 与 `is_immune_slow()` 这一类查询钩子即可，本体与僵尸子类都不需要认识它。
##
## **给一个角色加防具（两步，不需要改任何管理器）**
##   1. 角色根节点下加一个 Node2D，挂本脚本（需要特殊效果就挂本脚本的子类，
##      见 `component_armor_balloon.gd` / `component_armor_newspaper.gd`）；
##   2. 在检查器里填 `armor_type` / `armor_class` / `max_hp` / `body_change` / `sfx_be_attack`。
## `HpComponentZombie.component_ready()` 会**自动收集角色根目录下的所有本类节点**并排序，
## 不需要注册表、不需要宿主登记；把节点删掉角色照常运行，只是少一层防具。
##
## 伤害怎么流过防具：一次伤害在 **② 加工阶段**沿 `armor_list`（二类 → 一类，
## 同类按 `absorb_priority` 从大到小）逐层调用本组件的 `process_damage()` —— 每层**就地**
## 扣掉自己该吃的血、并把 `info.amount` 改写成"走完本层还剩多少"交给下一层
## （见 `HpComponentZombie.process_damage_armors()`），所以一次遍历就把整条防具链结算完。
## 六种 `ConstDamage.E_DamageMode` 的行为与重写前**逐条一致**
## （新增模式记得同步这里与 `HpComponentZombie.get_body_damage()`）。


#region 场景配置
@export_group("防具")
## 防具类型：只做标识与查找（`Zombie000Base.get_armor()`），不参与结算
@export var armor_type: ConstArmor.E_ArmorType = ConstArmor.E_ArmorType.Null
## 防具类别：二类在外、先挨打
@export var armor_class: ConstArmor.E_ArmorClass = ConstArmor.E_ArmorClass.Armor1
## 同类防具之间的挨打顺序：数值越大越外层、越先挨打（叠加同类防具时用它排出先后）
@export var absorb_priority: int = 0
## 本层防具的血量上限（0 = 这不是一件防具）
@export var max_hp: int = 0
## 防具受击音效
@export var sfx_be_attack := SoundManagerClass.TypeBeAttackSFX.Null
## 铁器节点：磁力菇可以把它吸走；非铁器防具留空
@export var iron_node: IronNode

@export_group("防具破损外观")
## 血量临界值数组，从满血到破损顺序；留空时按 `max_hp` 自动切成三段（2/3、1/3、0）
@export var boundary_value_hp: Array[int]
## 每到一个临界值要做的外观改变（换纹理 / 显隐精灵 / 掉落），与上面数组**一一对应**
@export var body_change: Array[ResourceBodyChange]
#endregion


#region 状态
## 当前血量。setter 里只做「外观阶段推进 + 破损事件」，伤害的分配顺序由血量组件决定
var curr_hp: int = 0:
	set(value):
		value = max(value, 0)
		var was_alive := is_alive()
		curr_hp = value
		_update_hp_stage()
		## 从"还活着"变成"破了"才发一次（初始化时 max_hp == 0 不会误发）
		if was_alive and curr_hp == 0:
			is_broken = true
			signal_armor_death.emit()
			on_armor_break()

## 是否已经被打掉
var is_broken := false
## 当前破损阶段（-1 = 未受损），联机快照下发的是这个（见 NetplayStateSync）
var curr_hp_stage := -1
## 本次结算中本层是否真的吃了伤害（血量组件在结算末尾按它补发掉血信号与音效）
var is_hit_this_time := false
#endregion


#region 信号
## 本层防具掉血（curr_hp:本层剩余血量 / is_drop:本次是否掉落）
signal signal_armor_hp_loss(curr_hp: int, is_drop: bool)
## 本层防具被打掉（掉落 / 破防表现挂在这里）
signal signal_armor_death
#endregion


## 一次伤害的吸收规则（吃多少 + 往下传多少）
class AbsorbRule:
	var absorb_type: ConstArmor.E_ArmorAbsorb = ConstArmor.E_ArmorAbsorb.Remain
	## `E_ArmorAbsorb.Fixed` 时的固定扣血值
	var absorb_value: int = 0
	var pass_type: ConstArmor.E_ArmorPass = ConstArmor.E_ArmorPass.Overflow
	## `E_ArmorPass.Fixed` 时往下传的固定值
	var pass_value: int = 0


func component_ready() -> void:
	super()
	if max_hp <= 0:
		return
	if boundary_value_hp.is_empty():
		@warning_ignore("integer_division")
		var two_third := max_hp * 2 / 3 - 1
		@warning_ignore("integer_division")
		var one_third := max_hp * 1 / 3 - 1
		boundary_value_hp = [two_third, one_third, 0]
	curr_hp = max_hp


#region 对外接口
## 本层防具是否还在（血没被打光、且确实是一件防具）
func is_alive() -> bool:
	return max_hp > 0 and curr_hp > 0


## 开始一次伤害结算：清掉上一次的"挨打"标记
## （由血量组件在 ② 加工阶段遍历防具链**之前**调用，见 `process_damage_armors()`）
func begin_damage_settlement() -> void:
	is_hit_this_time = false


## 补发掉血信号与受击音效（由血量组件在**结算末尾**调用 —— 那时「本体是否已死」才定下来，
## `is_drop` 要拿这个终态算，在遍历途中发会算错）
func notify_hp_loss(is_drop: bool, is_trigger_sfx: bool) -> void:
	signal_armor_hp_loss.emit(curr_hp, is_drop)
	if sfx_be_attack != SoundManagerClass.TypeBeAttackSFX.Null and is_trigger_sfx:
		SoundManager.play_be_attack_SFX(sfx_be_attack)


## 小推车碾压这类"不扣血、直接把防具演到破损"的场合：走完所有破损阶段（含掉落）
func force_break_appearance() -> void:
	if not is_alive():
		return
	_update_hp_stage(0)


## 联机：照主机下发的阶段号补齐破损外观（不扣血，只演表现）
## [param packed_stage] 编码后的阶段号（「阶段 + 1」；0 = 主机那边没有这一层）
func apply_stage_from_snapshot(packed_stage: int) -> void:
	if boundary_value_hp.is_empty() or packed_stage <= 0:
		return
	var target := mini(packed_stage - 1, boundary_value_hp.size() - 1)
	if curr_hp_stage >= target:
		return
	_update_hp_stage(boundary_value_hp[target])


## 小僵尸大麻烦：防具血量与临界值减半
func update_mini_zombie_hp() -> void:
	if max_hp == 0:
		return
	max_hp /= 2
	for i in boundary_value_hp.size():
		boundary_value_hp[i] /= 2
	curr_hp = max_hp
#endregion


#region 伤害结算
## 本层防具在某种伤害模式下怎么吃伤害（**子类重写这里就能做出"免疫某种伤害"的防具**）
##
## 默认表 = 重写前 `HpComponentZombie.hp_loss()` 六个分支的原样翻译：
##   Norm         溢出扣（二类 → 一类 → 本体）
##   Penetration  二类照扣但不消耗伤害（啃食 / 爆炸同时打到防具与本体）；一类溢出扣
##   Real         跳过二类（地刺 / 寒冰菇 / 残血流失）；一类溢出扣
##   BowlingFront 二类 400、一类 800，都不往下传
##   BowlingSide  二类 1800 并继续传 1800；一类 800，不往下传
##   Hammer       无视二类；一类 900，不往下传
##
## ⚠️ 那几个固定数值统一在 `ConstDamage.BOWLING_*` / `HAMMER_ARMOR1`（本体侧同源，
## 见 `HpComponentZombie.get_body_damage()`）—— 改数值请改常量，别在这里写裸数。
func get_absorb_rule(mode: ConstDamage.E_DamageMode) -> AbsorbRule:
	var is_armor2 := armor_class == ConstArmor.E_ArmorClass.Armor2
	match mode:
		ConstDamage.E_DamageMode.Norm:
			return _rule_remain_overflow()
		ConstDamage.E_DamageMode.Penetration:
			if is_armor2:
				return _rule_remain_unchanged()
			return _rule_remain_overflow()
		ConstDamage.E_DamageMode.Real:
			if is_armor2:
				return _rule_ignore()
			return _rule_remain_overflow()
		ConstDamage.E_DamageMode.BowlingFront:
			if is_armor2:
				return _rule_fixed(ConstDamage.BOWLING_FRONT_ARMOR2, 0)
			return _rule_fixed(ConstDamage.BOWLING_FRONT_ARMOR1, 0)
		ConstDamage.E_DamageMode.BowlingSide:
			if is_armor2:
				return _rule_fixed(ConstDamage.BOWLING_SIDE_ARMOR2, ConstDamage.BOWLING_SIDE_ARMOR2)
			return _rule_fixed(ConstDamage.BOWLING_SIDE_ARMOR1, 0)
		ConstDamage.E_DamageMode.Hammer:
			if is_armor2:
				return _rule_ignore()
			return _rule_fixed(ConstDamage.HAMMER_ARMOR1, 0)
	return _rule_remain_overflow()


## 让本层防具吸收一次伤害（由本组件的 `process_damage()` 在 ② 加工阶段调用，
## **不再**由血量组件在结算层调用 —— 吸收已经并入防具自己的加工环节）
## [param mode] 本次伤害的结算模式
## [param remain] 传到本层的剩余伤害
## [return] 交给下一层（更内层防具 / 本体）的伤害
func absorb_damage(mode: ConstDamage.E_DamageMode, remain: int) -> int:
	var rule := get_absorb_rule(mode)
	if rule.absorb_type == ConstArmor.E_ArmorAbsorb.None:
		return remain
	## 已经破了 / 没有伤害可吃：原样放行（重写前是 `if curr_hp_armorX > 0 and attack_value > 0`）
	if curr_hp <= 0 or remain <= 0:
		return remain

	var absorb_value := remain
	if rule.absorb_type == ConstArmor.E_ArmorAbsorb.Fixed:
		absorb_value = rule.absorb_value

	var hp_before := curr_hp
	curr_hp -= absorb_value
	is_hit_this_time = true
	var absorbed := hp_before - curr_hp

	match rule.pass_type:
		ConstArmor.E_ArmorPass.Unchanged:
			return remain
		ConstArmor.E_ArmorPass.Zero:
			return 0
		ConstArmor.E_ArmorPass.Fixed:
			return rule.pass_value
		_:
			return max(remain - absorbed, 0)


static func _rule_remain_overflow() -> AbsorbRule:
	var rule := AbsorbRule.new()
	rule.absorb_type = ConstArmor.E_ArmorAbsorb.Remain
	rule.pass_type = ConstArmor.E_ArmorPass.Overflow
	return rule


static func _rule_remain_unchanged() -> AbsorbRule:
	var rule := AbsorbRule.new()
	rule.absorb_type = ConstArmor.E_ArmorAbsorb.Remain
	rule.pass_type = ConstArmor.E_ArmorPass.Unchanged
	return rule


static func _rule_ignore() -> AbsorbRule:
	var rule := AbsorbRule.new()
	rule.absorb_type = ConstArmor.E_ArmorAbsorb.None
	return rule


## [param absorb_value] 本层固定扣多少 [param pass_value] 往下传多少（0 = 不传）
static func _rule_fixed(absorb_value: int, pass_value: int) -> AbsorbRule:
	var rule := AbsorbRule.new()
	rule.absorb_type = ConstArmor.E_ArmorAbsorb.Fixed
	rule.absorb_value = absorb_value
	rule.pass_type = ConstArmor.E_ArmorPass.Fixed
	rule.pass_value = pass_value
	return rule
#endregion


#region 特殊效果钩子（★「防具存在时的效果」写在这里，由防具组件自己定义）
## 【伤害系统 ② 加工包】**防具先于本体**拿到这次伤害的包：**既吸收本层伤害，也可以改它 / 整个取消**。
##
## 什么时候被调：`DamageSystem.apply()` 在调 `Character000Base.process_damage()` **之前**，
## 按 `HpComponentZombie.armor_list` 的顺序（二类 → 一类，同类按 `absorb_priority`）逐层调一遍
## —— **谁在外面谁先说话**。顺序由管线保证，不需要角色子类记得先调 `super()`。
##
## 本函数一次做两件事（都在防具自己的地盘上）：
##   1. **吸收**：按 `get_absorb_rule(info.mode)` 扣掉本层该吃的血（走 `absorb_damage()`），
##      并把 `info.amount` 改写成"走完本层还剩多少"交给下一层 —— 所以一次遍历就把整条防具链
##      结算完；③ 结算层只拿剩下的 `info.amount` 打本体（见 `HpComponentZombie.hp_loss()`）。
##   2. **加工包**：子类可以改这次伤害的 `amount` / `mode` / `effects`；`return false` 则
##      **取消整包**（回 `E_CancelReason.Armor`，本体与更内层不再挨打）。
##
## 重写时想同时保留吸收：改成 `info.amount = ...; return super(info)`（见探针
## `test/scenarios/probe_armor_component.gd` 的示例）。
##
## ⚠️ 顺序提醒：本函数排在**本体 `process_damage()` 与修饰器链之前**。所以「本层已经扣掉的血」
## 不会因为内层取消 / 修饰器回退而退还 —— 要"整包取消连防具也不掉血"，请让**最外层**的防具
## `return false`（"谁在外面谁先说话"）。
##
## ⚠️ 秒杀（`info.is_instant_kill`）**不看伤害值**，吸收规则一律绕过：防具与本体由 ③ 的
## `HpComponentZombie.clear_all_hp()` 一起清空（必然致死）。
##
## 两条纪律（与 `Character000Base.process_damage()` 同一套）：
##   · **不要在这里触发新的伤害**（嵌套 `apply()`）；
##   · 表现（音效 / 动画 / 掉落）放 ③ 末端，别放这里 —— 更内层还可能取消整包，
##     动画已经切了却没最终掉血会留下视觉 bug。本层掉血信号由 `notify_hp_loss()` 统一补发。
##
## [param info] 效果包，可直接改 `amount` / `mode` / `effects`
## [return] true = 继续往下走；false = **取消整包**（本体与更内层不再挨打，回 `E_CancelReason.Armor`）
func process_damage(info: DamageInfo) -> bool:
	## 秒杀不看伤害值：吸收一律绕过（防具与本体在 ③ 由 clear_all_hp() 一起清空）
	if info.is_instant_kill:
		return true
	## 吸收本层：扣自己的血，并把"剩下的"写回包里交给下一层 / 本体
	var hp_before := curr_hp
	info.amount = absorb_damage(info.mode, info.amount)
	## 记下"这次伤害确实落在防具上了"：③ 靠它把「被防具吃光」与「压根没伤害」分开
	## （见 `DamageInfo.is_armor_absorbed`）——否则防具的掉血信号 / 音效 / 血条刷新都会漏
	if curr_hp < hp_before:
		info.is_armor_absorbed = true
	return true


## 防具**生效**时调用一次（角色 ready 之后、所有组件都已就绪，见 `Zombie000Base.ready_norm()`）
## 防具存在期间持续有效的东西（浮空、免疫…）在这里打开，对应的撤销写 `on_armor_break()`
func on_armor_equip() -> void:
	pass


## 防具**被打掉**时调用一次（在 `curr_hp` 归零的 setter 里，掉落表现已经走完）
## 破防才触发的效果（报纸暴走、气球落地…）写在这里
func on_armor_break() -> void:
	pass


## 本防具存在时宿主是否免疫减速（寒冰豌豆 / 冰冻）
##
## 默认口径 = 重写前 `bullet_pea_snow.gd` 里的 `curr_hp_armor2 <= 0`：只要还举着二类
## 防具（报纸 / 铁门 / 梯子）就不吃减速。要做"戴了就不怕冰"的特殊防具就重写这里。
func is_immune_slow() -> bool:
	return armor_class == ConstArmor.E_ArmorClass.Armor2


## 本防具存在时宿主是否免疫黄油定身
func is_immune_butter() -> bool:
	return false


## 本防具的铁器节点（磁力菇吸铁用）；非铁器防具返回 null
func get_iron_node() -> IronNode:
	return iron_node
#endregion


#region 内部逻辑
## 推进破损阶段（换纹理 / 显隐精灵 / 触发掉落）
## [param judge_hp] 用来判定的血量，默认取当前血量；小推车碾压传 0 直接走到最后一段
func _update_hp_stage(judge_hp: int = -1) -> void:
	if boundary_value_hp.is_empty():
		return
	if judge_hp < 0:
		judge_hp = curr_hp
	## 已经到最后一段就不再推进（与重写前 `update_hp_armor_stage()` 一致）
	if curr_hp_stage == boundary_value_hp.size() - 1:
		return
	for i in boundary_value_hp.size():
		if curr_hp_stage < i and judge_hp <= boundary_value_hp[i]:
			curr_hp_stage = i
			var change := body_change[i] if i < body_change.size() else null
			if change == null:
				continue
			change.update_body(self)
#endregion
