extends ResourcePlantCondition
## 「产脑光墓碑」的种植条件（模组「僵尸卡」，只在「玩家对战」里用得到）
##
## 墓碑是**僵尸方**的单位（行为类似向日葵、产脑子），落位资格跟僵尸走：
##   · `can_common_zombie` —— 与本体僵尸放置判定（`hand_component_character.gd`
##     僵尸分支）同一资格线；将来对战补上红线 / 放置限制后自动跟着同规则
##   · 地形照常过一遍 `plant_condition`（本株按 DEFAULT_NORM 注册：草地 / 花盆 / 睡莲）
##   · 该位置为空
##
## ★ 为什么要换掉默认条件：默认条件第一关就看 `can_common_plant`（植物的「禁种」
##   标记）—— 而僵尸半场的格子将来多半会带「禁种」类标记，植物类卡按默认条件
##   在僵尸方地界一格都放不下去。墓碑是僵尸方单位，落位必须跟僵尸同一套。
##
## ★ 为什么是"换掉整个条件资源"而不是改字段：能不能种是**方法**里的逻辑，字段改不动；
##   由模组入口造一份本类实例，用 `CharacterRegistry.set_runtime_plant_condition()` 换上，
##   关模组时 `clear_runtime_plant_condition()` 撤回（见 `zombie_card_mod.gd`）。


## 判断是否可以种植（墓碑：跟僵尸同一套落位资格）
func judge_is_can_plant(plant_cell: PlantCell, curr_plant_type: StringName) -> bool:
	## 格子限种（观星的星星轮廓点只收杨桃 / 南瓜头）：所有植物都要先过这一关
	if not plant_cell.is_plant_type_allowed(curr_plant_type):
		return false
	## 落位资格跟僵尸走（僵尸半场），不看植物的「禁种」标记
	if not plant_cell.can_common_zombie:
		return false
	## 地形照常判（草地 / 花盆 / 睡莲……）
	if (plant_condition & plant_cell.curr_condition) == 0:
		return false
	## 该位置为空
	return not is_instance_valid(plant_cell.get_plant(place_plant_in_cell))
