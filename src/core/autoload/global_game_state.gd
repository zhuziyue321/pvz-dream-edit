extends Node
class_name GlobalGameState

const DEFAULT_COIN_VALUE: int = 0
## 首次进花园的植物由 GardenManager 发（原版戴夫送 2 株金盏花），默认不再预置随机幼苗
const DEFAULT_CURR_NUM_NEW_GARDEN_PLANT: int = 0
const DEFAULT_CARD_SLOT_UPGRADE_NUM: int = 0
const DEFAULT_IS_FIRST_COIN_ADVICE_SHOWN: bool = false
const DEFAULT_IS_POOL_CLEANER_BOUGHT: bool = false
const DEFAULT_IS_ROOF_CLEANER_BOUGHT: bool = false
## 坚果包扎术是否已购买(商店 $2000 买断,永久生效,见 ConstShop.WALL_NUT_FIRST_AID_PRICE)
const DEFAULT_IS_WALL_NUT_FIRST_AID_BOUGHT: bool = false
## 独轮车是否已购买(原版 $20 的摆设:买下什么都不发生,记下来只为了货架显示 Sold Out)
const DEFAULT_IS_WHEEL_BARROW_BOUGHT: bool = false
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
## 冒险模式周目:1 = 首周目。每通关一次 5-10 就 +1,没有上限(见 advance_adventure_round)
const DEFAULT_ADVENTURE_ROUND := 1
## 关卡记录里「这一关是第几周目通的」那个键
## 老存档 / 非冒险模式的记录没有它 —— 一律当周目 1,也就是「以前通的」
const LEVEL_STATE_DATA_ROUND_KEY := "Round"
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
## 待放置花园植物的**物种队列**（与 curr_num_new_garden_plant 一一对应）：
## 原版每一盆植物在入手那一刻就定好了 mSeedType（商店金盏花 / 关卡礼包各按自己的来源定种），
## 发芽期画的是通用幼苗，长大后才换成那个物种 —— 这里用队列把"入手时定种"落进存档。
## 老存档没有这个键时为空，放置时兜底随机（见 pop_new_garden_plant_species）
var curr_new_garden_plant_types: Array[StringName] = []


## 新增一株待放置的花园植物（原版 AddPottedPlant）
func add_new_garden_plant(species: StringName = PlantIds.NULL) -> void:
	curr_num_new_garden_plant += 1
	curr_new_garden_plant_types.append(species)


## 取出一株待放置植物的物种；队列空（老存档 / 手动改档）时随机一株
func pop_new_garden_plant_species() -> StringName:
	if curr_new_garden_plant_types.is_empty():
		return pick_random_garden_plant_species()
	return curr_new_garden_plant_types.pop_front()


## 随机一个花园植物物种（原版 PickRandomSeedType：40 种里排除金盏花 / 花盆）
## 这里额外排除只由代码创建的工具植物，以及没登记场景的 id
func pick_random_garden_plant_species() -> StringName:
	var pool: Array[StringName] = []
	for species in PlantIds.ALL:
		if species == PlantIds.MARI_GOLD or species == PlantIds.FLOWER_POT \
				or species == PlantIds.SPROUT or species == PlantIds.IMITATER \
				or species == PlantIds.WATER_BOWL:
			continue
		if Global.character_registry == null:
			continue
		if Global.character_registry.get_plant_info(
				species, CharacterRegistry.PlantInfoAttribute.PlantScenes) == null:
			continue
		pool.append(species)
	if pool.is_empty():
		return PlantIds.MARI_GOLD
	return pool.pick_random()
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
## 独轮车是否已购买(原版 $20 的摆设,买下不产生任何效果,见 ConstShop.WHEEL_BARROW_PRICE)
var is_wheel_barrow_bought: bool = DEFAULT_IS_WHEEL_BARROW_BOUGHT
## 「第一次掉落钱」的提示是否已经弹过(全局只弹一次,弹完即落存档,见 MainGameManager._on_first_coin_drop)
var is_first_coin_advice_shown: bool = DEFAULT_IS_FIRST_COIN_ADVICE_SHOWN
## 僵尸卡片是否被**运行期**打开（模组口子，见 `set_runtime_zombie_card_enabled()`；
## 本体自己从不置真，也不随存档走）
var _runtime_zombie_card_enabled: bool = false
var garden_data: Dictionary = DEFAULT_GARDEN_DATA.duplicate(true)
var curr_all_level_state_data: Dictionary = DEFAULT_CURR_ALL_LEVEL_STATE_DATA.duplicate(true)
## 冒险模式周目(1 = 首周目): 通关 5-10 后 +1,之后从 1-1 重打一轮(见 advance_adventure_round)
## ★ 存档键**不含**周目: 每周目的进度靠关卡记录里的 "Round" 跟它比较来区分,不是靠换存档键
## (换键等于把「10 关一页、按钮序号 == 关卡序号」那条老口径改掉,会静默挪移所有人的进度)
var curr_adventure_round: int = DEFAULT_ADVENTURE_ROUND
var selected_cards: Array = []

