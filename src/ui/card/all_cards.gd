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

	_invalidate_seed_chooser_catalog()


func _ready() -> void:
	## ★ 编辑器里**不重建**：本脚本是 `@tool`，编辑器启动扫描会把它当 autoload 实例化，
	##   那会儿各卡节点上挂的 `card.gd` 还只是**占位脚本实例**（成员表还没建）——
	##   它只认得场景里显式写过的属性（`card_reference` 这种 `@export`），
	##   读不到 `CardBase` 上算出来的只读属性 `card_type`，于是 `rebuild()` 会在
	##   第一张卡上当场中断（GDScript 运行期错误会终止当前函数），
	##   日志里就刷出那条 *Invalid access to property or key 'card_type'
	##   on a base object of type 'Control (Card)'*（编辑器里也拿不到卡目录，
	##   而这张目录本来就是运行期数据，编辑器侧没有消费者）。
	##   运行期（含模组插卡 / 植物僵尸热注册后再调 `rebuild()`）脚本一定已编译，照常重建。
	##   ⚠️ 别把 `rebuild()` 挪到 `CardBase` 的只读属性上做判断来"修"——
	##   占位实例连 `cool_time` / `sun_cost` 都写不进去，换一行只是换个报错位置。
	if Engine.is_editor_hint():
		return
	## 非编辑器中运行隐藏(游戏中)
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
#region 可选植物列表
## 是否属于「追加在普通植物后面」的那两类植物：**运行期开关解锁的** 或 **模组新增**
##
## ★ 本体只认这两类「不是原版流程能拿到的植物」，一个模组名字都不认识 ——
##   模组新增的判据是「运行期注册的」（见 `CharacterRegistry.is_runtime_plant`）。
## ⚠️ 运行期解锁那四株**只解锁、不登记任何选卡页**（见 `_plant_choose_pages`），
##   所以这个判据现在对它们只剩一个作用：别把它们当原版常规植物排进第 1 页。
static func is_appended_plant(plant_type: StringName) -> bool:
	## 原版流程拿不到的：三种保龄球 + 反向双发（见 ConstPlantUnlock.APPENDED_PLANT_TYPES）
	if ConstPlantUnlock.APPENDED_PLANT_TYPES.has(plant_type):
		return true
	## 模组新增：本体不认识任何一个模组，只认「运行期注册的」这一类
	## （见 CharacterRegistry.register_runtime_plant_recipe / is_runtime_plant）
	return Global.character_registry.is_runtime_plant(plant_type)


## 模组登记的选卡页：句柄 → 一页的格位列表（按格位顺序，`PlantIds.NULL` = 空一格）
##
## ★ 「注册了」不等于「可选」：热注册一株植物（`CharacterRegistry`）只是让它存在，
##   想让它在选卡界面里被挑到，还得把它落到某一页的某一格上 —— 见 `register_plant_choose_page()`。
##   以前「注册 + 解锁」就等于可选，于是「只给关卡脚本 / 传送带发货、不该让玩家挑」的植物
##   也会一起挤进待选区；这道门禁把两件事分开（判据的唯一来源就是这几页 + 原版常规植物）。
##   · 运行期解锁的四株（`ConstPlantUnlock.APPENDED_PLANT_TYPES`）：解锁方只把它们并进
##     已解锁名单，**不登记**任何一页 —— 所以选卡界面里没有它们的卡位；
##   · 模组新增的：装的时候由模组自己登记（`register_plant_choose_page()`），卸的时候自己撤。
##
## ★ 为什么按页登记（而不是按株追加）：一页的排版（谁在第几格、空几格、一页放几张）
##   是模组自己的事，本体不该替它把卡片塞进「原版植物后面的连续格位」——
##   以前那样每多一株就往后挤，多一株就凭空多一页。
var _plant_choose_pages: Dictionary[int, Array] = {}
## 页的登记顺序（= 它们接在原版植物页后面的先后）
var _plant_choose_page_order: Array[int] = []
## 下一个页句柄：只增不减，撤销后不复用，免得旧句柄把后登记的一页撤掉
var _next_plant_choose_page_handle := 0


