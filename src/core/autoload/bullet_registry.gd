extends Node
class_name BulletRegistry


## 子弹类型 id 已迁走：**id 现在是 StringName，不是 int 编号**（2026-10-13 迁移）。
##
## 旧写法 `enum BulletType {Bullet001Pea = 1, …}` 已删除，全部 id 见 `BulletIds`
## （`src/core/consts/bullet_ids.gd`）：`BulletIds.PEA` / `BulletIds.WINTER_MELON` …
## 写法迁移：`BulletRegistry.BulletType.Bullet001Pea` → `BulletIds.PEA`；
## 类型注解 `BulletType` → `StringName`（`@export var bullet_type: StringName`）。
##
## 本文件只保留「id → 场景路径」这一张映射表（硬约束 §1-4 的注册表独占）。


## 伤害种类已迁走：**伤害模式 / 伤害来源现在都在 `ConstDamage`**（`src/core/consts/const_damage.gd`）。
##
## 搬走的原因：它虽然诞生在这里，但早就不是子弹独占了 —— 锤子、爆炸、啃食、冰冻伤害、
## 残血流失都在用同一个枚举，放在"子弹注册表"里名不副实。
## 子弹场景的 `bullet_mode` 导出字段已改用 `ConstDamage.E_DamageMode`（**值一一对应**，
## 存量 `.tscn` 存的是 int，不需要改任何场景文件）。


## 子弹类型 → 场景路径
##
## 为什么这里存**路径字符串**而不是 `preload` 好的 PackedScene：
## BulletRegistry 是 autoload 单例，在项目启动时就构造完毕。原先 19 个 preload 意味着
## 玩家还在主菜单、一发子弹都没打出去的时候，全部子弹场景（连同它们的纹理、动画、
## 音效引用）就已经常驻内存了；而一局对战通常只用到其中三五种。
## 改成按需 `load()`：第一次真正要发射某种子弹时才加载，之后缓存在 _scene_cache 里。
##
## 本表**刻意不加 @export**：它是「类型 → 资源」的映射，按硬约束 1-4 该由注册表独占，
## 不该在检查器里再被改写一遍。取场景一律走 get_bullet_scenes()。
const BULLET_SCENE_PATHS: Dictionary[StringName, String] = {
	BulletIds.PEA: "res://src/entities/bullet/bullet_pea.tscn",
	BulletIds.PEA_SNOW: "res://src/entities/bullet/bullet_pea_snow.tscn",
	BulletIds.PUFF: "res://src/entities/bullet/bullet_puff.tscn",
	BulletIds.FUME: "res://src/entities/bullet/bullet_fume.tscn",
	BulletIds.PUFF_LONG_TIME: "res://src/entities/bullet/bullet_puff_long_time.tscn",
	BulletIds.PEA_FIRE: "res://src/entities/bullet/bullet_pea_fire.tscn",
	BulletIds.CACTUS: "res://src/entities/bullet/bullet_cactus.tscn",
	BulletIds.STAR: "res://src/entities/bullet/bullet_star.tscn",

	BulletIds.CABBAGE: "res://src/entities/bullet/bullet_cabbage.tscn",
	BulletIds.CORN: "res://src/entities/bullet/bullet_corn.tscn",
	BulletIds.BUTTER: "res://src/entities/bullet/bullet_butter.tscn",
	BulletIds.MELON: "res://src/entities/bullet/bullet_melon.tscn",

	BulletIds.BASKETBALL: "res://src/entities/bullet/bullet_basketball.tscn",

	BulletIds.CATTAIL: "res://src/entities/bullet/bullet_cattail_bullet.tscn",
	BulletIds.WINTER_MELON: "res://src/entities/bullet/bullet_winter_melon.tscn",

	BulletIds.COB_CANNON: "res://src/entities/bullet/bullet_cob_cannon.tscn",

	BulletIds.BOWLING: "res://src/entities/bullet/bullet_bowling.tscn",
	BulletIds.BOWLING_BOMB: "res://src/entities/bullet/bullet_bowling_bomb.tscn",
	BulletIds.BOWLING_BIG: "res://src/entities/bullet/bullet_bowling_big.tscn",
}

## 已加载过的场景缓存（按需加载的配套：第二次取同一种子弹不再走 load）
var _scene_cache: Dictionary[StringName, PackedScene] = {}

## 运行期覆盖某一种子弹的**属性值**（原版没有，留给模组）
##
## ★ 与 `CharacterRegistry.set_runtime_plant_stat()` 同款：子弹的 `max_attack_num`（能打几个）
##   / `attack_value` 之类都是 `@export`，改场景等于改原版；`PackedScene` 里那份默认值
##   又没法在运行期改（每颗子弹都是新实例），所以造出来之后照这张表覆盖一次。
##   空表 = 子弹场景里配什么就是什么（原版行为）。
var _runtime_bullet_stats: Dictionary = {}


