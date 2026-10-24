extends Node
## 散落的加载场景
##
## ★ 场景的**取用**统一走 `AssetRegistry`（`src/core/resource/asset_registry.gd`）：
##   这里只登记「散落场景 → 路径」，真正加载与缓存交给资源注册表 —— 同一个场景
##   别处再取一次也命中同一份缓存。所以成员是 `var` 而不是 `const preload`：
##   `preload` 的值无法参与「运行期注册 / 换绑」，`AssetRegistry` 可以。
##   （路径仍按硬约束 §1-5 写全 `res://`。）


## 花园植物格子
var PLANT_CELL_GARDEN: PackedScene = AssetRegistry.get_scene("res://src/garden/plant_cell_garden.tscn")
## 花园需求气泡
var GARDEN_SPEECH_BUBBLE: PackedScene = AssetRegistry.get_scene("res://src/garden/garden_speech_bubble.tscn")
## 花园花盆
var GARDEN_FLOWER_POT: PackedScene = AssetRegistry.get_scene("res://src/garden/garden_flower_pot.tscn")


## 戴夫
var CRAZY_DAVE: PackedScene = AssetRegistry.get_scene("res://src/dave/crazy_dave.tscn")

## 新手教程提示条（屏幕下方的提示文本 + 指向箭头）
var TUTORIAL_ADVICE: PackedScene = AssetRegistry.get_scene("res://src/ui/tutorial_advice_ui.tscn")

## 提示信息
var REMINDER_INFORMATION: PackedScene = AssetRegistry.get_scene("res://src/ui/reminder_information.tscn")

## 「开始战斗！」按钮（原版迷你游戏「坚不可摧」的布阵阶段，右下角）
var LETS_ROCK_BUTTON: PackedScene = AssetRegistry.get_scene("res://src/ui/main_game_ui/lets_rock_button.tscn")

## 钻石、金币、银币、
var COIN_DIAMOND: PackedScene = AssetRegistry.get_scene("res://src/items/drop/coin_diamond.tscn")
var COIN_GOLD: PackedScene = AssetRegistry.get_scene("res://src/items/drop/coin_gold.tscn")
var COIN_SILVER: PackedScene = AssetRegistry.get_scene("res://src/items/drop/coin_silver.tscn")
## 禅境花园的蜗牛(商店买断后才出现在花园里,见 GardenManager._init_stinky)
var STINKY: PackedScene = AssetRegistry.get_scene("res://src/garden/stinky.tscn")
var PRESENT: PackedScene = AssetRegistry.get_scene("res://src/items/drop/present.tscn")
## 种子包样式的掉落展示物（冒险模式通关拿到新植物时显示）
var SEED_PACKET: PackedScene = AssetRegistry.get_scene("res://src/items/drop/seed_packet.tscn")
## 僵尸掉落的巧克力（买了蜗牛之后才会掉，见 DropItemComponent.drop_chocolate）
var CHOCOLATE_DROP: PackedScene = AssetRegistry.get_scene("res://src/items/drop/chocolate.tscn")

## 待选卡槽
var CARD_CANDIDATE_CONTAINER: PackedScene = AssetRegistry.get_scene("res://src/ui/card/card_candidate_container.tscn")
## 植物种植特效
var PLANT_START_EFFECT: PackedScene = AssetRegistry.get_scene("res://src/items/plant_effect/plant_start_effect.tscn")
var PLANT_START_EFFECT_WATER: PackedScene = AssetRegistry.get_scene("res://src/items/plant_effect/plant_start_effect_water.tscn")

## 坑洞
var DOOM_SHROOM_CRATER: PackedScene = AssetRegistry.get_scene("res://src/fx/doom_shroom_crater.tscn")

## 墓碑
var TOMBSTONE: PackedScene = AssetRegistry.get_scene("res://src/items/tombstone.tscn")

## 灌木丛（DLC 版第 7 章 Woods）
var BUSH: PackedScene = AssetRegistry.get_scene("res://src/items/bush.tscn")


## 僵王博士不在本注册表里：僵王是正式角色，走 CharacterRegistry.ZombieBossType 查场景
## （见 Global.character_registry.get_zombie_boss_info(..., BossScenes)），血条由 LevelInfo 统一管理。

