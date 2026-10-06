extends Node2D
class_name SeedPacket
## 冒险模式首次通关拿到新植物时、由僵尸掉落的种子包
##
## 视觉与出战卡片（src/ui/card/card.tscn）完全一致 —— 卡片是 50x70，这里整体放大 2 倍：
##   底图        ：与卡片同一张 card_bg（data/ui/card_bg/norm.tres），100x140
##   植物缩放    ：PLANT_SCALE = 1.0（卡片里是 0.5）
##   植物挂点    ：PlantContainer = (0, 18)，等于卡片的 (25, 44) 乘 2 再减去半个底图
##   底部文本    ：阳光花费，字号 20（卡片 10）、黑色右对齐，位置同样是卡片 Cost 的 2 倍
##
## 掉落逻辑与金币一致（见 component_drop_item.gd / dim_coin.gd / coin.gd）：
##   僵尸死亡处 -> 抛物线弹出 -> 落地等玩家点击 -> 点开后飞向出战卡槽并弹解锁提示
## 由 DropItemManager.dim_seed_packet 实例化，掉落点是最后一只僵尸的死亡处

## 点开后显示的提示文本
@export var tip_text := ""
## 提示文本停留的秒数
@export var tip_show_time := 4.0
## 未被点击时自动消失的秒数
@export var auto_free_time := 15.0

## 抛物线飞行时间（与 Coin 同参数）
@export var duration := 1.0
## 抛物线的最大高度
@export var peak_height := 70.0

## 种子包大小：卡片 50x70 的 2 倍，点击区域按它来
const PACKET_SIZE := Vector2(100, 140)
## 卡片里的植物是原始尺寸的一半，底图放大 2 倍后这里是 1.0
const PLANT_SCALE := Vector2(1.0, 1.0)

## 是否已经打开（被拾取），避免自动收集与手动点击重复触发
var is_opened := false
## 是否是「本关结算线」上的掉落物（由 DropItemManager.create_adventure_reward_drop 标记）
## true 表示玩家点开它之后本关就结束了：交给 CanvasLayerWhiteScreen 播
## 「移向屏幕中央 -> 发光 -> 屏幕逐渐变白 -> 完全白了结算」，不再飞向出战卡槽
var is_level_complete_drop := false

var _tween: Tween = null

@onready var plant_container: Node2D = $PlantContainer
@onready var cost_label: Label = $Cost
@onready var texture_button: TextureButton = $TextureButton
@onready var pick_up_glow: Sprite2D = $PickUpGlow


func _ready() -> void:
	texture_button.pressed.connect(_on_texture_button_pressed)
	## 拾取光晕呼吸，提示玩家可以点
	TweenUtil.breath_scale_loop(pick_up_glow)

	await get_tree().create_timer(auto_free_time).timeout
	if not is_opened:
		fade_and_delete()


## 在种子包上放一株展示态植物，并在底部写上它的阳光花费（与出战卡片一致）
## 必须在加入场景树之后调用（要用到 @onready 的挂点）
func set_plant(plant_type:int) -> void:
	cost_label.text = str(int(Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.SunCost)))
	var plant_scene = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	if plant_scene == null:
		Log.error("种子包：植物没有配置场景 " + str(plant_type))
		return
	## 展示态不跑出战逻辑（与选关界面 / 图鉴里的植物一致），init 在 add_child 之前由工厂完成
	var plant := CharacterShowFactory.create_show_plant(plant_type, plant_container)
	if plant == null:
		return
	plant.scale = PLANT_SCALE


## 抛物线弹出（与 Coin.launch 一致，relative_target 是相对当前位置的落点偏移）
func launch(relative_target: Vector2) -> void:
	_tween = TweenUtil.parabola_launch(self, relative_target, duration, peak_height)

	await _tween.finished
	_tween = null
	## 开启自动收集金币时落地即拾取（与金币 / 礼包一致）
	if Global.config_service.auto_collect_coin:
		_on_texture_button_pressed()


## 点击拾取：弹解锁提示 -> 飞向出战卡槽 -> 淡出
## 本关结算线上的种子包改走 CanvasLayerWhiteScreen 的收尾表演，本体由它在白屏到底时释放
func _on_texture_button_pressed() -> void:
	if is_opened:
		return
	is_opened = true
	SoundManager.play_other_SFX("prize")
	## 打断抛物线
	TweenUtil.kill_tween(_tween)
	_tween = null
	texture_button.queue_free()

	if not tip_text.is_empty():
		var reminder_info: ReminderInformation = SceneRegistry.REMINDER_INFORMATION.instantiate()
		get_tree().current_scene.add_child(reminder_info)
		reminder_info._init_info([tip_text], tip_show_time)

	if is_level_complete_drop:
		EventBus.push_event("level_complete_pickup", [self])
		return

	var target_position := get_card_slot_target()
	if target_position != Vector2.ZERO:
		var fly_tween := create_tween()
		fly_tween.tween_property(self, "global_position", target_position, 0.5)
		await fly_tween.finished

	var fade_tween := create_tween()
	fade_tween.set_parallel()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	fade_tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.5)
	await fade_tween.finished
	queue_free()


## 拾取后飞向的目标：出战卡槽（与阳光一致，见 sun.gd）
## 拿不到卡槽位置时返回 Vector2.ZERO，调用方改成原地淡出
func get_card_slot_target() -> Vector2:
	if not is_instance_valid(Global.main_game):
		return Vector2.ZERO
	if is_instance_valid(Global.main_game.marker_2d_sun_target):
		## 卡槽在 canvaslayer 中，位置和摄像头位置有偏移
		return Global.main_game.marker_2d_sun_target.global_position \
			+ Global.main_game.camera_2d.global_position
	if is_instance_valid(Global.main_game.marker_2d_sun_target_default):
		return Global.main_game.marker_2d_sun_target_default.global_position
	return Vector2.ZERO


func fade_and_delete() -> void:
	TweenUtil.fade_out_and_free(self)
