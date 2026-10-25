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
## 迁移方式：**读权威值再写死**（不要推算 —— level_id 来自选关场景遍历按钮的顺序）：
##   `test/scenarios/tool_dump_save_keys.gd`（只读，跑一遍 3 个选关场景 dump 出权威键；
##     冒险模式**没有**选关界面，它的 level_id 就是关卡序号，走 `GlobalGameState.get_adventure_save_game_name()`）
##   → `test/scenarios/tool_write_save_keys.gd`（写入：改 `.gd` 里 `save_key = "..."` 那一行）
##   → `test/scenarios/probe_save_key.gd`（**另起一个进程**回读校验，同进程内关卡资源被选关场景引用、缓存顶不掉）
## ✅ 2026-10-22 已补齐：全 155 关（冒险 50 关 × 正本 / 二周目变体 + 迷你 / 解密 / 生存 55 关），见 docs/TODO清单.md 的 U-22。
##   ⚠️ 已写死的键**不要再动**：迷你 / 解密有 28 关的写死值与「当前遍历顺序拼出来的值」对不上，
##      那是既有事实 —— **写死值才是权威**（玩家存档里用的就是它），拿当前拼法去「纠正」等于把进度整体挪位。
## ⚠️ 只补 `save_key`，**不要**顺手把 `format_version` 改成 2 —— 那是「字段怎么读」的开关，属行为变更。
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
## ⚠️ 这里有三个都像「是哪一套场景」的字段，它们**粒度不同，不是重复表达**（U-09 已核实）：
##   - `game_sences`：用哪个**主场景文件**（前院 / 泳池 / 屋顶 三个槽位，见 MainSceneRegistry）；
##   - `game_BG`：用哪套**背景视觉**（比上者多了「夜」「雾」—— 前院关照样可以是夜）；
##   - `scene_name`：套用哪套**预设组合**（SceneSettingRegistry），选中后由
##     `apply_scene_setting()` 一次性展开、覆写上面这些字段。
## 优先级是单向明确的：**先按 scene_name 展开预设，再让关卡脚本在覆写的
## `apply_scene_setting()` 里改自己要改的**（见本文件该函数上方的示例）。
## 所以不必把它们收敛成一个字段 —— 合成一个反而表达不了「前院 + 夜」这种组合。
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
## 二周目及以后用的地图数据：留空 = 沿用 map_data（绝大多数关卡都留空）
## ★ 现在它是【兜底】：二周目起加载的是**另一套关卡脚本**（adventure_XX_YY_round2.gd，
##   见 docs/参考存档/二周目.md §6），变体脚本自己把 map_data 写成满草皮图；
##   只有「这一关没有变体文件、回退到正本」时才会走到这里。
## 原用途（原版那条「二周目起 1-1 ~ 1-3 直接给满 5 行草皮」）只有那三关填了它，
## 由 resolve_map_data() 在子管理器按图建格之前换过去。
@export var map_data_from_second_round: ResourceMapData
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
## 是否有血月事件（DLC 版 Moon 章的关卡级 gimmick，活动关也借用到 Night 上）：
## 全场僵尸大幅加速 + 画面变红。由场景开关带出来（scene_moon_roof.gd 给 true），关卡也能自己覆盖。
## 触发节奏 / 时长 / 强度见 `blood_moon_manager.gd`
@export var is_blood_moon: bool = false
## 血月是否**常驻**（开战即挂上、整关不退，DLC 活动关 Hemophilia 那类）
@export var is_blood_moon_permanent: bool = false
## 本关场景是否有专属的血月底图（有 = 换底图，没有 = 把底图染红）
@export var is_blood_moon_bg_art: bool = false
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
	is_blood_moon = setting.is_blood_moon
	is_blood_moon_permanent = setting.is_blood_moon_permanent
	is_blood_moon_bg_art = setting.is_blood_moon_bg_art

#endregion

