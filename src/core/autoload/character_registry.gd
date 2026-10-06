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


#region 数据表别名（数据本体已迁至 res://data/character/registry_data/）
## 三张表原先写在本文件里（约 800 行），现已按角色拆分；这里保留同名别名，
## 让既有代码里 CharacterRegistry.ZombieInfo 这类直接读表的写法继续可用。
const PlantInfo: Dictionary = PlantInfoData.PLANT_INFO
const ZombieInfo: Dictionary = ZombieInfoData.ZOMBIE_INFO
const ZombieSpawnPower: Dictionary = ZombieInfoData.ZOMBIE_SPAWN_POWER
const ZombieSpawnWeights: Dictionary = ZombieInfoData.ZOMBIE_SPAWN_WEIGHTS
const ZombieBossInfo: Dictionary = ZombieBossInfoData.ZOMBIE_BOSS_INFO
#endregion


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

## 获取植物属性方法
func get_plant_info(plant_type:PlantType, info_attribute:PlantInfoAttribute):
	if plant_type == PlantType.Null:
		Log.debug("warning:获取空植物信息")
		return null
	var curr_plant_info: Dictionary = PlantInfoData.PLANT_INFO[plant_type]
	return curr_plant_info[info_attribute]

## 获取僵尸属性方法
func get_zombie_info(zombie_type:ZombieType, info_attribute:ZombieInfoAttribute):
	if zombie_type == 0:
		Log.debug("warning: 获取空僵尸信息")
		return null
	var curr_zombie_info: Dictionary = ZombieInfoData.ZOMBIE_INFO[zombie_type]
	return curr_zombie_info[info_attribute]

## 空类型或未注册类型返回 null，由生成入口决定如何处理，不回退成其他角色。
func get_zombie_boss_info(boss_type: ZombieBossType, info_attribute: ZombieBossInfoAttribute):
	if boss_type == ZombieBossType.Null:
		Log.debug("warning: 获取空僵王信息")
		return null
	if not ZombieBossInfoData.ZOMBIE_BOSS_INFO.has(boss_type):
		Log.error("CharacterRegistry：未注册的僵王类型：%s" % boss_type)
		return null
	var curr_boss_info: Dictionary = ZombieBossInfoData.ZOMBIE_BOSS_INFO[boss_type]
	return curr_boss_info[info_attribute]
