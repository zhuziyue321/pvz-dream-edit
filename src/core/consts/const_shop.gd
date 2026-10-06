extends RefCounted
class_name ConstShop
## 疯狂戴夫商店的商品常量(植物卡片类商品的解锁关卡与售价见 ConstPlantUnlock)

## 存档的出战卡槽基准数(原版初始 6 格)
## 关卡资源没写 max_choosed_card_num 时,出战卡槽数 = 本值 + 已购扩充次数
## 见 GlobalGameState.get_card_slot_num()
const BASE_CARD_SLOT_NUM := 6

## 出战卡槽上限(原版最高 10 格)
## 卡槽扩充最多可购买 MAX_CARD_SLOT_NUM - BASE_CARD_SLOT_NUM 次
const MAX_CARD_SLOT_NUM := 10

## 卡槽扩充的分档售价(下标 = 已购买次数)
## 6->7 槽 $750、7->8 槽 $5000、8->9 槽 $20000、9->10 槽 $80000
## 商店(GoodsCardSlot)与 2-2 开场戴夫推销(DaveSellManager)共用这一份价格表,不要各写一份
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Seed_slot)
## 口径: 原版一代 PC,数组长度与 get_max_card_slot_upgrade_num() 一致
const CARD_SLOT_UPGRADE_PRICES: Array[int] = [750, 5000, 20000, 80000]


## 卡槽扩充最多可购买次数
static func get_max_card_slot_upgrade_num() -> int:
	return maxi(0, MAX_CARD_SLOT_NUM - BASE_CARD_SLOT_NUM)


#region 禅境花园类商品(原版 Crazy Dave's Twiddydinkies 的 Zen Garden 段)
## 花园背景类商品售价(键为 GardenManager.E_GardenBgType)
## 原版商店只出售蘑菇园与水族馆;阳光房是玩家默认就有的花园,不卖
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Crazy_Dave%27s_Twiddydinkies)
## 口径: 原版一代 PC;这类商品买一次即 Sold Out,不能重复购买
const GARDEN_BG_PRICE: Dictionary = {
	GardenManager.E_GardenBgType.MushroomGraden: 30000,
	GardenManager.E_GardenBgType.Aquarium: 30000,
}

## 智慧树售价
const TREE_OF_WISDOM_PRICE := 10000

## 金盏花幼苗售价
const MARIGOLD_SPROUT_PRICE := 2500

## 货架上摆几个植物盆(原版: "Only three can be bought per day")
## 每个盆槽位当天只能买一次(见 MARIGOLD_SPROUT_SLOT_BUY_DATE_KEY),
## 所以这也是每天最多能买到的幼苗数
const MARIGOLD_SPROUT_DAILY_LIMIT := 3

## garden_data 中"每个植物盆槽位最近一次购买的日期"的键
## 值是一个字典: {槽位序号字符串: 日期字符串(YYYY-MM-DD)},
## 某个槽位记的日期是今天就视为"该盆当天已售罄",跨自然日自动恢复
const MARIGOLD_SPROUT_SLOT_BUY_DATE_KEY := "marigold_sprout_slot_buy_date"
## garden_data 中"智慧树是否已购买"的键
const TREE_OF_WISDOM_BOUGHT_KEY := "is_tree_of_wisdom_bought"
## garden_data 中"智慧树长到多少英尺"的键(喂一袋树肥料 +1 英尺)
const TREE_OF_WISDOM_HEIGHT_KEY := "tree_of_wisdom_height"

## 花园工具类商品售价
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Crazy_Dave%27s_Twiddydinkies)
## 口径: 原版一代 PC
##   黄金水壶 $10000(一次浇 4 株)、留声机 $15000、园艺手套 $1000:买断型,买一次即"已拥有"
##   肥料 $750 / 5 个、杀虫剂 $1000 / 5 个:消耗型,用完可以再买,持有上限 TOOL_MAX_OWN_NUM
const GOLD_WATERING_CAN_PRICE := 10000
const PHONOGRAPH_PRICE := 15000
const GARDENING_GLOVE_PRICE := 1000
const FERTILIZER_PRICE := 750
const BUG_SPRAY_PRICE := 1000
## 蜗牛售价(买断:买了就在花园里待着帮忙捡钱,见 Stinky)
const SNAIL_PRICE := 3000
## 巧克力售价(一份 5 个,喂蜗牛让它爬得快)
## ⚠️ 巧克力**不在商店货架上**:库存只来自僵尸掉落,而且要买了蜗牛之后才开始掉
## (见 DropItemComponent.drop_chocolate;原版口径 "Chocolate will not appear until the
## player purchases Stinky the Snail",取自 https://plantsvszombies.wiki.gg/wiki/Chocolate)
## 这里的价格只用于"它是消耗品"的判定(在 CONSUMABLE_GARDEN_TOOL_PRICE 里),货架上没有对应商品
const CHOCOLATE_PRICE := 1000

