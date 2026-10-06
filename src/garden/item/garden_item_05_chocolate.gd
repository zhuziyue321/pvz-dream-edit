extends ItemBase
class_name Chocolate
## 巧克力:花园工具栏第 5 格,库存来自僵尸掉落(买了蜗牛之后才掉,见 DropItemComponent.drop_chocolate),
## 商店不出售它(见 ConstShop.CHOCOLATE_PRICE)
## 用法:选中后点蜗牛,蜗牛吃了爬得更快(见 Stinky.eat_chocolate);点了别处只是放下,不扣库存
## 原版口径:巧克力是喂蜗牛的,蜗牛没买就没什么可喂(按钮一并隐藏,见 GardenManager._refresh_garden_tool_visible)

## 花园里的蜗牛(GardenManager 注入,没买蜗牛时为空)
var stinky: Stinky


func _input(event: InputEvent) -> void:
	if is_clone or not is_activate:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		## 安卓适配:等两帧,让道具先跟着鼠标挪到位再判定
		is_mouse_button_pressed_wait = true
		global_position = get_global_mouse_position()
		await get_tree().physics_frame
		await get_tree().physics_frame
		if _is_hit_stinky(global_position):
			use_it()
		else:
			deactivate_it()
		is_mouse_button_pressed_wait = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		deactivate_it()


func _is_hit_stinky(global_pos: Vector2) -> bool:
	return stinky != null and is_instance_valid(stinky) and stinky.is_hit(global_pos)


## 喂蜗牛:先扣一块巧克力库存,没库存就用不了(正常情况下工具栏已隐藏)
func use_it():
	if stinky == null or not Global.global_game_state.use_garden_tool(
			GardenManager.E_GardenTool.Chocolate):
		deactivate_it()
		return
	stinky.eat_chocolate()
	deactivate_it()
	## 喂掉最后一块就当场撤下工具栏,别等到重进花园才消失
	## (判定口径与进花园 / 从商店回来时一致:见 GardenManager._refresh_garden_tool_visible)
	item_button.visible = Global.global_game_state.is_garden_tool_available(
		GardenManager.E_GardenTool.Chocolate)
