extends RefCounted
class_name PlantIds
## 植物类型 id 表：**用 StringName 当 id，不再用 P001 这种数字编号**（2026-10-13 迁移）。
##
## 为什么改（与 `BulletIds` 同一轮，子弹先试点通过后才铺到这里）：
##   ① `plant_type = 5` 这种数字在 57 个 `.tscn` / 关卡 `.tres` 里，**改枚举值会静默错位**，
##      而编译门禁查不出来（它只编译脚本，不校验资源里的值）；
##   ② 插一个新植物要在 P001–P050 的缝里挑号，`P050WaterBowl` 这种空槽位就是这么来的；
##   ③ 编号被当成数值用了：`content_id <= 0` 判空、`PlantIds.ALL` 遍历、热注册靠编号自增 ——
##      这些在字符串 id 下都要换成显式写法（判空用 `NULL`、遍历用 `ALL`）。
##
## 与旧枚举的**值对应关系**（旧 `CharacterRegistry.PlantType` 已删除）：
##   P001=1 … P050=50，P999Imitater=999，P1000Sprout=1000，P1001/1002/1003=1001/1002/1003。
## 映射表保留在 `LEGACY_INT_TO_ID`，**只用于读老存档**（见 `save_service.gd`），
## 业务代码里一律用 `PlantIds.XXX`，不要再出现裸数字。
##
## 取 id 的规范写法：`PlantIds.PEA_SHOOTER_SINGLE`；**不要**在业务代码里写裸字符串
## （写错要运行时才炸，而 `PlantIds.` 写错是编译错误）。
##
## ⚠️ 新增植物：加常量 + 进 `ALL` + 进 `PlantInfoData.PLANT_INFO`。
## **不要**动 `LEGACY_INT_TO_ID` —— 那是老存档里的固定历史值，新植物本来就不在老存档里。


## 空 id：没指定植物（如基类场景 / 只做展示）。
const NULL := &""


#region 常见植物（P001–P048）
const PEA_SHOOTER_SINGLE := &"pea_shooter_single"			## 豌豆射手
const SUN_FLOWER := &"sun_flower"						## 向日葵
const CHERRY_BOMB := &"cherry_bomb"						## 樱桃炸弹
const WALL_NUT := &"wall_nut"							## 坚果墙
const POTATO_MINE := &"potato_mine"						## 土豆雷
const SNOW_PEA := &"snow_pea"							## 寒冰射手
const CHOMPER := &"chomper"							## 大嘴花
const PEA_SHOOTER_DOUBLE := &"pea_shooter_double"				## 双发射手
const PUFF_SHROOM := &"puff_shroom"						## 小喷菇
const SUN_SHROOM := &"sun_shroom"						## 阳光菇
const FUME_SHROOM := &"fume_shroom"						## 大喷菇
const GRAVE_BUSTER := &"grave_buster"						## 墓碑吞噬者
const HYPNO_SHROOM := &"hypno_shroom"						## 魅惑菇
const SCAREDY_SHROOM := &"scaredy_shroom"					## 胆小菇
const ICE_SHROOM := &"ice_shroom"						## 寒冰菇
const DOOM_SHROOM := &"doom_shroom"						## 毁灭菇
const LILY_PAD := &"lily_pad"							## 睡莲
const SQUASH := &"squash"							## 窝瓜
const THREE_PEATER := &"three_peater"					## 三线豌豆
const TANGLE_KELP := &"tangle_kelp"						## 缠绕水草
const JALAPENO := &"jalapeno"							## 火爆辣椒
const CALTROP := &"caltrop"							## 地刺
const TORCH_WOOD := &"torch_wood"						## 火炬树桩
const TALL_NUT := &"tall_nut"							## 高坚果
const SEA_SHROOM := &"sea_shroom"						## 海蘑菇
const PLANTERN := &"plantern"							## 灯笼草
const CACTUS := &"cactus"							## 仙人掌
const BLOVER := &"blover"							## 三叶草
const SPLIT_PEA := &"split_pea"						## 裂荚射手
const STAR_FRUIT := &"star_fruit"						## 杨桃
const PUMPKIN := &"pumpkin"							## 南瓜头
const MAGNET_SHROOM := &"magnet_shroom"					## 磁力菇
const CABBAGE_PULT := &"cabbage_pult"						## 卷心菜投手
const FLOWER_POT := &"flower_pot"						## 花盆
const CORN_PULT := &"corn_pult"						## 玉米投手
const COFFEE_BEAN := &"coffee_bean"						## 咖啡豆
const GARLIC := &"garlic"							## 大蒜
const UMBRELLA_LEAF := &"umbrella_leaf"					## 叶子保护伞
const MARI_GOLD := &"mari_gold"						## 金盏花
const MELON_PULT := &"melon_pult"						## 西瓜投手
const GATLING_PEA := &"gatling_pea"						## 机枪豌豆
const TWIN_SUN_FLOWER := &"twin_sun_flower"					## 双胞胎向日葵
const GLOOM_SHROOM := &"gloom_shroom"					## 忧郁蘑菇
const CATTAIL := &"cattail"							## 香蒲
const WINTER_MELON := &"winter_melon"					## 冰瓜
const GOLD_MAGNET := &"gold_magnet"						## 吸金磁
const SPIKE_ROCK := &"spike_rock"						## 地刺王
const COB_CANNON := &"cob_cannon"						## 玉米加农炮
#endregion