## 登记一页选卡（模组侧的唯一入口）：这一页就是模组自己排好的版
##
## [param plant_types] **按格位顺序**列出本页要出现的植物；`PlantIds.NULL` 表示这一格留空。
##   每页格数以待选卡槽的网格模板为准（当前 48 格）：超过一页的条目顺延到你这一页的下一页。
##   排版完全由调用方决定 —— 本体不重排、不补齐、不插到别的页里；页序 = 登记顺序，接在原版植物页之后。
## [return] 页句柄（>= 0），关模组时凭它 `unregister_plant_choose_page()`；登记失败返回 -1
##   （空页 / 有类型没有卡位 / 同页里同一株登记了两次）。
##
## ⚠️ 调用时机排在 `PlantRuntimeKit.install()` 之后：卡要先插进源目录（`rebuild()`），
##   这里才校验得到卡位。
func register_plant_choose_page(plant_types: Array[StringName]) -> int:
	if plant_types.is_empty():
		Log.error("AllCards：选卡页不能是空的")
		return -1
	var seen: Dictionary[StringName, bool] = {}
	var entries: Array[StringName] = []
	for plant_type: StringName in plant_types:
		if plant_type == PlantIds.NULL:
			entries.append(PlantIds.NULL)
			continue
		if not all_plant_card_prefabs.has(plant_type):
			Log.error("AllCards：选卡页里的 %s 没有卡位（先装植物，再登记页）" % plant_type)
			return -1
		if seen.has(plant_type):
			Log.error("AllCards：选卡页里 %s 登记了两次（同一张卡只能占一格）" % plant_type)
			return -1
		seen[plant_type] = true
		entries.append(plant_type)
	var handle := _next_plant_choose_page_handle
	_next_plant_choose_page_handle += 1
	_plant_choose_pages[handle] = entries
	_plant_choose_page_order.append(handle)
	_invalidate_seed_chooser_catalog()
	Log.info("AllCards：登记选卡页 #%d（%d 格）" % [handle, entries.size()])
	return handle


## 撤掉一页选卡（关模组时调）；句柄不认识时什么都不做
func unregister_plant_choose_page(handle: int) -> void:
	if not _plant_choose_pages.has(handle):
		return
	_plant_choose_pages.erase(handle)
	_plant_choose_page_order.erase(handle)
	_invalidate_seed_chooser_catalog()
	Log.info("AllCards：撤销选卡页 #%d" % handle)


## 当前登记了哪些页（按登记顺序抄一份；探针 / 调试用）
func get_registered_plant_choose_pages() -> Array[Array]:
	var pages: Array[Array] = []
	for handle: int in _plant_choose_page_order:
		var entries: Array = _plant_choose_pages.get(handle, [])
		pages.append(entries.duplicate())
	return pages


## 这株植物现在是不是可选的：原版常规植物默认可选，其余必须登记在某一页里
##
## ⚠️ 原位替换的副本**不在这里**判 true：它自己没被登记，出场只是「替原植物占那一格」
## （见 `set_plant_choose_replacement()`）；要问「它现在会不会出现在列表里」问
## `get_plant_types_in_choose_order().has(...)`。
func is_selectable_plant(plant_type: StringName) -> bool:
	if all_plant_card_prefabs.has(plant_type) and not is_appended_plant(plant_type):
		return true
	for handle: int in _plant_choose_page_order:
		var entries: Array = _plant_choose_pages.get(handle, [])
		if entries.has(plant_type):
			return true
	return false


## 选卡列表的「原位替换」表：key = 被顶掉的植物（通常是原版），value = 顶替它出场的副本
##
## ★ 与 `register_plant_choose_page()` 的分工：登记页是**自己占一整页**（格位由模组排），
##   替换是**占原来那一株的格子**（原植物本尊从选卡列表里消失，副本顶上）。
##   给「同一个东西换皮 / 换数值」的副本用（例：明日方舟模组的植物精英化）——
##   否则每种副本都会多占一格，原植物那一格还留着窟窿。
## 只管**选卡列表里的位置**：副本自己仍是运行期植物（注册 / 插卡 / 解锁照旧，不必自己撤表）。
## 表可以按关卡增删（`set_...` / `clear_plant_choose_replacement()`），典型用法见 `arknights_mod.gd`。
var _plant_choose_replacements: Dictionary[StringName, StringName] = {}


