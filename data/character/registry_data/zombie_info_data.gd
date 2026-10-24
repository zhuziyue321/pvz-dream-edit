class_name ZombieInfoData
extends RefCounted

## 僵尸注册表数据表与出怪基础数据。
## 只放常量数据，查询入口见 CharacterRegistry.get_zombie_info()。

const ZOMBIE_INFO = {
	ZombieIds.NORM:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieNorm",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_norm.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.FLAG:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieFlag",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_flag.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.CONE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieCone",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 75,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_cone.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.POLE_VAULTER:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombiePoleVaulter",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 75,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pole_vaulter.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.BUCKET:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBucket",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bucket.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	ZombieIds.PAPER:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombiePaper",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_paper.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.SCREEN_DOOR:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieScreenDoor",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		## 我是僵尸模式价格（原版 100，见 I, Zombie 的 Zombies' sun costs）
		CharacterRegistry.ZombieInfoAttribute.SunCost: 100,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_screendoor.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.FOOTBALL:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieFootball",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes: preload("res://src/entities/character/zombie/zombie_football.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.JACKSON:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieJackson",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		## 我是僵尸模式价格（原版 350，比巨人还贵，见 I, Zombie 的 Zombies' sun costs）
		CharacterRegistry.ZombieInfoAttribute.SunCost: 350,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_jackson.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.DANCER:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieDancer",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_dancer.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.DUCKYTUBE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieDuckytube",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_duckytube.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.SNORKLE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieSnorkle",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 75,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_snorkle.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieIds.ZAMBONI:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieZamboni",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 250,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_zamboni.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.BOBSLED:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBobsled",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 200,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bobsled.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land,
		## 冰道是硬前提：没有冰的小队一落地就掉血，等于白出（旧写法是选行系统里按类型硬判）
		CharacterRegistry.ZombieInfoAttribute.ZombieCondition:preload("res://data/character/zombie_condition/zombie_bobsled_condition.tres")
	},
	ZombieIds.DOLPHINRIDER:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieDolphinrider",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 150,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_dolphinrider.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieIds.JACKBOX:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieJackbox",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 75,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_jackbox.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.BALLOON:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBallon",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		## 我是僵尸模式价格（原版 150，见 I, Zombie 的 Zombies' sun costs）
		CharacterRegistry.ZombieInfoAttribute.SunCost: 150,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_balloon.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.DIGGER:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieDigger",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_digger.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.POGO:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombiePogo",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pogo.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.YETI:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieYeti",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 100,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_yeti.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.BUNGI:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBungi",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bungi.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.LADDER:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieLadder",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 150,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_ladder.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.CATAPULT:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieCatapult",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 200,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_catapult.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.GARGANTUAR:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieGargantuar",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 300,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_gargantuar.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.IMP:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieImp",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_imp.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.BUNGI_DROP:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBungiDrop",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bungi_drop.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	## 植物僵尸（原版 ZomBotany，配置表见 zom_botany_config.gd）
	## SunCost 用的是「原版对战里这只僵尸的价格」，只用于「我是僵尸」模式，不影响自然出怪
	ZombieIds.PEA_SHOOTER_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombiePeaShooter",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 150,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pea_shooter.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.WALL_NUT_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieWallNut",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 100,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_wall_nut.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.SQUASH_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieSquash",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_squash.tscn"),
		## 只走陆地行：原版「除了窝瓜僵尸，其余植物僵尸都有鸭子圈版本」（PVZ Wiki ZomBotany 2），
		## 写成 Both 会让泳池关的水面行刷出一只没有鸭子圈却在水上走的窝瓜僵尸
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieIds.JALAPENO_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieJalapeno",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 200,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_jalapeno.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.GATLING_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieGatling",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 250,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_gatling.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.SNOW_PEA_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieSnowPea",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_snow_pea.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.TORCHWOOD_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieTorchwood",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_torchwood.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.MAGNET_SHROOM_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieMagnetShroom",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_magnet_shroom.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.PUMPKIN_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombiePumpkin",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 150,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pumpkin.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.CABBAGE_PULT_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieCabbagePult",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_cabbage_pult.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.COB_CANNON_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieCobCannon",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 500,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_cob_cannon.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.MELON_PULT_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieMelonPult",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 300,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_melon_pult.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.WINTER_MELON_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieWinterMelon",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 400,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_winter_melon.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieIds.TALL_NUT_ZOMBIE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieTallNut",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_tall_nut.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	## 单独雪橇僵尸
	ZombieIds.BOBSLED_SINGLE:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBobsledSingle",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bobsled_single.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},

	## 僵王博士：登记到僵尸表仅为让通用僵尸系统认它是僵尸，出场仍只由关卡 boss_type 驱动。
	## 它不在 ZOMBIE_SPAWN_POWER / ZOMBIE_SPAWN_WEIGHTS 里，因此不参与任何自然刷怪。
	ZombieIds.ZOMBOSS_DOCTOR:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZB001Doctor",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 10000,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie_boss/zombie_boss_doctor.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
}

