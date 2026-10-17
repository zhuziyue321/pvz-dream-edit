extends SpatterComponent
class_name SpatterComponentWinterMelon

var time_be_decelerated :float = 3.0


func attack_enemy(enemy:Character000Base, damage_per_enemy:int):
	## owner（= 所属子弹）作伤害载体，与基类 SpatterComponent.attack_enemy 一致
	enemy.be_attacked_bullet(damage_per_enemy,ConstDamage.E_DamageMode.Penetration, true, false, owner)
	enemy.be_ice_decelerate(time_be_decelerated)
