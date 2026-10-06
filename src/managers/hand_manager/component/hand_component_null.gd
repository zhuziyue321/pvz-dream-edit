extends HandComponentBase
class_name HandComponentNull
## 手持物组件：空手
## 手上什么都没拿时的兜底组件，负责空手状态下的格子交互（罐子敲击、花盆提示）。
## 注意：空手不算「手持中」，所以它不参与右键取消，也不显示任何手持物。

## 当前鼠标所在格子
## 这里自己存一份而不是直接用 HandManager 的：HandManager 在派发 mouse_exit 之前
## 就会先把自己那份清空，而这里移出格子时还需要用格子去关掉花盆提示
var curr_plant_cell: PlantCell


func get_hand_component_type() -> E_HandComponentType:
	return E_HandComponentType.Null


## 鼠标进入格子：显示花盆提示
func mouse_enter(plant_cell: PlantCell) -> void:
	curr_plant_cell = plant_cell
	if is_instance_valid(plant_cell.pot):
		plant_cell.pot.mouse_enter_pot()


## 鼠标移出格子：关闭花盆提示
func mouse_exit(plant_cell: PlantCell) -> void:
	if is_instance_valid(plant_cell.pot):
		plant_cell.pot.mouse_exit_pot()
	curr_plant_cell = null


## 点击格子：敲罐子。空手永远不消费手持物，返回 false
func click_cell(plant_cell: PlantCell) -> bool:
	if is_instance_valid(plant_cell.pot):
		plant_cell.pot.open_pot_be_hammar()
	return false


## 退出手持态：清掉空手期间留下的提示
func exit_hand() -> void:
	if curr_plant_cell != null and is_instance_valid(curr_plant_cell.pot):
		curr_plant_cell.pot.mouse_exit_pot()
	curr_plant_cell = null
