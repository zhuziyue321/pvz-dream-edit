extends Node
## 调试通道（自动加载名: DebugChannel）
##
## 目的：把「运行期才暴露、静态扫描查不出」的问题变成一份可回传的报告。
## 默认**完全静默**，只有满足以下任一条件才激活：
##   1. 命令行带用户参数:  godot --path . -- --debug-channel
##                        godot --path . -- --debug-channel-level   （额外自动跑一关）
##   2. 存在开关文件:      user://debug_channel.on
##
## 激活后：
##   - 启动时跑一遍只读探针（环境 / 自动加载 / 日志自检 / 注册表 / 运行时状态）
##   - 每 120 帧采样一次 FPS、节点数、孤儿节点数
##   - 按 F10 随时写一份当前状态快照
##   - 报告同时写入文件并打印到 stdout，方便用批处理重定向成单个日志
##
## 报告与状态采集复用 test/autopilot_report.gd 与 test/autopilot_state.gd
## —— 以前这里和 autopilot 各写一份落盘与格子/僵尸统计，改一处必然漏另一处。
##
## 报告路径会在控制台打印，形如:
##   [调试通道] 报告已写入: C:/Users/xxx/AppData/Roaming/Godot/app_userdata/<项目>/debug_reports/xxx.txt

const REPORT_DIR := "user://debug_reports"
const ENABLE_MARKER := "user://debug_channel.on"
## 存在这个文件就注入执行（见 _ready）
const INJECT_SCENARIO := "res://test/inject/scenario.gd"
## 采样间隔（帧）
const SAMPLE_INTERVAL := 120
## --debug-channel-level 模式下，进入关卡后运行多少「游戏秒」再出报告。
## 用时间而不是帧数：无头模式帧率不受限，按帧数算会跑得太短，僵尸还没出场。
## 可用命令行覆盖: --debug-channel-seconds=90
const LEVEL_RUN_SECONDS_DEFAULT := 45.0
## 自动加载单例清单，缺任何一个都说明 project.godot 被动过
const EXPECTED_AUTOLOADS: Array[String] = [
	"Log", "Global", "SoundManager", "SceneRegistry",
	"AllCards", "GlobalUtils", "EventBus", "TreePauseManager",
]
## 自动跑测试要用的关卡（前院第一天）
const AUTO_LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"

var _enabled := false
var _auto_level := false
var _report: AutopilotReport = null
var _state: AutopilotState = null
var _frames := 0
var _level_loaded := false
var _level_time := 0.0
var _level_run_seconds := LEVEL_RUN_SECONDS_DEFAULT
## 是否已经替玩家跳过选卡
var _autostart_done := false


func _ready() -> void:
	## 注入 autopilot 有两个**互相独立**的触发条件：
	##   1. 开关文件 test/inject/scenario.gd 存在 -> 编辑器里按 F5 就能跑（人工调试用）
	##   2. 命令行显式给了 --scenario=res://...   -> CI / 无头跑批用
	## 分开的理由：日常游玩时把开关文件收起来（改名 .off）就彻底干净，
	## 而跑批不依赖那个文件，随时能跑。
	## --no-autopilot 可再显式关掉：启动场景但不是玩游戏的场合，
	## 被注入 autopilot 会和被启动的场景互相打架（曾直接崩掉，exit 0xC0000005）。
	if not _autopilot_disabled() and (ResourceLoader.exists(INJECT_SCENARIO) or _cli_scenario() != ""):
		_spawn_autopilot()
		return
	_enabled = _detect_enabled()
	if not _enabled:
		return
	## 调试通道不要跟着全局暂停走
	process_mode = Node.PROCESS_MODE_ALWAYS
	_report = AutopilotReport.new()
	_report.setup_user(REPORT_DIR, "report_%s.txt" % Time.get_datetime_string_from_system().replace(":", "-"))
	_state = AutopilotState.new()
	_state.setup(get_tree())
	_report.line("=========== PVZ 调试通道报告 ===========")
	_report.line("时间: " + Time.get_datetime_string_from_system())
	_collect_environment()
	_collect_autoloads()
	_collect_logger()
	_collect_registries()
	_collect_runtime()
	_report.line("")
	_report.line("提示: 按 F10 可随时追加一份当前状态快照")
	_report.flush()
	Log.info("[调试通道] 已激活，报告: " + _report.abs_path())


