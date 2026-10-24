extends Node
## 僵尸波次生成管理器
class_name ZombieWaveCreateManager

#region 波次生成僵尸管理器参数
## 出怪倍率
var zombie_multy := 1
## 蹦极僵尸数量范围
var range_num_bungi:Vector2i = Vector2i(3,5)
## 波次里是否允许「额外补普僵」（旗帜波补旗子僵尸 + 一批普僵、点数残差补普僵）
## 原版 ZomBotany 两关关掉：这两关在 `Board::InitZombieWaves` 里被特判，整关只出植物僵尸。
## 数据来自关卡：`ResourceLevelData.spawn_plain_zombie_extra`
var spawn_plain_zombie_extra := true
#endregion
@onready var zombie_manager: ZombieManager = %ZombieManager

## 僵尸选行系统
@onready var zombie_choose_row_system: ZombieChooseRowSystem = %ZombieChooseRowSystem

## 僵尸战力 / 出怪权重的**唯一数据源**已收口到 `CharacterRegistry`
## （数据本体：`data/character/registry_data/zombie_info_data.gd` 里的
##  `ZOMBIE_SPAWN_POWER` / `ZOMBIE_SPAWN_WEIGHTS`）。
##
## 历史：这两张表曾在本文件里各有一份**逐行同值**的拷贝（U-02），于是「自然出怪」读本地表、
## 「僵王召唤僵尸」读注册表 —— 改一次平衡数值要改两处，漏一处就是两套战力打架。
## 现在只剩注册表那一份；植物僵尸（Z031+）的战力 / 权重不在这两张表里，走 `ZomBotanyConfig`。

## 初始权重的**运行期副本**：出怪密度倍率乘在这一份上（见 `get_zombie_weight`），
## 不改动注册表里的公共基础数据。
## 开局在 `init_zombie_wave_create_manager()` 里按注册表重取一次（含热注册的僵尸）
var zombie_weights:Dictionary = CharacterRegistry.ZombieSpawnWeights.duplicate_deep()

## 僵尸随机选择池
var zombie_choose_random_pool:RandomPicker

## 每波最大僵尸数量
@export var max_zombies_per_wave = 50
## 同一波僵尸在入场方向上的间隔（像素）：原版一波僵尸是陆续进场，不是同时从同一点涌入
@export var spawn_gap_x := 25.0
## 单波入场错开的总跨度上限（像素）：防止波末僵尸离场太远，把清场时间拖得过长
@export var spawn_gap_x_max := 400.0
## 当前波次生成的僵尸
var wave_all_zombies:Array[Zombie000Base]

## 初始化创建波次僵尸管理器
func init_zombie_wave_create_manager(game_para:ResourceLevelData):
	zombie_multy = game_para.zombie_multy
	range_num_bungi = game_para.range_num_bungi
	spawn_plain_zombie_extra = game_para.spawn_plain_zombie_extra
	## 权重在这里重取一次：运行期热注册的僵尸（见 `CharacterRegistry.register_runtime_zombie`）
	## 可能是本管理器建好之后才登记进来的，成员初始化那一次取不到它们
	zombie_weights = Global.character_registry.get_zombie_spawn_weights()
	zombie_choose_row_system.init_zombie_choose_row_system()
	update_zombie_refresh_types()

## 更新可以刷新的僵尸列表
func update_zombie_refresh_types():
	## 初始化僵尸生成随机池数据
	var zombie_choose_random_pool_data:Array[Array] = []
	for zombie_type in zombie_manager.zombie_refresh_types:
		## 两张表并不覆盖所有僵尸类型，裸索引遇到表外类型会直接报错
		var curr_power: int = get_zombie_power(zombie_type)
		if curr_power <= 0:
			Log.warn("僵尸类型 " + str(zombie_type) + " 没有配置 power，已从刷新池中跳过")
			continue
		zombie_choose_random_pool_data.append([zombie_type, get_zombie_weight(zombie_type)])
	zombie_choose_random_pool = RandomPicker.new(zombie_choose_random_pool_data)


