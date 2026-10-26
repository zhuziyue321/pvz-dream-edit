extends DamageModifierComponent
class_name ComponentImmuneMower
## 免疫「小推车」这种特殊伤害（2026-10-26）。
##
## 小推车 / 屋顶清洁车碾僵尸时，不再直接改血：`Zombie000Base.be_mowered_run()` 把它
## 包成一次 **`E_DamageCause.Mower` + `is_instant_kill`** 的伤害走 `DamageSystem`。
## 于是「压不动」这件事就变成了**免疫一类伤害**，挂在修饰器链上（②-c）：
## 本组件把打在自己身上的这类包整包取消 ⇒ 车体开过去**一滴血不掉、也不播压扁演出**。
##
## 为什么用 `DamageModifierComponent` 而不是在角色脚本里写 `if`：
##   · 免疫是可插拔的**通用规则**，谁挂谁生效（硬约束 §1-1 的组件化口径）；
##   · 角色脚本那边只剩一句"包成什么伤害"，不必认识"哪些僵尸压不动"。
##
## 挂法：角色根节点下加一个 Node2D，脚本指本文件（节点名随意，建议 `ImmuneMowerComponent`）。
## 当前挂着它的：僵王（`zb_base.tscn`）、对战里的靶子僵尸 / 产脑光墓碑（`mods_builtin/player_battle` 两个场景）。
##
## ⚠️ `modify()` 是**全场每一次伤害**都会进（修饰器是全局注册的），所以必须先按
## `info.target` 认领自己的包 —— 少了这一步，场上只要有一只免疫单位，
## 别处的同款伤害也会跟着被取消。

func modify(info: DamageInfo) -> bool:
	## 不是打在自己身上的包，不管
	if info.target != owner_character:
		return true
	## 小推车 / 屋顶清洁车：整包取消（血不掉、演出不播）
	if info.cause == ConstDamage.E_DamageCause.Mower:
		return false
	return true