#region 关卡流程
@export_group("关卡流程参数")
## 开局查看展示僵尸
@export var look_show_zombie: bool = true
## 是否可以选择卡片,传送带不可选择
@export var can_choosed_card: bool = true
## 开局是否播「准备…安放…植物」红字（砸罐子关不播：罐子摆好就能直接砸，见原版冒险 4-5）
## 关卡脚本的默认流程（LevelScriptBase.run_flow）里是否播「准备…安放…植物」红字
@export var is_show_ready_set_plant: bool = true
## 戴夫对话资源（关卡开场播放，原版：冒险模式 1-5 / 2-1）
@export var crazy_dave_dialog: CrazyDaveDialogResource
## 多轮关卡「下一轮」开场的戴夫对话：下标 0 = 第 2 轮开场、下标 1 = 第 3 轮开场……
## 第 1 轮开场一律用 crazy_dave_dialog（原版冒险 4-5：砸完一批罐子后戴夫再摆一批并说一段话）
@export var crazy_dave_dialog_next_round: Array[CrazyDaveDialogResource] = []
## 开场戴夫对话是否只在首次通关前播放（原版：进入夜晚场景 2-1 的这段话只说一次）
@export var dave_dialog_only_first_playthrough: bool = false

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

@export_subgroup("本关通关掉落")
## 本关通关掉的那个**战利品的名字** —— **直接编码在本关脚本里**（冒险模式每关 `_init()` 各写一份）
## 与上面的「解锁道具」是两条线:解锁道具是"掉钥匙解锁商店"这种功能解锁,
## 本组是本关自己的通关奖励(原版戴夫给的礼物盒 / 铁铲 / 车钥匙 / 玉米卷 / 新植物种子包)。
## 名字 -> 贴图 / 植物编号 / 提示文本那张表在 `src/items/drop/loot_registry.gd`(LootRegistry):
##   · "shovel" / "almanac" / "car_keys" / "taco" / "watering_can" 这类 = 道具战利品(礼物盒换贴图)
##   · "sunflower_seed_packet" 这类 = 新植物种子包(种子包是运行时拼的,没有独立贴图)
##   · "trophy" = 奖杯:本关没有奖励的关卡(1-9 / 2-9 / … / 5-10)就写它
##   · 留空 = 本关没有奖励,走 `win_on_level_complete()` 的奖杯兜底
## 植物类同时是"本关解锁哪株植物"的答案源(见 LevelRegistry.get_adventure_level_reward_plant),
## 项目里没有任何"关卡序号 -> 战利品"的表,改本关掉什么就改这里。
## 掉落时机在关卡流程末尾:`await gain(level_complete_loot)`,见 docs/参考存档/关卡时间轴.md
@export var level_complete_loot: String = ""
#endregion

