extends ItemPlantCellBase
class_name ItemPlantNeedBase

## 当前物品对应的植物需要的物品
@export var plant_need_item :GardenManager.E_NeedItem
@onready var anim_lib: AnimationPlayer = $AnimLib
## 单个植物道具位置修正，黄金水壶无位置修正
@export var correct_position :Vector2

@export var sfx_string_name:StringName

## 植物需要的道具 -> 商店出售的消耗型花园工具(肥料 / 杀虫剂,用一次扣一个)
## 基础水壶是戴夫送的,不在商店卖;留声机是买断型,不按次扣
const NEED_ITEM_TO_GARDEN_TOOL: Dictionary = {
	GardenManager.E_NeedItem.Fertilizer: GardenManager.E_GardenTool.Fertilizer,
	GardenManager.E_NeedItem.BugSpray: GardenManager.E_GardenTool.BugSpray,
}

## 黄金水壶重写该函数
func use_it():
	## 消耗型工具(肥料 / 杀虫剂)使用时扣库存;没有库存就用不了(正常情况下工具栏已隐藏)
	if NEED_ITEM_TO_GARDEN_TOOL.has(plant_need_item):
		var tool_type := NEED_ITEM_TO_GARDEN_TOOL[plant_need_item] as GardenManager.E_GardenTool
		if not Global.global_game_state.use_garden_tool(tool_type):
			deactivate_it()
			return
		## 用掉最后一个就当场撤下工具栏,别等到重进花园才消失
		## (判定口径与进花园 / 从商店回来时一致:见 GardenManager._refresh_garden_tool_visible)
		item_button.visible = Global.global_game_state.is_garden_tool_available(tool_type)
	play_plant_need_item_sfx()
	var clone_item_plant_cell = curr_plant_cell
	var clone:ItemBase = clone_self()

	## 修改道具位置
	clone.global_position = clone_item_plant_cell.global_position + correct_position

	deactivate_it(false)

	clone.visible = true
	clone.anim_lib.play("ALL_ANIMS")
	await clone.anim_lib.animation_finished
	## 是否跳到下一页
	if clone_item_plant_cell and is_instance_valid(clone_item_plant_cell):
		clone_item_plant_cell.use_item_in_this(self)

	clone.queue_free()

func play_plant_need_item_sfx():
	await get_tree().create_timer(0.2).timeout
	SoundManager.play_other_SFX(sfx_string_name)
