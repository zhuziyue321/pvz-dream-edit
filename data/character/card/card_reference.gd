## 卡牌身份与植物模仿修饰；模板和关卡中的引用按只读使用，不保存费用或运行状态。
@tool
extends Resource
class_name ResourceCardReference

## 卡牌内容类别；编号用于选卡记录，新增类别时保持已有编号不变。
##
## ⚠️ 这个枚举**不是角色编号**，只是「这张卡属于哪一大类」，仍然用 int（写进存档的 card_type 也是它）。
## 角色本身是哪一种由 `content_id` 表达，那个才是 StringName id（2026-10-13 起）。
enum CardType {
	Null = 0, ## 编辑器中尚未配置的引用，不参与注册。
	Plant = 1, ## 植物卡牌。
	Zombie = 2, ## 普通僵尸卡牌。
	ZombieBoss = 3, ## 僵王卡牌，用于图鉴展示、普通卡槽和临时卡召唤。
}

## 内容类别；切换类别时清空角色 id，要求重新选择该类别的角色。
@export var card_type: CardType = CardType.Null:
	set(value):
		if card_type == value:
			return
		card_type = value
		content_id = &""
		if card_type != CardType.Plant:
			is_imitater = false
		notify_property_list_changed()
## 所选类别的角色 id（StringName，见 `PlantIds` / `ZombieIds` / `ZombieBossIds`）；空串表示未配置，不能用于生成卡牌。
##
## 为什么不再是 int：原来这里存数字编号（`content_id <= 0` 判空、`PlantType.values().has()` 校验），
## 编号换语义 id 后，数字无从表达「这是豌豆射手」。现在是 `&"pea_shooter"` 这种字符串 id。
@export var content_id: StringName = &""
## 植物模仿修饰；id 仍指向被模仿植物，不另注册模板。
@export var is_imitater: bool = false


## 创建一份独立引用；[param type] 为卡牌类别，[param id] 为角色 id。
## [param imitater] 仅适用于具体植物；非法组合可由 [method is_valid] 检出。
static func create(type: int, id: StringName, imitater: bool = false) -> ResourceCardReference:
	# 新引用不与模板或关卡共享可写属性。
	var card_ref := ResourceCardReference.new()
	# 类别可能来自存档整数，赋值时显式转换为卡牌枚举，合法性仍由 is_valid 判断。
	card_ref.card_type = type as CardType
	card_ref.content_id = id
	card_ref.is_imitater = imitater
	return card_ref


## 返回独立身份副本；显式构造确保类别先于角色 id 赋值，不依赖 Resource 属性复制顺序。
func copy_reference() -> ResourceCardReference:
	return create(card_type, content_id, is_imitater)


#region 关卡配置批量构造
## 把关卡脚本 / 卡资源里写的角色 id 统一成 StringName id。
##
## 这是**数据层的边界**：本文件是 `@tool` 脚本，卡资源由编辑器加载器直接反序列化，
## 传进来的原始值不受本仓库代码控制，所以保留 `from_legacy()` 兜住老编号
## （`StringName(1001)` 在运行期会直接报 `Nonexistent 'StringName' constructor`，
## StringName 只有 String / StringName 两个构造）。
## 认不出来返回空 id（`&""`），由 [method is_valid] 兜底；这里不打日志 ——
## 本文件是 `@tool` 数据层脚本，编译期拿不到 `Log` 这个 autoload（`Identifier not found: Log`）。
static func normalize_id(type: CardType, value: Variant) -> StringName:
	var id := &""
	match type:
		CardType.Plant:
			id = PlantIds.from_legacy(value)
		CardType.Zombie:
			id = ZombieIds.from_legacy(value)
		CardType.ZombieBoss:
			id = ZombieBossIds.from_legacy(value)
	return id


## 关卡脚本写卡片配置用的语法糖：把角色 id 列表批量转成独立引用。
## 每个引用都是新建对象，不共享，关卡资源与运行期修改互不影响。
## 列表元素既可以是 id 字符串（`PlantIds.XXX`），也可以是老编号 int（见 [method normalize_id]）。

## 批量构造植物引用；[param ids] 为植物 id 列表，顺序保留。
static func create_plant_list(ids: Array) -> Array[ResourceCardReference]:
	return _create_list(CardType.Plant, ids)


## 批量构造普通僵尸引用；[param ids] 为僵尸 id 列表，顺序保留。
static func create_zombie_list(ids: Array) -> Array[ResourceCardReference]:
	return _create_list(CardType.Zombie, ids)


## 批量构造僵王引用；[param ids] 为僵王 id 列表，顺序保留。
static func create_boss_list(ids: Array) -> Array[ResourceCardReference]:
	return _create_list(CardType.ZombieBoss, ids)


## 按生成序号构造植物引用字典；键为生成序号，值为植物 id。
static func create_plant_order(order: Dictionary) -> Dictionary[int, ResourceCardReference]:
	return _create_order(CardType.Plant, order)


