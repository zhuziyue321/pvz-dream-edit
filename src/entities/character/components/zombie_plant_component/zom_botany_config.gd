class_name ZomBotanyConfig
## 植物僵尸（原版 ZomBotany）配置表：僵尸类型 →「替代僵尸头的那颗植物头」的一切
##
## 原版机制（数据来源: PVZ Wiki https://plantsvszombies.wiki.gg/wiki/ZomBotany）
##   僵尸的**头**被一棵植物取代，这棵植物
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
##   · `sprites` 只放**植物的头**（去掉茎）：那颗植物是拿来当僵尸头的，不是插在头顶的另一棵树

## 植物头的一张贴图（相对植物节点的偏移 + 缩放）
class PlantSprite:
	## 贴图
	var texture: Texture2D
	## 相对「植物节点原点」的偏移（原点是僵尸头贴图的中心，见 ZomBotanyInfo.head_offset）
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
	var zombie_type: StringName
	## 替代僵尸头的植物类型（原版对应关系，图鉴 / 提示文本用）
	var plant_type: StringName
	## 那颗植物的耐久（映射成僵尸的一类防具血量；打掉后僵尸变回普通僵尸）
	var plant_hp: int
	## 相对「僵尸头贴图中心」的微调偏移：
	##   植物节点挂在僵尸头节点（`Body/BodyCorrect/Anim_head1`）下，原点自动落在头贴图中心，
	##   这里只用来做最后那几像素的对位（默认 Vector2.ZERO）
	var head_offset: Vector2
	## 植物整体缩放（**最终**大小；僵尸头节点自身的缩放由组件抵消，不用在这里算）
	var head_scale: float
	## 植物头的贴图，按数组顺序绘制（越靠后越在上层）
	var sprites: Array[PlantSprite]
	## 自然出怪战力：植物僵尸走本字段，普通僵尸走 `CharacterRegistry.ZombieSpawnPower`，
	## 两边由 `zm_zombie_wave_create_manager.get_zombie_power()` 统一分派（U-02 后只有一份数据源）
	var power: int
	## 自然出怪初始权重：同上，普通僵尸走 `CharacterRegistry.ZombieSpawnWeights`
	var weight: int

	func _init(
		p_zombie_type: StringName,
		p_plant_type: StringName,
		p_plant_hp: int,
		p_sprites: Array[PlantSprite],
		p_power: int,
		p_weight: int,
		p_head_offset: Vector2 = Vector2.ZERO,
		p_head_scale: float = 0.6
	) -> void:
		zombie_type = p_zombie_type
		plant_type = p_plant_type
		plant_hp = p_plant_hp
		sprites = p_sprites
		power = p_power
		weight = p_weight
		head_offset = p_head_offset
		head_scale = p_head_scale


## 那颗植物的默认耐久（原版 ZomBotany：除坚果 / 南瓜外的植物都是 300）
const C_PLANT_HP_DEFAULT := 300
## 坚果 / 南瓜这类「本来就是肉盾」的植物给僵尸的额外耐久（原版 1100）
const C_PLANT_HP_SHELL := 1100
## 高坚果的额外耐久：原版高坚果僵尸总耐久 2470（PVZ Wiki Tall-nut Zombie），
## 是坚果僵尸（1100）的两倍档 —— 和「高坚果植物耐久是坚果墙两倍」同一比例
const C_PLANT_HP_TALL_NUT := 2200


## 全部植物僵尸的数据，键是僵尸类型
## 用 static var 而不是 const：GDScript 的 const 初始值里不允许 new 内部类实例
static var C_ZOM_BOTANY_INFO: Dictionary[StringName, ZomBotanyInfo] = {}

