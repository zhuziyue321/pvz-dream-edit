class_name PlantInfoData
extends RefCounted

## 植物注册表数据表。
## 只放常量数据，查询入口见 CharacterRegistry.get_plant_info()。

const PLANT_INFO = {
	PlantIds.PEA_SHOOTER_SINGLE: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "PeaShooterSingle",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource:preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pea_shooter_single.tscn")
		},
	PlantIds.SUN_FLOWER: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SunFlower",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource:preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_sun_flower.tscn")
		},
	PlantIds.CHERRY_BOMB: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "CherryBomb",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 150,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cherry_bomb.tscn")
		},
	PlantIds.WALL_NUT: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "WallNut",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_wall_nut.tscn")
		},
	PlantIds.POTATO_MINE: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "PotatoMine",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/potato_mine.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_potato_mine.tscn")
		},
	PlantIds.SNOW_PEA: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SnowPea",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 175,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_snow_pea.tscn")
		},
	PlantIds.CHOMPER: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Chomper",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 150,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_chomper.tscn")
		},
	PlantIds.PEA_SHOOTER_DOUBLE: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "PeaShooterDouble",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 200,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pea_shooter_double.tscn")
		},
		#
	PlantIds.PUFF_SHROOM: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "PuffShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 0,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_puff.tscn")
		},
	PlantIds.SUN_SHROOM: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SunShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_sun_shroom.tscn")
		},
	PlantIds.FUME_SHROOM: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "FumeShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 75,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_fume_shroom.tscn")
		},
	PlantIds.GRAVE_BUSTER: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "GraveBuster",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 75,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/grave_buster.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_grave_buster.tscn")
		},
	PlantIds.HYPNO_SHROOM: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "HypnoShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 75,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_hypno_shroom.tscn")
		},
	PlantIds.SCAREDY_SHROOM: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "ScaredyShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_scaredy_shroom.tscn")
		},
	PlantIds.ICE_SHROOM: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "IceShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 75,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_ice_shroom.tscn")
		},
	PlantIds.DOOM_SHROOM: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "DoomShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_doom_shroom.tscn")
		},
	PlantIds.LILY_PAD: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "LilyPad",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/lily_pad.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_lily_pad.tscn")
		},
	PlantIds.SQUASH: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Squash",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_squash.tscn")
		},
	PlantIds.THREE_PEATER: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "ThreePeater",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 325,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_three_peater.tscn")
		},
	PlantIds.TANGLE_KELP: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "TangleKelp",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/tanglekelp.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_tanglekelp.tscn")
		},
	PlantIds.JALAPENO: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Jalapeno",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_jalapeno.tscn")
		},
	PlantIds.CALTROP: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Caltrop",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/caltrop.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_caltrop.tscn")
		},
	PlantIds.TORCH_WOOD: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "TorchWood",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 175,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_torch_wood.tscn")
		},
	PlantIds.TALL_NUT: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "TallNut",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 175,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_tall_nut.tscn")
		},

	PlantIds.SEA_SHROOM: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SeaShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 0,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/tanglekelp.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_sea_shroom.tscn")
		},
	PlantIds.PLANTERN: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Plantern",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_plantern.tscn")
		},
	PlantIds.CACTUS: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Cactus",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cactus.tscn")
		},
	PlantIds.BLOVER: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Blover",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_blover.tscn")
		},
	PlantIds.SPLIT_PEA: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SplitPea",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_split_pea.tscn")
		},
	PlantIds.STAR_FRUIT: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "StarFruit",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_star_fruit.tscn")
		},
	PlantIds.PUMPKIN: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Pumpkin",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/pumpkin.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pumpkin.tscn")
		},
	PlantIds.MAGNET_SHROOM: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "MagnetShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_magnet_shroom.tscn")
		},

	PlantIds.CABBAGE_PULT: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "CabbagePult",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cabbage_pult.tscn")
		},
	PlantIds.FLOWER_POT: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "FlowerPot",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/flower_pot.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_flower_pot.tscn")
		},
	PlantIds.CORN_PULT: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "CornPult",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_corn_pult.tscn")
		},
	PlantIds.COFFEE_BEAN: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "CoffeeBean",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 75,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/coffee_bean.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_coffee_bean.tscn")
		},
	PlantIds.GARLIC: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Garlic",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_garlic.tscn")
		},
	PlantIds.UMBRELLA_LEAF: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "UmbrellaLeaf",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_umbrella_leaf.tscn")
		},
	PlantIds.MARI_GOLD: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "MariGold",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_mari_gold.tscn")
		},
	PlantIds.MELON_PULT: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "MelonPult",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 300,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_melon_pult.tscn")
		},

	PlantIds.GATLING_PEA: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "GatlingPea",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 250,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_gatling_pea.tscn")
		},

	PlantIds.TWIN_SUN_FLOWER: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "TwinSunFlower",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 150,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_twin_sun_flower.tscn")
		},

	PlantIds.GLOOM_SHROOM: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "GloomShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 150,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_gloom_shroom.tscn")
		},

	PlantIds.CATTAIL: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Cattail",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 225,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cattail.tscn")
		},

	PlantIds.WINTER_MELON: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "WinterMelon",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 200,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_winter_melon.tscn")
		},

	PlantIds.GOLD_MAGNET: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "GoldMagnet",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_gold_magnet.tscn")
		},

	PlantIds.SPIKE_ROCK: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SpikeRock",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_spike_rock.tscn")
		},

	PlantIds.COB_CANNON: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "CobCannon",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 500,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/cob_cannon.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cob_cannon.tscn")
		},

	PlantIds.PEA_SHOOTER_DOUBLE_REVERSE: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "PeaShooterDoubleReverse",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 200,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pea_shooter_double_reverse.tscn")
		},

	## 模仿者
	PlantIds.IMITATER:{
		CharacterRegistry.PlantInfoAttribute.PlantName: "Imitater",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 0,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/imitater.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_imitater.tscn")
		},


	## 发芽
	PlantIds.SPROUT:{
		CharacterRegistry.PlantInfoAttribute.PlantName: "Sprout",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_sprout.tscn")
		},

	## 保龄球
	PlantIds.WALL_NUT_BOWLING: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "WallNutBowling",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_wall_nut_bowling.tscn")
		},
	PlantIds.WALL_NUT_BOWLING_BOMB: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "WallNutBowlingBomb",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_wall_nut_bowling_bomb.tscn")
		},
	PlantIds.WALL_NUT_BOWLING_BIG: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "WallNutBowlingBig",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_wall_nut_bowling_big.tscn")
		},
	## 工具植物：**没有卡、不进选卡界面、不在 `PlantIds.ALL`**（见 `PlantIds.INVISIBLE` 的注释）。
	## 登记在这里的唯一目的：让调用方（模组 / 调试代码）能按 id 拿到它的场景，而不是自己写路径。
	PlantIds.INVISIBLE: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Invisible",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 0.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 0,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_invisible.tscn")
		},
}
