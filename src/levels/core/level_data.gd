extends Resource
class_name ResourceLevelData

#region 关卡格式版本
## 关卡格式版本：1 = 旧格式（扁平字段，存档键由选关场景现场拼出）
## 2 = V2（save_key 显式化 / level_script 脚本钩子 / rules 玩法模块 / 控制流事件）
## 版本只分派「哪些字段有效、字段怎么读」，不要求迁移：
## V1 关卡一个字段都不用改就照旧跑，逐关迁移到 V2 时把它改成 2 即可。
@export var format_version: int = 1
#endregion

#region 选关数据,管理关卡存档
## 游戏模式(冒险，迷你游戏，解密，生存)，游戏选关场景
var game_mode: MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.Null
## 游戏关卡所在的页面
var level_page: int = 0
## 当前关卡标识符
var level_id: String = "test"
## 多轮游戏存档保存的文件名(无后缀)
var save_game_name: String
## 存档键：显式写死后就不再依赖选关场景的遍历顺序（旧版由 set_choose_level 现场拼出）
## 留空 = 回退到旧的自动拼法 str(game_mode)_str(level_page)_str(level_id)，所以 V1 关卡不用改
## 迁移方式：按当前运行时逻辑把值**反算出来写死**进 .tres —— 值一模一样，玩家的存档一个都不会丢
## （见 test/scenarios/tool_migrate_save_key.gd）
@export var save_key: String = ""

## 初始化选关数据
func set_choose_level(curr_game_mode: MainSceneRegistry.MainScenes, curr_level_page: int, curr_level_id: String) -> void:
	game_mode = curr_game_mode
	level_page = curr_level_page
	level_id = curr_level_id
	if save_key != "":
		save_game_name = save_key
		return
	save_game_name = str(game_mode) + "_" + str(level_page) + "_" + str(level_id)

#endregion

#region 关卡背景
## 游戏场景
@export var game_sences: MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.MainGameFront
## 游戏轮次:多轮游戏且自然出怪 自动更新自然出怪列表 -1表示无尽，不要用其余的数字表示无尽
@export var game_round: int = 1
## 多轮关卡是否按轮次存档/读档（只影响 game_round != 1 的关卡）
## false = 本关不支持「续玩」：切轮不写存档，进关也不读存档，永远从第 1 轮开始
## 砸罐子关（冒险 4-5）必须关：罐子不进存档，读档恢复不出任何进度，
## 只会让玩家一进关就跳到第 N 批罐子（玩家以为自己什么都没干），原版也是每次从头砸
@export var is_save_multi_round_data := true

## 本关使用的**场景名**（取值见 SceneSettingRegistry.SCENE_*，如 SceneSettingRegistry.SCENE_FOG）
## 非空 = 本场景的**具体信息**（主游戏槽位 / 底图 / BGM / 雾 / 昼夜 / 天降阳光）由那一份
## 场景脚本给出（见 SceneSettingBase），关卡脚本不用再逐项抄一遍。
## **在赋值那一刻就套用**，所以写在它后面的同名字段就是「覆盖」—— 这是关卡改场景设置的工具：
##   func _init() -> void:
##       scene_name = SceneSettingRegistry.SCENE_FRONT_DAY
##       game_BGM = ConstLevelData.GameBGM.MiniGame  ## 冒险 1-5：前院场景，但播小游戏曲
## 覆盖项多 / 要按运行时条件改时，改为覆写 apply_scene_setting()
## 留空 = 不套用场景设置，各字段照旧自己写（老关卡 / 自制关不受影响，行为与原来完全一致）
@export var scene_name: StringName = &"":
	set(value):
		scene_name = value
		apply_scene_setting()

@export_group("关卡背景参数")
## 本关卡使用的地图数据：格子、僵尸行、小推车类型全由它决定（见 docs/参考存档/地图实现.md）
## 留空时按 game_sences 取场景默认地图
@export var map_data: ResourceMapData
## 游戏背景
@export var game_BG: ConstLevelData.GameBg = ConstLevelData.GameBg.FrontDay
## 游戏背景音乐
@export var game_BGM: ConstLevelData.GameBGM = ConstLevelData.GameBGM.FrontDay
## 是否有雾
@export var is_fog: bool = false
## 是否有雨
@export var is_rain: bool = false
## 是否有闪电(雷雨:屏幕压暗,打雷时亮一下),需要 is_rain 为 true
## 原版只有冒险 4-10 是雷雨夜,表现见 src/world/background/main_game_rain.gd
@export var is_lightning: bool = false
## 是否为白天,控制蘑菇睡觉
@export var is_day: bool = true
## 是否天降阳光,传送带没有
@export var is_day_sun: bool = true
## 是否有小推车
@export var is_lawn_mover: bool = true
## 是否僵尸能进房
@export var is_zombie_can_home: bool = true
## 进关时相机的初始 x（可见区左上角的世界 x，口径见 MainGameCamera.CAM_POS_INIT）
## 留 NAN = 不配（默认）：相机停在背景最左侧（只拍到房子），再由流程拉去看僵尸 / 归位
## 想一进关就拍别处（草坪不在默认位置 / 特殊关）时在本关 _init() 里给个值，
## 关卡脚本同样写 `camera_init_x = MainGameCamera.CAM_POS_ORI.x`（= 归位位，最常用的取值，
## 写常量而不是写死 10：改背景尺寸 / 分辨率时不用回来改关卡）
## （只影响进关那一瞬，看僵尸 / 归位 / 失败流程的停靠点不变）
@export var camera_init_x: float = NAN
## 本关是否配了初始相机 x（NAN = 没配，走相机自己的进关停靠点）
func has_camera_init_x() -> bool:
	return not is_nan(camera_init_x)

