extends DIM_Base
class_name DIM_GardenPlant
## 掉落管理器的子节点，掉落花园植物使用
##
## 与其它三类的区别：**不抛抛物线** —— 花园植物礼包就掉在僵尸死亡处（旧实现如此）

## 掉落花园植物的父节点
@export var all_drop_garden_plant_parent: Node2D


func get_drop_parent() -> Node2D:
	return all_drop_garden_plant_parent


func is_gate_enabled() -> bool:
	return false


func is_notify_spawned() -> bool:
	return false


func get_spawn_sfx() -> String:
	return "chime"


func _ready() -> void:
	EventBus.subscribe(ConstEventName.CREATE_GARDEN_PLANT, create_garden_plant)


## 掉落花园植物
func create_garden_plant(global_position_new_garden_plant:Vector2) -> Present:
	var new_garden_plant := instantiate_drop(SceneRegistry.PRESENT) as Present
	if new_garden_plant == null:
		return null
	new_garden_plant.global_position = global_position_new_garden_plant
	play_spawn_sfx()
	return new_garden_plant