## 已解锁的植物:
## 初始只有豌豆射手,白卡通过冒险模式关卡解锁(见 ConstPlantUnlock),紫卡与模仿者在商店购买后加入
var curr_plant :Array[StringName]= ConstPlantUnlock.INIT_PLANT_TYPES.duplicate()

## 把所有**落盘字段**清回默认值(切到一个还没有存档的新用户时调用)
##
## 为什么必须显式清:读档是"只覆盖读到的键",而新用户连存档文件都没有 ——
## 不先清空的话,上一个用户留在内存里的金币 / 关卡进度 / 花园 / 选卡 / 已解锁植物 / 僵尸
## 会被自动存档原样写进新用户的空目录,表现就是"新建的用户继承了上一个账号的存档"。
## 调用方只有一个:SaveService.load_global_game_data() 判定"该用户没有任何存档文件"时。
func reset_to_defaults() -> void:
	coin_value = DEFAULT_COIN_VALUE
	curr_num_new_garden_plant = DEFAULT_CURR_NUM_NEW_GARDEN_PLANT
	curr_new_garden_plant_types.clear()
	card_slot_upgrade_num = DEFAULT_CARD_SLOT_UPGRADE_NUM
	is_pool_cleaner_bought = DEFAULT_IS_POOL_CLEANER_BOUGHT
	is_roof_cleaner_bought = DEFAULT_IS_ROOF_CLEANER_BOUGHT
	rake_use_num = DEFAULT_RAKE_USE_NUM
	is_wall_nut_first_aid_bought = DEFAULT_IS_WALL_NUT_FIRST_AID_BOUGHT
	is_wheel_barrow_bought = DEFAULT_IS_WHEEL_BARROW_BOUGHT
	is_first_coin_advice_shown = DEFAULT_IS_FIRST_COIN_ADVICE_SHOWN
	garden_data = DEFAULT_GARDEN_DATA.duplicate(true)
	curr_all_level_state_data = DEFAULT_CURR_ALL_LEVEL_STATE_DATA.duplicate(true)
	curr_adventure_round = DEFAULT_ADVENTURE_ROUND
	selected_cards = []
	curr_plant = ConstPlantUnlock.INIT_PLANT_TYPES.duplicate()
	curr_zombie = DEFAULT_CURR_ZOMBIE.duplicate()

#region 植物解锁进度
## 植物是否已解锁
func is_plant_unlocked(plant_type: StringName) -> bool:
	return curr_plant.has(plant_type)

## 解锁一个植物,返回是否为本次新解锁
func unlock_plant(plant_type: StringName) -> bool:
	if plant_type == PlantIds.NULL:
		return false
	if curr_plant.has(plant_type):
		return false
	curr_plant.append(plant_type)
	return true

## 撤掉一株植物的解锁（模组关掉 / 玩法下线时用）：从已解锁列表摘掉,并把「上次选卡」里的
## 条目一并清掉
##
## ★ 这是留给模组的口子（与 `unlock_plant()` 成对）：只装一次的话玩家一读档植物就回来了
## （读档按存档重建 `curr_plant`），卸载时也要真的从列表里删 —— 光把开关置 false 没用。
func lock_plant(plant_type: StringName) -> void:
	if plant_type == PlantIds.NULL:
		return
	curr_plant.erase(plant_type)
	_remove_plant_from_selected_cards(plant_type)

## 批量解锁植物,返回本次新解锁的植物
func unlock_plants(plant_types:Array) -> Array[StringName]:
	var new_unlock:Array[StringName] = []
	for plant_type in plant_types:
		## 入参可能是老存档里的数字编号（见 PlantIds.from_legacy）
		if unlock_plant(PlantIds.from_legacy(plant_type)):
			new_unlock.append(PlantIds.from_legacy(plant_type))
	return new_unlock