## 每种僵尸消耗的出怪战力，供自然波次和僵王放置技能只读访问，无需复制。[br]
## 未列出的类型不能参与按战力预算生成；战力不包含生成后衍生出的其他僵尸。
const ZOMBIE_SPAWN_POWER: Dictionary[StringName, int] = {
	ZombieIds.NORM: 1,		# 普僵战力
	ZombieIds.FLAG: 1,		# 旗帜战力
	ZombieIds.CONE: 2,		# 路障战力
	ZombieIds.POLE_VAULTER: 2,	# 撑杆战力
	ZombieIds.BUCKET: 4,		# 铁桶战力

	ZombieIds.PAPER: 2,		# 读报战力
	ZombieIds.SCREEN_DOOR: 4,	# 铁门战力
	ZombieIds.FOOTBALL: 7,	# 橄榄球战力
	ZombieIds.JACKSON: 5,		# 舞王战力
	ZombieIds.DANCER: 1,		# 伴舞战力

	ZombieIds.SNORKLE: 3,		# 潜水
	ZombieIds.ZAMBONI: 7,		# 冰车
	ZombieIds.BOBSLED: 3,		# 滑雪四兄弟
	ZombieIds.DOLPHINRIDER: 3,# 海豚僵尸

	ZombieIds.JACKBOX: 3,		# 小丑
	ZombieIds.BALLOON: 2,		# 气球
	ZombieIds.DIGGER: 4,		# 矿工
	ZombieIds.POGO: 4,			# 跳跳
	ZombieIds.YETI: 4,			# 雪人

	ZombieIds.LADDER: 4,		# 扶梯
	ZombieIds.CATAPULT: 5,		# 投篮
	ZombieIds.GARGANTUAR: 10,	# 伽刚特尔
	ZombieIds.IMP: 1,			# 小鬼
}

## 首次登场的冒险关卡序号（**1 起算**，1 = 1-1、11 = 2-1、50 = 5-10）：原版
## `ZombieDefinition.mStartingLevel`，`Board::GetIntroducedZombieType()` 用它找「本关新登场的僵尸」，
## `Board::PickZombieWaves()` 再让这只僵尸**必定**出现在「中间波」与「最后一波」。[br]
## 数据本体同上（`../PvZ-Portable-main/src/Lawn/Zombie.cpp:80-113` 的 `gZombieDefs[]`）。[br]
## 取用按 `ZombieIds.ALL` 的顺序先到先得（与原版枚举序一致）：26 关同时有冰车 / 雪橇，取排在前面的冰车。
const ZOMBIE_STARTING_LEVEL: Dictionary[StringName, int] = {
	ZombieIds.NORM: 1,
	ZombieIds.FLAG: 1,
	ZombieIds.CONE: 3,			# 1-3
	ZombieIds.POLE_VAULTER: 6,	# 1-6
	ZombieIds.BUCKET: 8,		# 1-8
	ZombieIds.PAPER: 11,		# 2-1
	ZombieIds.SCREEN_DOOR: 13,	# 2-3
	ZombieIds.FOOTBALL: 16,		# 2-6
	ZombieIds.JACKSON: 18,		# 2-8（舞王，原版 ZOMBIE_DANCER）
	ZombieIds.DANCER: 18,		# 2-8（伴舞，原版 ZOMBIE_BACKUP_DANCER，不自然出怪）
	ZombieIds.DUCKYTUBE: 21,	# 3-1（原版 GetIntroducedZombieType 显式排除它）
	ZombieIds.SNORKLE: 23,		# 3-3
	ZombieIds.ZAMBONI: 26,		# 3-6
	ZombieIds.BOBSLED: 26,		# 3-6
	ZombieIds.DOLPHINRIDER: 28,	# 3-8
	ZombieIds.JACKBOX: 31,		# 4-1
	ZombieIds.BALLOON: 33,		# 4-3
	ZombieIds.DIGGER: 36,		# 4-6
	ZombieIds.POGO: 38,			# 4-8
	ZombieIds.YETI: 40,			# 4-10（原版只在「能放雪人」时认，本仓库雪人不进自然出怪池）
	ZombieIds.BUNGI: 41,		# 5-1
	ZombieIds.LADDER: 43,		# 5-3
	ZombieIds.CATAPULT: 46,		# 5-6
	ZombieIds.GARGANTUAR: 48,	# 5-8
	ZombieIds.IMP: 48,
}

