extends BulletLinear000Base
class_name Bullet002PeaSnow

## 冰冻减速时长（游戏秒）：原版口径 `ApplyChill(false)` = 1000 tick @100 Hz = **10 秒**
## （见 `../PvZ-Portable-main/src/Lawn/Zombie.cpp` 的 `ApplyChill()`）
@export var time_be_decelerated :float = 10.0

## 攻击一次
func attack_once(enemy:Character000Base):
	super(enemy)
	# 僵王没有防具，减速不看防具；普通僵尸身上若有一件"免疫减速"的防具（原版：还举着
	# 二类防具）就不吃减速 —— 具体由哪件防具免疫，是防具组件自己回答的（ArmorComponent.is_immune_slow）。
	if enemy is ZB000Base:
		enemy.be_ice_decelerate(time_be_decelerated)
	elif enemy is Zombie000Base and not enemy.is_slow_immune:
		enemy.be_ice_decelerate(time_be_decelerated)


