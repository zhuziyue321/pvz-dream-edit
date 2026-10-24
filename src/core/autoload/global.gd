extends Node

## 约定：业务/UI 只通过本脚本暴露的引用访问（如 `Global.user_manager`、`Global.save_service`、`Global.config_service`），
## 不要直接 `get_node` / `%` 访问 Global 场景里的子节点，避免绕过门面、破坏初始化顺序假设。
##
## **字段边界约定（U-32）**：本单例只放「跨局持久状态 + 注册表/服务引用」。
## 凡「这一局」的运行期对象（关卡参数、本局倍速、当前对局上下文）一律从
## `GameContext.curr_main_game` 取，不要在本文件新增「本局」字段。
## 存量本局字段（见下方 `game_para` / `time_scale`）标记「@本局」并给出迁移去向，
## 新代码调用它们前先确认是否应改走 `GameContext`。

## 全局注册表（Character/MainScene/Bullet/Item registry）
# 这里提供便捷的 registry 引用给全局使用者
@onready var character_registry: CharacterRegistry = %CharacterRegistry
@onready var main_scene_registry: MainSceneRegistry = %MainSceneRegistry
@onready var bullet_registry: BulletRegistry = %BulletRegistry
@onready var item_registry: ItemRegistry = %ItemRegistry
## 控制台条目注册表（控制台面板上的一切条目都从这里来；模组也往这里登记自己的调试开关）
@onready var console_registry: ConsoleRegistry = %ConsoleRegistry
## 用户管理（已从 Global 拆分）
@onready var user_manager: UserManager = %UserManager
## 存档服务
@onready var save_service: SaveService = %SaveService
## 配置服务（用户音量、控制台）
@onready var config_service: ConfigService = %ConfigService
## 全局游戏状态（金币、花园数据、关卡数据、当前植物、当前僵尸）
@onready var global_game_state: GlobalGameState = %GlobalGameState
## 全局只读数据（图鉴数据、刷怪白名单、罐子白名单等）
@onready var global_read_data: GlobalReadData = %GlobalReadData



func _ready() -> void:
	## 读取当前用户名
	user_manager.load_current_user()
	## 没有任何账号时静默创建默认账号，保证启动后一定有可用用户
	user_manager.ensure_default_user()
	if not user_manager.curr_user_name.is_empty():
		reload_session_for_current_user()
	## 不再起定时自动存档：存档一律由业务节点在关键时机调 SaveService.save_now()


## 在 `user_manager.curr_user_name` 已更新后，加载该用户下的全局存档与配置（与启动时一致）。
func reload_session_for_current_user() -> void:
	if user_manager.curr_user_name.is_empty():
		return
	save_service.load_global_game_data()
	config_service.load_and_apply_config()
	## 存档刚把全局状态覆盖过一遍（curr_plant 等）—— 通知已启用模组补一次它们写进
	## 存档态里的东西（见 `ModBase.on_session_reloaded()`）。本体自己不认识任何一个模组。
	## ⚠️ 启动时本函数跑在 `ModManager._ready()` 之前（autoload 顺序），那时它可能是 null。
	if ModManager != null:
		ModManager.notify_session_reloaded()

## ⚠️ **当前局上下文不在 Global 里** —— 唯一持有者是 `GameContext.curr_main_game`。
##
## 历史：这里曾有一个同名转发属性 `Global.main_game`，供 100+ 个存量文件直连。
## 2026-10-11 已全量迁走（`src/` `test/` `data/` 共 117 个文件、473 处），转发属性随之**删除**
## —— 留着它就会不停有人再写 `Global.main_game`，两条路径永远消不掉。
##
## 现在一律走 `GameContext`，或在角色 / 子弹 / 组件里用各自的 `get_main_game()`。

## @本局（U-32）：当前关卡运行期参数，应迁到 `GameContext.curr_main_game`；新代码勿从 Global 取
var game_para:ResourceLevelData

## 游戏倍速
## @本局（U-32）：本局倍速，应迁到 `GameContext`；跨局无此语义，新代码勿从 Global 取
var time_scale := 1.0


