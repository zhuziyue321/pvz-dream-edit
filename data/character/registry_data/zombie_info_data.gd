class_name ZombieInfoData
extends RefCounted

## 僵尸注册表数据表与出怪基础数据。
## 只放常量数据，查询入口见 CharacterRegistry.get_zombie_info()。

const ZOMBIE_INFO = {
	CharacterRegistry.ZombieType.Z001Norm:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieNorm",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_norm.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z002Flag:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieFlag",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_flag.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z003Cone:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieCone",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 75,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_cone.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z004PoleVaulter:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombiePoleVaulter",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 75,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pole_vaulter.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z005Bucket:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBucket",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bucket.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	CharacterRegistry.ZombieType.Z006Paper:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombiePaper",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_paper.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z007ScreenDoor:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieScreenDoor",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		## 我是僵尸模式价格（原版 100，见 I, Zombie 的 Zombies' sun costs）
		CharacterRegistry.ZombieInfoAttribute.SunCost: 100,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_screendoor.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z008Football:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieFootball",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes: preload("res://src/entities/character/zombie/zombie_football.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z009Jackson:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieJackson",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		## 我是僵尸模式价格（原版 350，比巨人还贵，见 I, Zombie 的 Zombies' sun costs）
		CharacterRegistry.ZombieInfoAttribute.SunCost: 350,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_jackson.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z010Dancer:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieDancer",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_dancer.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z011Duckytube:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieDuckytube",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_duckytube.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z012Snorkle:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieSnorkle",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 75,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_snorkle.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	CharacterRegistry.ZombieType.Z013Zamboni:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieZamboni",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 250,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_zamboni.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z014Bobsled:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBobsled",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 200,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bobsled.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z015Dolphinrider:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieDolphinrider",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 150,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_dolphinrider.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	CharacterRegistry.ZombieType.Z016Jackbox:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieJackbox",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 75,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_jackbox.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z017Balloon:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBallon",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		## 我是僵尸模式价格（原版 150，见 I, Zombie 的 Zombies' sun costs）
		CharacterRegistry.ZombieInfoAttribute.SunCost: 150,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_balloon.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z018Digger:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieDigger",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_digger.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z019Pogo:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombiePogo",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pogo.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z020Yeti:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieYeti",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 100,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_yeti.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z021Bungi:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBungi",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bungi.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z022Ladder:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieLadder",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 150,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_ladder.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z023Catapult:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieCatapult",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 200,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_catapult.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z024Gargantuar:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieGargantuar",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 300,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_gargantuar.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z025Imp:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieImp",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_imp.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z026BungiDrop:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBungiDrop",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bungi_drop.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	## 植物僵尸（原版 ZomBotany，配置表见 zom_botany_config.gd）
	## SunCost 用的是「原版对战里这只僵尸的价格」，只用于「我是僵尸」模式，不影响自然出怪
	CharacterRegistry.ZombieType.Z031PeaShooterZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombiePeaShooter",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 150,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pea_shooter.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z032WallNutZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieWallNut",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 100,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_wall_nut.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z033SquashZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieSquash",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_squash.tscn"),
		## 只走陆地行：原版「除了窝瓜僵尸，其余植物僵尸都有鸭子圈版本」（PVZ Wiki ZomBotany 2），
		## 写成 Both 会让泳池关的水面行刷出一只没有鸭子圈却在水上走的窝瓜僵尸
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	CharacterRegistry.ZombieType.Z034JalapenoZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieJalapeno",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 200,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_jalapeno.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z035GatlingZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieGatling",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 250,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_gatling.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z036SnowPeaZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieSnowPea",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_snow_pea.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z037TorchwoodZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieTorchwood",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_torchwood.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z038MagnetShroomZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieMagnetShroom",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 125,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_magnet_shroom.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z039PumpkinZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombiePumpkin",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 150,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pumpkin.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z040CabbagePultZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieCabbagePult",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_cabbage_pult.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z041CobCannonZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieCobCannon",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 500,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_cob_cannon.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z042MelonPultZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieMelonPult",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 300,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_melon_pult.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z043WinterMelonZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieWinterMelon",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 400,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_winter_melon.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	CharacterRegistry.ZombieType.Z044TallNutZombie:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieTallNut",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 175,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_tall_nut.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	## 单独雪橇僵尸
	CharacterRegistry.ZombieType.Z1001BobsledSingle:{
		CharacterRegistry.ZombieInfoAttribute.ZombieName: "ZombieBobsledSingle",
		CharacterRegistry.ZombieInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.ZombieInfoAttribute.SunCost: 50,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bobsled_single.tscn"),
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
}

