extends RefCounted
class_name ConstUnlockLevel
## 冒险模式进度解锁常量(植物以外的解锁:金钱、商店、商店扩展)
## 冒险模式 50 关的关卡序号: 1-1 = 1 …… 5-10 = 50(即 (区域-1)*10 + 小关号)
## 数据来源: PVZ Wiki(https://plantsvszombies.fandom.com/wiki/Money 、
## https://plantsvszombies.fandom.com/wiki/Crazy_Dave%27s_Twiddydinkies)

## 金钱解锁: 冒险模式 2-1 期间,第一个银币由僵尸掉落,在此之前不会产生任何金币
const MONEY_UNLOCK_ADVENTURE_LEVEL := 11

## 商店解锁: 通关冒险模式 3-4 获得车钥匙后,开放疯狂戴夫的商店
const SHOP_UNLOCK_ADVENTURE_LEVEL := 24

## 商店扩展(分批上架新商品)所需的冒险模式关卡序号
## 4-4(34): 忧郁蘑菇、香蒲
## 5-1(41): 吸金磁、地刺王
## 5-10(50): 通关冒险模式,上架冰西瓜、玉米加农炮、模仿者
const SHOP_EXPAND_ADVENTURE_LEVELS := [34, 41, 50]


## 金钱是否已解锁(已通关的最大冒险关卡序号 >= 2-1)
static func is_money_unlocked(max_success_adventure_level: int) -> bool:
	return max_success_adventure_level >= MONEY_UNLOCK_ADVENTURE_LEVEL


## 商店是否已解锁(已通关的最大冒险关卡序号 >= 3-4)
static func is_shop_unlocked(max_success_adventure_level: int) -> bool:
	return max_success_adventure_level >= SHOP_UNLOCK_ADVENTURE_LEVEL


## 当前已进行的商店扩展次数(0 = 刚解锁商店, 1/2/3 = 每次扩展)
static func get_shop_expand_stage(max_success_adventure_level: int) -> int:
	var stage := 0
	for level in SHOP_EXPAND_ADVENTURE_LEVELS:
		if max_success_adventure_level >= int(level):
			stage += 1
	return stage


## 下一次商店扩展所需的冒险关卡序号,已全部扩展完返回 -1
static func get_next_shop_expand_level(max_success_adventure_level: int) -> int:
	for level in SHOP_EXPAND_ADVENTURE_LEVELS:
		if max_success_adventure_level < int(level):
			return int(level)
	return -1


## 冒险模式关卡序号 -> 关卡名(如 24 -> "3-4"),序号非法返回空字符串
static func get_adventure_level_name(adventure_level: int) -> String:
	if adventure_level <= 0:
		return ""
	return "%d-%d" % [(adventure_level - 1) / 10 + 1, (adventure_level - 1) % 10 + 1]