#region 出怪参数
@export_group("出怪参数")
## 出怪模式
@export var monster_mode: ConstLevelData.E_MonsterMode = ConstLevelData.E_MonsterMode.Norm
@export_subgroup("正常出怪模式")
## 生存模式难度：非 None 时，多轮出怪改走**原版生存规则**（见
## `ZombieManager.update_multi_round_zombie_refresh_types`）：
##   第 1 轮固定起手，之后每轮按档位从地图允许的僵尸里随机抽一批；
##   普通档还只出「潜水僵尸及以前」的前期僵尸。普通 / 困难 / 无尽各填对应值，
##   旗数由 `game_round`（普通困难 5 轮、无尽 -1）+ 每轮波数（普通 10、困难/无尽 20）决定。
@export var survival_difficulty: ConstLevelData.E_SurvivalDifficulty = ConstLevelData.E_SurvivalDifficulty.None
## 出怪倍率
##
## **必须按原版模式倍率填**（`Board::PickZombieWaves()` 的 "Certain levels multiply the
## zombie points" 段，Board.cpp:666-686；两份本机 C++ 参照交叉验证一致）：
##   COLUMN 排山倒海 = 6；小小大僵尸 / 坚果保龄球1·2 = 4；
##   迷你Boss（冒险 1-10/2-10/3-10）/ 暴雨夜（冒险 4-10）= 3；
##   铲子 / 蹦极闪电战（冒险 5-5）/ 传送门 / 隐形 = 2；**其余全部 1**。
## 历史上这里被当成「加料旋钮」随手调（植物僵尸两关曾因此每波 10 倍出怪，2026-10-24 修正），
## 调它之前先对照原版倍率分支，没有依据就写 1。全表见 docs/参考存档/僵尸波次.md「模式倍率」。
@export var zombie_multy := 1
## 波次基础点数公式：默认 Norm（`波/3+1`，二周目冒险自动升档）。
## 只有原版另写公式的两类关要显式赋值：坚不可摧（迷你16）= LastStand、
## 生存模式 11 关 = Survival（第 1 轮仍走 Norm，与原版 `mSurvivalStage > 0` 分支一致）。
## 推导与化简见 `ZombieWaveCreateManager.calculate_base_wave_points()`。
@export var wave_points_formula: ConstLevelData.E_WavePointsFormula = ConstLevelData.E_WavePointsFormula.Norm
## 每轮游戏出怪波次，每10波生成1旗帜
##
## ⚠️ 同名的「波数」在本项目里有三份，改之前先认准是哪一份：
##   1. **本字段**（`level_data.max_wave`）= 每轮波数，**只有 3 个小游戏关直接赋值**
##      （05 / 07 / 09；15 关走 `max_wave_hammer_zombie`、16 关把波数当 `start_battle()` 的入参）。
##   2. `ZombieWaveManager.max_wave` = **本关累计总波数**（多轮关卡按轮往上加，
##      见 `apply_max_wave()` 与 `start_next_game_zombie_wave_mananger_update()`）。
##   3. 其余 100+ 关的波数是**「开战」事件带进去的**（`level_script_base.start_battle()`
##      → `LevelTimelineEventStartBattle._apply_battle_para`），运行时**不读本字段** ——
##      改了它看不出效果，是这里最常见的误会。
@export var max_wave := 30
## 开局到第一波僵尸的延迟秒数（「开战」事件里等这个秒数再开第一波；
## 关卡流程要提前开波就用 `await start_first_wave()`，不读本值）
##
## **关卡自己的首波时间不要写在这里**：写在流程里那一句开战上，看得见「这一仗怎么打」——
##   `await start_battle(10, zombie_list, 0.0, 36.0)   # 1-2：36 秒（10 波 / 出怪表 / 不超时 / 首波 36 秒）`
## 本字段只是**兜底默认值**：原版 `ZOMBIE_COUNTDOWN_FIRST_WAVE = 1800` tick
## （原版逻辑时钟 100 tick = 1 秒）= 18 秒。
## 各关的原版首波时间（1-2 的 36 秒 / 迷你 boss 的 1 秒 / 保龄球等 2 秒 / 排山倒海 24 秒 /
## 雪橇狂欢 45 秒 / 蹦蹦舞会 55 秒 / 坚不可摧 0.1 秒）见 docs/参考存档/僵尸波次.md 的「第一波时机」表；
## 生存模式第 2 轮起压到 `ZOMBIE_COUNTDOWN_RANGE = 600` tick = 6 秒（见 ZombieManager.start_game）
@export var first_wave_delay: float = 18.0
## 普通波 / 旗帜波到点的刷新间隔（秒）：Vector2(最短, 最长)，每波在区间内按 0.01 秒取整随机
## 对齐原版 `ZOMBIE_COUNTDOWN + Rand(ZOMBIE_COUNTDOWN_RANGE)` = 2500 + rand(0,600) tick
## = 25.00 ~ 30.99 秒；最短波长 6 秒的下限由刷新管理器统一兜着，不在这里配
## 原版对小僵尸大麻烦 / 排山倒海 / 最后防线三关写死 750 tick = 7.5 秒，那三关在本字段里覆盖
@export var wave_norm_time_range: Vector2 = Vector2(25.0, 31.0)
## 僵尸种类刷新列表 多轮游戏且自然出怪 自动更新自然出怪列表
@export var zombie_refresh_types: Array[StringName] = [
	ZombieIds.NORM, # 普通僵尸
	#ZombieIds.FLAG, # 旗帜僵尸
	ZombieIds.CONE, # 路障僵尸
	ZombieIds.POLE_VAULTER, # 撑杆僵尸
	ZombieIds.BUCKET, # 铁桶僵尸
]
## 波次里是否允许「额外补普僵」：大波（旗帜波）补旗子僵尸 + 一批普通僵尸，点数残差也拿普僵填。
## 原版绝大多数关卡都补；但**原版 ZomBotany 两关**（`Board::InitZombieWaves` 里对
## `WAR_AND_PEAS` / `WAR_AND_PEAS_2` 的特判）既不补普通僵尸、也不补旗子僵尸 ——
## 整关只出植物僵尸。这两关在 `_init()` 里写 false（见 docs/参考存档/植物僵尸.md §4）。
@export var spawn_plain_zombie_extra: bool = true
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