## 把 autopilot 挂进场景树，由它自己解析 --scenario 决定跑哪个脚本
func _spawn_autopilot() -> void:
	var script: GDScript = load("res://test/autopilot.gd")
	if script == null:
		Log.error("[调试通道] 注入失败：autopilot.gd 加载不了")
		return
	var ap: Node = script.new()
	ap.name = "InjectedAutopilot"
	add_child(ap)
	var why := _cli_scenario()
	if why == "":
		why = INJECT_SCENARIO
	Log.info("[调试通道] 已注入 autopilot，场景脚本 = " + why)


## 命令行显式给的场景脚本（--scenario=res://...）。给了就说明是跑批，不需要开关文件。
func _cli_scenario() -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--scenario="):
			return a.split("=", true, 1)[1]
	return ""


## 命令行是否显式要求不要注入 autopilot
func _autopilot_disabled() -> bool:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a == "--no-autopilot":
			return true
	return false


func _detect_enabled() -> bool:
	var user_args := OS.get_cmdline_user_args()
	var all_args := OS.get_cmdline_args()
	## 必须扫完所有参数再返回：以前遇到 --debug-channel 就 return，
	## 导致后面的 --debug-channel-level / --debug-channel-seconds= 全被吞掉，
	## 具体表现是「传了秒数却仍按默认 45 秒跑」。
	var enabled := false
	for a in user_args + all_args:
		if a == "--debug-channel":
			enabled = true
		elif a == "--debug-channel-level":
			_auto_level = true
			enabled = true
		elif a.begins_with("--debug-channel-seconds="):
			_level_run_seconds = maxf(1.0, a.split("=")[1].to_float())
	if FileAccess.file_exists(ENABLE_MARKER):
		enabled = true
	return enabled


func _process(delta: float) -> void:
	if not _enabled:
		return
	_frames += 1
	if _frames % SAMPLE_INTERVAL == 0:
		_report.line(_state.sample_line(_frames))
		_report.flush()
	if _auto_level:
		_auto_level_step(delta)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		_report.line("")
		_report.line("---- F10 手动快照 frame=" + str(_frames) + " ----")
		_collect_runtime()
		_report.flush()
		Log.info("[调试通道] 已写入快照: " + _report.abs_path())


func _exit_tree() -> void:
	if _enabled:
		_report.line("")
		_report.line("=========== 报告结束（进程退出） ===========")
		_report.flush()


#region 自动跑一关

func _auto_level_step(delta: float) -> void:
	if not _level_loaded:
		if _frames < 60:
			return
		_level_loaded = true
		_level_time = 0.0
		var para: Resource = (load(AUTO_LEVEL) as GDScript).new()
		if para == null:
			_report.line("[自动关卡] 关卡资源加载失败: " + AUTO_LEVEL)
			_report.flush()
			return
		Global.game_para = para
		_report.line("[自动关卡] 已载入关卡: " + AUTO_LEVEL)
		_report.line("[自动关卡] 正在切换到主游戏场景")
		_report.flush()
		GlobalUtils.change_scene(
			Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
		)
		return
	_level_time += delta
	## 关卡会停在 E_MainGameProgress.CHOOSE_CARD 等玩家选卡，不跳过就永远没有僵尸。
	## main_game_start() 正是「选卡结束」的入口（见 main_game_manager.gd）。
	## 卡槽被系统自动填满时关卡会自行跳过选卡，此时阶段已不是 CHOOSE_CARD，不能重复开始。
	if not _autostart_done and _level_time >= 3.0:
		_autostart_done = true
		var mg = Global.main_game
		if mg == null:
			_report.line("!! [自动关卡] Global.main_game 为空，无法开始游戏")
			_report.flush()
		elif mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
			_report.line("[自动关卡] 跳过选卡，直接调用 main_game_start() 让波次开始")
			_report.flush()
			mg.main_game_start()
		else:
			_report.line("[自动关卡] 关卡已自行开始（阶段=%d），无需跳过选卡" % mg.main_game_progress)
			_report.flush()
	if _level_time >= _level_run_seconds:
		_report.line("")
		_report.line("---- 关卡运行 %.1f 游戏秒后的状态 ----" % _level_time)
		_collect_runtime()
		_report.flush()
		Log.info("[调试通道] 自动关卡探针完成，报告: " + _report.abs_path())
		get_tree().quit()

