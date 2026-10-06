extends Node
class_name GlobalGameState

const DEFAULT_COIN_VALUE: int = 0
const DEFAULT_CURR_NUM_NEW_GARDEN_PLANT: int = 3
const DEFAULT_CARD_SLOT_UPGRADE_NUM: int = 0
const DEFAULT_IS_FIRST_COIN_ADVICE_SHOWN: bool = false
const DEFAULT_IS_POOL_CLEANER_BOUGHT: bool = false
const DEFAULT_IS_ROOF_CLEANER_BOUGHT: bool = false
## 坚果包扎术是否已购买(商店 $2000 买断,永久生效,见 ConstShop.WALL_NUT_FIRST_AID_PRICE)
const DEFAULT_IS_WALL_NUT_FIRST_AID_BOUGHT: bool = false
## 钉耙剩余可用关数:0 = 手上没有钉耙(买一次 3 关,见 ConstShop.RAKE_USE_NUM_PER_BUY)
const DEFAULT_RAKE_USE_NUM: int = 0
## 花园背景页数:num_bg_page_<背景枚举值>
## 阳光房(GreenHouse)默认就有 1 页;蘑菇园与水族馆默认 0 页 = 尚未在商店购买,
## 买了才置为 1 页(见 buy_garden_bg()),与"页数"解耦后才是原版的"拥有 / 未拥有"语义
## 原版: 蘑菇园与水族馆各 $30000,买一次即 Sold Out(见 ConstShop.GARDEN_BG_PRICE)
## garden_data 中"已买断的花园工具(GardenManager.E_GardenTool 的 int 数组)"的键
const BOUGHT_GARDEN_TOOLS_KEY := "bought_garden_tools"
## garden_data 中"消耗型花园工具的持有数量({工具枚举值字符串: 数量})"的键
const GARDEN_TOOL_NUM_KEY := "garden_tool_num"
const DEFAULT_GARDEN_DATA: Dictionary = {
	"num_bg_page_0": 1,
	"num_bg_page_1": 0,
	"num_bg_page_2": 0,
	## 智慧树页:买下智慧树时置 1(见 buy_tree_of_wisdom);不放植物格子,只放一棵树
	"num_bg_page_3": 0,
	BOUGHT_GARDEN_TOOLS_KEY: [],
	GARDEN_TOOL_NUM_KEY: {},
}
const DEFAULT_CURR_ALL_LEVEL_STATE_DATA: Dictionary = {}
## 冒险模式选关一页几关(5 页 × 10 关 = 50 关),存档名里的页码就是这么算出来的
const ADVENTURE_LEVEL_PER_PAGE := 10
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
## 商店购买的卡槽扩充次数(存档的出战卡槽数 = 基准 + 该值,上限 ConstShop.MAX_CARD_SLOT_NUM)
var card_slot_upgrade_num: int = DEFAULT_CARD_SLOT_UPGRADE_NUM
## 商店购买的水路小推车(泳池清洁车)是否已购买(原版 $1000,买一次永久生效)
var is_pool_cleaner_bought: bool = DEFAULT_IS_POOL_CLEANER_BOUGHT
## 商店购买的屋顶小推车(屋顶清洁车)是否已购买(原版 $3000,买一次永久生效)
var is_roof_cleaner_bought: bool = DEFAULT_IS_ROOF_CLEANER_BOUGHT
## 钉耙剩余可用关数(商店 $200 买一次管 3 关,每放置一关消耗 1 次,用完才能再买)
var rake_use_num: int = DEFAULT_RAKE_USE_NUM
## 坚果包扎术是否已购买(商店 $2000 买断,永久生效:关卡里可往受损坚果上补种,见 PlantCell.get_first_aid_plant)
var is_wall_nut_first_aid_bought: bool = DEFAULT_IS_WALL_NUT_FIRST_AID_BOUGHT
## 「第一次掉落钱」的提示是否已经弹过(全局只弹一次,弹完即落存档,见 MainGameManager._on_first_coin_drop)
var is_first_coin_advice_shown: bool = DEFAULT_IS_FIRST_COIN_ADVICE_SHOWN
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