@export_subgroup("灌木丛参数（DLC 版第 7 章 Woods）")
## 是否有灌木丛：灌木是长在草坪上的场景障碍物（占一格、不能种植物、藏僵尸），
## 开启后最终波每丛灌木会各放出一只伏击僵尸
## 数据来源: pvz-dlc-edition.fandom.com/wiki/Woods
@export var is_have_bush := false
## 开局生成的灌木数量（DLC 未公布各关数值，按关卡自配；与墓碑同款只长草坪右侧三分之二）
@export var init_bush_num := 0

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
@export var banned_plant_types_in_choose_card: Array[StringName] = []
## 开局锁定的随机卡槽数量：前 N 个出战卡槽由系统从「本关能用的植物」里**随机**塞入，
## 玩家只能编辑第 N+1 个槽起的部分。0（默认）= 不锁，行为与以前完全一样。
##
## 内容是「本关长什么样」，所以写关卡脚本 _init()（二周目关卡 adventure_XX_YY_round2.gd 写 3）。
## 由 _resolve_locked_random_cards() 在 init_para() 里算进 prechosen_cards，
## 填槽与锁定**全部复用** CardSlotNorm.init_pre_choosed_card()，UI 侧不用改（见 docs/参考存档/二周目.md）。
## ★ 与 is_locked_card_slot（全锁、跳过整个选卡界面）是两件事：这里只锁前几槽，
##   所以不置 is_locked_card_slot，玩家对后面的槽照旧有编辑权。
@export_range(0, 15) var locked_random_card_num: int = 0
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
@export var boss_type: StringName = ZombieBossIds.NULL
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
	return boss_type != ZombieBossIds.NULL

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
##
## 门的位置、换位节奏（首次 90 秒 / 之后每 60 秒）、判定窗口全部按原版写死在
## PortalManager 里（见 docs/参考存档/斗转星移传送门.md），**不做成关卡参数**。
@export var is_portal_combat := false
#endregion

#region 罐子参数
@export_group("罐子参数")
## 是否为罐子模式，影响胜利条件
@export var is_pot_mode := false
@export var pot_mode: ConstLevelData.E_PotMode = ConstLevelData.E_PotMode.Null
@export var pot_col_range: Vector2i = Vector2i(4, 9)
## 罐子占的列（列索引，0 起）：非空时用它替代 pot_col_range 的连续区间。
## 原版解谜第 2 关「一路向左」的罐子在第 3~7 列（最右一列留空），连续区间表达不了。
@export var pot_cols: PackedInt32Array = []
## 太阳罐的个数：原版只有无尽关有 1 个（SCARYPOT_SUN），砸开掉 1~3 颗阳光
@export var sun_pot_num: int = 0
## 无尽关的难度递增：每 N 轮多 1 个巨人僵尸（同时少 1 个普僵）。
## 原版无尽关是每 10 轮 +1 个巨人、最多 8 个（见 docs/参考存档/砸罐子原版对照.md）
@export var pot_extra_gargantuar_per_round: int = 0
## 无尽关巨人僵尸的递增上限
@export var pot_extra_gargantuar_max: int = 8
## 结果随机罐子是否永久可观察罐内（打开后砸之前就能看到里面是什么）
## 目前只有自定义关卡在用（data/levels/params/vase_zombie.gd），内置关卡一律 false
@export var is_can_look_random_res_pot := false
## 戴夫提示罐的个数：摆好罐子后有几个「装着植物的罐子」会显示成绿色植物罐，
## 玩家一眼就知道那几个是植物（但不知道是哪种植物）。
## 原版：解谜 1~9 关每关 2 个、冒险 4-5 是第 1 批 0 个 / 第 2 批 2 个 / 第 3 批 3 个
@export var pot_hint_num: int = 0

@export_subgroup("固定生成，随机位置(从后往前随机放置罐子，满足列对齐，不足的格子使用结果随机罐子补齐)")
@export var random_pot_plant: Dictionary[StringName, int]
@export var random_pot_zombie: Dictionary[StringName, int]
var random_pot_zombie_with_zombie_row_type: Dictionary[CharacterRegistry.ZombieRowType, Dictionary]
@export var plant_pot: Dictionary[StringName, int]
@export var zombie_pot: Dictionary[StringName, int]
var zombie_pot_with_zombie_row_type: Dictionary[CharacterRegistry.ZombieRowType, Dictionary]
var pot_num_on_fixed_mode: int = 0
@export var random_pot_num_on_fixed_mode: Vector3i = Vector3i.ZERO

