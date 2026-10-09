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
##   2. **开关在数据层**：`data/mods/mod_config.tres`（`ModConfig.enabled_mods`）
##   3. **本体不 import 模组**：本体只调 `is_mod_enabled(ModIds.XXX)`
##
## 装载时机：
##   `_ready()`                      —— 游戏启动：装载已启用模组的 `install()`，
##                                     并给每个模组往控制台登记一个「开 / 关本模组」的开关
##   `install_mods_to_main_game(mg)` —— 每局：由 `MainGameManager.init_manager()` 调用，
##                                     排在 `hand_manager.init_manager()` 之前
##
## 关联：ModBase ｜ ModIds ｜ ModConfig ｜ [模组机制](../../docs/参考存档/模组机制.md)

## 模组 id → 入口脚本路径（唯一的一张映射表）
const MOD_SCRIPT_PATHS: Dictionary = {
	ModIds.GLOVE: "res://src/mods/glove/glove_mod.gd",
	ModIds.CUSTOM_LEVEL: "res://src/mods/custom_level/custom_level_mod.gd",
	ModIds.NETPLAY: "res://src/mods/netplay/netplay_mod.gd",
}

## 模组开关的数据资源
const CONFIG_PATH := "res://data/mods/mod_config.tres"

## 已创建的模组（不论开关，创建出来是为了让日志 / 将来的界面能列出全部模组）
var all_mods: Dictionary[StringName, ModBase] = {}
## 每个模组的开关状态（启动时由 `ModConfig` 初始化，运行期可被改）
var enabled_mods: Dictionary[StringName, bool] = {}
## 已经跑过 `install()` 的模组（避免运行期开开关时重复安装）
var installed_mods: Dictionary[StringName, bool] = {}


func _ready() -> void:
	_load_config()
	_install_enabled_mods()


#region 装载
## 读数据层的开关清单；文件缺失 / 读不出来 = 全部关闭（本体 = 原版体验）
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
		_register_mod_switch(mod_id, mod)
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
	_register_console_entries(mod_id, mod)
	Log.info("ModManager: 已装载模组 [%s] %s" % [str(mod_id), mod.get_mod_name()])
#endregion


#region 控制台（模组开发的快捷工具）
## 取控制台注册表（拿不到就返回 null，缺它不该让游戏起不来）
func _console_registry() -> ConsoleRegistry:
	if Global == null:
		return null
	return Global.console_registry


## 给每个模组在控制台的「模组」组里放一个开关：不用改 .tres 就能开 / 关模组
func _register_mod_switch(mod_id: StringName, mod: ModBase) -> void:
	var registry := _console_registry()
	if registry == null:
		return
	registry.register_entry(ConsoleEntry.create_toggle(
			StringName("mod_switch_" + str(mod_id)), mod.get_mod_name())
		.set_tooltip(mod.get_mod_description())
		.set_category(ConsoleRegistry.CATEGORY_MOD)
		.set_source(&"mod_manager")
		.bind(func() -> bool: return is_mod_enabled(mod_id),
			func(value: bool) -> void: set_mod_enabled(mod_id, value)))


## 让模组自己往控制台加条目（重写 `ModBase.register_console_entries()`）
func _register_console_entries(mod_id: StringName, mod: ModBase) -> void:
	var registry := _console_registry()
	if registry == null:
		return
	mod.register_console_entries(registry)


## 关掉模组时把它登记过的控制台条目整组撤销（模组开关自己留着，方便再打开）
func _unregister_console_entries(mod_id: StringName) -> void:
	var registry := _console_registry()
	if registry == null:
		return
	registry.unregister_source(mod_id)
#endregion


#region 对外接口
## 某个模组当前是否启用
func is_mod_enabled(mod_id: StringName) -> bool:
	return enabled_mods.get(mod_id, false)


## 取模组实例（未启用也返回，便于日志 / 界面列出全部模组）
func get_mod(mod_id: StringName) -> ModBase:
	return all_mods.get(mod_id)


## 运行期改开关：关闭 = 下一局主游戏不再安装它；打开 = 立即补一次全局 install()
## （调试 / 探针用，正式开关改 `data/mods/mod_config.tres`）
func set_mod_enabled(mod_id: StringName, value: bool) -> void:
	if not MOD_SCRIPT_PATHS.has(mod_id):
		Log.error("ModManager: 未登记的模组 id %s" % str(mod_id))
		return
	enabled_mods[mod_id] = value
	if not value:
		_unregister_console_entries(mod_id)
		var mod := get_mod(mod_id)
		if mod != null and installed_mods.get(mod_id, false):
			mod.uninstall()
			installed_mods[mod_id] = false
		return
	var mod2 := get_mod(mod_id)
	if mod2 != null and not installed_mods.get(mod_id, false):
		_install(mod_id, mod2)


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
