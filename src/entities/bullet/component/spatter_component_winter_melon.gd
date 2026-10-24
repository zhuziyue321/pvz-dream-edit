extends SpatterComponent
class_name SpatterComponentWinterMelon

## 冰冻减速时长（游戏秒）：原版口径 10 秒，由持有它的冰瓜子弹下发（见 `Bullet015WinterMelon`）
var time_be_decelerated :float = 10.0


func attack_enemy(enemy:Character000Base, damage_per_enemy:int):
	## owner（= 所属子弹）作伤害载体，与基类 SpatterComponent.attack_enemy 一致
	enemy.be_attacked_bullet(damage_per_enemy,ConstDamage.E_DamageMode.Penetration, true, false, owner)
	## 溅射与直击走同一条减速判据（见 `Bullet015WinterMelon._apply_decelerate`）：
	## 还举着二类防具的僵尸不吃减速；伤害包先结算，所以本发把门打掉时仍会上减速
	if enemy is ZB000Base:
		enemy.be_ice_decelerate(time_be_decelerated)
	elif enemy is Zombie000Base and not enemy.is_slow_immune:
		enemy.be_ice_decelerate(time_be_decelerated)
