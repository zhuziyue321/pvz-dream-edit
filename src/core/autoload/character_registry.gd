extends Node
class_name CharacterRegistry


# 定义枚举
enum CharacterType {Null, Plant, Zombie, ZombieBoss}

#region 植物
## 植物信息属性
enum PlantInfoAttribute{
	PlantName,
	CoolTime,		## 植物种植冷却时间
	SunCost,		## 阳光消耗
	PlantScenes,	## 植物场景预加载
	PlantConditionResource,	## 植物种植条件资源预加载
}

## 植物类型
enum PlantType {
	Null = 0,
	P001PeaShooterSingle = 1,
	P002SunFlower,
	P003CherryBomb,
	P004WallNut,
	P005PotatoMine,
	P006SnowPea,
	P007Chomper,
	P008PeaShooterDouble,

	P009PuffShroom,
	P010SunShroom,
	P011FumeShroom,
	P012GraveBuster,
	P013HypnoShroom,
	P014ScaredyShroom,
	P015IceShroom,
	P016DoomShroom,

	P017LilyPad,
	P018Squash,
	P019ThreePeater,
	P020TangleKelp,
	P021Jalapeno,
	P022Caltrop,
	P023TorchWood,
	P024TallNut,

	P025SeaShroom,
	P026Plantern,
	P027Cactus,
	P028Blover,
	P029SplitPea,
	P030StarFruit,
	P031Pumpkin,
	P032MagnetShroom,

	P033CabbagePult,
	P034FlowerPot,
	P035CornPult,
	P036CoffeeBean,
	P037Garlic,
	P038UmbrellaLeaf,
	P039MariGold,
	P040MelonPult,

	P041GatlingPea,
	P042TwinSunFlower,
	P043GloomShroom,
	P044Cattail,
	P045WinterMelon,
	P046GoldMagnet,
	P047SpikeRock,
	P048CobCannon,

	P049PeaShooterDoubleReverse,

	## 模仿者
	P999Imitater = 999,
	## 发芽
	P1000Sprout = 1000,
	## 保龄球
	P1001WallNutBowling = 1001,
	P1002WallNutBowlingBomb,
	P1003WallNutBowlingBig,
	}


## 植物在格子中的位置
enum PlacePlantInCell{
	Norm,	## 普通位置
	Shell,	## 保护壳位置
	Down,	## 花盆（睡莲）位置
	Float,	## 漂浮位置
	Imitater,## 模仿者位置
}

#endregion

#region 僵尸
## 僵尸类型
enum ZombieType {
	Null = 0,

	Z001Norm = 1,
	Z002Flag,
	Z003Cone,
	Z004PoleVaulter,
	Z005Bucket,

	Z006Paper,
	Z007ScreenDoor,
	Z008Football,
	Z009Jackson,
	Z010Dancer,

	Z011Duckytube,
	Z012Snorkle,
	Z013Zamboni,
	Z014Bobsled,
	Z015Dolphinrider,

	Z016Jackbox,
	Z017Balloon,
	Z018Digger,
	Z019Pogo,
	Z020Yeti,

	Z021Bungi,
	Z022Ladder,
	Z023Catapult,
	Z024Gargantuar,
	Z025Imp,
	Z026BungiDrop,	## 蹦极空投僵尸：蹦极闪电战专用，只用来空投僵尸，不进自然出怪池