## 僵尸卡片（含僵王卡）当前是否可用：总开关打开，或被**运行期**打开
##
## ★ 这是僵尸卡片唯一的判据，三处入口都问它：待选卡槽生成僵尸卡页 / 关卡预选僵尸卡 /
## 「重选上次卡片」恢复僵尸卡 —— 别在调用点直接读 ConstFeatureSwitch.ZOMBIE_CARD_ENABLED。
##
## 原版没有「在关卡里直接放下僵尸」这个功能，所以「运行期打开」是留给**模组**的口子
## （见 `set_runtime_zombie_card_enabled()`）：本体自己从不置真。
func is_zombie_card_enabled() -> bool:
	return ConstFeatureSwitch.ZOMBIE_CARD_ENABLED or _runtime_zombie_card_enabled

## 运行期开关（模组用）：开放僵尸卡片；关掉时顺手清掉「上次选卡」里的僵尸条目
##
## ⚠️ 它不随存档走：模组开 / 关时自己调一次，读档覆盖 `selected_cards` 后由模组的
## `on_session_reloaded()` 再补一次（见 `ModBase.on_session_reloaded()`）。
func set_runtime_zombie_card_enabled(value: bool) -> void:
	if _runtime_zombie_card_enabled == value:
		return
	_runtime_zombie_card_enabled = value
	_sync_runtime_zombie_cards()

## 是否被运行期打开（模组自检用；业务侧一律问 `is_zombie_card_enabled()`）
func is_runtime_zombie_card_enabled() -> bool:
	return _runtime_zombie_card_enabled

## 僵尸卡片关掉时,把「上次选卡」里的僵尸 / 僵王条目一并清掉
## 为什么必须连这里一起清:「重选上次卡片」照存档条目直接点待选卡位(见 CardSlotNorm),
## 僵尸卡关掉后待选区根本没有僵尸容器,条目留着会索引到不存在的卡位。
## 总开关打开时僵尸卡始终可用,不做清理。
func _sync_runtime_zombie_cards() -> void:
	if is_zombie_card_enabled():
		return
	for i in range(selected_cards.size() - 1, -1, -1):
		var card_data: Dictionary = selected_cards[i]
		var card_type: ResourceCardReference.CardType = int(card_data.get(
			"card_type", ResourceCardReference.CardType.Null)) as ResourceCardReference.CardType
		if card_type == ResourceCardReference.CardType.Zombie \
			or card_type == ResourceCardReference.CardType.ZombieBoss:
			selected_cards.remove_at(i)

## 从「上次选卡」里摘掉一株已不可选的植物
## 为什么必须连这里一起清:「重选上次卡片」是照存档条目直接点待选卡位的(
## 见 CardSlotNorm._on_re_card_button_pressed),卡片容器在植物被撤销解锁 / 卸掉模组后已经不在了,
## 条目留着就会点到一个不存在的卡位。
func _remove_plant_from_selected_cards(plant_type: StringName) -> void:
	for i in range(selected_cards.size() - 1, -1, -1):
		var card_data: Dictionary = selected_cards[i]
		if int(card_data.get("card_type", ResourceCardReference.CardType.Null)) != ResourceCardReference.CardType.Plant:
			continue
		## content_id 可能是老存档的数字编号，按类别转一次再比（见 PlantIds.from_legacy）
		if PlantIds.from_legacy(card_data.get("content_id", &"")) != plant_type:
			continue
		selected_cards.remove_at(i)

## 通关冒险模式某关后解锁该关对应的植物,返回本次新解锁的植物
## adventure_level: 冒险模式关卡序号(1-1 = 1 …… 5-10 = 50)
## 该关给哪一株**由那一关的脚本**说了算(level_complete_loot 那个战利品名字,见 LootRegistry):
## 既向本关掉的那包种子,也决定这里解锁的植物 —— 同一件事只在一处写,没有另外一张「关卡序号 -> 植物」表。
func unlock_plant_on_adventure_level(adventure_level:int) -> Array[StringName]:
	var plants: Array[StringName] = []
	var reward_plant := LevelRegistry.get_adventure_level_reward_plant(adventure_level)
	if reward_plant != PlantIds.NULL:
		plants.append(reward_plant)
	return unlock_plants(plants)

## 已通关的最大冒险模式关卡序号,**历史最高**(跨周目),没有通关过冒险关卡时返回 0
##
## ⚠️ 这是「解锁门」的口径,不是「本周目进度」——所有解锁(铲子 / 图鉴 / 花园 / 商店 /
## 商店扩展 / 紫卡 / 迷你 / 解谜 / 生存)都读它,所以二周目**不清任何记录**就能让已解锁的东西全部继承;
## 「本周目打哪一关」读另一个函数 get_adventure_round_cleared_level()。
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


