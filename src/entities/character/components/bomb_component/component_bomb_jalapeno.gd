extends BombComponentBase
class_name BombComponentJalapeno

## 宿主植物：在基类 `owner_character` 之上收窄一次类型，**不回写 owner**
var owner_plant:Plant000Base:
	get: return owner_character as Plant000Base

func component_ready() -> void:
	super()
	if owner_plant == null:
		Log.error("BombComponentJalapeno 只能挂在植物上，当前 owner：" + str(owner))
		return

## 爆炸特效\冰道\梯子
func _start_bomb_fx():
	EventBus.push_event(ConstEventName.JALAPENO_BOMB_EFFECT, [owner_plant.row_col.x])

## 炸死所有敌人
func _bomb_all_enemy():
	EventBus.push_event(ConstEventName.JALAPENO_BOMB_LANE_ZOMBIE, [owner_plant.row_col.x])
	## 销毁当前行道具[冰道和梯子]
	EventBus.push_event(ConstEventName.JALAPENO_BOMB_ITEM_LANE, [owner_plant.row_col.x])