	## 植物僵尸（原版 ZomBotany）：僵尸头顶插着一棵植物，耐久与能力都是那棵植物的
	## 编号段 Z031–Z044 由「植物僵尸」占用，配置表见 src/entities/character/components/zombie_plant_component/zom_botany_config.gd
	Z031PeaShooterZombie = 31,	## 豌豆僵尸：射豌豆
	Z032WallNutZombie,			## 坚果僵尸：头顶坚果（耐久 1100）
	Z033SquashZombie,			## 窝瓜僵尸：压扁碰到的植物后消失
	Z034JalapenoZombie,			## 火爆辣椒僵尸：烧掉整行后消失
	Z035GatlingZombie,			## 机枪僵尸：一次 4 连发
	Z036SnowPeaZombie,			## 寒冰射手僵尸：射减速豌豆
	Z037TorchwoodZombie,		## 火炬僵尸：把玩家射来的豌豆点成火豌豆
	Z038MagnetShroomZombie,		## 磁力菇僵尸：定期吸走玩家的磁力菇
	Z039PumpkinZombie,			## 南瓜头僵尸：头顶南瓜（耐久 1100）
	Z040CabbagePultZombie,		## 卷心菜僵尸：投卷心菜
	Z041CobCannonZombie,		## 玉米加农炮僵尸：发射玉米炮
	Z042MelonPultZombie,		## 西瓜僵尸：投西瓜
	Z043WinterMelonZombie,		## 冰瓜僵尸：投冰瓜
	Z044TallNutZombie,			## 高坚果僵尸：头顶高坚果（耐久 2200，原版只出现在 ZomBotany 2）

	Z1001BobsledSingle=1001,	## 单个雪橇车僵尸
	}

## 僵尸行类型
enum ZombieRowType{
	Land,
	Pool,
	Both,
	None,	## 该行不自然出怪（原版没铺草皮的行，行数仍在但什么都不出）
}

## 僵尸信息属性
enum ZombieInfoAttribute{
	ZombieName,
	CoolTime,		## 僵尸冷却时间
	SunCost,		## 阳光消耗
	ZombieScenes,	## 植物场景预加载
	ZombieRowType,	## 僵尸行类型
}


#endregion


## 紫卡植物种植前置植物
@export var AllPrePlantPurple:Dictionary[PlantType, PlantType]= {
	PlantType.P041GatlingPea:PlantType.P008PeaShooterDouble,
	PlantType.P042TwinSunFlower:PlantType.P002SunFlower,
	PlantType.P043GloomShroom:PlantType.P011FumeShroom,
	PlantType.P044Cattail:PlantType.P017LilyPad,
	PlantType.P045WinterMelon:PlantType.P040MelonPult,
	PlantType.P046GoldMagnet:PlantType.P032MagnetShroom,
	PlantType.P047SpikeRock:PlantType.P022Caltrop,
	PlantType.P048CobCannon:PlantType.P035CornPult,
}

