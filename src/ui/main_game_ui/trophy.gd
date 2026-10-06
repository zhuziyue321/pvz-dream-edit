extends Node2D
class_name Trophy

@onready var pick_up_glow: Sprite2D = $PickUpGlow

@onready var all_rays: Node2D = $AllRays
@onready var glow: Node2D = $Glow

func _ready():
	TweenUtil.breath_scale_loop(pick_up_glow)  # 无限循环
	Global.save_service.save_now()

func _on_trophy_button_pressed() -> void:
	SoundManager.play_other_SFX("winmusic")
	$TrophyButton.disabled = true
	var center = get_viewport().get_visible_rect().size / 2 + Global.main_game.camera_2d.global_position
	var tween = create_tween()
	tween.tween_property(self, "position", center, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	all_rays.visible = true
	for ray in all_rays.get_children():
		var tween_rays1 = create_tween()
		# 无限循环旋转
		tween_rays1.tween_property(ray, "rotation", ray.rotation + TAU, 5.0) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

		var tween_rays2 = create_tween()
		# 无限放大
		tween_rays2.tween_property(ray, "scale", Vector2(10, 10), 5.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	glow.visible = true
	var tween_glow = create_tween()
	tween_glow.tween_property(glow, "modulate:a", 1, 5.0)

	await get_tree().create_timer(5.0).timeout
	EventBus.push_event("win_main_game")


func _on_trophy_button_mouse_entered() -> void:
	## 悬停奖杯时露出系统鼠标：自定义光标模式下系统鼠标平时是藏起来的，不露出来点不动奖杯
	if is_instance_valid(Global.main_game):
		Global.main_game.on_cursor_ui_hover_enter()
