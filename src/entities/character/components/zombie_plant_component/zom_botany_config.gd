class_name ZomBotanyConfig
## 植物僵尸（原版 ZomBotany）配置表：僵尸类型 →「头顶那棵植物」的一切
##
## 原版机制（数据来源: PVZ Wiki https://plantsvszombies.wiki.gg/wiki/ZomBotany）
##   僵尸头顶插着一棵植物，这棵植物
##     · 有**自己的耐久**（植物僵尸先掉植物耐久，植物掉了才轮到僵尸本体）→ 本仓库映射成僵尸的「一类防具血量」；
##     · 会**用这棵植物的能力攻击玩家的植物**（豌豆僵尸射豌豆、投手僵尸投掷…）。
##
## 为什么集中在这里：
##   这 14 种植物僵尸的差异全是数据（贴图 / 耐久 / 子弹 / 战力），行为骨架共用一套组件。
##   数据散进 14 个场景会各自漂移，改一个数值要开 14 个文件。
##
## 约定：
##   · 全部 static，不持有状态（与 BulletCampConfig / DetectTargetStrategy 同风格）
##   · 贴图走 `preload`：路径写错在编译期就暴露，不要运行期 `load()`

## 头顶植物的一张贴图（相对植物节点的偏移 + 缩放）
class PlantSprite:
	## 贴图
	var texture: Texture2D
	## 相对「头顶植物」节点原点的偏移
	var offset: Vector2
	## 缩放
	var scale: float

	func _init(p_texture: Texture2D, p_offset: Vector2 = Vector2.ZERO, p_scale: float = 1.0) -> void:
		texture = p_texture
		offset = p_offset
		scale = p_scale


## 一种植物僵尸的全部数据
class ZomBotanyInfo:
	## 僵尸类型
	var zombie_type: CharacterRegistry.ZombieType
	## 头顶的植物类型（原版对应关系，图鉴 / 提示文本用）
	var plant_type: CharacterRegistry.PlantType
	## 头顶植物的耐久（映射成僵尸的一类防具血量；打掉后僵尸变回普通僵尸）
	var plant_hp: int
	## 头顶植物挂点的位置（相对 Body/BodyCorrect，僵尸头部上方）
	var head_offset: Vector2
	## 头顶植物整体缩放（原图是按植物尺寸画的，插在僵尸头上要缩小）
	var head_scale: float
	## 头顶植物的贴图，按数组顺序绘制（越靠后越在上层）
	var sprites: Array[PlantSprite]
	## 自然出怪战力（见 zm_zombie_wave_create_manager.zombie_power）
	var power: int
	## 自然出怪初始权重（见 zm_zombie_wave_create_manager.zombie_weights_ori）
	var weight: int

	func _init(
		p_zombie_type: CharacterRegistry.ZombieType,
		p_plant_type: CharacterRegistry.PlantType,
		p_plant_hp: int,
		p_sprites: Array[PlantSprite],
		p_power: int,
		p_weight: int,
		p_head_offset: Vector2 = Vector2(24, -38),
		p_head_scale: float = 0.55
	) -> void:
		zombie_type = p_zombie_type
		plant_type = p_plant_type
		plant_hp = p_plant_hp
		sprites = p_sprites
		power = p_power
		weight = p_weight
		head_offset = p_head_offset
		head_scale = p_head_scale


## 头顶植物的默认耐久（原版 ZomBotany：除坚果 / 南瓜外的植物都是 300）
const C_PLANT_HP_DEFAULT := 300
## 坚果 / 南瓜这类「本来就是肉盾」的植物给僵尸的额外耐久（原版 1100）
const C_PLANT_HP_SHELL := 1100
## 高坚果的额外耐久：原版高坚果僵尸总耐久 2470（PVZ Wiki Tall-nut Zombie），
## 是坚果僵尸（1100）的两倍档 —— 和「高坚果植物耐久是坚果墙两倍」同一比例
const C_PLANT_HP_TALL_NUT := 2200


## 全部植物僵尸的数据，键是僵尸类型
## 用 static var 而不是 const：GDScript 的 const 初始值里不允许 new 内部类实例
static var C_ZOM_BOTANY_INFO: Dictionary[CharacterRegistry.ZombieType, ZomBotanyInfo] = {}

