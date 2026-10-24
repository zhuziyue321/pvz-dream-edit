extends AnimComponentBase
class_name AnimComponentPlayer
## 只使用AnimationPlayer和自定义状态机处理动画
##
## 与 `AnimComponentNorm` 的区别：这里没有 AnimationTree，**播哪条由代码点名**
## （僵王博士的状态机逐段编排）。所以本地驱动天然就是 `request_state()`；
## 远端驱动（包分发）只多一层"挡住本地编排"，别让状态机把包指定的动画抢回去。

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"

func component_ready() -> void:
	if not is_instance_valid(animation_player):
		Log.warn("[AnimComponentPlayer] 取不到 AnimationPlayer（宿主 %s）"
				% [String(owner.name) if owner != null else "?"])
		return
	animation_origin_speed = animation_player.speed_scale
	animation_player.animation_finished.connect(_on_animation_finished)


## 刷新当前动画：这类角色直接用 AnimationPlayer 播，`current_animation` 是准的
## （只有动画树驱动的那条路才读不到，见 `AnimComponentNorm`）
func update_current_anim() -> void:
	if _anim_probe_frame == Engine.get_frames_drawn():
		return
	_anim_probe_frame = Engine.get_frames_drawn()
	anim_name_now = &""
	anim_position_now = -1.0
	if not is_instance_valid(animation_player):
		return
	anim_name_now = animation_player.current_animation
	## ⚠️ 没在播时读 `current_animation_position` 会刷一行 ERROR，必须先判空
	anim_position_now = animation_player.current_animation_position if anim_name_now != &"" else -1.0


## 本地驱动 · 显式切状态 = 直接按名字播（僵王的状态机逐段编排，没有树可 travel）
func request_state(state: StringName) -> void:
	play_anim(state)


## 直接按动画名播放（僵王博士这类「行为由管理器逐段编排」的角色使用，不走 AnimationTree 状态机）
##
## ⚠️ 远端驱动下必须挡住：客户端的僵王仍有本地状态机在跑，它点名的动画会把
##    主机下发的包覆盖掉（"发了等于没发"）。
func play_anim(anim_name:StringName, custom_speed:float = -1.0):
	if driver == E_Driver.REMOTE:
		return
	if not is_instance_valid(animation_player):
		return
	if not animation_player.has_animation(anim_name):
		Log.error("动画不存在：" + str(anim_name))
		return
	animation_player.play(anim_name)
	if custom_speed > 0:
		animation_player.speed_scale = animation_origin_speed * custom_speed


## 本组件的播放器访问器：硬编码的 `$"../AnimationPlayer"` 收在这里，
## 远端驱动（包分发）只通过基类的下标 / 相位接口操作，不再自己找节点
func get_animation_player() -> AnimationPlayer:
	return animation_player


## 更新动画速度
func owner_update_speed(speed_factor_product:float):
	if driver == E_Driver.REMOTE:
		return
	if not is_instance_valid(animation_player):
		return
	animation_player.speed_scale = animation_origin_speed * speed_factor_product

## 更新动画速度(动画播放速度)
func update_anim_speed_scale(speed_scale:float):
	if driver == E_Driver.REMOTE:
		return
	if not is_instance_valid(animation_player):
		return
	animation_player.speed_scale = speed_scale

## 停止动画
func stop_anim():
	if not is_instance_valid(animation_player):
		return
	animation_player.pause()