#endregion


#region 探针

func _collect_environment() -> void:
	_report.line("--- 环境 ---")
	var v: Dictionary = Engine.get_version_info()
	_report.line("引擎版本: " + str(v.get("string", "?")))
	_report.line("平台: %s  编辑器内: %s  debug构建: %s" % [OS.get_name(), OS.has_feature("editor"), OS.is_debug_build()])
	_report.line("渲染方式: " + str(ProjectSettings.get_setting("rendering/renderer/rendering_method")))
	_report.line("视口尺寸: " + str(DisplayServer.window_get_size()))
	_report.line("最大FPS: %d   时间缩放: %.2f" % [Engine.max_fps, Engine.time_scale])
	_report.line("main_scene: " + str(ProjectSettings.get_setting("application/run/main_scene")))


func _collect_autoloads() -> void:
	_report.line("")
	_report.line("--- 自动加载单例 ---")
	var missing: Array[String] = []
	for autoload_name in EXPECTED_AUTOLOADS:
		var n := get_node_or_null("/root/" + autoload_name)
		if n == null or not is_instance_valid(n):
			missing.append(autoload_name)
	_report.line("已注册: %d/%d" % [EXPECTED_AUTOLOADS.size() - missing.size(), EXPECTED_AUTOLOADS.size()])
	if not missing.is_empty():
		_report.line("!! 缺失: " + str(missing))


func _collect_logger() -> void:
	_report.line("")
	_report.line("--- 日志自检 ---")
	if Log == null:
		_report.line("!! Log 单例不存在")
		return
	## 这四行是回归用例：曾经 _write() 里误用 Log.debug() 造成无限递归爆栈。
	## 只要报告里能看到「日志四级调用: 正常」，就说明没有递归。
	Log.debug("[调试通道] debug 级自检")
	Log.info("[调试通道] info 级自检")
	Log.warn("[调试通道] warn 级自检")
	Log.error("[调试通道] error 级自检（应出现在 stderr）")
	_report.line("日志四级调用: 正常（无递归爆栈）")
	_report.line("当前日志级别: %d  带级别前缀: %s  带时间戳: %s" % [Log.level, Log.with_level_prefix, Log.with_timestamp])


func _collect_registries() -> void:
	_report.line("")
	_report.line("--- 注册表 ---")
	if Global == null:
		_report.line("!! Global 不存在，跳过")
		return
	var cr = Global.character_registry
	if cr != null:
		_report.line("角色注册表: 植物=%d 僵尸=%d" % [cr.PlantInfo.size(), cr.ZombieInfo.size()])
	else:
		_report.line("!! Global.character_registry 为空")
	var br = Global.get("bullet_registry")
	if br != null and br.get("BulletTypeMap") != null:
		_report.line("子弹注册表: %d" % br.BulletTypeMap.size())
	else:
		_report.line("子弹注册表: 取不到（成员名可能已变）")
	if AllCards != null:
		_report.line("AllCards: 植物卡=%d 僵尸卡=%d 僵王卡=%d" % [
			AllCards.all_plant_card_prefabs.size(), AllCards.all_zombie_card_prefabs.size(),
			AllCards.all_boss_card_prefabs.size()])
	_collect_scene_registry()


func _collect_scene_registry() -> void:
	var names := ["PLANT_CELL_GARDEN", "CRAZY_DAVE", "REMINDER_INFORMATION", "COIN_GOLD", "SPLASH", "LADDER", "SUN", "TOMBSTONE"]
	var ok := 0
	var bad: Array[String] = []
	for n in names:
		var v = SceneRegistry.get(n)
		if v is PackedScene and v.can_instantiate():
			ok += 1
		else:
			bad.append(n)
	_report.line("SceneRegistry 抽检: ok=%d/%d" % [ok, names.size()])
	if not bad.is_empty():
		_report.line("!! 取不到的键: " + str(bad))


func _collect_runtime() -> void:
	_report.line("")
	_report.line("--- 运行时状态 ---")
	_report.write_lines(_state.runtime_lines())

#endregion
