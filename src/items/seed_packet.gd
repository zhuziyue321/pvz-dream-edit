extends DropItemBase
class_name SeedPacket
## 冒险模式首次通关拿到新植物时、由僵尸掉落的种子包
##
## 视觉与出战卡片（src/ui/card/card.tscn）完全一致 —— 卡片是 50x70，这里整体放大 2 倍：
##   底图        ：与卡片同一张 card_bg（data/ui/card_bg/norm.tres，50x70），Sprite2D 放大 2 倍 → 100x140
##   植物缩放    ：PLANT_SCALE = 1.0（卡片里是 0.5）
##   植物挂点    ：PlantContainer = (0, 18)，等于卡片的 (25, 44) 乘 2 再减去半个底图
##   底部文本    ：阳光花费，字号 20（卡片 10）、黑色右对齐，位置同样是卡片 Cost 的 2 倍
##
## 掉落逻辑与金币一致（见 component_drop_item.gd / dim_coin.gd）：
##   僵尸死亡处 -> 抛物线弹出 -> 落地等玩家点击 -> 点开后飞向出战卡槽并弹解锁提示
## 由 DropItemManager.dim_seed_packet 实例化，掉落点是最后一只僵尸的死亡处

## 点开后显示的提示文本
@export var tip_text := ""

## 种子包大小：卡片 50x70 的 2 倍，点击区域按它来
const PACKET_SIZE := Vector2(100, 140)
## 卡片里的植物是原始尺寸的一半，底图放大 2 倍后这里是 1.0
const PLANT_SCALE := Vector2(1.0, 1.0)

@onready var plant_container: Node2D = $PlantContainer
@onready var cost_label: Label = $Cost
@onready var texture_button: TextureButton = $TextureButton


## 在种子包上放一株展示态植物，并在底部写上它的阳光花费（与出战卡片一致）
## 必须在加入场景树之后调用（要用到 @onready 的挂点）
func set_plant(plant_type: StringName) -> void:
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


## 点开拾取：弹解锁提示 -> 飞向出战卡槽 -> 淡出
## 本关结算线上的种子包改走 CanvasLayerWhiteScreen 的收尾表演，本体由它在白屏到底时释放
func pick() -> void:
	if is_opened:
		return
	is_opened = true
	SoundManager.play_other_SFX("prize")
	## 打断抛物线
	kill_launch_tween()
	texture_button.queue_free()

	if not tip_text.is_empty():
		var reminder_info: ReminderInformation = SceneRegistry.REMINDER_INFORMATION.instantiate()
		get_tree().current_scene.add_child(reminder_info)
		reminder_info._init_info([tip_text], tip_show_time)

	if is_level_complete_drop:
		EventBus.push_event(ConstEventName.LEVEL_COMPLETE_PICKUP, [self])
		return

	## 拿不到卡槽位置（get_card_slot_target 返回 ZERO）时原地淡出
	fly_to_target(get_card_slot_target())


## 老名字的入口（探针直接点种子包时调）：一律走 `pick()`
func _on_texture_button_pressed() -> void:
	pick()


## 拾取后飞向的目标：出战卡槽（与阳光一致，见 sun.gd）
## 拿不到卡槽位置时返回 Vector2.ZERO，调用方改成原地淡出
func get_card_slot_target() -> Vector2:
	if not is_instance_valid(GameContext.curr_main_game):
		return Vector2.ZERO
	if is_instance_valid(GameContext.curr_main_game.marker_2d_sun_target):
		## 卡槽在 canvaslayer 中，位置和摄像头位置有偏移
		return GameContext.curr_main_game.marker_2d_sun_target.global_position \
			+ GameContext.curr_main_game.camera_2d.global_position
	if is_instance_valid(GameContext.curr_main_game.marker_2d_sun_target_default):
		return GameContext.curr_main_game.marker_2d_sun_target_default.global_position
	return Vector2.ZERO
