extends RefCounted
class_name ZombieIds
## 僵尸类型 id 表：**用 StringName 当 id，不再用 Z001 这种数字编号**（2026-10-13 迁移）。
##
## 与 `PlantIds` / `BulletIds` 同一轮迁移，理由一致：数字编号不携带语义、插新僵尸要挑号、
## 42 个 `.tscn` 里的 `zombie_type = 3` 改枚举值会静默错位而编译门禁查不出来。
##
## 与旧枚举的**值对应关系**（旧 `CharacterRegistry.ZombieType` 已删除）：
##   Z001=1 … Z026=26，Z031=31 … Z044=44，Z1001BobsledSingle=1001，Z999ZombossDoctor=999。
##
## 编号段的来历（改字符串后**不再需要**分段，但配置表仍按这段组织）：
##   Z031–Z044 是「植物僵尸」（原版 ZomBotany，僵尸头顶插一棵植物），
##   配置表见 `src/entities/character/components/zombie_plant_component/zom_botany_config.gd`。
##
## ⚠️ 僵王博士**同时**在这里（`ZOMBOSS_DOCTOR`）和 `ZombieBossIds.DOCTOR` 里：
##   生成侧（关卡 `boss_type` / 僵王卡）用 `ZombieBossIds`，通用僵尸系统（遍历 / 计数 / 图鉴）
##   用这里的 id —— 它**不**在 `ZOMBIE_SPAWN_WEIGHTS` / `ZOMBIE_SPAWN_POWER` 里，不会被自然刷怪抽到。
##
## 新增僵尸：加常量 + 进 `ALL` + 进 `ZOMBIE_INFO` + 出怪表；**不需要**动 `LEGACY_INT_TO_ID`
## （那是给老存档用的历史值）。


## 空 id：没指定僵尸（如基类场景）。
const NULL := &""


#region 普通僵尸（Z001–Z026）
const NORM := &"norm"						## 普通僵尸
const FLAG := &"flag"						## 旗帜僵尸
const CONE := &"cone"						## 路障僵尸
const POLE_VAULTER := &"pole_vaulter"				## 撑杆跳僵尸
const BUCKET := &"bucket"					## 铁桶僵尸
const PAPER := &"paper"						## 报纸僵尸
const SCREEN_DOOR := &"screen_door"				## 铁网门僵尸
const FOOTBALL := &"football"					## 橄榄球僵尸
const JACKSON := &"jackson"					## 舞王僵尸
const DANCER := &"dancer"					## 伴舞僵尸
const DUCKYTUBE := &"duckytube"				## 鸭子救生圈僵尸
const SNORKLE := &"snorkle"					## 潜水僵尸
const ZAMBONI := &"zamboni"					## 冰车僵尸
const BOBSLED := &"bobsled"					## 雪橇僵尸小队
const DOLPHINRIDER := &"dolphinrider"				## 海豚骑士僵尸
const JACKBOX := &"jackbox"					## 小丑僵尸
const BALLOON := &"balloon"					## 气球僵尸
const DIGGER := &"digger"					## 矿工僵尸
const POGO := &"pogo"						## 蹦蹦僵尸
const YETI := &"yeti"						## 雪人僵尸
const BUNGI := &"bungi"						## 蹦极僵尸
const LADDER := &"ladder"					## 扶梯僵尸
const CATAPULT := &"catapult"					## 投石车僵尸
const GARGANTUAR := &"gargantuar"				## 巨人僵尸
const IMP := &"imp"						## 小鬼僵尸
const BUNGI_DROP := &"bungi_drop"				## 蹦极空投僵尸：蹦极闪电战专用，只用来空投僵尸，不进自然出怪池
#endregion


#region 植物僵尸（Z031–Z044，原版 ZomBotany）
const PEA_SHOOTER_ZOMBIE := &"pea_shooter_zombie"		## 豌豆僵尸
const WALL_NUT_ZOMBIE := &"wall_nut_zombie"			## 坚果僵尸（耐久 1100）
const SQUASH_ZOMBIE := &"squash_zombie"			## 窝瓜僵尸
const JALAPENO_ZOMBIE := &"jalapeno_zombie"			## 火爆辣椒僵尸
const GATLING_ZOMBIE := &"gatling_zombie"			## 机枪僵尸（一次 4 连发）
const SNOW_PEA_ZOMBIE := &"snow_pea_zombie"			## 寒冰射手僵尸
const TORCHWOOD_ZOMBIE := &"torchwood_zombie"			## 火炬僵尸（把玩家射来的豌豆点成火豌豆）
const MAGNET_SHROOM_ZOMBIE := &"magnet_shroom_zombie"		## 磁力菇僵尸
const PUMPKIN_ZOMBIE := &"pumpkin_zombie"			## 南瓜头僵尸（耐久 1100）
const CABBAGE_PULT_ZOMBIE := &"cabbage_pult_zombie"		## 卷心菜僵尸
const COB_CANNON_ZOMBIE := &"cob_cannon_zombie"		## 玉米加农炮僵尸
const MELON_PULT_ZOMBIE := &"melon_pult_zombie"		## 西瓜僵尸
const WINTER_MELON_ZOMBIE := &"winter_melon_zombie"		## 冰瓜僵尸
const TALL_NUT_ZOMBIE := &"tall_nut_zombie"			## 高坚果僵尸（耐久 2200，原版只出现在 ZomBotany 2）
#endregion