## 让 [param replacement] 在**选卡列表里顶替** [param original] 的位置（不是追加一项）
##
## [return] 本次是否登记成功（类型非法 / 源卡或替补卡没有卡位返回 false）
func set_plant_choose_replacement(original: StringName, replacement: StringName) -> bool:
	if original == PlantIds.NULL or replacement == PlantIds.NULL or original == replacement:
		return false
	if not all_plant_card_prefabs.has(original) or not all_plant_card_prefabs.has(replacement):
		Log.error("AllCards：选卡替换的源卡或替补卡没有卡位（%s → %s）" % [original, replacement])
		return false
	_plant_choose_replacements[original] = replacement
	_invalidate_seed_chooser_catalog()
	return true


## 撤掉某一株的选卡替换（回到「原植物自己占那一格」）；换关卡 / 卸模组时逐行撤
func clear_plant_choose_replacement(original: StringName) -> void:
	if not _plant_choose_replacements.has(original):
		return
	_plant_choose_replacements.erase(original)
	_invalidate_seed_chooser_catalog()


## 某一株在选卡列表里被谁顶替（没有替换返回 `PlantIds.NULL`）
func get_plant_choose_replacement(original: StringName) -> StringName:
	return _plant_choose_replacements.get(original, PlantIds.NULL)


## **可选植物列表**（摊平版）：待选区（选卡界面）与图鉴扩展页共用的那一份，顺序就是它们落位的先后
##
## 内容 = **原版常规植物**（卡片源目录里的全部，顺序固定，不需要谁去登记）
##      + **模组登记的页**（`register_plant_choose_page()`，按登记顺序接在后面，页内格位顺序照登记）。
## 玩家真正能在待选区挑到的仍是这份列表 ∩ 已解锁名单（`GlobalGameState.curr_plant`，
## 由 `CardSlotCandidate` 点亮）—— 所以「注册了但没登记进任何一页」的植物既是造不出卡位、
## 也不会被点亮，等于不存在。
##
## **原位替换**（`set_plant_choose_replacement()`）：表里登记过的原植物**不进列表**，
## 由它的副本占那一格 —— 副本因此不再按追加项排到末尾（位置与列表长度都跟原版一致）。
## 替换**只作用于原版常规植物那几页**：模组登记的页里写的是哪张卡就出哪张卡（模组自己排的版）。
##
## 为什么不能直接照 `all_plant_card_prefabs` 的顺序用：那个顺序就是卡片源目录里的节点顺序，
## 卡的编号（`card_id`）按节点顺序算（见 `rebuild()`），往中间插一张卡会让后面每一株的编号挪一格 ——
## 最后一株普通植物就被挤到下一页去了。模组（例如「水盆」）是在运行期往源目录里加卡的，
## 本体不认识任何一个模组、也没法要求它一定插在末尾，所以顺序在**消费侧**显式排一次。
func get_plant_types_in_choose_order() -> Array[StringName]:
	var plant_types: Array[StringName] = []
	var emitted: Dictionary[StringName, bool] = {}
	_append_base_plant_types(plant_types, emitted)
	for handle: int in _plant_choose_page_order:
		for plant_type: StringName in _plant_choose_pages.get(handle, []):
			## 空位：模组排版本就允许留空格
			if plant_type == PlantIds.NULL:
				continue
			## 卡已经不在目录里了（模组卸了 / 类型写错了）：跳过，这一格留空
			if not all_plant_card_prefabs.has(plant_type):
				continue
			## 模组页里的卡片**照登记时写的那张出**（不走原位替换：版是模组自己排的）
			_append_page_choose_slot(plant_types, emitted, plant_type)
	return plant_types


## 把模组页里的一格写进 [param plant_types]（不走原位替换，见 `get_plant_types_in_choose_order`）
func _append_page_choose_slot(plant_types: Array[StringName],
		emitted: Dictionary[StringName, bool], plant_type: StringName) -> void:
	if emitted.has(plant_type):
		return
	plant_types.append(plant_type)
	emitted[plant_type] = true


## 原版常规植物那一串（不含追加类，替换表照常生效）—— 摊平列表与数据层快照共用
func _append_base_plant_types(plant_types: Array[StringName],
		emitted: Dictionary[StringName, bool]) -> void:
	for plant_type: StringName in all_plant_card_prefabs:
		## 追加类（调试专属 / 模组新增）不在这里收：它们要显式登记进某一页才算可选
		if is_appended_plant(plant_type):
			continue
		_append_choose_slot(plant_types, emitted, plant_type)