## 僵尸战力：植物僵尸（Z031+）统一在 ZomBotanyConfig 配，其余读注册表的 `ZombieSpawnPower`
## （唯一数据源，见文件头注释；13 只植物僵尸各写一份会让这张表翻倍，且和 zom_botany_config.gd 各演化各的）
func get_zombie_power(zombie_type: StringName) -> int:
	var zom_botany_info := ZomBotanyConfig.get_info(zombie_type)
	if zom_botany_info != null:
		return zom_botany_info.power
	return Global.character_registry.get_zombie_spawn_power(zombie_type)


## 僵尸初始权重：植物僵尸走 ZomBotanyConfig，其余走 zombie_weights
## **已乘上出怪密度倍率**（见 set_zombie_density）—— 随机池一律按「密度生效后」这个值算
func get_zombie_weight(zombie_type: StringName) -> int:
	var base_weight: int
	var zom_botany_info := ZomBotanyConfig.get_info(zombie_type)
	if zom_botany_info != null:
		base_weight = zom_botany_info.weight
	else:
		base_weight = zombie_weights.get(zombie_type, 9999)
	return maxi(1, int(base_weight * get_zombie_density(zombie_type)))


#region 出怪密度（通用旋钮）
## 出怪密度倍率表：按僵尸类型缩放它在随机池里的权重（1.0 = 用原版权重）
## 只影响「这一波随机挑到什么僵尸」—— 不碰战力上限 / 波数 / 出怪节奏
## 「谁在什么时候调到多少」是关卡自己的事（硬约束 §1-8），本体只给这个通用旋钮
var zombie_density_scale: Dictionary = {}


## 设置某类僵尸的出怪密度倍率（> 1 = 出得更多，1.0 = 回到原版权重）
## 只在倍率真的变了时才动随机池，避免每波无谓重建别名表
func set_zombie_density(zombie_type: StringName, density:float) -> void:
	if density <= 0.0:
		Log.error("出怪密度倍率必须为正数: " + str(zombie_type) + " -> " + str(density))
		return
	if is_equal_approx(density, get_zombie_density(zombie_type)):
		return
	zombie_density_scale[zombie_type] = density
	_sync_density_to_pool(zombie_type)


## 取某类僵尸当前的出怪密度倍率（没设过 = 1.0）
func get_zombie_density(zombie_type: StringName) -> float:
	return float(zombie_density_scale.get(zombie_type, 1.0))


## 所有僵尸回到原版权重（清掉全部密度倍率）
## 关卡级行限制：本波这些行不出怪（下标 = 行号）
## 关卡脚本在 `LevelScriptBase.before_wave_spawn()` 里按波设置 / 清空，
## 例如隐形食脑者「前几波最下行不刷怪」（原版 `Board.cpp` 的 INVISIGHOUL 分支）
func set_banned_spawn_rows(rows: Array[int]) -> void:
	zombie_choose_row_system.set_banned_lanes(rows)


## 撤销行限制（每波该重设就重设，别让限制漏到后面几波）
func clear_banned_spawn_rows() -> void:
	zombie_choose_row_system.clear_banned_lanes()


## 当前关卡的僵尸行数（关卡脚本按行做限制时，靠它算最后一行的下标）
func get_row_num() -> int:
	return zombie_choose_row_system.get_row_num()


func clear_zombie_density() -> void:
	if zombie_density_scale.is_empty():
		return
	var changed_types: Array = zombie_density_scale.keys()
	zombie_density_scale.clear()
	for zombie_type in changed_types:
		_sync_density_to_pool(zombie_type)


## 把某类僵尸「密度生效后的权重」写回随机池，并重建别名表
func _sync_density_to_pool(zombie_type: StringName) -> void:
	if zombie_choose_random_pool == null or zombie_manager == null:
		return
	if not zombie_type in zombie_manager.zombie_refresh_types:
		return
	zombie_choose_random_pool.update_item_weight(zombie_type, get_zombie_weight(zombie_type), false)
	zombie_choose_random_pool.rebuild_alias_table()
#endregion


