extends BombComponentBase
class_name BombComponentIce

## 宿主植物：伤害取自它的角色攻击力（`Character000Base.attack_value`，见 plant_ice_shroom.tscn）
var owner_plant: Plant000Base:
	get: return owner_character as Plant000Base

@onready var bomb_effect: BombEffectBase = $BombEffect

@export var time_ice:float = 3
@export var time_decelerate: float = 5

func component_ready() -> void:
	super()
	if owner_plant == null:
		Log.error("BombComponentIce 只能挂在植物上，当前 owner：" + str(owner))

## 爆炸特效
func _start_bomb_fx():
	bomb_effect.activate_bomb_effect()

## 对所有敌人结算伤害，并把冰冻作为附加控制效果一起给过去。[br]
## 伤害取角色攻击力（plant_ice_shroom.tscn 配 20），与地刺 / 忧郁菇同一口径，改数值不用动代码。
func _bomb_all_enemy():
	EventBus.push_event(ConstEventName.ICE_ALL_ZOMBIE,
		[time_ice, time_decelerate, owner_plant.attack_value])
