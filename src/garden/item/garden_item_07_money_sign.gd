extends ItemPlantCellBase
class_name MoneySign

@export var dave_dialog:CrazyDaveDialogResource
## 当前选择的植物数据
var choosed_plant_data:Dictionary
var curr_plant_price := 0
## 售卖植物的格子，若没没卖出去，植物重新初始化
var sell_plant_cell :PlantCellGarden
## 给戴夫手上的plant_cell
var plant_cell_give_dave:PlantCellGarden

## 售价（原版 ZenGarden::GetPlantSellPrice）：
##   金盏花：苗 150 / 小 200 / 中 250 / 满级 300
##   其余：  苗 150 / 小 300 / 中 500 / 满级 800（满级的水生 / 夜行植物 1000）
const MARIGOLD_PRICE_FROM_STAGE := {
	GardenManager.E_GrowthStage.Sprout: 150,
	GardenManager.E_GrowthStage.Small: 200,
	GardenManager.E_GrowthStage.Medium: 250,
	GardenManager.E_GrowthStage.Full: 300,
}
const PRICE_FROM_STAGE := {
	GardenManager.E_GrowthStage.Sprout: 150,
	GardenManager.E_GrowthStage.Small: 300,
	GardenManager.E_GrowthStage.Medium: 500,
	GardenManager.E_GrowthStage.Full: 800,
}
## 满级水生 / 夜行植物的售价（原版 Plant::IsAquatic / IsNocturnal 的加价）
const FULL_AQUATIC_OR_NOCTURNAL_PRICE := 1000


## 这株植物戴夫出多少钱（原版 GetPlantSellPrice）
## 物种在入手时就定了，存在 curr_plant_species；老存档没有这个键时退回 curr_plant_type
func _get_sell_price(plant_data: Dictionary) -> int:
	var stage := int(plant_data.get("curr_growth_stage", GardenManager.E_GrowthStage.Sprout)) \
		as GardenManager.E_GrowthStage
	var species := PlantIds.from_legacy(plant_data.get("curr_plant_species", PlantIds.NULL))
	if species == PlantIds.NULL:
		species = PlantIds.from_legacy(plant_data.get("curr_plant_type", PlantIds.NULL))

	if species == PlantIds.MARI_GOLD:
		return int(MARIGOLD_PRICE_FROM_STAGE.get(stage, 150))
	if stage == GardenManager.E_GrowthStage.Full:
		## curr_plant_condition 的 bit1 = 陆地，清掉就是水生
		var is_aquatic := (int(plant_data.get("curr_plant_condition", 2)) & 2) == 0
		if is_aquatic or PlantIds.NOCTURNAL.has(species):
			return FULL_AQUATIC_OR_NOCTURNAL_PRICE
	return int(PRICE_FROM_STAGE.get(stage, 150))
@onready var crazy_dave: CrazyDave = $DaveCanvasLayer/CrazyDave


func use_it():
	## 当前选择的植物数据
	choosed_plant_data = curr_plant_cell.get_curr_plant()
	sell_plant_cell = curr_plant_cell
	curr_plant_cell.free_curr_plant()

	curr_plant_price = _get_sell_price(choosed_plant_data)

	dave_dialog.dialog_detail_list[0].text = "我给你$" + str(curr_plant_price) + "换你这棵植物！"

	## 给戴夫手上的plant_cell
	plant_cell_give_dave = SceneRegistry.PLANT_CELL_GARDEN.instantiate()
	plant_cell_give_dave.position += Vector2(-40,-60)
	crazy_dave.reset_dave(dave_dialog, plant_cell_give_dave)
	plant_cell_give_dave.init_curr_plant_cell(choosed_plant_data)
	crazy_dave.is_activate = true
	crazy_dave.visible = true
	deactivate_it()

	## 戴夫离开
	await crazy_dave.signal_dave_leave_end
	crazy_dave.visible = false
	choosed_plant_data = {}
	curr_plant_price = 0
	sell_plant_cell = null


## 同意售卖
func sell_agree():
	Global.global_game_state.coin_value += curr_plant_price

	plant_cell_give_dave.queue_free()
## 不同意售卖
func sell_disagree():
	sell_plant_cell.init_curr_plant_cell(choosed_plant_data)

	plant_cell_give_dave.queue_free()