## 某一关记录里的周目(记录没有这个键时当周目 1:老存档 / 非冒险模式的记录都属于「以前通的」)
static func get_round_on_level_state_data(level_state_data: Dictionary) -> int:
	return int(level_state_data.get(LEVEL_STATE_DATA_ROUND_KEY, DEFAULT_ADVENTURE_ROUND))


## 本周目已通关的最大冒险关卡序号(0 = 本周目一关都还没通)
##
## ⚠️ 与 get_max_success_adventure_level() 的分工(**别混用**):
##   · 本函数看「本周目」——决定该打哪一关、主菜单木牌显示哪一关;
##   · 那个看「历史最高」——决定各类解锁门(见那处注释)。
##
## 二周目的「进度清零」是**算出来的,不是删出来的**:进二周目只把 curr_adventure_round +1,
## 一条记录都不删 —— 老记录的 Round 小于当前周目,自然就不算「本周目已通关」。
## 这样已解锁的东西(植物按记录重建、商店 / 花园状态另存)全部原样继承,
## 也不会误删迷你 / 解谜 / 生存的进度(它们本来就不是冒险模式的键)。
func get_adventure_round_cleared_level() -> int:
	var max_level := 0
	for save_game_name in curr_all_level_state_data:
		var level_state_data: Dictionary = curr_all_level_state_data[save_game_name]
		if not level_state_data.get("IsSuccess", false):
			continue
		var adventure_level: int = get_adventure_level_on_save_game_name(str(save_game_name))
		if adventure_level <= max_level:
			continue
		if get_round_on_level_state_data(level_state_data) < curr_adventure_round:
			continue
		max_level = adventure_level
	return max_level


## 是否已经是二周目及以后(二周目起换用这一关自己的脚本 adventure_XX_YY_round2.gd,
## 那边 1-1 ~ 1-3 直接给满 5 行草皮, 见 docs/参考存档/二周目.md §6)
func is_from_second_round() -> bool:
	return curr_adventure_round >= DEFAULT_ADVENTURE_ROUND + 1


## 本周目的冒险模式是否已全部通关(1-1 ~ 5-10 都通了)
func is_adventure_round_finished() -> bool:
	return get_adventure_round_cleared_level() >= ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL


## 通关本周目的最后一关(5-10)后进下一周目: 周目 +1 并落盘,返回是否真的进了下一周目。
##
## 由 MgmRewardManager.win_main_game() 在写完通关存档之后调用,**幂等**:
## 本周目没全通时什么都不做(所以重打 5-10 / 在别的关卡结算都不会误进下一周目)。
## 「重新从 1-1 开始」不用在这里做任何事 —— 它是 get_adventure_round_cleared_level() 的过滤结果。
func advance_adventure_round() -> bool:
	if not is_adventure_round_finished():
		return false
	curr_adventure_round += 1
	Global.save_service.save_now()
	Log.info(str("冒险模式第 ") + str(curr_adventure_round) + str(" 周目开始：木牌上的关卡号回到 1-1，已解锁内容全部保留"))
	return true

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

## 冒险模式当前该打的那一关的序号(1-1 = 1 …… 5-10 = 50)
## = **本周目**已通关的最大序号 + 1(新档 / 刚进二周目 = 1-1) —— 与主菜单木牌上的关卡号同一口径
## (ConstUnlockLevel.get_adventure_button_level),两者对不上就是「木牌写 1-2 却进了别的关」。
##
## 走的是本周目进度(get_adventure_round_cleared_level),不是历史最高:二周目进档时历史最高还是 50,
## 拿它当口径会把玩家直接丢回 5-10。
func get_curr_adventure_level_to_play() -> int:
	return ConstUnlockLevel.get_adventure_button_level(get_adventure_round_cleared_level())


## 拼出「冒险模式当前该打的那一关」的进关参数：**进冒险模式直接拿它开打**
##
## 冒险模式没有选关界面(见 docs/参考存档/选关界面与解锁.md)，所以这份参数由这里现场拼 ——
## 它与「以前在选关界面上点那一关的按钮」得到的参数完全一致：
##   · 关卡本体按序号走 LevelRegistry(硬约束 §1-4，业务代码不写 res:// 关卡路径)；
##   · 选关三件套仍走 set_choose_level()，页码 / 关卡号沿用「10 关一页、按钮序号 == 关卡序号」的旧口径
##     —— 没写 save_key 的老关卡**就靠这两个值拼出存档键**，换算法等于把玩家的通关进度整体挪位
##     (护栏见 test/scenarios/probe_level_registry_order.gd)。
func build_curr_adventure_level_para() -> ResourceLevelData:
	return build_adventure_level_para(get_curr_adventure_level_to_play())


