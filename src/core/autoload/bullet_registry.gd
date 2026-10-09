extends Node
class_name BulletRegistry


enum BulletType{
	Null = 0,

	Bullet001Pea = 1,			## 豌豆
	Bullet002PeaSnow,		## 寒冰豌豆
	Bullet003Puff,			## 小喷孢子
	Bullet004Fume,			## 大喷孢子
	Bullet005PuffLongTime,	## 胆小菇孢子（和小喷孢子一样，不过修改存在持续距离）
	Bullet006PeaFire,		## 火焰豌豆
	Bullet007Cactus,		## 仙人掌尖刺
	Bullet008Star,			## 星星子弹

	Bullet009Cabbage,		## 卷心菜
	Bullet010Corn,			## 玉米
	Bullet011Butter,		## 黄油
	Bullet012Melon,			## 西瓜

	Bullet013Basketball,	## 篮球

	Bullet014CattailBullet,	## 香蒲子弹
	Bullet015WinterMelon,	## 冰瓜子弹

	Bullet016CobCannon,		## 玉米加农炮子弹


	Bullet1001Bowling = 1001,		## 保龄球
	Bullet1002BowlingBomb,	## 爆炸保龄球
	Bullet1003BowlingBig,	## 大保龄球

}


## 伤害种类
## 普通，穿透，真实
enum AttackMode {
	Norm, 			## 正常 按顺序对二类防具、一类防具、本体造成伤害
	Penetration, 	## 穿透 对二类防具造成伤害同时对一类防具造成伤害
	Real,			## 真实 不对二类防具造成伤害，直接对一类防具造成伤害
	BowlingFront,		## 保龄球正面
	BowlingSide,		## 保龄球侧面
	Hammer,			## 锤子

	}


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
const BULLET_SCENE_PATHS: Dictionary[BulletType, String] = {
	BulletType.Bullet001Pea: "res://src/entities/bullet/bullet_pea.tscn",
	BulletType.Bullet002PeaSnow: "res://src/entities/bullet/bullet_pea_snow.tscn",
	BulletType.Bullet003Puff: "res://src/entities/bullet/bullet_puff.tscn",
	BulletType.Bullet004Fume: "res://src/entities/bullet/bullet_fume.tscn",
	BulletType.Bullet005PuffLongTime: "res://src/entities/bullet/bullet_puff_long_time.tscn",
	BulletType.Bullet006PeaFire: "res://src/entities/bullet/bullet_pea_fire.tscn",
	BulletType.Bullet007Cactus: "res://src/entities/bullet/bullet_cactus.tscn",
	BulletType.Bullet008Star: "res://src/entities/bullet/bullet_star.tscn",

	BulletType.Bullet009Cabbage: "res://src/entities/bullet/bullet_cabbage.tscn",
	BulletType.Bullet010Corn: "res://src/entities/bullet/bullet_corn.tscn",
	BulletType.Bullet011Butter: "res://src/entities/bullet/bullet_butter.tscn",
	BulletType.Bullet012Melon: "res://src/entities/bullet/bullet_melon.tscn",

	BulletType.Bullet013Basketball: "res://src/entities/bullet/bullet_basketball.tscn",

	BulletType.Bullet014CattailBullet: "res://src/entities/bullet/bullet_cattail_bullet.tscn",
	BulletType.Bullet015WinterMelon: "res://src/entities/bullet/bullet_winter_melon.tscn",

	BulletType.Bullet016CobCannon: "res://src/entities/bullet/bullet_cob_cannon.tscn",

	BulletType.Bullet1001Bowling: "res://src/entities/bullet/bullet_bowling.tscn",
	BulletType.Bullet1002BowlingBomb: "res://src/entities/bullet/bullet_bowling_bomb.tscn",
	BulletType.Bullet1003BowlingBig: "res://src/entities/bullet/bullet_bowling_big.tscn",
}

## 已加载过的场景缓存（按需加载的配套：第二次取同一种子弹不再走 load）
var _scene_cache: Dictionary[BulletType, PackedScene] = {}


## 获取子弹场景
##
## 第一次取某种子弹时才真正 load，之后命中 _scene_cache。
## 取不到（类型没登记 / 文件缺失）会 Log.error 并返回 null —— 与原来
## `BulletTypeMap.get()` 对未知 key 返回 null 的行为一致，调用方照旧判空。
func get_bullet_scenes(bullet_type:BulletType) -> PackedScene:
	if _scene_cache.has(bullet_type):
		return _scene_cache[bullet_type]

	## 注意不能写成 `var path := BULLET_SCENE_PATHS.get(...)`：
	## Dictionary.get() 的返回值是 Variant（哪怕字典本身是 typed 的），
	## 用 := 会把 path 推断成 Variant，项目把「推断自 Variant」当编译错误。
	var path: String = BULLET_SCENE_PATHS.get(bullet_type, "")
	if path == "":
		Log.error("子弹类型没有登记场景路径: %d" % bullet_type)
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
func create_bullet(bullet_type:BulletType, is_ignore_gate: bool = false) -> Bullet000Base:
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
	return bullet


## 预热：提前把一批子弹场景加载进缓存
##
## 按需加载的代价是「第一次发射某种子弹时要等一次加载」。
## 关卡开局若已知会用到哪些子弹（按本关的植物 / 僵尸构成），可以在载入界面或开场演出时
## 调一次本方法把卡顿挪到不敏感的时刻。传空数组是安全的空操作。
func preload_bullet_scenes(bullet_types: Array[BulletType]) -> void:
	for bullet_type in bullet_types:
		get_bullet_scenes(bullet_type)


## 已缓存的子弹场景数量（调试 / 自检用）
func get_cached_scene_count() -> int:
	return _scene_cache.size()