#region 工具植物（**没有卡，只能由代码 / 模组创建**）
## 隐形植物：看不见、不攻击、不生产，只留一副「能被僵尸索敌」的受击框；
## 伤害可以转移给绑定角色（见 `PlantInvisible`）。
##
## ⚠️ 它**不进 `ALL`**：`ALL` 是「内置玩法植物」的名单（`ResourceCardReference.is_valid()`
## 等都拿它当判据），工具植物进去会凭空多出一张卡 / 一条图鉴。登记在
## `PlantInfoData.PLANT_INFO` 里就够调用方按 id 取场景了。
const INVISIBLE := &"invisible_plant"
#endregion


#region 特殊段
const PEA_SHOOTER_DOUBLE_REVERSE := &"pea_shooter_double_reverse"	## 反向双发射手（P049）
const WATER_BOWL := &"water_bowl"						## 水盆（P050，**空槽位**：场景/数据/卡片由 `water_bowl` 模组运行期注入）
const IMITATER := &"imitater"							## 模仿者（P999）
const SPROUT := &"sprout"							## 萌芽（P1000）
const WALL_NUT_BOWLING := &"wall_nut_bowling"				## 保龄球坚果（P1001）
const WALL_NUT_BOWLING_BOMB := &"wall_nut_bowling_bomb"			## 爆炸保龄球坚果（P1002）
const WALL_NUT_BOWLING_BIG := &"wall_nut_bowling_big"			## 大保龄球坚果（P1003）
#endregion


## 全部内置植物 id（顺序与原枚举声明顺序一致，遍历口径见 `global_read_data.gd`）
const ALL: Array[StringName] = [
	PEA_SHOOTER_SINGLE, SUN_FLOWER, CHERRY_BOMB, WALL_NUT, POTATO_MINE, SNOW_PEA, CHOMPER,
	PEA_SHOOTER_DOUBLE, PUFF_SHROOM, SUN_SHROOM, FUME_SHROOM, GRAVE_BUSTER, HYPNO_SHROOM,
	SCAREDY_SHROOM, ICE_SHROOM, DOOM_SHROOM, LILY_PAD, SQUASH, THREE_PEATER, TANGLE_KELP,
	JALAPENO, CALTROP, TORCH_WOOD, TALL_NUT, SEA_SHROOM, PLANTERN, CACTUS, BLOVER, SPLIT_PEA,
	STAR_FRUIT, PUMPKIN, MAGNET_SHROOM, CABBAGE_PULT, FLOWER_POT, CORN_PULT, COFFEE_BEAN,
	GARLIC, UMBRELLA_LEAF, MARI_GOLD, MELON_PULT, GATLING_PEA, TWIN_SUN_FLOWER, GLOOM_SHROOM,
	CATTAIL, WINTER_MELON, GOLD_MAGNET, SPIKE_ROCK, COB_CANNON,
	PEA_SHOOTER_DOUBLE_REVERSE, WATER_BOWL,
	IMITATER, SPROUT, WALL_NUT_BOWLING, WALL_NUT_BOWLING_BOMB, WALL_NUT_BOWLING_BIG,
]


