extends RefCounted
class_name ConstAdventureReward
## 冒险模式每关「首次通关掉落」的奖励表（原版：通关后疯狂戴夫给的礼物盒 / 铲子 / 车钥匙 / 玉米卷）
## 与选关界面「本关看点」一一对应：**第 N 关的奖励 = 第 N+1 关按钮上的图标**
##   · 植物奖励直接查 ConstPlantUnlock.ADVENTURE_LEVEL_UNLOCK_PLANT（新植物只改那张表即可）
##   · 道具奖励在下面的 LEVEL_ITEM_REWARD 里显式登记（贴图 + 提示文本）
## 关卡序号口径与 ConstUnlockLevel 一致：1-1 = 1 …… 5-10 = 50（(区域-1)*10 + 小关号）
## 数据来源: PVZ Wiki(https://pvz.huijiwiki.com/wiki/冒险模式)
## 改这张表 / 改解锁表后必须同步 adventure_choose_level.tscn 的「本关看点」图标，
## 否则选关预览会和实际掉落脱节

## 奖励字典的键
const KEY_TYPE := "Type"
const KEY_PLANT_TYPE := "PlantType"
const KEY_TIP := "Tip"
const KEY_ICON := "Icon"

## 奖励类型
enum E_RewardType {
	Plant,	## 新植物：贴图用默认礼物盒，提示文本里带植物名
	Item,	## 道具：用 LEVEL_ITEM_REWARD 里的贴图与提示
}

## 道具类奖励：关卡序号 -> {Tip, Icon}
## 与植物奖励互斥（同一关不会既有道具又有新植物），两类都在时以道具为准
## 已经在关卡资源里配了 drop_unlock_on_level_complete 的关卡（3-4 车钥匙 / 4-4 玉米卷）
## 继续以关卡资源为准，不重复登记到这里（同一件事只在一处写）
const LEVEL_ITEM_REWARD: Dictionary = {
	4: {	## 1-4 通关：疯狂戴夫把铲子交给玩家（ConstUnlockLevel.SHOVEL_UNLOCK_ADVENTURE_LEVEL）
		KEY_TIP: "你得到一把铁铲！用它可以铲掉种下的植物。",
		KEY_ICON: preload("res://assets/image/ui/ui_card/Shovel.png"),
	},
	14: {	## 2-4 通关：疯狂戴夫掉落大图鉴（原版 lawn_strings [FOUND_SUBURBAN_ALMANAC]）
		KEY_TIP: "你发现了大图鉴！记载所有你遇到的植物和僵尸。",
		KEY_ICON: preload("res://assets/image/main_game_item/Almanac.png"),
	},
	44: {	## 5-4 通关：疯狂戴夫把禅境花园的洒水壶交给玩家（原版 [FOUND_WATERING_CAN]），
		## 下一步 5-5 通关就拿到花园本身（ConstUnlockLevel.GARDEN_UNLOCK_ADVENTURE_LEVEL）
		KEY_TIP: "你发现了个洒水壶！用它给花园里的植物浇水。",
		KEY_ICON: preload("res://assets/image/garden/WateringCan.png"),
	},
}

## 植物奖励的提示文本模板（%s = 植物中文名，原版 lawn_strings [NEW_PLANT]）
const TIP_NEW_PLANT := "你得到一株新植物：%s！"


## 冒险关卡序号 -> 本关首次通关掉落的奖励，本关没有奖励时返回空字典
## 返回: {Type: E_RewardType, Tip: String, Icon: Texture2D(仅道具), PlantType: int(仅植物)}
static func get_reward(adventure_level: int) -> Dictionary:
	if adventure_level <= 0:
		return {}
	var item_reward: Dictionary = LEVEL_ITEM_REWARD.get(adventure_level, {})
	if not item_reward.is_empty():
		return {
			KEY_TYPE: E_RewardType.Item,
			KEY_TIP: String(item_reward.get(KEY_TIP, "")),
			KEY_ICON: item_reward.get(KEY_ICON, null),
		}
	var plants: Array = ConstPlantUnlock.get_unlock_plant_on_adventure_level(adventure_level)
	if plants.is_empty():
		return {}
	return {
		KEY_TYPE: E_RewardType.Plant,
		KEY_PLANT_TYPE: int(plants[0]),
		KEY_TIP: TIP_NEW_PLANT,
	}