## 套用 scene_name 对应的场景设置 —— **关卡脚本可覆写**
## 场景脚本给出这个场景的具体信息（槽位 / 底图 / BGM / 雾 / 昼夜 / 天降阳光），
## 由 scene_name 的 setter 在**赋值那一刻**调用，所以关卡脚本写在 scene_name 之后的
## 同名字段即为覆盖（单项覆盖用那一条就够，不必覆写本方法）。
## 需要按运行时条件改 / 覆盖项较多时才覆写：
##   func apply_scene_setting() -> void:
##       super.apply_scene_setting()
##       game_BGM = ConstLevelData.GameBGM.NoBGM
## 雨 / 闪电（is_rain / is_lightning）是关卡级天气开关，不在场景里，关卡自己写。
## scene_name 为空时什么都不做（老关卡 / 自制关照旧）。
func apply_scene_setting() -> void:
	if scene_name == &"":
		return
	var setting := SceneSettingRegistry.get_scene(scene_name)
	if setting == null:
		return
	game_sences = setting.game_sences
	game_BG = setting.game_BG
	game_BGM = setting.game_BGM
	is_fog = setting.is_fog
	is_day = setting.is_day
	is_day_sun = setting.is_day_sun

#endregion

#region 关卡流程
@export_group("关卡流程参数")
## 开局查看展示僵尸
@export var look_show_zombie: bool = true
## 是否可以选择卡片,传送带不可选择
@export var can_choosed_card: bool = true
## 开局是否播「准备…安放…植物」红字（砸罐子关不播：罐子摆好就能直接砸，见原版冒险 4-5）
## 只影响默认时间轴：留空 timeline 时按本开关决定是否生成一个「准备安放植物」事件，
## 配了自己的 timeline 就由时间轴上的那条事件决定（见 build_default_timeline）
@export var is_show_ready_set_plant: bool = true
## 戴夫对话资源（关卡开场播放，原版：冒险模式 1-5 / 2-1）
@export var crazy_dave_dialog: CrazyDaveDialogResource
## 多轮关卡「下一轮」开场的戴夫对话：下标 0 = 第 2 轮开场、下标 1 = 第 3 轮开场……
## 第 1 轮开场一律用 crazy_dave_dialog（原版冒险 4-5：砸完一批罐子后戴夫再摆一批并说一段话）
@export var crazy_dave_dialog_next_round: Array[CrazyDaveDialogResource] = []
## 开场戴夫对话是否只在首次通关前播放（原版：进入夜晚场景 2-1 的这段话只说一次）
@export var dave_dialog_only_first_playthrough: bool = false

@export_subgroup("关卡时间轴")
## 关卡时间轴:按顺序执行的关卡事件(戴夫对话 / 选卡 / 开战 / 一波…),见 ResourceLevelTimelineData
## 留空时按上面这些开关自动生成一条等价的默认时间轴(见 build_default_timeline),老关卡不用改
@export var timeline: ResourceLevelTimelineData

@export_subgroup("关卡掉落解锁道具")
## 解锁道具掉落时机之一:本关结束时掉落(最后一波僵尸清完、出奖杯之前),仅在首次通关本关时掉
## 用于真正由"通关本关"触发的解锁(原版冒险 3-4 掉车钥匙解锁商店),与商店解锁的存档时机对齐
@export var drop_unlock_on_level_complete: bool = false
## 解锁道具掉落时机之二:第几波僵尸(0 开始)携带解锁道具,该僵尸死亡时在原地掉落,-1 表示不走这条
## 用于解锁时点早于通关的表现,两种时机互斥,drop_unlock_on_level_complete 为 true 时忽略本值
@export var drop_unlock_wave: int = -1
## 解锁道具拾取后显示的提示文本,掉落时应填写
@export var drop_unlock_tip: String = ""
## 解锁道具的贴图,留空用默认的礼物盒(如 3-4 的车钥匙用 CarKeys.png)
@export var drop_unlock_icon: Texture2D
#endregion

#region 出怪参数
@export_group("出怪参数")
## 出怪模式
@export var monster_mode: ConstLevelData.E_MonsterMode = ConstLevelData.E_MonsterMode.Norm
@export_subgroup("正常出怪模式")
## 出怪倍率
@export var zombie_multy := 1
## 每轮游戏出怪波次，每10波生成1旗帜
@export var max_wave := 30
## 开局到第一波僵尸的延迟秒数（「开战」事件里等这个秒数再开第一波；
## 关卡流程要提前开波就用 `await start_first_wave()`，不读本值）
@export var first_wave_delay: float = 20.0
## 僵尸种类刷新列表 多轮游戏且自然出怪 自动更新自然出怪列表
@export var zombie_refresh_types: Array[CharacterRegistry.ZombieType] = [
	CharacterRegistry.ZombieType.Z001Norm, # 普通僵尸
	#CharacterRegistry.ZombieType.Z002Flag, # 旗帜僵尸
	CharacterRegistry.ZombieType.Z003Cone, # 路障僵尸
	CharacterRegistry.ZombieType.Z004PoleVaulter, # 撑杆僵尸
	CharacterRegistry.ZombieType.Z005Bucket, # 铁桶僵尸
]
## 是否有蹦极僵尸
@export var is_bungi := false
## 大波时生成的蹦极僵尸数量范围
@export var range_num_bungi: Vector2i = Vector2i(3, 5)

@export_subgroup("锤僵尸出怪模式（需调整对应墓碑参数）")
## 墓碑出怪倍率
@export var zombie_multy_hammer := 1
## 锤僵尸出怪波数
@export var max_wave_hammer_zombie := 10
## 初始化僵尸速度
@export var speed_zombie_init := 1.0
## 每波僵尸速度提升
@export var speed_zombie_add := 0.15
## 僵尸速度提升最大值
@export var speed_zombie_max := 2.0

@export_subgroup("全场加速（僵尸快跑）")
## 僵尸速度全局倍率（1 = 原速，2 = 跑两倍快）
## 与 speed_zombie_* 的区别：那三个是**锤僵尸模式**每波递增用的，这里是本关**恒定**的倍率；
## 走角色速度因子通道（E_Influence_Speed_Factor.LevelSpeed），移动 / 动画 / 啃食一起加速 ——
## 普通僵尸是动画驱动位移（MoveComponent.E_MoveMode.Ground），只有改动画速度才能真正跑起来
@export var speed_factor_zombie := 1.0
## 植物速度全局倍率（1 = 原速，2 = 射速翻倍）
## 同样走角色速度因子通道：攻击间隔（attack_cd / 倍率）/ 攻击动画 / 产阳光一起缩短
@export var speed_factor_plant := 1.0

