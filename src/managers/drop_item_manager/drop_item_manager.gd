extends MainGameSubManager
class_name DropItemManager
## 掉落道具管理器, 管理掉落金币、花盆、关卡中途掉落的解锁道具
## 主游戏场景和花园场景使用

## 解锁道具未被点击时的存在秒数（提示文本比花园植物长，给足阅读时间）
const UNLOCK_DROP_EXIST_TIME := 15.0
## 解锁提示文本的停留秒数
const UNLOCK_DROP_TIP_TIME := 4.0

@onready var dim_garden_plant: DIM_GardenPlant = $DIM_GardenPlant
@onready var dim_coin: DIM_Coin = $DIM_Coin
@onready var dim_seed_packet: DIM_SeedPacket = $DIM_SeedPacket
@onready var dim_chocolate: DIM_Chocolate = $DIM_Chocolate


func _ready() -> void:
	EventBus.subscribe("gold_magnet_attract_once", gold_magnet_attract_once)
	## 关卡中途掉落的解锁道具（由僵尸波次管理器在携带道具的僵尸死亡时推送）
	EventBus.subscribe("create_unlock_drop", create_unlock_drop)
	## 僵尸掉的巧克力（买了蜗牛之后才掉，见 DropItemComponent.drop_chocolate）
	EventBus.subscribe("create_chocolate", create_chocolate)

func init_manager() -> void:
	pass

## 吸金磁 吸引金币一次
func gold_magnet_attract_once(target_pos:Vector2):
	for c in dim_coin.all_drop_coin_parent.get_children():
		if c is Coin:
			c.be_attract_gold_magnet(target_pos)


## 掉落关卡中途的解锁道具（原版：冒险 3-2 掉礼物盒解锁迷你游戏）
## 掉落位置为携带道具的僵尸死亡处，提示文本与贴图取自关卡数据的 drop_unlock_tip / drop_unlock_icon
func create_unlock_drop(drop_global_position:Vector2):
	create_unlock_drop_present(drop_global_position)
	Log.debug("关卡中途掉落解锁道具")


## 僵尸掉的巧克力（买了蜗牛之后才会掉，见 DropItemComponent.drop_chocolate）
## 落点与种子包一样先收进可视范围：巧克力只有 57x66，掉到画面外就点不到了
## 返回实例化出来的掉落物，没有配置父节点时为 null
func create_chocolate(drop_global_position: Vector2) -> Node2D:
	if dim_chocolate == null:
		return null
	var new_drop := dim_chocolate.create_chocolate(
		get_clamp_drop_position(drop_global_position, CHOCOLATE_DROP_EDGE_MARGIN))
	if new_drop != null:
		Log.debug("僵尸掉落巧克力")
	return new_drop


## 掉落关卡结束时的解锁道具（原版：冒险 3-4 通关掉车钥匙解锁商店）
## 与中途掉落共用一套实例化逻辑，区别只在掉落的时机与位置来源（最后一只僵尸死亡处）
## 返回实例化出来的道具，调用方可以等它被拾取 / 自动消失后再继续出奖杯
func create_unlock_drop_on_level_complete(drop_global_position:Vector2) -> Present:
	var new_drop := create_unlock_drop_present(drop_global_position)
	if new_drop == null:
		return null
	Log.debug("关卡结束掉落解锁道具")
	return new_drop


## 实例化一个解锁类礼包（is_garden_plant = false：不计入花园植物数量、不写存档）
## 提示文本、贴图优先用传进来的（冒险模式通关奖励），没传则取关卡数据的
## drop_unlock_tip / drop_unlock_icon，位置收进可视范围
func create_unlock_drop_present(drop_global_position:Vector2, tip_text := "", icon_texture: Texture2D = null) -> Present:
	if dim_garden_plant == null or dim_garden_plant.all_drop_garden_plant_parent == null:
		return null
	if tip_text.is_empty() and game_para != null:
		tip_text = game_para.drop_unlock_tip
		icon_texture = game_para.drop_unlock_icon
	if tip_text.is_empty():
		Log.warn("关卡配置了掉落解锁道具，但没有填写 drop_unlock_tip，已跳过")
		return null

	var new_drop:Present = SceneRegistry.PRESENT.instantiate()
	new_drop.is_garden_plant = false
	new_drop.auto_free_time = UNLOCK_DROP_EXIST_TIME
	new_drop.tip_show_time = UNLOCK_DROP_TIP_TIME
	new_drop.open_tip_text = tip_text
	new_drop.icon_texture = icon_texture

	dim_garden_plant.all_drop_garden_plant_parent.add_child(new_drop)
	new_drop.global_position = get_clamp_drop_position(drop_global_position)
	SoundManager.play_other_SFX("chime")
	return new_drop


