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

## 植物类型 id 已迁走：**id 现在是 StringName，不是 P001 这种数字编号**（2026-10-13 迁移）。
##
## 旧写法 `enum PlantType {P001PeaShooterSingle = 1, …}` 已删除，全部 id 见 `PlantIds`
## （`src/core/consts/plant_ids.gd`）：`PlantIds.PEA_SHOOTER_SINGLE` / `PlantIds.WATER_BOWL` …
## 写法迁移：`CharacterRegistry.PlantType.P001PeaShooterSingle` → `PlantIds.PEA_SHOOTER_SINGLE`；
## 类型注解 `PlantType` → `StringName`（`@export var plant_type: StringName = PlantIds.NULL`）。
##
## 顺带消失的三件麻烦事（都是「编号」带来的，改字符串后不复存在）：
##   ① 编号被当数值用（`content_id <= 0` 判空、`PlantType.values()` 遍历）→ 改用 `PlantIds.NULL` / `PlantIds.ALL`；
##   ② 插入新植物要挑号（水盆那个空槽位就是这么来的）→ 加一个常量即可；
##   ③ 57 个 `.tscn` / 关卡 `.tres` 里的 `plant_type = 5` 改枚举值会静默错位 → 现在写 `&"potato_mine"`，看一眼就知道是谁。
##
## ★ 水盆（原 `P050WaterBowl`）：本体**只留 id 常量**，场景 / 数据 / 卡片 / 解锁都由模组「水盆」
## 在运行期登记（见 `register_runtime_plant()`）；不装模组 = 这个 id 谁都不认识，`get_plant_info()` 照旧报「未注册」。
##
## 老存档里的数字编号读回来时走 `PlantIds.from_legacy()` 转换（见 `save_service.gd`），玩家数据不丢。


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
## 僵尸类型 id 已迁走：**id 现在是 StringName，不是 Z001 这种数字编号**（2026-10-13 迁移）。
##
## 旧写法 `enum ZombieType {Z001Norm = 1, …}` 已删除，全部 id 见 `ZombieIds`
## （`src/core/consts/zombie_ids.gd`）：`ZombieIds.NORM` / `ZombieIds.GARGANTUAR` …
## 写法迁移：`CharacterRegistry.ZombieType.Z001Norm` → `ZombieIds.NORM`；
## 类型注解 `ZombieType` → `StringName`（`@export var zombie_type: StringName = ZombieIds.NULL`）。
##
## 旧编号段的来历（改字符串后**不再需要**分段）：Z031–Z044 是「植物僵尸」（原版 ZomBotany，
## 僵尸头顶插一棵植物），配置表见
## `src/entities/character/components/zombie_plant_component/zom_botany_config.gd`。
##
## 热注册僵尸（模组新增）的 id 由 `next_runtime_zombie_type()` 生成，形如 `runtime_zombie_1`
## —— 原来是 9001–9999 的编号段，字符串 id 没有号段，也就没有「段用完」这回事。

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
@export var AllPrePlantPurple:Dictionary[StringName, StringName]= {
	PlantIds.GATLING_PEA:PlantIds.PEA_SHOOTER_DOUBLE,
	PlantIds.TWIN_SUN_FLOWER:PlantIds.SUN_FLOWER,
	PlantIds.GLOOM_SHROOM:PlantIds.FUME_SHROOM,
	PlantIds.CATTAIL:PlantIds.LILY_PAD,
	PlantIds.WINTER_MELON:PlantIds.MELON_PULT,
	PlantIds.GOLD_MAGNET:PlantIds.MAGNET_SHROOM,
	PlantIds.SPIKE_ROCK:PlantIds.CALTROP,
	PlantIds.COB_CANNON:PlantIds.CORN_PULT,
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
## 僵王类型 id 已迁走：**id 现在是 StringName**（2026-10-13 迁移），全部 id 见 `ZombieBossIds`
## （`src/core/consts/zombie_boss_ids.gd`）：`ZombieBossIds.DOCTOR`。
## 写法迁移：`CharacterRegistry.ZombieBossType.ZB001Doctor` → `ZombieBossIds.DOCTOR`；
## 类型注解 `ZombieBossType` → `StringName`。
##
## 僵王**两张表各有一个 id**：生成侧（关卡 `boss_type` / `ZmBossRegistry` / 僵王卡）用 `ZombieBossIds.DOCTOR`，
## 通用僵尸系统（遍历 / 敌方计数 / 图鉴）用 `ZombieIds.ZOMBOSS_DOCTOR` —— 详见 `ZombieIds` 文件头。

## 注册表只保存公共定义，血量和死亡状态由每局生成的僵王实例维护。
enum ZombieBossInfoAttribute {
	BossName,
	BossScenes,
	SunCost, ## 僵王卡每次成功召唤的阳光费用，取非负整数。
	CoolTime, ## 僵王卡每次成功召唤后的冷却时长，单位为游戏秒，0 表示无冷却。
}
#endregion

## 获取植物属性方法
## 三个访问器（植物 / 僵尸 / 僵王）口径统一：空类型 → debug，未注册类型 → error + null，
## 都不裸索引（U-03）。以前植物 / 僵尸那两个是裸索引，未注册类型会直接崩，
## 而僵王那个判了存在只报错 —— 同样的错一边崩一边报错，排查时很容易被带偏。
func get_plant_info(plant_type: StringName, info_attribute:PlantInfoAttribute):
	if plant_type == PlantIds.NULL:
		return null
	var curr_plant_info: Dictionary = {}
	if _runtime_plant_info.has(plant_type):
		curr_plant_info = _runtime_plant_info[plant_type]
	elif PlantInfoData.PLANT_INFO.has(plant_type):
		curr_plant_info = PlantInfoData.PLANT_INFO[plant_type]
	else:
		Log.error("CharacterRegistry：未注册的植物类型：%s" % plant_type)
		return null
	## 运行期覆盖优先（判据 / 数值两张覆盖表，见 set_runtime_plant_condition / set_runtime_plant_stat）
	if info_attribute == PlantInfoAttribute.PlantConditionResource \
	and _runtime_plant_conditions.has(plant_type):
		return _runtime_plant_conditions[plant_type]
	if _runtime_plant_stats.has(plant_type) \
	and (_runtime_plant_stats[plant_type] as Dictionary).has(info_attribute):
		return (_runtime_plant_stats[plant_type] as Dictionary)[info_attribute]
	if not curr_plant_info.has(info_attribute):
		Log.error("CharacterRegistry：植物类型 %s 没有登记属性 %s" % [str(plant_type), str(info_attribute)])
		return null
	return curr_plant_info[info_attribute]


#region 运行期注册植物
## **热注册的唯一入口**：运行期往注册表里加一株植物（配方 = 一张与 `PLANT_INFO` 同构的属性字典）
##
## 与 `register_runtime_zombie()` 同一思路：`PlantInfoData.PLANT_INFO` 是 **const** 表、
## 全仓共享的公共基础数据，运行期写不进去；而「原版没有的植物」又不能预先在表里
## preload 模组的场景（本体不 import 模组，硬约束）。所以新增植物只能走这一层：
## 本体留编号槽位（`PlantIds.WATER_BOWL`），场景 / 冷却 / 阳光 / 种植条件由模组在这里登记。
##
## ★ 不装模组 = 这个编号谁都不认识：`get_plant_info()` 照旧报「未注册」，本体零分支。
##
## ⚠️ 不允许覆盖静态表里已有的植物（那等于改原版数据），要改判据走 `set_runtime_plant_condition()`
var _runtime_plant_info: Dictionary = {}


## 登记一株植物；重复登记同一编号 = 覆盖上一条（会打一条 warn）
func register_runtime_plant(plant_type: StringName, info: Dictionary) -> bool:
	if plant_type == PlantIds.NULL or info.is_empty():
		Log.error("CharacterRegistry：热注册植物失败（类型 %s，属性表 %s）" % [
			str(plant_type), "空" if info.is_empty() else "非空"])
		return false
	if PlantInfoData.PLANT_INFO.has(plant_type):
		Log.error("CharacterRegistry：热注册植物失败，id %s 已被内置植物占用" % plant_type)
		return false
	if not info.has(PlantInfoAttribute.PlantScenes):
		Log.error("CharacterRegistry：热注册植物失败，属性表没有 PlantScenes（id %s）" % plant_type)
		return false
	if _runtime_plant_info.has(plant_type):
		Log.warn("CharacterRegistry：植物 id %s 已经注册过，本次覆盖" % plant_type)
	_runtime_plant_info[plant_type] = info.duplicate()
	return true


## 撤销一株运行期注册的植物（回到「这个编号谁都不认识」）
func clear_runtime_plant(plant_type: StringName) -> void:
	_runtime_plant_info.erase(plant_type)


## **配方入口**：按 `PlantRuntimeRecipe` 登记一株植物（与 `register_runtime_zombie(recipe)` 同一口径）
##
## 配方里 `plant_type` 留空时由 `next_runtime_plant_type()` 自动分配一个没被占用的 id。
## [return] 成功返回 true；配方不合法 / id 被内置植物占用返回 false（一步都不做）
func register_runtime_plant_recipe(recipe: PlantRuntimeRecipe) -> bool:
	if recipe == null:
		Log.error("CharacterRegistry：热注册植物失败，配方是空的")
		return false
	if recipe.plant_scene == null:
		Log.error("CharacterRegistry：热注册植物失败，配方没有植物场景（plant_scene）")
		return false
	if recipe.plant_type == PlantIds.NULL:
		recipe.plant_type = next_runtime_plant_type()
	return register_runtime_plant(recipe.plant_type, recipe.build_info())


## 热注册植物的 id 前缀：内置植物的 id 见 `PlantIds`，加前缀保证不会和它们撞名
##
## 与热注册僵尸同一个道理（字符串 id 没有号段，也就没有「段用完」这回事）——
## 模组想注册几株就注册几株，不必再让本体留 `PlantIds.WATER_BOWL` 那种空槽位。
const RUNTIME_PLANT_ID_PREFIX := &"runtime_plant_"
## 下一个可以自动分配的序号
var _next_runtime_plant_seq := 1


## 取下一个没被占用的热注册 id（`runtime_plant_1` 起，取走后自增）
func next_runtime_plant_type() -> StringName:
	## `StringName(x)` 不是构造函数，拼出 String 交给返回类型自己转
	var new_id := str(RUNTIME_PLANT_ID_PREFIX) + str(_next_runtime_plant_seq)
	while _runtime_plant_info.has(new_id) or PlantInfoData.PLANT_INFO.has(new_id):
		_next_runtime_plant_seq += 1
		new_id = str(RUNTIME_PLANT_ID_PREFIX) + str(_next_runtime_plant_seq)
	_next_runtime_plant_seq += 1
	return new_id


## 按地形位反查植物：「谁能种在这些地形上」的通用查询
##
## ★ 这是留给模组的口子：新增一只底部植物（它给格子加一个新的地形位）之后，
##   要找出「哪些植物该认这个新位」—— 本体不认识任何一只模组植物，只能按位查。
##   水盆找水生植物就是这么找的（条件 = 8 水、占普通位 → 海蘑菇 / 缠绕海草）。
##
## [param bits] 要匹配的地形位（见 `PlantConditionBits`）
## [param place] 只收占这个位置的植物
## [param exact] true = 条件位**恰好等于** bits；false = 只要包含这些位就算
## [return] 静态表 + 运行期注册的植物都算，顺序按静态表再运行期的顺序
func collect_plant_types_by_condition(bits: int,
		place: PlacePlantInCell = PlacePlantInCell.Norm, exact := true) -> Array[StringName]:
	var all_types: Array[StringName] = []
	all_types.append_array(PlantInfoData.PLANT_INFO.keys())
	for plant_type in _runtime_plant_info:
		if not all_types.has(plant_type):
			all_types.append(plant_type)
	var result: Array[StringName] = []
	for plant_type in all_types:
		var condition := get_plant_info(plant_type, PlantInfoAttribute.PlantConditionResource) \
			as ResourcePlantCondition
		if condition == null or condition.place_plant_in_cell != place:
			continue
		var matched := condition.plant_condition == bits if exact \
			else (condition.plant_condition & bits) == bits
		if matched:
			result.append(plant_type)
	return result


## 该植物是否为**运行期注册**的（= 模组新增，不在内置植物表 `PLANT_INFO` 里）
##
## 为什么需要这个查询：选卡界面与图鉴扩展页要把「模组 / 调试模式新增的植物」排在普通植物后面
## （见 `AllCards.is_appended_plant()`），而本体不认识任何一个模组 ——
## 只能认「走了 `register_runtime_plant()` 的」这一类。
##
## ⚠️ 别写成 `CharacterRegistry.PlantInfo.has(...)`：那是**类常量**引用，会撞循环依赖，
## 实测编译报 `Could not resolve external class member "PlantInfo"` —— 走实例方法没有这个问题。
func is_runtime_plant(plant_type: StringName) -> bool:
	return _runtime_plant_info.has(plant_type)
#endregion


#region 运行期覆盖植物数值
## 运行期**覆盖**某一种植物的某一项数值（如 `SunCost` / `CoolTime`）
##
## 与上面「换判据」同一思路，只是这次改的是**数值**：
## `PlantInfoData.PLANT_INFO` 是 const 表，而 Godot 4.4 起**常量字典是只读的**
## （实测就地写会报 `ERROR: Dictionary is in read-only state.`），改不动；
## 又不能预先在表里替模组写一份 —— 本体不 import 模组。所以运行期要改数值只能走这张覆盖表。
##
## ★ 这是留给模组的口子（"原版平衡"这类**只调数值**的同人改动）：
##   本体不认识任何一个模组，谁覆盖、覆盖成什么由调用方决定；撤得掉
##   （`clear_runtime_plant_stats()`），关掉模组 = 数值回到原版。
##
## ⚠️ 只允许覆盖**数值类**属性（阳光 / 冷却）：判据那类"方法决定行为"的走
##   `set_runtime_plant_condition()` 整份换资源，塞进这里也拦不住它的方法。
var _runtime_plant_stats: Dictionary = {}


## 覆盖一种植物的一项数值（同一植物同一属性重复调用 = 覆盖上一条）
func set_runtime_plant_stat(plant_type: StringName, attribute: PlantInfoAttribute,
		value: Variant) -> void:
	if plant_type == PlantIds.NULL or value == null:
		Log.error("CharacterRegistry：运行期植物数值不合法（类型 %s，值 %s）" % [
			str(plant_type), str(value)])
		return
	if not _runtime_plant_stats.has(plant_type):
		_runtime_plant_stats[plant_type] = {}
	(_runtime_plant_stats[plant_type] as Dictionary)[attribute] = value


## 撤销一种植物的全部运行期数值覆盖（回到静态表里那一份）
func clear_runtime_plant_stats(plant_type: StringName) -> void:
	_runtime_plant_stats.erase(plant_type)
#endregion


#region 运行期覆盖种植条件
## 运行期**整份换掉**某一种植物的种植条件资源（`PlantInfoAttribute.PlantConditionResource`）
##
## 与 `register_runtime_zombie()` 同一思路：`PlantInfoData.PLANT_INFO` 是编译期的公共数据，
## 运行期要改判定只能走这张覆盖表 —— 换的是**条件资源里的那几个方法**（能不能种、
## 紫卡有没有基座），只改字段做不到，所以整份换掉，撤得掉（见 `clear_runtime_plant_condition()`）。
##
## ★ 这是留给模组的口子（原版之外的玩法，例如「紫卡不必种在基座上」）：
##   本体**不认识**任何一个模组，也不 import 它们 —— 谁来换、换成什么由调用方决定。
##   条件资源是**共享对象**（多种植物共用同一份 `.tres`），要换就换新的实例，不要改原对象。
var _runtime_plant_conditions: Dictionary = {}


## 覆盖一种植物的种植条件资源（同一类型重复调用 = 覆盖上一条）
## [param condition] 新的条件资源；传 null 表示不合法，只报错不覆盖
func set_runtime_plant_condition(plant_type: StringName, condition: ResourcePlantCondition) -> void:
	if plant_type == PlantIds.NULL or condition == null:
		Log.error("CharacterRegistry：运行期种植条件不合法（类型 %s，条件 %s）" % [
			str(plant_type), str(condition)])
		return
	_runtime_plant_conditions[plant_type] = condition


## 撤销一种植物的运行期种植条件（回到静态表里那一份）
func clear_runtime_plant_condition(plant_type: StringName) -> void:
	_runtime_plant_conditions.erase(plant_type)


## 给一株植物**多加一个可种地形位**（在它现有条件的基础上按位或）
##
## ★ 这是留给模组的口子：新增一只底部植物（如水盆给格子加「64 水盆」位）之后，
##   要让某些植物认这个新位。整份换掉（上面那个 `set_runtime_plant_condition()`）得自己
##   把原条件抄一遍，抄漏一位就丢一种地形 —— 这里在**当前**条件上或一位，撤得掉。
##
## ⚠️ 换的是**副本**：条件资源是共享对象（多种植物共用同一份 `.tres`），就地改会连累别人。
## [return] 这株植物没登记条件时返回 false（并报错），其余返回 true
func add_runtime_plant_condition_bit(plant_type: StringName, condition_bit: int) -> bool:
	var current := get_plant_info(plant_type, PlantInfoAttribute.PlantConditionResource) \
		as ResourcePlantCondition
	if current == null:
		Log.error("CharacterRegistry：%s 没有种植条件，加不了地形位 %d" % [
			str(plant_type), condition_bit])
		return false
	var patched := current.duplicate() as ResourcePlantCondition
	patched.plant_condition |= condition_bit
	set_runtime_plant_condition(plant_type, patched)
	return true
#endregion


## 获取僵尸属性方法（先查运行期热注册的那张，再查静态表）
func get_zombie_info(zombie_type: StringName, info_attribute:ZombieInfoAttribute):
	if zombie_type == ZombieIds.NULL:
		return null
	## 两张表分开取、不用 `.get()` 兜底：`Dictionary.get()` 缺键返回 null，
	## 把 null 塞进 `Dictionary` 型的变量会当场报一次运行期错误（这里的调用量很大，不能忍）
	var curr_zombie_info: Dictionary = {}
	if _runtime_zombie_info.has(zombie_type):
		curr_zombie_info = _runtime_zombie_info[zombie_type]
	elif ZombieInfoData.ZOMBIE_INFO.has(zombie_type):
		curr_zombie_info = ZombieInfoData.ZOMBIE_INFO[zombie_type]
	else:
		Log.error("CharacterRegistry：未注册的僵尸类型：%s" % zombie_type)
		return null
	if not curr_zombie_info.has(info_attribute):
		Log.error("CharacterRegistry：僵尸类型 %s 没有登记属性 %s" % [zombie_type, info_attribute])
		return null
	return curr_zombie_info[info_attribute]

## 空类型或未注册类型返回 null，由生成入口决定如何处理，不回退成其他角色。
func get_zombie_boss_info(boss_type: StringName, info_attribute: ZombieBossInfoAttribute):
	if boss_type == ZombieBossIds.NULL:
		return null
	if not ZombieBossInfoData.ZOMBIE_BOSS_INFO.has(boss_type):
		Log.error("CharacterRegistry：未注册的僵王类型：%s" % boss_type)
		return null
	var curr_boss_info: Dictionary = ZombieBossInfoData.ZOMBIE_BOSS_INFO[boss_type]
	return curr_boss_info[info_attribute]


#region 运行期热注册僵尸
## **热注册的唯一入口**：运行期往注册表里加一只僵尸，配方 = 一个本体 + 一个脚本
## （防具由脚本自己在 `build_runtime_parts()` 里挂，见 `ZombieRuntimeRecipe` 的类注释）。
##
## 为什么要这一层：内置的二十多只僵尸都是「一个 `.tscn` 一只」，加一只要新开场景并在
## `zombie_info_data.gd` 登记一行 —— 那是**编译期**的事。模组 / 自制关卡 / 控制台要在
## 运行期加僵尸，只能走这里。
##
## 与静态表分开存：`ZOMBIE_INFO` 是 const 表、全仓共享的公共基础数据（注释里写明
## 「各出怪系统复制后独立调整，不修改公共基础数据」），往里写等于改所有关卡的出怪基线，
## 而且撤不掉。热注册是「这一局 / 这个模组」的事，所以要能整条摘掉。
##
## 怎么用：
## ```gdscript
## var recipe := ZombieRuntimeRecipe.new()
## recipe.base_scene = preload("res://src/entities/character/zombie/zombie_norm.tscn")
## recipe.zombie_script = preload("user://mods/my_mod/my_zombie.gd")
## recipe.spawn_power = 2
## recipe.spawn_weight = 1000
## Global.character_registry.register_runtime_zombie(recipe)
## ```
## 之后 `ZombieManager.create_norm_zombie(recipe.zombie_type, ...)` 就能生成它。

## 运行期热注册的配方：僵尸类型 → `ZombieRuntimeRecipe`
var runtime_zombie_recipes: Dictionary = {}
## 由配方生成的 `ZOMBIE_INFO` 条目（`get_zombie_info()` 优先查这一张）
var _runtime_zombie_info: Dictionary = {}
## 运行期僵尸的自然出怪战力 / 权重（只收配方里两个值都 > 0 的那些）
var _runtime_zombie_spawn_power: Dictionary = {}
var _runtime_zombie_spawn_weights: Dictionary = {}

## 热注册僵尸的 id 前缀：内置僵尸的 id 见 `ZombieIds`，加前缀保证不会和它们撞名
##
## 为什么是「前缀 + 自增序号」而不是原来的 9001–9999 编号段：字符串 id 没有号段概念，
## 也就没有「段用完」这回事 —— 模组想注册几只就注册几只，不必再去抢号。
const RUNTIME_ZOMBIE_ID_PREFIX := &"runtime_zombie_"
## 下一个可以自动分配的序号
var _next_runtime_zombie_seq := 1


## 运行期注册一只僵尸；重复注册同一 id = 覆盖上一条（会打一条 warn）
## [param recipe] 配方：一个本体 + 一个脚本
## [return] 注册成功返回 true；配方不合法或 id 被内置僵尸占用时返回 false 并报错
func register_runtime_zombie(recipe: ZombieRuntimeRecipe) -> bool:
	if recipe == null:
		Log.error("CharacterRegistry：热注册僵尸失败，配方是空的")
		return false
	if recipe.base_scene == null:
		Log.error("CharacterRegistry：热注册僵尸失败，配方没有本体（base_scene）")
		return false
	if recipe.zombie_type == ZombieIds.NULL:
		recipe.zombie_type = next_runtime_zombie_type()
	elif ZombieInfoData.ZOMBIE_INFO.has(recipe.zombie_type):
		Log.error("CharacterRegistry：热注册僵尸失败，id %s 已被内置僵尸占用" % recipe.zombie_type)
		return false
	var zombie_type := recipe.zombie_type
	if runtime_zombie_recipes.has(zombie_type):
		Log.warn("CharacterRegistry：僵尸 id %s 已经注册过，本次覆盖" % zombie_type)
	runtime_zombie_recipes[zombie_type] = recipe
	_runtime_zombie_info[zombie_type] = recipe.build_info()
	_set_runtime_spawn_para(zombie_type, recipe.spawn_power, recipe.spawn_weight)
	Log.info("CharacterRegistry：已热注册僵尸 %s（id %s）" % [recipe.get_display_name(), zombie_type])
	return true


## 撤销一只热注册僵尸（内置僵尸撤不掉，返回 false）
func unregister_runtime_zombie(zombie_type: StringName) -> bool:
	if not runtime_zombie_recipes.has(zombie_type):
		Log.warn("CharacterRegistry：id %s 不是热注册的僵尸，没什么可撤" % zombie_type)
		return false
	runtime_zombie_recipes.erase(zombie_type)
	_runtime_zombie_info.erase(zombie_type)
	_runtime_zombie_spawn_power.erase(zombie_type)
	_runtime_zombie_spawn_weights.erase(zombie_type)
	return true


## 取下一个没被占用的热注册 id（`runtime_zombie_1` 起，取走后自增）
func next_runtime_zombie_type() -> StringName:
	## `StringName(x)` 不是构造函数，拼出 String 交给返回类型自己转
	var new_id := str(RUNTIME_ZOMBIE_ID_PREFIX) + str(_next_runtime_zombie_seq)
	while runtime_zombie_recipes.has(new_id):
		_next_runtime_zombie_seq += 1
		new_id = str(RUNTIME_ZOMBIE_ID_PREFIX) + str(_next_runtime_zombie_seq)
	_next_runtime_zombie_seq += 1
	return new_id


## 这个 id 是不是运行期热注册进来的
func is_runtime_zombie(zombie_type: StringName) -> bool:
	return runtime_zombie_recipes.has(zombie_type)


## 这个僵尸类型登记过没有（静态表 + 运行期热注册都算）
func has_zombie(zombie_type: StringName) -> bool:
	if zombie_type == ZombieIds.NULL:
		return false
	return _runtime_zombie_info.has(zombie_type) or ZombieInfoData.ZOMBIE_INFO.has(zombie_type)


## 这个类型现在能不能被创建出来（静态场景可实例化，或热注册的配方合法）
func can_instantiate_zombie(zombie_type: StringName) -> bool:
	if zombie_type == ZombieIds.NULL:
		return false
	var recipe := runtime_zombie_recipes.get(zombie_type) as ZombieRuntimeRecipe
	if recipe != null:
		return recipe.base_scene != null and recipe.base_scene.can_instantiate()
	if not ZombieInfoData.ZOMBIE_INFO.has(zombie_type):
		return false
	var scene := ZombieInfoData.ZOMBIE_INFO[zombie_type].get(ZombieInfoAttribute.ZombieScenes) as PackedScene
	return scene != null and scene.can_instantiate()


## **僵尸的统一实例化入口**：静态表走场景，运行期热注册的走配方现场组装。
## 所有"按类型创建僵尸"的地方都该走这里（`ZombieManager` / `CharacterShowFactory`），
## 别再自己 `get_zombie_info(..., ZombieScenes).instantiate()` —— 热注册的僵尸没有场景文件。
## [return] 失败返回 null 并报错
func instantiate_zombie(zombie_type: StringName) -> Zombie000Base:
	if zombie_type == ZombieIds.NULL:
		return null
	var recipe := runtime_zombie_recipes.get(zombie_type) as ZombieRuntimeRecipe
	if recipe != null:
		return recipe.build()
	if not ZombieInfoData.ZOMBIE_INFO.has(zombie_type):
		Log.error("CharacterRegistry：未注册的僵尸类型：%s" % zombie_type)
		return null
	var scene := ZombieInfoData.ZOMBIE_INFO[zombie_type].get(ZombieInfoAttribute.ZombieScenes) as PackedScene
	if scene == null or not scene.can_instantiate():
		Log.error("CharacterRegistry：僵尸类型 %s 的场景无法实例化" % zombie_type)
		return null
	return scene.instantiate() as Zombie000Base


## 自然出怪战力（静态表 + 运行期热注册）；没有返回 -1，消费方据此把它从刷新池里跳过
func get_zombie_spawn_power(zombie_type: StringName) -> int:
	if _runtime_zombie_spawn_power.has(zombie_type):
		return int(_runtime_zombie_spawn_power[zombie_type])
	return ZombieInfoData.ZOMBIE_SPAWN_POWER.get(zombie_type, -1)


## 自然出怪初始权重（静态表 + 运行期热注册）；**返回的是副本**，各出怪系统照旧复制后自行调整
func get_zombie_spawn_weights() -> Dictionary:
	var merged := ZombieInfoData.ZOMBIE_SPAWN_WEIGHTS.duplicate()
	merged.merge(_runtime_zombie_spawn_weights, true)
	return merged


## 已热注册的编号列表（调试 / 日志用）
func get_runtime_zombie_types() -> Array:
	return runtime_zombie_recipes.keys()


## 战力与权重是**成对**生效的：缺一个就两头都撤掉，免得出现「有战力没权重」的半截配置
## （波次管理器见战力 <= 0 会整只跳过，权重留着也没人用）
func _set_runtime_spawn_para(zombie_type: StringName, spawn_power: int, spawn_weight: int) -> void:
	if spawn_power > 0 and spawn_weight > 0:
		_runtime_zombie_spawn_power[zombie_type] = spawn_power
		_runtime_zombie_spawn_weights[zombie_type] = spawn_weight
		return
	_runtime_zombie_spawn_power.erase(zombie_type)
	_runtime_zombie_spawn_weights.erase(zombie_type)
#endregion
