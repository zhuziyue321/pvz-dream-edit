extends Control

@onready var viewport := $PanelContainer/MarginContainer/SubViewportContainer/SubViewport
@onready var output_display := $TextureRect
@onready var export_button := $Button


func _ready():
	# 设置 Viewport 尺寸和透明背景
	viewport.transparent_bg = true

	export_button.pressed.connect(_export_combined_image)


func _export_combined_image():
	var img: Image = viewport.get_texture().get_image()
	var path := "res://combined_result.png"
	img.save_png(path)
