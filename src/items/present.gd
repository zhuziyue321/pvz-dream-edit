extends Node2D
class_name Present
## 掉落的礼包
## 三种用途:
##   1. 花园植物礼包(is_garden_plant = true,僵尸死亡概率掉落,默认)
##   2. 关卡掉落的解锁道具(is_garden_plant = false,时机由关卡数据决定:
##      drop_unlock_on_level_complete = true 在通关时掉,否则由 drop_unlock_wave 指定波次的僵尸携带,
##      拾取后显示 drop_unlock_tip 配置的解锁提示)
##   3. 同上但换成自定义贴图(icon_texture),如冒险 3-4 掉落的疯狂戴夫车钥匙、1-4 的铲子
##      （拿到新植物掉的是种子包 SeedPacket,由 DropItemManager.dim_seed_packet 直接掉,不包礼物盒）

## 默认的花园植物礼包提示文本（原版见 data/strings/lawn_strings.txt）
const TIP_NEW_GARDEN_PLANT := "你为你的花园找到一株新植物"

## 打开后的提示文本，留空时使用默认的花园植物文案
@export var open_tip_text: String = ""
## 掉落物贴图，留空用默认的礼物盒（车钥匙 / 铲子等解锁道具传对应贴图）
@export var icon_texture: Texture2D
## 是否为花园植物礼包：false 表示解锁类礼包，不计入花园植物数量也不写存档
@export var is_garden_plant := true
## 未被点击时自动消失的秒数（解锁类礼包的提示更长，可以配得更久）
@export var auto_free_time := 10.0
## 提示文本停留的秒数
@export var tip_show_time := 2.0

## 是否已经打开，避免自动收集与手动点击重复触发
var is_opened := false
## 是否是「本关结算线」上的掉落物（由 DropItemManager.create_adventure_reward_drop 标记）
## true 表示玩家点开它之后本关就结束了：交给 CanvasLayerWhiteScreen 播
## 「移向屏幕中央 -> 发光 -> 屏幕逐渐变白 -> 完全白了结算」，不再走下面的普通拾取表现
var is_level_complete_drop := false

@onready var pick_up_glow: Sprite2D = $PickUpGlow

@onready var present: Sprite2D = $Present
@onready var present_open: Sprite2D = $PresentOpen
@onready var flower_pot: Node2D = $PresentOpen/FlowerPot
@onready var texture_button: TextureButton = $TextureButton
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

func _ready():
	apply_icon_texture()
	TweenUtil.breath_scale_loop(pick_up_glow)  # 无限循环

	## 自动收集金币
	if Global.config_service.auto_collect_coin:
		_on_texture_button_pressed()

	## 等待指定秒数未点击删除（已打开时由打开流程自行释放）
	await get_tree().create_timer(auto_free_time).timeout
	if not is_opened:
		queue_free()


func _on_texture_button_pressed() -> void:
	if is_opened:
		return
	is_opened = true
	SoundManager.play_other_SFX("prize")

	var reminder_info :ReminderInformation =  SceneRegistry.REMINDER_INFORMATION.instantiate()
	get_tree().current_scene.add_child(reminder_info)
	reminder_info._init_info([get_open_tip_text()], tip_show_time)

	if is_garden_plant:
		Global.global_game_state.curr_num_new_garden_plant += 1
		Global.save_service.save_now()

	## 本关结算线上的掉落物：收尾表演由 CanvasLayerWhiteScreen 接管，本体也由它在白屏到底时释放
	if is_level_complete_drop:
		EventBus.push_event("level_complete_pickup", [self])
		return

	texture_button.visible = false
	gpu_particles_2d.emitting = true
	## 换成自定义贴图的解锁道具（车钥匙、铲子）没有"打开的盒子"这一态，只有拾取特效
	var has_open_box := icon_texture == null
	present_open.visible = has_open_box
	flower_pot.visible = has_open_box and is_garden_plant

	await gpu_particles_2d.finished
	queue_free()


## 用关卡配置的贴图替换礼物盒，并把点击区域改成贴图大小
func apply_icon_texture() -> void:
	if icon_texture == null:
		return
	texture_button.texture_normal = icon_texture
	## 礼物盒的点击遮罩不适用于自定义贴图，改为整块矩形可点
	texture_button.texture_click_mask = null
	var icon_size := icon_texture.get_size()
	texture_button.offset_left = -icon_size.x / 2.0
	texture_button.offset_right = icon_size.x / 2.0
	texture_button.offset_top = -icon_size.y / 2.0
	texture_button.offset_bottom = icon_size.y / 2.0



## 打开礼包后显示的提示文本
func get_open_tip_text() -> String:
	if open_tip_text.is_empty():
		return TIP_NEW_GARDEN_PLANT
	return open_tip_text