## 覆盖一种子弹的一个属性值（同一类型同一属性重复调用 = 覆盖上一条）
func set_runtime_bullet_stat(bullet_type: StringName, property: StringName, value: Variant) -> void:
	if bullet_type == &"" or property == &"":
		return
	if not _runtime_bullet_stats.has(bullet_type):
		_runtime_bullet_stats[bullet_type] = {}
	_runtime_bullet_stats[bullet_type][property] = value


## 撤销一种子弹的全部运行期覆盖
func clear_runtime_bullet_stats(bullet_type: StringName) -> void:
	_runtime_bullet_stats.erase(bullet_type)


## 照覆盖表给一颗刚造出来的子弹写属性（属性不存在就跳过，不报错）
func _apply_runtime_bullet_stats(bullet_type: StringName, bullet: Bullet000Base) -> void:
	if not _runtime_bullet_stats.has(bullet_type):
		return
	var stats: Dictionary = _runtime_bullet_stats[bullet_type]
	for property in stats:
		if property in bullet:
			bullet.set(property, stats[property])


## 获取子弹场景
##
## 第一次取某种子弹时才真正 load，之后命中 _scene_cache。
## 取不到（id 没登记 / 文件缺失）会 Log.error 并返回 null —— 与原来
## `BulletTypeMap.get()` 对未知 key 返回 null 的行为一致，调用方照旧判空。
func get_bullet_scenes(bullet_type: StringName) -> PackedScene:
	if _scene_cache.has(bullet_type):
		return _scene_cache[bullet_type]

	## 注意不能写成 `var path := BULLET_SCENE_PATHS.get(...)`：
	## Dictionary.get() 的返回值是 Variant（哪怕字典本身是 typed 的），
	## 用 := 会把 path 推断成 Variant，项目把「推断自 Variant」当编译错误。
	var path: String = BULLET_SCENE_PATHS.get(bullet_type, "")
	if path == "":
		Log.error("子弹类型没有登记场景路径: %s" % bullet_type)
		return null

	var scene := load(path) as PackedScene
	if scene == null:
		Log.error("子弹场景加载失败: %s" % path)
		return null

	_scene_cache[bullet_type] = scene
	return scene


## 生成一颗子弹（**只创建，不入场景树**，调用方负责 add_child）
##
## 为什么收口出这个方法：原先 7 个文件里散着 9 处
## `Global.bullet_registry.get_bullet_scenes(t).instantiate()`，
## 每个调用方都得先知道「有注册表」「要调 get_bullet_scenes」「还得自己 instantiate」三步。
## 收口之后调用方只说「我要一颗 X 型子弹」；将来要加预热 / 统计 / 复用，只改这一处。
## [is_ignore_gate] 为 true 时**不看闸门** —— 专给联机客户端"照主机数据重建一颗"用。
## ⚠️ 这个口是必需的：客户端自己占着闸门，重建路径若也走闸门，
## 客户端就**一颗子弹都造不出来**（场上会完全没有豌豆）。只有 `NetplayStateSync` 该传 true。
func create_bullet(bullet_type: StringName, is_ignore_gate: bool = false) -> Bullet000Base:
	## 闸门被占住时（联机客户端）这一颗不造：场上飞着什么由**主机**随快照下发，
	## 客户端再自己造一份就是"一发豌豆两颗"。⚠️ 调用方必须判 null（9 处调用点都已判）。
	if not is_ignore_gate and GlobalUtils.bullet_spawn_gate.is_valid() \
			and bool(GlobalUtils.bullet_spawn_gate.call()):
		return null
	var scene := get_bullet_scenes(bullet_type)
	if scene == null:
		return null
	var bullet := scene.instantiate() as Bullet000Base
	if bullet == null:
		return null
	## 领号放在**这里**（唯一的创建口），不去 `_ready()`：
	## 7 个子类重写了 `_ready()`，基类里的自动领号对没调 `super()` 的那批会静默失效
	## （详见 `Bullet000Base.entity_id` 的注释）。客户端随后可用 `assign_entity_id()` 改成主机的号。
	bullet.entity_id = Character000Base.take_next_entity_id()
	_apply_runtime_bullet_stats(bullet_type, bullet)
	return bullet


## 预热：提前把一批子弹场景加载进缓存
##
## 按需加载的代价是「第一次发射某种子弹时要等一次加载」。
## 关卡开局若已知会用到哪些子弹（按本关的植物 / 僵尸构成），可以在载入界面或开场演出时
## 调一次本方法把卡顿挪到不敏感的时刻。传空数组是安全的空操作。
func preload_bullet_scenes(bullet_types: Array[StringName]) -> void:
	for bullet_type in bullet_types:
		get_bullet_scenes(bullet_type)


## 已缓存的子弹场景数量（调试 / 自检用）
func get_cached_scene_count() -> int:
	return _scene_cache.size()
