extends DropItemBase
class_name Present
## 掉落的礼包
## 四种用途:
##   1. 花园植物礼包(is_garden_plant = true,僵尸死亡概率掉落,默认)
##   2. 关卡掉落的解锁道具(is_garden_plant = false,时机由关卡数据决定:
##      drop_unlock_on_level_complete = true 在通关时掉,否则由 drop_unlock_wave 指定波次的僵尸携带,
##      拾取后显示 drop_unlock_tip 配置的解锁提示)
##   3. 同上但换成自定义贴图(icon_texture),如冒险 3-4 掉落的疯狂戴夫车钥匙、1-4 的铲子
##      （拿到新植物掉的是种子包 SeedPacket,由 DropItemManager.dim_seed_packet 直接掉,不包礼物盒）
##   4. 战利品（奖杯 / 玉米卷…）：同样是「自定义贴图 + 不弹提示」，贴图由 LootRegistry 按名字给
##      （见 DropItemManager.create_loot_drop），点开后走 CanvasLayerWhiteScreen 的收尾表演
##
## 与金币那类的区别：**没有抛物线** —— 掉在哪儿就停在哪儿（has_launch_animation() = false），
## 所以开了自动收集时会当场被收走（见 DropItemBase._ready）。

## 默认的花园植物礼包提示文本（原版见 data/strings/lawn_strings.txt）
const TIP_NEW_GARDEN_PLANT := "你为你的花园找到一株新植物"

## 打开后的提示文本，留空时使用默认的花园植物文案
@export var open_tip_text: String = ""
## 打开后是否弹提示文本：纯贴图的战利品（奖杯这类）没有文案，由生产方关掉
@export var is_show_open_tip := true
## 打开时播放的音效名（见 SoundManager.play_other_SFX），战利品由 LootRegistry 指定
@export var open_sfx := "prize"
## 掉落物贴图，留空用默认的礼物盒（车钥匙 / 铲子等解锁道具传对应贴图）
## 生产方有的在入树前给（那时由 `drop_ready()` 统一应用），有的入树后才给 —— 后者靠这个 setter
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_inside_tree():
			apply_icon_texture()
## 是否为花园植物礼包：false 表示解锁类礼包，不计入花园植物数量也不写存档
@export var is_garden_plant := true

@onready var present: Sprite2D = $Present
@onready var present_open: Sprite2D = $PresentOpen
@onready var flower_pot: Node2D = $PresentOpen/FlowerPot
@onready var texture_button: TextureButton = $TextureButton
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D


func drop_ready() -> void:
	apply_icon_texture()


## 没有抛物线：掉在哪儿就停在哪儿
func has_launch_animation() -> bool:
	return false


## 点开拾取：入账（花园植物数 / 解锁）-> 弹提示 -> 开盒特效 -> 删除
## 本关结算线上的礼包改走 CanvasLayerWhiteScreen 的收尾表演，本体由它在白屏到底时释放
func pick() -> void:
	if is_opened:
		return
	is_opened = true
	SoundManager.play_other_SFX(open_sfx)

	if is_show_open_tip:
		var reminder_info :ReminderInformation =  SceneRegistry.REMINDER_INFORMATION.instantiate()
		get_tree().current_scene.add_child(reminder_info)
		reminder_info._init_info([get_open_tip_text()], tip_show_time)

	if is_garden_plant:
		## 原版礼包里是一株**已定种**的盆栽（PottedPlant::InitializePottedPlant(PickRandomSeedType())），
		## 这里在拾取时把物种一起入队，发芽期过后长成它
		Global.global_game_state.add_new_garden_plant(
			Global.global_game_state.pick_random_garden_plant_species())
		Global.save_service.save_now()

	## 本关结算线上的掉落物：收尾表演由 CanvasLayerWhiteScreen 接管，本体也由它在白屏到底时释放
	if is_level_complete_drop:
		EventBus.push_event(ConstEventName.LEVEL_COMPLETE_PICKUP, [self])
		return

	texture_button.visible = false
	gpu_particles_2d.emitting = true
	## 换成自定义贴图的解锁道具（车钥匙、铲子）没有"打开的盒子"这一态，只有拾取特效
	var has_open_box := icon_texture == null
	present_open.visible = has_open_box
	flower_pot.visible = has_open_box and is_garden_plant

	await gpu_particles_2d.finished
	queue_free()


## 老名字的入口（探针直接点礼包时调）：一律走 `pick()`
func _on_texture_button_pressed() -> void:
	pick()


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