## 每种僵尸消耗的出怪战力，供自然波次和僵王放置技能只读访问，无需复制。[br]
## 未列出的类型不能参与按战力预算生成；战力不包含生成后衍生出的其他僵尸。
const ZOMBIE_SPAWN_POWER: Dictionary[CharacterRegistry.ZombieType, int] = {
	CharacterRegistry.ZombieType.Z001Norm: 1,		# 普僵战力
	CharacterRegistry.ZombieType.Z002Flag: 1,		# 旗帜战力
	CharacterRegistry.ZombieType.Z003Cone: 2,		# 路障战力
	CharacterRegistry.ZombieType.Z004PoleVaulter: 2,	# 撑杆战力
	CharacterRegistry.ZombieType.Z005Bucket: 4,		# 铁桶战力

	CharacterRegistry.ZombieType.Z006Paper: 2,		# 读报战力
	CharacterRegistry.ZombieType.Z007ScreenDoor: 4,	# 铁门战力
	CharacterRegistry.ZombieType.Z008Football: 7,	# 橄榄球战力
	CharacterRegistry.ZombieType.Z009Jackson: 5,		# 舞王战力
	CharacterRegistry.ZombieType.Z010Dancer: 1,		# 伴舞战力

	CharacterRegistry.ZombieType.Z012Snorkle: 3,		# 潜水
	CharacterRegistry.ZombieType.Z013Zamboni: 7,		# 冰车
	CharacterRegistry.ZombieType.Z014Bobsled: 3,		# 滑雪四兄弟
	CharacterRegistry.ZombieType.Z015Dolphinrider: 3,# 海豚僵尸

	CharacterRegistry.ZombieType.Z016Jackbox: 3,		# 小丑
	CharacterRegistry.ZombieType.Z017Balloon: 2,		# 气球
	CharacterRegistry.ZombieType.Z018Digger: 4,		# 矿工
	CharacterRegistry.ZombieType.Z019Pogo: 4,			# 跳跳
	CharacterRegistry.ZombieType.Z020Yeti: 4,			# 雪人

	CharacterRegistry.ZombieType.Z022Ladder: 4,		# 扶梯
	CharacterRegistry.ZombieType.Z023Catapult: 5,		# 投篮
	CharacterRegistry.ZombieType.Z024Gargantuar: 10,	# 伽刚特尔
	CharacterRegistry.ZombieType.Z025Imp: 1,			# 小鬼
}

## 僵尸初始出怪权重；各出怪系统复制后独立调整，不修改公共基础数据。[br]
## 未列出的类型不参与此权重池，旗帜与小鬼等特殊生成仍由各自逻辑处理。
const ZOMBIE_SPAWN_WEIGHTS: Dictionary[CharacterRegistry.ZombieType, int] = {
	CharacterRegistry.ZombieType.Z001Norm: 4000,			# 普僵权重
	CharacterRegistry.ZombieType.Z003Cone: 4000,			# 路障权重
	CharacterRegistry.ZombieType.Z004PoleVaulter: 2000,	# 撑杆权重
	CharacterRegistry.ZombieType.Z005Bucket: 3000,		# 铁桶权重

	CharacterRegistry.ZombieType.Z006Paper: 1000,		# 读报权重
	CharacterRegistry.ZombieType.Z007ScreenDoor: 3500,	# 铁门权重
	CharacterRegistry.ZombieType.Z008Football: 2000,		# 橄榄球权重
	CharacterRegistry.ZombieType.Z009Jackson: 1000,		# 舞王权重
	CharacterRegistry.ZombieType.Z010Dancer: 4000,		# 伴舞权重

	CharacterRegistry.ZombieType.Z012Snorkle: 2000,		# 潜水
	CharacterRegistry.ZombieType.Z013Zamboni: 2000,		# 冰车
	CharacterRegistry.ZombieType.Z014Bobsled: 2000,		# 滑雪四兄弟
	CharacterRegistry.ZombieType.Z015Dolphinrider: 1500,	# 海豚僵尸

	CharacterRegistry.ZombieType.Z016Jackbox: 1000,		# 小丑
	CharacterRegistry.ZombieType.Z017Balloon: 2000,		# 气球
	CharacterRegistry.ZombieType.Z018Digger: 1000,		# 矿工
	CharacterRegistry.ZombieType.Z019Pogo: 1000,			# 跳跳
	CharacterRegistry.ZombieType.Z020Yeti: 1,			# 雪人

	CharacterRegistry.ZombieType.Z022Ladder: 1000,		# 扶梯
	CharacterRegistry.ZombieType.Z023Catapult: 1500,	# 投篮
	CharacterRegistry.ZombieType.Z024Gargantuar: 1500,	# 伽刚特尔
}
