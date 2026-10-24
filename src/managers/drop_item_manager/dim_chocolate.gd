extends DIM_Base
class_name DIM_Chocolate
## 掉落管理器的子节点，掉落巧克力使用
## 只管实例化（公共那套在 `DIM_Base`）；事件订阅与位置收敛由 DropItemManager 转接
## （转接是为了用 `DropPositionUtil.clamp_drop_position` 把落点收进画面，见那里关于画布偏移的说明）

## 掉落巧克力的父节点
@export var all_drop_chocolate_parent: Node2D


func get_drop_parent() -> Node2D:
	return all_drop_chocolate_parent


func get_spawn_sfx() -> String:
	return "chime"


## 掉落巧克力，返回实例化出来的掉落物
## drop_global_position：僵尸死亡处（世界坐标，已由 DropItemManager 收进可视范围）
func create_chocolate(drop_global_position: Vector2) -> ChocolateDrop:
	## 闸门被占住时（联机客户端）这一块不掉：掉不掉由**主机**下发（与金币同一个闸门）
	if is_blocked():
		return null
	var new_chocolate := instantiate_drop(
		ItemRegistry.get_drop_scene(ItemRegistry.E_DropKind.Chocolate)) as ChocolateDrop
	if new_chocolate == null:
		return null
	new_chocolate.drop_kind = ItemRegistry.E_DropKind.Chocolate
	new_chocolate.global_position = drop_global_position
	## 抛物线弹出（与金币一致）
	launch_with_random_target(new_chocolate)
	notify_drop_spawned(new_chocolate)
	play_spawn_sfx()
	return new_chocolate
