extends Node

## 约定：业务/UI 只通过本脚本暴露的引用访问（如 `Global.user_manager`、`Global.save_service`、`Global.config_service`），
## 不要直接 `get_node` / `%` 访问 Global 场景里的子节点，避免绕过门面、破坏初始化顺序假设。

## 全局注册表（Character/MainScene/Bullet/Item registry）
# 这里提供便捷的 registry 引用给全局使用者
@onready var character_registry: CharacterRegistry = %CharacterRegistry
@onready var main_scene_registry: MainSceneRegistry = %MainSceneRegistry
@onready var bullet_registry: BulletRegistry = %BulletRegistry
@onready var item_registry: ItemRegistry = %ItemRegistry
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
	## 创建全局数据自动存档计时器（由 SaveService 负责）
	save_service.start_autosave(60.0)


## 在 `user_manager.curr_user_name` 已更新后，加载该用户下的全局存档与配置（与启动时一致）。
func reload_session_for_current_user() -> void:
	if user_manager.curr_user_name.is_empty():
		return
	save_service.load_global_game_data()
	config_service.load_and_apply_config()

var main_game:MainGameManager
var game_para:ResourceLevelData

## 游戏倍速
var time_scale := 1.0


#region 调试快捷键
## 调试快捷键总开关：Ctrl+D（输入映射 ShortcutKeys_WinLevel）
## 按下后进入「等下一个按键」的状态，由**下一个按键**决定要做什么：
##   0 —— 立刻通关本关（走 MgmRewardManager.win_main_game()，不用打完所有波次就能结算本关）
##   1 —— 通关所有冒险关卡（1-1 ~ 5-10 一次全写成已通关 + 解锁沿途植物）
##   2 —— 打开存档文件夹（系统文件管理器定位到当前用户的存档目录）
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
		Log.info("调试快捷键 Ctrl+D：等待下一个按键（0 = 立刻通关本关，1 = 通关所有冒险关卡，2 = 打开存档文件夹）")


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
		_:
			Log.debug("调试快捷键 Ctrl+D + 未知按键，已取消")
			return false


## 「Ctrl+D 然后按 0」：立刻通关本关（必须正在关卡里）
func debug_win_main_game() -> void:
	if not is_instance_valid(main_game):
		Log.info("调试快捷键 Ctrl+D + 0：当前不在关卡内，忽略")
		return
	main_game.shortcut_win_main_game()


## 「Ctrl+D 然后按 1」：通关所有冒险关卡（只写全局关卡数据，不结算当前这一局）
func debug_success_all_adventure_level() -> void:
	var num := global_game_state.success_all_adventure_level()
	Log.info("调试快捷键 Ctrl+D + 1：已通关所有冒险关卡（%d 关），冒险进度 %d" % [num, global_game_state.get_max_success_adventure_level()])


## 「Ctrl+D 然后按 2」：用系统文件管理器打开存档文件夹
## 定位到当前用户的存档目录（user://<用户名>/）：全局存档 + 各关的多轮存档都在这一层下面；
## 还没登录 / 没建账号时退回 user:// 根目录。
func debug_open_save_dir() -> void:
	var dir := "user://"
	if user_manager != null and not user_manager.curr_user_name.is_empty():
		dir = "user://" + user_manager.curr_user_name + "/"
	var abs_path := ProjectSettings.globalize_path(dir)
	var err := OS.shell_open(abs_path)
	Log.info("调试快捷键 Ctrl+D + 2：打开存档文件夹 %s（错误码 %d）" % [abs_path, err])
#endregion

