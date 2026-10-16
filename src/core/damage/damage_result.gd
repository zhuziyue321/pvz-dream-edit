extends RefCounted
class_name DamageResult
## 一次伤害的**结算结果**（纯数据）。
##
## 为什么要返回结果：以前 `hp_loss()` 只回一个 `bool`（是否死亡），调用方想知道
## 「这次到底掉了多少血」只能自己在调用前后各读一次 `get_all_hp()` ——
## 联机同步、反伤、统计都要这个数，与其每个调用点各算一遍，不如管线统一算好给出来。
##
## 没生效时（`is_applied == false`）看 `cancel_reason` 就知道为什么：
## 是目标没了，还是被免疫类修饰器挡下来了。

## 是否真的结算了（false = 本次伤害被取消，一滴血都没掉）
var is_applied: bool = false
## 取消原因（见 `ConstDamage.E_CancelReason`；`is_applied` 为 true 时恒为 None）
var cancel_reason: ConstDamage.E_CancelReason = ConstDamage.E_CancelReason.None
## 结算前的总血量（三类血之和；已经死了的角色再被打，这里是 0）
var hp_before: int = 0
## 结算后的总血量
var hp_after: int = 0
## 本次实际掉的总血量（含防具。注意：不等于 `amount`，防具溢出/固定伤害都会让它对不上）
var hp_loss: int = 0
## 本次结算后目标是否已进入死亡（由血量组件的死亡信号驱动，见 `HpComponent`）
var is_lethal: bool = false
## 系统真正施加了的通用效果名列表（见 `ConstDamage.EFFECT_*`）
##
## 只看 `is_applied` 分不清"掉了血"和"只上了个减速"，这里给出明细：
## 联机对账 / 统计 / 调试都靠它。系统**不认**的特殊效果不在这里（那是受击方消费的）。
var applied_effects: Array[StringName] = []

## 工厂：一次完全没生效的结果
static func canceled(reason: ConstDamage.E_CancelReason) -> DamageResult:
	var result := DamageResult.new()
	result.is_applied = false
	result.cancel_reason = reason
	return result


## 工厂：一次生效的结果（血量差由 `DamageSystem` 填）
static func applied(hp_before_value: int, hp_after_value: int, is_lethal_value: bool) -> DamageResult:
	var result := DamageResult.new()
	result.is_applied = true
	result.cancel_reason = ConstDamage.E_CancelReason.None
	result.hp_before = hp_before_value
	result.hp_after = hp_after_value
	result.hp_loss = hp_before_value - hp_after_value
	result.is_lethal = is_lethal_value
	return result
