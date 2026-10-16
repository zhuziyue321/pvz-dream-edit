extends Resource
class_name ZombieRuntimeRecipe
## 运行期热注册一只僵尸的配方：**一个本体 + 一个脚本**
##
## 内置的二十多只僵尸是「一个 `.tscn` 一只」：本体、防具、行为脚本全都写死在场景里，
## 加一只就要新开一个 `.tscn` 并在 `zombie_info_data.gd` 登记一行。
## 运行期（模组 / 自制关卡 / 控制台）没有编辑器可用，走不了这条路 —— 本配方就是那条路：
##   · **本体** `base_scene`：复用一个现成的僵尸场景当骨架（如 `zombie_norm.tscn`）；
##   · **脚本** `zombie_script`：挂到本体根节点上，这只僵尸的行为全由它决定；
##   · **防具**：不在配方里 —— 脚本重写 `Zombie000Base.build_runtime_parts()`，
##     在里面调 `add_armor()`，想挂几层挂几层（防具自己的特殊效果照旧由防具组件定义）。
##
## 用法：配好一份交给 `CharacterRegistry.register_runtime_zombie()`，之后出战生成
## （`ZombieManager.create_norm_zombie()`）、图鉴 / 开局预览（`CharacterShowFactory`）
## 等所有入口都认它，与内置僵尸没有区别。
##
## 编号：热注册的僵尸类型号落在 `CharacterRegistry.RUNTIME_ZOMBIE_TYPE_MIN ~ MAX`（9001–9999）。
## 留 `Null` 时由注册表自动分配下一个 —— 不要去占内置僵尸已用的号段（见 `ZombieType` 注释）。
##
## 关联：[僵尸热注册](../../../../docs/参考存档/僵尸热注册.md) ｜ CharacterRegistry ｜ Zombie000Base ｜ ArmorComponent


#region 配方
## 本体：被复用的僵尸场景（必填），它的根节点必须是 `Zombie000Base`
@export var base_scene: PackedScene

## 脚本：挂到本体根节点上（必填）。行为与防具都写在它里面
@export var zombie_script: Script

## 僵尸类型号；留 `Null` 时由 `register_runtime_zombie()` 从 9001 起自动分配一个
@export var zombie_type: StringName = ZombieIds.NULL

## 僵尸名（图鉴 / 日志用）；留空时自动取 `ZombieRuntime<编号>`
@export var zombie_name: StringName = &""

## 僵尸冷却时间
@export var cool_time: float = 0.0

## 阳光消耗（「我是僵尸」模式放这只僵尸的价格）
@export var sun_cost: int = 50

## 行类型：决定它能出现在陆地行还是水面行
@export var row_type: CharacterRegistry.ZombieRowType = CharacterRegistry.ZombieRowType.Both

## 自然出怪战力（按战力预算生成时用）；<= 0 = 不进按战力预算的生成
@export var spawn_power: int = 0

## 自然出怪初始权重；<= 0 = 不进基础权重池，只能被技能 / 关卡脚本点名生成
@export var spawn_weight: int = 0
#endregion


## 显示名：没起名时按编号兜一个，保证日志与图鉴里不会空着
func get_display_name() -> StringName:
	if not zombie_name.is_empty():
		return zombie_name
	## 显示名里带上 id —— 原来的 `ZombieRuntime%d % int(zombie_type)` 是拿编号拼的，
	## 现在 id 是字符串，直接拼（`StringName(x)` 不是构造函数）
	return "ZombieRuntime_" + str(zombie_type)


## 生成注册表要的那一条 `ZOMBIE_INFO`。
## `ZombieScenes` 留空是**故意的**：热注册的僵尸没有场景文件，实例化一律走
## `CharacterRegistry.instantiate_zombie()`（由配方现场组装），不要拿这一格去 `instantiate()`。
func build_info() -> Dictionary:
	return {
		CharacterRegistry.ZombieInfoAttribute.ZombieName: get_display_name(),
		CharacterRegistry.ZombieInfoAttribute.CoolTime: cool_time,
		CharacterRegistry.ZombieInfoAttribute.SunCost: sun_cost,
		CharacterRegistry.ZombieInfoAttribute.ZombieScenes: null,
		CharacterRegistry.ZombieInfoAttribute.ZombieRowType: row_type,
	}


## 按配方组装出一只僵尸（还没进场景树，交给生成方 `add_child`）
## [return] 失败返回 null 并报错（本体场景不可用 / 根节点不是僵尸）
func build() -> Zombie000Base:
	if base_scene == null or not base_scene.can_instantiate():
		Log.error("热注册僵尸 [%s]：本体场景不可用，无法创建" % get_display_name())
		return null
	var root := base_scene.instantiate()
	if not (root is Zombie000Base):
		Log.error("热注册僵尸 [%s]：本体场景的根节点 %s 不是僵尸（Zombie000Base）"
			% [get_display_name(), root.name])
		root.free()
		return null
	if zombie_script != null:
		_apply_script(root, zombie_script)
	root.zombie_type = zombie_type
	return root as Zombie000Base


## 把脚本挂到本体根节点上，并尽量保住本体场景里配好的那些导出值
##
## 为什么要抄一遍：Godot 的 `Object.set_script()` 会**重建脚本实例**，场景里配的导出值
## 会被清回脚本默认值（编辑器里「改脚本」会帮你补回来，运行期没人补）。
## 所以先把「会存进场景」的导出项抄一份，换完脚本再灌回去 —— 与编辑器的口径一致。
##
## ⚠️ 抄不回来的只有**节点引用类**导出项（如 `iron_node`）：本体还没进树，路径解析不了，
## 读回来是 null，写 null 反而会把场景里那条路径冲掉。需要铁器就在脚本的
## `build_runtime_parts()` 里自己 `get_node()` 补上。
static func _apply_script(target: Node, new_script: Script) -> void:
	var snapshot := _snapshot_stored_properties(target)
	target.set_script(new_script)
	for property_name in snapshot:
		if not _has_stored_property(target, property_name):
			continue
		var value: Variant = snapshot[property_name]
		if value == null or (value is Array and (value as Array).has(null)):
			continue
		target.set(property_name, value)


## 抄一份「会存进场景」的属性（跳过 `script` 本身 —— 它就是这次要换掉的那个）
static func _snapshot_stored_properties(target: Node) -> Dictionary:
	var snapshot: Dictionary = {}
	for property in target.get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		if property.name == &"script":
			continue
		snapshot[property.name] = target.get(property.name)
	return snapshot


## 换完脚本之后，这个属性还在不在（新脚本不认的属性不能硬写）
static func _has_stored_property(target: Node, property_name: StringName) -> bool:
	for property in target.get_property_list():
		if property.name == property_name and (property.usage & PROPERTY_USAGE_STORAGE):
			return true
	return false