#region 创建当前波次僵尸
## 创建当前波僵尸
func create_curr_wave_all_zombies(wave:int, is_big_wave:bool):
	var level_script := zombie_manager.game_para as LevelScriptBase
	## **先**让关卡脚本按当前局势调本波的出怪密度（比如「冰面全被融掉 → 普僵变多」）。
	## 必须排在 create_curr_wave_zombie_list 之前：那一步才按权重随机挑僵尸，
	## 等清单出来了再改权重，本波已经挑完，只能影响下一波。
	if level_script != null:
		level_script.before_wave_spawn(self, wave, is_big_wave)
	## 获取当前波僵尸生成列表
	var wave_spawn :Array[StringName] = create_curr_wave_zombie_list(wave, is_big_wave)
	## 本波僵尸「怎么进场」交给关卡脚本：默认是走进来，一关专属的进场方式（空投这类）
	## 由脚本自己覆写 create_wave_zombies 换掉 —— 本文件不认识任何具体玩法
	## （见 LevelScriptBase.create_wave_zombies；关卡不覆写时走通用进场）
	if level_script != null:
		return level_script.create_wave_zombies(self, wave_spawn, wave)
	return create_norm_wave_zombies(wave_spawn, wave)


## 通用进场：僵尸按清单从场地边缘走进来
## 关卡脚本覆写 create_wave_zombies 时想退化成普通进场就调这里
func create_norm_wave_zombies(wave_spawn:Array[StringName], wave:int) -> Array[Zombie000Base]:
	wave_all_zombies.clear()

	for i in range(wave_spawn.size()):
		var zombie_type : StringName = wave_spawn[i]
		var lane :int = -1
		## 需要冰道才能出的僵尸（雪橇队）：由注册表的规则资源声明，不再按类型硬判
		if Global.character_registry.is_zombie_need_ice_road(zombie_type):
			## 挑一条「冰面还在」的行：没有冰的小队一落地就开始掉血（见 Zombie014Bobsled.judge_is_in_ice_road），
			## 这样的班级不算有效出怪 —— 一条冰道都没有时本波改出洗冰车，由它把冰铺回来
			## （对应原版「玩家把冰面融掉后，冰面恢复前只出洗冰车」）
			lane = select_bobsled_spawn_row()
			if lane < 0:
				zombie_type = ZombieIds.ZAMBONI
		if lane < 0:
			lane = zombie_choose_row_system.select_spawn_row(
				Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType) as CharacterRegistry.ZombieRowType
			)
		wave_all_zombies.append(
			wave_create_zombie(zombie_type, lane, wave, Callable(), i)
		)

	return wave_all_zombies


## 雪橇队的出怪行：只在「冰面还在」的行里挑
## 返回 -1 = 整张图一条冰道都没有（冰被融掉了，还没被洗冰车铺回来）
func select_bobsled_spawn_row() -> int:
	var ice_row_weight:Array[float] = []
	for row_ice_road:Array[IceRoad] in zombie_manager.all_ice_roads:
		ice_row_weight.append(0.0 if row_ice_road.is_empty() else 1.0)
	if GlobalUtils.sum_arr(ice_row_weight) == 0:
		return -1
	return zombie_choose_row_system.select_spawn_row(
		Global.character_registry.get_zombie_info(ZombieIds.BOBSLED, CharacterRegistry.ZombieInfoAttribute.ZombieRowType) as CharacterRegistry.ZombieRowType,
		ice_row_weight)


## 生成波次僵尸
func wave_create_zombie(
	zombie_type: StringName,
	lane:int, 	## 僵尸行
	curr_wave:int,		## 僵尸波次
	init_zombie_special:Callable = Callable(),		## 初始化僵尸特殊属性
	spawn_index:int = -1		## 本波内第几只（>=0 时按序号在入场方向上错开，模拟原版陆续进场）
):
	var zombie_init_para:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane:lane,
		Zombie000Base.E_ZInitAttr.CurrWave:curr_wave,
	}
	## 同一波僵尸按序号往场外错开，变成原版的「陆续进场」；spawn_index < 0 表示不错开（珊瑚 / 蹦极等）
	var spawn_gap := 0.0
	if spawn_index > 0:
		spawn_gap = min(spawn_index * spawn_gap_x, spawn_gap_x_max)
	var zombie_glo_pos = zombie_manager.all_zombie_rows[lane].zombie_create_position.global_position + Vector2(randf_range(-10, 10), 0)

	## 父节点不传：由 create_norm_zombie 按 para 里的 Lane 取该行节点
	return zombie_manager.create_norm_zombie(zombie_type, null, zombie_init_para, zombie_glo_pos, init_zombie_special, spawn_gap)

