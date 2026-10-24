extends Plant000Base
class_name Plant032MagnetShroom

@onready var magnet_component: MagnetComponent = $MagnetComponent

@export_group("动画状态")
@export var is_attack:=false

## 初始化正常出战角色信号连接
##
## ★ 动画状态由本脚本点名（该植物动画树两条转换已改为手动 travel，
##   见 `plant_magnet_shroom.tscn`），不再由 `is_attack` 表达式自动推导。
func ready_norm_signal_connect():
	super()
	magnet_component.signal_attack_start.connect(_on_attack_start)
	magnet_component.signal_attack_cd_end.connect(_on_attack_cd_end)

	signal_update_speed.connect(magnet_component.owner_update_speed)


## 开始吸附：播发射动画
func _on_attack_start():
	is_attack = true
	request_anim_state(&"Magnetshroom_shooting")


## 冷却结束：回待机
func _on_attack_cd_end():
	is_attack = false
	request_anim_state(&"Magnetshroom_idle")