## 舞王管理器
var JACKSON_MANAGER: PackedScene = AssetRegistry.get_scene("res://src/entities/character/zombie/jackson/jackson_manager.tscn")

## 奖杯不再是一个独立场景：它是一种**战利品**，按名字取贴图现生产
## （名字 -> 贴图那张表在 LootRegistry，生产在 DropItemManager.create_loot_drop）

## 锤僵尸玩法（迷你游戏 15「打僵尸」/ 冒险 2-5「打地鼠」两关共用）：
## 锤子美术常驻主场景（CanvasLayerTemp 的 RealHammer，由手持物组件 HandComponentHammer 拿着），
## 这里只登记出怪器 —— 由这两关共用的玩法规则装配（见 LevelRuleHammerZombie）
var HAMMER_ZOMBIE_SOURCE: PackedScene = AssetRegistry.get_scene("res://src/managers/zombie_manager/zm_hammer_zombie_manager.tscn")

## 冰冻僵尸特效
var ICE_EFFECT: PackedScene = AssetRegistry.get_scene("res://src/fx/ice_effect.tscn")
## 泳池水花场景
var SPLASH: PackedScene = AssetRegistry.get_scene("res://src/items/splash.tscn")
## 火焰特效(火爆辣椒\火焰豌豆)
var FIRE: PackedScene = AssetRegistry.get_scene("res://src/fx/fire.tscn")
## 黄油特效
var BUTTER_SPLAT: PackedScene = AssetRegistry.get_scene("res://src/fx/butter_splat.tscn")

## 阳光
var SUN: PackedScene = AssetRegistry.get_scene("res://src/items/sun.tscn")

## 僵尸水族馆（迷你游戏第 8 关）：入口场景（壳）→ 玩法总控 / 宠物潜水僵尸 / 喂僵尸的脑子
## 关卡走 ZOMBIQUARIUM_SCENE（见 minigame_08_zombie_aquarium）；单独预览时直接在编辑器里跑它
var ZOMBIQUARIUM_SCENE: PackedScene = AssetRegistry.get_scene("res://src/zombiquarium/zombiquarium.tscn")
var ZOMBIQUARIUM: PackedScene = AssetRegistry.get_scene("res://src/zombiquarium/zombiquarium_manager.tscn")
var ZOMBIQUARIUM_PET: PackedScene = AssetRegistry.get_scene("res://src/zombiquarium/zombiquarium_pet.tscn")
var ZOMBIQUARIUM_BRAIN: PackedScene = AssetRegistry.get_scene("res://src/zombiquarium/zombiquarium_brain.tscn")

## 泥土上升特效
var DIRT_RISE_EFFECT: PackedScene = AssetRegistry.get_scene("res://src/entities/character/item/dirt_rise_effect.tscn")

## 梯子
var LADDER: PackedScene = AssetRegistry.get_scene("res://src/items/ladder.tscn")

## 小推车 / 水路清洁车 / 屋顶清洁车（按 `GIM_LawnMover.E_LawnMoverType` 索引）
## 类型由地图数据 `row_data.lawn_mover_type` 给；水路 / 屋顶款还要在商店买过才配发
## （见 `GIM_LawnMover.is_lane_can_have_mover`）
var LAWN_MOVER_MAP: Dictionary = {
	GIM_LawnMover.E_LawnMoverType.LawnMover:   AssetRegistry.get_scene("res://src/items/lawn_mower/lawn_mower.tscn"),
	GIM_LawnMover.E_LawnMoverType.PoolCleaner: AssetRegistry.get_scene("res://src/items/lawn_mower/pool_cleaner.tscn"),
	GIM_LawnMover.E_LawnMoverType.RoofCleaner: AssetRegistry.get_scene("res://src/items/lawn_mower/roof_cleaner.tscn"),
}

## 禅境花园的背景页（按 `GardenManager.E_GardenBgType` 索引）
## 加第五个背景：枚举加一项 + 这里加一条 + `GardenManager.get_plant_cell_num_per_page()` 补页容量。
## 之前这张表写在 `GardenManager` 里（业务管理器各自登记场景），是第二套场景入口 —— 见 TODO 的 U-46。
var GARDEN_BG_PAGE_SCENES: Dictionary = {
	GardenManager.E_GardenBgType.GreenHouse:     AssetRegistry.get_scene("res://src/garden/bg_00_greenhouse.tscn"),
	GardenManager.E_GardenBgType.MushroomGraden: AssetRegistry.get_scene("res://src/garden/bg_01_mushroom_garden.tscn"),
	GardenManager.E_GardenBgType.Aquarium:       AssetRegistry.get_scene("res://src/garden/bg_02_aquarium.tscn"),
	GardenManager.E_GardenBgType.TreeBg:         AssetRegistry.get_scene("res://src/garden/bg_03_tree_of_wisdom.tscn"),
}