#region 创建当前波僵尸生成列表
## 创建当前波僵尸生成列表
func create_curr_wave_zombie_list(wave:int, is_big_wave:bool):
	## 计算当前波僵尸战力上限
	var curr_wave_power_limit = calculate_wave_power_limit(wave, is_big_wave)
	## 获取当前波的生成僵尸列表
	var wave_spawn :Array[StringName] = get_curr_wave_zombie_list(wave, is_big_wave, curr_wave_power_limit)

	return wave_spawn

## 本波的「基础点数」：原版 `aZombiePoints`（未乘大波 2.5 的那一份）
## 首周目 `aWave / 3 + 1`；二周目 `aWave * 2 / 5 + 1`（1-5 例外，仍走首周目公式）
## 大波补几只普僵也按它算（`aPlainZombiesNum = min(aZombiePoints, 8)`）
## 数据来源: 原版 `Board::PickZombieWaves()`（../PvZ-Portable-main/src/Lawn/Board.cpp:633-649）
@warning_ignore("integer_division")
func calculate_base_wave_points(wave: int) -> int:
	if is_second_round_adventure():
		return wave * 2 / 5 + 1
	return wave / 3 + 1

## 计算每波的战力上限（原版「本波总级别」）
## 原版公式: n÷3 向下取整 + 1（n 为当前波数）；大波再乘 2.5 向下取整；出怪倍率最后整体相乘
## 数据来源: 原版 `Board::PickZombieWaves()`（../PvZ-Portable-main/src/Lawn/Board.cpp:633-686）
func calculate_wave_power_limit(wave:int, is_big_wave: bool) -> int:
	var base_power_limit: int = calculate_base_wave_points(wave)
	## 如果是大波，战力上限是原战力上限的2.5倍
	var power_limit:int = base_power_limit * zombie_multy
	if is_big_wave:
		power_limit = int(base_power_limit * 2.5) * zombie_multy
	## 至少保留1点战力，避免某一波一只都不出
	return max(1, power_limit)

## 取某类僵尸的「首次允许波次」（**1 起算**）
## 植物僵尸读 `ZomBotanyConfig`（原版 ZomBotany 两关的硬规则），其余读注册表里的
## `ZOMBIE_FIRST_ALLOWED_WAVE`（原版 `ZombieDefinition.mFirstAllowedWave`，见 `zombie_info_data.gd`）
func get_zombie_first_allowed_wave(zombie_type: StringName) -> int:
	var zom_botany_info := ZomBotanyConfig.get_info(zombie_type)
	if zom_botany_info != null:
		return zom_botany_info.first_allowed_wave
	return Global.character_registry.get_zombie_first_allowed_wave(zombie_type)


## 本关是不是冒险模式：原版有几条出怪规则（首次允许波次 / 新登场僵尸 / 最后一波补齐）只对冒险模式生效
func is_adventure_level() -> bool:
	var level_data := zombie_manager.game_para as ResourceLevelData
	return level_data != null \
		and level_data.game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure


## 本关是否按**二周目**的点数公式算出怪（原版 `IsAdventureMode() && HasFinishedAdventure() && mLevel != 5`）
## 原版 1-5 例外：二周目回到本关时仍用首周目公式（那一关原版是「第二次玩追加撑杆 / 铁桶 / 读报」的特殊关）。
func is_second_round_adventure() -> bool:
	if not is_adventure_level():
		return false
	var level_data := zombie_manager.game_para as ResourceLevelData
	if level_data == null or level_data.get_adventure_level_index() == 5:
		return false
	return Global.global_game_state.is_from_second_round()


