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
## 僵王源卡目录；追加在僵尸目录之后，索引独立编号
@onready var all_boss_cards_parent_node_root: Array[GridContainer] = [
	%BossCards
]

## 模仿者卡片:它有静态形象(商店图标要用),但不参与 all_plant_card_prefabs ——
## 选卡界面按这个字典的顺序与 plant_card_ids 下标生成候选卡位(见 card_slot_candidate.gd),
## 把模仿者混进去会多出一张候选卡并打乱下标,所以单独留一个引用只给"取静态形象"用
@onready var imitater_card: Card = $CardImitater

@export var all_plant_card_prefabs:Dictionary[CharacterRegistry.PlantType, Card]
@export var all_zombie_card_prefabs:Dictionary[CharacterRegistry.ZombieType, Card]
@export var all_boss_card_prefabs:Dictionary[CharacterRegistry.ZombieBossType, Card]

@export var plant_card_ids :Dictionary[CharacterRegistry.PlantType, int]
@export var zombie_card_ids :Dictionary[CharacterRegistry.ZombieType, int]
@export var boss_card_ids :Dictionary[CharacterRegistry.ZombieBossType, int]

## 所有已注册模板，键为 ResourceCardReference.get_template_key()（类别 + 角色编号）
var all_card_templates: Dictionary[Vector2i, Card] = {}
## 源目录顺序：植物、普通僵尸、僵王
var _source_directories: Array[Array] = []

var frame_num := 0


## 更新每个已经制作的卡片（卡片类型不为空）
func _ready() -> void:
	## 非编辑器中运行隐藏(游戏中)
	if not Engine.is_editor_hint():
		visible = false
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

	var boss_i = -1
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

func init_card(card:CardBase, card_init_para:Dictionary):
	card.card_id = card_init_para[CardBase.E_CInitAttr.CardId]
	card.cool_time = card_init_para[CardBase.E_CInitAttr.CoolTime]
	card.sun_cost = card_init_para[CardBase.E_CInitAttr.SunCost]

## 登记模板；同一身份重复注册报错并保留先注册的那张。
func _register_template(card: Card) -> void:
	if card.card_reference == null:
		return
	var template_key: Vector2i = card.card_reference.get_template_key()
	if all_card_templates.has(template_key):
		Log.error("AllCards：卡牌身份重复注册：%s" % card.card_reference.to_dict())
		return
	all_card_templates[template_key] = card

#region 查询与创建
## 查询只读源卡；[param reference] 非法或未注册时返回 null。
func get_template(reference: ResourceCardReference) -> Card:
	if reference == null or not reference.is_valid():
		return null
	return all_card_templates.get(reference.get_template_key())

## 是否有已注册的可出战模板；[param reference] 非法时返回 false。
func has_template(reference: ResourceCardReference) -> bool:
	return get_template(reference) != null

## 是否为可出战卡：已注册的植物、普通僵尸或僵王；模仿者选择入口不出战。
func is_battle_card(reference: ResourceCardReference) -> bool:
	if reference == null or not reference.is_valid():
		return false
	if reference.is_imitater:
		return false
	return all_card_templates.has(reference.get_template_key())

## 创建持有独立引用的卡片；返回时尚未入树。[br]
## [param context] 为卡片点击用途（见 Card.CardContext），非法或未注册身份返回 null。
func create_card(reference: ResourceCardReference, context: Card.CardContext = Card.CardContext.Catalog) -> Card:
	var template: Card = get_template(reference)
	if template == null:
		Log.error("AllCards：无法创建未注册的卡牌：%s"
			% (reference.to_dict() if reference != null else "null"))
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
