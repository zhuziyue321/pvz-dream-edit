@tool
extends Control
## 所有的卡片
class_name AllCardsClass

@onready var all_plant_cards_parent_node_root: Array[GridContainer] = [
	%PlantCards, %PlantCards2
]
@onready var all_zombie_cards_parent_node_root: Array[GridContainer] = [
	%ZombieCards, %ZombieCards2
]
## 僵王源卡目录；节点顺序接在僵尸目录之后
## ★ 编号也跟着接：下面 `rebuild()` 里 `boss_i` 从 `zombie_i` 续着数，
##   于是「普通僵尸 + 僵王」在选卡层是同一个连续编号空间（见 get_enemy_cards_in_choose_order）
@onready var all_boss_cards_parent_node_root: Array[GridContainer] = [
	%BossCards
]

## 模仿者卡片:它有静态形象(商店图标要用),但不参与 all_plant_card_prefabs ——
## 选卡界面按这个字典的顺序与 plant_card_ids 下标生成候选卡位(见 card_slot_candidate.gd),
## 把模仿者混进去会多出一张候选卡并打乱下标,所以单独留一个引用只给"取静态形象"用
@onready var imitater_card: Card = $CardImitater

@export var all_plant_card_prefabs:Dictionary[StringName, Card]
@export var all_zombie_card_prefabs:Dictionary[StringName, Card]
@export var all_boss_card_prefabs:Dictionary[StringName, Card]

@export var plant_card_ids :Dictionary[StringName, int]
@export var zombie_card_ids :Dictionary[StringName, int]
@export var boss_card_ids :Dictionary[StringName, int]

## 所有已注册模板，键为 ResourceCardReference.get_template_key()（`"plant:pea_shooter"` 这种字符串键）
##
## 原来是 `Dictionary[Vector2i, Card]`（类别 + 角色编号两个 int），角色编号改成字符串 id 之后
## Vector2i 装不下了，键就换成人能读的字符串。
var all_card_templates: Dictionary[StringName, Card] = {}
## 源目录顺序：植物、普通僵尸、僵王
var _source_directories: Array[Array] = []

var frame_num := 0


## 重建三张目录（植物 / 僵尸 / 僵王）：模板字典、`*_card_ids` 与卡上的 `card_id` 一起重排
##
## ★ 这是留给模组的口子：卡的编号是按**源目录里的节点顺序**算的（先 PlantCards 后 PlantCards2），
##   运行期往源目录里插一张卡（例如模组新增的植物）就要调一次，否则新卡没有编号、
##   选卡界面也认不出它。想让新卡排在谁后面，就把节点插在谁后面再调本函数。
func rebuild() -> void:
	_source_directories = [all_plant_cards_parent_node_root,
		all_zombie_cards_parent_node_root, all_boss_cards_parent_node_root]
	all_card_templates.clear()

	var plant_i = -1
	all_plant_card_prefabs.clear()
	plant_card_ids.clear()
	for plant_cards_parent_node in all_plant_cards_parent_node_root:
		for i in range(plant_cards_parent_node.get_children().size()):
			var card:Card = plant_cards_parent_node.get_children()[i]
			if card.card_reference == null or card.card_type != ResourceCardReference.CardType.Plant:
				continue
			plant_i += 1
			var card_para:Dictionary[Card.E_CInitAttr, Variant] = {
				Card.E_CInitAttr.CardId:plant_i,
				Card.E_CInitAttr.CoolTime:Global.character_registry.get_plant_info(card.card_plant_type, CharacterRegistry.PlantInfoAttribute.CoolTime),
				Card.E_CInitAttr.SunCost:Global.character_registry.get_plant_info(card.card_plant_type, CharacterRegistry.PlantInfoAttribute.SunCost)
			}
			init_card(card, card_para)
			all_plant_card_prefabs[card.card_plant_type] = card
			plant_card_ids[card.card_plant_type] = plant_i
			_register_template(card)

	var zombie_i = -1
	all_zombie_card_prefabs.clear()
	zombie_card_ids.clear()
	for zombie_cards_parent_node in all_zombie_cards_parent_node_root:
		for i in range(zombie_cards_parent_node.get_children().size()):
			var card:Card = zombie_cards_parent_node.get_children()[i]
			if card.card_reference == null or card.card_type != ResourceCardReference.CardType.Zombie:
				continue
			zombie_i += 1
			var zombie_para:Dictionary[Card.E_CInitAttr, Variant] = {
				Card.E_CInitAttr.CardId:zombie_i,
				Card.E_CInitAttr.CoolTime:Global.character_registry.get_zombie_info(card.card_zombie_type, CharacterRegistry.ZombieInfoAttribute.CoolTime),
				Card.E_CInitAttr.SunCost:Global.character_registry.get_zombie_info(card.card_zombie_type, CharacterRegistry.ZombieInfoAttribute.SunCost)
			}
			init_card(card, zombie_para)
			all_zombie_card_prefabs[card.card_zombie_type] = card
			zombie_card_ids[card.card_zombie_type] = zombie_i
			_register_template(card)

	## 僵王的 card_id **接在最后一张僵尸卡之后**（不再从 -1 重新数）：
	## 选卡层把僵王当普通僵尸排页 / 排格，前提是两者同属一个连续编号空间 ——
	## 各数一套的话，僵王 id 会与僵尸 id 撞车，卡位换算（card_id % 每页格数）也对不上。
	var boss_i = zombie_i
	all_boss_card_prefabs.clear()
	boss_card_ids.clear()
	for boss_cards_parent_node in all_boss_cards_parent_node_root:
		for i in range(boss_cards_parent_node.get_children().size()):
			var card:Card = boss_cards_parent_node.get_children()[i]
			if card.card_reference == null or card.card_type != ResourceCardReference.CardType.ZombieBoss:
				continue
			boss_i += 1
			var boss_para:Dictionary[Card.E_CInitAttr, Variant] = {
				Card.E_CInitAttr.CardId:boss_i,
				Card.E_CInitAttr.CoolTime:Global.character_registry.get_zombie_boss_info(card.card_zombie_boss_type, CharacterRegistry.ZombieBossInfoAttribute.CoolTime),
				Card.E_CInitAttr.SunCost:Global.character_registry.get_zombie_boss_info(card.card_zombie_boss_type, CharacterRegistry.ZombieBossInfoAttribute.SunCost)
			}
			init_card(card, boss_para)
			all_boss_card_prefabs[card.card_zombie_boss_type] = card
			boss_card_ids[card.card_zombie_boss_type] = boss_i
			_register_template(card)


