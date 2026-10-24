extends MainGameSubManager
class_name DropItemManager
## 掉落道具管理器, 管理掉落金币、花盆、关卡中途掉落的解锁道具
## 主游戏场景和花园场景使用

## 战利品的**种类**（联机下发要说清"掉了哪一件"，见 `create_drop_of_kind`）
## ⚠️ 定义已经搬到 `ItemRegistry.E_DropKind`（硬约束 §1-4：类型映射一律走注册表），
## 这里留一个同名的转发常量：老代码 / 联机模组都写的是 `DropItemManager.E_DropKind`。
const E_DropKind := ItemRegistry.E_DropKind

## 解锁道具未被点击时的存在秒数（提示文本比花园植物长，给足阅读时间）
const UNLOCK_DROP_EXIST_TIME := 15.0
## 解锁提示文本的停留秒数
const UNLOCK_DROP_TIP_TIME := 4.0
## **永不过期**：存在时长给这个值（0）时，掉落物不会自己消失
##
## 原版口径：关卡奖励（`Coin::IsLevelAward()`）**不会自己过期** —— 不点掉就一直留在场上，
## 靠上方那个弹跳箭头提示玩家去点（PvZ-Portable src/Lawn/Coin.cpp 的 mDisappearCounter 分支：
## `if (!IsLevelAward() && !IsPresentWithAdvice()) mDisappearCounter++`）。
## 结算线上的战利品一律用这个值；玩家一直不点也不会卡死 ——
## MgmRewardManager 那边的等待有兜底超时，超时后照样结算。
const LOOT_NEVER_EXPIRE := 0.0
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
	var coin_parent := dim_coin.get_drop_parent()
	if coin_parent == null or not is_instance_valid(coin_parent):
		return
	for c in coin_parent.get_children():
		if c is Coin:
			c.be_attract_gold_magnet(target_pos)


## **清空场上所有掉落物与阳光**（多轮关卡切轮 / 退出关卡时调，见 `MainGameManager`）
##
## 以前没人管这件事：切轮只重置卡槽、背景、僵尸，上一轮没被点掉的钱和阳光原样留在场上，
## 新一轮开局时它们还在（而且定时器已经跑了一半，点一下入账的还是上一轮的钱）。
## 结算线上的掉落物不在考虑范围内 —— 那一步之后马上切场景，走不到切轮。
func clear_all_drops() -> void:
	_clear_drop_parent(dim_coin.get_drop_parent())
	_clear_drop_parent(dim_chocolate.get_drop_parent())
	_clear_drop_parent(dim_seed_packet.get_drop_parent())
	_clear_drop_parent(dim_garden_plant.get_drop_parent())
	if is_instance_valid(main_game) and is_instance_valid(main_game.suns):
		_clear_drop_parent(main_game.suns)


func _clear_drop_parent(parent: Node2D) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	for child in parent.get_children():
		if is_instance_valid(child):
			child.queue_free()


## 掉落关卡中途的解锁道具（原版：冒险 3-2 掉礼物盒解锁迷你游戏）
## 掉落位置为携带道具的僵尸死亡处，提示文本与贴图取自关卡数据的 drop_unlock_tip / drop_unlock_icon
func create_unlock_drop(drop_global_position:Vector2):
	create_unlock_drop_present(drop_global_position)


## 僵尸掉的巧克力（买了蜗牛之后才会掉，见 DropItemComponent.drop_chocolate）
## 落点与种子包一样先收进可视范围：巧克力只有 57x66，掉到画面外就点不到了
## 返回实例化出来的掉落物，没有配置父节点时为 null
func create_chocolate(drop_global_position: Vector2) -> Node2D:
	if dim_chocolate == null:
		return null
	var new_drop := dim_chocolate.create_chocolate(
		get_clamp_drop_position(drop_global_position, CHOCOLATE_DROP_EDGE_MARGIN))
	return new_drop


