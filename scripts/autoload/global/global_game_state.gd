extends Node
class_name GlobalGameState

const DEFAULT_COIN_VALUE: int = 0
const DEFAULT_CURR_NUM_NEW_GARDEN_PLANT: int = 3
const DEFAULT_GARDEN_DATA: Dictionary = {
	"num_bg_page_0": 1,
	"num_bg_page_1": 1,
	"num_bg_page_2": 1,
}
const DEFAULT_CURR_ALL_LEVEL_STATE_DATA: Dictionary = {}
"""
## 一个关卡的游戏状态的例子
var curr_one_level_state_data:Dictionary = {
	"IsSuccess":false,
	"IsHaveMultiRoundSaveGameData":false,
	"CurrGameRound":1
}
"""
signal coin_value_changed(new_value: int)

var coin_value: int = DEFAULT_COIN_VALUE:
	set(value):
		coin_value = value
		coin_value_changed.emit(coin_value)

var curr_num_new_garden_plant: int = DEFAULT_CURR_NUM_NEW_GARDEN_PLANT
var garden_data: Dictionary = DEFAULT_GARDEN_DATA.duplicate(true)
var curr_all_level_state_data: Dictionary = DEFAULT_CURR_ALL_LEVEL_STATE_DATA.duplicate(true)
var selected_cards: Array = []

## 已解锁的植物:
## 初始只有豌豆射手,白卡通过冒险模式关卡解锁(见 ConstPlantUnlock),紫卡与模仿者在商店购买后加入
var curr_plant :Array[CharacterRegistry.PlantType]= ConstPlantUnlock.INIT_PLANT_TYPES.duplicate()

#region 植物解锁进度
## 植物是否已解锁
func is_plant_unlocked(plant_type:CharacterRegistry.PlantType) -> bool:
	return curr_plant.has(plant_type)

## 解锁一个植物,返回是否为本次新解锁
func unlock_plant(plant_type:CharacterRegistry.PlantType) -> bool:
	if plant_type == CharacterRegistry.PlantType.Null:
		return false
	if curr_plant.has(plant_type):
		return false
	curr_plant.append(plant_type)
	return true

## 批量解锁植物,返回本次新解锁的植物
func unlock_plants(plant_types:Array) -> Array[CharacterRegistry.PlantType]:
	var new_unlock:Array[CharacterRegistry.PlantType] = []
	for plant_type in plant_types:
		if unlock_plant(int(plant_type) as CharacterRegistry.PlantType):
			new_unlock.append(int(plant_type) as CharacterRegistry.PlantType)
	return new_unlock

## 通关冒险模式某关后解锁该关对应的植物,返回本次新解锁的植物
## adventure_level: 冒险模式关卡序号(1-1 = 1 …… 5-10 = 50)
func unlock_plant_on_adventure_level(adventure_level:int) -> Array[CharacterRegistry.PlantType]:
	return unlock_plants(ConstPlantUnlock.get_unlock_plant_on_adventure_level(adventure_level))

## 已通关的最大冒险模式关卡序号,没有通关过冒险关卡时返回 0
func get_max_success_adventure_level() -> int:
	var max_level := 0
	for save_game_name in curr_all_level_state_data:
		var curr_level_state_data: Dictionary = curr_all_level_state_data[save_game_name]
		if not curr_level_state_data.get("IsSuccess", false):
			continue
		var adventure_level: int = get_adventure_level_on_save_game_name(str(save_game_name))
		if adventure_level > max_level:
			max_level = adventure_level
	return max_level

## 从关卡存档名(game_mode_level_page_level_id)中取冒险模式关卡序号,非冒险模式返回 0
func get_adventure_level_on_save_game_name(save_game_name:String) -> int:
	var parts := save_game_name.split("_")
	if parts.size() < 3:
		return 0
	if int(parts[0]) != MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		return 0
	return int(parts[2])

## 紫卡植物与模仿者是否已开放购买(需通关对应关卡后在商店购买)
func is_purple_card_can_buy(plant_type:CharacterRegistry.PlantType) -> bool:
	return ConstPlantUnlock.is_purple_card_can_buy(plant_type, get_max_success_adventure_level())
## 该植物是否为商店商品(紫卡或模仿者)
func is_shop_plant(plant_type:CharacterRegistry.PlantType) -> bool:
	return ConstPlantUnlock.is_shop_plant(plant_type)
#endregion

#region 金钱与商店解锁进度
## 金钱是否已解锁(冒险模式 2-1 之前僵尸不掉落金币)
func is_money_unlocked() -> bool:
	return ConstUnlockLevel.is_money_unlocked(get_max_success_adventure_level())

## 商店是否已解锁(通关 3-4 获得车钥匙)
func is_shop_unlocked() -> bool:
	return ConstUnlockLevel.is_shop_unlocked(get_max_success_adventure_level())

## 当前已进行的商店扩展次数
func get_shop_expand_stage() -> int:
	return ConstUnlockLevel.get_shop_expand_stage(get_max_success_adventure_level())

## 下一次商店扩展所需的冒险关卡序号,已全部扩展完返回 -1
func get_next_shop_expand_level() -> int:
	return ConstUnlockLevel.get_next_shop_expand_level(get_max_success_adventure_level())
#endregion

var curr_zombie :Array[CharacterRegistry.ZombieType]= [
	CharacterRegistry.ZombieType.Z001Norm,
	CharacterRegistry.ZombieType.Z002Flag,
	CharacterRegistry.ZombieType.Z003Cone,
	CharacterRegistry.ZombieType.Z004PoleVaulter,
	CharacterRegistry.ZombieType.Z005Bucket,
	CharacterRegistry.ZombieType.Z006Paper,
	CharacterRegistry.ZombieType.Z007ScreenDoor,
	CharacterRegistry.ZombieType.Z008Football,
	CharacterRegistry.ZombieType.Z009Jackson,
	CharacterRegistry.ZombieType.Z010Dancer,
	CharacterRegistry.ZombieType.Z011Duckytube,
	CharacterRegistry.ZombieType.Z012Snorkle,
	CharacterRegistry.ZombieType.Z013Zamboni,
	CharacterRegistry.ZombieType.Z014Bobsled,
	CharacterRegistry.ZombieType.Z015Dolphinrider,
	CharacterRegistry.ZombieType.Z016Jackbox,
	CharacterRegistry.ZombieType.Z017Balloon,
	CharacterRegistry.ZombieType.Z018Digger,
	CharacterRegistry.ZombieType.Z019Pogo,
	CharacterRegistry.ZombieType.Z020Yeti,
	CharacterRegistry.ZombieType.Z021Bungi,
	CharacterRegistry.ZombieType.Z022Ladder,
	CharacterRegistry.ZombieType.Z023Catapult,
	CharacterRegistry.ZombieType.Z024Gargantuar,
	CharacterRegistry.ZombieType.Z025Imp,
	CharacterRegistry.ZombieType.Z1001BobsledSingle,
]
