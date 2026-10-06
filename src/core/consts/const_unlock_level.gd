extends RefCounted
class_name ConstUnlockLevel
## 冒险模式进度解锁常量(植物以外的解锁:模式、花园、铲子、金钱、商店、商店扩展)
## 冒险模式 50 关的关卡序号: 1-1 = 1 …… 5-10 = 50(即 (区域-1)*10 + 小关号)
## 数据来源: PVZ Wiki(https://pvz.huijiwiki.com/wiki/冒险模式 、
## https://strategywiki.org/wiki/Plants_vs._Zombies/Puzzle_Mode 、
## https://plantsvszombies.fandom.com/wiki/Money 、
## https://plantsvszombies.fandom.com/wiki/Crazy_Dave%27s_Twiddydinkies)

#region 模式解锁
## 迷你游戏解锁: 冒险模式 3-2 通关后掉落礼物盒解锁迷你游戏,首批开放 3 关
const MINI_GAME_UNLOCK_ADVENTURE_LEVEL := 22

## 解谜模式解锁: 冒险模式 4-6(第一次出矿工僵尸的关卡)通关后掉落礼物盒解锁解谜模式,首批开放 3 关
const PUZZLE_UNLOCK_ADVENTURE_LEVEL := 36

## 生存模式解锁: 通关冒险模式 5-10(僵王博士)后解锁
const SURVIVAL_UNLOCK_ADVENTURE_LEVEL := 50

## 冒险模式最后一关序号(5-10),通关即"首次完成冒险模式"
const ADVENTURE_FINAL_ADVENTURE_LEVEL := 50

## 各选关模式解锁所需的冒险模式关卡序号
## 不在表里的模式(冒险模式本身、自定义关卡)不做限制,永远开放
const MODE_UNLOCK_ADVENTURE_LEVEL: Dictionary[MainSceneRegistry.MainScenes, int] = {
	MainSceneRegistry.MainScenes.ChooseLevelMiniGame: MINI_GAME_UNLOCK_ADVENTURE_LEVEL,
	MainSceneRegistry.MainScenes.ChooseLevelPuzzle: PUZZLE_UNLOCK_ADVENTURE_LEVEL,
	MainSceneRegistry.MainScenes.ChooseLevelSurvival: SURVIVAL_UNLOCK_ADVENTURE_LEVEL,
}
#endregion

## 铲子解锁: 通关冒险模式 1-4 后疯狂戴夫把铲子交给玩家,1-1 ~ 1-4 期间没有铲子
const SHOVEL_UNLOCK_ADVENTURE_LEVEL := 4

## 图鉴解锁: 通关冒险模式 2-4(关卡序号 14)后戴夫掉下大图鉴,拾取后开放图鉴。
## 与铲子 / 手套同一套口径(由通关记录推导,不落库存档),判定入口 is_almanac_unlocked()。
## 原版口径: 通关 2-4 后戴夫掉落 Suburban Almanac,在此之前主菜单与暂停菜单的图鉴入口不可用
const ALMANAC_UNLOCK_ADVENTURE_LEVEL := 14

## 手套解锁: 通关冒险模式 4-5(关卡序号 35)后疯狂戴夫把手套交给玩家,4-6 起卡槽才出现手套。
## 与铲子同一套口径(由通关记录推导,不落库存档),选点理由:
##   4-6 是矿工僵尸(Z018Digger)首次登场的关卡,矿工从后排钻出,玩家第一次需要挪动已种下的植物,
##   手套的战术价值在该关才成立,赠送即教学;更早给会削弱"种下即定"的布局压力、且让铲子显得多余。
## 原版口径: 手套是禅境花园工具,随花园(4-5 之后)出现,时间点与之对齐
const GLOVE_UNLOCK_ADVENTURE_LEVEL := 35

## 花园解锁: 通关冒险模式 5-5(关卡序号 45)后疯狂戴夫把禅境花园交给玩家。
## 与铲子 / 手套同一套口径(由通关记录推导,不落库存档),判定入口 is_garden_unlocked()。
## 解锁前: 僵尸不掉落花园植物礼包(见 DropItemComponent.drop_garden_plant)、商店不卖花园植物礼包,
## 即"没有花园就没有花园植物";解锁后两者同时放开。
const GARDEN_UNLOCK_ADVENTURE_LEVEL := 45


## 金钱解锁: 冒险模式 2-1(关卡序号 11)开始,僵尸就会掉落金币,在此之前不产生任何金币
## 判定口径见 is_money_unlocked(): 进到 2-1 就掉钱(即通关 1-10 后),不用等通关 2-1
const MONEY_UNLOCK_ADVENTURE_LEVEL := 11

## 商店解锁: 通关冒险模式 3-4 获得车钥匙后,开放疯狂戴夫的商店
const SHOP_UNLOCK_ADVENTURE_LEVEL := 24

## 夜晚戴夫推销:商店解锁之前,戴夫在冒险模式关卡开场推销卡槽扩充(见 DaveSellManager)
## 本仓库的推销节奏:
##   2-2(关卡序号 12)开场固定出现一次"攒够 $N 我就卖给你"的预告;
##   2-2 之后只要玩家攒够了当前档位的价钱,开场立即推销,直到商店解锁(通关 3-4)
const DAVE_SELL_ADVENTURE_LEVEL := 12

