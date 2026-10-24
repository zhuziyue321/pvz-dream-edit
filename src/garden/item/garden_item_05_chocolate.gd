extends ItemBase
class_name Chocolate
## 巧克力:花园工具栏第 5 格,库存来自僵尸掉落(买了蜗牛之后才掉,见 DropItemComponent.drop_chocolate),
## 商店不出售它(见 ConstShop.CHOCOLATE_PRICE)
## 用法:原版既可喂蜗牛(爬得更快)也可喂植物(进入"嗨"状态、产币加速,见 FeedChocolateToPlant)。
## 选中后点蜗牛喂蜗牛,点植物喂植物,点别处只是放下,不扣库存

## 花园里的蜗牛(GardenManager 注入,没买蜗牛时为空)
var stinky: Stinky
var garden_manager: GardenManager

func _input(event: InputEvent) -> void:
	if is_clone or not is_activate:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		## 安卓适配:等两帧,让道具先跟着鼠标挪到位再判定
		is_mouse_button_pressed_wait = true
		global_position = get_global_mouse_position()
		await get_tree().physics_frame
		await get_tree().physics_frame
		## 先判植物格子(原版巧克力也能喂植物),再判蜗牛
		if garden_manager == null:
			garden_manager = get_tree().current_scene as GardenManager
		var plant_cell := garden_manager.get_plant_cell_at_global_pos(global_position)
		if plant_cell != null and is_instance_valid(plant_cell) and plant_cell.plant_in_cell != null:
			_feed_plant(plant_cell.plant_in_cell)
		elif _is_hit_stinky(global_position):
			_feed_stinky()
		else:
			deactivate_it()
		is_mouse_button_pressed_wait = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		deactivate_it()

func _is_hit_stinky(global_pos: Vector2) -> bool:
	return stinky != null and is_instance_valid(stinky) and stinky.is_hit(global_pos)

## 喂植物(原版 FeedChocolateToPlant):植物进入"嗨"状态、产币加速
## 原版只有"满级 + 今天已经照顾过 + 当前不嗨"的植物能被喂（PlantCanHaveChocolate），
## 喂不上时把刚扣的那块巧克力退回去
func _feed_plant(plant) -> void:
	if not Global.global_game_state.use_garden_tool(GardenManager.E_GardenTool.Chocolate):
		deactivate_it()
		return
	if not plant.feed_chocolate():
		Global.global_game_state.add_garden_tool_num(GardenManager.E_GardenTool.Chocolate, 1)
		deactivate_it()
		return
	deactivate_it()
	## 喂掉最后一块就当场撤下工具栏,别等到重进花园才消失
	## (判定口径与进花园 / 从商店回来时一致:见 GardenManager._refresh_garden_tool_visible)
	item_button.visible = Global.global_game_state.is_garden_tool_available(GardenManager.E_GardenTool.Chocolate)

## 喂蜗牛(原版:蜗牛吃了爬得更快)
func _feed_stinky() -> void:
	if stinky == null or not Global.global_game_state.use_garden_tool(GardenManager.E_GardenTool.Chocolate):
		deactivate_it()
		return
	stinky.eat_chocolate()
	deactivate_it()
	item_button.visible = Global.global_game_state.is_garden_tool_available(GardenManager.E_GardenTool.Chocolate)