static func _static_init() -> void:
	C_ZOM_BOTANY_INFO = {
	CharacterRegistry.ZombieType.Z031PeaShooterZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z031PeaShooterZombie,
		CharacterRegistry.PlantType.P001PeaShooterSingle,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/PeaShooter_stalk_bottom.png"), Vector2(0, 26), 0.9),
			PlantSprite.new(preload("res://assets/reanim/PeaShooter_stalk_top.png"), Vector2(0, 8), 0.9),
			PlantSprite.new(preload("res://assets/reanim/PeaShooter_Head.png"), Vector2(0, -6), 0.9),
		],
		2, 2000
	),
	CharacterRegistry.ZombieType.Z032WallNutZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z032WallNutZombie,
		CharacterRegistry.PlantType.P004WallNut,
		C_PLANT_HP_SHELL,
		[
			PlantSprite.new(preload("res://assets/reanim/Wallnut_body.png")),
		],
		3, 1500,
		Vector2(24, -30), 0.6
	),
	CharacterRegistry.ZombieType.Z033SquashZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z033SquashZombie,
		CharacterRegistry.PlantType.P018Squash,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/Squash_body.png"), Vector2(0, 6)),
			PlantSprite.new(preload("res://assets/reanim/Squash_eyes.png"), Vector2(-6, -2)),
			PlantSprite.new(preload("res://assets/reanim/Squash_stem.png"), Vector2(2, -24)),
		],
		3, 800
	),
	CharacterRegistry.ZombieType.Z034JalapenoZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z034JalapenoZombie,
		CharacterRegistry.PlantType.P021Jalapeno,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/Jalapeno_body.png")),
			PlantSprite.new(preload("res://assets/reanim/Jalapeno_eye1.png"), Vector2(-6, -4)),
			PlantSprite.new(preload("res://assets/reanim/Jalapeno_stem.png"), Vector2(4, -26)),
		],
		3, 600
	),
	CharacterRegistry.ZombieType.Z035GatlingZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z035GatlingZombie,
		CharacterRegistry.PlantType.P041GatlingPea,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/PeaShooter_stalk_bottom.png"), Vector2(0, 26), 0.9),
			PlantSprite.new(preload("res://assets/reanim/GatlingPea_barrel.png"), Vector2(0, 4), 0.85),
			PlantSprite.new(preload("res://assets/reanim/GatlingPea_head.png"), Vector2(0, -6), 0.85),
		],
		4, 500
	),
	CharacterRegistry.ZombieType.Z036SnowPeaZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z036SnowPeaZombie,
		CharacterRegistry.PlantType.P006SnowPea,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/PeaShooter_stalk_bottom.png"), Vector2(0, 26), 0.9),
			PlantSprite.new(preload("res://assets/reanim/PeaShooter_stalk_top.png"), Vector2(0, 8), 0.9),
			PlantSprite.new(preload("res://assets/reanim/SnowPea_head.png"), Vector2(0, -6), 0.9),
		],
		3, 1200
	),
	CharacterRegistry.ZombieType.Z037TorchwoodZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z037TorchwoodZombie,
		CharacterRegistry.PlantType.P023TorchWood,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/Torchwood_body.png"), Vector2(0, 4), 0.9),
			PlantSprite.new(preload("res://assets/reanim/Torchwood_eyes1.png"), Vector2(-6, -6), 0.9),
		],
		3, 800
	),
	CharacterRegistry.ZombieType.Z038MagnetShroomZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z038MagnetShroomZombie,
		CharacterRegistry.PlantType.P032MagnetShroom,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/Magnetshroom_stem.png"), Vector2(0, 24), 0.9),
			PlantSprite.new(preload("res://assets/reanim/Magnetshroom_head1.png"), Vector2(0, -2), 0.9),
		],
		3, 600
	),
	CharacterRegistry.ZombieType.Z039PumpkinZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z039PumpkinZombie,
		CharacterRegistry.PlantType.P031Pumpkin,
		C_PLANT_HP_SHELL,
		[
			PlantSprite.new(preload("res://assets/reanim/Pumpkin_front.png")),
		],
		3, 1000,
		Vector2(24, -28), 0.6
	),
	CharacterRegistry.ZombieType.Z040CabbagePultZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z040CabbagePultZombie,
		CharacterRegistry.PlantType.P033CabbagePult,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/Cabbagepult_stalk1.png"), Vector2(0, 26), 0.9),
			PlantSprite.new(preload("res://assets/reanim/Cabbagepult_head.png"), Vector2(0, -4), 0.9),
		],
		3, 1200
	),
	CharacterRegistry.ZombieType.Z041CobCannonZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z041CobCannonZombie,
		CharacterRegistry.PlantType.P048CobCannon,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/CobCannon_husk1.png"), Vector2(0, 12), 0.8),
			PlantSprite.new(preload("res://assets/reanim/CobCannon_cob.png"), Vector2(6, -12), 0.8),
		],
		5, 400
	),
	CharacterRegistry.ZombieType.Z042MelonPultZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z042MelonPultZombie,
		CharacterRegistry.PlantType.P040MelonPult,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/Melonpult_stalk.png"), Vector2(0, 26), 0.9),
			PlantSprite.new(preload("res://assets/reanim/Melonpult_body.png"), Vector2(0, -2), 0.9),
		],
		4, 700
	),
	CharacterRegistry.ZombieType.Z043WinterMelonZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z043WinterMelonZombie,
		CharacterRegistry.PlantType.P045WinterMelon,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://assets/reanim/WinterMelon_stalk.png"), Vector2(0, 26), 0.9),
			PlantSprite.new(preload("res://assets/reanim/WinterMelon_melon.png"), Vector2(0, -2), 0.9),
		],
		5, 500
	),
	CharacterRegistry.ZombieType.Z044TallNutZombie: ZomBotanyInfo.new(
		CharacterRegistry.ZombieType.Z044TallNutZombie,
		CharacterRegistry.PlantType.P024TallNut,
		C_PLANT_HP_TALL_NUT,
		[
			PlantSprite.new(preload("res://assets/reanim/Tallnut_body.png")),
		],
		4, 2000,
		Vector2(24, -30), 0.6
	),
	}


## 取一种植物僵尸的数据；不是植物僵尸（或没配）时返回 null
static func get_info(zombie_type: CharacterRegistry.ZombieType) -> ZomBotanyInfo:
	return C_ZOM_BOTANY_INFO.get(zombie_type)


## 是否属于植物僵尸
static func is_zom_botany(zombie_type: CharacterRegistry.ZombieType) -> bool:
	return C_ZOM_BOTANY_INFO.has(zombie_type)
