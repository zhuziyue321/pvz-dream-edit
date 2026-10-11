extends Node
class_name ModManagerClass
## 模组管理器（autoload 单例 `ModManager`）：原版之外的玩法一律做成模组，由本管理器装载
##
## ⚠️ 类名带 `Class` 后缀：autoload 单例名与 `class_name` 同名时，Godot 报
##    "Class 'Xxx' hides an autoload singleton"，且代码里的 `Xxx.yyy()` 会被解析成
##    "在类上调用非静态函数" —— 所以 autoload 脚本要么不写 class_name（如 `EventBus`），
##    要么写成 `XxxClass`（如 `GlobalUtilsClass` / `AllCardsClass`）。
##
## 为什么要有这一层：本仓库的目标是复刻原版，凡是原版没有的玩法（手套、僵尸卡片…）
## 都不该长在本体里 —— 否则"关掉它"就要在本体留一堆 `if is_xxx` 分支
## （历史教训见 [工作记录 2026-10-04 隐藏关卡内手套功能](../../docs/工作记录/2026-10-04_隐藏关卡内手套功能.md)，
## 那次为了隐藏手套要在 5 个本体文件里各堵一层）。
## 做成模组后：关 = 不装载，本体零分支、零节点。
##
## 三条约定：
##   1. **id 走注册表**：id 常量在 `ModIds`，id → 入口脚本的映射只在下面的
##      `MOD_SCRIPT_PATHS`（硬约束 §1-4），业务代码里不许再出现第二张映射表
##   2. **开关与设置都在一份存档里**：`user://<用户名>/mod_config.ini`（**每个用户一份**，
##      与 `config.ini` 同目录；一个模组一个段，`enabled` 是开关，其余键是这个模组自己的设置）。
##      `data/mods/mod_config.tres`（`ModConfig`）退成**工程默认**：只有在这个用户的存档文件
##      还不存在时照它播种一份，之后一律以存档文件为准 —— 页面上开 / 关就真的持久化了。
##   3. **本体不 import 模组**：本体只调 `is_mod_enabled(ModIds.XXX)`
##
## 装载时机：
##   `_ready()`                      —— 游戏启动：装载已启用模组的 `install()`
##   `install_mods_to_main_game(mg)` —— 每局：由 `MainGameManager.init_manager()` 调用，
##                                     排在 `hand_manager.init_manager()` 之前
##
## 换用户：本管理器自己盯 `UserManager.signal_users_update`，存档换一份、模组跟着补装 / 卸载。
##
## 界面：模组的列表与开 / 关在**模组页面**（`src/ui/mod_page/mod_page.tscn`，
## 主菜单 → 选项 → 控制台 →「模组」），本管理器不往控制台挂任何东西。
##
## 关联：ModBase ｜ ModIds ｜ ModConfig ｜ [模组机制](../../docs/参考存档/模组机制.md)

## 模组 id → 入口脚本路径（唯一的一张映射表）
const MOD_SCRIPT_PATHS: Dictionary = {
	ModIds.GLOVE: "res://src/mods/glove/glove_mod.gd",
	ModIds.CUSTOM_LEVEL: "res://src/mods/custom_level/custom_level_mod.gd",
	ModIds.NETPLAY: "res://src/mods/netplay/netplay_mod.gd",
}

## 工程默认开关（`ModConfig`）：**只在存档文件还不存在时播种一次**，之后一律以存档文件为准
const CONFIG_PATH := "res://data/mods/mod_config.tres"
## 模组存档文件名（`user://<当前用户名>/` 下面，与 `config.ini` 同目录）
const MOD_SAVE_FILE := "mod_config.ini"
## 存档文件里「这个模组开没开」的键名（一个模组一个段，段名就是模组 id）
const ENABLED_KEY := "enabled"

## 已创建的模组（不论开关，创建出来是为了让日志 / 将来的界面能列出全部模组）
var all_mods: Dictionary[StringName, ModBase] = {}
## 每个模组的开关状态（启动时由存档文件初始化，运行期可被改）
var enabled_mods: Dictionary[StringName, bool] = {}
## 已经跑过 `install()` 的模组（避免运行期开开关时重复安装）
var installed_mods: Dictionary[StringName, bool] = {}
## 每个模组**自己的设置**：{模组 id = {键 = 值}}（与开关同一份存档文件，见 `get_mod_value()`）
var mod_settings: Dictionary = {}
## 落盘节流标记：一帧里改好几次也只在帧末写一次文件（拖滑条时不会每帧写一遍）
var _save_scheduled := false


