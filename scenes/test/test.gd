extends Node2D

@onready var almanac_ground_pool: Sprite2D = $AlmanacGroundPool
@onready var almanac_ground_roof: Sprite2D = $AlmanacGroundRoof
@onready var control: Control = $Control


@onready var area_2d_2: Area2D = $AlmanacGroundRoof/Area2D2


var a:Array[Node2D] = []
# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#Log.debug(str("移动前位置") + str(almanac_ground_pool.position))
	#Log.debug(str("移动前全局位置") + str(almanac_ground_pool.global_position))
	#remove_child(almanac_ground_pool)
	#control.add_child(almanac_ground_pool)
#
	#Log.debug(str("移动后位置") + str(almanac_ground_pool.position))
	#Log.debug(str("移动后全局位置") + str(almanac_ground_pool.global_position))
#

func _on_area_2d_area_entered(area: Area2D) -> void:
	prints("检测到区域2")
	Log.debug(area.get_parent().name)


func _on_area_2d_area_exited(area: Area2D) -> void:
	prints("检测到区域2离开")


func _on_button_pressed() -> void:
	Log.debug("点击按钮")
	Log.debug(a)
	var b = Node2D.new()
	a.append(b)
	Log.debug(a)
	b.queue_free()
	var c = Node2D.new()
	a.append(c)
	await get_tree().process_frame
	Log.debug(a)
	prints(is_instance_valid(a[0]), is_instance_valid(a[1]))

func _on_area_2d_2_area_entered(area: Area2D) -> void:
	Log.debug("区域2检测到区域一")
	pass # Replace with function body.
