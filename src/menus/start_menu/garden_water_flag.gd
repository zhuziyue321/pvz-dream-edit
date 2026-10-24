extends TextureRect
class_name GardenConditionFlag

## 主菜单花园按钮上的状态角标：有待放置植物 -> 幼苗图标；有植物要浇水 -> 水滴图标。
##
## 判定直接读存档里的花园植物数据（此刻没有花园节点），所以这里必须自己按原版
## `GetPlantsNeed()` 的口径估一遍「这株是不是要水」—— 口径与
## `GardenComponent.get_plants_need()` 保持一致（时间戳 / 夜行 / 水生 / 每日需求）。

@onready var water: TextureRect = $Water
@onready var sprout: TextureRect = $Sprout

## 与 GardenComponent 同源的原版常量
const WATER_INTERVAL := 15
const HOUR := 3600


func _ready() -> void:
	judge_garden_condition()

func judge_garden_condition():
	if Global.global_game_state.curr_num_new_garden_plant > 0:
		sprout.visible = true
		water.visible = false
		visible = true
	elif _judge_need_water():
		sprout.visible = false
		water.visible = true
		visible = true
	else:
		visible = false


func _judge_need_water() -> bool:
	var garden_data: Dictionary = Global.global_game_state.garden_data
	for bg_index in range(GardenManager.E_GardenBgType.size()):
		var page_num := int(garden_data.get("num_bg_page_" + str(bg_index), 0))
		var curr_bg_data: Dictionary = garden_data.get(GardenManager.make_bg_save_key(bg_index), {})
		for page in range(page_num):
			var curr_bg_page_data: Dictionary = curr_bg_data.get(
				GardenManager.make_page_save_key(page), {})
			for cell_index in range(curr_bg_page_data.size()):
				var plant_data: Dictionary = curr_bg_page_data.get(
					GardenManager.make_cell_save_key(cell_index), {})
				if plant_data and _plant_data_needs_water(plant_data, bg_index):
					return true
	return false


## 这株存档植物现在是不是缺水（原版 GetPlantsNeed 的简化版：只判 PLANTNEED_WATER）
static func _plant_data_needs_water(plant_data: Dictionary, bg_index: int) -> bool:
	var stage := int(plant_data.get("curr_growth_stage", GardenManager.E_GrowthStage.Sprout))
	if stage == GardenManager.E_GrowthStage.Sprout:
		return false

	var species := PlantIds.from_legacy(plant_data.get("curr_plant_species", PlantIds.NULL))
	if species == PlantIds.NULL:
		species = PlantIds.from_legacy(plant_data.get("curr_plant_type", PlantIds.NULL))
	## 夜行植物在主花园（阳光房）不需要任何照顾
	if PlantIds.NOCTURNAL.has(species) and bg_index == GardenManager.E_GardenBgType.GreenHouse:
		return false

	var now := int(Time.get_unix_time_from_system())
	var last_watered := int(plant_data.get("last_watered_time", 0))
	var last_fulfilled := int(plant_data.get("last_need_fulfilled_time", 0))
	var last_fertilized := int(plant_data.get("last_fertilized_time", 0))
	if now - last_fertilized < HOUR:
		return false
	if now - last_fulfilled < HOUR or _day_key(now) <= _day_key(last_fulfilled):
		return false

	## 水生植物永远不要水（满级走药 / 留声机，非满级只在水族馆要肥料）
	if (int(plant_data.get("curr_plant_condition", 2)) & 2) == 0:
		return false

	if now - last_watered <= WATER_INTERVAL:
		return false
	if stage == GardenManager.E_GrowthStage.Full:
		## 满级：每日需求还没摇出来时就轮到浇水（原版 return PLANTNEED_WATER）
		return int(plant_data.get("daily_need_item", GardenManager.E_NeedItem.Null)) \
			== GardenManager.E_NeedItem.Null
	var times_fed := int(plant_data.get("times_fed", plant_data.get("curr_water_time", 0)))
	var feedings_per_grow := int(plant_data.get(
		"feedings_per_grow", plant_data.get("max_water_time", 0)))
	if feedings_per_grow <= 0:
		feedings_per_grow = 5
	return times_fed < feedings_per_grow


static func _day_key(unix_time: int) -> String:
	return Time.get_datetime_string_from_unix_time(unix_time, true).substr(0, 10)