func _ready() -> void:
	## 换用户时存档要换一份（自己的那份开关与设置）—— 名字在 `set_current_user()` 里先改好，
	## 信号后发，所以这里读到的已经是新用户
	if Global != null and Global.user_manager != null:
		Global.user_manager.signal_users_update.connect(_on_users_update)
	_load_config()
	_load_save()
	_install_enabled_mods()


#region 装载
## 读工程默认开关（`data/mods/mod_config.tres`）；文件缺失 / 读不出来 = 全部关闭（本体 = 原版体验）
## ⚠️ 它只是**播种用的默认值**：紧接着的 `_load_save()` 会用玩家的存档文件覆盖它
func _load_config() -> void:
	for mod_id in MOD_SCRIPT_PATHS:
		enabled_mods[mod_id] = false
	var config: ModConfig = load(CONFIG_PATH)
	if config == null:
		Log.warn("ModManager: 读不到模组配置 %s，全部模组按关闭处理" % CONFIG_PATH)
		return
	for mod_id in config.enabled_mods:
		if not MOD_SCRIPT_PATHS.has(mod_id):
			Log.error("ModManager: 配置里的模组 id 没有登记 %s" % str(mod_id))
			continue
		enabled_mods[mod_id] = true


## 创建全部模组实例，并给已启用的跑一次全局 install()
func _install_enabled_mods() -> void:
	for mod_id in MOD_SCRIPT_PATHS:
		var mod := _create_mod(mod_id)
		if mod == null:
			continue
		all_mods[mod_id] = mod
		if not is_mod_enabled(mod_id):
			continue
		_install(mod_id, mod)


## 创建一个模组实例（实例化失败只记日志，不让游戏起不来）
func _create_mod(mod_id: StringName) -> ModBase:
	var script_path: String = MOD_SCRIPT_PATHS[mod_id]
	var script: GDScript = load(script_path)
	if script == null:
		Log.error("ModManager: 模组入口脚本加载失败 %s" % script_path)
		return null
	var mod: ModBase = script.new() as ModBase
	if mod == null:
		Log.error("ModManager: 模组入口脚本不是 ModBase 子类 %s" % script_path)
		return null
	return mod


func _install(mod_id: StringName, mod: ModBase) -> void:
	mod.install()
	installed_mods[mod_id] = true
	Log.info("ModManager: 已装载模组 [%s] %s" % [str(mod_id), mod.get_mod_name()])
#endregion


#region 模组存档
## 模组存档文件的路径（`user://<用户名>/mod_config.ini`）；还没有登录用户 = 空串（不读也不写）
func _save_path() -> String:
	if Global == null or Global.user_manager == null or Global.user_manager.curr_user_name.is_empty():
		return ""
	return "user://%s/%s" % [Global.user_manager.curr_user_name, MOD_SAVE_FILE]


## 读存档文件：**开关与模组自己的设置都在这一份里**，读到的覆盖掉工程默认
##
## 文件不存在 = 这个用户第一次启动：保留工程默认（`ModConfig`），并在帧末播种一份存档文件 ——
## 之后玩家在模组页面上的开 / 关与改设置就只跟这份文件打交道，不用再去动 `data/` 里的资源。
func _load_save() -> void:
	mod_settings.clear()
	var path := _save_path()
	if path.is_empty():
		return
	var config := ConfigFile.new()
	if config.load(path) != OK:
		Log.info("ModManager: 没有模组存档 %s，按工程默认播种一份" % path)
		_schedule_save()
		return
	for mod_id in MOD_SCRIPT_PATHS:
		var section := str(mod_id)
		if not config.has_section(section):
			continue
		if config.has_section_key(section, ENABLED_KEY):
			enabled_mods[mod_id] = bool(config.get_value(section, ENABLED_KEY, false))
		var bag: Dictionary = {}
		for key in config.get_section_keys(section):
			if key == ENABLED_KEY:
				continue
			bag[key] = config.get_value(section, key)
		if not bag.is_empty():
			mod_settings[mod_id] = bag
	Log.info("ModManager: 已读模组存档 %s（启用 %d 个）" % [path, _enabled_count()])


## 立刻把「开关 + 全部模组的设置」写进存档文件
##
## 一个模组一个段（段名 = 模组 id），段里 `enabled` 是开关，其余键是这个模组自己的设置：
##   [glove]
##   enabled = true
##   cooldown_enabled = false
##   cooldown_time = 5.0
func save_mods() -> void:
	var path := _save_path()
	if path.is_empty():
		return
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir) and DirAccess.make_dir_recursive_absolute(dir) != OK:
		Log.error("ModManager: 建不出存档目录 %s，模组开关与设置没存下来" % dir)
		return
	var config := ConfigFile.new()
	for mod_id in MOD_SCRIPT_PATHS:
		var section := str(mod_id)
		config.set_value(section, ENABLED_KEY, is_mod_enabled(mod_id))
		var bag: Dictionary = mod_settings.get(mod_id, {})
		for key in bag:
			config.set_value(section, key, bag[key])
	var err := config.save(path)
	if err != OK:
		Log.error("ModManager: 模组存档保存失败 %s（错误码 %d）" % [path, err])