const PlantInfo = {
	PlantType.P001PeaShooterSingle: {
		PlantInfoAttribute.PlantName: "PeaShooterSingle",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource:preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pea_shooter_single.tscn")
		},
	PlantType.P002SunFlower: {
		PlantInfoAttribute.PlantName: "SunFlower",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource:preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_sun_flower.tscn")
		},
	PlantType.P003CherryBomb: {
		PlantInfoAttribute.PlantName: "CherryBomb",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cherry_bomb.tscn")
		},
	PlantType.P004WallNut: {
		PlantInfoAttribute.PlantName: "WallNut",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_wall_nut.tscn")
		},
	PlantType.P005PotatoMine: {
		PlantInfoAttribute.PlantName: "PotatoMine",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/potato_mine.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_potato_mine.tscn")
		},
	PlantType.P006SnowPea: {
		PlantInfoAttribute.PlantName: "SnowPea",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_snow_pea.tscn")
		},
	PlantType.P007Chomper: {
		PlantInfoAttribute.PlantName: "Chomper",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_chomper.tscn")
		},
	PlantType.P008PeaShooterDouble: {
		PlantInfoAttribute.PlantName: "PeaShooterDouble",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pea_shooter_double.tscn")
		},
		#
	PlantType.P009PuffShroom: {
		PlantInfoAttribute.PlantName: "PuffShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_puff.tscn")
		},
	PlantType.P010SunShroom: {
		PlantInfoAttribute.PlantName: "SunShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_sun_shroom.tscn")
		},
	PlantType.P011FumeShroom: {
		PlantInfoAttribute.PlantName: "FumeShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_fume_shroom.tscn")
		},
	PlantType.P012GraveBuster: {
		PlantInfoAttribute.PlantName: "GraveBuster",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/grave_buster.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_grave_buster.tscn")
		},
	PlantType.P013HypnoShroom: {
		PlantInfoAttribute.PlantName: "HypnoShroom",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_hypno_shroom.tscn")
		},
	PlantType.P014ScaredyShroom: {
		PlantInfoAttribute.PlantName: "ScaredyShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_scaredy_shroom.tscn")
		},
	PlantType.P015IceShroom: {
		PlantInfoAttribute.PlantName: "IceShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_ice_shroom.tscn")
		},
	PlantType.P016DoomShroom: {
		PlantInfoAttribute.PlantName: "DoomShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_doom_shroom.tscn")
		},
	PlantType.P017LilyPad: {
		PlantInfoAttribute.PlantName: "LilyPad",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/lily_pad.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_lily_pad.tscn")
		},
	PlantType.P018Squash: {
		PlantInfoAttribute.PlantName: "Squash",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_squash.tscn")
		},
	PlantType.P019ThreePeater: {
		PlantInfoAttribute.PlantName: "ThreePeater",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 325,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_three_peater.tscn")
		},
	PlantType.P020TangleKelp: {
		PlantInfoAttribute.PlantName: "TangleKelp",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/tanglekelp.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_tanglekelp.tscn")
		},
	PlantType.P021Jalapeno: {
		PlantInfoAttribute.PlantName: "Jalapeno",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_jalapeno.tscn")
		},
	PlantType.P022Caltrop: {
		PlantInfoAttribute.PlantName: "Caltrop",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/caltrop.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_caltrop.tscn")
		},
	PlantType.P023TorchWood: {
		PlantInfoAttribute.PlantName: "TorchWood",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_torch_wood.tscn")
		},
	PlantType.P024TallNut: {
		PlantInfoAttribute.PlantName: "TallNut",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 175,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_tall_nut.tscn")
		},

	PlantType.P025SeaShroom: {
		PlantInfoAttribute.PlantName: "SeaShroom",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/tanglekelp.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_sea_shroom.tscn")
		},
	PlantType.P026Plantern: {
		PlantInfoAttribute.PlantName: "Plantern",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_plantern.tscn")
		},
	PlantType.P027Cactus: {
		PlantInfoAttribute.PlantName: "Cactus",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cactus.tscn")
		},
	PlantType.P028Blover: {
		PlantInfoAttribute.PlantName: "Blover",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_blover.tscn")
		},
	PlantType.P029SplitPea: {
		PlantInfoAttribute.PlantName: "SplitPea",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_split_pea.tscn")
		},
	PlantType.P030StarFruit: {
		PlantInfoAttribute.PlantName: "StarFruit",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_star_fruit.tscn")
		},
	PlantType.P031Pumpkin: {
		PlantInfoAttribute.PlantName: "Pumpkin",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/pumpkin.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pumpkin.tscn")
		},
	PlantType.P032MagnetShroom: {
		PlantInfoAttribute.PlantName: "MagnetShroom",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_magnet_shroom.tscn")
		},

	PlantType.P033CabbagePult: {
		PlantInfoAttribute.PlantName: "CabbagePult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cabbage_pult.tscn")
		},
	PlantType.P034FlowerPot: {
		PlantInfoAttribute.PlantName: "FlowerPot",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 25,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/flower_pot.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_flower_pot.tscn")
		},
	PlantType.P035CornPult: {
		PlantInfoAttribute.PlantName: "CornPult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_corn_pult.tscn")
		},
	PlantType.P036CoffeeBean: {
		PlantInfoAttribute.PlantName: "CoffeeBean",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 75,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/coffee_bean.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_coffee_bean.tscn")
		},
	PlantType.P037Garlic: {
		PlantInfoAttribute.PlantName: "Garlic",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_garlic.tscn")
		},
	PlantType.P038UmbrellaLeaf: {
		PlantInfoAttribute.PlantName: "UmbrellaLeaf",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 100,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_umbrella_leaf.tscn")
		},
	PlantType.P039MariGold: {
		PlantInfoAttribute.PlantName: "MariGold",
		PlantInfoAttribute.CoolTime: 30.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_mari_gold.tscn")
		},
	PlantType.P040MelonPult: {
		PlantInfoAttribute.PlantName: "MelonPult",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 300,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_melon_pult.tscn")
		},

	PlantType.P041GatlingPea: {
		PlantInfoAttribute.PlantName: "GatlingPea",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 250,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_gatling_pea.tscn")
		},

	PlantType.P042TwinSunFlower: {
		PlantInfoAttribute.PlantName: "TwinSunFlower",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_twin_sun_flower.tscn")
		},

	PlantType.P043GloomShroom: {
		PlantInfoAttribute.PlantName: "GloomShroom",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 150,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_gloom_shroom.tscn")
		},

	PlantType.P044Cattail: {
		PlantInfoAttribute.PlantName: "Cattail",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 225,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cattail.tscn")
		},

	PlantType.P045WinterMelon: {
		PlantInfoAttribute.PlantName: "WinterMelon",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_winter_melon.tscn")
		},

	PlantType.P046GoldMagnet: {
		PlantInfoAttribute.PlantName: "GoldMagnet",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_gold_magnet.tscn")
		},

	PlantType.P047SpikeRock: {
		PlantInfoAttribute.PlantName: "SpikeRock",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 125,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_spike_rock.tscn")
		},

	PlantType.P048CobCannon: {
		PlantInfoAttribute.PlantName: "CobCannon",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 500,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/cob_cannon.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cob_cannon.tscn")
		},

	PlantType.P049PeaShooterDoubleReverse: {
		PlantInfoAttribute.PlantName: "PeaShooterDoubleReverse",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 200,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pea_shooter_double_reverse.tscn")
		},

	## 模仿者
	PlantType.P999Imitater:{
		PlantInfoAttribute.PlantName: "Imitater",
		PlantInfoAttribute.CoolTime: 50.0,
		PlantInfoAttribute.SunCost: 0,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/imitater.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_imitater.tscn")
		},


	## 发芽
	PlantType.P1000Sprout:{
		PlantInfoAttribute.PlantName: "Sprout",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_sprout.tscn")
		},

	## 保龄球
	PlantType.P1001WallNutBowling: {
		PlantInfoAttribute.PlantName: "WallNutBowling",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_wall_nut_bowling.tscn")
		},
	PlantType.P1002WallNutBowlingBomb: {
		PlantInfoAttribute.PlantName: "WallNutBowlingBomb",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_wall_nut_bowling_bomb.tscn")
		},
	PlantType.P1003WallNutBowlingBig: {
		PlantInfoAttribute.PlantName: "WallNutBowlingBig",
		PlantInfoAttribute.CoolTime: 7.5,
		PlantInfoAttribute.SunCost: 50,
		PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_wall_nut_bowling_big.tscn")
		},
}


