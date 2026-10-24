extends Node
class_name DIM_Base
## **掉落子管理器（DIM_*）的公共壳**：实例化 -> 挂父节点 -> 落点 -> 抛物线 -> 广播
##
## 四个 DIM_* 以前各写一遍这条尾巴（"父节点没配"的报错、随机落点、`DROP_ITEM_SPAWNED` 广播、
## 掉落音效），落点范围还在 `DIM_Chocolate` / `DIM_SeedPacket` 里逐字重了一份。
## 现在差异只剩三个开关（见下面三个重写点）+ 各自的"掉哪一种 / 掉在哪儿"。
##
## 子类要重写：
##   `get_drop_parent()`  挂到哪个父节点（各 DIM 的导出字段不同，改名要连 .tscn 一起改）
##   `is_gate_enabled()`  受不受联机 `drop_gate` 约束（随机掉落 = true；关卡脚本定时机 = false）
##   `is_notify_spawned()` 掉出来要不要广播（联机主机靠它下发；战斗随机掉落 = true）
##   `get_spawn_sfx()`    掉落音效名（留空不播）
##
## 关联：DropItemManager（这四位的宿主） / DropItemBase（掉落物本体的基类）

## 掉落的抛物线落点：相对出生点的水平 / 垂直偏移范围（钱 / 巧克力 / 种子包共用同一套）
const TARGET_MOVE_X_RANGE := Vector2(-50.0, 50.0)
const TARGET_MOVE_Y_RANGE := Vector2(80.0, 90.0)


## 掉落物挂到哪个父节点下
func get_drop_parent() -> Node2D:
	return null


## 受不受联机闸门约束：true = 客户端一件都不掉（"掉不掉"由主机下发）
func is_gate_enabled() -> bool:
	return true


## 掉出来要不要广播"多了这一件"（联机主机靠它下发；单机没人连，发了也无事）
func is_notify_spawned() -> bool:
	return true


## 掉落时播的音效名（见 SoundManager.play_other_SFX），留空不播
func get_spawn_sfx() -> String:
	return ""


## 闸门被占住时（联机客户端）这一件不掉：
## "这只僵尸死了掉什么"是战斗逻辑，客户端不该自己判、更不该自己摇 `randf()`
func is_blocked() -> bool:
	if not is_gate_enabled():
		return false
	return GlobalUtils.drop_gate.is_valid() and bool(GlobalUtils.drop_gate.call())


## 实例化并挂上场：父节点 / 场景 / 类型三处没配对都在这里报错（以前各家报得参差不齐）
## 返回挂上去的掉落物，失败返回 null
##
## ⚠️ 要改**入树之前才生效**的那几个字段（编号 `entity_id`、存在时长 `auto_free_time`、
## 提示时长 `tip_show_time`：`_ready()` 当场就按它们起定时器 / 分编号），
## 请用 `create_drop()` + `add_drop()` 两步，别用这一条
func instantiate_drop(scene: PackedScene) -> DropItemBase:
	var new_drop := create_drop(scene)
	if new_drop == null:
		return null
	if not add_drop(new_drop):
		return null
	return new_drop


## 只实例化、**不挂树**（要在入树之前塞字段时用这一条，塞完调 `add_drop()`）
func create_drop(scene: PackedScene) -> DropItemBase:
	if scene == null:
		Log.error("掉落但没有登记场景：" + str(name))
		return null
	var new_drop := scene.instantiate() as DropItemBase
	if new_drop == null:
		Log.error("掉落场景不是掉落物（DropItemBase）：" + str(scene.resource_path))
		return null
	return new_drop


## 把 `create_drop()` 出来的那件挂到父节点下；父节点没配时报错并返回 false
func add_drop(new_drop: DropItemBase) -> bool:
	var parent := get_drop_parent()
	if parent == null or not is_instance_valid(parent):
		Log.error("掉落但没有配置父节点：" + str(name))
		return false
	parent.add_child(new_drop)
	return true


## 随机落点 + 抛物线弹出：落点写进 `spawn_target`，联机两端才落在同一处
func launch_with_random_target(new_drop: DropItemBase,
		x_range := TARGET_MOVE_X_RANGE, y_range := TARGET_MOVE_Y_RANGE) -> void:
	if new_drop == null or not is_instance_valid(new_drop):
		return
	new_drop.launch(Vector2(
		randf_range(x_range.x, x_range.y),
		randf_range(y_range.x, y_range.y)))


## 落点写完之后才广播（联机主机靠它下发）
func notify_drop_spawned(new_drop: DropItemBase) -> void:
	if not is_notify_spawned() or new_drop == null or not is_instance_valid(new_drop):
		return
	EventBus.push_event(ConstEventName.DROP_ITEM_SPAWNED, [new_drop])


## 播掉落音效（没配就不播）
func play_spawn_sfx() -> void:
	var sfx := get_spawn_sfx()
	if not sfx.is_empty():
		SoundManager.play_other_SFX(sfx)
