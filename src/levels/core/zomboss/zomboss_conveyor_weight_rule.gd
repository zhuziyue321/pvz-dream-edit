extends ConveyorWeightRule
class_name ZombossConveyorWeightRule
## 僵王战传送带权重规则（冒险 5-10 / 迷你游戏 20「僵尸博士的复仇」两关共用）
##
## 原版僵王战传送带给的是「花盆 + 几张能打的卡」，屋顶没有花盆就种不了东西，
## 但花盆给多了又会把传送带塞满、挤掉真正用来打僵王的卡。这条规则按场上情况让权重浮动：
##
##   1. **场上空花盆 <= 5** → 花盆权重下降（场上已经没什么空盆等着填了）
##   2. **传送带里花盆 >= 4** → 寒冰菇 / 火爆辣椒权重上升
##      （这两张是对付僵王的主力：冰冻打断出招、火焰直接掉血；花盆堆在带上时要让路）
##
## 阈值与倍率都在下面的常量里，想调手感改这里就行。

## 场上空花盆数 <= 该值时，花盆权重下降
const EMPTY_POT_DOWN_THRESHOLD := 5
## 花盆权重下降后的倍率（乘在关卡给的初始权重上）
const POT_WEIGHT_SCALE := 0.5

## 传送带里花盆卡数 >= 该值时，下面两张的权重上升
const POT_CARD_UP_THRESHOLD := 4
## 寒冰菇 / 火爆辣椒权重上升的倍率
const COUNTER_WEIGHT_SCALE := 2.0


func apply_weights(conveyor: ConveyorBeltController) -> void:
	if conveyor == null:
		return
	if _count_empty_flower_pot() <= EMPTY_POT_DOWN_THRESHOLD:
		conveyor.set_plant_weight_scale(CharacterRegistry.PlantType.P034FlowerPot, POT_WEIGHT_SCALE)
	## 花盆堆在传送带上：把位置让给打僵王的两张卡
	if conveyor.count_card(CharacterRegistry.PlantType.P034FlowerPot) >= POT_CARD_UP_THRESHOLD:
		conveyor.set_plant_weight_scale(CharacterRegistry.PlantType.P015IceShroom, COUNTER_WEIGHT_SCALE)
		conveyor.set_plant_weight_scale(CharacterRegistry.PlantType.P021Jalapeno, COUNTER_WEIGHT_SCALE)


## 场上的空花盆数：有花盆且花盆上没种东西的格子数
## （花盆躺在 `PlacePlantInCell.Down` 层，格子里的植物总数 = 1 表示只有花盆）
func _count_empty_flower_pot() -> int:
	var main_game := get_main_game()
	if main_game == null or main_game.plant_cell_manager == null:
		return 0
	var num := 0
	for plant_cell_lane in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in plant_cell_lane:
			var pot := plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Down)
			if pot == null or pot.plant_type != CharacterRegistry.PlantType.P034FlowerPot:
				continue
			if plant_cell.get_curr_plant_num() > 1:
				continue
			num += 1
	return num