func _ready() -> void:
	## 非编辑器中运行隐藏(游戏中)
	if not Engine.is_editor_hint():
		visible = false
	rebuild()


func init_card(card:CardBase, card_init_para:Dictionary):
	card.card_id = card_init_para[CardBase.E_CInitAttr.CardId]
	card.cool_time = card_init_para[CardBase.E_CInitAttr.CoolTime]
	card.sun_cost = card_init_para[CardBase.E_CInitAttr.SunCost]

## 登记模板；同一身份重复注册报错并保留先注册的那张。
func _register_template(card: Card) -> void:
	if card.card_reference == null:
		return
	var template_key: StringName = card.card_reference.get_template_key()
	if all_card_templates.has(template_key):
		Log.error("AllCards：卡牌身份重复注册：%s" % card.card_reference.to_dict())
		return
	all_card_templates[template_key] = card

#region 查询与创建
## 查询只读源卡；[param reference] 非法或未注册时返回 null。
##
## ★ 判据是「模板登记了没有」，**不是** `ResourceCardReference.is_valid()`：
##   那个只认**内置**角色（在 `PlantIds.ALL` / `ZombieIds.ALL` 里的），运行期热注册的
##   （模组加的僵尸 / 植物）一律不算 —— 可它们的卡就登记在这本目录里，照 `is_valid()` 判
##   就是「模组插了卡、却造不出这张卡」（`create_card()` 直接返回 null，
##   连「我是僵尸」那种预选发牌与读档恢复出战卡槽都跟着失效）。
##   卡片能不能用，本目录自己就是权威 —— 认模板，不认角色是不是内置的。
func get_template(reference: ResourceCardReference) -> Card:
	if not _has_content_id(reference):
		return null
	return all_card_templates.get(reference.get_template_key())

## 是否有已注册的可出战模板；[param reference] 非法时返回 false。
func has_template(reference: ResourceCardReference) -> bool:
	return get_template(reference) != null

## 是否为可出战卡：模板已登记的植物、普通僵尸或僵王；模仿者选择入口不出战。
func is_battle_card(reference: ResourceCardReference) -> bool:
	if not _has_content_id(reference) or reference.is_imitater:
		return false
	return all_card_templates.has(reference.get_template_key())

## 身份里那个角色 id 填了没有（空 = 这张卡还没配内容，谈不上出战）
static func _has_content_id(reference: ResourceCardReference) -> bool:
	return reference != null and reference.content_id != &""

## 创建持有独立引用的卡片；返回时尚未入树。[br]
## [param context] 为卡片点击用途（见 Card.CardContext），非法或未注册身份返回 null。
func create_card(reference: ResourceCardReference, context: Card.CardContext = Card.CardContext.Catalog) -> Card:
	var template: Card = get_template(reference)
	if template == null:
		Log.error("AllCards：无法创建未注册的卡牌：%s"
			% ("null" if reference == null else str(reference.to_dict())))
		return null
	var new_card: Card = template.duplicate()
	new_card.card_reference = reference.copy_reference()
	new_card.card_context = context
	return new_card