@export_subgroup("墓碑参数")
## 是否有墓碑,即墓碑是否生成僵尸(原版:所有有墓碑的关卡,墓碑只在最后一大波放伏击僵尸)
@export var is_have_tombston := false
## 初始生成的墓碑数量(原版各关固定: 2-1~2-3=4, 2-4=7, 2-5=9, 2-6=7, 2-7=11, 2-8=7, 2-9=11, 2-10=13, 生存夜晚=5)
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Grave_(PvZ))
@export var init_tombstone_num := 0
## 墓碑是否会在大波前继续生长(原版只有「会补墓碑」的关卡:生存夜晚 / 锤僵尸类。
## 普通冒险夜晚关卡只有开局那一批,打完就没了)
## 开启后:每个大波(生存模式一轮的最终波)前先补 1~3 个墓碑,再由全部墓碑各放一只伏击僵尸
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Grave_(PvZ) "Survival: Night Levels")
@export var is_tombstone_respawn := false

#endregion

#region 卡片参数
@export_group("卡片参数")
## 卡槽模式，只有Norm可以选卡
## Both = 卡槽（选卡）+ 传送带同时出现，卡槽在上、传送带在下（见 docs/参考存档/卡槽与传送带.md）
@export var card_mode: ConstLevelData.E_CardMode = ConstLevelData.E_CardMode.Norm
## 是否有种子雨
@export var is_seed_rain := false
@export_subgroup("正常卡槽参数")
## 最大卡槽数量
## 0 = 不覆盖存档:出战卡槽数一律取存档的卡槽数(见 GlobalGameState.get_card_slot_num);
## 只有关卡要固定卡槽数时才写非 0 值(如原版 2-5 锤僵尸关的固定 3 张卡、僵尸公敌的可用僵尸数)
@export_range(0, 15) var max_choosed_card_num: int = 0
## 开始阳光数量
@export var start_sun: int = 50
## 系统预选卡片，按列表顺序入槽；预选卡不能在选卡时取消。
## 植物、普通僵尸、僵王共用这一个列表（旧版本是「植物列表 + 僵尸列表按下标配对」的两份结构）。
@export var prechosen_cards: Array[ResourceCardReference] = []
## 本关禁选的植物：这些卡在选卡界面**整张不出现**（原版迷你游戏「坚不可摧」：
## 阳光生产类向日葵 / 阳光菇 / 双子向日葵 与免费植物小喷菇 / 海蘑菇都不能带，
## 本关没有阳光收入，全靠开局那笔阳光和每波补给）。
## 模仿者是「同一张卡换个壳」（card_plant_type 不变），跟着一起禁掉，
## 消费见 CardSlotCandidate.set_plant_card_banned
@export var banned_plant_types_in_choose_card: Array[CharacterRegistry.PlantType] = []
## 卡槽是否被锁死(冒险模式:卡槽数 >= 已拥有植物卡数时,按顺序固定选卡,玩家无选择权)
## 运行期算出来的,不进 .tres:由 _resolve_adventure_locked_cards() 置位,
## 消费方是 is_no_choose_permission()(锁死 = 没有选卡权,直接跳过选卡阶段)
var is_locked_card_slot := false

@export_subgroup("传送带卡片参数")
## 传送带随机卡片与相对权重；权重为 0 的条目不参与抽取。
@export var conveyor_weights: Array[ResourceCardWeight] = []
## 固定顺序的传送带卡片；键为从 0 开始的生成序号，未指定的序号走随机池。
@export var conveyor_order: Dictionary[int, ResourceCardReference] = {}
@export var create_new_card_speed: float = 1

@export_subgroup("种子雨卡片参数")
## 种子雨随机卡片与相对权重；与传送带配置相互独立。
@export var seed_rain_weights: Array[ResourceCardWeight] = []
## 固定顺序的种子雨卡片；键为从 0 开始的生成序号，未指定的序号走随机池。
@export var seed_rain_order: Dictionary[int, ResourceCardReference] = {}

@export_subgroup("僵王参数")
## 自动出场僵王类型；Null 表示关闭自动出场，不限制卡牌召唤
@export var boss_type: CharacterRegistry.ZombieBossType = CharacterRegistry.ZombieBossType.Null
## 自动出场波次：0 为开战生成，1..max_wave 为指定波次生成
@export var boss_spawn_wave: int = 0
## 僵王初始血量；0 表示沿用僵王场景自带的上限（默认 40000）。
## 机甲破损阈值按新上限与场景上限的比例同步缩放，保持各关一致的破损观感。
@export var boss_hp: int = 0
## 僵王出生点固定在 ZB000Base.FIXED_SPAWN_POSITION（800x600 标定值），关卡不再配置
## 开启额外的「僵王全部死亡即胜利」条件，与自动出场是否配置独立
@export var win_on_boss_death := false
#endregion

## 本关是否配置了自动出场的僵王
func has_boss() -> bool:
	return boss_type != CharacterRegistry.ZombieBossType.Null

## 本关有没有常规卡槽（选卡界面 / 出战卡槽）；Both 模式下也有
func has_norm_card_slot() -> bool:
	return card_mode == ConstLevelData.E_CardMode.Norm \
		or card_mode == ConstLevelData.E_CardMode.Both

## 本关有没有传送带；Both 模式下也有
func has_conveyor_belt() -> bool:
	return card_mode == ConstLevelData.E_CardMode.ConveyorBelt \
		or card_mode == ConstLevelData.E_CardMode.Both

@export_subgroup("种植参数")
## 是否有铲子
@export var is_shovel := true
#endregion

#region 斗转星移传送门参数
@export_subgroup("斗转星移传送门参数")
## 迷你游戏「斗转星移」：草坪上摆两对传送门（一对方形一对圆形），
## 子弹 / 僵尸从一扇进、配对的另一扇出且方向不变；开启后由 PortalManager 接管
@export var is_portal_combat := false
## 传送门每隔多少秒随机换一次位置（<= 0 表示摆好后不再换）
@export var portal_reshuffle_interval := 15.0
#endregion

