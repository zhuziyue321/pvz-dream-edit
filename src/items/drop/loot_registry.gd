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
	"peashooter_seed_packet": CharacterRegistry.PlantType.P001PeaShooterSingle,
	"sunflower_seed_packet": CharacterRegistry.PlantType.P002SunFlower,
	"cherry_bomb_seed_packet": CharacterRegistry.PlantType.P003CherryBomb,
	"wall_nut_seed_packet": CharacterRegistry.PlantType.P004WallNut,
	"potato_mine_seed_packet": CharacterRegistry.PlantType.P005PotatoMine,
	"snow_pea_seed_packet": CharacterRegistry.PlantType.P006SnowPea,
	"chomper_seed_packet": CharacterRegistry.PlantType.P007Chomper,
	"peashooter_double_seed_packet": CharacterRegistry.PlantType.P008PeaShooterDouble,
	"puff_shroom_seed_packet": CharacterRegistry.PlantType.P009PuffShroom,
	"sun_shroom_seed_packet": CharacterRegistry.PlantType.P010SunShroom,
	"fume_shroom_seed_packet": CharacterRegistry.PlantType.P011FumeShroom,
	"grave_buster_seed_packet": CharacterRegistry.PlantType.P012GraveBuster,
	"hypno_shroom_seed_packet": CharacterRegistry.PlantType.P013HypnoShroom,
	"scaredy_shroom_seed_packet": CharacterRegistry.PlantType.P014ScaredyShroom,
	"ice_shroom_seed_packet": CharacterRegistry.PlantType.P015IceShroom,
	"doom_shroom_seed_packet": CharacterRegistry.PlantType.P016DoomShroom,
	"lily_pad_seed_packet": CharacterRegistry.PlantType.P017LilyPad,
	"squash_seed_packet": CharacterRegistry.PlantType.P018Squash,
	"three_peater_seed_packet": CharacterRegistry.PlantType.P019ThreePeater,
	"tangle_kelp_seed_packet": CharacterRegistry.PlantType.P020TangleKelp,
	"jalapeno_seed_packet": CharacterRegistry.PlantType.P021Jalapeno,
	"caltrop_seed_packet": CharacterRegistry.PlantType.P022Caltrop,
	"torch_wood_seed_packet": CharacterRegistry.PlantType.P023TorchWood,
	"tall_nut_seed_packet": CharacterRegistry.PlantType.P024TallNut,
	"sea_shroom_seed_packet": CharacterRegistry.PlantType.P025SeaShroom,
	"plantern_seed_packet": CharacterRegistry.PlantType.P026Plantern,
	"cactus_seed_packet": CharacterRegistry.PlantType.P027Cactus,
	"blover_seed_packet": CharacterRegistry.PlantType.P028Blover,
	"split_pea_seed_packet": CharacterRegistry.PlantType.P029SplitPea,
	"star_fruit_seed_packet": CharacterRegistry.PlantType.P030StarFruit,
	"pumpkin_seed_packet": CharacterRegistry.PlantType.P031Pumpkin,
	"magnet_shroom_seed_packet": CharacterRegistry.PlantType.P032MagnetShroom,
	"cabbage_pult_seed_packet": CharacterRegistry.PlantType.P033CabbagePult,
	"flower_pot_seed_packet": CharacterRegistry.PlantType.P034FlowerPot,
	"corn_pult_seed_packet": CharacterRegistry.PlantType.P035CornPult,
	"coffee_bean_seed_packet": CharacterRegistry.PlantType.P036CoffeeBean,
	"garlic_seed_packet": CharacterRegistry.PlantType.P037Garlic,
	"umbrella_leaf_seed_packet": CharacterRegistry.PlantType.P038UmbrellaLeaf,
	"mari_gold_seed_packet": CharacterRegistry.PlantType.P039MariGold,
	"melon_pult_seed_packet": CharacterRegistry.PlantType.P040MelonPult,
}


## 战利品对应的植物编号：种子包类战利品才有，其余返回 CharacterRegistry.PlantType.Null
static func get_plant_type(loot_name: String) -> int:
	return int(PLANT_SEED_PACKET_MAP.get(loot_name, CharacterRegistry.PlantType.Null))


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
