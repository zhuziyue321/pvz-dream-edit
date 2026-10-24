extends DIM_Base
class_name DIM_SeedPacket
## 掉落管理器的子节点，掉落「首次通关拿到新植物」的种子包
## 种子包不再包在礼物盒里（Present），由本管理器直接实例化 SeedPacket
##
## 与钱那类的两个区别：**不看联机闸门、不广播** —— 它掉在关卡的结算线上，时机由关卡脚本定
## （确定性），联机那边也不接管这一条（见 NetplayDropSync 文件头关于 Present 的取舍）

## 掉落种子包的父节点
@export var all_drop_seed_packet_parent: Node2D


func get_drop_parent() -> Node2D:
	return all_drop_seed_packet_parent


func is_gate_enabled() -> bool:
	return false


func is_notify_spawned() -> bool:
	return false


func get_spawn_sfx() -> String:
	return "chime"


## 掉落种子包，返回实例化出来的种子包（调用方可以等它被拾取 / 自动消失后再继续出奖杯）
## drop_global_position：最后一只僵尸的死亡处（世界坐标，已收进可视范围）
func create_seed_packet(plant_type: StringName, tip_text:String, drop_global_position:Vector2,
		exist_time:float, tip_time:float) -> SeedPacket:
	var new_packet := create_drop(SceneRegistry.SEED_PACKET) as SeedPacket
	if new_packet == null:
		return null
	## 存在时间与提示时长要在加入场景树之前给到，节点 _ready 里就按它起定时器
	new_packet.auto_free_time = exist_time
	new_packet.tip_show_time = tip_time
	new_packet.tip_text = tip_text
	if not add_drop(new_packet):
		return null
	new_packet.set_plant(plant_type)
	new_packet.global_position = drop_global_position
	## 抛物线弹出（与金币一致）
	launch_with_random_target(new_packet)
	play_spawn_sfx()
	return new_packet