@export_subgroup("多轮砸罐子（按轮次覆盖上面的固定生成配置）")
## 每一轮罐子的配置，下标 0 = 第 1 轮。留空表示所有轮次都用上面那一份配置
## （解谜模式的砸罐子无尽关就是这么用的；原版冒险 4-5 三批罐子一批比一批难，必须逐轮覆盖）。
## 字典的键（都可省略，省略则沿用上一轮的值）：
##   random_pot_plant / plant_pot / random_pot_zombie / zombie_pot / random_pot_num_on_fixed_mode
##   pot_col_range（本轮罐子占的列，原版冒险 4-5：3 列 → 4 列 → 5 列）/ pot_cols（本轮罐子占的列集合）
##   pot_hint_num（本轮戴夫提示罐个数）/ sun_pot_num（本轮太阳罐个数）
@export var pot_config_on_round: Array[Dictionary] = []
## 第 1 批罐子配置的快照：apply_pot_config_on_round() 改写的就是上面这批顶层字段，
## 而顶层字段同时是第 1 批的数据源（init_para() 只读顶层字段），
## 不快照的话同一进程里第二次进本关（重玩 / 读档）第 1 批会变成上次玩到的那一批。
var pot_config_first_round: Dictionary = {}
#endregion

#region 我是僵尸模式
@export_group("我是僵尸模式")
@export var is_zombie_mode := false
## 红线左侧的列数 —— 原版 `Challenge::CanPlantAt` 的 aLimit（= `IZombiePlacePlants` 的 aColumns）：
## 第 1~5 关 = 4、第 6~8 关 = 5、第 9 关 = 6、无尽关 = 5。
## 这个数同时决定「纸板植物能占的列」与「僵尸能放的列」（原版两者是同一个数）。
@export var plant_col_on_zombie_mode: int = 4
## 原版逐关的纸板植物布局表（`Challenge::IZombieInitLevel`，见 docs/参考存档/我是僵尸原版对照.md）
##
## 每项一个字典，字段：
##   "plant" —— 植物 id（PlantIds.XXX）
##   "row"   —— 行号（0 起，0 = 顶行）；-1 = 不限行（全 5 行）
##   "col"   —— 列号（0 起，0 = 最左列）；-1 = 在红线左侧的可用列里随机落位
##   "count" —— 数量（只有 col = -1 的随机条目用得上）
##
## 原版有两种摆放：固定格位（`IZombiePlacePlantInSquare`）与范围内随机（`IZombiePlacePlants`），
## 这里用 col >= 0 / col < 0 区分，**按数组顺序执行**（后面的条目会避开已经占掉的格子）。
@export var zombie_mode_plant_layout: Array[Dictionary] = []

#endregion

## 我是僵尸模式**本轮**要摆的纸板植物布局表
##
## 默认就是关卡写死的 `zombie_mode_plant_layout`（原版第 1~9 关：逐关固定表）。
## 无尽关要「每轮换一套阵型」（原版 `Challenge::IZombieInitLevel` 的 ENDLESS 分支），
## 由关卡脚本覆写这个方法按轮次现算 —— 本体不认识任何具体玩法（硬约束 §1-8）。
func get_zombie_mode_plant_layout() -> Array[Dictionary]:
	return zombie_mode_plant_layout


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
	## 顺序在「冒险全锁」之后：那条路会 clear 掉 prechosen_cards（见 _resolve_locked_random_cards）
	_resolve_locked_random_cards()
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
	var owned_cards: Array[StringName] = Global.global_game_state.curr_plant
	if owned_cards.is_empty():
		return
	if get_max_choosed_card_num() < owned_cards.size():
		return
	prechosen_cards = ResourceCardReference.create_plant_list(owned_cards)
	is_locked_card_slot = true


