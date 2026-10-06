extends AnimComponentBase
class_name AnimComponentPlayer
## 只使用AnimationPlayer和自定义状态机处理动画

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"

func _ready() -> void:
	animation_origin_speed = animation_player.speed_scale
	animation_player.animation_finished.connect(_on_animation_finished)

## 直接按动画名播放（僵王博士这类「行为由管理器逐段编排」的角色使用，不走 AnimationTree 状态机）
func play_anim(anim_name:StringName, custom_speed:float = -1.0):
	if not animation_player.has_animation(anim_name):
		Log.error("动画不存在：" + str(anim_name))
		return
	animation_player.play(anim_name)
	if custom_speed > 0:
		animation_player.speed_scale = animation_origin_speed * custom_speed

## 更新动画速度
func owner_update_speed(speed_factor_product:float):
	animation_player.speed_scale = animation_origin_speed * speed_factor_product

## 更新动画速度(动画播放速度)
func update_anim_speed_scale(speed_scale:float):
	animation_player.speed_scale = speed_scale

## 停止动画
func stop_anim():
	animation_player.pause()
