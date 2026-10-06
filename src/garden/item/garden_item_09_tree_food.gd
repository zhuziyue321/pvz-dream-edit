extends ItemBase
class_name TreeFood
## 树肥料(Tree Food):花园工具栏第 9 格,商店第四页第二行第一格 $2500 一袋
## (见 ConstTreeOfWisdom.TREE_FOOD_PRICE / 商店商品 src/store/goods_garden_tool.gd)
## 用法:选中后拖到智慧树的树根上点一下,树长高一英尺并讲一句智慧(见 TreeOfWisdom.add_height);
## 点了别处只是放下,不扣库存
## 原版口径:一次一袋,最多囤 10 袋;没买智慧树就没什么可喂(按钮一并隐藏,
## 见 GardenManager._refresh_garden_tool_visible)

## 当前页的智慧树(GardenManager 注入,不在智慧树页时为空)
var tree_of_wisdom: TreeOfWisdom

@onready var anim_lib: AnimationPlayer = $AnimLib


func _input(event: InputEvent) -> void:
	if is_clone or not is_activate:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		## 安卓适配:等两帧,让道具先跟着鼠标挪到位再判定
		is_mouse_button_pressed_wait = true
		global_position = get_global_mouse_position()
		await get_tree().physics_frame
		await get_tree().physics_frame
		if _is_hit_tree(global_position):
			use_it()
		else:
			deactivate_it()
		is_mouse_button_pressed_wait = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		deactivate_it()


func _is_hit_tree(global_pos: Vector2) -> bool:
	return tree_of_wisdom != null and is_instance_valid(tree_of_wisdom) \
		and tree_of_wisdom.is_hit(global_pos)


## 施肥:先扣一袋库存,没库存就用不了(正常情况下工具栏已隐藏)
## 本体当场收起,让克隆体在树根播"倒肥料"动画,播完树才长高
func use_it() -> void:
	if not _is_hit_tree(get_global_mouse_position()) or not Global.global_game_state.use_garden_tool(
			GardenManager.E_GardenTool.TreeFood):
		deactivate_it()
		return
	var clone := clone_self() as TreeFood
	clone.global_position = tree_of_wisdom.get_feed_position()
	deactivate_it(false)
	clone.visible = true
	clone.anim_lib.play("ALL_ANIMS")
	await clone.anim_lib.animation_finished
	## 等动画的这会儿可能被切走(翻页 / 进商店),树已经被释放了
	if is_instance_valid(tree_of_wisdom):
		tree_of_wisdom.add_height()
	clone.queue_free()
	## 喂掉最后一袋就当场撤下工具栏,别等到重进花园才消失
	item_button.visible = Global.global_game_state.is_garden_tool_available(
		GardenManager.E_GardenTool.TreeFood)
