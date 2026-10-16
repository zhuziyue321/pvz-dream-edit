class_name LootRegistry
## **战利品注册表：战利品名字 -> 贴图**（硬约束 §1-4：类型映射一律走注册表）
##
## 关卡脚本里 `await gain("taco")` / `_init()` 里 `level_complete_loot = "taco"` 那一个字符串
## 在这里查表，查出贴图后交给 DropItemManager.create_loot_drop() 生产一个掉落物
## （整条线见 MgmRewardManager.gain_loot）。
## **加一种战利品 = 这里加一行**，本体不认识任何具体战利品名（硬约束 §1-8）。
##
## 战利品分三类（同一个名字只命中一类，按「种子包 -> 贴图」的顺序查）：
##   1. **种子包类**：名字以 `_seed_packet` 结尾，值是植物编号 —— 种子包是运行时拼出来的
##      （卡片底图 + 植物形象，见 SeedPacket.set_plant），没有独立贴图
##   2. **贴图类**：奖杯 / 玉米卷 / 铁铲这类有现成贴图的 —— 掉的是礼物盒 Present 换上这张贴图
##      （与冒险 4-4 的玉米卷同一套，见 DropItemManager.create_loot_drop）
##   3. **提示与音效**：点开时弹的那句文本与播的音效（不配就用掉落物自带的）
##
## 谁在用它：
##   MgmRewardManager.gain_loot()        —— 掉落 + 等点开 + 收尾表演 + 结算切场景
##   LevelScriptBase.gain()              —— 关卡脚本里 `await gain("taco")` 那一句
##   LevelScriptBase.level_complete_loot —— 冒险每关「本关掉什么」的声明（_init 里写）
##   LevelRegistry.get_adventure_level_reward_plant() —— 「冒险第 N 关给哪株植物」的答案源

## 奖杯：关卡结束的兜底战利品（本关没有奖励时掉它，见 MgmRewardManager._spawn_trophy）
const TROPHY := "trophy"

## 疯狂戴夫的玉米卷（冒险 4-4，贴图类）
const TACO := "taco"
## 铁铲（冒险 1-4，贴图类）
const SHOVEL := "shovel"
## 大图鉴（冒险 2-4，贴图类）
const ALMANAC := "almanac"
## 戴夫的车钥匙（冒险 3-4，贴图类）
const CAR_KEYS := "car_keys"
## 禅境花园的洒水壶（冒险 5-4，贴图类）
const WATERING_CAN := "watering_can"

## 名字 -> 贴图（res:// 绝对路径，硬约束 §1-5）
const TEXTURE_MAP := {
	TROPHY: preload("res://assets/image/ui/ui_trophy/trophy_hi_res.png"),
	TACO: preload("res://assets/image/main_game_item/Taco.png"),
	SHOVEL: preload("res://assets/image/ui/ui_card/Shovel.png"),
	ALMANAC: preload("res://assets/image/main_game_item/Almanac.png"),
	CAR_KEYS: preload("res://assets/image/main_game_item/CarKeys.png"),
	WATERING_CAN: preload("res://assets/image/garden/WateringCan.png"),
}

## 名字 -> 点开时弹的提示文本（种子包类不写：提示是新植物那句，由植物中文名现拼）
const TIP_MAP := {
	SHOVEL: "你得到一把铁铲！用它可以铲掉种下的植物。",
	ALMANAC: "你发现了大图鉴！记载所有你遇到的植物和僵尸。",
	CAR_KEYS: "你找到了戴夫的车钥匙，商店解锁！",
	TACO: "你找到了戴夫的玉米卷，商店上架了新商品！",
	WATERING_CAN: "你发现了个洒水壶！用它给花园里的植物浇水。",
}

## 名字 -> 点开音效（不配就用掉落物自带的那个）
const SFX_MAP := {
	TROPHY: "winmusic",
}

