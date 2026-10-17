extends ArmorComponent
## 「更多的防具」模组：铜桶那一层防具 —— 铁桶那层 + **随时间氧化的易伤**
##
## ★ 为什么铜桶要有自己的防具脚本：要的是「**只有防具在吃伤害时**才放大」。
##   伤害是沿着防具链往下走的（② 加工阶段逐层调 `ArmorComponent.process_damage()`）：
##   每层吃多少、往下传多少由防具自己回答，本体最后拿到的永远是「防具没吃掉的那部分」。所以放大只能发生在
##   **本层自己吃的那一步** —— 正是 `ArmorComponent.absorb_damage()`，也就是防具组件的地盘
##   （[防具](../../../../docs/参考存档/防具.md) §4：防具存在时的效果由防具组件自己定义，
##   本体与僵尸子类都不需要认识它）。
##
## 把「随时间获得易伤（仅对防具有效）」拆开：
##   · **随时间**：本组件按 `_process` 累计在场时间，氧化进度 0 → 1，倍率一路涨上去；
##   · **易伤**：本层实际扣血 = 打到本层的伤害 × 倍率；
##   · **仅对防具有效**：放大出来的伤害**只啃防具**，往下传的永远是**原始伤害**
##     没被吃完的那部分 —— 否则防具一破，多出来的伤害会顺着溢到本体上，
##     「仅对防具有效」就不成立（连磁力菇吸个桶都要啃掉僵尸本体一大截血：
##     `break_armor()` 走的同样是这条伤害管线）。
##
## 三条不放大（放大只会改坏原版那张分配表）：
##   · 固定伤害（保龄球 / 锤子）：口径就是「打多少扣多少」；
##   · 原样下传（穿透打到二类防具）：传下去的量必须是原始伤害；
##   · 本层已经破了 / 没有伤害：原样放行。
##
## 「贴图变成铜锈色」不在这里 —— 那是外观，归宿主（`zombie_copper_bucket.gd`）
## 按 `get_oxidation_progress()` 去染。
##
## 装配：由 `zombie_copper_bucket.gd` 用 `add_armor(..., 本脚本)` 挂上去。

## 从出场到完全氧化需要多少秒
const OXIDIZE_FULL_TIME := 30.0
## 完全氧化后的易伤倍率（1.0 = 不多吃伤害）
const MAX_DAMAGE_RATE := 2.0


## 易伤倍率：本层防具实际承受的伤害 = 打到本层的伤害 × 本倍率
var damage_rate := 1.0
## 已经在场多久（秒）
var oxidized_time := 0.0


func _process(delta: float) -> void:
	## 防具没了就不用再氧化：破了以后易伤对谁都不生效
	if not is_alive():
		return
	oxidized_time += delta
	damage_rate = lerpf(1.0, MAX_DAMAGE_RATE, get_oxidation_progress())


## 氧化进度（0 = 刚出场，1 = 完全氧化）；宿主拿它把桶染成铜锈色
func get_oxidation_progress() -> float:
	if OXIDIZE_FULL_TIME <= 0.0:
		return 1.0
	return clampf(oxidized_time / OXIDIZE_FULL_TIME, 0.0, 1.0)


## 本层吃伤害：只放大**本层吃掉的那部分**，往下传的量按原始伤害算（见类注释）
func absorb_damage(mode: ConstDamage.E_DamageMode, remain: int) -> int:
	if damage_rate <= 1.0 or remain <= 0 or not is_alive():
		return super.absorb_damage(mode, remain)
	var rule := get_absorb_rule(mode)
	## 只有「按剩余伤害扣、没扣完的往下溢」这一类才放大
	if rule.absorb_type != ConstArmor.E_ArmorAbsorb.Remain or rule.pass_type != ConstArmor.E_ArmorPass.Overflow:
		return super.absorb_damage(mode, remain)
	var hp_before := curr_hp
	## 放大后交给父类去扣（父类只认传进来的那个值）
	var passed := super.absorb_damage(mode, maxi(roundi(remain * damage_rate), remain))
	var absorbed := hp_before - curr_hp
	return mini(passed, maxi(remain - mini(absorbed, remain), 0))