## 把「前 N 个随机卡槽」算成 prechosen_cards —— locked_random_card_num > 0 的关卡用
## （二周目关卡 adventure_XX_YY_round2.gd 都写 3，见 docs/参考存档/二周目.md）
##
## 只负责**挑哪几张**：入槽、锁死（预选卡点不动、选卡阶段取消不了）都由现有的
## CardSlotNorm.init_pre_choosed_card() 完成，这里不碰 UI。
##
## ⚠️ 三条边界（踩了就会从「锁前 3 槽」变成「整关跳过选卡」或塞进禁选植物）：
##   1. 不置 is_locked_card_slot —— 置了 is_no_choose_permission() 就返回 true，整个选卡界面不出现；
##   2. 至少给玩家留 1 个槽（N 夹到 卡槽数 - 1），否则卡槽被预选卡填满，同样退化成跳过选卡；
##   3. 随机池要剔掉本关禁选的植物（禁选是在卡位生成之后才生效，预选这条路绕不过它）。
## 另外随机池**只取原版绿卡**：紫卡 / 模仿者（商店购买）与调试专属 / 模组新增植物一律不锁 ——
## 紫卡要场上先有前置植物、模仿者要先挑目标卡，被锁在不可编辑的前几槽里等于废卡。
func _resolve_locked_random_cards() -> void:
	if locked_random_card_num <= 0:
		return
	## 冒险模式的「全锁」（卡槽数 >= 已拥有植物卡数）把 prechosen_cards 全填满了，不再接手
	if is_locked_card_slot:
		return
	if not can_choosed_card or not has_norm_card_slot():
		return
	var owned_cards: Array[StringName] = []
	for plant_type: StringName in Global.global_game_state.curr_plant:
		## 紫卡 + 模仿者：见 ConstPlantUnlock.PURPLE_CARD_PRICE
		if ConstPlantUnlock.is_shop_plant(plant_type):
			continue
		## 调试模式专属 / 模组新增：见 AllCards.is_appended_plant()
		if AllCards.is_appended_plant(plant_type):
			continue
		if banned_plant_types_in_choose_card.has(plant_type):
			continue
		## 已禁用模组残留在 curr_plant 里的孤儿植物：既不在内置表 PlantIds.ALL、
		## 也没注册卡模板（is_appended_plant 只认「当前运行期注册」的，关掉就不认了），
		## 这种 id 漏过上面三条过滤混进随机池，会让 init_pre_choosed_card() 报
		## 「跳过未注册或不可出战的引用」并白占一个锁槽。是否真能出战以 AllCards 为准。
		if not AllCards.is_battle_card(ResourceCardReference.create(
				ResourceCardReference.CardType.Plant, plant_type)):
			continue
		owned_cards.append(plant_type)
	if owned_cards.is_empty():
		return
	## 随机走 GameRng：联机 / 回归要能靠同一颗种子复现（见 game_rng.gd 的说明）
	GameRng.shuffle(owned_cards)
	var lock_num: int = mini(locked_random_card_num, get_max_choosed_card_num() - 1)
	if lock_num <= 0:
		return
	prechosen_cards = ResourceCardReference.create_plant_list(owned_cards.slice(0, lock_num))


## 卡槽数在关卡运行期发生变化时(夜晚关卡开场戴夫卖出卡槽扩充)重新结算预选卡
## 卡槽数变大可能让"锁定卡槽"失效(已拥有植物卡数 <= 新的卡槽数),所以要重跑一次
## 同理「前 N 个随机卡槽」的 N 也是按卡槽数夹的,卡槽数变了要重挑
func refresh_pre_choosed_card_on_card_slot_change() -> void:
	_resolve_adventure_locked_cards()
	_resolve_locked_random_cards()


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
	## 二周目起换底图：只认关卡自己填了 map_data_from_second_round 的那几关
	## （原版 1-1 ~ 1-3 在二周目直接给满 5 行草皮）。
	## ★ 现在这是**兜底**：二周目起加载的是另一套关卡脚本（adventure_XX_YY_round2.gd），
	##   变体自己就把 map_data 写成满草皮图了；只有回退到正本时才走到这里（见 docs/参考存档/二周目.md §6）。
	## 为什么换在这里而不是进关前拼参数：进关的路不止「主菜单点木牌」一条（联机 / 探针 / 调试都自己拼参数），
	## 关卡数据自己看周目才不会漏；而且这里是**子管理器按图建格之前**唯一的时机。
	if map_data_from_second_round != null and Global.global_game_state.is_from_second_round():
		map_data = map_data_from_second_round
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


func _init_pot_mode() -> void:
	if pot_mode == ConstLevelData.E_PotMode.Fixd:
		_init_pot_mode_fixed()


