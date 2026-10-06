extends ItemPlantNeedBase
class_name WateringCan

## 基础水壶与黄金水壶是同一个道具:戴夫送的是基础水壶(一次浇 1 株),
## 在商店买断黄金水壶(见 GardenManager.E_GardenTool.GoldWateringCan)后,
## 壶身贴图 / 浇水动画 / 作用范围一起升级成黄金款(一次最多浇 4 株)。
## 是否已买见 GlobalGameState.is_garden_tool_bought,外观刷新见 refresh_visual()

## 待机时壶身贴图
const CAN_TEXTURE: Dictionary = {
	false: preload("res://assets/reanim/ZenGarden_wateringcan1.png"),
	true: preload("res://assets/reanim/ZenGarden_wateringcan1_gold.png"),
}
## 工具栏按钮图标
const BUTTON_ICON: Dictionary = {
	false: preload("res://assets/image/garden/WateringCan.png"),
	true: preload("res://assets/image/garden/WateringCanGold.png"),
}
## 浇水动画(动画里的壶身贴图也是分红金两套)
const WATER_ANIM: Dictionary = {
	false: &"ZenGarden_wateringcan_water",
	true: &"ALL_ANIMS",
}
## 检测半径:基础水壶是个"点"(与肥料 / 杀虫剂一致,一次只罩住 1 株),
## 黄金水壶是原版的范围圈(半径内最多罩 4 株)
const REACH_RADIUS: Dictionary = {
	false: 0.1,
	true: 62.0081,
}
## 一次最多浇几株(原版:基础 1 株,黄金 4 株)
const MAX_PLANT_NUM: Dictionary = {
	false: 1,
	true: 4,
}

@onready var water_sprite: Sprite2D = $Body/Water
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var zen_gold_tool_reticle_result: Sprite2D = $ZenGoldToolReticleResult
## 当前碰撞的植物格子，单格子道具使用时，每个格子之间必须有空隙，并且道具碰撞器要非常小
var curr_plant_cells:Array[PlantCellGarden]


## 当前是黄金水壶(已买断)还是基础水壶
func is_gold() -> bool:
	return Global.global_game_state.is_garden_tool_bought(GardenManager.E_GardenTool.GoldWateringCan)


## 按当前是基础水壶还是黄金水壶刷新外观与作用范围
## 调用点:进花园时 GardenManager._refresh_garden_tool_visible,
## 从商店回来时 _update_back_from_store(可能刚买了黄金水壶)
func refresh_visual() -> void:
	var gold := is_gold()
	water_sprite.texture = CAN_TEXTURE[gold]
	## 范围准星是黄金水壶专属,基础水壶只瞄一株,不该画出来
	zen_gold_tool_reticle_result.visible = gold
	(collision_shape.shape as CircleShape2D).radius = REACH_RADIUS[gold]
	if item_button:
		item_button.item_texture.texture = BUTTON_ICON[gold]


## 判断当前是否有植物格子
func judge_is_curr_plant_cell() -> bool:
	return curr_plant_cells != []


## 本次浇水要作用的植物格子:基础水壶 1 株,黄金水壶取半径内最近的 4 株
func get_target_plant_cells() -> Array[PlantCellGarden]:
	var target_cells: Array[PlantCellGarden] = curr_plant_cells.duplicate()
	if is_gold():
		target_cells.sort_custom(func(a: PlantCellGarden, b: PlantCellGarden) -> bool:
			return a.global_position.distance_squared_to(global_position) \
					< b.global_position.distance_squared_to(global_position))
	return target_cells.slice(0, MAX_PLANT_NUM[is_gold()])


func use_it():
	play_plant_need_item_sfx()
	var clone_item_plant_cells := get_target_plant_cells()
	var clone:ItemBase = clone_self()

	## 如果当前只对一个植物生效，修改道具位置
	if clone_item_plant_cells.size() == 1 and correct_position != Vector2.ZERO:
		clone.global_position = clone_item_plant_cells[0].global_position + correct_position

	clone.visible = true
	clone.anim_lib.play(WATER_ANIM[is_gold()])

	deactivate_it(false)

	await clone.anim_lib.animation_finished
	for plant_cell in clone_item_plant_cells:
		if plant_cell and is_instance_valid(plant_cell):
			plant_cell.use_item_in_this(self)
	clone.queue_free()


## 克隆自己
func clone_self():
	var clone = super.clone_self()
	clone.zen_gold_tool_reticle_result.visible = false
	return clone


## 检测到进入的植物格子
func _on_area_2d_area_entered(area: Area2D) -> void:
	var new_plant_cell:PlantCellGarden = area.get_parent()
	curr_plant_cells.append(new_plant_cell)
	new_plant_cell.plant_cell_light()


## 检测到出去的植物格子
func _on_area_2d_area_exited(area: Area2D) -> void:
	var new_plant_cell:PlantCellGarden = area.get_parent()
	curr_plant_cells.erase(new_plant_cell)
	new_plant_cell.plant_cell_color_restore()
