extends Node2D
class_name DoomShroomCrater

#陆地白天、黑夜
#泳池白天、黑夜
#屋顶中间、左边

## 当前坑洞
var curr_crater:Node2D
var curr_crater_0:Sprite2D
var curr_crater_1:Sprite2D
@export var creater_time := 180.0

## [cell_type] 地形（0 = 陆地白天/黑夜，1 = 泳池白天/黑夜，……）
## [plant_cell] 所属格子，坑消失时回调它清掉「不能种植」的状态
## [duration] 坑存在多少秒；**传 0 表示永久**（只能由 plant_cell.remove_crater() 主动填平，
##             见 plant_cell.create_crater_permanent）
func init_crater(cell_type:int, plant_cell:PlantCell=null, duration:float=180.0):
	curr_crater = get_child(cell_type)
	curr_crater.visible = true
	curr_crater_0 = curr_crater.get_child(0)
	curr_crater_1 = curr_crater.get_child(1)
	curr_crater_0.visible = true
	if duration <= 0.0:
		return

	await get_tree().create_timer(duration/2).timeout
	curr_crater_0.visible = false
	curr_crater_1.visible = true
	await get_tree().create_timer(duration/2).timeout
	curr_crater_1.visible = false
	if plant_cell != null:
		plant_cell.delete_crater_update_plant_cell_data()
	queue_free()