## 本关「新登场的僵尸」（原版 `Board::GetIntroducedZombieType()`）：`&""` = 本关没有新僵尸
## 只认**本关出怪表里也有**的类型，原版那几条排除就自动成立了：
##   鸭子圈（原版显式跳过，本仓库 3-1 出怪表里本来也没有）、
##   蹦极（本仓库走 `is_bungi` 的大波空投，不进出怪表）、
##   雪人（本仓库不进自然出怪池，只在重玩 4-10 那条线上）。
func get_introduced_zombie_type() -> StringName:
	var level_data := zombie_manager.game_para as ResourceLevelData
	if not is_adventure_level() or level_data == null:
		return &""
	## 原版 1-1 不算「新登场」（`mLevel == 1` 直接返回无效）
	var level_index: int = level_data.get_adventure_level_index()
	if level_index <= 1:
		return &""
	## 按 `ZombieIds.ALL` 的顺序先到先得（与原版枚举序一致：3-6 的冰车排在雪橇前）
	for zombie_type: StringName in ZombieIds.ALL:
		if Global.character_registry.get_zombie_starting_level(zombie_type) != level_index:
			continue
		if not zombie_manager.zombie_refresh_types.has(zombie_type):
			continue
		return zombie_type
	return &""


## 这只「新登场僵尸」该不该出现在本波（原版 `Board.cpp:688-715`）
##   矿工 / 气球：第 7 波（下标 + 1 == 7）与最后一波
##   其余：中间波（每轮波数 / 2）与最后一波
@warning_ignore("integer_division")
func is_introduced_zombie_wave(intro_zombie: StringName, wave: int) -> bool:
	if _is_final_wave(wave):
		return true
	if intro_zombie == ZombieIds.DIGGER or intro_zombie == ZombieIds.BALLOON:
		return wave + 1 == 7
	return wave == zombie_manager.zombie_wave_manager.max_wave_one_round / 2


## 按「首次允许波次」开关随机池
## 原版 `Board::PickZombieType()`：`theWaveIndex + 1 < mFirstAllowedWave` 的僵尸直接跳过。
## 池子只能整项增删（`update_item_weight()` 不接受 0 权重），所以每波按需加回 / 移除一次，
## 变了才重建别名表。`power <= 0` 的类型建池时就被跳过，这里也不往回加。
##
## ⚠️ 注册表那张表只对**冒险模式**生效：小游戏 / 生存 / 我是僵尸在原版里各自另写一套出怪规则
## （原版还专门豁免了蹦蹦舞会 / 全面冻结 / 蹦极闪电战），本仓库这些关卡的出怪表已经按各自规则写好，
## 再套一层会让波数少的关卡前几波一只都出不来（如蹦蹦舞会的出怪表只有蹦蹦，首次允许波次是 10）。
## 植物僵尸那几个「第 10 波起」的类型不受这条限制 —— 那是原版 ZomBotany 的硬规则，任何模式都生效。
func _apply_first_allowed_wave(wave: int) -> void:
	if not is_instance_valid(zombie_choose_random_pool):
		return
	var gate_by_table := is_adventure_level()
	var changed := false
	for zombie_type in zombie_manager.zombie_refresh_types:
		if get_zombie_power(zombie_type) <= 0:
			continue
		var first_wave: int = get_zombie_first_allowed_wave(zombie_type)
		var is_gated: bool = first_wave > 1 \
			and (gate_by_table or ZomBotanyConfig.get_info(zombie_type) != null)
		var allowed: bool = (not is_gated) or wave + 1 >= first_wave
		var in_pool: bool = zombie_choose_random_pool.has_item(zombie_type)
		if allowed and not in_pool:
			changed = zombie_choose_random_pool.add_item(
				zombie_type, get_zombie_weight(zombie_type), false, false) or changed
		elif not allowed and in_pool:
			changed = zombie_choose_random_pool.remove_item(zombie_type, false) or changed
	if changed:
		zombie_choose_random_pool.rebuild_alias_table()


## 按权重抽一只「战力 ≤ 剩余点数」的僵尸
## 原版 `Board::PickZombieType()` 的做法是**先把买不起的类型整个排除**再按权重抽，
## 而不是「抽一只，买不起就重抽」—— 后者在只剩 1~2 点时会把便宜的普僵/路障抽成主力。
## 返回 `&""` = 池子里一只都买不起（原版这时会从空权重表落到 0 号普僵，等价于下面的余额补齐）。
func pick_zombie_within_power(remaining_power: int) -> StringName:
	var candidates: Array = []
	for zombie_type in zombie_manager.zombie_refresh_types:
		## 池里没有 = 本波还没到它的首次允许波次（见 _apply_first_allowed_wave）
		if not zombie_choose_random_pool.has_item(zombie_type):
			continue
		var zombie_power: int = get_zombie_power(zombie_type)
		if zombie_power <= 0 or zombie_power > remaining_power:
			continue
		candidates.append([zombie_type, zombie_choose_random_pool.get_item_weight(zombie_type)])
	if candidates.is_empty():
		return &""
	return RandomPicker.new(candidates).get_random_item()


