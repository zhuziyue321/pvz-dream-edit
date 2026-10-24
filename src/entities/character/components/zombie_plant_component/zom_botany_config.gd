class_name ZomBotanyConfig
## 植物僵尸（原版 ZomBotany）配置表：僵尸类型 →「替代僵尸头的那颗植物头」的一切
##
## 数据来源: PVZ Wiki（https://plantsvszombies.wiki.gg/wiki/ZomBotany_zombies 及各僵尸条目的
##   Overview 段 `absorbs … damage` 原句 / 信息框 `health`、`wave point cost`、`weight`）
##
## 原版机制：
##   僵尸的**头**被一棵植物取代，这棵植物
##     · 可能**有自己的耐久**（植物僵尸先掉植物耐久，植物掉了才轮到僵尸本体）→ 本仓库映射成僵尸的「一类防具血量」；
##     · 会**用这棵植物的能力攻击玩家的植物**（豌豆僵尸射豌豆、投手僵尸投掷…）。
##
## 【原版一代只有 6 只】（其余 8 只是本仓库扩展，见下面第二张表）
##   名称            关卡          原版总耐久    wiki 依据（条目页 Overview / 信息框）
##   豌豆僵尸        植物僵尸 1/2   270          Peashooter_Zombie：90 掉手 / 180 掉头 / 270 死
##   坚果僵尸        植物僵尸 1/2   1370         Wall-nut_Zombie：370 / 730 裂纹 / 1370 死（health = 1370）
##   窝瓜僵尸        植物僵尸 2     270          Squash_Zombie：90 / 180 / 270
##   火爆辣椒僵尸    植物僵尸 2     500          Jalapeno_Zombie：166 / 333 / 500（health = 500）
##   机枪僵尸        植物僵尸 2     270          Gatling_Pea_Zombie：90 / 180 / 270
##   高坚果僵尸      植物僵尸 2     2470         Tall-nut_Zombie：信息框 health = 2470
##                                              （同页正文写 2670 / 2400 三个数字互相矛盾，以信息框为准）
##
##   原版口径：**总耐久 = 僵尸本体 270 + 头顶植物那层耐久**。
##     · 豌豆 / 窝瓜 / 机枪 的总耐久就是 270 —— 那颗植物头**没有**独立耐久
##       （原文 `loses its <植物> head at 180` 是本体血量的 2/3，纯表现），映射成 `plant_hp = 0`：
##       `ArmorComponent` 的 `max_hp = 0` 语义就是「这不是一件防具」，不打血、不挡子弹、也不隐藏植物头；
##     · 坚果 1370 = 270 + 1100、高坚果 2470 = 270 + 2200、火爆辣椒 500 = 270 + 230。
##
## 【本仓库扩展的 8 只】寒冰射手 / 火炬树桩 / 磁力菇 / 南瓜头 / 卷心菜投手 / 玉米加农炮 / 西瓜投手 / 冰瓜投手
##   原版一代**没有**这 8 只（PVZ Wiki《ZomBotany zombies》明说寒冰射手僵尸
##   "does not appear in the first Plants vs. Zombies"，只在中文版二代里出现）。
##   它们的耐久 / 战力 / 权重是本仓库给加料关卡定的，**不是原版数据**（耐久按 `C_PLANT_HP_DEFAULT`）。
##
## 为什么集中在这里：
##   这 14 种植物僵尸的差异全是数据（头 / 耐久 / 子弹 / 战力），行为骨架共用一套组件。
##   数据散进 14 个场景会各自漂移，改一个数值要开 14 个文件。
##
## 约定：
##   · 全部 static，不持有状态（与 BulletCampConfig / DetectTargetStrategy 同风格）
##   · 贴图 / 头场景走 `preload`：路径写错在编译期就暴露，不要运行期 `load()`
##   · `sprites` 只放**植物的头**（去掉茎）：那颗植物是拿来当僵尸头的，不是插在头顶的另一棵树
##   · 想要「会动的头」就用 `head_scene`（见 ZomBotanyInfo.head_scene），`sprites` 只是兜底

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


