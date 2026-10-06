extends LevelProgressProvider
class_name ZombossProgressProvider
## 僵王战的数据源：进度条 = 僵王血量百分比
##
## 血量本体在僵王的 HpComponent 里，这里每帧读一次换算成百分比：
## 满血 = 100，打死 = 0（原版僵王战没有波次，进度条那条就是僵王的血量）。
##
## 多个僵王时取第一个存活的（顺序同 `ZombieManager.get_living_bosses()`）；
## 僵王还没出场 / 已经死亡 / 已离场 → 进度条不显示（避免主 UI 上留一条孤儿进度条）。


func get_progress() -> float:
	var boss := _living_boss()
	if boss == null:
		return 0.0
	var hp_component := boss.hp_component
	if not is_instance_valid(hp_component) or hp_component.max_hp <= 0:
		return 0.0
	return clampf(float(hp_component.curr_hp) / float(hp_component.max_hp) * 100.0, 0.0, 100.0)


func is_bar_visible() -> bool:
	return _living_boss() != null


## 僵王战没有波次，进度条上不画旗帜
func get_flag_num() -> int:
	return 0


func _living_boss() -> ZB000Base:
	if controller == null or not is_instance_valid(controller.main_game):
		return null
	var zombie_manager := controller.main_game.zombie_manager
	if zombie_manager == null:
		return null
	var bosses := zombie_manager.get_living_bosses()
	if bosses.is_empty():
		return null
	return bosses[0]