## 获取植物属性方法
func get_plant_info(plant_type:PlantType, info_attribute:PlantInfoAttribute):
	if plant_type == PlantType.Null:
		Log.debug("warning:获取空植物信息")
		return null
	var curr_plant_info = PlantInfo[plant_type]
	return curr_plant_info[info_attribute]

#endregion

#region 僵尸
## 僵尸信息
const ZombieInfo = {
	ZombieType.Z001Norm:{
		ZombieInfoAttribute.ZombieName: "ZombieNorm",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_norm.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z002Flag:{
		ZombieInfoAttribute.ZombieName: "ZombieFlag",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_flag.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z003Cone:{
		ZombieInfoAttribute.ZombieName: "ZombieCone",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_cone.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z004PoleVaulter:{
		ZombieInfoAttribute.ZombieName: "ZombiePoleVaulter",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pole_vaulter.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z005Bucket:{
		ZombieInfoAttribute.ZombieName: "ZombieBucket",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bucket.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	ZombieType.Z006Paper:{
		ZombieInfoAttribute.ZombieName: "ZombiePaper",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_paper.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z007ScreenDoor:{
		ZombieInfoAttribute.ZombieName: "ZombieScreenDoor",
		ZombieInfoAttribute.CoolTime: 0.0,
		## 我是僵尸模式价格（原版 100，见 I, Zombie 的 Zombies' sun costs）
		ZombieInfoAttribute.SunCost: 100,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_screendoor.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z008Football:{
		ZombieInfoAttribute.ZombieName: "ZombieFootball",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 175,
		ZombieInfoAttribute.ZombieScenes: preload("res://src/entities/character/zombie/zombie_football.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z009Jackson:{
		ZombieInfoAttribute.ZombieName: "ZombieJackson",
		ZombieInfoAttribute.CoolTime: 0.0,
		## 我是僵尸模式价格（原版 350，比巨人还贵，见 I, Zombie 的 Zombies' sun costs）
		ZombieInfoAttribute.SunCost: 350,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_jackson.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z010Dancer:{
		ZombieInfoAttribute.ZombieName: "ZombieDancer",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_dancer.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z011Duckytube:{
		ZombieInfoAttribute.ZombieName: "ZombieDuckytube",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_duckytube.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z012Snorkle:{
		ZombieInfoAttribute.ZombieName: "ZombieSnorkle",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_snorkle.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieType.Z013Zamboni:{
		ZombieInfoAttribute.ZombieName: "ZombieZamboni",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 250,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_zamboni.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z014Bobsled:{
		ZombieInfoAttribute.ZombieName: "ZombieBobsled",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 200,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bobsled.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z015Dolphinrider:{
		ZombieInfoAttribute.ZombieName: "ZombieDolphinrider",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_dolphinrider.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Pool
	},
	ZombieType.Z016Jackbox:{
		ZombieInfoAttribute.ZombieName: "ZombieJackbox",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 75,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_jackbox.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z017Balloon:{
		ZombieInfoAttribute.ZombieName: "ZombieBallon",
		ZombieInfoAttribute.CoolTime: 0.0,
		## 我是僵尸模式价格（原版 150，见 I, Zombie 的 Zombies' sun costs）
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_balloon.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z018Digger:{
		ZombieInfoAttribute.ZombieName: "ZombieDigger",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_digger.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z019Pogo:{
		ZombieInfoAttribute.ZombieName: "ZombiePogo",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pogo.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z020Yeti:{
		ZombieInfoAttribute.ZombieName: "ZombieYeti",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 100,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_yeti.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z021Bungi:{
		ZombieInfoAttribute.ZombieName: "ZombieBungi",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bungi.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z022Ladder:{
		ZombieInfoAttribute.ZombieName: "ZombieLadder",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_ladder.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z023Catapult:{
		ZombieInfoAttribute.ZombieName: "ZombieCatapult",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 200,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_catapult.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z024Gargantuar:{
		ZombieInfoAttribute.ZombieName: "ZombieGargantuar",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_gargantuar.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z025Imp:{
		ZombieInfoAttribute.ZombieName: "ZombieImp",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_imp.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z026BungiDrop:{
		ZombieInfoAttribute.ZombieName: "ZombieBungiDrop",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bungi_drop.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	## 植物僵尸（原版 ZomBotany，配置表见 zom_botany_config.gd）
	## SunCost 用的是「原版对战里这只僵尸的价格」，只用于「我是僵尸」模式，不影响自然出怪
	ZombieType.Z031PeaShooterZombie:{
		ZombieInfoAttribute.ZombieName: "ZombiePeaShooter",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pea_shooter.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z032WallNutZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieWallNut",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 100,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_wall_nut.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z033SquashZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieSquash",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 175,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_squash.tscn"),
		## 只走陆地行：原版「除了窝瓜僵尸，其余植物僵尸都有鸭子圈版本」（PVZ Wiki ZomBotany 2），
		## 写成 Both 会让泳池关的水面行刷出一只没有鸭子圈却在水上走的窝瓜僵尸
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
	ZombieType.Z034JalapenoZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieJalapeno",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 200,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_jalapeno.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z035GatlingZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieGatling",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 250,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_gatling.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z036SnowPeaZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieSnowPea",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 175,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_snow_pea.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z037TorchwoodZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieTorchwood",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 175,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_torchwood.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z038MagnetShroomZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieMagnetShroom",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 125,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_magnet_shroom.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z039PumpkinZombie:{
		ZombieInfoAttribute.ZombieName: "ZombiePumpkin",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 150,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_pumpkin.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z040CabbagePultZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieCabbagePult",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 175,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_cabbage_pult.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z041CobCannonZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieCobCannon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 500,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_cob_cannon.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z042MelonPultZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieMelonPult",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 300,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_melon_pult.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z043WinterMelonZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieWinterMelon",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 400,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_winter_melon.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},
	ZombieType.Z044TallNutZombie:{
		ZombieInfoAttribute.ZombieName: "ZombieTallNut",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 175,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_tall_nut.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Both
	},

	## 单独雪橇僵尸
	ZombieType.Z1001BobsledSingle:{
		ZombieInfoAttribute.ZombieName: "ZombieBobsledSingle",
		ZombieInfoAttribute.CoolTime: 0.0,
		ZombieInfoAttribute.SunCost: 50,
		ZombieInfoAttribute.ZombieScenes:preload("res://src/entities/character/zombie/zombie_bobsled_single.tscn"),
		ZombieInfoAttribute.ZombieRowType:CharacterRegistry.ZombieRowType.Land
	},
}

## 每种僵尸消耗的出怪战力，供自然波次和僵王放置技能只读访问，无需复制。[br]
## 未列出的类型不能参与按战力预算生成；战力不包含生成后衍生出的其他僵尸。
const ZombieSpawnPower: Dictionary[ZombieType, int] = {
	ZombieType.Z001Norm: 1,		# 普僵战力
	ZombieType.Z002Flag: 1,		# 旗帜战力
	ZombieType.Z003Cone: 2,		# 路障战力
	ZombieType.Z004PoleVaulter: 2,	# 撑杆战力
	ZombieType.Z005Bucket: 4,		# 铁桶战力

	ZombieType.Z006Paper: 2,		# 读报战力
	ZombieType.Z007ScreenDoor: 4,	# 铁门战力
	ZombieType.Z008Football: 7,	# 橄榄球战力
	ZombieType.Z009Jackson: 5,		# 舞王战力
	ZombieType.Z010Dancer: 1,		# 伴舞战力

	ZombieType.Z012Snorkle: 3,		# 潜水
	ZombieType.Z013Zamboni: 7,		# 冰车
	ZombieType.Z014Bobsled: 3,		# 滑雪四兄弟
	ZombieType.Z015Dolphinrider: 3,# 海豚僵尸

	ZombieType.Z016Jackbox: 3,		# 小丑
	ZombieType.Z017Balloon: 2,		# 气球
	ZombieType.Z018Digger: 4,		# 矿工
	ZombieType.Z019Pogo: 4,			# 跳跳
	ZombieType.Z020Yeti: 4,			# 雪人

	ZombieType.Z022Ladder: 4,		# 扶梯
	ZombieType.Z023Catapult: 5,		# 投篮
	ZombieType.Z024Gargantuar: 10,	# 伽刚特尔
	ZombieType.Z025Imp: 1,			# 小鬼
}

## 僵尸初始出怪权重；各出怪系统复制后独立调整，不修改公共基础数据。[br]
## 未列出的类型不参与此权重池，旗帜与小鬼等特殊生成仍由各自逻辑处理。
const ZombieSpawnWeights: Dictionary[ZombieType, int] = {
	ZombieType.Z001Norm: 4000,			# 普僵权重
	ZombieType.Z003Cone: 4000,			# 路障权重
	ZombieType.Z004PoleVaulter: 2000,	# 撑杆权重
	ZombieType.Z005Bucket: 3000,		# 铁桶权重

	ZombieType.Z006Paper: 1000,		# 读报权重
	ZombieType.Z007ScreenDoor: 3500,	# 铁门权重
	ZombieType.Z008Football: 2000,		# 橄榄球权重
	ZombieType.Z009Jackson: 1000,		# 舞王权重
	ZombieType.Z010Dancer: 4000,		# 伴舞权重

	ZombieType.Z012Snorkle: 2000,		# 潜水
	ZombieType.Z013Zamboni: 2000,		# 冰车
	ZombieType.Z014Bobsled: 2000,		# 滑雪四兄弟
	ZombieType.Z015Dolphinrider: 1500,	# 海豚僵尸

	ZombieType.Z016Jackbox: 1000,		# 小丑
	ZombieType.Z017Balloon: 2000,		# 气球
	ZombieType.Z018Digger: 1000,		# 矿工
	ZombieType.Z019Pogo: 1000,			# 跳跳
	ZombieType.Z020Yeti: 1,			# 雪人

	ZombieType.Z022Ladder: 1000,		# 扶梯
	ZombieType.Z023Catapult: 1500,	# 投篮
	ZombieType.Z024Gargantuar: 1500,	# 伽刚特尔
}


## 获取僵尸属性方法
func get_zombie_info(zombie_type:ZombieType, info_attribute:ZombieInfoAttribute):
	if zombie_type == 0:
		Log.debug("warning: 获取空僵尸信息")
		return null
	var curr_zombie_info = ZombieInfo[zombie_type]
	return curr_zombie_info[info_attribute]

#endregion

#region 僵王信息

#region 僵王
## 僵王使用独立类型，不参与普通僵尸的自然刷新列表；新增类型保持已有编号不变。
enum ZombieBossType {
	Null = 0,
	ZB001Doctor = 1,
}

## 注册表只保存公共定义，血量和死亡状态由每局生成的僵王实例维护。
enum ZombieBossInfoAttribute {
	BossName,
	BossScenes,
	SunCost, ## 僵王卡每次成功召唤的阳光费用，取非负整数。
	CoolTime, ## 僵王卡每次成功召唤后的冷却时长，单位为游戏秒，0 表示无冷却。
}
#endregion

## 通过 Global.character_registry 查询场景，关卡只需保存 ZombieBossType。
const ZombieBossInfo = {
	ZombieBossType.ZB001Doctor: {
		ZombieBossInfoAttribute.BossName: "ZB001Doctor",
		ZombieBossInfoAttribute.BossScenes: preload("res://src/entities/character/zombie_boss/zombie_boss_001_doctor.tscn"),
		ZombieBossInfoAttribute.SunCost: 10000,
		ZombieBossInfoAttribute.CoolTime: 0,
	},
}


## 空类型或未注册类型返回 null，由生成入口决定如何处理，不回退成其他角色。
func get_zombie_boss_info(boss_type: ZombieBossType, info_attribute: ZombieBossInfoAttribute):
	if boss_type == ZombieBossType.Null:
		Log.debug("warning: 获取空僵王信息")
		return null
	if not ZombieBossInfo.has(boss_type):
		Log.error("CharacterRegistry：未注册的僵王类型：%s" % boss_type)
		return null
	var curr_boss_info: Dictionary = ZombieBossInfo[boss_type]
	return curr_boss_info.get(info_attribute)
#endregion
