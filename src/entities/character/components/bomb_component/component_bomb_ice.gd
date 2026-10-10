extends BombComponentBase
class_name BombComponentIce

@onready var bomb_effect: BombEffectBase = $BombEffect

@export var time_ice:float = 3
@export var time_decelerate: float = 5

## 爆炸特效
func _start_bomb_fx():
	bomb_effect.activate_bomb_effect()

## 对所有敌人结算伤害，并把冰冻作为附加控制效果一起给过去。[br]
## 伤害取基类的 `bomb_value`（场上配置，见 plant_ice_shroom.tscn），
## 与火爆辣椒 / 樱桃炸弹同一套口径，改数值不用动代码。
func _bomb_all_enemy():
	EventBus.push_event(ConstEventName.ICE_ALL_ZOMBIE, [time_ice, time_decelerate, bomb_value])
