extends "res://src/core/damage/damage_modifier.gd"
## 调试模组：植物无敌（伤害修饰器）
##
## 拦住所有落在**植物**身上的伤害，只放行两类「本意就是要它死」的来源：
##   · `E_DamageCause.Death` —— 铲子 / 死亡消失（`HpComponent.hp_loss_to_death()`）
##   · `E_DamageCause.Script` —— 关卡脚本的一次性强杀
## 不放行的话，开了无敌就铲不掉植物、关卡脚本也清不了场。
##
## **生命周期**：由 `debug_window_entries.gd` 的「植物无敌」开关注册 / 注销。
## ⚠️ `DamageSystem` 切关会 `clear_modifiers()`，所以窗口定时器每次刷新都会再调一次
## `register_modifier()`（它自身幂等：已在列表里就直接返回），这样切关后开关仍然有效。
##
## 与 `DamageModifierComponent` 的区别：这里要的是「全场所有植物」，不能逐株去挂组件。

## 放行的伤害来源
const ALLOWED_CAUSES := [
	ConstDamage.E_DamageCause.Death,
	ConstDamage.E_DamageCause.Script,
]


func modify(info: DamageInfo) -> bool:
	if not (info.target is Plant000Base):
		return true
	return info.cause in ALLOWED_CAUSES
