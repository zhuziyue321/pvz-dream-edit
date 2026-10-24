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
## ★★ 模组在哪：**两个加载源，`user://mods/` 优先**，两份各自独立、**不互相复制**
##   · `user://mods/`        —— **优先**：玩家那份。想改内置模组就把它**整个目录**拷到这里再改；
##                               放自己的模组也在这里（要先在 `MOD_SCRIPT_PATHS` 登记 id）。
##   · `res://mods_builtin/` —— 工程里的内置源（导出后躺在包里）：玩家那份没有 / 读不出来时从这里加载。
##
##   装载时按**模组**判定（见 `_resolve_mod_roots()`）：
##   `user://mods/<入口脚本>` 在 → 整个模组从 `user://mods/` 加载；不在 → 从 `res://mods_builtin/` 加载。
##
##   ⚠️ 一个模组只从**一个根**加载，绝不混着来：模组内部靠 `preload("相对路径")` 互相引用，
##   一半 `user://`、一半包里会错位报错。所以改内置模组要**整个目录拷过去**，
##   拷漏了不会自动退回内置源 —— 那样「改了不生效」更难查，改成启动打一行 warn 列出缺哪些。
##   （模组基类 `mod_base.gd` 不在根里：它只有**框架一份**，在 `res://src/mods/`。）
##
##   内置源永远齐全，所以它是「只给玩家一个游戏文件」时保证模组一定能跑起来的那份；
##   玩家那份**读不出来**时（导出把脚本二进制化后引擎认不出的形态）也会退到这里再试一次。
##
## 三条约定：
##   1. **id 走注册表**：id 常量在 `ModIds`，id → 入口脚本的映射只在下面的
##      `MOD_SCRIPT_PATHS`（硬约束 §1-4），业务代码里不许再出现第二张映射表
##   2. **开关与设置都在一份存档里**：`user://<用户名>/mod_config.ini`（**每个用户一份**，
##      与 `config.ini` 同目录；一个模组一个段，`enabled` 是开关，其余键是这个模组自己的设置）。
##      `data/mods/mod_config.tres`（`ModConfig`）退成**工程默认**：只有在这个用户的存档文件
##      还不存在时照它播种一份，之后一律以存档文件为准 —— 页面上开 / 关就真的持久化了。
##   3. **本体不 import 模组**：本体只调 `is_mod_enabled(ModIds.XXX)`
##   4. **依赖跟着开关走**：模组在 `get_mod_dependencies()` 里声明依赖哪些模组，
##      打开它时依赖一并被打开（递归 + 带环保护），启动 / 换用户时也补一遍；
##      细则见 `get_mod_dependencies()` 与 [模组机制](../../docs/参考存档/模组机制.md) §2.3。
##
## ⚠️ 从 `user://mods/` 加载时，那些脚本**不是**工程脚本，有两条硬限制（Godot 4.6.2 实测）：
##   · 它们的 `class_name` **不会注册成全局类** —— 所以模组内部一律 `extends "相对路径.gd"`
##     与 `const Xxx := preload("xxx.gd")`，**不能**写 `extends ModBase` / `var m: ModBase`；
##     **唯一的例外是模组基类**：它只有框架一份（`res://src/mods/mod_base.gd`），
##     模组入口照写绝对路径 `extends "res://src/mods/mod_base.gd"` —— 两个根下都指向同一份；
##   · 相应地，本文件（在 `res://`）也不能引用任何模组里的类 —— 一律按 `Variant` 动态调用。
##   退回内置源加载时这两条限制会**自动消失**（`res://` 下写相对路径照样能用，只是整套已经按上面的
##   口吻写好了，**不要**因为「这次能写 `extends ModBase`」就去改 —— 玩家那份一回来就会炸）。
##   详见 [模组机制](../../docs/参考存档/模组机制.md) §二与 `mods_builtin/README.md`。
##
## 装载时机：
##   `_ready()`                      —— 游戏启动：定加载根 → 读存档 → 装载已启用模组的 `install()`
##   `install_mods_to_main_game(mg)` —— 每局：由 `MainGameManager.init_manager()` 调用，
##                                     排在 `hand_manager.init_manager()` 之前
##
## 换用户：本管理器自己盯 `UserManager.signal_users_update`，存档换一份、模组跟着补装 / 卸载。
##
## 界面：模组的列表与开 / 关在**模组页面**（`src/ui/mod_page/mod_page.tscn`，
## 主菜单 → 选项 → 控制台 →「模组」），本管理器不往控制台挂任何东西。
##
## 关联：ModIds ｜ ModConfig ｜ [模组机制](../../docs/参考存档/模组机制.md)