## 冒险模式关卡序号 -> 关卡存档名(上面那个函数的逆运算)
## 存档名格式 "<模式>_<页码>_<4 位按钮序号>"(见 ResourceLevelData.set_choose_level):
## 冒险模式 10 关一页,按钮序号与关卡序号同号,所以能凭关卡序号反推出存档名。
## 只有"手里没有关卡资源、却要写某一关的通关状态"的场合才用(调试快捷键 Ctrl+D 然后按 1);
## 正常通关流程一律以关卡自己的 save_game_name 为准,不要在这里拼。
func get_adventure_save_game_name(adventure_level:int) -> String:
	if adventure_level <= 0:
		return ""
	# 用浮点除法再向下取整:页码本就是向下取整的结果,这样写可避免 GDScript 的 integer_division 警告
	var level_page := floori(float(adventure_level - 1) / float(ADVENTURE_LEVEL_PER_PAGE))
	return "%d_%d_%04d" % [MainSceneRegistry.MainScenes.ChooseLevelAdventure, level_page, adventure_level]

## 某一关是否已经通关过：**按关卡存档名查**
## level_save_key: 关卡存档名（ResourceLevelData.save_game_name，V2 关卡就是它在 _init() 里写死的 save_key）
## 从来没有打过 / 打过但没通的关卡返回 false
## 谁在用它：MainGameManager.is_curr_level_success()（查本关）、
## LevelScriptBase.is_level_success()（关卡脚本查别的一关）
func is_level_success(level_save_key:String) -> bool:
	if level_save_key.is_empty():
		return false
	var curr_level_state_data: Dictionary = curr_all_level_state_data.get(level_save_key, {})
	return curr_level_state_data.get("IsSuccess", false)

## 调试用：把冒险模式 1-1 ~ 5-10 全部写成已通关（快捷键 Ctrl+D 然后按 1）
## 与「本关通关」同一套写法，只是把「本关」换成「每一关」：写通关存档 + 按关卡序号解锁沿途植物。
## 放在这里而不是存档子管理器，是因为它只碰全局关卡数据、跟当前这一局无关，
## 因此在选关界面 / 主菜单也能按（不需要有 MainGameManager 在场）。
## 跟「真打完一局」绑定的副作用（钉耙消耗、多轮存档重置）这里不做 —— 快捷键并没有真打。
## 返回本次写成通关的关卡数量
func success_all_adventure_level() -> int:
	var success_num := 0
	for adventure_level in range(1, ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL + 1):
		var save_game_name := get_adventure_save_game_name(adventure_level)
		if save_game_name == "":
			continue
		var curr_level_state_data: Dictionary = curr_all_level_state_data.get(save_game_name, {})
		curr_level_state_data["IsSuccess"] = true
		curr_all_level_state_data[save_game_name] = curr_level_state_data
		var new_unlock: Array[CharacterRegistry.PlantType] = unlock_plant_on_adventure_level(adventure_level)
		for plant_type:CharacterRegistry.PlantType in new_unlock:
			Log.debug(str("通关解锁新植物: ") + str(Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)))
		success_num += 1
	Global.save_service.save_now()
	return success_num


## 紫卡植物与模仿者是否已开放购买(需通关对应关卡后在商店购买)
func is_purple_card_can_buy(plant_type:CharacterRegistry.PlantType) -> bool:
	return ConstPlantUnlock.is_purple_card_can_buy(plant_type, get_max_success_adventure_level())
## 该植物是否为商店商品(紫卡或模仿者)
func is_shop_plant(plant_type:CharacterRegistry.PlantType) -> bool:
	return ConstPlantUnlock.is_shop_plant(plant_type)
#endregion

#region 选关模式解锁进度
## 迷你游戏 / 解谜 / 生存模式是否已解锁(与冒险模式进度挂钩)
## 冒险模式与自定义关卡无限制,恒为 true
func is_mode_unlocked(game_mode: MainSceneRegistry.MainScenes) -> bool:
	return ConstUnlockLevel.is_mode_unlocked(game_mode, get_max_success_adventure_level())

## 该模式解锁所需的冒险模式关卡序号,无限制返回 -1(用于给玩家提示"通关 X-X 后解锁")
func get_mode_unlock_adventure_level(game_mode: MainSceneRegistry.MainScenes) -> int:
	return ConstUnlockLevel.get_mode_unlock_adventure_level(game_mode)

## 该模式的关卡是否已全部开放(首次通关冒险模式后不再逐步解锁)
func is_mode_all_level_open(game_mode: MainSceneRegistry.MainScenes) -> bool:
	return ConstUnlockLevel.is_mode_all_level_open(game_mode, get_max_success_adventure_level())
#endregion

#region 道具解锁进度
## 铲子是否已解锁(通关 1-4 后获得,在此之前卡槽不出现铲子)
func is_shovel_unlocked() -> bool:
	return ConstUnlockLevel.is_shovel_unlocked(get_max_success_adventure_level())

