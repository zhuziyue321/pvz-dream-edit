extends Plant000Base
class_name Plant999Imitater

## 模仿的植物类型
var imitater_plant_type :CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null
@onready var imitater_effect: Node2D = $ImitaterEffect


## 更新模仿者植物
## 由变身动画（animation/character/plant/imitater/imitater_explode.tres 的方法轨）调用
func update_imitater():
	## 变身交给 plant_cell 排到下一帧（本体 queue_free 后格子才空出来），这里不等它
	plant_cell.imitater_create_plant(imitater_plant_type)
	imitater_effect.visible = true
	imitater_effect.z_index += 1
	imitater_effect.activate_it()
	## 角色死亡直接消失
	character_death_disappear()