## 某个模组的开关变了（开 / 关都发一次）：本体界面连它就能跟着刷新
## （例：主菜单那块「MULTIPLAYER」牌 —— 玩家对战模组没开时整块不显示，
##  在模组页面里把开关拨一下，这块牌要立刻出现 / 消失）
signal mod_enabled_changed(mod_id: StringName, enabled: bool)

## 玩家那一份的根目录（`user://` = 编辑器与导出后同址）：**优先加载**
const MODS_ROOT := "user://mods"
## 内置模组的根（工程内，导出后躺在包里）：玩家那份没有 / 读不出来时的**兜底加载根**
const BUILTIN_MODS_DIR := "res://mods_builtin"
## 不算「模组文件」的后缀：`.uid` 是 Godot 给 `res://` 文件配的 id，`.import` 同理
const IGNORE_SUFFIXES: Array[String] = [".uid", ".import"]

## 模组 id → 入口脚本路径（唯一的一张映射表；**相对加载根**，见 `_mod_script_path()`）
const MOD_SCRIPT_PATHS: Dictionary = {
	ModIds.GLOVE: "glove/glove_mod.gd",
	ModIds.HAMMER: "hammer/hammer_mod.gd",
	ModIds.PURPLE_DIRECT_PLANT: "purple_direct_plant/purple_direct_plant_mod.gd",
	ModIds.MORE_ARMOR: "more_armor/more_armor_mod.gd",
	ModIds.CUSTOM_LEVEL: "custom_level/custom_level_mod.gd",
	ModIds.PLAYER_BATTLE: "player_battle/player_battle_mod.gd",
	ModIds.NETPLAY: "netplay/netplay_mod.gd",
	ModIds.ECO: "eco/eco_mod.gd",
	ModIds.PVZ2: "pvz2/pvz2_mod.gd",
	ModIds.PAM: "pam/pam_mod.gd",
	ModIds.ZHAOXIAO: "zhaoxiao/zhaoxiao_mod.gd",
	ModIds.ARKNIGHTS: "arknights/arknights_mod.gd",
	ModIds.DLC: "dlc/dlc_mod.gd",
	ModIds.DEBUG: "debug/debug_mod.gd",
	ModIds.ZOMBIE_CARD: "zombie_card/zombie_card_mod.gd",
}
## 模组基类（**框架单一一份**，在 `src/mods/`）：用它判断「入口脚本是不是真的继承了 ModBase」
## ⚠️ 它**不在**两个加载根里（`mods_builtin/` 只放模组目录）：模组入口一律
##    `extends "res://src/mods/mod_base.gd"` —— 绝对路径在两个根下都指向同一份，
##    把模组目录拷到 `user://mods/` 时不需要再带一份 `mod_base.gd`
const MOD_BASE_PATH := "res://src/mods/mod_base.gd"
## **旧版布局**里 `mod_base.gd` 的位置（各加载根下那份）：只为认出没跟着升级的玩家模组，
## 别在新模组里用（它们仍能装载，只是基链比的是这两个旧路径）
const LEGACY_MOD_BASE_PATHS: Array[String] = [
	"user://mods/mod_base.gd",
	"res://mods_builtin/mod_base.gd",
]

## 工程默认开关（`ModConfig`）：**只在存档文件还不存在时播种一次**，之后一律以存档文件为准
const CONFIG_PATH := "res://data/mods/mod_config.tres"
## 模组存档文件名（`user://<当前用户名>/` 下面，与 `config.ini` 同目录）
const MOD_SAVE_FILE := "mod_config.ini"
## 存档文件里「这个模组开没开」的键名（一个模组一个段，段名就是模组 id）
const ENABLED_KEY := "enabled"