## 改了开关 / 设置之后请一次落盘：合并到帧末写一次（一帧内的多次改动只写一遍文件）
func _schedule_save() -> void:
	if _save_scheduled:
		return
	_save_scheduled = true
	call_deferred("_flush_save")


func _flush_save() -> void:
	_save_scheduled = false
	save_mods()


## 换用户（用户名已改、存档目录随之换了一份）：重读新用户那份存档，模组跟着补装 / 卸载
func _on_users_update() -> void:
	reload_for_current_user()


## 现在开着几个模组（只在日志里用：读档完报一句，省得猜读到的是哪一份）
func _enabled_count() -> int:
	var count := 0
	for mod_id in enabled_mods:
		if enabled_mods[mod_id]:
			count += 1
	return count
#endregion


#region 对外接口
## 某个模组当前是否启用
func is_mod_enabled(mod_id: StringName) -> bool:
	return enabled_mods.get(mod_id, false)


## 取模组实例（未启用也返回，便于日志 / 界面列出全部模组）
func get_mod(mod_id: StringName) -> ModBase:
	return all_mods.get(mod_id)


## 读一个模组**自己的设置**（没存过就返回 [param default_value]）
##
## 设置与开关在**同一份存档文件**里（那一段就是 `get_mod_id()`），键名由模组自己定 ——
## 不用给 `ConfigService` 加字段，也不用自己管存盘（`set_mod_value()` 会安排落盘）。
func get_mod_value(mod_id: StringName, key: String, default_value: Variant = null) -> Variant:
	if not mod_settings.has(mod_id):
		return default_value
	var bag: Dictionary = mod_settings[mod_id]
	return bag.get(key, default_value)


## 写一个模组自己的设置：改内存 + 安排一次落盘（与 `save_mods()` 同一份文件）
func set_mod_value(mod_id: StringName, key: String, value: Variant) -> void:
	if not mod_settings.has(mod_id):
		mod_settings[mod_id] = {}
	var bag: Dictionary = mod_settings[mod_id]
	bag[key] = value
	_schedule_save()


## 改一个模组的开关：**存档文件里也跟着改**（下次启动照旧），模组页面上那个按钮走的就是这里
##   开 = 立即补一次全局 install()；关 = 下一局主游戏不再安装它（并当场 uninstall()）
func set_mod_enabled(mod_id: StringName, value: bool) -> void:
	if not MOD_SCRIPT_PATHS.has(mod_id):
		Log.error("ModManager: 未登记的模组 id %s" % str(mod_id))
		return
	_apply_enabled_state(mod_id, value)
	_schedule_save()


## 只改内存里的开关 + 补装 / 卸载，**不落盘**（换用户重读存档时用：文件本来就是刚读出来的）
func _apply_enabled_state(mod_id: StringName, value: bool) -> void:
	enabled_mods[mod_id] = value
	var mod := get_mod(mod_id)
	if mod == null:
		return
	if value:
		if not installed_mods.get(mod_id, false):
			_install(mod_id, mod)
		return
	if installed_mods.get(mod_id, false):
		mod.uninstall()
		installed_mods[mod_id] = false


## 换用户：模组开关与设置跟着换成新用户那一份（存档文件在用户目录下，一人一份）
##
## 已经建好的模组实例按新的开关补装 / 卸载（与启动时那次装载同一套处理）。
func reload_for_current_user() -> void:
	_load_config()
	_load_save()
	for mod_id in all_mods:
		_apply_enabled_state(mod_id, is_mod_enabled(mod_id))


## 关卡数据就绪的通知（见 `ModBase.on_level_para_ready()`）：给已启用模组改关卡数据的唯一时机
## 由 `MainGameManager._ready()` 调用（排在 `init_manager()` 之前）
func notify_level_para_ready(main_game: MainGameManager) -> void:
	if main_game == null:
		return
	for mod_id in all_mods:
		if not is_mod_enabled(mod_id):
			continue
		all_mods[mod_id].on_level_para_ready(main_game)


## 每局安装：把已启用模组挂进这一局主游戏
## 由 `MainGameManager.init_manager()` 调用（排在 HandManager 注册组件之前）
func install_mods_to_main_game(main_game: MainGameManager) -> void:
	if main_game == null:
		return
	for mod_id in all_mods:
		if not is_mod_enabled(mod_id):
			continue
		all_mods[mod_id].install_to_main_game(main_game)
#endregion