## 掉落冒险模式本关的「首次通关奖励」（原版：通关后戴夫给的礼物盒 / 铲子 / 车钥匙 / 玉米卷）
## 奖励内容优先取关卡资源的 drop_unlock_on_level_complete（3-4 车钥匙 / 4-4 玉米卷），
## 没配的关卡再查 ConstAdventureReward（与选关界面「本关看点」同一套表）
## 道具类奖励（铲子等）走礼物盒 Present，植物类奖励走僵尸掉的种子包 SeedPacket
## 返回 null 表示本关没有奖励
func create_adventure_reward_drop(drop_global_position:Vector2) -> Node2D:
	if game_para == null:
		return null
	## 关卡资源显式配了通关掉落：以关卡资源的贴图与提示为准
	if game_para.drop_unlock_on_level_complete and not game_para.drop_unlock_tip.is_empty():
		return mark_level_complete_drop(create_unlock_drop_on_level_complete(drop_global_position))
	var adventure_level: int = Global.global_game_state.get_adventure_level_on_save_game_name(
		game_para.save_game_name)
	var reward: Dictionary = ConstAdventureReward.get_reward(adventure_level)
	if reward.is_empty():
		return null
	var tip_text := String(reward.get(ConstAdventureReward.KEY_TIP, ""))
	var icon_texture: Texture2D = reward.get(ConstAdventureReward.KEY_ICON, null)
	## 植物奖励：由僵尸掉一包种子（视觉同出战卡片，逻辑同金币），不走礼物盒
	if int(reward.get(ConstAdventureReward.KEY_TYPE, -1)) == ConstAdventureReward.E_RewardType.Plant:
		var plant_type := int(reward.get(ConstAdventureReward.KEY_PLANT_TYPE, 0))
		tip_text = tip_text % get_plant_show_name(plant_type)
		if dim_seed_packet == null:
			return null
		var new_packet := dim_seed_packet.create_seed_packet(plant_type, tip_text,
			get_clamp_drop_position(drop_global_position, SeedPacket.PACKET_SIZE.x / 2.0),
			UNLOCK_DROP_EXIST_TIME, UNLOCK_DROP_TIP_TIME)
		if new_packet != null:
			Log.debug("掉落本关首次通关奖励：" + tip_text)
		return mark_level_complete_drop(new_packet)
	var new_drop := create_unlock_drop_present(drop_global_position, tip_text, icon_texture)
	if new_drop != null:
		Log.debug("掉落本关首次通关奖励：" + tip_text)
	return mark_level_complete_drop(new_drop)


## 标记成「本关结算线」上的掉落物：点开它之后本关就结束了（见 Present / SeedPacket 的
## is_level_complete_drop），点开后播「移向屏幕中央 -> 发光 -> 屏幕逐渐变白 -> 完全白了结算」
## 而不是普通拾取表现。只有这条奖励线适用 —— 通关解锁道具（3-4 车钥匙等）点开后还要抛奖杯，不能标记
func mark_level_complete_drop(new_drop: Node2D) -> Node2D:
	if new_drop != null:
		new_drop.set("is_level_complete_drop", true)
	return new_drop


## 取植物的中文名（图鉴数据），取不到时退回植物注册名
func get_plant_show_name(plant_type:int) -> String:
	Global.global_read_data.ensure_almanac_loaded()
	var plant_name := String(Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantName))
	var all_plant_data: Dictionary = Global.global_read_data.data_almanac.get("Plant", {})
	var plant_data: Dictionary = all_plant_data.get(plant_name, {})
	return String(plant_data.get("名字", plant_name))


## 掉落位置留出的边距：礼包的点击区约 80x80（present.tscn 的 TextureButton），
## 夹在最边上会有一半身在画面外、点不中，所以往里收半个礼盒
const DROP_EDGE_MARGIN := 40.0
## 巧克力掉落物的半个身位（贴图 57x66，见 assets/image/garden/chocolate.png）
const CHOCOLATE_DROP_EDGE_MARGIN := 30.0

## 把掉落位置收进**看得见的范围内**，避免掉落物掉在屏幕外玩家点不到
## 画布是有偏移的（相机跟随 / 关卡根节点挪过 / 开场那趟展示动画），屏幕左上角并不对应世界原点，
## 直接拿视口尺寸去夹，画面右侧这 150 像素范围里的掉落物都会跑到屏幕外 —— 只能眼看它 15 秒后消失
## edge_margin：掉落物自身半个身位（礼包约 40、种子包 50），不传就用礼包的
func get_clamp_drop_position(drop_global_position:Vector2, edge_margin := DROP_EDGE_MARGIN) -> Vector2:
	var rect := get_viewport_visible_rect().grow(-edge_margin)
	var min_pos := rect.position
	var max_pos := Vector2(maxf(rect.end.x, min_pos.x), maxf(rect.end.y, min_pos.y))
	return Vector2(
		clampf(drop_global_position.x, min_pos.x, max_pos.x),
		clampf(drop_global_position.y - 50.0, min_pos.y, max_pos.y)
	)


## 当前视口能看见的那块世界矩形（掉落物用的是世界坐标，必须换算回去再夹）
## 没有画布偏移时它等于视口矩形，与直接按视口尺寸夹的结果一致
func get_viewport_visible_rect() -> Rect2:
	var screen_rect := get_viewport().get_visible_rect()
	var to_world := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := to_world * screen_rect.position
	var bottom_right := to_world * (screen_rect.position + screen_rect.size)
	return Rect2(top_left, bottom_right - top_left)
