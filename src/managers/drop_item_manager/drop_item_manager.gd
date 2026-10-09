extends MainGameSubManager
class_name DropItemManager
## 掉落道具管理器, 管理掉落金币、花盆、关卡中途掉落的解锁道具
## 主游戏场景和花园场景使用

## 战利品的**种类**（联机下发要说清"掉了哪一件"，见 `create_drop_of_kind`）
enum E_DropKind{
	Silver,		## 银币
	Gold,		## 金币
	Diamond,	## 钻石
	Chocolate,	## 巧克力
}

## 解锁道具未被点击时的存在秒数（提示文本比花园植物长，给足阅读时间）
const UNLOCK_DROP_EXIST_TIME := 15.0
## 解锁提示文本的停留秒数
const UNLOCK_DROP_TIP_TIME := 4.0
## 战利品未被点击时的存在秒数（比解锁道具再长一点：它是本关的收尾，玩家可能在看别处）
const LOOT_EXIST_TIME := 20.0
## 战利品提示文本的停留秒数
const LOOT_TIP_TIME := 4.0
## 植物类通关奖励的提示文本模板（%s = 植物中文名，原版 lawn_strings [NEW_PLANT]）
const TIP_NEW_PLANT := "你得到一株新植物：%s！"

@onready var dim_garden_plant: DIM_GardenPlant = $DIM_GardenPlant
@onready var dim_coin: DIM_Coin = $DIM_Coin
@onready var dim_seed_packet: DIM_SeedPacket = $DIM_SeedPacket
@onready var dim_chocolate: DIM_Chocolate = $DIM_Chocolate


func _ready() -> void:
	EventBus.subscribe(ConstEventName.GOLD_MAGNET_ATTRACT_ONCE, gold_magnet_attract_once)
	## 关卡中途掉落的解锁道具（由僵尸波次管理器在携带道具的僵尸死亡时推送）
	EventBus.subscribe(ConstEventName.CREATE_UNLOCK_DROP, create_unlock_drop)
	## 僵尸掉的巧克力（买了蜗牛之后才掉，见 DropItemComponent.drop_chocolate）
	EventBus.subscribe(ConstEventName.CREATE_CHOCOLATE, create_chocolate)

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


## 按**给定的种类 / 编号 / 起点 / 落点**掉一件战利品（通用口，不带联机字样）
##
## 与 `create_chocolate()` 那条普通入口的区别：**一个随机数都不摇** ——
## 种类、编号、起点、落点全由调用方给定，原样长出同一件。
## 单机没人调（照旧走随机那条）；联机客户端照主机下发的数据重建掉落物时用它
## （"掉不掉、掉哪一种"是战斗逻辑，客户端不该自己判，见 `GlobalUtils.drop_gate`）。
func create_drop_of_kind(kind: int, drop_entity_id: int, from_pos: Vector2, to_pos: Vector2) -> Node2D:
	var relative_target := to_pos - from_pos
	match kind:
		E_DropKind.Silver, E_DropKind.Gold, E_DropKind.Diamond:
			if dim_coin == null or dim_coin.all_drop_coin_parent == null:
				return null
			if not is_instance_valid(dim_coin.coin_bank_label):
				return null
			var scene: PackedScene = SceneRegistry.COIN_SILVER
			if kind == E_DropKind.Gold:
				scene = SceneRegistry.COIN_GOLD
			elif kind == E_DropKind.Diamond:
				scene = SceneRegistry.COIN_DIAMOND
			var coin: Coin = scene.instantiate()
			## 编号在入树**之前**塞进去：`_ready()` 看到非 0 就不再自己分配，两端才是同一枚
			coin.assign_entity_id(drop_entity_id)
			coin.drop_kind = kind
			dim_coin.all_drop_coin_parent.add_child(coin)
			coin.setup(dim_coin.coin_bank_label.marker_2d_coin_target.global_position)
			coin.global_position = from_pos
			coin.spawn_target = to_pos
			coin.launch(relative_target)
			return coin
		E_DropKind.Chocolate:
			if dim_chocolate == null or dim_chocolate.all_drop_chocolate_parent == null:
				return null
			var chocolate: ChocolateDrop = SceneRegistry.CHOCOLATE_DROP.instantiate()
			chocolate.assign_entity_id(drop_entity_id)
			chocolate.drop_kind = kind
			dim_chocolate.all_drop_chocolate_parent.add_child(chocolate)
			chocolate.global_position = from_pos
			chocolate.spawn_target = to_pos
			chocolate.launch(relative_target)
			return chocolate
	return null


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