## 原版 attach 参数：头场景的根挂到哪条轨道上、偏移多少
##
## 直接照抄 `../PvZ-Portable-main/src/Lawn/Zombie.cpp` 里那 6 只的
## `AttachReanim(轨道, offset, rot, scale)`（707–851 行），**不要自己调**：
## 原版挂的轨道本身就是「图层」—— 挂 `anim_head1` 的跟着摇头 / 点头，挂 `Zombie_body` 的跟身体走。
## 头场景的根 = **植物自己的原点**（内部层级与植物场景一致，含 `Body/BodyCorrect` 偏移），
## 所以这里的 offset / scale 就是原版对「植物 reanim 原点」的摆放。
class HeadAttach:
	## true = 挂身体贴图 `Zombie_body`（原版坚果 / 高坚果 / 辣椒），false = 挂僵尸头 `Anim_head1`
	var to_body: bool
	## 挂点局部坐标里的偏移
	var offset: Vector2
	## 挂点局部坐标里的旋转（弧度）
	var rotation: float
	## 挂点局部坐标里的缩放；**x 的负号是原版的水平镜像**（植物贴图朝右，僵尸朝左）
	var scale: Vector2

	func _init(
		p_to_body: bool = false,
		p_offset: Vector2 = Vector2.ZERO,
		p_rotation: float = 0.0,
		p_scale: Vector2 = Vector2.ONE
	) -> void:
		to_body = p_to_body
		offset = p_offset
		rotation = p_rotation
		scale = p_scale


## 一种植物僵尸的全部数据
class ZomBotanyInfo:
	## 僵尸类型
	var zombie_type: StringName
	## 替代僵尸头的植物类型（原版对应关系，图鉴 / 提示文本用）
	var plant_type: StringName
	## 那颗植物的耐久（映射成僵尸的一类防具血量；打掉后僵尸变回普通僵尸）。
	## **0 = 原版口径里这颗植物头没有独立耐久**（总耐久就是僵尸本体 270，见文件头「原版只有 6 只」）。
	var plant_hp: int
	## 【静态头】相对「僵尸头贴图中心」的微调偏移：
	##   植物节点挂在僵尸头节点（`Body/BodyCorrect/Anim_head1`）下，原点自动落在头贴图中心，
	##   这里只用来做最后那几像素的对位（默认 Vector2.ZERO）
	var head_offset: Vector2
	## 【静态头】植物整体缩放（**最终**大小；僵尸头节点自身的缩放由组件抵消，不用在这里算）
	var head_scale: float
	## 【动画头】原版 attach：挂点轨道 + offset / rot / scale（见 HeadAttach）。
	## null = 不给动画头（静态头用上面的 head_offset / head_scale）
	var attach: HeadAttach
	## 植物头的贴图，按数组顺序绘制（越靠后越在上层）
	var sprites: Array[PlantSprite]
	## 受损裂纹贴图（**替换 `sprites[0]` 那张主体贴图**）：下标 0 = 掉到 2/3 血、1 = 掉到 1/3 血。
	## 原版坚果 / 高坚果僵尸靠 `SetImageOverride("anim_face", WALLNUT_CRACKED1/2)` 换裂纹，
	## 空数组 = 这只没有裂纹表现（本仓库大多数植物头没有对应的裂纹贴图）。
	var cracked_sprites: Array[Texture2D]
	## 动画版植物头场景（可选，给了就**优先于** `sprites`）：
	##   根节点 = **植物自己的原点**（内部层级照抄植物场景，含 `Body/BodyCorrect` 偏移），
	##   下面挂植物自己的头部件 + 一个 `AnimationPlayer`（直接播植物那份 idle 动画资源）。
	##   `Head_Idle` 是待机循环（呼吸 / 张嘴），`Head_Attack` 是攻击动画（发射那一帧走它的方法轨，
	##   见 `ZombiePlantComponent._bind_head_attack_shoot_track`）。
	##   原版 6 只都是这种（`plant_head_*.tscn`），摆位走 `attach`；扩展的 8 只仍是拼静态 PNG。
	var head_scene: PackedScene
	## 自然出怪战力：植物僵尸走本字段，普通僵尸走 `CharacterRegistry.ZombieSpawnPower`，
	## 两边由 `zm_zombie_wave_create_manager.get_zombie_power()` 统一分派（U-02 后只有一份数据源）
	var power: int
	## 自然出怪初始权重：同上，普通僵尸走 `CharacterRegistry.ZombieSpawnWeights`
	var weight: int
	## 首次允许出现的波次（**1 起算**，与关卡波数同口径）。
	## 原版 `ZombieDefinition.mFirstAllowedWave`：`theWaveIndex + 1 < mFirstAllowedWave` 时不出。
	## 豌豆 / 坚果 = 1（全程可出），窝瓜 / 辣椒 / 机枪 / 高坚果 = 10（第 10 波起才进随机池）。
	var first_allowed_wave: int
	## 隐藏僵尸的领带（原版那三只 `ReanimShowPrefix("Zombie_tie", RENDER_GROUP_HIDDEN)`）：
	## 坚果 / 高坚果 / 火爆辣椒僵尸的头是**整颗植物**，领带会从植物底下露出来
	var hide_tie: bool
	## 动画头里「主体贴图」的节点路径（**相对头场景根**）：受损裂纹换的就是这一张。
	## 静态头换的是 `sprites[0]`；动画头的贴图由动画资源自己设，只能按路径找节点。
	var head_body_path: NodePath

	func _init(
		p_zombie_type: StringName,
		p_plant_type: StringName,
		p_plant_hp: int,
		p_sprites: Array[PlantSprite],
		p_power: int,
		p_weight: int,
		p_head_offset: Vector2 = Vector2.ZERO,
		p_head_scale: float = 0.5,
		p_head_scene: PackedScene = null,
		p_first_allowed_wave: int = 1,
		p_cracked_sprites: Array[Texture2D] = [],
		p_hide_tie: bool = false,
		p_head_body_path: NodePath = ^"",
		p_attach: HeadAttach = null
	) -> void:
		zombie_type = p_zombie_type
		plant_type = p_plant_type
		plant_hp = p_plant_hp
		sprites = p_sprites
		power = p_power
		weight = p_weight
		head_offset = p_head_offset
		head_scale = p_head_scale
		head_scene = p_head_scene
		first_allowed_wave = p_first_allowed_wave
		cracked_sprites = p_cracked_sprites
		hide_tie = p_hide_tie
		head_body_path = p_head_body_path
		attach = p_attach