#region 待选卡容器池（跨关卡复用）
## ★ 为什么要有池：待选区动辄上百张卡（植物 + 敌人 + 模仿者页各一份），
##   每关都 `duplicate()` 卡模板 + `instantiate()` 容器 + 建静态形象，进关要多吃一次同步开销。
##   这些节点与关卡数据无关（身份 / 外观 / 费用全由卡模板决定），可以**换关不重建**：
##   关卡开始从池里取，关卡销毁前还回池（见 `CardSlotNorm._exit_tree`）。
##
## 池挂在 autoload 上（不在关卡场景子树里），所以关卡切场景不会连带销毁。
## 兜底：万一某个退出路径漏了归还，节点会随旧场景一起释放 —— `acquire` 侧用
## `is_instance_valid` 判掉失效缓存并重建，正确性不受影响，只是那一次退化成旧行为。
##
## 池里的容器**始终隐藏**；取件方负责自己的可见性（`CardSlotCandidate` 按已解锁名单点亮）。

## 池的存放节点（隐藏的 Control，跨关卡存活）
var _candidate_pool_storage: Control = null
## 空闲容器：键 = 卡身份（含模仿修饰）→ 容器数组
var _candidate_pool_free: Dictionary = {}
## 已借出的容器：关卡销毁时按这一份整批收回
var _candidate_pool_borrowed: Dictionary = {}


## 取一个待选卡容器（没有可复用的就新建一个）；返回时尚未挂进关卡界面
func acquire_candidate_container(source_card: Card, imitater: bool) -> CardCandidateContainer:
	var key := _candidate_pool_key(source_card, imitater)
	var free_list: Array = _candidate_pool_free.get(key, [])
	while not free_list.is_empty():
		var cached: Variant = free_list.pop_back()
		if not is_instance_valid(cached):
			continue
		var pooled := cached as CardCandidateContainer
		if pooled == null or pooled.card == null or not is_instance_valid(pooled.card):
			## 卡已随旧场景销毁（漏归还的兜底）：容器本身也丢掉，不留在池里占位
			if pooled != null:
				pooled.queue_free()
			continue
		_sync_candidate_source(pooled, source_card)
		if not _reset_candidate_container(pooled):
			pooled.queue_free()
			continue
		_candidate_pool_borrowed[pooled] = true
		return pooled
	var container := _create_candidate_container(source_card, imitater)
	_candidate_pool_borrowed[container] = true
	return container


## 把一个容器还回池（先把它里面的卡搬回容器并清掉上一关的状态）
func release_candidate_container(container: CardCandidateContainer) -> void:
	if container == null or not is_instance_valid(container):
		return
	_candidate_pool_borrowed.erase(container)
	if not _reset_candidate_container(container):
		container.queue_free()
		return
	var storage := _get_candidate_pool_storage()
	if container.get_parent() != storage:
		if container.get_parent() == null:
			storage.add_child(container)
		else:
			## 必须传 false：池只负责存节点，不该保留关卡界面里的布局。
			## 传 true 时 Godot 会为了「保持全局变换」把本地 position 改写成上一局的
			## 屏幕绝对坐标，下一关取件用 false 挂进占位格时不会纠正，整片种子包就整体偏移。
			container.reparent(storage, false)
	var key := _candidate_pool_key(container.card, container.card.is_imitater)
	var free_list: Array = _candidate_pool_free.get(key, [])
	free_list.append(container)
	_candidate_pool_free[key] = free_list


## 关卡销毁前整批收回本局借出的容器（下一关直接复用）
func recall_candidate_containers() -> void:
	if _candidate_pool_borrowed.is_empty():
		return
	for container: Variant in _candidate_pool_borrowed.keys():
		release_candidate_container(container as CardCandidateContainer)
	_candidate_pool_borrowed.clear()