## 每个模组**当前实际从哪个根加载**（两个源，`MODS_ROOT` 优先；见 `_resolve_mod_roots()`）
var mod_roots: Dictionary[StringName, String] = {}
## 已创建的模组（不论开关，创建出来是为了让日志 / 将来的界面能列出全部模组）
## ⚠️ 值**不能**标成 `ModBase`：基类不写 `class_name`（模组脚本可能在 `user://` 下加载），按名字引用不到
var all_mods: Dictionary = {}
## 每个模组的开关状态（启动时由存档文件初始化，运行期可被改）
var enabled_mods: Dictionary[StringName, bool] = {}
## 已经跑过 `install()` 的模组（避免运行期开开关时重复安装）
var installed_mods: Dictionary[StringName, bool] = {}
## 每个模组**自己的设置**：{模组 id = {键 = 值}}（与开关同一份存档文件，见 `get_mod_value()`）
var mod_settings: Dictionary = {}
## 落盘节流标记：一帧里改好几次也只在帧末写一次文件（拖滑条时不会每帧写一遍）
var _save_scheduled := false
## 素材缓存：`"<模组 id>/<相对路径>"` → 读到的 Resource（见 `load_mod_asset()`）
var _asset_cache: Dictionary = {}
## 已经因为「用的是旧版 ModBase」告警过的模组（每个模组只告警一次，别刷屏）
## 用途见 `_warn_legacy_mod()`：删掉三处 `has_method()` 兼容分支之前，先看这里还剩谁（TODO L-29）
var _legacy_mod_warned: Dictionary[StringName, bool] = {}


func _ready() -> void:
	## 换用户时存档要换一份（自己的那份开关与设置）—— 名字在 `set_current_user()` 里先改好，
	## 信号后发，所以这里读到的已经是新用户
	if Global != null and Global.user_manager != null:
		Global.user_manager.signal_users_update.connect(_on_users_update)
	_resolve_mod_roots()
	_load_config()
	_load_save()
	_install_enabled_mods()


## 某个模组入口脚本的**当前生效**路径（`<加载根>/<id>/<xxx>_mod.gd`）
func _mod_script_path(mod_id: StringName) -> String:
	return _mod_root(mod_id).path_join(MOD_SCRIPT_PATHS[mod_id])


## 这个模组从哪个根加载：**玩家那份优先**，那份没有就用内置源（未解析过也给内置源）
func _mod_root(mod_id: StringName) -> String:
	return mod_roots.get(mod_id, BUILTIN_MODS_DIR)


#region 加载根：两个源，user://mods 优先
## 定每个模组的**加载根**：玩家那份有入口脚本就用它，没有就用内置源
##
## 两个源**不互相复制**（2026-10-15 起）：仓库里的内置源不再往 `user://mods/` 铺一份，
## 玩家想改哪个内置模组，自己把**整个目录**拷到 `user://mods/` 下再改 —— 拷过去才生效，
## 没拷就跑内置源那份（永远齐全）。
## 早先的「启动自动复制 + 内容指纹决定要不要重铺」已撤销：它会把玩家改过的文件冲回去，
## 也多一份「到底跑的是哪边」的解释成本；现在哪边有就跑哪边，一眼可判。
##
## 判定粒度是**整个模组**：一个模组只从一个根加载 —— 模组内部靠 `preload("相对路径")` 互相引用，
## 混着来会错位报错。玩家那份**缺文件**不退回内置源（改了不生效更难查），只打一行 warn 列清单。
func _resolve_mod_roots() -> void:
	mod_roots.clear()
	## 加载根可能变（玩家那份来 / 走），缓存过的素材要作废
	_asset_cache.clear()
	var from_user: Array[String] = []
	var from_builtin: Array[String] = []
	for mod_id in MOD_SCRIPT_PATHS:
		var rel_script := String(MOD_SCRIPT_PATHS[mod_id])
		if FileAccess.file_exists(MODS_ROOT.path_join(rel_script)):
			mod_roots[mod_id] = MODS_ROOT
			from_user.append(str(mod_id))
			_warn_missing_files(mod_id)
			continue
		mod_roots[mod_id] = BUILTIN_MODS_DIR
		from_builtin.append(str(mod_id))
	Log.info("ModManager: 模组加载根 —— 玩家目录 %d 个 [%s]，内置源 %d 个 [%s]" % [
		from_user.size(), ", ".join(from_user), from_builtin.size(), ", ".join(from_builtin)])