## 老存档里的数字编号 → id（**只给读老存档用**，见 `save_service.gd`）
##
## 为什么单独留这张表：存档是**已经写在玩家磁盘上**的数据，改 id 不能让它作废。
## 读档时遇到 int 就按这张表转成 id，转完写回 —— 玩家已解锁的植物、上次选的卡都不丢。
## ⚠️ 这是**历史值**，不要往里加新植物；也不要在业务代码里反向查它。
##
## ⚠️ 别把它当死代码删：玩家磁盘上的老存档还在靠这张表，包括**从没被新版加载过**的档
##   （`user://<用户名>/GlobalSaveGame.json`，比如一直没切过去的 `default user`，里面还是
##   `curr_zombie = [1, 2, 3…]`）。删掉 = 那些档的解锁植物 / 上次选卡 / 僵尸图鉴全变空。
##   调用面已收窄到**存档读取**这一条路（`save_service` / `global_game_state` / 花园三处），
##   卡槽、关卡配置、联机快照这些业务路径不再二次兜底 —— 上游漏转就当场露出空卡，
##   好过被这里静默映射成另一株植物。
const LEGACY_INT_TO_ID: Dictionary[int, StringName] = {
	1: PEA_SHOOTER_SINGLE, 2: SUN_FLOWER, 3: CHERRY_BOMB, 4: WALL_NUT, 5: POTATO_MINE,
	6: SNOW_PEA, 7: CHOMPER, 8: PEA_SHOOTER_DOUBLE, 9: PUFF_SHROOM, 10: SUN_SHROOM,
	11: FUME_SHROOM, 12: GRAVE_BUSTER, 13: HYPNO_SHROOM, 14: SCAREDY_SHROOM, 15: ICE_SHROOM,
	16: DOOM_SHROOM, 17: LILY_PAD, 18: SQUASH, 19: THREE_PEATER, 20: TANGLE_KELP,
	21: JALAPENO, 22: CALTROP, 23: TORCH_WOOD, 24: TALL_NUT, 25: SEA_SHROOM, 26: PLANTERN,
	27: CACTUS, 28: BLOVER, 29: SPLIT_PEA, 30: STAR_FRUIT, 31: PUMPKIN, 32: MAGNET_SHROOM,
	33: CABBAGE_PULT, 34: FLOWER_POT, 35: CORN_PULT, 36: COFFEE_BEAN, 37: GARLIC,
	38: UMBRELLA_LEAF, 39: MARI_GOLD, 40: MELON_PULT, 41: GATLING_PEA, 42: TWIN_SUN_FLOWER,
	43: GLOOM_SHROOM, 44: CATTAIL, 45: WINTER_MELON, 46: GOLD_MAGNET, 47: SPIKE_ROCK,
	48: COB_CANNON, 49: PEA_SHOOTER_DOUBLE_REVERSE, 50: WATER_BOWL,
	999: IMITATER, 1000: SPROUT,
	1001: WALL_NUT_BOWLING, 1002: WALL_NUT_BOWLING_BOMB, 1003: WALL_NUT_BOWLING_BIG,
}


## 是不是一个已知的植物 id（空 id 不算；运行期热注册的植物不在 `ALL` 里，要另外判）
static func is_valid(plant_id: StringName) -> bool:
	return plant_id != &"" and plant_id in ALL


## 老存档迁移：把一个可能是 int 也可能是 id 的值统一成 id
##
## [param value] 存档里读到的原始值（int / float / String / StringName 都可能）
## 返回：能认出来就返回 id，认不出来（0 / 空 / 未知编号）返回 `NULL`
static func from_legacy(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME or typeof(value) == TYPE_STRING:
		## ⚠️ **不能**写 `StringName(value)`：Godot 4 里 StringName 没有构造函数
		## （会报 "Nonexistent 'StringName' constructor"）。交一个 String 回去，
		## 返回类型是 StringName，GDScript 会自己转。
		return str(value)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return LEGACY_INT_TO_ID.get(int(value), NULL)
	return NULL
