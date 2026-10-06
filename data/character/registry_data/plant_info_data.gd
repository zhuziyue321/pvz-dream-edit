class_name PlantInfoData
extends RefCounted

## 植物注册表数据表。
## 只放常量数据，查询入口见 CharacterRegistry.get_plant_info()。

const PLANT_INFO = {
	CharacterRegistry.PlantType.P001PeaShooterSingle: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "PeaShooterSingle",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource:preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pea_shooter_single.tscn")
		},
	CharacterRegistry.PlantType.P002SunFlower: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SunFlower",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource:preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_sun_flower.tscn")
		},
	CharacterRegistry.PlantType.P003CherryBomb: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "CherryBomb",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 150,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cherry_bomb.tscn")
		},
	CharacterRegistry.PlantType.P004WallNut: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "WallNut",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_wall_nut.tscn")
		},
	CharacterRegistry.PlantType.P005PotatoMine: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "PotatoMine",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/potato_mine.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_potato_mine.tscn")
		},
	CharacterRegistry.PlantType.P006SnowPea: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SnowPea",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 175,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_snow_pea.tscn")
		},
	CharacterRegistry.PlantType.P007Chomper: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Chomper",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 150,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_chomper.tscn")
		},
	CharacterRegistry.PlantType.P008PeaShooterDouble: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "PeaShooterDouble",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 200,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pea_shooter_double.tscn")
		},
		#
	CharacterRegistry.PlantType.P009PuffShroom: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "PuffShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 0,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_puff.tscn")
		},
	CharacterRegistry.PlantType.P010SunShroom: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SunShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_sun_shroom.tscn")
		},
	CharacterRegistry.PlantType.P011FumeShroom: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "FumeShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 75,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_fume_shroom.tscn")
		},
	CharacterRegistry.PlantType.P012GraveBuster: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "GraveBuster",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 75,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/grave_buster.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_grave_buster.tscn")
		},
	CharacterRegistry.PlantType.P013HypnoShroom: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "HypnoShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 75,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_hypno_shroom.tscn")
		},
	CharacterRegistry.PlantType.P014ScaredyShroom: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "ScaredyShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_scaredy_shroom.tscn")
		},
	CharacterRegistry.PlantType.P015IceShroom: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "IceShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 75,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_ice_shroom.tscn")
		},
	CharacterRegistry.PlantType.P016DoomShroom: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "DoomShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_doom_shroom.tscn")
		},
	CharacterRegistry.PlantType.P017LilyPad: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "LilyPad",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/lily_pad.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_lily_pad.tscn")
		},
	CharacterRegistry.PlantType.P018Squash: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Squash",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_squash.tscn")
		},
	CharacterRegistry.PlantType.P019ThreePeater: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "ThreePeater",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 325,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_three_peater.tscn")
		},
	CharacterRegistry.PlantType.P020TangleKelp: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "TangleKelp",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/tanglekelp.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_tanglekelp.tscn")
		},
	CharacterRegistry.PlantType.P021Jalapeno: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Jalapeno",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_jalapeno.tscn")
		},
	CharacterRegistry.PlantType.P022Caltrop: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Caltrop",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/caltrop.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_caltrop.tscn")
		},
	CharacterRegistry.PlantType.P023TorchWood: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "TorchWood",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 175,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_torch_wood.tscn")
		},
	CharacterRegistry.PlantType.P024TallNut: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "TallNut",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 175,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_tall_nut.tscn")
		},

	CharacterRegistry.PlantType.P025SeaShroom: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SeaShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 0,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/tanglekelp.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_sea_shroom.tscn")
		},
	CharacterRegistry.PlantType.P026Plantern: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Plantern",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_plantern.tscn")
		},
	CharacterRegistry.PlantType.P027Cactus: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Cactus",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cactus.tscn")
		},
	CharacterRegistry.PlantType.P028Blover: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Blover",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_blover.tscn")
		},
	CharacterRegistry.PlantType.P029SplitPea: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SplitPea",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_split_pea.tscn")
		},
	CharacterRegistry.PlantType.P030StarFruit: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "StarFruit",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_star_fruit.tscn")
		},
	CharacterRegistry.PlantType.P031Pumpkin: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Pumpkin",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/pumpkin.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pumpkin.tscn")
		},
	CharacterRegistry.PlantType.P032MagnetShroom: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "MagnetShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_magnet_shroom.tscn")
		},

	CharacterRegistry.PlantType.P033CabbagePult: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "CabbagePult",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cabbage_pult.tscn")
		},
	CharacterRegistry.PlantType.P034FlowerPot: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "FlowerPot",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 25,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/flower_pot.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_flower_pot.tscn")
		},
	CharacterRegistry.PlantType.P035CornPult: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "CornPult",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_corn_pult.tscn")
		},
	CharacterRegistry.PlantType.P036CoffeeBean: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "CoffeeBean",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 75,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/coffee_bean.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_coffee_bean.tscn")
		},
	CharacterRegistry.PlantType.P037Garlic: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Garlic",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_garlic.tscn")
		},
	CharacterRegistry.PlantType.P038UmbrellaLeaf: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "UmbrellaLeaf",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 100,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_umbrella_leaf.tscn")
		},
	CharacterRegistry.PlantType.P039MariGold: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "MariGold",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 30.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_mari_gold.tscn")
		},
	CharacterRegistry.PlantType.P040MelonPult: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "MelonPult",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 300,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_melon_pult.tscn")
		},

	CharacterRegistry.PlantType.P041GatlingPea: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "GatlingPea",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 250,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_gatling_pea.tscn")
		},

	CharacterRegistry.PlantType.P042TwinSunFlower: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "TwinSunFlower",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 150,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_twin_sun_flower.tscn")
		},

	CharacterRegistry.PlantType.P043GloomShroom: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "GloomShroom",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 150,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_gloom_shroom.tscn")
		},

	CharacterRegistry.PlantType.P044Cattail: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "Cattail",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 225,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cattail.tscn")
		},

	CharacterRegistry.PlantType.P045WinterMelon: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "WinterMelon",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 200,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_winter_melon.tscn")
		},

	CharacterRegistry.PlantType.P046GoldMagnet: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "GoldMagnet",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_gold_magnet.tscn")
		},

	CharacterRegistry.PlantType.P047SpikeRock: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "SpikeRock",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 125,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_purple.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_spike_rock.tscn")
		},

	CharacterRegistry.PlantType.P048CobCannon: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "CobCannon",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 500,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/cob_cannon.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_cob_cannon.tscn")
		},

	CharacterRegistry.PlantType.P049PeaShooterDoubleReverse: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "PeaShooterDoubleReverse",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 200,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_pea_shooter_double_reverse.tscn")
		},

	## 模仿者
	CharacterRegistry.PlantType.P999Imitater:{
		CharacterRegistry.PlantInfoAttribute.PlantName: "Imitater",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 50.0,
		CharacterRegistry.PlantInfoAttribute.SunCost: 0,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/imitater.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_imitater.tscn")
		},


	## 发芽
	CharacterRegistry.PlantType.P1000Sprout:{
		CharacterRegistry.PlantInfoAttribute.PlantName: "Sprout",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_sprout.tscn")
		},

	## 保龄球
	CharacterRegistry.PlantType.P1001WallNutBowling: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "WallNutBowling",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_wall_nut_bowling.tscn")
		},
	CharacterRegistry.PlantType.P1002WallNutBowlingBomb: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "WallNutBowlingBomb",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource :  preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes :  preload("res://src/entities/character/plant/plant_wall_nut_bowling_bomb.tscn")
		},
	CharacterRegistry.PlantType.P1003WallNutBowlingBig: {
		CharacterRegistry.PlantInfoAttribute.PlantName: "WallNutBowlingBig",
		CharacterRegistry.PlantInfoAttribute.CoolTime: 7.5,
		CharacterRegistry.PlantInfoAttribute.SunCost: 50,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource : preload("res://data/character/plant_condition/common_plant_land.tres"),
		CharacterRegistry.PlantInfoAttribute.PlantScenes : preload("res://src/entities/character/plant/plant_wall_nut_bowling_big.tscn")
		},
}