#region 罐子参数
@export_group("罐子参数")
## 是否为罐子模式，影响胜利条件
@export var is_pot_mode := false
@export var pot_mode: ConstLevelData.E_PotMode = ConstLevelData.E_PotMode.Null
@export var pot_col_range: Vector2i = Vector2i(4, 9)
## 结果随机罐子是否永久可观察罐内（打开后砸之前就能看到里面是什么）
## 目前只有自定义关卡在用（data/levels/params/vase_zombie.tres），内置关卡一律 false
@export var is_can_look_random_res_pot := false
## 戴夫提示罐的个数：摆好罐子后有几个「装着植物的罐子」会显示成绿色植物罐，
## 玩家一眼就知道那几个是植物（但不知道是哪种植物）。
## 原版冒险 4-5：第 1 批全是棕色罐（0）、第 2 批 2 个绿罐、第 3 批 3 个
@export var pot_hint_num: int = 0

@export_subgroup("固定生成，随机位置(从后往前随机放置罐子，满足列对齐，不足的格子使用结果随机罐子补齐)")
@export var random_pot_plant: Dictionary[CharacterRegistry.PlantType, int]
@export var random_pot_zombie: Dictionary[CharacterRegistry.ZombieType, int]
var random_pot_zombie_with_zombie_row_type: Dictionary[CharacterRegistry.ZombieRowType, Dictionary]
@export var plant_pot: Dictionary[CharacterRegistry.PlantType, int]
@export var zombie_pot: Dictionary[CharacterRegistry.ZombieType, int]
var zombie_pot_with_zombie_row_type: Dictionary[CharacterRegistry.ZombieRowType, Dictionary]
var pot_num_on_fixed_mode: int = 0
@export var random_pot_num_on_fixed_mode: Vector3i = Vector3i.ZERO

@export_subgroup("多轮砸罐子（按轮次覆盖上面的固定生成配置）")
## 每一轮罐子的配置，下标 0 = 第 1 轮。留空表示所有轮次都用上面那一份配置
## （解谜模式的砸罐子无尽关就是这么用的；原版冒险 4-5 三批罐子一批比一批难，必须逐轮覆盖）。
## 字典的键（都可省略，省略则沿用上一轮的值）：
##   random_pot_plant / plant_pot / random_pot_zombie / zombie_pot / random_pot_num_on_fixed_mode
##   pot_col_range（本轮罐子占的列，原版冒险 4-5：3 列 → 4 列 → 5 列）/ pot_hint_num（本轮戴夫提示罐个数）
@export var pot_config_on_round: Array[Dictionary] = []
## 第 1 批罐子配置的快照：apply_pot_config_on_round() 改写的就是上面这批顶层字段，
## 而顶层字段同时是第 1 批的数据源（init_para() 只读顶层字段），
## 不快照的话同一进程里第二次进本关（重玩 / 读档）第 1 批会变成上次玩到的那一批。
var pot_config_first_round: Dictionary = {}
#endregion

#region 我是僵尸模式
@export_group("我是僵尸模式")
@export var is_zombie_mode := false
@export var plant_col_on_zombie_mode: int = 4
@export var all_plants_weight_on_zombie_mode: Dictionary[CharacterRegistry.PlantType, int]
@export var all_must_plants_on_zombie_mode: Dictionary[CharacterRegistry.PlantType, int]

#endregion

#region 迷你游戏物品参数
@export_group("游戏物品参数")
@export_subgroup("保龄球红线")
@export var is_bowling_stripe := false
## 第几列植物格子之后(0开始)
@export var plant_cell_col_j: int = 2
@export var plant_cell_can_use: Dictionary[String, bool] = {
	"left_can_plant": true,
	"right_can_plant": true,
	"left_can_zombie": true,
	"right_can_zombie": true,
}

#endregion

## 存档之前的原始数据,如果因为存档改变, 删除存档后重新修复回来
var ori_data_on_save_data_update: Dictionary = {}
## 存档数据
var save_game_data_main_game: ResourceSaveGameMainGame

## 游戏开始会根据参数初始化一些硬性的参数。
## 卡槽: 传送带禁止选卡、禁止天降阳光。
## 出怪: 正常模式下刷新列表会按白名单过滤；禁止在列表中写 Z021Bungi，应使用 is_bungi。
func init_para() -> void:
	resolve_map_data()
	_apply_card_mode_constraints()
	_resolve_adventure_locked_cards()
	_init_zombie_refresh_from_whitelist()
	## 罐子配置：先恢复第 1 批的原始配置（上次玩到后面几批时顶层字段被改过），再重新快照
	reset_pot_config_first_round()
	snapshot_pot_config_first_round()
	_normalize_pot_col_range()
	_init_pot_mode()
	_apply_zombie_mode_rules()
	_maybe_load_multi_round_save()


func _apply_card_mode_constraints() -> void:
	match card_mode:
		ConstLevelData.E_CardMode.Norm, ConstLevelData.E_CardMode.Both:
			pass
		ConstLevelData.E_CardMode.ConveyorBelt:
			## 只有「纯传送带」才禁选卡 / 关天降阳光：
			## Both 模式有常规卡槽，出战卡照样由选卡决定，阳光也按关卡自己的配置走
			can_choosed_card = false
			is_day_sun = false
	if not has_norm_card_slot() and can_choosed_card:
		Log.debug("warning: 当前卡槽模式无法选卡, 已修改选卡为false")
		can_choosed_card = false


## 实际出战卡槽数:默认取存档的卡槽数(GlobalGameState.get_card_slot_num:
## 原版初始 ConstShop.BASE_CARD_SLOT_NUM 格,商店购买的卡槽扩充每买一次 +1,上限 ConstShop.MAX_CARD_SLOT_NUM)
## 关卡资源写了非 0 的 max_choosed_card_num 时,表示本关要覆盖存档的卡槽数
## (原版 2-5 锤僵尸关的固定 3 张卡、僵尸公敌的可用僵尸数这类关卡设计值)。
## 卡槽相关判定与卡槽创建统一走本函数,不要直接读 max_choosed_card_num
func get_max_choosed_card_num() -> int:
	if max_choosed_card_num > 0:
		return max_choosed_card_num
	return Global.global_game_state.get_card_slot_num()


