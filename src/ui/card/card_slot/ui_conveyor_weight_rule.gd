extends RefCounted
class_name ConveyorWeightRule
## 传送带权重规则
##
## 每次出卡前被传送带控制器问一次（`apply_weights`），按场上情况把权重调高 / 调低：
## 规则只调控制器上的权重，不碰传送带节点，也不改关卡资源上的权重条目。
##
## 用法（关卡脚本里加一行，见 adventure_05_10 / minigame_20_zomboss_revenge）：
##   _mg.card_manager.add_conveyor_weight_rule(ZombossConveyorWeightRule.new())
##
## 一关专属的规则写在关卡脚本那一侧（硬约束 §1-8）；两关以上共用才上浮成单独的类
## （`ZombossConveyorWeightRule` 就是冒险 5-10 与迷你游戏 20 共用）。

## 所属传送带控制器（由 add_weight_rule() 注入）
var controller: ConveyorBeltController


## 每次出卡前调用一次；控制器此时已经把权重恢复成关卡的初始值，
## 规则想改哪一项就调 `set_plant_weight` / `set_plant_weight_scale`
func apply_weights(_conveyor: ConveyorBeltController) -> void:
	pass


## 规则常用的上下文：当前主游戏（取场上植物 / 僵王等）
func get_main_game() -> MainGameManager:
	return controller.card_manager.main_game if controller != null and controller.card_manager != null else null