## 按**给定的种类 / 编号 / 起点 / 落点**掉一件战利品（通用口，不带联机字样）
##
## 与 `create_chocolate()` 那条普通入口的区别：**一个随机数都不摇** ——
## 种类、编号、起点、落点全由调用方给定，原样长出同一件。
## 单机没人调（照旧走随机那条）；联机客户端照主机下发的数据重建掉落物时用它
## （"掉不掉、掉哪一种"是战斗逻辑，客户端不该自己判，见 `GlobalUtils.drop_gate`）。
func create_drop_of_kind(kind: int, drop_entity_id: int, from_pos: Vector2, to_pos: Vector2) -> Node2D:
	var dim := _dim_of_kind(kind)
	if dim == null:
		Log.error("按编号重建掉落物，但这一类没有登记：" + str(kind))
		return null
	## 钱要飞向钱袋，没有钱袋就没有落点（见 Coin.setup）
	if ItemRegistry.is_coin_kind(kind) \
			and (dim_coin == null or not is_instance_valid(dim_coin.coin_bank_label)):
		return null
	var new_drop := dim.create_drop(ItemRegistry.get_drop_scene(kind))
	if new_drop == null:
		return null
	## 编号在入树**之前**塞进去：`_ready()` 看到非 0 就不再自己分配，两端才是同一枚
	new_drop.assign_entity_id(drop_entity_id)
	new_drop.drop_kind = kind
	if not dim.add_drop(new_drop):
		return null
	if new_drop is Coin:
		(new_drop as Coin).setup(dim_coin.coin_bank_label.marker_2d_coin_target.global_position)
	new_drop.global_position = from_pos
	## 落点由 launch 自己算（= 起点 + 相对偏移 = to_pos），两端落在同一处
	new_drop.launch(to_pos - from_pos)
	return new_drop


## 这一类归哪个子管理器管（加一种掉落物时：ItemRegistry 加一行场景、这里挂一个 DIM）
func _dim_of_kind(kind: int) -> DIM_Base:
	if ItemRegistry.is_coin_kind(kind):
		return dim_coin
	if kind == ItemRegistry.E_DropKind.Chocolate:
		return dim_chocolate
	return null


## 掉落关卡结束时的解锁道具（原版：冒险 3-4 通关掉车钥匙解锁商店）
## 与中途掉落共用一套实例化逻辑，区别只在掉落的时机与位置来源（最后一只僵尸死亡处）
## 返回实例化出来的道具，调用方可以等它被拾取 / 自动消失后再继续出奖杯
func create_unlock_drop_on_level_complete(drop_global_position:Vector2) -> Present:
	var new_drop := create_unlock_drop_present(drop_global_position)
	if new_drop == null:
		return null
	return new_drop


## 关卡结算奖项里"一盆花园植物"的概率（原版 Challenge.cpp：aHit = Rand(100)，aHit < 15）
const GARDEN_PLANT_AWARD_RATE := 0.15


## 关卡结算时按原版概率掉一个花园植物礼包
## 条件对齐原版 CanDropPottedPlantLoot：已通关冒险模式 + 花园（主花园）还有空位。
## 返回 null 表示这次没掉（概率没中 / 条件不满足），调用方不需要处理
func try_drop_garden_plant_award(drop_global_position: Vector2) -> Present:
	if dim_garden_plant == null:
		return null
	if not Goods.is_adventure_finished():
		return null
	if not Global.global_game_state.has_empty_garden_cell():
		return null
	if randf() >= GARDEN_PLANT_AWARD_RATE:
		return null
	return dim_garden_plant.create_garden_plant(get_clamp_drop_position(drop_global_position))


