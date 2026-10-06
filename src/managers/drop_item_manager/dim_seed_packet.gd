extends Node
class_name DIM_SeedPacket
## 掉落管理器的子节点，掉落「首次通关拿到新植物」的种子包
## 与金币同一套掉落逻辑（见 DIM_Coin / Coin）：僵尸死亡处 -> 抛物线弹出 -> 落地等玩家点击
## 种子包不再包在礼物盒里（Present），由本管理器直接实例化 SeedPacket

## 掉落种子包的父节点
@export var all_drop_seed_packet_parent: Node2D

## 掉落的抛物线落点：相对出生点的水平 / 垂直偏移范围（与 DropItemComponent 的金币一致）
const TARGET_MOVE_X_RANGE := Vector2(-50.0, 50.0)
const TARGET_MOVE_Y_RANGE := Vector2(80.0, 90.0)


## 掉落种子包，返回实例化出来的种子包（调用方可以等它被拾取 / 自动消失后再继续出奖杯）
## drop_global_position：最后一只僵尸的死亡处（世界坐标，已收进可视范围）
func create_seed_packet(plant_type:int, tip_text:String, drop_global_position:Vector2,
		exist_time:float, tip_time:float) -> SeedPacket:
	if all_drop_seed_packet_parent == null:
		Log.error("掉落种子包但没有配置 all_drop_seed_packet_parent")
		return null
	var new_packet: SeedPacket = SceneRegistry.SEED_PACKET.instantiate()
	## 存在时间与提示时长要在加入场景树之前给到，节点 _ready 里就按它起定时器
	new_packet.auto_free_time = exist_time
	new_packet.tip_show_time = tip_time
	new_packet.tip_text = tip_text

	all_drop_seed_packet_parent.add_child(new_packet)
	new_packet.set_plant(plant_type)
	new_packet.global_position = drop_global_position
	## 抛物线弹出（与金币一致）
	new_packet.launch(Vector2(
		randf_range(TARGET_MOVE_X_RANGE.x, TARGET_MOVE_X_RANGE.y),
		randf_range(TARGET_MOVE_Y_RANGE.x, TARGET_MOVE_Y_RANGE.y)))
	SoundManager.play_other_SFX("chime")
	return new_packet
