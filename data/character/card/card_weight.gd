## 传送带和种子雨共用的卡牌权重条目；引用描述身份，权重描述相对出现概率。
extends Resource
class_name ResourceCardWeight

## 参与抽取的植物或普通僵尸引用；随机池入口明确拒绝僵王。
@export var card_reference: ResourceCardReference
## 相对权重；0 不参与抽取，负数和全部为零的池由初始化入口拒绝。
@export_range(0, 100000, 1, "or_greater") var weight: int = 1


## 构造单条权重；[param card_ref] 为身份引用，[param value] 为相对权重。
## 注意：参数不能命名为 reference，会遮蔽 RefCounted.reference() 触发 SHADOWED_VARIABLE_BASE_CLASS。
static func create(card_ref: ResourceCardReference, value: int) -> ResourceCardWeight:
	var entry := ResourceCardWeight.new()
	entry.card_reference = card_ref
	entry.weight = value
	return entry


#region 关卡配置批量构造
## 把 {角色编号: 权重} 批量转成权重条目数组，供关卡脚本直接赋值给 LevelData。
## 与 [method ResourceCardReference.create_plant_list] 配套使用，保持一处配置一张表。

## 批量构造植物权重；[param weights] 键为植物编号，值为相对权重。
static func create_plant_weights(weights: Dictionary) -> Array[ResourceCardWeight]:
	return _create_weights(ResourceCardReference.CardType.Plant, weights)


## 批量构造普通僵尸权重；[param weights] 键为僵尸编号，值为相对权重。
static func create_zombie_weights(weights: Dictionary) -> Array[ResourceCardWeight]:
	return _create_weights(ResourceCardReference.CardType.Zombie, weights)


static func _create_weights(type: ResourceCardReference.CardType, weights: Dictionary) -> Array[ResourceCardWeight]:
	var result: Array[ResourceCardWeight] = []
	for content_id in weights:
		result.append(create(ResourceCardReference.create(type, int(content_id)), int(weights[content_id])))
	return result
#endregion