## 图鉴是否已解锁(通关 2-4 后戴夫掉落大图鉴,在此之前主菜单与暂停菜单的图鉴入口不可用)
func is_almanac_unlocked() -> bool:
	return ConstUnlockLevel.is_almanac_unlocked(get_max_success_adventure_level())

## 手套是否已解锁(通关 4-5 后获得,在此之前卡槽不出现手套)
## 总开关关闭时恒为 false,手套功能整体隐藏(见 ConstFeatureSwitch.GLOVE_ENABLED)
func is_glove_unlocked() -> bool:
	return ConstUnlockLevel.is_glove_unlocked(get_max_success_adventure_level())

## 花园是否已解锁(通关 5-5 后戴夫把禅境花园交给玩家,在此之前拿不到任何花园植物)
func is_garden_unlocked() -> bool:
	return ConstUnlockLevel.is_garden_unlocked(get_max_success_adventure_level())
#endregion

#region 小推车解锁进度
## 该类型的小推车是否已在商店购买(普通草坪小推车免费配发,恒为 true)
func is_lawn_mover_bought(mover_type: GIM_LawnMover.E_LawnMoverType) -> bool:
	if not ConstShop.is_need_buy_cleaner(mover_type):
		return true
	match mover_type:
		GIM_LawnMover.E_LawnMoverType.PoolCleaner:
			return is_pool_cleaner_bought
		GIM_LawnMover.E_LawnMoverType.RoofCleaner:
			return is_roof_cleaner_bought
	return true

## 购买一个清洁车,已购买或不需要购买时返回 false
func buy_lawn_mover(mover_type: GIM_LawnMover.E_LawnMoverType) -> bool:
	if not ConstShop.is_need_buy_cleaner(mover_type):
		return false
	if is_lawn_mover_bought(mover_type):
		return false
	match mover_type:
		GIM_LawnMover.E_LawnMoverType.PoolCleaner:
			is_pool_cleaner_bought = true
		GIM_LawnMover.E_LawnMoverType.RoofCleaner:
			is_roof_cleaner_bought = true
	return true
#endregion

#region 钉耙使用次数
## 手上是否还有钉耙(剩余关数 > 0,关卡开局才会真的放下去,见 GIM_Rake)
func is_rake_owned() -> bool:
	return rake_use_num > 0

## 钉耙剩余可用关数
func get_rake_use_num() -> int:
	return rake_use_num

## 买一次钉耙:手上还有钉耙时不能重复买,返回 false
func buy_rake() -> bool:
	if is_rake_owned():
		return false
	rake_use_num = ConstShop.RAKE_USE_NUM_PER_BUY
	return true

## 放置了一关的钉耙后消耗 1 次
## 原版: 就算本关一只僵尸都没踩到也算用掉(lasts for three levels)
func consume_rake_use() -> bool:
	if not is_rake_owned():
		return false
	rake_use_num -= 1
	return true
#endregion

#region 坚果包扎术
## 坚果包扎术是否已购买(商店 $2000 买断,买了就永久生效)
func is_wall_nut_first_aid_owned() -> bool:
	return is_wall_nut_first_aid_bought

## 购买坚果包扎术,已经买过返回 false
func buy_wall_nut_first_aid() -> bool:
	if is_wall_nut_first_aid_bought:
		return false
	is_wall_nut_first_aid_bought = true
	return true
#endregion


## 禅境花园的存档状态逻辑（背景页数 / 智慧树 / 花园工具库存）。
## 业务本体在 global_garden_state.gd，这里持有实例并转发，避免本文件继续膨胀。
var garden_state: GlobalGardenState = GlobalGardenState.new(self)

#region 禅境花园转发（业务见 global_garden_state.gd）
## 该花园背景的页数在 garden_data 里的键
static func get_bg_page_num_key(bg_type: GardenManager.E_GardenBgType) -> String:
	return GlobalGardenState.get_bg_page_num_key(bg_type)

## 该花园背景当前的页数
func get_garden_bg_page_num(bg_type: GardenManager.E_GardenBgType) -> int:
	return garden_state.get_garden_bg_page_num(bg_type)

## 该花园背景是否已拥有（页数 >= 1）
func is_garden_bg_owned(bg_type: GardenManager.E_GardenBgType) -> bool:
	return garden_state.is_garden_bg_owned(bg_type)

## 已拥有的花园背景（按枚举顺序）
func get_owned_garden_bg_types() -> Array[GardenManager.E_GardenBgType]:
	return garden_state.get_owned_garden_bg_types()

