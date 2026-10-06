extends Sprite2D
class_name ZombiquariumBrain
## 僵尸水族馆里喂僵尸的「脑子」
##
## 点鱼缸造一个脑子（花 ConstZombiquarium.BRAIN_SUN_COST 阳光），脑子从落点慢慢往下沉，
## 沉到缸底还没被吃掉就消失 —— 那一份阳光就白花了（原版表现，见灰机wiki「脑子掉到水底后会消失」）。
## 贴图: res://assets/image/main_game_item/brain.png

## 下沉速度（像素/秒）
const SINK_SPEED := 26.0
## 沉到缸底后淡出的时长（秒）
const FADE_TIME := 0.5

## 脑子没了（沉到缸底 / 被吃掉），管理器据此把僵尸的目标清掉
signal signal_brain_gone(brain: ZombiquariumBrain)

## 沉到这个 y（相对水族馆节点）就算到缸底
var bottom_y := 545.0
## 是否已经被吃掉（被吃掉时管理器补一次消失表现）
var is_eaten := false


func _process(delta: float) -> void:
	position.y += SINK_SPEED * delta
	if position.y < bottom_y:
		return
	## 沉到缸底：淡出后消失，这一份阳光白花了
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	signal_brain_gone.emit(self)
	queue_free()


## 被僵尸吃掉：发信号后直接消失（咬的那口由僵尸的动画表现）
func be_eaten() -> void:
	if is_eaten:
		return
	is_eaten = true
	set_process(false)
	signal_brain_gone.emit(self)
	queue_free()
