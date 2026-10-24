extends RefCounted
class_name AssetRegistry

## 资源注册表：**图片 / 音频 / 字体 / 场景 / 任意 Resource 的统一取用口**
##
## 为什么要有它：原先「取资源」没有统一入口 —— 一部分散在各家注册表的字典里 `preload`
## （`SceneRegistry` / `LootRegistry` / `SoundManager`），一部分在业务脚本里裸写
## `load("res://pak/...")`。同一个贴图被几个脚本各加载一份；音效表在启动时把上百条
## `.ogg` 全部常驻内存。现在统一走这里：**按路径缓存 + 可给路径起逻辑 id + 运行期可注册**。
##
## 三种 key 都行，混用不冲突：
##   AssetRegistry.get_texture("res://pak/images/Taco.png")     ## 绝对路径（硬约束 §1-5）
##   AssetRegistry.register(&"loot_taco", "res://pak/images/Taco.png")
##   AssetRegistry.get_texture(&"loot_taco")                    ## 逻辑 id
##   AssetRegistry.register_asset(&"mod_logo", some_texture)     ## 内存资源（模组用）
##
## 约定：
##   · **新代码取资源一律走这里**，不要再写裸 `load()` / 无理由的 `preload()`；
##     `.tscn` 里的 `ext_resource` 不受影响 —— 那是场景数据绑定，不是代码取用。
##   · 缓存 key 是**解析后的路径**，同一个文件即使用 id 和路径各取一次也只加载一份。
##   · 缓存是进程级的（static 变量），**不随场景切换清空**；要回收调 `clear_cache()`。
##   · 取不到 / 类型不符一律返回 `null` 并 `Log.error`，调用方照旧判空
##     （与 `BulletRegistry.get_bullet_scenes` 的行为一致）。
##   · 本表**不做自动目录扫描**：路径就是唯一真相，id 只是给人 / 模组用的别名。

## 已登记的逻辑 id → 资源路径（res:// 绝对路径）
static var _id_paths: Dictionary = {}
## 已登记的逻辑 id → 内存里的资源（模组直接给对象，没有磁盘路径）
static var _id_resources: Dictionary = {}
## 已加载资源缓存：资源路径 → Resource（贴图 / 音频 / 字体 / PackedScene / 其它）
static var _cache: Dictionary = {}


#region 运行时注册
## 登记一个逻辑 id → 资源路径
##
## 同一 id 重复登记 = 覆盖；新路径第一次被取用时才真正加载。
## 模组 / 自制关卡想用自己的素材而又不想在业务代码里写死路径时用这个口。
static func register(id: StringName, path: String) -> void:
	if id == &"":
		_log_error("AssetRegistry.register: id 不能为空")
		return
	if path == "":
		_log_error("AssetRegistry.register: 路径不能为空（id=%s）" % String(id))
		return
	if not path.begins_with("res://") and not path.begins_with("user://"):
		_log_error("AssetRegistry.register: 路径必须是 res:// 或 user:// 绝对路径（id=%s, path=%s）" % [String(id), path])
		return
	_id_paths[id] = path
	_id_resources.erase(id)


## 批量登记：{id: 路径}，等价于对每一项调 `register()`
static func register_many(table: Dictionary) -> void:
	for id: Variant in table.keys():
		register(StringName(id), String(table[id]))


## 登记一个**已在内存里**的资源（没有磁盘路径的场合：模组现生成的贴图 / 主题）
static func register_asset(id: StringName, resource: Resource) -> void:
	if id == &"":
		_log_error("AssetRegistry.register_asset: id 不能为空")
		return
	if resource == null:
		_log_error("AssetRegistry.register_asset: 资源为 null（id=%s）" % String(id))
		return
	_id_resources[id] = resource
	_id_paths.erase(id)


## 撤销一个逻辑 id（不影响已经进入缓存、被别处持有着的资源）
static func unregister(id: StringName) -> void:
	_id_paths.erase(id)
	_id_resources.erase(id)


## 这个 id 有没有登记（路径 key 不算）
static func has(id: StringName) -> bool:
	return _id_paths.has(id) or _id_resources.has(id)


## 逻辑 id 登记的资源路径；没登记 / 登记的是内存资源时返回空串
static func get_path(id: StringName) -> String:
	return String(_id_paths.get(id, ""))
#endregion


#region 取资源（带缓存）
## 把 key 解析成资源路径：给 res:// / user:// 就原样返回，给逻辑 id 就查表，查不到返回空串
static func resolve_path(key: Variant) -> String:
	if key == null:
		return ""
	var text := String(key)
	if text == "":
		return ""
	if text.begins_with("res://") or text.begins_with("user://"):
		return text
	return String(_id_paths.get(StringName(text), ""))


## 取一张贴图（png / jpg / webp，含 atlas 里的整图）
static func get_texture(key: Variant) -> Texture2D:
	var res := _get_resource(key)
	if res == null:
		return null
	if res is Texture2D:
		return res
	_log_type_error(key, "Texture2D", res)
	return null