## 拼出冒险模式第 adventure_level 关的进关参数；序号没有对应的关卡 / 关卡取不出来返回 null
func build_adventure_level_para(adventure_level: int) -> ResourceLevelData:
	## 按**当前周目**取关卡：二周目及以后优先拿这一关的二周目变体脚本
	## （adventure_XX_YY_round2，见 LevelRegistry.ROUND_VARIANT_SUFFIX 与 docs/参考存档/二周目.md）
	var level_id := LevelRegistry.get_adventure_level_id(adventure_level, curr_adventure_round)
	if level_id.is_empty():
		Log.error("冒险模式关卡序号非法：%d" % adventure_level)
		return null
	var level_para := LevelRegistry.get_level(level_id)
	if level_para == null:
		return null
	var level_page := floori(float(adventure_level - 1) / float(ADVENTURE_LEVEL_PER_PAGE))
	level_para.set_choose_level(
		MainSceneRegistry.MainScenes.ChooseLevelAdventure, level_page, "%04d" % adventure_level)
	return level_para

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
##
## 写的是**当前周目**的通关（记录里带 "Round"），所以在二周目按它 = 把二周目打通到 5-10；
## **不会**顺手进下一周目 —— 周目只在 win_main_game() 真的打完 5-10 时 +1
## （想快速看到二周目：本快捷键 + 进 5-10 再 Ctrl+D 0 通关本关）。
## 返回本次写成通关的关卡数量
func success_all_adventure_level() -> int:
	var success_num := 0
	for adventure_level in range(1, ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL + 1):
		var save_game_name := get_adventure_save_game_name(adventure_level)
		if save_game_name == "":
			continue
		var curr_level_state_data: Dictionary = curr_all_level_state_data.get(save_game_name, {})
		curr_level_state_data["IsSuccess"] = true
		curr_level_state_data[LEVEL_STATE_DATA_ROUND_KEY] = curr_adventure_round
		curr_all_level_state_data[save_game_name] = curr_level_state_data
		var new_unlock: Array[StringName] = unlock_plant_on_adventure_level(adventure_level)
		for plant_type: StringName in new_unlock:
			Log.info(str("通关解锁新植物: ") + str(Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)))
		success_num += 1
	Global.save_service.save_now()
	return success_num


## 紫卡植物与模仿者是否已开放购买(需通关对应关卡后在商店购买)
func is_purple_card_can_buy(plant_type: StringName) -> bool:
	return ConstPlantUnlock.is_purple_card_can_buy(plant_type, get_max_success_adventure_level())
## 该植物是否为商店商品(紫卡或模仿者)
func is_shop_plant(plant_type: StringName) -> bool:
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

## 花园是否已解锁(通完 5-4 后戴夫把禅境花园交给玩家,在此之前拿不到任何花园植物)
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

#region 独轮车
## 独轮车是否已购买(原版一次性商品:买完即 Sold Out,本身没有任何功能)
func is_wheel_barrow_owned() -> bool:
	return is_wheel_barrow_bought

## 购买独轮车,已经买过返回 false
func buy_wheel_barrow() -> bool:
	if is_wheel_barrow_bought:
		return false
	is_wheel_barrow_bought = true
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

## 把 garden_data 里每株已存档花园植物的类型(id / 枚举)统一回运行期形态（读档后调一次）
func normalize_garden_plant_cell_data() -> void:
	garden_state.normalize_garden_plant_cell_data()

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


