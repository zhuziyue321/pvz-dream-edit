extends Bullet000ParabolaBase
class_name Bullet015WinterMelon


## 冰冻减速时长（游戏秒）：原版口径 `ApplyChill(false)` = 1000 tick @100 Hz = **10 秒**（冰瓜同值）
@export var time_be_decelerated :float = 10.0
@onready var spatter_component: SpatterComponentWinterMelon = $SpatterComponent

func _ready() -> void:
	super()
	spatter_component.time_be_decelerated = time_be_decelerated

## 攻击一次
func attack_once(enemy:Character000Base):
	super(enemy)
	spatter_component.spatter_all_area_enemy(enemy, lane)
	if enemy != null:
		_apply_decelerate(enemy)


## 减速直击目标：与寒冰豌豆同一条判据（`bullet_pea_snow.gd`）
##
## 原版 `Zombie::TakeShieldDamage()` 里**不调** `ApplyChill()`，只有打在本体（`TakeBodyDamage`）
## 或一类防具（`TakeHelmDamage`）上才上减速 ⇒ 二类防具（铁门 / 报纸 / 梯子）还举着时
## 这一发不吃减速。本作由防具组件回答 `is_immune_slow()`，这里只转发。
## 判定放在 `super(enemy)` 之后：这一发把二类防具打掉时，原版会把剩余伤害传到本体并上减速，
## 而防具已 `is_alive() == false`，`is_slow_immune` 自然变成 false，行为一致。
func _apply_decelerate(enemy: Character000Base) -> void:
	if enemy is ZB000Base:
		enemy.be_ice_decelerate(time_be_decelerated)
	elif enemy is Zombie000Base and not enemy.is_slow_immune:
		enemy.be_ice_decelerate(time_be_decelerated)