## 取一段音频（ogg / mp3 / wav）
static func get_audio(key: Variant) -> AudioStream:
	var res := _get_resource(key)
	if res == null:
		return null
	if res is AudioStream:
		return res
	_log_type_error(key, "AudioStream", res)
	return null


## 取一个字体（ttf / ttc / otf）
static func get_font(key: Variant) -> Font:
	var res := _get_resource(key)
	if res == null:
		return null
	if res is Font:
		return res
	_log_type_error(key, "Font", res)
	return null


## 取一个场景（PackedScene，取到的是**模板**，要实例化请用 `instantiate()`）
static func get_scene(key: Variant) -> PackedScene:
	var res := _get_resource(key)
	if res == null:
		return null
	if res is PackedScene:
		return res
	_log_type_error(key, "PackedScene", res)
	return null


## 取任意资源（.tres / 自定义 Resource 等）
static func get_resource(key: Variant) -> Resource:
	return _get_resource(key)


## 取场景并实例化（**只创建，不入场景树**，调用方负责 add_child / queue_free）
static func instantiate(key: Variant) -> Node:
	var scene := get_scene(key)
	if scene == null:
		return null
	return scene.instantiate()


## 预热：把一批 key 提前加载进缓存（传空数组是安全的空操作）
##
## 按需加载的代价是「第一次取用要等一次磁盘 IO」。已知即将用到哪些素材时
## （关卡载入 / 演出开始前）调一次，把卡顿挪到不敏感的时刻。
static func prefetch(keys: Array) -> void:
	for key: Variant in keys:
		_get_resource(key)
#endregion


#region 缓存维护
## 这个 key 当前在不在缓存里
static func is_cached(key: Variant) -> bool:
	var path := resolve_path(key)
	if path == "":
		return _id_resources.has(StringName(String(key)))
	return _cache.has(path)


## 已缓存的资源数量
static func get_cached_count() -> int:
	return _cache.size()


## 已缓存的资源路径（调试 / 自检用，返回的是副本）
static func get_cached_paths() -> Array[String]:
	var paths: Array[String] = []
	for path: Variant in _cache.keys():
		paths.append(String(path))
	return paths


## 丢掉一个 key 的缓存（资源仍被别处持有时不会释放；下次取用重新加载）
static func uncache(key: Variant) -> void:
	var path := resolve_path(key)
	if path != "":
		_cache.erase(path)


## 丢掉**全部**资源缓存（id 表与内存资源保留）
##
## 用途：切章节 / 回主菜单后回收内存。注意只是从缓存里摘掉引用，
## 仍被场景节点持有着的资源不会真的释放。
static func clear_cache() -> void:
	_cache.clear()


## 清空一切：缓存 + 逻辑 id + 内存资源（等同刚启动的状态，主要给测试用）
static func clear_all() -> void:
	_cache.clear()
	_id_paths.clear()
	_id_resources.clear()


## 强制重新从磁盘加载一个 key（改过素材后热重载用）
static func reload(key: Variant) -> Resource:
	var path := resolve_path(key)
	if path == "":
		return _get_resource(key)
	_cache.erase(path)
	return _get_resource(path)


## 当前状态快照（调试窗口 / 控制台展示用）
static func get_stats() -> Dictionary:
	return {
		"cached": _cache.size(),
		"ids": _id_paths.size(),
		"runtime_assets": _id_resources.size(),
	}
#endregion


#region 内部
## 统一取资源：内存资源 → 缓存 → 磁盘加载
static func _get_resource(key: Variant) -> Resource:
	var path := resolve_path(key)
	if path == "":
		var mem_id := StringName(String(key))
		if _id_resources.has(mem_id):
			return _id_resources[mem_id] as Resource
		_log_error("资源 key 未登记（既不是 res:// 路径，也不是已注册 id）: %s" % String(key))
		return null

	if _cache.has(path):
		return _cache[path] as Resource

	if not ResourceLoader.exists(path):
		_log_error("资源不存在: %s（key=%s）" % [path, String(key)])
		return null

	var res: Resource = load(path)
	if res == null:
		_log_error("资源加载失败（不是有效资源？）: %s（key=%s）" % [path, String(key)])
		return null

	_cache[path] = res
	return res


static func _log_type_error(key: Variant, expected: String, res: Resource) -> void:
	_log_error("资源类型不符：期望 %s，实际 %s（key=%s）" % [expected, res.get_class(), String(key)])


## 本类会在 autoload（`SceneRegistry` 等）的成员初始化阶段被调用，
## 那时 `Log` 可能还没挂上，所以取不到就走 `push_error` 兜底而不是直接崩。
static func _log_error(msg: String) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	if loop != null and loop.root != null and loop.root.has_node_or_null(^"Log") != null:
		Log.error(msg)
	else:
		push_error(msg)
#endregion