## 种子包类战利品：名字 = "<植物>_seed_packet"，值是植物编号
## （冒险模式「本关给哪株植物」就是这张表的键，见 LevelRegistry.get_adventure_level_reward_plant）
const PLANT_SEED_PACKET_MAP := {
	"peashooter_seed_packet": PlantIds.PEA_SHOOTER_SINGLE,
	"sunflower_seed_packet": PlantIds.SUN_FLOWER,
	"cherry_bomb_seed_packet": PlantIds.CHERRY_BOMB,
	"wall_nut_seed_packet": PlantIds.WALL_NUT,
	"potato_mine_seed_packet": PlantIds.POTATO_MINE,
	"snow_pea_seed_packet": PlantIds.SNOW_PEA,
	"chomper_seed_packet": PlantIds.CHOMPER,
	"peashooter_double_seed_packet": PlantIds.PEA_SHOOTER_DOUBLE,
	"puff_shroom_seed_packet": PlantIds.PUFF_SHROOM,
	"sun_shroom_seed_packet": PlantIds.SUN_SHROOM,
	"fume_shroom_seed_packet": PlantIds.FUME_SHROOM,
	"grave_buster_seed_packet": PlantIds.GRAVE_BUSTER,
	"hypno_shroom_seed_packet": PlantIds.HYPNO_SHROOM,
	"scaredy_shroom_seed_packet": PlantIds.SCAREDY_SHROOM,
	"ice_shroom_seed_packet": PlantIds.ICE_SHROOM,
	"doom_shroom_seed_packet": PlantIds.DOOM_SHROOM,
	"lily_pad_seed_packet": PlantIds.LILY_PAD,
	"squash_seed_packet": PlantIds.SQUASH,
	"three_peater_seed_packet": PlantIds.THREE_PEATER,
	"tangle_kelp_seed_packet": PlantIds.TANGLE_KELP,
	"jalapeno_seed_packet": PlantIds.JALAPENO,
	"caltrop_seed_packet": PlantIds.CALTROP,
	"torch_wood_seed_packet": PlantIds.TORCH_WOOD,
	"tall_nut_seed_packet": PlantIds.TALL_NUT,
	"sea_shroom_seed_packet": PlantIds.SEA_SHROOM,
	"plantern_seed_packet": PlantIds.PLANTERN,
	"cactus_seed_packet": PlantIds.CACTUS,
	"blover_seed_packet": PlantIds.BLOVER,
	"split_pea_seed_packet": PlantIds.SPLIT_PEA,
	"star_fruit_seed_packet": PlantIds.STAR_FRUIT,
	"pumpkin_seed_packet": PlantIds.PUMPKIN,
	"magnet_shroom_seed_packet": PlantIds.MAGNET_SHROOM,
	"cabbage_pult_seed_packet": PlantIds.CABBAGE_PULT,
	"flower_pot_seed_packet": PlantIds.FLOWER_POT,
	"corn_pult_seed_packet": PlantIds.CORN_PULT,
	"coffee_bean_seed_packet": PlantIds.COFFEE_BEAN,
	"garlic_seed_packet": PlantIds.GARLIC,
	"umbrella_leaf_seed_packet": PlantIds.UMBRELLA_LEAF,
	"mari_gold_seed_packet": PlantIds.MARI_GOLD,
	"melon_pult_seed_packet": PlantIds.MELON_PULT,
}


## 战利品对应的植物 id：种子包类战利品才有，其余返回 PlantIds.NULL
static func get_plant_type(loot_name: String) -> StringName:
	## 表里存的就是 id，不用再转一次（`StringName(x)` 也不是构造函数）
	return PLANT_SEED_PACKET_MAP.get(loot_name, PlantIds.NULL)


## 战利品的贴图；名字没登记 / 是种子包类时返回 null
static func get_texture(loot_name: String) -> Texture2D:
	return TEXTURE_MAP.get(loot_name, null) as Texture2D


## 战利品点开时弹的提示文本，没配返回空串（种子包类由调用方用植物名现拼）
static func get_tip(loot_name: String) -> String:
	return String(TIP_MAP.get(loot_name, ""))


## 战利品点开时的音效名，没配返回空串（调用方沿用掉落物自带的音效）
static func get_sfx(loot_name: String) -> String:
	return String(SFX_MAP.get(loot_name, ""))


## 这个名字有没有登记（种子包类 / 贴图类都算）
static func has(loot_name: String) -> bool:
	if PLANT_SEED_PACKET_MAP.has(loot_name):
		return true
	return TEXTURE_MAP.has(loot_name)