## 买一次消耗型工具给几个(原版: "$750 for five")
## 例外是树肥料: 原版一次只卖一袋(见 ConstTreeOfWisdom.TREE_FOOD_NUM_PER_BUY)
const TOOL_NUM_PER_BUY := 5
## 消耗型工具的持有上限(原版: "max of twenty can be owned at any given time")
## 例外是树肥料: 原版一次最多囤 10 袋(见 ConstTreeOfWisdom.TREE_FOOD_MAX_OWN_NUM)
const TOOL_MAX_OWN_NUM := 20

## 买断型工具的售价(买了永久拥有),见 GlobalGameState.is_garden_tool_bought
const ONE_TIME_GARDEN_TOOL_PRICE: Dictionary = {
	GardenManager.E_GardenTool.GoldWateringCan: GOLD_WATERING_CAN_PRICE,
	GardenManager.E_GardenTool.Phonograph: PHONOGRAPH_PRICE,
	GardenManager.E_GardenTool.GardeningGlove: GARDENING_GLOVE_PRICE,
	GardenManager.E_GardenTool.Snail: SNAIL_PRICE,
}
## 消耗型工具一份的售价,见 GlobalGameState.get_garden_tool_num
const CONSUMABLE_GARDEN_TOOL_PRICE: Dictionary = {
	GardenManager.E_GardenTool.Fertilizer: FERTILIZER_PRICE,
	GardenManager.E_GardenTool.BugSpray: BUG_SPRAY_PRICE,
	GardenManager.E_GardenTool.Chocolate: CHOCOLATE_PRICE,
	GardenManager.E_GardenTool.TreeFood: ConstTreeOfWisdom.TREE_FOOD_PRICE,
}

## 该花园工具的售价,不在商店出售的工具返回 0
static func get_garden_tool_price(tool_type: GardenManager.E_GardenTool) -> int:
	if ONE_TIME_GARDEN_TOOL_PRICE.has(tool_type):
		return int(ONE_TIME_GARDEN_TOOL_PRICE[tool_type])
	return int(CONSUMABLE_GARDEN_TOOL_PRICE.get(tool_type, 0))

## 该消耗型工具买一份能得几个(买断型恒为 0)
static func get_garden_tool_num_per_buy(tool_type: GardenManager.E_GardenTool) -> int:
	if tool_type == GardenManager.E_GardenTool.TreeFood:
		return ConstTreeOfWisdom.TREE_FOOD_NUM_PER_BUY
	return TOOL_NUM_PER_BUY if CONSUMABLE_GARDEN_TOOL_PRICE.has(tool_type) else 0

## 该消耗型工具的持有上限(商品页据此禁售);买断型用不到这个数,仍返回通用上限
static func get_tool_max_own_num(tool_type: GardenManager.E_GardenTool) -> int:
	if tool_type == GardenManager.E_GardenTool.TreeFood:
		return ConstTreeOfWisdom.TREE_FOOD_MAX_OWN_NUM
	return TOOL_MAX_OWN_NUM

## 花园背景类商品的售价,非商店出售的背景返回 0
static func get_garden_bg_price(bg_type: GardenManager.E_GardenBgType) -> int:
	return int(GARDEN_BG_PRICE.get(bg_type, 0))
#endregion


#region 防御道具类商品
## 水路小推车(泳池清洁车)售价
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Pool_Cleaner)
## 口径: 原版一代 PC
const POOL_CLEANER_PRICE := 1000

## 屋顶小推车(屋顶清洁车)售价
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Roof_Cleaner)
## 口径: 原版一代 PC
const ROOF_CLEANER_PRICE := 3000

## 清洁车类商品的售价映射(普通草坪小推车免费配发,不在这个字典里)
const CLEANER_PRICE: Dictionary = {
	GIM_LawnMover.E_LawnMoverType.PoolCleaner: POOL_CLEANER_PRICE,
	GIM_LawnMover.E_LawnMoverType.RoofCleaner: ROOF_CLEANER_PRICE,
}

## 清洁车类商品上架所需的冒险模式关卡序号
## 原版:每个关卡场景(Fog / Roof)开始时会有一批新商品上架 ——
## 水路清洁车随商店解锁(3-4)出现,屋顶清洁车要等到进入屋顶(5-1)才出现
const CLEANER_SHOP_LEVEL: Dictionary = {
	GIM_LawnMover.E_LawnMoverType.PoolCleaner: ConstUnlockLevel.SHOP_UNLOCK_ADVENTURE_LEVEL,
	GIM_LawnMover.E_LawnMoverType.RoofCleaner: ConstUnlockLevel.ROOF_CLEANER_SHOP_ADVENTURE_LEVEL,
}

## 该清洁车在商店上架所需的冒险模式关卡序号,不商店出售的类型返回 0
static func get_cleaner_shop_level(mover_type: GIM_LawnMover.E_LawnMoverType) -> int:
	return int(CLEANER_SHOP_LEVEL.get(mover_type, 0))

