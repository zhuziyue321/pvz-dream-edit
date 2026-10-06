extends BulletLinear000Base
class_name Bullet002PeaSnow

@export var time_be_decelerated :float = 3.0

## 攻击一次
func attack_once(enemy:Character000Base):
	super(enemy)
	# 僵王没有二类防具，减速不看防具；普通僵尸仍要先破二类防具才吃减速。
	if enemy is ZB000Base:
		enemy.be_ice_decelerate(time_be_decelerated)
	elif enemy is Zombie000Base and enemy.hp_component.curr_hp_armor2 <= 0:
		enemy.be_ice_decelerate(time_be_decelerated)