## 复制源卡的静态形象，返回独立 Node2D；模仿引用应用模仿材质。
func create_static_preview(reference: ResourceCardReference) -> Node2D:
	var template: Card = get_template(reference)
	if template == null or not is_instance_valid(template.character_static):
		return null
	var preview: Node2D = template.character_static.duplicate()
	if reference != null and reference.is_imitater:
		preview.material = Card.IMITATER.duplicate()
		for child in preview.get_children():
			GlobalUtils.node_use_parent_material(child)
	return preview

## 选卡层的「敌方卡」顺序：**普通僵尸在前，僵王紧接其后**，两者串成一条连续列表。
##
## 为什么能串成一条：僵王的 `card_id` 在 `rebuild()` 里就接在最后一张僵尸卡之后，
## 于是「摆在第几页第几格」的换算（`i / 每页格数`、`i % 每页格数`）对两者完全一致，
## 待选区照这条列表连续排页即可，**不必再给僵王单开一页**（见 `card_slot_candidate.gd`）。
## ⚠️ 僵王在**战斗层**仍不是普通僵尸（卡牌类型还是 `CardType.ZombieBoss`、
## 落地走 `ZombieManager.try_create_boss_from_card()`）；这里只是在**选卡 / 卡牌层**按普通僵尸排。
#region 植物排列顺序
## 是否属于「追加在普通植物后面」的那两类植物：**调试模式专属** 或 **模组新增**
##
## ★ 本体只认这两类「不是原版流程能拿到的植物」，一个模组名字都不认识 ——
##   模组新增的判据是「运行期注册的」（见 `CharacterRegistry.is_runtime_plant`）。
static func is_appended_plant(plant_type: StringName) -> bool:
	## 调试模式专属：三种保龄球 + 反向双发（见 ConstPlantUnlock.DEBUG_MODE_PLANT_TYPES）
	if ConstPlantUnlock.DEBUG_MODE_PLANT_TYPES.has(plant_type):
		return true
	## 模组新增：本体不认识任何一个模组，只认「运行期注册的」这一类
	## （见 CharacterRegistry.register_runtime_plant_recipe / is_runtime_plant）
	return Global.character_registry.is_runtime_plant(plant_type)


## 待选区（选卡界面）与图鉴扩展页**共用**的排列顺序：**普通植物在最前面且顺序固定，
## 追加类植物排在最后**（它们彼此先后无所谓）
##
## 为什么不能直接照 `all_plant_card_prefabs` 的顺序用：那个顺序就是卡片源目录里的节点顺序，
## 卡的编号（`card_id`）按节点顺序算（见 `rebuild()`），往中间插一张卡会让后面每一株的编号挪一格 ——
## 最后一株普通植物就被挤到下一页去了。模组（例如「水盆」）是在运行期往源目录里加卡的，
## 本体不认识任何一个模组、也没法要求它一定插在末尾，所以顺序在**消费侧**显式排一次。
func get_plant_types_in_choose_order() -> Array[StringName]:
	var normal_plant_types: Array[StringName] = []
	var appended_plant_types: Array[StringName] = []
	for plant_type: StringName in all_plant_card_prefabs:
		if is_appended_plant(plant_type):
			appended_plant_types.append(plant_type)
		else:
			normal_plant_types.append(plant_type)
	normal_plant_types.append_array(appended_plant_types)
	return normal_plant_types
#endregion


func get_enemy_cards_in_choose_order() -> Array[Card]:
	var enemy_cards: Array[Card] = []
	for zombie_type: StringName in all_zombie_card_prefabs:
		enemy_cards.append(all_zombie_card_prefabs[zombie_type])
	for boss_type: StringName in all_boss_card_prefabs:
		enemy_cards.append(all_boss_card_prefabs[boss_type])
	return enemy_cards

## 按源目录顺序返回该类别的独立引用列表。
func get_references(card_type: ResourceCardReference.CardType) -> Array[ResourceCardReference]:
	var references: Array[ResourceCardReference] = []
	var directories: Array[GridContainer] = []
	match card_type:
		ResourceCardReference.CardType.Plant:
			directories = all_plant_cards_parent_node_root
		ResourceCardReference.CardType.Zombie:
			directories = all_zombie_cards_parent_node_root
		ResourceCardReference.CardType.ZombieBoss:
			directories = all_boss_cards_parent_node_root
	for directory: GridContainer in directories:
		if not is_instance_valid(directory):
			continue
		for child in directory.get_children():
			var card: Card = child as Card
			if card == null or card.card_reference == null or card.card_type != card_type:
				continue
			references.append(card.card_reference.copy_reference())
	return references
#endregion