## 调试用：把疯狂戴夫商店里的商品全部置为「已拥有」（快捷键 Ctrl+D 然后按 3）
## 与真花钱买的区别只有「不扣金币」：每一件都走各自的购买入口（buy_* / unlock_plant），
## 所以买断型记"已买"、消耗型补到持有上限、紫卡与模仿者直接进已解锁植物 —— 与在货架上买完等价。
##
## ⚠️ 不动关卡进度：商店"开不开门 / 上不上架"是通关进度推出来的（见 ConstUnlockLevel），
## 想连关卡一起解锁请按 Ctrl+D 然后按 1；这里只负责"货架上能看到的那些货都归你"。
## 巧克力不在货架上（只由僵尸掉落，见 ConstShop.CHOCOLATE_PRICE 的注释），调试时顺手一起补满。
## 返回本次新拥有的商品件数
func unlock_all_shop_goods() -> int:
	var goods_num := 0
	## 卡槽扩充拉满（原版最多买到 ConstShop.MAX_CARD_SLOT_NUM 格）
	while add_card_slot_upgrade():
		goods_num += 1
	## 水路 / 屋顶清洁车（普通草坪小推车免费配发，不在货架上）
	var cleaner_types: Array[GIM_LawnMover.E_LawnMoverType] = [
		GIM_LawnMover.E_LawnMoverType.PoolCleaner,
		GIM_LawnMover.E_LawnMoverType.RoofCleaner,
	]
	for mover_type in cleaner_types:
		if buy_lawn_mover(mover_type):
			goods_num += 1
	## 钉耙：手上没有就买一次，有就补满（买一次管 ConstShop.RAKE_USE_NUM_PER_BUY 关）
	if buy_rake():
		goods_num += 1
	elif rake_use_num < ConstShop.RAKE_USE_NUM_PER_BUY:
		rake_use_num = ConstShop.RAKE_USE_NUM_PER_BUY
	## 坚果包扎术
	if buy_wall_nut_first_aid():
		goods_num += 1
	## 独轮车（原版 $20 的摆设，买完 Sold Out，本身没有功能）
	if buy_wheel_barrow():
		goods_num += 1
	## 紫卡与模仿者：直接进已解锁植物（再到货架上看到就是"已拥有"）
	goods_num += unlock_plants(ConstPlantUnlock.get_all_shop_plant_types()).size()
	## 蘑菇园 / 水族馆（阳光房默认就有；智慧树页由 buy_tree_of_wisdom() 一并开出来）
	for bg_type in ConstShop.GARDEN_BG_PRICE:
		if buy_garden_bg(int(bg_type) as GardenManager.E_GardenBgType):
			goods_num += 1
	## 智慧树（买断 + 开智慧树页 + 送戴夫白送的那几袋树肥料）
	if buy_tree_of_wisdom():
		goods_num += 1
	## 花园工具：买断型记"已买"，消耗型补到持有上限
	for i in range(GardenManager.E_GardenTool.size()):
		var tool_type := i as GardenManager.E_GardenTool
		if GlobalGameState.is_consumable_garden_tool(tool_type):
			var lack_num := ConstShop.get_tool_max_own_num(tool_type) - get_garden_tool_num(tool_type)
			if lack_num > 0 and add_garden_tool_num(tool_type, lack_num):
				goods_num += 1
		elif buy_garden_tool(tool_type):
			goods_num += 1
	Global.save_service.save_now()
	return goods_num
#endregion

## 已解锁僵尸的默认列表(新用户 / 重置存档时的初始值,见 reset_to_defaults)
const DEFAULT_CURR_ZOMBIE: Array[StringName] = [
	ZombieIds.NORM,
	ZombieIds.FLAG,
	ZombieIds.CONE,
	ZombieIds.POLE_VAULTER,
	ZombieIds.BUCKET,
	ZombieIds.PAPER,
	ZombieIds.SCREEN_DOOR,
	ZombieIds.FOOTBALL,
	ZombieIds.JACKSON,
	ZombieIds.DANCER,
	ZombieIds.DUCKYTUBE,
	ZombieIds.SNORKLE,
	ZombieIds.ZAMBONI,
	ZombieIds.BOBSLED,
	ZombieIds.DOLPHINRIDER,
	ZombieIds.JACKBOX,
	ZombieIds.BALLOON,
	ZombieIds.DIGGER,
	ZombieIds.POGO,
	ZombieIds.YETI,
	ZombieIds.BUNGI,
	ZombieIds.LADDER,
	ZombieIds.CATAPULT,
	ZombieIds.GARGANTUAR,
	ZombieIds.IMP,
	ZombieIds.BOBSLED_SINGLE,
]

## 已解锁的僵尸（新用户取 DEFAULT_CURR_ZOMBIE，见 reset_to_defaults）
var curr_zombie :Array[StringName]= DEFAULT_CURR_ZOMBIE.duplicate()

## 已解锁的僵王；博士默认可选，与已解锁的普通僵尸共同组成僵尸候选页
var curr_zombie_boss :Array[StringName] = [
	ZombieBossIds.DOCTOR,
]

## 僵王是否已解锁
func is_zombie_boss_unlocked(boss_type: StringName) -> bool:
	return curr_zombie_boss.has(boss_type)
