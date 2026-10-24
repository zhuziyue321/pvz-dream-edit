extends AnimComponentBase
class_name AnimComponentBobsled
## 雪橇小队：**一个角色带 4 个播放器**（本体 + 3 个附属 body），速度要一起改
##
## ★ 远端驱动（包分发）只认**本体那一个播放器**的动画名与相位 —— 快照协议里
##   一个角色只有一条 `anim` 下标。附属播放器因此按"同名动画存在就跟着播"处理：
##   同名的会跟主机对齐，不同名的（各 body 自己的那条）保持本地节奏，
##   这比"整只角色只有本体在动"更接近主机画面。

@onready var animation_player: AnimationPlayer = $"../Body/AnimationPlayer"
@onready var all_sub_bobsled_anim_player = [
	$"../Body2/AnimationPlayer",
	$"../Body4/AnimationPlayer",
	$"../Body3/AnimationPlayer"
]

func component_ready() -> void:
	## 初始化时获取动画角色原始速度
	animation_origin_speed = animation_player.speed_scale
	animation_player.animation_finished.connect(_on_animation_finished)


## 远端驱动下读本体播放器（附属播放器的进度不在协议里）
func update_current_anim() -> void:
	if _anim_probe_frame == Engine.get_frames_drawn():
		return
	_anim_probe_frame = Engine.get_frames_drawn()
	anim_name_now = &""
	anim_position_now = -1.0
	if not is_instance_valid(animation_player):
		return
	anim_name_now = animation_player.current_animation
	anim_position_now = animation_player.current_animation_position if anim_name_now != &"" else -1.0


## 本组件的播放器访问器（远端驱动 / 下标映射用本体那一个）
func get_animation_player() -> AnimationPlayer:
	return animation_player


## 远端驱动：本体播哪条，附属里有同名的也一起播
func apply_anim_index(anim_index: int) -> void:
	super(anim_index)
	_sync_sub_players(anim_name_at(anim_index))


## 远端驱动：本体对齐相位后，附属里正在播同名动画的也对齐
func apply_anim_phase(position: float) -> void:
	super(position)
	_sync_sub_players(anim_name_now, position)


func _sync_sub_players(anim_name: StringName, position: float = -1.0) -> void:
	if anim_name == &"":
		return
	for node in all_sub_bobsled_anim_player:
		var player := node as AnimationPlayer
		if player == null or not player.has_animation(anim_name):
			continue
		if player.current_animation != anim_name:
			player.play(anim_name)
		if position >= 0.0:
			player.seek(clampf(position, 0.0, maxf(player.current_animation_length, 0.0)), true)


## 更新动画速度(根据速度倍率)
func owner_update_speed(speed_factor_product:float):
	if driver == E_Driver.REMOTE:
		return
	animation_player.speed_scale = animation_origin_speed * speed_factor_product
	for sub_bobsled_anim_player in all_sub_bobsled_anim_player:
		sub_bobsled_anim_player.speed_scale = animation_origin_speed * speed_factor_product

## 更新动画速度(动画播放速度)
func update_anim_speed_scale(speed_scale:float):
	if driver == E_Driver.REMOTE:
		return
	animation_player.speed_scale = speed_scale
	for sub_bobsled_anim_player in all_sub_bobsled_anim_player:
		sub_bobsled_anim_player.speed_scale = speed_scale

## 停止动画
func stop_anim():
	animation_player.pause()
	for sub_bobsled_anim_player in all_sub_bobsled_anim_player:
		sub_bobsled_anim_player.pause()
