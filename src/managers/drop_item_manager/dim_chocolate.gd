extends Node
class_name DIM_Chocolate
## 掉落管理器的子节点，掉落巧克力使用
## 与 DIM_SeedPacket 同构：只管实例化，事件订阅与位置收敛由 DropItemManager 转接
## （转接是为了用 DropItemManager.get_clamp_drop_position 把落点收进画面，见那里关于画布偏移的说明）

## 掉落巧克力的父节点
@export var all_drop_chocolate_parent: Node2D

## 掉落的抛物线落点：相对出生点的水平 / 垂直偏移范围（与 DropItemComponent 的金币一致）
const TARGET_MOVE_X_RANGE := Vector2(-50.0, 50.0)
const TARGET_MOVE_Y_RANGE := Vector2(80.0, 90.0)


## 掉落巧克力，返回实例化出来的掉落物
## drop_global_position：僵尸死亡处（世界坐标，已由 DropItemManager 收进可视范围）
func create_chocolate(drop_global_position: Vector2) -> ChocolateDrop:
	## 闸门被占住时（联机客户端）这一块不掉：掉不掉由**主机**下发（与金币同一个闸门）
	if GlobalUtils.drop_gate.is_valid() and bool(GlobalUtils.drop_gate.call()):
		return null
	if all_drop_chocolate_parent == null:
		Log.error("掉落巧克力但没有配置 all_drop_chocolate_parent")
		return null
	var new_chocolate: ChocolateDrop = SceneRegistry.CHOCOLATE_DROP.instantiate()
	new_chocolate.drop_kind = DropItemManager.E_DropKind.Chocolate
	all_drop_chocolate_parent.add_child(new_chocolate)
	new_chocolate.global_position = drop_global_position
	## 抛物线弹出（与金币一致）
	var target_position := Vector2(
		randf_range(TARGET_MOVE_X_RANGE.x, TARGET_MOVE_X_RANGE.y),
		randf_range(TARGET_MOVE_Y_RANGE.x, TARGET_MOVE_Y_RANGE.y))
	new_chocolate.spawn_target = new_chocolate.global_position + target_position
	new_chocolate.launch(target_position)
	## 落点写完了才广播（联机主机靠它下发；单机没人连，发了也无事）
	EventBus.push_event(ConstEventName.DROP_ITEM_SPAWNED, [new_chocolate])
	SoundManager.play_other_SFX("chime")
	return new_chocolate
