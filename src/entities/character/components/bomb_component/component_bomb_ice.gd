extends BombComponentBase
class_name BombComponentIce

## 宿主植物：伤害取自它的角色攻击力（`Character000Base.attack_value`，见 plant_ice_shroom.tscn）
var owner_plant: Plant000Base:
	get: return owner_character as Plant000Base

@onready var bomb_effect: BombEffectBase = $BombEffect

## 全场统一冻结时长（游戏秒）：**0 = 按原版口径**（陆地 4~6 秒随机、水中 3 秒，
## 见 `ZombieManager.ICE_TRAP_FREEZE_LAND` / `ICE_TRAP_FREEZE_POOL`）；
## > 0 = 所有僵尸统一冻这么久（剧情 / 模组特调时才配）
@export var time_ice:float = 0.0
## 减速**总**时长（游戏秒，**从冰冻那一刻起算**）：原版 `ApplyChill(true)` = 2000 tick = 20 秒。
## 本作「解冻后减速」是串在冰冻之后的第二个计时器，实际下发的时长 = 本值 − 冻结时长
## （冻 4 秒的僵尸解冻后还剩约 16 秒减速）；0 = 解冻后不再减速。
@export var time_decelerate: float = 20.0

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