## 玩家那份**缺哪些文件**（对比内置源的同名目录）：只报不改判定，让玩家自己补
func _warn_missing_files(mod_id: StringName) -> void:
	var rel_dir := String(MOD_SCRIPT_PATHS[mod_id]).get_base_dir()
	var missing: Array[String] = []
	_collect_missing_files(
		BUILTIN_MODS_DIR.path_join(rel_dir), MODS_ROOT.path_join(rel_dir), rel_dir, missing)
	if missing.is_empty():
		return
	Log.warn("ModManager: [%s] 玩家那份 %s 缺 %d 个文件 [%s] —— 整个模组只从玩家那份加载，缺的请补上" % [
		str(mod_id), MODS_ROOT.path_join(rel_dir), missing.size(), ", ".join(missing)])


## 递归收集 `src_dir` 里有、`dst_dir` 里没有的文件（跳过 `.uid` / `.import`）
func _collect_missing_files(src_dir: String, dst_dir: String, rel_dir: String, out: Array[String]) -> void:
	var dir := DirAccess.open(src_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if not entry_name.begins_with("."):
			var rel := rel_dir.path_join(entry_name)
			if dir.current_is_dir():
				_collect_missing_files(
					src_dir.path_join(entry_name), dst_dir.path_join(entry_name), rel, out)
			elif not _is_ignored_file(entry_name) and not FileAccess.file_exists(dst_dir.path_join(entry_name)):
				out.append(rel)
		entry_name = dir.get_next()
	dir.list_dir_end()


func _is_ignored_file(file_name: String) -> bool:
	for suffix in IGNORE_SUFFIXES:
		if file_name.ends_with(suffix):
			return true
	return false
#endregion


#region 装载
## 读工程默认开关（`data/mods/mod_config.tres`）；文件缺失 / 读不出来 = 全部关闭（本体 = 原版体验）
## ⚠️ 它只是**播种用的默认值**：紧接着的 `_load_save()` 会用玩家的存档文件覆盖它
func _load_config() -> void:
	for mod_id in MOD_SCRIPT_PATHS:
		enabled_mods[mod_id] = false
	var config = load(CONFIG_PATH)
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
	## 先把实例建齐：依赖声明要读模组自己（`get_mod_dependencies()`），实例不齐读不到
	for mod_id in MOD_SCRIPT_PATHS:
		var mod = _create_mod(mod_id)
		if mod == null:
			continue
		all_mods[mod_id] = mod
	## 实例齐了再补依赖：已启用模组缺的依赖一并打开（只改内存，帧末那次存档照此写）
	_ensure_dependencies_enabled()
	for mod_id in MOD_SCRIPT_PATHS:
		var mod = all_mods.get(mod_id)
		if mod == null or not is_mod_enabled(mod_id):
			continue
		_install(mod_id, mod)


## 把**已启用模组**声明依赖的模组一并补开（递归，带环保护）
##
## 为什么启动时要补一遍：存档文件可能被手改过、或工程默认（`data/mods/mod_config.tres`）
## 里开了 A 漏了 B —— 缺了依赖的模组是"开着却跑不起来"的状态，不如启动时补齐。
## 只改内存不落盘：紧接着的存档写入会把补齐后的开关一起写掉（本来就是打开时才补的）。
func _ensure_dependencies_enabled() -> void:
	for mod_id in all_mods:
		if is_mod_enabled(mod_id):
			_enable_dependencies_first(mod_id, {})


## 打开 `mod_id` 之前，先把它依赖的模组逐个打开（递归；`visited` 防环）
## 已经开着的依赖不再递归 —— 它当初被打开时，它的依赖已经补过一遍了
func _enable_dependencies_first(mod_id: StringName, visited: Dictionary) -> void:
	if visited.has(mod_id):
		Log.error("ModManager: 模组依赖成环，环上的开关不自动补开（环入口 [%s]）" % str(mod_id))
		return
	visited[mod_id] = true
	for dep_id in get_mod_dependencies(mod_id):
		if is_mod_enabled(dep_id):
			continue
		Log.info("ModManager: [%s] 依赖 [%s]，打开 [%s] 时把依赖一并打开" % [
			str(mod_id), str(dep_id), str(mod_id)])
		_enable_dependencies_first(dep_id, visited)
		_apply_enabled_state(dep_id, true)


## 创建一个模组实例（实例化失败只记日志，不让游戏起不来）
##
## ⚠️ 返回值不能标 `ModBase`：入口脚本可能来自 `user://`（那里 `class_name` 不注册为全局类，
## 见类注释）。校验「是不是真的继承了 ModBase」也不能用
## `Script.instance_has()` —— user:// 下的脚本不走资源缓存，每次 `load()` 都是新对象，
## 指针比不上，实测恒为 false；改成沿 `get_base_script()` 基链比 **路径**。
##
## 最后一重兜底：入口脚本在（判过 `FileAccess.file_exists`）却**读不出来** —— 导出把脚本二进制化后
## `user://` 那份可能是引擎认不出的形态。这时退内置源再试一次，总比整个模组静默消失好。
func _create_mod(mod_id: StringName):
	var script_path := _mod_script_path(mod_id)
	## 局部变量不叫 script：本类继承 Node，`script` 是 Object 的属性，同名会触发 SHADOWED_VARIABLE_BASE_CLASS
	var mod_script = load(script_path)
	if mod_script == null and _mod_root(mod_id) != BUILTIN_MODS_DIR:
		Log.warn("ModManager: [%s] 玩家那份读不出来 %s，退回内置源" % [str(mod_id), script_path])
		mod_roots[mod_id] = BUILTIN_MODS_DIR
		script_path = _mod_script_path(mod_id)
		mod_script = load(script_path)
	if mod_script == null:
		Log.error("ModManager: 模组入口脚本加载失败 %s" % script_path)
		return null
	var mod = mod_script.new()
	if mod == null:
		Log.error("ModManager: 模组入口脚本实例化失败 %s" % script_path)
		return null
	if not _extends_mod_base(mod):
		Log.error("ModManager: 模组入口脚本不是 ModBase 子类 %s" % script_path)
		return null
	return mod


## 实例的基链里有没有 `mod_base.gd`（比 `instance_has()` 可靠，见 `_create_mod` 注释）
## 新模组一律 `extends "res://src/mods/mod_base.gd"`（单一一份）；旧版在各自加载根下带一份，
## 那两个路径也认（`LEGACY_MOD_BASE_PATHS`），否则没跟着升级的玩家模组会被误判成「不是 ModBase 子类」
func _extends_mod_base(mod) -> bool:
	var sc = mod.get_script()
	while sc != null:
		if sc.resource_path == MOD_BASE_PATH or LEGACY_MOD_BASE_PATHS.has(sc.resource_path):
			return true
		sc = sc.get_base_script()
	return false


## 旧版 `ModBase` 兼容告警（每个模组只告警一次）
##
## `user://mods/` 下可能躺着没跟着升级的模组，它们的入口脚本缺新方法。
## 本体因此不得不在三处写 `has_method()` 兜底（`_install` / 卸载 / `get_mod_dependencies`），
## 每给 `ModBase` 加一个能力就多一处兜底 —— 见 TODO L-29。
## 这里先做**统计与点名**，等日志里不再出现这条 warn，才能整批删掉兼容分支。
func _warn_legacy_mod(mod_id: StringName, mod) -> void:
	if _legacy_mod_warned.get(mod_id, false):
		return
	_legacy_mod_warned[mod_id] = true
	var mod_name: String = str(mod_id)
	if mod != null and mod.has_method("get_mod_name"):
		mod_name = mod.get_mod_name()
	Log.warn("ModManager: 模组 [%s] %s 用的是**旧版 ModBase**（缺伤害修饰器接口），已走兼容分支；请升级该模组，否则本体后续新能力它拿不到" % [str(mod_id), mod_name])


func _install(mod_id: StringName, mod) -> void:
	mod.install()
	installed_mods[mod_id] = true
	## 把本模组的伤害修饰器接进 DamageSystem 的修饰器链（mod_base.gd 提供；旧版没有则跳过）
	if mod.has_method("_install_damage_modifiers"):
		mod._install_damage_modifiers()
	else:
		_warn_legacy_mod(mod_id, mod)
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
func get_mod(mod_id: StringName):
	return all_mods.get(mod_id)


## 这个模组**声明依赖**哪些模组（入口脚本里重写 `ModBase.get_mod_dependencies()`）
##
## 只返回**登记在册**的 id：未登记的（写歪了 / 模组删了）与自己依赖自己，
## 各打一行 error 后剔除（去重、保模组声明的顺序）—— 界面与补开逻辑都只认这里的结果。
## 旧版入口脚本（`user://mods/` 下没跟着升级的那份）没有这个方法 = 空数组，
## 所以调用方一律 `has_method()` 防御式转调，别直接 `mod.get_mod_dependencies()`。
func get_mod_dependencies(mod_id: StringName) -> Array[StringName]:
	var mod = get_mod(mod_id)
	if mod == null or not mod.has_method("get_mod_dependencies"):
		return []
	var out: Array[StringName] = []
	for dep in mod.get_mod_dependencies():
		var dep_id := StringName(dep)
		if dep_id == mod_id:
			Log.error("ModManager: 模组 [%s] 声明依赖自己，已忽略" % str(mod_id))
			continue
		if not MOD_SCRIPT_PATHS.has(dep_id):
			Log.error("ModManager: 模组 [%s] 依赖了未登记的模组 [%s]，已忽略" % [
				str(mod_id), str(dep_id)])
			continue
		if not out.has(dep_id):
			out.append(dep_id)
	return out


## 这个模组**当前实际**从哪个根加载（`MODS_ROOT` / `BUILTIN_MODS_DIR`）
## 模组里要拼自己的资源路径（场景 / 脚本 / 图片）就用这个 —— 别去抄根目录常量：
## 根是启动期定的，写死成 `user://mods` 会在「这份跑的是内置源」时指到空目录
func get_mod_root(mod_id: StringName) -> String:
	return _mod_root(mod_id)


## 读一个模组**自己的素材**（贴图 / 场景 / 资源）：`rel_path` 相对**模组目录**
## （例：`"tongtong.png"` / `"bonkchoy/bonkchoy_88x73.png"`），读不到给 null。
##
## 为什么要有这个口子 —— 模组有两个加载根（`user://mods/` 优先 / `res://mods_builtin/` 兜底），
## 而 `user://` 下的图片**不走引擎导入管线**（`.import` 只对 `res://` 生效），
## 直接 `load("user://...png")` 拿不到 Texture2D。本方法统一处理：
##   · 先按本模组**当前生效的加载根**拼出完整路径；
##   · 优先 `load()`（`res://` 下图片已导入 = 直接得 Texture2D；`.tscn` / `.tres` 两根都行）；
##   · 拿不到且文件在时，退回 `Image.load_from_file()` + `ImageTexture`（`user://` 那份）。
## 结果按「模组 + 相对路径」缓存，同一个素材读多次只解码一次。
##
## 模组素材请走这个口子（别再 `preload("res://assets_custom/...")` 塞进本体 —— 那样模组不自包含、
## 导出后 `user://` 那份也读不到）；模组入口（`ModBase` 子类）可直接用 `load_asset()` 转调这里。
func load_mod_asset(mod_id: StringName, rel_path: String) -> Resource:
	var key := "%s/%s" % [str(mod_id), rel_path]
	if _asset_cache.has(key):
		return _asset_cache[key]
	var full := _mod_dir(mod_id).path_join(rel_path)
	var res: Resource = null
	if ResourceLoader.exists(full):
		res = load(full)
	if res == null and FileAccess.file_exists(full):
		## `user://` 下的图片没被引擎导入过：直接读原始文件再包成 ImageTexture
		var image := Image.load_from_file(full)
		if image != null:
			res = ImageTexture.create_from_image(image)
	if res == null:
		Log.error("ModManager: 读不到模组 [%s] 的素材 %s（模组目录 %s）" % [
			str(mod_id), rel_path, _mod_dir(mod_id)])
		return null
	_asset_cache[key] = res
	return res


## 模组素材的完整路径（按当前加载根 + 模组目录拼出，不读文件）—— 给需要**路径**的地方用（如探针断言）
func get_mod_asset_path(mod_id: StringName, rel_path: String) -> String:
	return _mod_dir(mod_id).path_join(rel_path)


## 一个模组**自己的目录**（`<加载根>/<id 目录>`）：`MOD_SCRIPT_PATHS[id]` 是
## `<id 目录>/<入口脚本>`，所以取它的目录那一段 —— `_mod_root()` 返回的是**父目录**，
## 直接 path_join(rel_path) 会少一层模组目录
func _mod_dir(mod_id: StringName) -> String:
	return _mod_root(mod_id).path_join(String(MOD_SCRIPT_PATHS[mod_id]).get_base_dir())


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
##   开 = 先把它**声明依赖**的模组一并打开（递归，见 `_enable_dependencies_first()`），
##        再立即补一次全局 install()；关 = 下一局主游戏不再安装它（并当场 uninstall()）
##   ⚠️ 只补开、不连锁关：关掉一个被依赖的模组不会连带关掉依赖者（那是玩家自己的选择，
##      他会在模组页面详情末尾的依赖列表里看到哪个依赖"未启用"）。
func set_mod_enabled(mod_id: StringName, value: bool) -> void:
	if not MOD_SCRIPT_PATHS.has(mod_id):
		Log.error("ModManager: 未登记的模组 id %s" % str(mod_id))
		return
	if value:
		_enable_dependencies_first(mod_id, {})
	_apply_enabled_state(mod_id, value)
	_schedule_save()


## 只改内存里的开关 + 补装 / 卸载，**不落盘**（换用户重读存档时用：文件本来就是刚读出来的）
func _apply_enabled_state(mod_id: StringName, value: bool) -> void:
	enabled_mods[mod_id] = value
	var mod = get_mod(mod_id)
	if mod != null:
		if value:
			if not installed_mods.get(mod_id, false):
				_install(mod_id, mod)
		elif installed_mods.get(mod_id, false):
			mod.uninstall()
			installed_mods[mod_id] = false
			## 摘掉本模组注册进 DamageSystem 的伤害修饰器（旧版 mod_base 没有则跳过）
			if mod.has_method("_uninstall_damage_modifiers"):
				mod._uninstall_damage_modifiers()
			else:
				_warn_legacy_mod(mod_id, mod)
	## 开关真的变了：通知外面一声（本体界面按这个刷新，如主菜单那块「MULTIPLAYER」牌）
	mod_enabled_changed.emit(mod_id, value)


## 换用户：模组开关与设置跟着换成新用户那一份（存档文件在用户目录下，一人一份）
##
## 已经建好的模组实例按新的开关补装 / 卸载（与启动时那次装载同一套处理）。
func reload_for_current_user() -> void:
	_load_config()
	_load_save()
	## 新用户那份存档也可能漏开依赖（手改过 / 工程默认漏登记）：补开后再按新开关补装 / 卸载
	_ensure_dependencies_enabled()
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


## 全局存档重读完的通知（见 `ModBase.on_session_reloaded()`）
## 由 `Global.reload_session_for_current_user()` 在读档之后调用：存档把全局状态覆盖过，
## 已启用模组在这里补回它们写进那些状态里的东西（旧版模组没有这个方法则跳过）。
func notify_session_reloaded() -> void:
	for mod_id in all_mods:
		if not is_mod_enabled(mod_id):
			continue
		var mod = all_mods[mod_id]
		if mod != null and mod.has_method("on_session_reloaded"):
			mod.on_session_reloaded()
#endregion
