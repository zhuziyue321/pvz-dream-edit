extends ArmorComponent
## 「更多的防具」模组：下界合金桶那一层防具 —— **50% 减伤**
##
## ★ 为什么减伤长在防具上：与铜桶的「只放大防具」同源 —— 伤害沿防具链走
## （`HpComponentZombie.hp_loss()`），本体拿到的永远是「防具没吃掉的那部分」；
## 减伤也只能在防具自己吃的那一步（`ArmorComponent.absorb_damage()`）实现，
## 也就是防具组件的地盘（[防具](../../../../docs/参考存档/防具.md) §4）。
##
## 减伤的语义：打到本层防具的伤害先打个折再交给父类去扣血；
## 「本层实际掉多少血」是折扣后的口径 —— 把它换算回原始伤害再决定往下传多少
## （**只减本层吃掉的那部分**，不破「防具没了就裸奔」的口径）。
##
## 三条不打折（与铜桶同源，保持原版那张分配表）：
##   · 固定伤害（保龄球 / 锤子）：口径就是「打多少扣多少」；
##   · 原样下传（穿透的二类防具）：传下去的量必须是原始伤害；
##   · 本层已经破了 / 没有伤害：原样放行。
##
## 装配：由 `zombie_netherite_bucket.gd`（或钻石桶变身后）用 `add_armor(..., 本脚本)` 挂上去。
##
## 关联：[防具](../../../../docs/参考存档/防具.md) ｜ [模组机制 §6.3](../../../../docs/参考存档/模组机制.md) ｜ ArmorComponent

## 减伤比例：1.0 = 不减，0.0 = 全免疫；下界合金桶 0.5（半价）
const DAMAGE_REDUCTION := 0.5


## 本层吃伤害：先按 `1 - DAMAGE_REDUCTION` 的比例把伤害折小再交给父类去扣，
## 然后**按本层实际掉血量（折扣后）换算回原始伤害**，作为往下传的口径
func absorb_damage(mode: ConstDamage.E_DamageMode, remain: int) -> int:
	if DAMAGE_REDUCTION <= 0.0 or remain <= 0 or not is_alive():
		return super.absorb_damage(mode, remain)
	var rule := get_absorb_rule(mode)
	## 只有「按剩余伤害扣、没扣完的往下溢」这一类才打折 —— 其它模式照旧
	if rule.absorb_type != ConstArmor.E_ArmorAbsorb.Remain or rule.pass_type != ConstArmor.E_ArmorPass.Overflow:
		return super.absorb_damage(mode, remain)
	## 折小的伤害至少为 1：极端情况下（remain=1, 0.5 减伤）父类还要按 1 扣一次
	var halved := maxi(roundi(remain * (1.0 - DAMAGE_REDUCTION)), 1)
	var hp_before := curr_hp
	super.absorb_damage(mode, halved)
	var absorbed := hp_before - curr_hp
	## 折扣后扣 1 点血 = 挡住了 `1 / (1 - 减伤率)` 点原始伤害；这里就是 `×2`
	return maxi(remain - roundi(absorbed / (1.0 - DAMAGE_REDUCTION)), 0)
