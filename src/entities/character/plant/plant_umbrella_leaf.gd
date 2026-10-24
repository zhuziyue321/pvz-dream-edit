extends Plant000Base
class_name Plant038UmbrellaLeaf

@export var is_activate_umbrella:=false

func _on_area_2d_umbrella_area_entered(area: Area2D) -> void:
	var area_owner = area.owner
	## 如果是蹦极僵尸
	if area_owner is Zombie021Bungi:
		is_activate_umbrella = true
		## ★ 动画状态由本脚本点名（该转换已改为手动 travel，见 `plant_umbrella_leaf.tscn`）
		request_anim_state(&"Umbrellaleaf_block")
		area_owner.be_umbrella_leaf()

func activete_umbrella():
	z_index = 101
	is_activate_umbrella = true
	request_anim_state(&"Umbrellaleaf_block")

## 激活保护伞一次,动画调用
func activate_umbrella_once():
	is_activate_umbrella = false
	z_index = 0


