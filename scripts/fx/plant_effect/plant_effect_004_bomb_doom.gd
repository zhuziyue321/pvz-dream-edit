extends BombEffectBase
class_name BombEffectDoom

## 爆炸动画播放器,场景内尚未配置该节点时为空(毁灭菇爆炸动画待补)
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

func activate_bomb_effect():
	super()
	EventBus.push_event("canvas_layer_effect_once", [CanvasLayerEffect.E_CanvasLayerEffectType.Doom])

	if not is_instance_valid(animation_player):
		queue_free()
		return

	animation_player.play("idle")
	await animation_player.animation_finished
	queue_free()
