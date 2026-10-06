extends Control
class_name CardBase

@onready var card_bg: TextureRect = $CardBg
@onready var cost: Label = $CardBg/Cost
@onready var _cool_mask: ProgressBar = $ProgressBar

enum E_CardBg{
	CB01Norm,	## 普通卡片背景
	CB02Purple,	## 紫卡背景
	CB03Gray,	## 灰卡背景
}

## 卡片背景对应资源
var CradBgMap:Dictionary[E_CardBg, Resource] = {
	E_CardBg.CB01Norm:load("res://data/ui/card_bg/norm.tres"),
	E_CardBg.CB02Purple:load("res://data/ui/card_bg/purple.tres"),
	E_CardBg.CB03Gray:load("res://data/ui/card_bg/gray.tres")
}

## 卡片索引位置,用于在备选卡槽时确定位置
@export var card_id :int = -1

## 卡牌唯一身份；类别、角色编号与模仿修饰都在引用里，不再拆成多个枚举字段。
## 费用与冷却由 AllCards 按类别查角色注册表写入，引用本身不保存运行数值。
@export var card_reference: ResourceCardReference = null

#region 身份派生属性
## 卡牌内容类别；未配置引用时为 Null。
var card_type: ResourceCardReference.CardType:
	get:
		return card_reference.card_type if card_reference != null else ResourceCardReference.CardType.Null

## 是否为出战用的植物、普通僵尸或僵王；模仿者选择入口不算出战卡。
## 这里只做身份自检，是否已注册模板另由 AllCards.is_battle_card() 判断。
var is_battle_card: bool:
	get:
		return card_reference != null and card_reference.is_valid() and not card_reference.is_imitater

## 兼容旧字段：植物编号；非植物卡或未配置时返回 Null。
var card_plant_type: CharacterRegistry.PlantType:
	get:
		if card_reference == null or card_reference.card_type != ResourceCardReference.CardType.Plant:
			return CharacterRegistry.PlantType.Null
		return card_reference.content_id as CharacterRegistry.PlantType
	set(value):
		_set_content(ResourceCardReference.CardType.Plant, value)

## 兼容旧字段：普通僵尸编号；非僵尸卡或未配置时返回 Null。
var card_zombie_type: CharacterRegistry.ZombieType:
	get:
		if card_reference == null or card_reference.card_type != ResourceCardReference.CardType.Zombie:
			return CharacterRegistry.ZombieType.Null
		return card_reference.content_id as CharacterRegistry.ZombieType
	set(value):
		_set_content(ResourceCardReference.CardType.Zombie, value)

## 兼容旧字段：僵王编号；非僵王卡或未配置时返回 Null。
var card_zombie_boss_type: CharacterRegistry.ZombieBossType:
	get:
		if card_reference == null or card_reference.card_type != ResourceCardReference.CardType.ZombieBoss:
			return CharacterRegistry.ZombieBossType.Null
		return card_reference.content_id as CharacterRegistry.ZombieBossType
	set(value):
		_set_content(ResourceCardReference.CardType.ZombieBoss, value)

## 兼容旧字段：模仿修饰，直接落到身份引用上。
var is_imitater: bool:
	get:
		return card_reference != null and card_reference.is_imitater
	set(value):
		if card_reference == null:
			card_reference = ResourceCardReference.new()
		card_reference.is_imitater = value
#endregion

## 按类别写入角色编号；没有引用时新建一份，保留已有的模仿修饰。
func _set_content(new_type: ResourceCardReference.CardType, content_id: int) -> void:
	if card_reference == null:
		card_reference = ResourceCardReference.create(new_type, content_id, false)
		return
	card_reference.card_type = new_type
	card_reference.content_id = content_id

## 是否为紫卡
var is_purple_card := false
## 卡片背景,紫卡会自动更换背景
@export var curr_card_gb :E_CardBg = E_CardBg.CB01Norm
## 该植物种植条件,紫卡使用内部方法判断是否可以种植
var plant_condition:ResourcePlantCondition
## 卡片冷却时间
@export var cool_time: float = 7.5:
	set(value):
		cool_time = value
		if _cool_mask:
			_cool_mask.max_value = value

## 卡片阳光消耗
@export var sun_cost: int = 100:
	set(value):
		sun_cost = value
		if cost:
			cost.text = str(int(value))

func _ready() -> void:
	## 只有植物卡才有种植条件与紫卡背景；普通僵尸和僵王沿用普通背景。
	if card_type == ResourceCardReference.CardType.Plant:
		plant_condition = Global.character_registry.get_plant_info(card_plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
		is_purple_card = plant_condition.is_purple_card
		if is_purple_card:
			curr_card_gb = E_CardBg.CB02Purple
		if is_imitater:
			curr_card_gb = E_CardBg.CB03Gray


		card_bg.texture = CradBgMap[curr_card_gb]

## 返回身份的独立副本；没有身份时返回 null，调用方自行检查。
func get_card_reference_copy() -> ResourceCardReference:
	return card_reference.copy_reference() if card_reference != null else null

## 让本卡持有独立的身份引用。[br]
## Node.duplicate() 不会复制 Resource，副本会和源卡共享同一个引用；
## 模仿者页这类要改 is_imitater 的地方必须先把引用换成副本，否则会改到源模板。
func make_reference_unique() -> void:
	if card_reference != null:
		card_reference = card_reference.copy_reference()

## 卡片初始化参数
enum E_CInitAttr{
	CardId,	## 卡片id,目前没有用到,植物卡片和僵尸卡片单独使用
	SunCost,
	CoolTime,
}

func init_card(card_init_para:Dictionary):
	card_id = card_init_para[E_CInitAttr.CardId]
	cool_time = card_init_para[E_CInitAttr.CoolTime]
	sun_cost = card_init_para[E_CInitAttr.SunCost]