## 僵尸本体耐久：`zombie_base.tscn` 的 `HpComponent.max_hp`（原版普通僵尸 270，PVZ Wiki Zombie）
## 只用于把 wiki 的「总耐久」换算成 `plant_hp`（总耐久 − 本体），运行时真源仍在场景里
const C_ZOMBIE_BODY_HP := 270

## 植物头**没有独立耐久**：`ArmorComponent.max_hp = 0` 的语义就是「这不是一件防具」——
## 不参与伤害结算、不显示血条、`is_alive()` 恒 false，植物头也就永远不会被「打掉」
## （原版这几只的植物头本来只在 2/3 血量时掉落，是纯表现，不是一层血量）
const C_PLANT_HP_NONE := 0

## 本仓库扩展的 8 只（非原版）用的默认耐久，**不是原版数据**（原版只有 6 只，见文件头）
const C_PLANT_HP_DEFAULT := 300
## 坚果 / 南瓜这类「本来就是肉盾」的植物给僵尸的额外耐久：
## 原版坚果僵尸总耐久 1370 = 本体 270 + 1100（PVZ Wiki Wall-nut Zombie）
const C_PLANT_HP_SHELL := 1100
## 高坚果的额外耐久：原版高坚果僵尸总耐久 2470 = 本体 270 + 2200（PVZ Wiki Tall-nut Zombie）
const C_PLANT_HP_TALL_NUT := 2200
## 火爆辣椒僵尸：原版总耐久 500（PVZ Wiki Jalapeno_Zombie，同页正文 166 / 333 / 500 三段阈值），
## 它本体是「撑杆跳体型」的 500，本仓库本体统一 270，所以差额 230 记在植物头上
const C_PLANT_HP_JALAPENO := 230


## 全部植物僵尸的数据，键是僵尸类型
## 用 static var 而不是 const：GDScript 的 const 初始值里不允许 new 内部类实例
static var C_ZOM_BOTANY_INFO: Dictionary[StringName, ZomBotanyInfo] = {}