## 实例化一个解锁类礼包（is_garden_plant = false：不计入花园植物数量、不写存档）
## 提示文本、贴图优先用传进来的（冒险模式通关奖励），没传则取关卡数据的
## drop_unlock_tip / drop_unlock_icon，位置收进可视范围
func create_unlock_drop_present(drop_global_position:Vector2, tip_text := "", icon_texture: Texture2D = null) -> Present:
	if dim_garden_plant == null:
		return null
	if tip_text.is_empty() and game_para != null:
		tip_text = game_para.drop_unlock_tip
		icon_texture = game_para.drop_unlock_icon
	if tip_text.is_empty():
		Log.warn("关卡配置了掉落解锁道具，但没有填写 drop_unlock_tip，已跳过")
		return null

	var new_drop := dim_garden_plant.create_drop(SceneRegistry.PRESENT) as Present
	if new_drop == null:
		return null
	## 存在时长要在入树之前给（_ready 里就按它起定时器），贴图由 setter 自己应用
	new_drop.is_garden_plant = false
	new_drop.auto_free_time = UNLOCK_DROP_EXIST_TIME
	new_drop.tip_show_time = UNLOCK_DROP_TIP_TIME
	new_drop.open_tip_text = tip_text
	new_drop.icon_texture = icon_texture
	if not dim_garden_plant.add_drop(new_drop):
		return null
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
	if plant_type != PlantIds.NULL:
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
func _create_loot_seed_packet(plant_type: StringName, tip_text: String, drop_global_position: Vector2) -> Node2D:
	if dim_seed_packet == null:
		return null
	## 存在时长 0 = **永不过期**（原版的关卡奖励不自己消失，见 LOOT_NEVER_EXPIRE）
	return dim_seed_packet.create_seed_packet(plant_type, tip_text,
		get_clamp_drop_position(drop_global_position, SeedPacket.PACKET_SIZE.x / 2.0),
		LOOT_NEVER_EXPIRE, LOOT_TIP_TIME)


## 掉一个战利品礼物盒：礼物盒本体换成战利品贴图（与冒险 4-4 的玉米卷同一套表现）
## 点击区按贴图大小重算（见 Present.apply_icon_texture），所以留的边距也按贴图算
func _create_loot_present(
	loot_name: String,
	icon: Texture2D,
	tip_text: String,
	drop_global_position: Vector2
) -> Node2D:
	var new_drop := dim_garden_plant.create_drop(SceneRegistry.PRESENT) as Present
	if new_drop == null:
		return null
	## 存在时长要在入树之前给（_ready 里就按它起定时器），贴图由 setter 自己应用
	new_drop.is_garden_plant = false
	## 存在时长 0 = **永不过期**（原版的关卡奖励不自己消失，见 LOOT_NEVER_EXPIRE）
	new_drop.auto_free_time = LOOT_NEVER_EXPIRE
	new_drop.tip_show_time = LOOT_TIP_TIME
	new_drop.open_tip_text = tip_text
	new_drop.is_show_open_tip = not tip_text.is_empty()
	## 记下这是哪个战利品：点开时才知道要不要散币（原版 Coin::FanOutCoins）
	new_drop.loot_name = loot_name
	new_drop.icon_texture = icon
	var sfx := LootRegistry.get_sfx(loot_name)
	if not sfx.is_empty():
		new_drop.open_sfx = sfx
	if not dim_garden_plant.add_drop(new_drop):
		return null

	new_drop.global_position = get_clamp_drop_position(drop_global_position, icon.get_size().x / 2.0)
	SoundManager.play_other_SFX("chime")
	return new_drop


## 标记成「本关结算线」上的掉落物：点开它之后本关就结束了（见 Present / SeedPacket 的
## is_level_complete_drop），点开后播「移向屏幕中央 -> 发光 -> 屏幕逐渐变白 -> 完全白了结算」
## 而不是普通拾取表现。只有这条奖励线适用 —— 通关解锁道具（3-4 车钥匙等）点开后还要抛奖杯，不能标记
func mark_level_complete_drop(new_drop: Node2D) -> Node2D:
	if new_drop is DropItemBase:
		(new_drop as DropItemBase).is_level_complete_drop = true
	elif new_drop != null:
		Log.error("要标记的掉落物不是 DropItemBase 的子类：" + str(new_drop.get_script()))
	return new_drop


## 取植物的中文名（图鉴数据），取不到时退回植物注册名
func get_plant_show_name(plant_type: StringName) -> String:
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
## （换算本身在 `DropPositionUtil`：僵尸掉钱那条路要用，组件不该来够本管理器）
func get_clamp_drop_position(drop_global_position:Vector2, edge_margin := DROP_EDGE_MARGIN) -> Vector2:
	return DropPositionUtil.clamp_drop_position(self, drop_global_position, edge_margin)


## 当前视口能看见的那块世界矩形（掉落物用的是世界坐标，必须换算回去再夹）
## 没有画布偏移时它等于视口矩形，与直接按视口尺寸夹的结果一致
func get_viewport_visible_rect() -> Rect2:
	return DropPositionUtil.get_viewport_visible_rect(self)