## 切换到第 round_index 轮(1 起)的罐子配置：多轮砸罐子关每批罐子不一样
## (原版冒险 4-5:第一批只有豌豆 / 窝瓜且植物比僵尸多，第三批才出铁桶 / 舞王)。
## 只在固定生成模式生效;配置缺失 / 越界时保持当前配置不变。
## 由 PlantCellManager 在每轮创建罐子之前调用(见 start_next_game_plant_cell_manager_update)
func apply_pot_config_on_round(round_index: int) -> void:
	## 每轮都从第 1 批的原始配置出发：
	## 少了这一步，反复切轮次会把配置一层层叠上去（而且第 1 批会被后面几批顶掉），
	## 无尽关的「巨人递增」也会在上一轮的结果上再减一次，越滚越多
	reset_pot_config_first_round()
	if not pot_config_on_round.is_empty():
		var index: int = round_index - 1
		if index < 0 or index >= pot_config_on_round.size():
			Log.warn(
				str("第 ") + str(round_index) + str(" 轮没有对应的罐子配置(共 ") \
			+ str(pot_config_on_round.size()) + str(" 份)，沿用上一轮的罐子配置")
			)
		else:
			## 依次覆盖到第 round_index 批：每份配置里省略的键沿用上一批的值
			for i in range(index + 1):
				_apply_pot_config_on_round(pot_config_on_round[i])
	## 无尽关的难度递增：跟批次数无关，单独算（所以不能跟着上面那段一起早退）
	_apply_pot_gargantuar_grow(round_index)
	_init_pot_mode_fixed()


## 无尽砸罐子的难度递增：每 N 轮多 1 个巨人僵尸，同时少 1 个普僵。
## 原版：g = clamp(阶段数 / 10, 0, 8)，普僵 8-g、巨人 1+g
## （原版的无尽关第 1 批阶段数是 0，所以第一批是普僵 8 / 巨人 1）。
func _apply_pot_gargantuar_grow(round_index: int) -> void:
	if pot_extra_gargantuar_per_round <= 0:
		return
	## 没有第 1 批的快照就无从「从原始配置重算」，跳过（否则会在上一轮的结果上继续减）
	if pot_config_first_round.is_empty():
		return
	@warning_ignore("integer_division")
	var extra: int = mini(
		pot_extra_gargantuar_max,
		int((round_index - 1) / pot_extra_gargantuar_per_round)
	)
	if extra <= 0:
		return
	var norm_num: int = int(random_pot_zombie.get(ZombieIds.NORM, 0))
	var gargantuar_num: int = int(random_pot_zombie.get(ZombieIds.GARGANTUAR, 0))
	## 普僵最多减到 0（原版普僵本来就只有 8 个）
	var add_num: int = mini(extra, norm_num)
	random_pot_zombie[ZombieIds.NORM] = norm_num - add_num
	random_pot_zombie[ZombieIds.GARGANTUAR] = gargantuar_num + add_num


