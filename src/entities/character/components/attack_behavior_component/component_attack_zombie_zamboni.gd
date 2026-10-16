extends AttackComponentBase
class_name AttackComponentZombieZamboni
## 碾压攻击（谁挂上就碾谁）：冰车 `Zombie013Zamboni` 与投石车 `Zombie023Catapult`
## 共用本组件 —— 投石车场景里的 `AttackComponent2` 就是它。
##
## ⚠️ **挂本组件的角色不要勾「地刺」位**（`CanAttackStatusComponent.can_attack_plant_status` 的 4）：
## 洗冰车 / 投石车不是把地刺压扁再等它反击，而是**被地刺主动扎爆** —— 地刺自己的
## `DetectComponent` 每 0.75 秒扎一次检测区内的敌人，包里带 `EFFECT_CALTROP` 便条，
## 由它们在 `process_damage()` 里翻译成"伤害 = 我全部血量"（见 `Plant022Caltrop._attack_once()`）。
## 勾了地刺位就会多走一次 `be_flattened_from_enemy()`：车爆了，地刺也塌了 —— 与原版不符。
## 唯一还会压到地刺的是巨人（`plant_cell.gd` 直接调，不走检测），而它自己取消了整包。

## 开始攻击
func attack_start():
	## 必须调 super()，否则基类的 signal_change_is_attack(true) 不会发出，
	## is_attack 动画状态与"攻击时受击框"都失效
	super()
	if is_instance_valid(detect_component.enemy_can_be_attacked):
		detect_component.enemy_can_be_attacked.be_flattened_from_enemy(owner)
	elif is_instance_valid(detect_component.brain):
		var brain:BrainOnZombieMode = detect_component.brain
		brain.be_flattened()

## 结束攻击
func attack_end():
	super()

## 修改速度
func owner_update_speed(_speed_product:float):
	pass