## 获取当前波僵尸列表（对齐原版 `Board::PickZombieWaves()` 里「一波」的算法）
func get_curr_wave_zombie_list(wave:int, is_big_wave: bool, curr_wave_power_limit:int) ->Array[StringName]:
	## 先按波次开关池子：撑杆 / 舞王 / 潜水 / 伽刚特尔这些原版有「首次允许波次」的类型
	_apply_first_allowed_wave(wave)
	## 当前波的僵尸列表
	var wave_spawn :Array[StringName]= []
	## 目前总战力
	var total_power = 0
	## 当前空隙位置
	var curr_spare_slot = max_zombies_per_wave

	## 大波：原版先按点数放一批普僵、再放旗帜僵尸（`Board.cpp:651-664`）
	## 关掉 `spawn_plain_zombie_extra` 的关卡（原版 ZomBotany 两关）连旗子僵尸也不补：
	## 原版在这两关整关只出植物僵尸，旗帜波只是点数 ×2.5 的普通波
	if is_big_wave and spawn_plain_zombie_extra:
		## 原版 `aPlainZombiesNum = min(aZombiePoints, 8)`：
		## 第 10 波 4 只、第 20 波 7 只、第 30 波起封顶 8 只（不是简单的「5+ 一律 8 只」）
		var plain_num: int = mini(calculate_base_wave_points(wave), 8)
		for i in range(plain_num):
			wave_spawn.append(ZombieIds.NORM)
			total_power += get_zombie_power(ZombieIds.NORM)
			curr_spare_slot -= 1
		## 旗帜僵尸
		wave_spawn.append(ZombieIds.FLAG)
		total_power += get_zombie_power(ZombieIds.FLAG)
		curr_spare_slot -= 1

	## 本关「新登场的僵尸」：原版让它必定出现在中间波与最后一波（矿工 / 气球提前到第 7 波起）
	var intro_zombie: StringName = get_introduced_zombie_type()
	if intro_zombie != &"" and is_introduced_zombie_wave(intro_zombie, wave) and curr_spare_slot > 0:
		wave_spawn.append(intro_zombie)
		total_power += get_zombie_power(intro_zombie)
		curr_spare_slot -= 1

	## 原版第 5 步（随机填充**之前**）：冒险关最后一波补齐本关漏掉的类型。
	## 补齐同样扣点数，扣成负数后面就不再随机抽了。
	total_power += _put_in_missing_zombies(wave_spawn, wave)

	# 生成剩余僵尸，直到总战力符合当前战力上限
	while curr_spare_slot > 0 and total_power < curr_wave_power_limit:
		var remaining_power: int = curr_wave_power_limit - total_power
		var selected_zombie: StringName = pick_zombie_within_power(remaining_power)
		if selected_zombie == &"":
			## 余额已经买不起出怪表里任何一只 = 原版会从空权重表落到 0 号普僵（即拿普僵补余额）。
			## 这一步同样受「额外补普僵」开关约束：关掉的关卡宁可这一波少几只，
			## 也不凭空多出出怪表里没有的普僵
			if spawn_plain_zombie_extra:
				for i in range(remaining_power):
					wave_spawn.append(ZombieIds.NORM)
					total_power += get_zombie_power(ZombieIds.NORM)
					curr_spare_slot -= 1
			break
		wave_spawn.append(selected_zombie)
		total_power += get_zombie_power(selected_zombie)
		curr_spare_slot -= 1

	return wave_spawn


