extends Node2D
class_name GardenFlowerPot

@export var down_plant_container:Node2D
@onready var animation_tree: AnimationTree = $AnimationTree

## 是否为水路植物
@export var is_water := false
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D
@onready var pot_glow: Sprite2D = $Body/BodyCorrect/PotGlow
@onready var pot_glow_2: Sprite2D = $Body/BodyCorrect/PotGlow2
@onready var pot_top: Sprite2D = $Body/BodyCorrect/Pot_top
## 盆口深色叠加层（原版 SetImageOverride("Pot_top", IMAGE_REANIM_POT_TOP_DARK)）
@onready var pot_top_dark: Sprite2D = $Body/BodyCorrect/Pot_top_dark

@onready var body: Node2D = $Body


## 叠加层要跟着 Pot_top 的浮动动画走：动画每帧覆写 Pot_top 的 transform，
## 所以不能直接把深色贴图塞进 Pot_top.texture（下一帧就被 AnimationTree 盖回去）
func _process(_delta: float) -> void:
	if pot_top_dark.visible:
		pot_top_dark.position = pot_top.position
		pot_top_dark.rotation = pot_top.rotation
		pot_top_dark.scale = pot_top.scale
		pot_top_dark.self_modulate = pot_top.self_modulate


## 盆口是否显示深色土（原版：WATERED / NEEDY / HAPPY 三态都是深色，只有 NEEDY_WATER 与睡着了才是普通色）
func plant_change_pot_top_dark(is_dark: bool) -> void:
	pot_top_dark.visible = is_dark and pot_top.visible
	if pot_top_dark.visible:
		pot_top_dark.position = pot_top.position
		pot_top_dark.rotation = pot_top.rotation
		pot_top_dark.scale = pot_top.scale


func _ready() -> void:
	var ori_speed = animation_tree.get("parameters/TimeScale/scale")
	var anim_random = randf_range(0.9,1.1)
	animation_tree.set("parameters/TimeScale/scale", ori_speed * anim_random)

## 植物是否"今天被照顾过"（原版 STATE_ZEN_GARDEN_HAPPY）：花盆冒光 + 粒子
## 注意：原版这个状态跟"满级"无关（满级但今天没照顾过不发光），改名会牵动调用点，函数名保持历史拼写
func plant_change_profect(is_profect:bool):
	if is_profect:
		gpu_particles_2d.emitting = true
		if is_water:
			pot_glow.visible = false
			pot_glow_2.visible = true
		else:
			pot_glow.visible = true
			pot_glow_2.visible = false
	else:
		gpu_particles_2d.emitting = false
		pot_glow.visible = false
		pot_glow_2.visible = false

func update_body_visible(curr_is_visible:bool = true):
	body.visible = curr_is_visible
	animation_tree.active = curr_is_visible