## 按生成序号构造普通僵尸引用字典；键为生成序号，值为僵尸 id。
static func create_zombie_order(order: Dictionary) -> Dictionary[int, ResourceCardReference]:
	return _create_order(CardType.Zombie, order)


static func _create_list(type: CardType, ids: Array) -> Array[ResourceCardReference]:
	var result: Array[ResourceCardReference] = []
	for id in ids:
		## 老编号 int 也要认（`StringName(1001)` 是运行期报错，见 normalize_id 的说明）
		result.append(create(type, normalize_id(type, id)))
	return result


static func _create_order(type: CardType, order: Dictionary) -> Dictionary[int, ResourceCardReference]:
	var result: Dictionary[int, ResourceCardReference] = {}
	for index in order:
		result[int(index)] = create(type, normalize_id(type, order[index]))
	return result
#endregion


## 返回是否为已定义的非空角色，模仿修饰不能用于其他类别或模仿者选择入口。
##
## ⚠️ 这里只认**内置**角色：运行期热注册的模组角色（`register_runtime_plant()` /
## `register_runtime_zombie()`）不在 `ALL` 里，与改之前 `enum.values().has()` 的口径一致。
func is_valid() -> bool:
	if content_id == &"":
		return false
	if is_imitater and (card_type != CardType.Plant or content_id == PlantIds.IMITATER):
		return false
	match card_type:
		CardType.Plant:
			return PlantIds.ALL.has(content_id)
		CardType.Zombie:
			return ZombieIds.ALL.has(content_id)
		CardType.ZombieBoss:
			return ZombieBossIds.ALL.has(content_id)
	return false


## 类别在键里的标签（键是给人看的，见 [method get_template_key]）
static func type_tag(type: CardType) -> String:
	match type:
		CardType.Plant:
			return "plant"
		CardType.Zombie:
			return "zombie"
		CardType.ZombieBoss:
			return "zombie_boss"
	return "null"


## 返回模板身份的键；普通卡和模仿卡共用目标植物模板。
##
## 原来是 `Vector2i(card_type, content_id)`：装得下两个 int，装不下字符串 id，
## 所以改成 `&"plant:pea_shooter"` 这种**人能读的字符串键** —— 打印日志时一眼看得出是哪张卡。
func get_template_key() -> StringName:
	return "%s:%s" % [type_tag(card_type), content_id]


## 返回包含模仿修饰的选卡键，用于区分同一植物的两张备选卡。
func get_selection_key() -> StringName:
	return "%s:%s:%d" % [type_tag(card_type), content_id, int(is_imitater)]


## 返回可直接写入 JSON 的选卡数据，不将 Resource 对象交给 JSON 编码器。
func to_dict() -> Dictionary:
	return {"card_type": card_type, "content_id": content_id, "is_imitater": is_imitater}


## 从当前格式还原引用；[param data] 必须包含三个字段，旧格式或非法值返回 null。
##
## 调用方是**联机模组**（`netplay_battle_sync` / `netplay_card_spawn_sync` 解对端发来的卡），
## 对端与本端版本可能不一致，所以 content_id 同时认**数字编号**（老版本对端）与
## **字符串 id**（当前格式），数字按类别走各自的 `from_legacy()` 转成 id。
## 注意：老存档的选卡**不走这里**，读档那条路在 `save_service._normalize_selected_cards()`。
static func from_dict(data: Dictionary) -> ResourceCardReference:
	if typeof(data.get("is_imitater")) != TYPE_BOOL:
		return null
	var raw_type: Variant = data.get("card_type")
	if typeof(raw_type) != TYPE_INT and typeof(raw_type) != TYPE_FLOAT:
		return null
	var type := int(raw_type)
	var raw_id: Variant = data.get("content_id")
	var id := &""
	match type:
		CardType.Plant:
			id = PlantIds.from_legacy(raw_id)
		CardType.Zombie:
			id = ZombieIds.from_legacy(raw_id)
		CardType.ZombieBoss:
			id = ZombieBossIds.from_legacy(raw_id)
	if id == &"":
		return null
	var card_ref := create(type, id, data["is_imitater"])
	return card_ref if card_ref.is_valid() else null


## 为 [param property] 中的角色 id 提供当前类别的可选值；不依赖运行中的 Global。
func _validate_property(property: Dictionary) -> void:
	if property.name != "content_id":
		return
	# 当前类别的角色 id 列表（改之前是把整个 enum 摊成 "名称:编号" 选项，现在直接给 id）
	var options := PackedStringArray()
	match card_type:
		CardType.Plant:
			options.append(PlantIds.NULL)
			options.append_array(PlantIds.ALL)
		CardType.Zombie:
			options.append(ZombieIds.NULL)
			options.append_array(ZombieIds.ALL)
		CardType.ZombieBoss:
			options.append(ZombieBossIds.NULL)
			options.append_array(ZombieBossIds.ALL)
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(options)