## 商店第二批扩展所需的冒险模式关卡序号(5-1,关卡序号 41)
## 这一关起上架吸金磁、地刺王,商店也往后翻出一页新货架
const SHOP_EXPAND_SECOND_ADVENTURE_LEVEL := 41

## 商店扩展(分批上架新商品)所需的冒险模式关卡序号
## 4-4(34): 忧郁蘑菇、香蒲
## 5-1(41): 吸金磁、地刺王、屋顶清洁车(进入屋顶后才有用,原版也是进屋顶才上架)
## 5-10(50): 通关冒险模式,上架冰西瓜、玉米加农炮、模仿者
const SHOP_EXPAND_ADVENTURE_LEVELS := [34, SHOP_EXPAND_SECOND_ADVENTURE_LEVEL, 50]

## 屋顶小推车(屋顶清洁车)在商店上架所需的冒险模式关卡序号(5-1)
## 水路小推车随商店解锁(3-4)一起上架;屋顶清洁车要等到玩家进入屋顶才有用,原版也是 5-1 才出现
const ROOF_CLEANER_SHOP_ADVENTURE_LEVEL := SHOP_EXPAND_SECOND_ADVENTURE_LEVEL


## 铲子是否已解锁(已通关的最大冒险关卡序号 >= 1-4)
static func is_shovel_unlocked(max_success_adventure_level: int) -> bool:
	return max_success_adventure_level >= SHOVEL_UNLOCK_ADVENTURE_LEVEL


## 图鉴是否已解锁(已通关的最大冒险关卡序号 >= 2-4,见 ALMANAC_UNLOCK_ADVENTURE_LEVEL)
static func is_almanac_unlocked(max_success_adventure_level: int) -> bool:
	return max_success_adventure_level >= ALMANAC_UNLOCK_ADVENTURE_LEVEL


## 手套是否已解锁(已通关的最大冒险关卡序号 >= 4-5,见 GLOVE_UNLOCK_ADVENTURE_LEVEL)
## 总开关关闭时恒为 false(见 ConstFeatureSwitch.GLOVE_ENABLED),整个手套功能隐藏
static func is_glove_unlocked(max_success_adventure_level: int) -> bool:
	if not ConstFeatureSwitch.GLOVE_ENABLED:
		return false
	return max_success_adventure_level >= GLOVE_UNLOCK_ADVENTURE_LEVEL


## 花园是否已解锁(已通关的最大冒险关卡序号 >= 5-5,见 GARDEN_UNLOCK_ADVENTURE_LEVEL)
static func is_garden_unlocked(max_success_adventure_level: int) -> bool:
	return max_success_adventure_level >= GARDEN_UNLOCK_ADVENTURE_LEVEL


## 当前正在打的冒险模式关卡序号 = 已通关的最大序号 + 1(新档还没有通关记录时为 1-1 = 1)
static func get_current_adventure_level(max_success_adventure_level: int) -> int:
	return maxi(1, max_success_adventure_level + 1)


## 金钱是否已解锁(当前正在打的冒险关卡序号 >= 2-1,即通关 1-10 后进 2-1 就开始掉钱)
static func is_money_unlocked(max_success_adventure_level: int) -> bool:
	return get_current_adventure_level(max_success_adventure_level) >= MONEY_UNLOCK_ADVENTURE_LEVEL


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


#region 模式解锁判定
## 该选关模式解锁所需的冒险模式关卡序号,无限制(冒险模式本身、自定义关卡)返回 -1
static func get_mode_unlock_adventure_level(game_mode: MainSceneRegistry.MainScenes) -> int:
	return int(MODE_UNLOCK_ADVENTURE_LEVEL.get(game_mode, -1))


## 该选关模式是否已解锁(已通关的最大冒险关卡序号 >= 解锁所需关卡)
static func is_mode_unlocked(game_mode: MainSceneRegistry.MainScenes, max_success_adventure_level: int) -> bool:
	var need_level := get_mode_unlock_adventure_level(game_mode)
	if need_level < 0:
		return true
	return max_success_adventure_level >= need_level


## 该模式的关卡是否已全部开放:
## 首次完成冒险模式(通关 5-10)后,迷你游戏与解谜模式的剩余关卡、生存模式全部开放,
## 不再按"通关一关解锁下一关"逐步解锁
static func is_mode_all_level_open(game_mode: MainSceneRegistry.MainScenes, max_success_adventure_level: int) -> bool:
	if not MODE_UNLOCK_ADVENTURE_LEVEL.has(game_mode):
		return false
	return max_success_adventure_level >= ADVENTURE_FINAL_ADVENTURE_LEVEL
#endregion


## 冒险模式关卡序号 -> 关卡名(如 24 -> "3-4"),序号非法返回空字符串
static func get_adventure_level_name(adventure_level: int) -> String:
	if adventure_level <= 0:
		return ""
	return "%d-%d" % [int((adventure_level - 1) / 10.0) + 1, (adventure_level - 1) % 10 + 1]
