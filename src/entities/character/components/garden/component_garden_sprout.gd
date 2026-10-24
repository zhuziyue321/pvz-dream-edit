extends GardenComponent
class_name GardenComponentSprout

## 发芽期专用组件（当前 `plant_sprout.tscn` 用的是基类 `GardenComponent`，本类保留备用）。
## 成长 / 需求 / 产币全部继承基类（口径见 component_garden.gd），这里只补两件事：
##   · 苗→小时由植物格子重建（基类已用 signal_sprout_grow 表达）；
##   · 发芽期的物种选择（基类 up_growth_stage 已经处理，本类不再重复摇物种）。

var plant_cell:PlantCellGarden


## 更新状态
func update_growth_stage():
	match curr_growth_stage:
		GardenManager.E_GrowthStage.Sprout:
			pass
		GardenManager.E_GrowthStage.Small:
			plant_cell.sprout_up_new_plant()

	flower_pot.plant_change_profect(is_need_fulfilled_today())


## 成长状态升级：物种在入手时已定（见基类 up_growth_stage）
func up_growth_stage():
	super()