## 新建一个容器：复制源卡 → 换成独立身份引用 → 装进容器 → 先挂到池里跑一次 `_ready`
func _create_candidate_container(source_card: Card, imitater: bool) -> CardCandidateContainer:
	var new_card: Card = source_card.duplicate()
	## 副本默认与源卡共享身份资源，换成独立引用（模仿者页还要单独打开模仿修饰）
	new_card.make_reference_unique()
	if imitater:
		new_card.is_imitater = true
	var container: CardCandidateContainer = CARD_CANDIDATE_CONTAINER.instantiate()
	container.init_card_in_seed_chooser(new_card)
	_get_candidate_pool_storage().add_child(container)
	container.visible = false
	return container


## 以源卡当前值为准刷新池里的容器：`AllCards.rebuild()` 会重排编号、角色注册表里的
## 费用 / 冷却也可能被模组改过，而池里这份是上次创建时的旧值
func _sync_candidate_source(container: CardCandidateContainer, source_card: Card) -> void:
	container.card_id = source_card.card_id
	container.card.card_id = source_card.card_id
	container.sun_cost = source_card.sun_cost
	container.cool_time = source_card.cool_time
	container.source_sun_cost = source_card.sun_cost
	container.source_cool_time = source_card.cool_time


## 复位一个容器：卡搬回容器、断开上一关的点击连接、清掉选卡 / 冷却 / 禁选状态
func _reset_candidate_container(container: CardCandidateContainer) -> bool:
	var card: Card = container.card
	if card == null or not is_instance_valid(card):
		return false
	## 选卡时卡会被搬进出战卡槽 / 动画层（见 CardSlotNorm.move_card_to），搬回容器再还池
	if card.get_parent() != container:
		if card.get_parent() == null:
			container.add_child(card)
		else:
			card.reparent(container)
	_disconnect_card_signals(card)
	## 这张卡跟着出过战：紫卡加价 / 测试关零冷却 / 一次性卡置灰都可能改过它，按源值恢复
	card.sun_cost = container.source_sun_cost
	card.cool_time = container.source_cool_time
	card.is_disabled_forever = false
	card.is_blocked = false
	card.is_almanac_card = false
	card.card_context = Card.CardContext.Catalog
	card.position = Vector2.ZERO
	card.visible = true
	card.is_choosed_pre_card = false
	card.set_card_cool_end()
	card.set_shortcut_disappear()
	card.mouse_filter_start()
	card.card_ready()
	## 容器自己也要归位：它的坐标是相对占位格的本地坐标，正常恒为 (0,0)。
	## 上一局若被改写过（历史 bug：还池时保持全局变换）或卡片被拖去动画层又搬回，
	## 不清零就会带着脏坐标进下一关，表现为选卡界面种子包整体偏移。
	container.position = Vector2.ZERO
	container.scale = Vector2.ONE
	container.rotation = 0.0
	container.is_banned = false
	container.visible = false
	return true


## 断开上一关宿主（CardSlotNorm）连上的点击 / 使用信号；宿主释放时本来也会自动断开，
## 这里显式清一遍，保证池里的卡不会带着半截连接进下一关
func _disconnect_card_signals(card: Card) -> void:
	for connection: Dictionary in card.signal_card_click.get_connections():
		card.signal_card_click.disconnect(connection.callable)
	for connection: Dictionary in card.signal_card_use_end.get_connections():
		card.signal_card_use_end.disconnect(connection.callable)


## 池的存放节点：懒创建（隐藏的 Control，避免池里的卡在屏幕角落露出来）
func _get_candidate_pool_storage() -> Control:
	if is_instance_valid(_candidate_pool_storage):
		return _candidate_pool_storage
	_candidate_pool_storage = Control.new()
	_candidate_pool_storage.name = "CardCandidatePoolStorage"
	_candidate_pool_storage.visible = false
	add_child(_candidate_pool_storage)
	return _candidate_pool_storage


## 池的键：卡身份（`plant:pea_shooter` 这种）+ 模仿修饰
func _candidate_pool_key(source_card: Card, imitater: bool) -> StringName:
	var base: StringName = &""
	if source_card.card_reference != null:
		base = source_card.card_reference.get_template_key()
	return StringName(str(base) + (":imitater" if imitater else ""))
#endregion
