extends Node2D

@onready var almanac_ground_pool: Sprite2D = $AlmanacGroundPool
@onready var almanac_ground_roof: Sprite2D = $AlmanacGroundRoof
@onready var control: Control = $Control


@onready var area_2d_2: Area2D = $AlmanacGroundRoof/Area2D2


var a:Array[Node2D] = []
# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#remove_child(almanac_ground_pool)
	#control.add_child(almanac_ground_pool)
#
#

func _on_area_2d_area_entered(_area: Area2D) -> void:
	prints("检测到区域2")


func _on_area_2d_area_exited(_area: Area2D) -> void:
	prints("检测到区域2离开")


func _on_button_pressed() -> void:
	var b = Node2D.new()
	a.append(b)
	b.queue_free()
	var c = Node2D.new()
	a.append(c)
	await get_tree().process_frame
	prints(is_instance_valid(a[0]), is_instance_valid(a[1]))

func _on_area_2d_2_area_entered(_area: Area2D) -> void:
	pass # Replace with function body.