## **按名字生产一个战利品掉落物** —— 「名字 -> 贴图 / 植物编号」那张表在 LootRegistry
##
## [param loot_name] 战利品名字（"trophy" / "peashooter_seed_packet" / "taco"）：
##   贴图类（有现成贴图的）掉的是换上这张贴图的礼物盒 Present；
##   种子包类（没有独立贴图的，如豌豆射手种子包）掉的是运行时拼出来的 SeedPacket。
## [param tip_text] 点开时弹的那句提示，留空时按战利品自己取：
##   种子包类 = 「你得到一株新植物：X！」，贴图类 = LootRegistry.get_tip()（都没有就不弹）。
## 点开音效取 LootRegistry.get_sfx()，没配就用掉落物自带的那个。
##
## 返回实例化出来的掉落物；**名字没登记 / 掉落容器没配时返回 null** ——
## 调用方必须兜住（直接结算），不能把玩家一直卡在场上（见 MgmRewardManager.gain_loot）。
## 掉出来之后由调用方决定它是不是「本关结算线」上的掉落物（mark_level_complete_drop）。
func create_loot_drop(loot_name: String, drop_global_position: Vector2, tip_text := "") -> Node2D:
	var plant_type := LootRegistry.get_plant_type(loot_name)
	if plant_type != CharacterRegistry.PlantType.Null:
		## 种子包类：提示文本模板里的 %s 换成植物中文名
		var seed_tip := tip_text if not tip_text.is_empty() \
			else TIP_NEW_PLANT % get_plant_show_name(plant_type)
		return _create_loot_seed_packet(plant_type, seed_tip, drop_global_position)
	var icon := LootRegistry.get_texture(loot_name)
	if icon == null:
		Log.error("掉落战利品但没有登记这个战利品名：" + loot_name)
		return null
	var item_tip := tip_text if not tip_text.is_empty() else LootRegistry.get_tip(loot_name)
	return _create_loot_present(loot_name, icon, item_tip, drop_global_position)


## 掉一包战利品种子包（豌豆射手种子包这类：本体是卡片底图 + 植物形象，见 SeedPacket）
func _create_loot_seed_packet(plant_type: int, tip_text: String, drop_global_position: Vector2) -> Node2D:
	if dim_seed_packet == null:
		return null
	return dim_seed_packet.create_seed_packet(plant_type, tip_text,
		get_clamp_drop_position(drop_global_position, SeedPacket.PACKET_SIZE.x / 2.0),
		LOOT_EXIST_TIME, LOOT_TIP_TIME)


## 掉一个战利品礼物盒：礼物盒本体换成战利品贴图（与冒险 4-4 的玉米卷同一套表现）
## 点击区按贴图大小重算（见 Present.apply_icon_texture），所以留的边距也按贴图算
func _create_loot_present(
	loot_name: String,
	icon: Texture2D,
	tip_text: String,
	drop_global_position: Vector2
) -> Node2D:
	if dim_garden_plant == null or dim_garden_plant.all_drop_garden_plant_parent == null:
		return null
	var new_drop: Present = SceneRegistry.PRESENT.instantiate()
	new_drop.is_garden_plant = false
	new_drop.auto_free_time = LOOT_EXIST_TIME
	new_drop.tip_show_time = LOOT_TIP_TIME
	new_drop.open_tip_text = tip_text
	new_drop.is_show_open_tip = not tip_text.is_empty()
	new_drop.icon_texture = icon
	var sfx := LootRegistry.get_sfx(loot_name)
	if not sfx.is_empty():
		new_drop.open_sfx = sfx

	dim_garden_plant.all_drop_garden_plant_parent.add_child(new_drop)
	new_drop.global_position = get_clamp_drop_position(drop_global_position, icon.get_size().x / 2.0)
	SoundManager.play_other_SFX("chime")
	return new_drop


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