## 该小推车类型是否需要在商店购买
static func is_need_buy_cleaner(mover_type: GIM_LawnMover.E_LawnMoverType) -> bool:
	return CLEANER_PRICE.has(mover_type)

## 货架每一行摆几格商品(原版货架一行 4 格)
const SHOP_ROW_SLOT_NUM := 4

## 货架一页摆几格商品:一页 SHOP_PAGE_SLOT_NUM 格,分两行摆(每行 SHOP_ROW_SLOT_NUM 格)
const SHOP_PAGE_SLOT_NUM := SHOP_ROW_SLOT_NUM * 2

## 货架每一页上架所需的冒险模式关卡序号(下标 = StoreManager 的页序)
## 商店一开始只有第一页,随进度往后加页:
##   3-4(24 商店解锁): 第一页 —— 道具一行 + 第一批紫卡一行
##   5-1(41): 第二页 —— 第二批紫卡一行 + 模仿者一行
##   5-5(45 花园解锁): 第三页(花园工具)与第四页(禅境花园、蜗牛、智慧树、树肥料、巧克力)
const PAGE_SHOP_LEVEL: Array[int] = [
	ConstUnlockLevel.SHOP_UNLOCK_ADVENTURE_LEVEL,
	ConstUnlockLevel.SHOP_EXPAND_SECOND_ADVENTURE_LEVEL,
	ConstUnlockLevel.GARDEN_UNLOCK_ADVENTURE_LEVEL,
	ConstUnlockLevel.GARDEN_UNLOCK_ADVENTURE_LEVEL,
]

## 第 page_index 页上架所需的冒险模式关卡序号;页数越界时返回一个不可达的关卡序号(= 永不上架)
static func get_page_shop_level(page_index: int) -> int:
	if page_index < 0 or page_index >= PAGE_SHOP_LEVEL.size():
		return ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL * 100
	return PAGE_SHOP_LEVEL[page_index]

## 该小推车类型在商店的售价,不需要购买或未知类型返回 0
static func get_cleaner_price(mover_type: GIM_LawnMover.E_LawnMoverType) -> int:
	return int(CLEANER_PRICE.get(mover_type, 0))

## 钉耙(Garden Rake)售价
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Garden_Rake)
## 口径: 原版一代 PC, $200 买一次,持续三关(lasts for three levels),用完可以再买
const RAKE_PRICE := 200

## 买一次钉耙获得的可用关数(原版: 买一次管三关,没踩到也照样算用掉)
const RAKE_USE_NUM_PER_BUY := 3

## 钉耙命中僵尸时的穿透伤害
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Garden_Rake)
## 口径: 原版一代 PC 为 1800,除巨人 / 红眼巨人 / 高坚果僵尸外当场击杀;
## 与倭瓜同级(Zombie000Base.be_squash 的默认伤害也是 1800)
const RAKE_ATTACK_VALUE := 1800

## 坚果包扎术(Wall-nut First Aid)售价
## 买断后永久生效: 关卡里手持坚果类卡片,直接往"已经掉手 / 裂开"的同种坚果上补种,
## 不用先铲掉旧的(原版: plant new seeds over the old damaged ones and fully restore their health),
## 补种照样花一张卡的钱与冷却(见 HandComponentCharacter.click_cell)
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Wall-nut_First_Aid)
## 口径: 原版一代 PC, $2000,通关冒险模式后上架(与模仿者同一页)
const WALL_NUT_FIRST_AID_PRICE := 2000

## 坚果包扎术能修的植物(原版: 坚果 / 高坚果 / 南瓜头)
## 数据来源: 同上(Wall-nut First Aid 的 Strategies 段: Wall-nuts, Tall-nuts, Pumpkins)
## 口径: 原版一代;大蒜与地刺王不在此列 —— 大蒜是防御植物但不能补种,
## 地刺王虽然也会分段掉外观却不是防御植物,同样不能补种(见该页 Trivia)
const WALL_NUT_FIRST_AID_PLANT_TYPES: Array[int] = [
	CharacterRegistry.PlantType.P004WallNut,
	CharacterRegistry.PlantType.P024TallNut,
	CharacterRegistry.PlantType.P031Pumpkin,
]
#endregion


## 该植物是否能用坚果包扎术补种修复(见 WALL_NUT_FIRST_AID_PLANT_TYPES)
static func is_first_aid_plant(plant_type: CharacterRegistry.PlantType) -> bool:
	return WALL_NUT_FIRST_AID_PLANT_TYPES.has(plant_type)

## 再买一次卡槽扩充的价格(已购买 upgrade_num 次),已满级或价目缺失返回 -1
static func get_card_slot_upgrade_price(upgrade_num: int) -> int:
	if upgrade_num < 0 or upgrade_num >= CARD_SLOT_UPGRADE_PRICES.size():
		return -1
	return CARD_SLOT_UPGRADE_PRICES[upgrade_num]