## 把「某一株植物在选卡列表里的那一格」写进 [param plant_types]：
## 有原位替换就换成副本（原植物本尊不进列表），否则照旧写它自己。
##
## [param emitted] 记「已经占过格子的类型」—— 副本顶替出场后，它自己后面再被遍历到时不会再占一格。
## ⚠️ 副本的卡没了（模组卸了 / 登记失败）就照旧输出原植物，不让这一格凭空消失。
func _append_choose_slot(plant_types: Array[StringName],
		emitted: Dictionary[StringName, bool], plant_type: StringName) -> void:
	var replacement: StringName = get_plant_choose_replacement(plant_type)
	var slot_type: StringName = plant_type
	if replacement != PlantIds.NULL and all_plant_card_prefabs.has(replacement):
		slot_type = replacement
	if emitted.has(slot_type):
		return
	plant_types.append(slot_type)
	emitted[slot_type] = true
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


#region 选卡候选卡池快照（跨关卡持久）
## 当前快照；为 null 或版本不一致时在 `get_seed_chooser_catalog()` 里重建
var _seed_chooser_catalog: CardSeedChooserCatalog = null
## 卡池内容版本：登记页 / 原位替换 / 卡目录有一处变化就 +1
var _seed_chooser_catalog_version := 0
## 上次生成快照时「敌方页开关」的值：调试模式开关会让页的构成变化，也要重建
var _seed_chooser_catalog_zombie_page := false


## 选卡候选卡池快照（**数据层唯一来源**，跨关卡复用）
##
## 待选卡槽只拿这份快照排页 / 按顺序造卡位，不再自己现场算顺序：
## 第一次查询时建好并常驻在 autoload 里，之后换关直接返回同一个对象；
## 卡池真的变了（`rebuild()`、登记页 / 原位替换、调试模式开关）才重建一次。
func get_seed_chooser_catalog() -> CardSeedChooserCatalog:
	var zombie_page: bool = Global.global_game_state.is_zombie_card_enabled()
	if _seed_chooser_catalog == null \
		or _seed_chooser_catalog.version != _seed_chooser_catalog_version \
		or _seed_chooser_catalog_zombie_page != zombie_page:
		_seed_chooser_catalog = _build_seed_chooser_catalog(zombie_page)
	return _seed_chooser_catalog


## 按当前目录内容生成一份新快照（条目仍指向源卡节点，不做副本）
##
## 分两块交给 UI：原版常规植物是一串连续列表（由 UI 按每页格数切页），
## 模组登记的页则**保留格位**（`null` = 空一格），UI 原样照搬、不重排。
func _build_seed_chooser_catalog(zombie_page: bool) -> CardSeedChooserCatalog:
	var catalog := CardSeedChooserCatalog.new()
	catalog.version = _seed_chooser_catalog_version
	catalog.has_enemy_page = zombie_page
	## 已经输出过的卡：同一张卡只能有一个卡位（容器 / 禁选 / 预选都按 card_id 找它）
	var emitted: Dictionary[StringName, bool] = {}
	var base_types: Array[StringName] = []
	_append_base_plant_types(base_types, emitted)
	for plant_type: StringName in base_types:
		var plant_card: Card = all_plant_card_prefabs.get(plant_type)
		if plant_card == null:
			continue
		catalog.plants.append(plant_card)
	for handle: int in _plant_choose_page_order:
		var entries: Array = _plant_choose_pages.get(handle, [])
		var page_cards: Array[Card] = []
		page_cards.resize(entries.size())
		for slot_index: int in entries.size():
			var plant_type: StringName = entries[slot_index]
			if plant_type == PlantIds.NULL or not all_plant_card_prefabs.has(plant_type):
				continue
			## 这一张已经在原版页或前面某一页出现过：这一格留空（同一张卡不占两格）
			if emitted.has(plant_type):
				continue
			emitted[plant_type] = true
			page_cards[slot_index] = all_plant_card_prefabs[plant_type]
		catalog.plant_pages.append(page_cards)
	if zombie_page:
		catalog.enemies = get_enemy_cards_in_choose_order()
	_seed_chooser_catalog_zombie_page = zombie_page
	return catalog


## 卡池内容变了：让下次查询重建快照（调用点见 rebuild / 登记页 / 原位替换那几个口子）
func _invalidate_seed_chooser_catalog() -> void:
	_seed_chooser_catalog_version += 1
#endregion
