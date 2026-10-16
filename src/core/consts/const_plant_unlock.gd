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
const INIT_PLANT_TYPES: Array[StringName] = [
	PlantIds.PEA_SHOOTER_SINGLE,
]

## 控制台「调试模式」打开才解锁的植物：三种保龄球 + 反向双发
## （坚果保龄球 / 爆炸坚果保龄球 / 巨型坚果墙保龄球 / 反向双发射手）
##
## 这四株的本体与卡片都是现成的：既有行为（`src/entities/character/plant/plant_wall_nut_bowling*.tscn`、
## `plant_pea_shooter_double_reverse.tscn`），也有卡片（AllCards 第二页的前四张，
## 也就是选卡界面第 2 页的前四格）。
## 但正常流程不解锁它们 —— 玩家只有「坚果保龄球」两个关卡里由传送带发货，
## 反向双发在原版里是「一路向左」那类特殊关 NPC 发货，也没有任何关卡给过种子包。
## 想随手把它们当普通植物玩，就去控制台开「调试模式」（同步逻辑见 GlobalGameState.apply_debug_mode）。
const DEBUG_MODE_PLANT_TYPES: Array[StringName] = [
	PlantIds.WALL_NUT_BOWLING,
	PlantIds.WALL_NUT_BOWLING_BOMB,
	PlantIds.WALL_NUT_BOWLING_BIG,
	PlantIds.PEA_SHOOTER_DOUBLE_REVERSE,
]

## 紫卡植物与模仿者: 不通关直接获得,需通关对应关卡后在疯狂戴夫商店花钱购买
## 键为植物类型,值为"通关该关卡后开放购买"的关卡序号
const PURPLE_CARD_CAN_BUY_LEVEL: Dictionary = {
	PlantIds.GATLING_PEA: 24,		## 3-4 后 $5000
	PlantIds.TWIN_SUN_FLOWER: 24,	## 3-4 后 $5000
	PlantIds.GLOOM_SHROOM: 34,	## 4-4 后 $7500
	PlantIds.CATTAIL: 34,		## 4-4 后 $10000
	PlantIds.GOLD_MAGNET: 41,		## 5-1 后 $3000
	PlantIds.SPIKE_ROCK: 41,		## 5-1 后 $7500
	PlantIds.WINTER_MELON: 50,	## 通关冒险模式后 $10000
	PlantIds.COB_CANNON: 50,		## 通关冒险模式后 $20000
	PlantIds.IMITATER: 50,		## 通关冒险模式后 $30000
}

## 紫卡植物与模仿者在疯狂戴夫商店的售价
## 这些植物不会通过通关冒险模式直接获得,只能在商店上架后花钱购买
const PURPLE_CARD_PRICE: Dictionary = {
	PlantIds.GATLING_PEA: 5000,
	PlantIds.TWIN_SUN_FLOWER: 5000,
	PlantIds.GLOOM_SHROOM: 7500,
	PlantIds.CATTAIL: 10000,
	PlantIds.GOLD_MAGNET: 3000,
	PlantIds.SPIKE_ROCK: 7500,
	PlantIds.WINTER_MELON: 10000,
	PlantIds.COB_CANNON: 20000,
	PlantIds.IMITATER: 30000,
}

## 紫卡植物当前是否已开放购买(通关对应关卡后)
static func is_purple_card_can_buy(plant_type: StringName, max_success_adventure_level: int) -> bool:
	if not PURPLE_CARD_CAN_BUY_LEVEL.has(plant_type):
		return false
	return max_success_adventure_level >= int(PURPLE_CARD_CAN_BUY_LEVEL[plant_type])

## 商店出售的植物(紫卡 + 模仿者),按上架顺序排列
static func get_all_shop_plant_types() -> Array[StringName]:
	var result: Array[StringName] = []
	for plant_type in PURPLE_CARD_PRICE:
		## 交 String 就行：数组是 `Array[StringName]`，GDScript 会自己转
		result.append(str(plant_type))
	return result

## 该植物在商店的售价,非商店商品返回 0
static func get_shop_plant_price(plant_type: StringName) -> int:
	return int(PURPLE_CARD_PRICE.get(plant_type, 0))

## 该植物是否为商店商品(紫卡或模仿者)
static func is_shop_plant(plant_type: StringName) -> bool:
	return PURPLE_CARD_PRICE.has(plant_type)