## 冒险模式的出战卡一律由已拥有植物决定,关卡资源不写预选卡(写了也在此清掉)
## 卡槽数 >= 已拥有的植物卡数量时,按顺序固定选卡: 所有已拥有的植物按解锁顺序
## (即 curr_plant 的顺序)自动填满卡槽,玩家没有选择权(种子包不够挑)
## 卡槽数 < 已拥有植物卡数量时不给预选卡,玩家自由选择出战卡
func _resolve_adventure_locked_cards() -> void:
	is_locked_card_slot = false
	if game_mode != MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		return
	if not can_choosed_card or not has_norm_card_slot():
		return
	prechosen_cards.clear()
	var owned_cards: Array[CharacterRegistry.PlantType] = Global.global_game_state.curr_plant
	if owned_cards.is_empty():
		return
	if get_max_choosed_card_num() < owned_cards.size():
		return
	prechosen_cards = ResourceCardReference.create_plant_list(owned_cards)
	is_locked_card_slot = true
	Log.debug(str("冒险关卡锁定卡槽: 卡槽数") + str(get_max_choosed_card_num()) \
		+ str(" >= 拥有植物卡数") + str(owned_cards.size()) + str(",按顺序固定选卡"))


## 卡槽数在关卡运行期发生变化时(夜晚关卡开场戴夫卖出卡槽扩充)重新结算预选卡
## 卡槽数变大可能让"锁定卡槽"失效(已拥有植物卡数 <= 新的卡槽数),所以要重跑一次
func refresh_pre_choosed_card_on_card_slot_change() -> void:
	_resolve_adventure_locked_cards()


## 系统预选卡的有效数量
## 列表里可能夹着空引用或未注册的引用(关卡脚本手写 / 冒险模式未解锁),必须逐个判断
func get_valid_pre_choosed_card_num() -> int:
	var valid_num := 0
	for card_reference in prechosen_cards:
		if card_reference != null and card_reference.is_valid() and AllCards.is_battle_card(card_reference):
			valid_num += 1
	return valid_num


## 玩家是否没有选卡权(选卡界面没有任何可操作空间,应当跳过选卡阶段)
## 三种情况:
##   1. 不能选卡(can_choosed_card = false,传送带 / 金币卡槽等卡槽模式不是 Norm 的关卡)
##      出战卡由关卡给定的卡槽现场发牌,压根没有普通选卡界面,等价于没有选卡权。
##      少了这一条,这类关卡固化时间轴上的「选卡」事件会去操作不存在的普通卡槽
##      (CardManager.card_slot_norm 为 null)而报错卡半路,关卡永远进不到开战
##      (冒险 1-10 / 2-10 / 3-10 / 4-10 / 5-5 / 5-10 这些传送带关都踩过,见 docs/工作记录 的僵王关地图)
##   2. is_locked_card_slot(冒险模式):卡槽数 >= 已拥有植物卡数,已拥有的卡被全部自动选入,
##      待选区已经没有多余的卡可挑(即使卡槽没满也没得选)
##   3. 系统预选卡把出战卡槽填满(关卡资源自带预选卡的关卡):预选卡不可取消,
##      卡槽没有空位,玩家也放不进任何卡
## 例:某关卡卡槽 1、预选卡 [豌豆射手] -> 槽数 < 拥有卡数不锁槽,
## 但唯一卡槽已被预选卡占满,仍应跳过
## 注:冒险模式的预选卡由 _resolve_adventure_locked_cards() 按已拥有植物生成,
## 关卡资源不写;条件 3 当前只对非冒险模式(自带预选卡的关卡)有意义
func is_no_choose_permission() -> bool:
	if not can_choosed_card:
		return true
	if is_locked_card_slot:
		return true
	return get_valid_pre_choosed_card_num() >= get_max_choosed_card_num()


## 第 round_index 轮(1 起)开场要播的戴夫对话，没有则返回 null。
## 第 1 轮就是 crazy_dave_dialog；第 2 轮起取 crazy_dave_dialog_next_round
## (原版冒险 4-5:砸完一批罐子后戴夫再摆一批，同时说一段话)
func get_crazy_dave_dialog_on_round(round_index: int) -> CrazyDaveDialogResource:
	if round_index <= 1:
		return crazy_dave_dialog
	var index: int = round_index - 2
	if index < 0 or index >= crazy_dave_dialog_next_round.size():
		return null
	return crazy_dave_dialog_next_round[index]


## 本关任意一轮有没有戴夫对话
## 一轮都没有的话，「关卡戴夫对话」事件是空转（run() 取不到对话直接 return）
func has_dave_dialog_on_any_round() -> bool:
	for round_index in range(1, maxi(game_round, 1) + 1):
		if get_crazy_dave_dialog_on_round(round_index) != null:
			return true
	return false


## 本关**有没有可能**出现戴夫推销卡槽扩充（只按关卡数据静态判断）
## 运行时还要看卡槽是否已满 / 金币够不够（见 DaveSellManager.is_can_sell），
## 这里只排掉「本关永远不可能推销」的情况。
## **推销写不写在本关流程里是关卡脚本的事**（run_flow 开头 `await dave_sell_card_slot()`），
## 本关有戴夫对话时就别写那一句，免得开场连播两段戴夫。
func is_dave_sell_possible() -> bool:
	## 商店已解锁（通关 3-4 拿到车钥匙）：卡槽扩充改由商店出售，戴夫不再开场推销
	## —— 与 DaveSellManager.is_can_sell() 里的同一判据互为保险：这里先挡一道，
	## 关卡脚本那句快捷工具整句空转，连推销事件都不会创建
	if Global.global_game_state.is_shop_unlocked():
		return false
	## 只有冒险模式的出战卡槽吃商店 / 推销的扩充
	if game_mode != MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		return false
	## 2-2 起才开始推销（金币从 2-1 掉落），之前的关卡永远不会推销
	if get_adventure_level_index() < ConstUnlockLevel.DAVE_SELL_ADVENTURE_LEVEL:
		return false
	## 不能选卡的关卡（传送带）买了卡槽也没地方用
	return can_choosed_card


## 本关的冒险模式关卡序号（1-1 = 1 …… 5-10 = 50）；非冒险模式返回 0
## （存档名格式 "<模式>_<...>_<序号>"，与 GlobalGameState.get_adventure_level_on_save_game_name 同规则）
func get_adventure_level_index() -> int:
	var parts := save_game_name.split("_")
	if parts.size() < 3:
		return 0
	if int(parts[0]) != MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		return 0
	return int(parts[2])