## 购买（解锁）一个花园背景
func buy_garden_bg(bg_type: GardenManager.E_GardenBgType) -> bool:
	return garden_state.buy_garden_bg(bg_type)

## 智慧树是否已在商店买断
func is_tree_of_wisdom_bought() -> bool:
	return garden_state.is_tree_of_wisdom_bought()

## 买下智慧树
func buy_tree_of_wisdom() -> bool:
	return garden_state.buy_tree_of_wisdom()

## 智慧树现在多少英尺高
func get_tree_of_wisdom_height() -> int:
	return garden_state.get_tree_of_wisdom_height()

## 给智慧树长高，返回长完后的高度
func add_tree_of_wisdom_height(add_feet: int = ConstTreeOfWisdom.TREE_FOOD_GROW_FEET) -> int:
	return garden_state.add_tree_of_wisdom_height(add_feet)

## 该工具是不是消耗型
static func is_consumable_garden_tool(tool_type: GardenManager.E_GardenTool) -> bool:
	return GlobalGardenState.is_consumable_garden_tool(tool_type)

## 该买断型工具是否已购买
func is_garden_tool_bought(tool_type: GardenManager.E_GardenTool) -> bool:
	return garden_state.is_garden_tool_bought(tool_type)

## 买断一个花园工具，已拥有时返回 false
func buy_garden_tool(tool_type: GardenManager.E_GardenTool) -> bool:
	return garden_state.buy_garden_tool(tool_type)

## 消耗型工具当前的持有数量
func get_garden_tool_num(tool_type: GardenManager.E_GardenTool) -> int:
	return garden_state.get_garden_tool_num(tool_type)

## 给消耗型工具加库存，已达上限时返回 false
func add_garden_tool_num(tool_type: GardenManager.E_GardenTool, add_num: int) -> bool:
	return garden_state.add_garden_tool_num(tool_type, add_num)

## 用掉一个消耗型工具，没有库存时返回 false
func use_garden_tool(tool_type: GardenManager.E_GardenTool) -> bool:
	return garden_state.use_garden_tool(tool_type)

## 把 garden_data 里从 JSON 读回来的数字统一转回 int（读档后调一次）
func normalize_garden_data_numbers() -> void:
	garden_state.normalize_garden_data_numbers()

## 该花园工具现在能不能用：买断型 = 已买，消耗型 = 还有库存
func is_garden_tool_available(tool_type: GardenManager.E_GardenTool) -> bool:
	return garden_state.is_garden_tool_available(tool_type)

## 禅境花园是否还有空位
func has_empty_garden_cell() -> bool:
	return garden_state.has_empty_garden_cell()
#endregion

#region 金钱与商店解锁进度
## 金钱是否已解锁(冒险模式 2-1 起僵尸开始掉落金币,在此之前不掉钱)
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

## 已购买的卡槽扩充次数
func get_card_slot_upgrade_num() -> int:
	return card_slot_upgrade_num

## 存档当前的出战卡槽数(原版初始 ConstShop.BASE_CARD_SLOT_NUM 格,
## 商店买一次卡槽扩充 +1,上限 ConstShop.MAX_CARD_SLOT_NUM)
## 关卡资源没写 max_choosed_card_num(0 = 不覆盖)时,出战卡槽数一律取这个值
## 见 ResourceLevelData.get_max_choosed_card_num()
func get_card_slot_num() -> int:
	return mini(ConstShop.BASE_CARD_SLOT_NUM + card_slot_upgrade_num, ConstShop.MAX_CARD_SLOT_NUM)

## 卡槽扩充是否已达上限(不能再购买)
func is_card_slot_upgrade_max() -> bool:
	return card_slot_upgrade_num >= ConstShop.get_max_card_slot_upgrade_num()

## 购买一次卡槽扩充,已达上限时返回 false
func add_card_slot_upgrade() -> bool:
	if is_card_slot_upgrade_max():
		return false
	card_slot_upgrade_num += 1
	return true
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

## 已解锁的僵王；博士默认可选，与已解锁的普通僵尸共同组成僵尸候选页
var curr_zombie_boss :Array[CharacterRegistry.ZombieBossType] = [
	CharacterRegistry.ZombieBossType.ZB001Doctor,
]

## 僵王是否已解锁
func is_zombie_boss_unlocked(boss_type: CharacterRegistry.ZombieBossType) -> bool:
	return curr_zombie_boss.has(boss_type)