static func _static_init() -> void:
	C_ZOM_BOTANY_INFO = {
	ZombieIds.PEA_SHOOTER_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.PEA_SHOOTER_ZOMBIE,
		PlantIds.PEA_SHOOTER_SINGLE,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/PeaShooter_Head.png"), Vector2(0, -6)),
		],
		2, 2000, Vector2.ZERO, 0.6
	),
	ZombieIds.WALL_NUT_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.WALL_NUT_ZOMBIE,
		PlantIds.WALL_NUT,
		C_PLANT_HP_SHELL,
		[
			PlantSprite.new(preload("res://pak/reanim/Wallnut_body.png")),
		],
		3, 1500, Vector2.ZERO, 0.6
	),
	ZombieIds.SQUASH_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.SQUASH_ZOMBIE,
		PlantIds.SQUASH,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/Squash_body.png"), Vector2(0, 6)),
			PlantSprite.new(preload("res://pak/reanim/Squash_eyes.png"), Vector2(-6, -2)),
		],
		3, 800, Vector2.ZERO, 0.6
	),
	ZombieIds.JALAPENO_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.JALAPENO_ZOMBIE,
		PlantIds.JALAPENO,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/Jalapeno_body.png")),
			PlantSprite.new(preload("res://pak/reanim/Jalapeno_eye1.png"), Vector2(-6, -4)),
		],
		3, 600, Vector2.ZERO, 0.6
	),
	ZombieIds.GATLING_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.GATLING_ZOMBIE,
		PlantIds.GATLING_PEA,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/GatlingPea_barrel.png"), Vector2(0, 4)),
			PlantSprite.new(preload("res://pak/reanim/GatlingPea_head.png"), Vector2(0, -6)),
		],
		4, 500, Vector2.ZERO, 0.6
	),
	ZombieIds.SNOW_PEA_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.SNOW_PEA_ZOMBIE,
		PlantIds.SNOW_PEA,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/SnowPea_head.png"), Vector2(0, -6)),
		],
		3, 1200, Vector2.ZERO, 0.6
	),
	ZombieIds.TORCHWOOD_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.TORCHWOOD_ZOMBIE,
		PlantIds.TORCH_WOOD,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/Torchwood_body.png"), Vector2(0, 4)),
			PlantSprite.new(preload("res://pak/reanim/Torchwood_eyes1.png"), Vector2(-6, -6)),
		],
		3, 800, Vector2.ZERO, 0.6
	),
	ZombieIds.MAGNET_SHROOM_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.MAGNET_SHROOM_ZOMBIE,
		PlantIds.MAGNET_SHROOM,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/Magnetshroom_head1.png"), Vector2(0, -2)),
		],
		3, 600, Vector2.ZERO, 0.6
	),
	ZombieIds.PUMPKIN_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.PUMPKIN_ZOMBIE,
		PlantIds.PUMPKIN,
		C_PLANT_HP_SHELL,
		[
			PlantSprite.new(preload("res://pak/reanim/Pumpkin_front.png")),
		],
		3, 1000, Vector2.ZERO, 0.6
	),
	ZombieIds.CABBAGE_PULT_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.CABBAGE_PULT_ZOMBIE,
		PlantIds.CABBAGE_PULT,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/Cabbagepult_head.png"), Vector2(0, -4)),
		],
		3, 1200, Vector2.ZERO, 0.6
	),
	ZombieIds.COB_CANNON_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.COB_CANNON_ZOMBIE,
		PlantIds.COB_CANNON,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/CobCannon_husk1.png"), Vector2(0, 12)),
			PlantSprite.new(preload("res://pak/reanim/CobCannon_cob.png"), Vector2(6, -12)),
		],
		5, 400, Vector2.ZERO, 0.6
	),
	ZombieIds.MELON_PULT_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.MELON_PULT_ZOMBIE,
		PlantIds.MELON_PULT,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/Melonpult_body.png"), Vector2(0, -2)),
		],
		4, 700, Vector2.ZERO, 0.6
	),
	ZombieIds.WINTER_MELON_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.WINTER_MELON_ZOMBIE,
		PlantIds.WINTER_MELON,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(preload("res://pak/reanim/WinterMelon_melon.png"), Vector2(0, -2)),
		],
		5, 500, Vector2.ZERO, 0.6
	),
	ZombieIds.TALL_NUT_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.TALL_NUT_ZOMBIE,
		PlantIds.TALL_NUT,
		C_PLANT_HP_TALL_NUT,
		[
			PlantSprite.new(preload("res://pak/reanim/Tallnut_body.png")),
		],
		4, 2000, Vector2.ZERO, 0.6
	),
	}


## 取一种植物僵尸的数据；不是植物僵尸（或没配）时返回 null
static func get_info(zombie_type: StringName) -> ZomBotanyInfo:
	return C_ZOM_BOTANY_INFO.get(zombie_type)


## 是否属于植物僵尸
static func is_zom_botany(zombie_type: StringName) -> bool:
	return C_ZOM_BOTANY_INFO.has(zombie_type)