#region 关卡时间轴
## 默认时间轴缓存:本关没配 timeline 时只生成一次,多轮游戏每轮复用
var _default_timeline: ResourceLevelTimelineData

## 本关实际使用的时间轴:显式配了 timeline 就用它,否则按现有开关生成等价的默认时间轴
func get_timeline() -> ResourceLevelTimelineData:
	if timeline != null and not timeline.events.is_empty():
		return timeline
	return build_default_timeline()


## 按本关现有开关生成等价的默认时间轴
## 把原本写死在 MainGameManager 开场流程里的顺序搬进数据:
## 戴夫推销 -> 戴夫对话 -> 开场教程 -> 保龄球红线 -> 展示僵尸 -> 选卡 -> 准备安放植物 -> 开战
## 这样老关卡一个字段都不用改就照旧跑,要改流程就配一条自己的 timeline
## （一种事件一个脚本，这里 new 的就是各事件脚本，参数用默认值）
func build_default_timeline() -> ResourceLevelTimelineData:
	if _default_timeline != null:
		return _default_timeline
	var data := ResourceLevelTimelineData.new()
	## 只生成本关**真实生效**的步骤：下面几个开关不满足时，对应事件的 run() 就是直接 return
	## （空转步骤），生成出来白占一行，还会让人误以为本关有这一步。
	## 判据见各事件脚本的 run() 与下面 is_dave_sell_possible() 等三个辅助方法
	if is_dave_sell_possible():
		_append_timeline_event(data, LevelTimelineEventDaveSell.new(), "戴夫推销卡槽扩充", true)
	## 对话内容取关卡当轮的对话(第 1 轮 crazy_dave_dialog,之后 crazy_dave_dialog_next_round)
	if has_dave_dialog_on_any_round():
		_append_timeline_event(data, LevelTimelineEventDaveDialog.new(), "关卡戴夫对话")
	if is_bowling_stripe:
		_append_timeline_event(data, LevelTimelineEventBowlingStripe.new(), "保龄球红线", true)
	if look_show_zombie:
		_append_timeline_event(data, LevelTimelineEventShowZombie.new(), "展示僵尸")
		if can_choosed_card:
			_append_timeline_event(data, LevelTimelineEventChooseCard.new(), "选卡")
		else:
			## 不能选卡:相机在预览位停 3 秒再归位开战(等价旧的 no_choosed_card_start_game)
			var wait_event := LevelTimelineEventWait.new()
			wait_event.wait_time = 3.0
			_append_timeline_event(data, wait_event, "不选卡时相机停留")
			_append_timeline_event(data, LevelTimelineEventCameraBack.new(), "相机归位")
	## 小推车登场：出生在屏幕外左侧，按从下到上的顺序开到位（本关没开推车时事件自己跳过）
	_append_timeline_event(data, LevelTimelineEventLawnMover.new(), "初始化小推车")
	## 「准备…安放…植物」红字：砸罐子关不播（罐子摆好就能直接砸，见原版冒险 4-5）
	if is_show_ready_set_plant:
		_append_timeline_event(data, LevelTimelineEventReadySetPlant.new(), "准备安放植物")
	_append_timeline_event(data, LevelTimelineEventStartBattle.new(), "开战")
	## 开战事件自己会等到本段打完（砸罐子：罐子全开 + 僵尸清空；出怪关：最后一波刷完 + 僵尸清空），
	## 所以默认轴末尾不再单独挂别的事件
	_default_timeline = data
	return data


## 往时间轴上加一个事件：填通用参数（各事件自己的参数在外面配）
func _append_timeline_event(
	data: ResourceLevelTimelineData,
	new_event: ResourceLevelTimelineEvent,
	event_note: String,
	is_first_round_only := false
) -> void:
	new_event.note = event_note
	new_event.is_first_round_only = is_first_round_only
	data.events.append(new_event)
#endregion


func _init_zombie_refresh_from_whitelist() -> void:
	if monster_mode != ConstLevelData.E_MonsterMode.Norm:
		return
	resolve_map_data()
	if map_data == null:
		return
	## 行类型由地图数据的僵尸行决定（原本是第三份手工维护的表）
	whitelist_refresh_zombie_types = Global.global_read_data.whitelist_refresh_zombie_types_with_zombie_row_type[map_data.get_default_zombie_row_type()]
	zombie_refresh_types = filter_invalid_zombie_refresh_types(zombie_refresh_types, whitelist_refresh_zombie_types)


## 解析地图数据。主游戏场景在 _enter_tree 就会调用它，
## 保证各子管理器 _ready（生成格子/僵尸行）时 map_data 已经就绪
func resolve_map_data() -> void:
	if map_data != null:
		return
	map_data = Global.main_scene_registry.get_default_map_data(game_sences) as ResourceMapData
	if map_data == null:
		Log.error("关卡 %s 没有可用的地图数据（game_sences=%s）" % [level_id, str(game_sences)])


func _normalize_pot_col_range() -> void:
	if pot_mode == ConstLevelData.E_PotMode.Null:
		return
	if pot_col_range.x > pot_col_range.y:
		pot_col_range = Vector2i(pot_col_range.y, pot_col_range.x)
	Log.debug(str("生成罐子的列数为") + str(pot_col_range.x) + str("（含）到") + str(pot_col_range.y) + str("（不含）"))


func _init_pot_mode() -> void:
	if pot_mode == ConstLevelData.E_PotMode.Fixd:
		_init_pot_mode_fixed()


## 切换到第 round_index 轮(1 起)的罐子配置：多轮砸罐子关每批罐子不一样
## (原版冒险 4-5:第一批只有豌豆 / 窝瓜且植物比僵尸多，第三批才出铁桶 / 舞王)。
## 只在固定生成模式生效;配置缺失 / 越界时保持当前配置不变。
## 由 PlantCellManager 在每轮创建罐子之前调用(见 start_next_game_plant_cell_manager_update)
func apply_pot_config_on_round(round_index: int) -> void:
	if pot_config_on_round.is_empty():
		return
	var index: int = round_index - 1
	if index < 0 or index >= pot_config_on_round.size():
		Log.warn(
			str("第 ") + str(round_index) + str(" 轮没有对应的罐子配置(共 ") \
			+ str(pot_config_on_round.size()) + str(" 份)，沿用上一轮的罐子配置")
		)
		return
	## 从第 1 批的原始配置出发，依次覆盖到第 round_index 批：
	## 每份配置里省略的键沿用上一批的值，不复位的话反复切轮次会把配置一层层叠上去，
	## 而且第 1 批（init_para 读顶层字段）会被后面几批的配置顶掉
	reset_pot_config_first_round()
	for i in range(index + 1):
		_apply_pot_config_on_round(pot_config_on_round[i])
	_init_pot_mode_fixed()