## 记录第 1 批罐子的配置，作为每次切轮次的起点（见 apply_pot_config_on_round）
func snapshot_pot_config_first_round() -> void:
	pot_config_first_round = {
		"random_pot_plant": random_pot_plant.duplicate(true),
		"plant_pot": plant_pot.duplicate(true),
		"random_pot_zombie": random_pot_zombie.duplicate(true),
		"zombie_pot": zombie_pot.duplicate(true),
		"random_pot_num_on_fixed_mode": random_pot_num_on_fixed_mode,
		"pot_col_range": pot_col_range,
		"pot_cols": Array(pot_cols),
		"pot_hint_num": pot_hint_num,
		"sun_pot_num": sun_pot_num,
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
	pot_cols = PackedInt32Array(pot_config_first_round["pot_cols"])
	pot_hint_num = int(pot_config_first_round["pot_hint_num"])
	sun_pot_num = int(pot_config_first_round["sun_pot_num"])


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
	## 每批罐子占的列集合（任意列集合，优先于 pot_col_range）
	if config.has("pot_cols"):
		var cols_cfg = config["pot_cols"]
		if cols_cfg is PackedInt32Array:
			pot_cols = cols_cfg.duplicate()
		elif cols_cfg is Array:
			pot_cols = PackedInt32Array(cols_cfg)
	## 每批戴夫提示罐的个数（原版冒险 4-5：不提示 → 2 个 → 3 个）
	if config.has("pot_hint_num"):
		pot_hint_num = int(config["pot_hint_num"])
	## 每批太阳罐的个数
	if config.has("sun_pot_num"):
		sun_pot_num = int(config["sun_pot_num"])
	_init_pot_mode_fixed()


## 把配置里的 untyped 字典转成「植物类型 → 个数」
func to_plant_num_dict(source: Dictionary) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for key in source:
		out[str(key)] = int(source[key])
	return out


## 把配置里的 untyped 字典转成「僵尸类型 → 个数」
func to_zombie_num_dict(source: Dictionary) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for key in source:
		out[str(key)] = int(source[key])
	return out


func _init_pot_mode_fixed() -> void:
	pot_num_on_fixed_mode = 0
	for plant_type in random_pot_plant.keys():
		if Global.global_read_data.blacklist_plant_types_with_pot.has(plant_type):
			random_pot_plant.erase(plant_type)
		else:
			pot_num_on_fixed_mode += random_pot_plant[plant_type]
	for plant_type in plant_pot.keys():
		if Global.global_read_data.blacklist_plant_types_with_pot.has(plant_type):
			plant_pot.erase(plant_type)
		else:
			pot_num_on_fixed_mode += plant_pot[plant_type]
	for zombie_type in random_pot_zombie.keys():
		if Global.global_read_data.blacklist_zombie_types_with_pot.has(zombie_type):
			random_pot_zombie.erase(zombie_type)
		else:
			pot_num_on_fixed_mode += random_pot_zombie[zombie_type]
	for zombie_type in zombie_pot.keys():
		if Global.global_read_data.blacklist_zombie_types_with_pot.has(zombie_type):
			zombie_pot.erase(zombie_type)
		else:
			pot_num_on_fixed_mode += zombie_pot[zombie_type]
	pot_num_on_fixed_mode += random_pot_num_on_fixed_mode.x + random_pot_num_on_fixed_mode.y + random_pot_num_on_fixed_mode.z
	## 太阳罐也占格子
	pot_num_on_fixed_mode += sun_pot_num
	random_pot_zombie_with_zombie_row_type = get_pot_zombie_with_row_type_pot_on_fiexd_mode(random_pot_zombie)
	zombie_pot_with_zombie_row_type = get_pot_zombie_with_row_type_pot_on_fiexd_mode(zombie_pot)


func _apply_zombie_mode_rules() -> void:
	if is_zombie_mode:
		is_zombie_can_home = false


func _maybe_load_multi_round_save() -> void:
	## 不支持续玩的多轮关卡（is_save_multi_round_data = false）不读存档：
	## 读了会直接跳到第 N 轮，而本关没有可恢复的进度（罐子不进存档）
	if game_round != 1 and is_save_multi_round_data:
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
		else:
			Log.error("加载的资源类型不对: “%s” 不是 ResourceSaveGameMainGame" % path)
			save_game_data_main_game = null
	else:
		save_game_data_main_game = null


## 删除存档
func delete_game_data():
	save_game_data_main_game = null
	var path = get_save_game_path()

	if ResourceLoader.exists(path):
		var err = DirAccess.remove_absolute(path)
		if err == OK:
			return true
		else:
			Log.error("删除存档失败: %s 错误码 %d" % [path, err])
			return false

#region 自然刷怪过滤
## 当前场景可以刷新的僵尸
var whitelist_refresh_zombie_types: Array[StringName] = []

## 根据白名单过滤出怪类型列表。
## 不修改入参 zombie_types，返回新数组。若列表中含 Z021Bungi，会将本资源的 is_bungi 设为 true。
func filter_invalid_zombie_refresh_types(
	zombie_types: Array[StringName],
	curr_whitelist_refresh_zombie_types: Array[StringName]
) -> Array[StringName]:
	var out: Array[StringName] = []
	for zt: StringName in zombie_types:
		if not curr_whitelist_refresh_zombie_types.has(zt):
			Log.warn(
				"warning: 出怪刷新列表中",
				Global.character_registry.get_zombie_info(zt, CharacterRegistry.ZombieInfoAttribute.ZombieName),
				"不在当前场景可以自然刷怪列表"
			)
			continue
		if zt == ZombieIds.BUNGI:
			is_bungi = true
			continue
		out.append(zt)

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