static func _static_init() -> void:
	C_ZOM_BOTANY_INFO = {
	ZombieIds.PEA_SHOOTER_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.PEA_SHOOTER_ZOMBIE,
		PlantIds.PEA_SHOOTER_SINGLE,
		## 原版总耐久 270（= 本体，植物头没有独立耐久）；战力 1 / 权重 4000 同普通僵尸
		C_PLANT_HP_NONE,
		## 静态兜底：头场景实例化失败时仍然是这颗头，不是一个空窟窿
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/PeaShooter_Head.png"), Vector2(0, -6)),
		],
		1, 4000, Vector2.ZERO, 0.5,
		## 动画版头：`Head_Idle` 直接搬自植物场景；场景根 = 植物原点（内部层级照抄植物）
		AssetRegistry.get_scene("res://src/entities/character/components/zombie_plant_component/plant_head_pea_shooter.tscn"),
		1,
		[],
		false,
		^"",
		## 原版 `Zombie.cpp`：attach `anim_head1`，offset (65,-5)，rot 0.2，scale 水平镜像
		HeadAttach.new(false, Vector2(65, -5), 0.2, Vector2(-1, 1))
	),
	ZombieIds.WALL_NUT_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.WALL_NUT_ZOMBIE,
		PlantIds.WALL_NUT,
		## 原版总耐久 1370 = 本体 270 + 坚果 1100；战力 4 / 权重 3000
		C_PLANT_HP_SHELL,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Wallnut_body.png")),
		],
		4, 3000, Vector2.ZERO, 0.5,
		## 动画头：直接播坚果自己的 `Wallnut_idle`（原版 `REANIM_WALLNUT` 的 `anim_idle`）
		AssetRegistry.get_scene("res://src/entities/character/components/zombie_plant_component/plant_head_wall_nut.tscn"),
		1,
		## 原版掉到 2/3、1/3 血换 `WALLNUT_CRACKED1/2`（`Zombie::TakeHelmDamage` 的 damage index）
		[
			AssetRegistry.get_texture("res://pak/reanim/Wallnut_cracked1.png"),
			AssetRegistry.get_texture("res://pak/reanim/Wallnut_cracked2.png"),
		],
		## 原版坚果僵尸藏掉领带（整颗坚果替换了头）
		true,
		## 动画头换裂纹的位置（静态头换的是 `sprites[0]`）
		^"Body/BodyCorrect/Anim_face",
		## 原版 `Zombie.cpp`：attach `Zombie_body`（跟身体走、不跟头），offset (50,0)，scale 0.8 且水平镜像
		HeadAttach.new(true, Vector2(50, 0), 0.2, Vector2(-0.8, 0.8))
	),
	ZombieIds.SQUASH_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.SQUASH_ZOMBIE,
		PlantIds.SQUASH,
		## 原版总耐久 270（= 本体）；战力 3 / 权重 2000；第 10 波起才进随机池
		C_PLANT_HP_NONE,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Squash_body.png"), Vector2(0, 6)),
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Squash_eyes.png"), Vector2(-6, -2)),
		],
		3, 2000, Vector2.ZERO, 0.5,
		## 动画头：播窝瓜自己的 `Squash_idle`（原版 `REANIM_SQUASH` 的 `anim_idle`）
		AssetRegistry.get_scene("res://src/entities/character/components/zombie_plant_component/plant_head_squash.tscn"),
		10,
		[],
		false,
		^"",
		## 原版 `Zombie.cpp`：attach `anim_head1`，offset (55,-15)，rot 0.2，scale 0.75 且水平镜像
		HeadAttach.new(false, Vector2(55, -15), 0.2, Vector2(-0.75, 0.75))
	),
	ZombieIds.JALAPENO_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.JALAPENO_ZOMBIE,
		PlantIds.JALAPENO,
		## 原版总耐久 500 = 本体 270 + 230；战力 3 / 权重 1000；第 10 波起才进随机池
		C_PLANT_HP_JALAPENO,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Jalapeno_body.png")),
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Jalapeno_eye1.png"), Vector2(-6, -4)),
		],
		3, 1000, Vector2.ZERO, 0.5,
		## 动画头：播辣椒自己的 `Jalapeno_idle`（原版 `REANIM_JALAPENO` 的 `anim_idle`）
		AssetRegistry.get_scene("res://src/entities/character/components/zombie_plant_component/plant_head_jalapeno.tscn"),
		10,
		[],
		## 原版辣椒僵尸藏掉领带
		true,
		^"",
		## 原版 `Zombie.cpp`：attach `Zombie_body`（跟身体走、不跟头），offset (55,-5)，rot 0.2，水平镜像
		HeadAttach.new(true, Vector2(55, -5), 0.2, Vector2(-1, 1))
	),
	ZombieIds.GATLING_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.GATLING_ZOMBIE,
		PlantIds.GATLING_PEA,
		## 原版总耐久 270（= 本体）；战力 3 / 权重 2000；第 10 波起才进随机池
		C_PLANT_HP_NONE,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/GatlingPea_barrel.png"), Vector2(0, 4)),
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/GatlingPea_head.png"), Vector2(0, -6)),
		],
		3, 2000, Vector2.ZERO, 0.5,
		## 动画头：播机枪豌豆自己的 `GatlingPea_head_idle`（原版 `REANIM_GATLINGPEA` 的 `anim_head_idle`）
		AssetRegistry.get_scene("res://src/entities/character/components/zombie_plant_component/plant_head_gatling_pea.tscn"),
		10,
		[],
		false,
		^"",
		## 原版 `Zombie.cpp`：attach `anim_head1`，offset (65,-5)，rot 0.2，scale 水平镜像
		HeadAttach.new(false, Vector2(65, -5), 0.2, Vector2(-1, 1))
	),
	## ⬇️ 以下 8 只是本仓库扩展（原版一代没有），耐久 / 战力 / 权重不是 wiki 数据
	ZombieIds.SNOW_PEA_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.SNOW_PEA_ZOMBIE,
		PlantIds.SNOW_PEA,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/SnowPea_head.png"), Vector2(0, -6)),
		],
		3, 1200, Vector2.ZERO, 0.5
	),
	ZombieIds.TORCHWOOD_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.TORCHWOOD_ZOMBIE,
		PlantIds.TORCH_WOOD,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Torchwood_body.png"), Vector2(0, 4)),
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Torchwood_eyes1.png"), Vector2(-6, -6)),
		],
		3, 800, Vector2.ZERO, 0.5
	),
	ZombieIds.MAGNET_SHROOM_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.MAGNET_SHROOM_ZOMBIE,
		PlantIds.MAGNET_SHROOM,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Magnetshroom_head1.png"), Vector2(0, -2)),
		],
		3, 600, Vector2.ZERO, 0.5
	),
	ZombieIds.PUMPKIN_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.PUMPKIN_ZOMBIE,
		PlantIds.PUMPKIN,
		C_PLANT_HP_SHELL,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Pumpkin_front.png")),
		],
		3, 1000, Vector2.ZERO, 0.5
	),
	ZombieIds.CABBAGE_PULT_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.CABBAGE_PULT_ZOMBIE,
		PlantIds.CABBAGE_PULT,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Cabbagepult_head.png"), Vector2(0, -4)),
		],
		3, 1200, Vector2.ZERO, 0.5
	),
	ZombieIds.COB_CANNON_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.COB_CANNON_ZOMBIE,
		PlantIds.COB_CANNON,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/CobCannon_husk1.png"), Vector2(0, 12)),
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/CobCannon_cob.png"), Vector2(6, -12)),
		],
		5, 400, Vector2.ZERO, 0.5
	),
	ZombieIds.MELON_PULT_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.MELON_PULT_ZOMBIE,
		PlantIds.MELON_PULT,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Melonpult_body.png"), Vector2(0, -2)),
		],
		4, 700, Vector2.ZERO, 0.5
	),
	ZombieIds.WINTER_MELON_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.WINTER_MELON_ZOMBIE,
		PlantIds.WINTER_MELON,
		C_PLANT_HP_DEFAULT,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/WinterMelon_melon.png"), Vector2(0, -2)),
		],
		5, 500, Vector2.ZERO, 0.5
	),
	ZombieIds.TALL_NUT_ZOMBIE: ZomBotanyInfo.new(
		ZombieIds.TALL_NUT_ZOMBIE,
		PlantIds.TALL_NUT,
		## 原版总耐久 2470 = 本体 270 + 高坚果 2200；战力 4 / 权重 2000；第 10 波起才进随机池
		C_PLANT_HP_TALL_NUT,
		[
			PlantSprite.new(AssetRegistry.get_texture("res://pak/reanim/Tallnut_body.png")),
		],
		4, 2000, Vector2.ZERO, 0.5,
		## 动画头：播高坚果自己的 `Tallnut_idle`（原版 `REANIM_TALLNUT` 的 `anim_idle`）
		AssetRegistry.get_scene("res://src/entities/character/components/zombie_plant_component/plant_head_tall_nut.tscn"),
		10,
		## 原版掉到 2/3、1/3 血换 `TALLNUT_CRACKED1/2`
		[
			AssetRegistry.get_texture("res://pak/reanim/Tallnut_cracked1.png"),
			AssetRegistry.get_texture("res://pak/reanim/Tallnut_cracked2.png"),
		],
		## 原版高坚果僵尸藏掉领带
		true,
		## 动画头换裂纹的位置（高坚果的主体贴图节点叫 `Anim_idle`，不是 `Anim_face`）
		^"Body/BodyCorrect/Anim_idle",
		## 原版 `Zombie.cpp`：attach `Zombie_body`（跟身体走、不跟头），offset (37,0)，scale 0.8 且水平镜像
		HeadAttach.new(true, Vector2(37, 0), 0.2, Vector2(-0.8, 0.8))
	),
	}


## 取一种植物僵尸的数据；不是植物僵尸（或没配）时返回 null
static func get_info(zombie_type: StringName) -> ZomBotanyInfo:
	return C_ZOM_BOTANY_INFO.get(zombie_type)


## 是否属于植物僵尸
static func is_zom_botany(zombie_type: StringName) -> bool:
	return C_ZOM_BOTANY_INFO.has(zombie_type)