#region 调试快捷键
## 调试快捷键总开关：Ctrl+D（输入映射 ShortcutKeys_WinLevel）
## 按下后进入「等下一个按键」的状态，由**下一个按键**决定要做什么：
##   0 —— 立刻通关本关（走 MgmRewardManager.win_main_game()，不用打完所有波次就能结算本关）
##   1 —— 通关所有冒险关卡（1-1 ~ 5-10 一次全写成已通关 + 解锁沿途植物）
##   2 —— 打开存档文件夹（系统文件管理器定位到当前用户的存档目录）
##   3 —— 解锁所有商品（商店货架上的商品全部置为已拥有：紫卡 / 卡槽 / 小推车 / 花园 …）
## 拆成两段是因为调试功能会越加越多，一个组合键占一个功能迟早不够用；
## 顺带的好处是单按 Ctrl+D 不会误改存档，必须再补一个数字键才生效（按别的键 = 取消）。
##
## 挂在 autoload 而不是 MainGameManager 上，是因为「通关所有冒险关卡」这类只动全局存档的操作
## 在选关界面 / 主菜单按才有意义 —— 那里根本没有 MainGameManager。
## 只有「通关本关」需要 MainGameManager 在场，不在关卡里时按 0 会提示并忽略。
## 是否正在等 Ctrl+D 之后的那个按键
var is_waiting_debug_follow_key := false


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	## 第二段：Ctrl+D 之后等着的那个按键（这一下无论认不认都算用掉了这次等待）
	if is_waiting_debug_follow_key:
		is_waiting_debug_follow_key = false
		if _run_debug_follow_key(event):
			get_viewport().set_input_as_handled()
		return
	if Input.is_action_just_pressed("ShortcutKeys_WinLevel"):
		is_waiting_debug_follow_key = true
		get_viewport().set_input_as_handled()


## 执行 Ctrl+D 之后那个按键对应的调试操作
## 返回 true 表示这个按键被快捷键吃掉了（调用方会把事件标记为已处理）
func _run_debug_follow_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	## 非 QWERTY 布局下 keycode 可能是 KEY_NONE，退回物理键位
	var key := key_event.keycode
	if key == KEY_NONE:
		key = key_event.physical_keycode
	match key:
		KEY_0, KEY_KP_0:
			debug_win_main_game()
			return true
		KEY_1, KEY_KP_1:
			debug_success_all_adventure_level()
			return true
		KEY_2, KEY_KP_2:
			debug_open_save_dir()
			return true
		KEY_3, KEY_KP_3:
			debug_unlock_all_shop_goods()
			return true
		_:
			return false


## 「Ctrl+D 然后按 0」：立刻通关本关（必须正在关卡里）
func debug_win_main_game() -> void:
	if not GameContext.is_in_main_game():
		return
	GameContext.curr_main_game.shortcut_win_main_game()


## 「Ctrl+D 然后按 1」：通关所有冒险关卡（只写全局关卡数据，不结算当前这一局）
func debug_success_all_adventure_level() -> void:
	global_game_state.success_all_adventure_level()


## 「Ctrl+D 然后按 2」：用系统文件管理器打开存档文件夹
## 定位到当前用户的存档目录（user://<用户名>/）：全局存档 + 各关的多轮存档都在这一层下面；
## 还没登录 / 没建账号时退回 user:// 根目录。
func debug_open_save_dir() -> void:
	var dir := "user://"
	if user_manager != null and not user_manager.curr_user_name.is_empty():
		dir = "user://" + user_manager.curr_user_name + "/"
	var abs_path := ProjectSettings.globalize_path(dir)
	OS.shell_open(abs_path)


## 「Ctrl+D 然后按 3」：解锁所有商品
## 把商店货架上的商品全部置为已拥有（不扣金币、不动关卡进度），本体在
## GlobalGameState.unlock_all_shop_goods() —— 与 Ctrl+D 1 一样只碰全局存档，
## 所以选关界面 / 主菜单按也生效；商店本身还没开门时先按 1 通关所有冒险关卡。
func debug_unlock_all_shop_goods() -> void:
	var num := global_game_state.unlock_all_shop_goods()
	Log.info("调试快捷键：已解锁商店全部商品，本次新拥有 %d 件" % num)
#endregion