## 记录第 1 批罐子的配置，作为每次切轮次的起点（见 apply_pot_config_on_round）
func snapshot_pot_config_first_round() -> void:
	pot_config_first_round = {
		"random_pot_plant": random_pot_plant.duplicate(true),
		"plant_pot": plant_pot.duplicate(true),
		"random_pot_zombie": random_pot_zombie.duplicate(true),
		"zombie_pot": zombie_pot.duplicate(true),
		"random_pot_num_on_fixed_mode": random_pot_num_on_fixed_mode,
		"pot_col_range": pot_col_range,
		"pot_hint_num": pot_hint_num,
	}


## 把罐子配置恢复成第 1 批（顶层字段的原始值）
func reset_pot_config_first_round() -> void:
	if pot_config_first_round.is_empty():
		return
	random_pot_plant = pot_config_first_round["random_pot_plant"].duplicate(true)
	plant_pot = pot_config_first_round["plant_pot"].duplicate(true)
	random_pot_zombie = pot_config_first_round["random_pot_zombie"].duplicate(true)
	zombie_pot = pot_config_first_round["zombie_pot"].duplicate(true)
	random_pot_num_on_fixed_mode = pot_config_first_round["random_pot_num_on_fixed_mode"] as Vector3i
	pot_col_range = pot_config_first_round["pot_col_range"] as Vector2i
	pot_hint_num = int(pot_config_first_round["pot_hint_num"])


## 覆盖一份轮次罐子配置
func _apply_pot_config_on_round(config: Dictionary) -> void:
	## 重新拷贝一份再赋值：下面的 _init_pot_mode_fixed() 会按黑名单原地删键，
	## 不能直接改数组里存的那份（否则第二次进本关时配置已经被改过）
	if config.has("random_pot_plant"):
		random_pot_plant = to_plant_num_dict(config["random_pot_plant"])
	if config.has("plant_pot"):
		plant_pot = to_plant_num_dict(config["plant_pot"])
	if config.has("random_pot_zombie"):
		random_pot_zombie = to_zombie_num_dict(config["random_pot_zombie"])
	if config.has("zombie_pot"):
		zombie_pot = to_zombie_num_dict(config["zombie_pot"])
	if config.has("random_pot_num_on_fixed_mode"):
		random_pot_num_on_fixed_mode = config["random_pot_num_on_fixed_mode"] as Vector3i
	## 每批罐子占的列数可以不一样（原版冒险 4-5：3 列 → 4 列 → 5 列）
	if config.has("pot_col_range"):
		pot_col_range = config["pot_col_range"] as Vector2i
		_normalize_pot_col_range()
	## 每批戴夫提示罐的个数（原版冒险 4-5：不提示 → 2 个 → 3 个）
	if config.has("pot_hint_num"):
		pot_hint_num = int(config["pot_hint_num"])
	_init_pot_mode_fixed()


## 把配置里的 untyped 字典转成「植物类型 → 个数」
func to_plant_num_dict(source: Dictionary) -> Dictionary[CharacterRegistry.PlantType, int]:
	var out: Dictionary[CharacterRegistry.PlantType, int] = {}
	for key in source:
		out[key as CharacterRegistry.PlantType] = int(source[key])
	return out


## 把配置里的 untyped 字典转成「僵尸类型 → 个数」
func to_zombie_num_dict(source: Dictionary) -> Dictionary[CharacterRegistry.ZombieType, int]:
	var out: Dictionary[CharacterRegistry.ZombieType, int] = {}
	for key in source:
		out[key as CharacterRegistry.ZombieType] = int(source[key])
	return out


func _init_pot_mode_fixed() -> void:
	pot_num_on_fixed_mode = 0
	for plant_type in random_pot_plant.keys():
		if Global.global_read_data.blacklist_plant_types_with_pot.has(plant_type):
			random_pot_plant.erase(plant_type)
			Log.debug(str("warning: 植物") + str(Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)) + str("在罐子刷新黑名单中，已删除该植物"))
		else:
			pot_num_on_fixed_mode += random_pot_plant[plant_type]
	for plant_type in plant_pot.keys():
		if Global.global_read_data.blacklist_plant_types_with_pot.has(plant_type):
			plant_pot.erase(plant_type)
			Log.debug(str("warning: 植物") + str(Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName)) + str("在罐子刷新黑名单中，已删除该植物"))
		else:
			pot_num_on_fixed_mode += plant_pot[plant_type]
	for zombie_type in random_pot_zombie.keys():
		if Global.global_read_data.blacklist_zombie_types_with_pot.has(zombie_type):
			random_pot_zombie.erase(zombie_type)
			Log.debug(str("warning: 僵尸") + str(Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName)) + str("在罐子刷新黑名单中，已删除该僵尸"))
		else:
			pot_num_on_fixed_mode += random_pot_zombie[zombie_type]
	for zombie_type in zombie_pot.keys():
		if Global.global_read_data.blacklist_zombie_types_with_pot.has(zombie_type):
			zombie_pot.erase(zombie_type)
			Log.debug(str("warning: 僵尸") + str(Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName)) + str("在罐子刷新黑名单中，已删除该僵尸"))
		else:
			pot_num_on_fixed_mode += zombie_pot[zombie_type]
	pot_num_on_fixed_mode += random_pot_num_on_fixed_mode.x + random_pot_num_on_fixed_mode.y + random_pot_num_on_fixed_mode.z
	Log.debug(str("固定模式的罐子需求总数（包括结果固定罐子和结果随机罐子）为：") + str(pot_num_on_fixed_mode))
	random_pot_zombie_with_zombie_row_type = get_pot_zombie_with_row_type_pot_on_fiexd_mode(random_pot_zombie)
	zombie_pot_with_zombie_row_type = get_pot_zombie_with_row_type_pot_on_fiexd_mode(zombie_pot)


