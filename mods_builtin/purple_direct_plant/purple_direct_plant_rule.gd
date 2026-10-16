extends RefCounted
## 模组「紫卡直接种植」的**规则与运行期状态**
##
## 为什么单独一份：模组入口（`purple_direct_plant_mod.gd`）与两个条件资源
## （`condition_purple_direct.gd` / `condition_purple_direct_cob_cannon.gd`）都要用它，
## 互相 preload 会成环（手套模组的 `glove_settings.gd` 是同一个套路）。
##
## 规则一句话：
##   紫卡**不必先种基座植物**，可以直接种在空地上；
##   代价是那一格要付「紫卡自己的价格 + 基座植物的阳光 + 惩罚阳光」。
##   种在基座上（原版那样）价格不变。

## 惩罚阳光在**模组存档文件**里的键名（`[purple_direct_plant]` 段；
## 与开关同一份文件，不用给 `ConfigService` 加字段）
const SETTING_KEY_PENALTY_SUN := "penalty_sun"
## 惩罚阳光的默认值 / 可调范围：0 = 只收基座植物的阳光，不额外罚
const PENALTY_SUN_DEFAULT := 50.0
const PENALTY_SUN_MIN := 0.0
const PENALTY_SUN_MAX := 300.0
const PENALTY_SUN_STEP := 25.0

## 当前拿在手上的那张卡（由 EventBus `HAND_CARD_TAKE` / `HAND_CARD_RELEASE` 维护）
## 判定"这一格种下去要付多少"改的是**这张卡**的价格 —— 手上没卡时
## （种子雨那种自动种、迷你游戏补种）不碰价格，只回答能不能种
static var curr_card: Card = null


## 没种在基座上时要多付的惩罚阳光（模组页面里可调，值落在模组存档文件里）
static func get_penalty_sun() -> int:
	return int(ModManager.get_mod_value(
			ModIds.PURPLE_DIRECT_PLANT, SETTING_KEY_PENALTY_SUN, PENALTY_SUN_DEFAULT))


static func set_penalty_sun(value: Variant) -> void:
	ModManager.set_mod_value(ModIds.PURPLE_DIRECT_PLANT, SETTING_KEY_PENALTY_SUN,
			clampf(float(value), PENALTY_SUN_MIN, PENALTY_SUN_MAX))


## 拿起一张卡（改价与判阳光都用得上它）
static func on_card_take(card: Card) -> void:
	curr_card = card


## 手上的卡放下 / 收回：把可能被改过的价格刷回标准价
## （不然悬着一张带惩罚价的卡，下一局看上去像涨价了）
static func on_card_release(_card: Card) -> void:
	if is_instance_valid(curr_card):
		refresh_card_sun_cost(curr_card.card_plant_type, false)
	curr_card = null


## 紫卡在出战卡槽里的**标准价**：本体那条公式（底价 + 50 × 场上已有的同款数量，
## 见 `CardSlotBattle.update_card_purple_sun_cost()`）
static func get_standard_sun_cost(plant_type: StringName) -> int:
	var base_cost := int(Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.SunCost))
	return base_cost + 50 * get_plant_num(plant_type)


## 没种在基座时这一格要付的价：标准价 + 基座植物的阳光 + 惩罚阳光
static func get_sun_cost_without_base(plant_type: StringName) -> int:
	return get_standard_sun_cost(plant_type) \
		+ get_base_plant_sun_cost(plant_type) \
		+ get_penalty_sun()


## 紫卡的基座植物（原版必须先种它；玉米加农炮的基座是玉米投手）
static func get_base_plant_type(plant_type: StringName) -> StringName:
	return Global.character_registry.AllPrePlantPurple.get(
			plant_type, PlantIds.NULL)


## 基座植物自己的阳光价格
static func get_base_plant_sun_cost(plant_type: StringName) -> int:
	var base_type := get_base_plant_type(plant_type)
	if base_type == PlantIds.NULL:
		return 0
	return int(Global.character_registry.get_plant_info(
			base_type, CharacterRegistry.PlantInfoAttribute.SunCost))


## 场上已有的同款植物数量（紫卡每多一株价格 +50，本体口径）
static func get_plant_num(plant_type: StringName) -> int:
	var main_game := GameContext.curr_main_game
	if main_game == null or main_game.plant_cell_manager == null:
		return 0
	return int(main_game.plant_cell_manager.curr_plant_num.get(plant_type, 0))


## 玩家现在的阳光（传送带关没有出战卡槽 = 0，那种关的紫卡走传送带、不花阳光）
static func get_sun_value() -> int:
	return LevelWaitCondition.get_sun_value(GameContext.curr_main_game)


## 没种在基座上时，这一格**付不付得起**
## 手上没这张卡（种子雨那种自动种植）或卡不花阳光（传送带）都算付得起 —— 那两种不经过玩家掏钱
static func can_afford_without_base(plant_type: StringName) -> bool:
	var card := curr_card
	if not is_instance_valid(card) or card.card_plant_type != plant_type:
		return true
	if card.card_context != Card.CardContext.Battle:
		return true
	return get_sun_value() >= get_sun_cost_without_base(plant_type)


## 把手上那张卡的价格改成"这一格种下去要付多少"
##
## 为什么要在这里改：扣钱是卡槽照 `card.sun_cost` 扣的（`CardSlotBattle.card_use_end()`），
## 而"种在基座上 / 没种在基座上"只有判定时才知道 —— 于是判定（鼠标进格子）顺手把价改好，
## 玩家在卡面上就能看到这一格的价，点下去扣的就是它。
## 种完本体那次 `update_card_purple_sun_cost()` 会把它刷回标准价，不用在这里收尾。
##
## [param with_penalty] true = 没种在基座上（加收基座阳光 + 惩罚），false = 标准价
static func refresh_card_sun_cost(plant_type: StringName, with_penalty: bool) -> void:
	var card := curr_card
	if not is_instance_valid(card) or card.card_plant_type != plant_type:
		return
	## 只改出战卡槽里的卡：传送带上的卡不花阳光（`sun_cost` 恒为 0），给它标价反而误导
	if card.card_context != Card.CardContext.Battle:
		return
	card.sun_cost = get_sun_cost_without_base(plant_type) if with_penalty \
		else get_standard_sun_cost(plant_type)
	## 顺手让这张卡自己重新判一次"阳光够不够"（不够就压暗，一眼看得出来）
	card.judge_sun_enough(get_sun_value())
