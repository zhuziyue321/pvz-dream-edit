extends RefCounted
class_name ConstPlantUnlock
## 植物解锁进度常量
## 数据来源: PVZ Wiki 植物图鉴(https://wiki.pvz1.com/doku.php?id=教程:植物图鉴)
## 冒险模式 50 关的关卡序号: 1-1 = 1 …… 5-10 = 50(即 (区域-1)*10 + 小关号)

## 初始拥有的植物
const INIT_PLANT_TYPES: Array[CharacterRegistry.PlantType] = [
	CharacterRegistry.PlantType.P001PeaShooterSingle,
]

## 通关冒险模式某一关后解锁的植物(白卡)
## 键为冒险模式关卡序号,值为该关通关后获得的植物
const ADVENTURE_LEVEL_UNLOCK_PLANT: Dictionary = {
	1: [CharacterRegistry.PlantType.P002SunFlower],		## 1-1 向日葵
	2: [CharacterRegistry.PlantType.P003CherryBomb],		## 1-2 樱桃炸弹
	3: [CharacterRegistry.PlantType.P004WallNut],		## 1-3 坚果
	5: [CharacterRegistry.PlantType.P005PotatoMine],		## 1-5 土豆地雷
	6: [CharacterRegistry.PlantType.P006SnowPea],		## 1-6 寒冰射手
	7: [CharacterRegistry.PlantType.P007Chomper],		## 1-7 大嘴花
	8: [CharacterRegistry.PlantType.P008PeaShooterDouble],	## 1-8 双发射手
	10: [CharacterRegistry.PlantType.P009PuffShroom],	## 1-10 小喷菇
	11: [CharacterRegistry.PlantType.P010SunShroom],		## 2-1 阳光菇
	12: [CharacterRegistry.PlantType.P011FumeShroom],	## 2-2 大喷菇
	13: [CharacterRegistry.PlantType.P012GraveBuster],	## 2-3 墓碑吞噬者
	15: [CharacterRegistry.PlantType.P013HypnoShroom],	## 2-5 魅惑菇
	16: [CharacterRegistry.PlantType.P014ScaredyShroom],	## 2-6 胆小菇
	17: [CharacterRegistry.PlantType.P015IceShroom],		## 2-7 寒冰菇
	18: [CharacterRegistry.PlantType.P016DoomShroom],	## 2-8 毁灭菇
	20: [CharacterRegistry.PlantType.P017LilyPad],		## 2-10 睡莲
	21: [CharacterRegistry.PlantType.P018Squash],		## 3-1 窝瓜
	22: [CharacterRegistry.PlantType.P019ThreePeater],	## 3-2 三线射手
	23: [CharacterRegistry.PlantType.P020TangleKelp],	## 3-3 缠绕海草
	25: [CharacterRegistry.PlantType.P021Jalapeno],		## 3-5 火爆辣椒
	26: [CharacterRegistry.PlantType.P022Caltrop],		## 3-6 地刺
	27: [CharacterRegistry.PlantType.P023TorchWood],		## 3-7 火炬树桩
	28: [CharacterRegistry.PlantType.P024TallNut],		## 3-8 高坚果
	30: [CharacterRegistry.PlantType.P025SeaShroom],		## 3-10 海蘑菇
	31: [CharacterRegistry.PlantType.P026Plantern],		## 4-1 路灯花
	32: [CharacterRegistry.PlantType.P027Cactus],		## 4-2 仙人掌
	33: [CharacterRegistry.PlantType.P028Blover],		## 4-3 三叶草
	35: [CharacterRegistry.PlantType.P029SplitPea],		## 4-5 裂荚射手
	36: [CharacterRegistry.PlantType.P030StarFruit],		## 4-6 杨桃
	37: [CharacterRegistry.PlantType.P031Pumpkin],		## 4-7 南瓜
	38: [CharacterRegistry.PlantType.P032MagnetShroom],	## 4-8 磁力菇
	40: [CharacterRegistry.PlantType.P033CabbagePult],	## 4-10 卷心菜投手
	41: [CharacterRegistry.PlantType.P034FlowerPot],		## 5-1 花盆
	42: [CharacterRegistry.PlantType.P035CornPult],		## 5-2 玉米投手
	43: [CharacterRegistry.PlantType.P036CoffeeBean],	## 5-3 咖啡豆
	45: [CharacterRegistry.PlantType.P037Garlic],		## 5-5 大蒜
	46: [CharacterRegistry.PlantType.P038UmbrellaLeaf],	## 5-6 叶子保护伞
	47: [CharacterRegistry.PlantType.P039MariGold],		## 5-7 金盏花
	48: [CharacterRegistry.PlantType.P040MelonPult],		## 5-8 西瓜投手
}

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

## 冒险模式关卡序号 -> 该关解锁的植物(没有则返回空数组)
static func get_unlock_plant_on_adventure_level(adventure_level: int) -> Array:
	return ADVENTURE_LEVEL_UNLOCK_PLANT.get(adventure_level, [])

## 冒险模式该关(含之前所有关卡)通关后,累计解锁的全部植物
static func get_all_unlock_plant_until_adventure_level(adventure_level: int) -> Array[CharacterRegistry.PlantType]:
	var result: Array[CharacterRegistry.PlantType] = []
	for plant_type in INIT_PLANT_TYPES:
		result.append(plant_type)
	for i in range(1, adventure_level + 1):
		for plant_type in get_unlock_plant_on_adventure_level(i):
			if not result.has(plant_type):
				result.append(plant_type)
	return result

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