## 首次允许出怪的波次（**1 起算**）：原版 `ZombieDefinition.mFirstAllowedWave`，
## `Board::PickZombieType()` 里 `theWaveIndex + 1 < mFirstAllowedWave` 的类型直接跳过随机池。[br]
## 数据本体：`../PvZ-Portable-main/src/Lawn/Zombie.cpp:80-113` 的 `gZombieDefs[]`
## （`../re-plants-vs-zombies-main` 同源，逐行一致）。未列出的类型（模组 / 运行期热注册）按 1 处理。[br]
## 植物僵尸（Z031+）不在这张表里：它们的首次允许波次由 `ZomBotanyConfig` 给。
const ZOMBIE_FIRST_ALLOWED_WAVE: Dictionary[StringName, int] = {
	ZombieIds.NORM: 1,
	ZombieIds.FLAG: 1,
	ZombieIds.CONE: 1,
	ZombieIds.POLE_VAULTER: 5,	# 1-6 登场后第 5 波起才进池
	ZombieIds.BUCKET: 1,
	ZombieIds.PAPER: 1,
	ZombieIds.SCREEN_DOOR: 5,
	ZombieIds.FOOTBALL: 5,
	ZombieIds.JACKSON: 5,		# 舞王
	ZombieIds.DANCER: 5,		# 伴舞（由舞王召唤，不自然出怪）
	ZombieIds.DUCKYTUBE: 5,
	ZombieIds.SNORKLE: 10,
	ZombieIds.ZAMBONI: 10,
	ZombieIds.BOBSLED: 10,
	ZombieIds.DOLPHINRIDER: 10,
	ZombieIds.JACKBOX: 10,
	ZombieIds.BALLOON: 10,
	ZombieIds.DIGGER: 10,
	ZombieIds.POGO: 10,
	ZombieIds.YETI: 1,
	ZombieIds.BUNGI: 10,
	ZombieIds.LADDER: 10,
	ZombieIds.CATAPULT: 10,
	ZombieIds.GARGANTUAR: 15,
	ZombieIds.IMP: 1,
}

## 僵尸初始出怪权重；各出怪系统复制后独立调整，不修改公共基础数据。[br]
## 未列出的类型不参与此权重池，旗帜与小鬼等特殊生成仍由各自逻辑处理。
const ZOMBIE_SPAWN_WEIGHTS: Dictionary[StringName, int] = {
	ZombieIds.NORM: 4000,			# 普僵权重
	ZombieIds.CONE: 4000,			# 路障权重
	ZombieIds.POLE_VAULTER: 2000,	# 撑杆权重
	ZombieIds.BUCKET: 3000,		# 铁桶权重

	ZombieIds.PAPER: 1000,		# 读报权重
	ZombieIds.SCREEN_DOOR: 3500,	# 铁门权重
	ZombieIds.FOOTBALL: 2000,		# 橄榄球权重
	ZombieIds.JACKSON: 1000,		# 舞王权重
	ZombieIds.DANCER: 4000,		# 伴舞权重

	ZombieIds.SNORKLE: 2000,		# 潜水
	ZombieIds.ZAMBONI: 2000,		# 冰车
	ZombieIds.BOBSLED: 2000,		# 滑雪四兄弟
	ZombieIds.DOLPHINRIDER: 1500,	# 海豚僵尸

	ZombieIds.JACKBOX: 1000,		# 小丑
	ZombieIds.BALLOON: 2000,		# 气球
	ZombieIds.DIGGER: 1000,		# 矿工
	ZombieIds.POGO: 1000,			# 跳跳
	ZombieIds.YETI: 1,			# 雪人

	ZombieIds.LADDER: 1000,		# 扶梯
	ZombieIds.CATAPULT: 1500,	# 投篮
	ZombieIds.GARGANTUAR: 1500,	# 伽刚特尔
}
