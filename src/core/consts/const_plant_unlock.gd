extends RefCounted
class_name ConstPlantUnlock
## 植物解锁进度常量
## 数据来源: PVZ Wiki 植物图鉴(https://wiki.pvz1.com/doku.php?id=教程:植物图鉴)
##
## ⚠️ **「冒险第 N 关给哪株植物」不写在这里** —— 那一句话写在那一关的脚本上
## （`src/levels/mode_adventure/adventure_<大关>_<小关>.gd` 的 `_init()`：
## `level_complete_loot = "sunflower_seed_packet"`，名字 -> 植物编号那张表在 LootRegistry），
## 既决定本关掉的那一包种子（战利品），也决定通关解锁的那株植物
## （解锁侧见 GlobalGameState.unlock_plant_on_adventure_level）。
## 这里只留「与具体关卡无关的」植物进度：初始植物、紫卡上架关与售价。

## 初始拥有的植物
const INIT_PLANT_TYPES: Array[CharacterRegistry.PlantType] = [
	CharacterRegistry.PlantType.P001PeaShooterSingle,
]

## 紫卡植物与模仿者: 不通关直接获得,需通关对应关卡后在疯狂戴夫商店花钱购买
## 键为植物类型,值为"通关该关卡后开放购买"的关卡序号
const PURPLE_CARD_CAN_BUY_LEVEL: Dictionary = {
	CharacterRegistry.PlantType.P041GatlingPea: 24,		## 3-4 后 $5000
	CharacterRegistry.PlantType.P042TwinSunFlower: 24,	## 3-4 后 $5000
	CharacterRegistry.PlantType.P043GloomShroom: 34,	## 4-4 后 $7500
	CharacterRegistry.PlantType.P044Cattail: 34,		## 4-4 后 $10000
	CharacterRegistry.PlantType.P046GoldMagnet: 41,		## 5-1 后 $3000
	CharacterRegistry.PlantType.P047SpikeRock: 41,		## 5-1 后 $7500
	CharacterRegistry.PlantType.P045WinterMelon: 50,	## 通关冒险模式后 $10000
	CharacterRegistry.PlantType.P048CobCannon: 50,		## 通关冒险模式后 $20000
	CharacterRegistry.PlantType.P999Imitater: 50,		## 通关冒险模式后 $30000
}

## 紫卡植物与模仿者在疯狂戴夫商店的售价
## 这些植物不会通过通关冒险模式直接获得,只能在商店上架后花钱购买
const PURPLE_CARD_PRICE: Dictionary = {
	CharacterRegistry.PlantType.P041GatlingPea: 5000,
	CharacterRegistry.PlantType.P042TwinSunFlower: 5000,
	CharacterRegistry.PlantType.P043GloomShroom: 7500,
	CharacterRegistry.PlantType.P044Cattail: 10000,
	CharacterRegistry.PlantType.P046GoldMagnet: 3000,
	CharacterRegistry.PlantType.P047SpikeRock: 7500,
	CharacterRegistry.PlantType.P045WinterMelon: 10000,
	CharacterRegistry.PlantType.P048CobCannon: 20000,
	CharacterRegistry.PlantType.P999Imitater: 30000,
}

## 紫卡植物当前是否已开放购买(通关对应关卡后)
static func is_purple_card_can_buy(plant_type: CharacterRegistry.PlantType, max_success_adventure_level: int) -> bool:
	if not PURPLE_CARD_CAN_BUY_LEVEL.has(plant_type):
		return false
	return max_success_adventure_level >= int(PURPLE_CARD_CAN_BUY_LEVEL[plant_type])

## 商店出售的植物(紫卡 + 模仿者),按上架顺序排列
static func get_all_shop_plant_types() -> Array[CharacterRegistry.PlantType]:
	var result: Array[CharacterRegistry.PlantType] = []
	for plant_type in PURPLE_CARD_PRICE:
		result.append(int(plant_type) as CharacterRegistry.PlantType)
	return result

## 该植物在商店的售价,非商店商品返回 0
static func get_shop_plant_price(plant_type: CharacterRegistry.PlantType) -> int:
	return int(PURPLE_CARD_PRICE.get(plant_type, 0))

## 该植物是否为商店商品(紫卡或模仿者)
static func is_shop_plant(plant_type: CharacterRegistry.PlantType) -> bool:
	return PURPLE_CARD_PRICE.has(plant_type)