## 原版 `Board::PutInMissingZombies()`（`Board.cpp:560-569` / `722-726`）：
## 冒险关**最后一波**把本关出怪表里这一波还没出现过的类型各补一只 ——
## 所以冒险关的最后一波必定凑齐本关全部僵尸种类（这正是原版「最后一波最凶」的一环）。
## 雪人除外：原版这里显式跳过 `ZOMBIE_YETI`，它只在暴雨夜放。
## 返回这些僵尸占掉的战力：原版 `PutZombieInWave()` 一样扣点数，扣成负数后本波就不再随机抽了。
func _put_in_missing_zombies(wave_spawn: Array[StringName], wave: int) -> int:
	if not is_adventure_level() or not _is_final_wave(wave):
		return 0
	var added_power := 0
	for zombie_type in zombie_manager.zombie_refresh_types:
		if zombie_type == ZombieIds.YETI:
			continue
		var zombie_power: int = get_zombie_power(zombie_type)
		if zombie_power <= 0:
			continue
		if wave_spawn.has(zombie_type):
			continue
		if wave_spawn.size() >= max_zombies_per_wave:
			break
		wave_spawn.append(zombie_type)
		added_power += zombie_power
	return added_power


## 本关的最后一波（下标 = 总波数 - 1，与 `ZombieWaveManager.start_next_wave()` 同口径）
func _is_final_wave(wave: int) -> bool:
	if wave < 0:
		return false
	return wave == zombie_manager.zombie_wave_manager.max_wave - 1

#endregion

#endregion

#region 大波僵尸时生成特殊僵尸
## 大波僵尸时创建特殊僵尸
## [is_final:bool] 是否为最后一波
func spawn_special_zombie_in_big_wave(is_final:=false):
	## 珊瑚僵尸,若有水路自动创建,没有则不创建
	if is_final:
		if not zombie_manager.is_ice:
			spawn_sea_weed_zombies()
	## 如果有蹦极僵尸
	if zombie_manager.is_bungi:
		spawn_bungi_zombies()

#region 珊瑚僵尸
## 最后一大波珊瑚僵尸
func spawn_sea_weed_zombies():
	var zombie_row_pool_i :Array[int]
	for i in range(zombie_manager.all_zombie_rows.size()):
		if zombie_manager.all_zombie_rows[i].zombie_row_type == CharacterRegistry.ZombieRowType.Pool:
			zombie_row_pool_i.append(i)
	if zombie_row_pool_i.is_empty():
		return

	var zombie_type_sea_weed_list :Array= [ZombieIds.NORM, ZombieIds.CONE, ZombieIds.BUCKET]

	for i in range(3):
		## 走 `GameRng`：珊瑚僵尸的种类 / 行 / 位置两端要一致
		var zombie_type: StringName = GameRng.pick_random(zombie_type_sea_weed_list)
		var lane:int= GameRng.pick_random(zombie_row_pool_i)
		var zombie_sea_weed:Zombie000Base = wave_create_zombie(zombie_type, lane, -1, _zombie_seaweed)

		zombie_sea_weed.global_position.x = GameRng.randf_range(500, 750)

## 珊瑚僵尸
func _zombie_seaweed(z:Zombie001Norm):
	z.is_seaweed = true
#endregion

#region 蹦极僵尸
## 大波空投一批偷植物的蹦极僵尸（蹦极闪电战的大波也走这里）
func spawn_bungi_zombies():
	## 选择plant_cell
	var num_bungi_rand:int = GameRng.randi_range(range_num_bungi.x, range_num_bungi.y)
	var all_cell_have_plant:Array[PlantCell] = zombie_manager.main_game.plant_cell_manager.get_cell_have_plant()
	var num_bungi_res:int = min(num_bungi_rand, all_cell_have_plant.size())
	## 打乱顺序（走 `GameRng`：两端要偷同一批格子）
	GameRng.shuffle(all_cell_have_plant)
	## 蹦极僵尸选中的plant_cell
	var all_cell_be_bungi = all_cell_have_plant.slice(0, num_bungi_res)
	## 生成蹦极僵尸
	for plant_cell:PlantCell in all_cell_be_bungi:
		var zombie_init_para:Dictionary = {
			Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane:plant_cell.row_col.x
		}

		zombie_manager.create_norm_zombie(
			ZombieIds.BUNGI,
			zombie_manager.all_zombie_rows[plant_cell.row_col.x],
			zombie_init_para,
			Vector2(plant_cell.global_position.x + plant_cell.size.x/2,
				zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_create_position.global_position.y
			),
			GlobalUtils.create_bungi.bind(plant_cell)
		)

#endregion

#endregion