func _apply_zombie_mode_rules() -> void:
	if is_zombie_mode:
		is_zombie_can_home = false


func _maybe_load_multi_round_save() -> void:
	## 不支持续玩的多轮关卡（is_save_multi_round_data = false）不读存档：
	## 读了会直接跳到第 N 轮，而本关没有可恢复的进度（罐子不进存档）
	if game_round != 1 and is_save_multi_round_data:
		Log.debug("更新多轮游戏存档数据")
		update_data_with_save_game_data()


## 罐子固定生成模式下，获取僵尸按行类型生成的分类字典
func get_pot_zombie_with_row_type_pot_on_fiexd_mode(pot_zombie_dic: Dictionary) -> Dictionary[CharacterRegistry.ZombieRowType, Dictionary]:
	var pot_zombie_with_row_type: Dictionary[CharacterRegistry.ZombieRowType, Dictionary] = {
		CharacterRegistry.ZombieRowType.Land: {},
		CharacterRegistry.ZombieRowType.Pool: {},
		CharacterRegistry.ZombieRowType.Both: {},
	}
	for zombie_type in pot_zombie_dic.keys():
		var zombie_row_type: CharacterRegistry.ZombieRowType = Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
		pot_zombie_with_row_type[zombie_row_type][zombie_type] = pot_zombie_dic[zombie_type]

	return pot_zombie_with_row_type


## 更新数据 (存档相关)
func update_data_with_save_game_data() -> void:
	var path = get_save_game_path()
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is ResourceSaveGameMainGame:
			save_game_data_main_game = res
			Log.debug(str("加载关卡数据存档成功：") + str(path))
		else:
			Log.error("加载的资源类型不对: “%s” 不是 ResourceSaveGameMainGame" % path)
			save_game_data_main_game = null
	else:
		Log.debug(str("关卡数据存档不存在：") + str(path))
		save_game_data_main_game = null


## 删除存档
func delete_game_data():
	save_game_data_main_game = null
	var path = get_save_game_path()

	if ResourceLoader.exists(path):
		var err = DirAccess.remove_absolute(path)
		if err == OK:
			Log.debug(str("删除存档成功：") + str(path))
			return true
		else:
			Log.error("删除存档失败: %s 错误码 %d" % [path, err])
			return false

#region 自然刷怪过滤
## 当前场景可以刷新的僵尸
var whitelist_refresh_zombie_types: Array[CharacterRegistry.ZombieType] = []

## 根据白名单过滤出怪类型列表。
## 不修改入参 zombie_types，返回新数组。若列表中含 Z021Bungi，会将本资源的 is_bungi 设为 true。
func filter_invalid_zombie_refresh_types(
	zombie_types: Array[CharacterRegistry.ZombieType],
	curr_whitelist_refresh_zombie_types: Array[CharacterRegistry.ZombieType]
) -> Array[CharacterRegistry.ZombieType]:
	var out: Array[CharacterRegistry.ZombieType] = []
	var is_err := false
	for zt: CharacterRegistry.ZombieType in zombie_types:
		if not curr_whitelist_refresh_zombie_types.has(zt):
			Log.warn(
				"warning: 出怪刷新列表中",
				Global.character_registry.get_zombie_info(zt, CharacterRegistry.ZombieInfoAttribute.ZombieName),
				"不在当前场景可以自然刷怪列表"
			)
			is_err = true
			continue
		if zt == CharacterRegistry.ZombieType.Z021Bungi:
			Log.debug("warning: 出怪刷新列表禁止使用 Z021Bungi ,已修改为选择 is_bungi 参数")
			is_bungi = true
			is_err = true
			continue
		out.append(zt)

	if is_err:
		Log.debug("将上述出怪刷新列表错误僵尸删除")

	return out

#endregion

#region 全场加速（僵尸快跑）
## 给一个角色下发本关的**僵尸**速度倍率（speed_factor_zombie）
## 调用时机：角色 add_child 进场景树之后 —— 移动 / 攻击组件是在 _ready 里才连上 signal_update_speed 的
func apply_speed_factor_to_zombie(zombie: Character000Base) -> void:
	_apply_speed_factor(zombie, speed_factor_zombie)

## 给一个角色下发本关的**植物**速度倍率（speed_factor_plant）
func apply_speed_factor_to_plant(plant: Character000Base) -> void:
	_apply_speed_factor(plant, speed_factor_plant)

## 1.0 = 原速，直接跳过，免得给所有默认关卡白 emit 一次信号
func _apply_speed_factor(character: Character000Base, speed_factor: float) -> void:
	if speed_factor == 1.0:
		return
	character.update_speed_factor(speed_factor, Character000Base.E_Influence_Speed_Factor.LevelSpeed)

#endregion

#region 关卡给僵尸的额外初始化参数
## 本关给「正常出战僵尸」追加的初始化参数 —— **关卡脚本可覆写**
##
## 返回一张 `Zombie000Base.E_ZInitAttr → 值` 的表，由 `ZombieManager.create_norm_zombie()`
## 在生成僵尸时并进 `zombie_init_para`（本表写了的键覆盖出怪方给的同名键）。
##
## 本体只负责「并表」，不认识任何具体关卡 / 玩法（§1-8）：只有一关要用的角色设定
## （如迷你游戏 06「隐形战争」让出战僵尸本体隐形）由关卡脚本自己写在这里，
## 见 src/levels/mode_minigame/minigame_06_invisi_ghoul.gd
func get_zombie_init_para_extra() -> Dictionary:
	return {}
#endregion

#region 存档
## 读档系统只能从空白场景读档
## 获取存档路径
func get_save_game_path() -> String:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(Global.user_manager.curr_user_name + "/" + Global.save_service.MAIN_GAME_SAVE_DIR_NAME):
		dir.make_dir(Global.user_manager.curr_user_name + "/" + Global.save_service.MAIN_GAME_SAVE_DIR_NAME)

	return "user://" + Global.user_manager.curr_user_name + "/" + Global.save_service.MAIN_GAME_SAVE_DIR_NAME + "/" + save_game_name + ".tres"

#endregion