#region 特殊段
const BOBSLED_SINGLE := &"bobsled_single"			## 单个雪橇车僵尸（Z1001）
const ZOMBOSS_DOCTOR := &"zomboss_doctor"			## 僵王博士（Z999）
#endregion


## 全部内置僵尸 id（顺序与原枚举声明顺序一致）
const ALL: Array[StringName] = [
	NORM, FLAG, CONE, POLE_VAULTER, BUCKET, PAPER, SCREEN_DOOR, FOOTBALL, JACKSON, DANCER,
	DUCKYTUBE, SNORKLE, ZAMBONI, BOBSLED, DOLPHINRIDER, JACKBOX, BALLOON, DIGGER, POGO, YETI,
	BUNGI, LADDER, CATAPULT, GARGANTUAR, IMP, BUNGI_DROP,
	PEA_SHOOTER_ZOMBIE, WALL_NUT_ZOMBIE, SQUASH_ZOMBIE, JALAPENO_ZOMBIE, GATLING_ZOMBIE,
	SNOW_PEA_ZOMBIE, TORCHWOOD_ZOMBIE, MAGNET_SHROOM_ZOMBIE, PUMPKIN_ZOMBIE,
	CABBAGE_PULT_ZOMBIE, COB_CANNON_ZOMBIE, MELON_PULT_ZOMBIE, WINTER_MELON_ZOMBIE,
	TALL_NUT_ZOMBIE,
	BOBSLED_SINGLE, ZOMBOSS_DOCTOR,
]


## 老存档里的数字编号 → id（**只给读老存档用**，见 `save_service.gd`）
##
## ⚠️ 别当死代码删：玩家磁盘上的老存档还在靠它（完整理由见 `PlantIds.LEGACY_INT_TO_ID`
## 的注释）。僵尸这边的调用面已收窄到 `save_service` 的几条读档路径。
const LEGACY_INT_TO_ID: Dictionary[int, StringName] = {
	1: NORM, 2: FLAG, 3: CONE, 4: POLE_VAULTER, 5: BUCKET, 6: PAPER, 7: SCREEN_DOOR,
	8: FOOTBALL, 9: JACKSON, 10: DANCER, 11: DUCKYTUBE, 12: SNORKLE, 13: ZAMBONI, 14: BOBSLED,
	15: DOLPHINRIDER, 16: JACKBOX, 17: BALLOON, 18: DIGGER, 19: POGO, 20: YETI, 21: BUNGI,
	22: LADDER, 23: CATAPULT, 24: GARGANTUAR, 25: IMP, 26: BUNGI_DROP,
	31: PEA_SHOOTER_ZOMBIE, 32: WALL_NUT_ZOMBIE, 33: SQUASH_ZOMBIE, 34: JALAPENO_ZOMBIE,
	35: GATLING_ZOMBIE, 36: SNOW_PEA_ZOMBIE, 37: TORCHWOOD_ZOMBIE, 38: MAGNET_SHROOM_ZOMBIE,
	39: PUMPKIN_ZOMBIE, 40: CABBAGE_PULT_ZOMBIE, 41: COB_CANNON_ZOMBIE, 42: MELON_PULT_ZOMBIE,
	43: WINTER_MELON_ZOMBIE, 44: TALL_NUT_ZOMBIE,
	999: ZOMBOSS_DOCTOR, 1001: BOBSLED_SINGLE,
}


## 是不是一个已知的僵尸 id（空 id 不算；运行期热注册的僵尸不在 `ALL` 里，要另外判）
static func is_valid(zombie_id: StringName) -> bool:
	return zombie_id != &"" and zombie_id in ALL


## 老存档迁移：把一个可能是 int 也可能是 id 的值统一成 id（转不出来返回 `NULL`）
static func from_legacy(value: Variant) -> StringName:
	if typeof(value) == TYPE_STRING_NAME or typeof(value) == TYPE_STRING:
		## 同 `PlantIds.from_legacy()`：`StringName(value)` 是构造不出来 id 的，交 String 回去即可
		return str(value)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return LEGACY_INT_TO_ID.get(int(value), NULL)
	return NULL
