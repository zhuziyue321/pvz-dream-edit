extends RefCounted
## 调试窗口里的条目（调试模组）：一条一行，写法与 `ConsoleBuiltinEntries` 一致
##
## 为什么单独一个文件：调试窗口（`debug_window.gd`）只负责「把条目渲染成控件、按分组分页、
## 定时刷新、搜索过滤」，它不该认识「刷一只僵尸」这种具体操作 —— 加 / 删一个调试功能只改这里。
##
## 条目形态复用控制台那套：`ConsoleEntry`（数据）+ `ConsoleEntryControl`（渲染器），
## 见 [控制台](../../../docs/参考存档/控制台.md) —— 控制台与模组页面用的也是这两个。
## 但**这些条目不登记进 `ConsoleRegistry`**，而是直接交给调试窗口自己的渲染器，
## 所以控制台面板上不会多出这些按钮，两边互不干扰。
##
## 分页（顺序 = `get_categories()`）：
##   常用 / 战斗 / 资源 / 开关 / 运行 / 状态 / 日志
## 「日志」页不是条目，由 `debug_window.gd` 直接铺一个只读文本框（读 `Log.get_recent_text()`），
## 所以 `register_all()` 对它什么都不做。
##
## ⚠️ 与内置控制台条目一样：**不要在登记时读 `Global.config_service` / 各管理器** ——
##    一律写进 lambda，等面板真取值 / 真执行时才去读（`bind_config()` 已经这么做了）。
##
## 关联：[调试窗口](../../../docs/参考存档/调试窗口.md) ｜ debug_window.gd ｜ ConsoleEntry ｜ ConsoleEntryControl

## 同目录的伤害修饰器（模组脚本不写 `class_name`，一律 preload 引用）
const DebugDamageModifierScript := preload("debug_damage_modifier.gd")


#region 分组
## 一次性动作（按钮）
const CATEGORY_COMMON := "常用"
## 关卡内战斗操作（刷僵尸 / 波次 / 秒杀 / 无敌）
const CATEGORY_BATTLE := "战斗"
## 阳光 / 金币
const CATEGORY_RESOURCE := "资源"
## 持久化开关（与控制台同一批 `ConfigService` 字段，集中一份入口）
const CATEGORY_SWITCH := "开关"
## 运行期控制（倍速 / 暂停）
const CATEGORY_RUNTIME := "运行"
## 只读状态行（定时刷新）
const CATEGORY_STATE := "状态"
## 日志页（不是条目，窗口自己铺文本框）
const CATEGORY_LOG := "日志"
#endregion


#region 常量
## 动作反馈在窗口底部停留多久（毫秒）
const FEEDBACK_KEEP_MSEC := 4000
## 「无限阳光」锁定的阳光值
const INFINITE_SUN_VALUE := 999999
## 「刷僵尸」没填类型时用的 id
const DEFAULT_ZOMBIE_TYPE := "norm"
## 冒险模式关卡总数（1-1 = 1，5-10 = 50）
const MAX_ADVENTURE_LEVEL := 50
#endregion


#region 搜索索引
## 「一页里每一行」的索引：`{control: Control, text: String}`
## 由 `_add()` 在造控件时登记，搜索框调 `apply_filter()` 只切 `visible`，不重建控件（不丢焦点）
static var _rows: Array[Dictionary] = []


## 重建页面之前清一次索引（窗口在 `_build_pages()` 开头调用）
static func begin_register() -> void:
	_rows.clear()


## 按关键字过滤所有页里的行（空关键字 = 全部显示）；返回命中的行数
static func apply_filter(keyword: String) -> int:
	var key := keyword.strip_edges().to_lower()
	var shown := 0
	for row: Dictionary in _rows:
		var control: Control = row.get("control")
		if not is_instance_valid(control):
			continue
		var matched := key.is_empty() or key in String(row.get("text", ""))
		control.visible = matched
		if matched:
			shown += 1
	return shown
#endregion


#region 动作反馈
static var _feedback_text := ""
static var _feedback_is_error := false
static var _feedback_msec := 0


## 一条动作结果（窗口底部状态条读它；`is_error` 显示成红色）
static func notify(text: String, is_error := false) -> void:
	_feedback_text = text
	_feedback_is_error = is_error
	_feedback_msec = Time.get_ticks_msec()


## 当前反馈：`{text, is_error, age}`；`age` 超过 `FEEDBACK_KEEP_MSEC` 时窗口自己淡出
static func get_feedback() -> Dictionary:
	return {
		"text": _feedback_text,
		"is_error": _feedback_is_error,
		"age": Time.get_ticks_msec() - _feedback_msec,
	}
#endregion


#region 随窗口开关的状态
## 植物无敌（伤害修饰器）
static var _plant_invincible := false
## 无限阳光（定时把卡槽阳光顶回 `INFINITE_SUN_VALUE`）
static var _infinite_sun := false
## 当前注册的修饰器实例（关掉时注销）
static var _damage_modifier: DamageModifier = null


## 窗口定时器每跳一次调它：把「需要持续生效」的开关重新落实一遍
##
## `DamageSystem` 切关会 `clear_modifiers()`，所以无敌修饰器要定期补注册
## （`register_modifier()` 幂等，已在列表里就直接返回）。
static func tick() -> void:
	if _plant_invincible:
		_ensure_damage_modifier()
	if _infinite_sun:
		_pin_sun()


## 窗口 / 模组销毁时调：把本窗口打开过的副作用全部撤掉
static func shutdown() -> void:
	_plant_invincible = false
	_infinite_sun = false
	_release_damage_modifier()
	_rows.clear()
	_feedback_text = ""
	_feedback_msec = 0
#endregion


## 登记某一组的全部条目（[param parent] 是这一页的容器，控件直接加进去）
static func register_all(builder: ConsoleEntryControl, category: String, parent: Control) -> void:
	if builder == null or parent == null:
		return
	match category:
		CATEGORY_COMMON:
			_register_common_entries(builder, parent)
		CATEGORY_BATTLE:
			_register_battle_entries(builder, parent)
		CATEGORY_RESOURCE:
			_register_resource_entries(builder, parent)
		CATEGORY_SWITCH:
			_register_switch_entries(builder, parent)
		CATEGORY_RUNTIME:
			_register_runtime_entries(builder, parent)
		CATEGORY_STATE:
			_register_state_entries(builder, parent)
		CATEGORY_LOG:
			pass  ## 日志页由窗口自己铺
		_:
			Log.warn("调试窗口：没有「%s」这一组" % category)


## 分页顺序 = 这里返回的顺序
static func get_categories() -> Array[String]:
	return [CATEGORY_COMMON, CATEGORY_BATTLE, CATEGORY_RESOURCE, CATEGORY_SWITCH,
		CATEGORY_RUNTIME, CATEGORY_STATE, CATEGORY_LOG]


#region 常用
static func _register_common_entries(builder: ConsoleEntryControl, parent: Control) -> void:
	_add(builder, parent, ConsoleEntry.create_button(&"debug_win_level", "通关本关", _win_level)
		.set_tooltip("立刻结算本关（与 Ctrl+D 然后按 0 同一入口）。只在关卡里生效")
		.set_category(CATEGORY_COMMON)
		.set_order(10))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_restart_level", "重开本关", _restart_level)
		.set_tooltip("清掉本关的多轮存档后重载当前场景（与暂停菜单里的「重新开始」同一条链）")
		.set_category(CATEGORY_COMMON)
		.set_order(20))

	var level_entry := ConsoleEntry.create_slider(&"debug_jump_level", "冒险关卡序号", 1.0,
		float(MAX_ADVENTURE_LEVEL), 1.0) \
		.set_tooltip("1-1 = 1，5-10 = 50；按下面的按钮直接进关（会切场景）") \
		.set_category(CATEGORY_COMMON) \
		.set_order(30) \
		.bind_config("debug_window.adventure_level", 1.0)
	_add(builder, parent, level_entry)

	_add(builder, parent, ConsoleEntry.create_button(&"debug_jump_level_go", "进入该冒险关卡",
		func() -> void: _jump_adventure_level(int(level_entry.get_value())))
		.set_tooltip("菜单 / 关卡里都能按；联机客户端会被进关闸门拦下")
		.set_category(CATEGORY_COMMON)
		.set_order(40))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_success_all_adventure", "通关所有冒险关卡",
		_success_all_adventure)
		.set_tooltip("1-1 ~ 5-10 一次全写成已通关并解锁沿途植物。只动全局存档，菜单里按也生效")
		.set_category(CATEGORY_COMMON)
		.set_order(50))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_unlock_all_shop_goods", "解锁所有商品",
		_unlock_all_shop_goods)
		.set_tooltip("商店货架上的商品全部置为已拥有（不扣金币、不动关卡进度）")
		.set_category(CATEGORY_COMMON)
		.set_order(60))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_save_now", "立即写存档", _save_now)
		.set_tooltip("把当前全局存档立刻落盘（平时由业务节点在关键时机自己调）")
		.set_category(CATEGORY_COMMON)
		.set_order(70))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_open_save_dir", "打开存档文件夹",
		_open_save_dir)
		.set_tooltip("用系统文件管理器定位到当前账号的存档目录（与 Ctrl+D 然后按 2 同一入口）")
		.set_category(CATEGORY_COMMON)
		.set_order(80))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_blood_moon", "触发血月", _blood_moon)
		.set_tooltip("立刻开始 / 结束一次血月（全场僵尸 ×2、画面变红 15 秒）。只在开了血月的关卡里生效")
		.set_category(CATEGORY_COMMON)
		.set_order(90))
#endregion


#region 战斗
static func _register_battle_entries(builder: ConsoleEntryControl, parent: Control) -> void:
	var type_entry := ConsoleEntry.create_text(&"debug_spawn_type", "僵尸类型", DEFAULT_ZOMBIE_TYPE) \
		.set_placeholder("如 norm / cone / gargantuar（见 ZombieIds）") \
		.set_tooltip("按僵尸 id 刷（不是数字编号）。运行期热注册的僵尸也能填") \
		.set_category(CATEGORY_BATTLE) \
		.set_order(10) \
		.bind_config("debug_window.zombie_type", DEFAULT_ZOMBIE_TYPE)
	_add(builder, parent, type_entry)

	var lane_entry := ConsoleEntry.create_slider(&"debug_spawn_lane", "行（1-5）", 1.0, 5.0, 1.0) \
		.set_tooltip("第几行出怪；五行齐刷时忽略这一项") \
		.set_category(CATEGORY_BATTLE) \
		.set_order(20) \
		.bind_config("debug_window.zombie_lane", 3.0)
	_add(builder, parent, lane_entry)

	_add(builder, parent, ConsoleEntry.create_button(&"debug_spawn_one", "刷一只（本行）",
		func() -> void: _spawn_zombies(String(type_entry.get_value()), int(lane_entry.get_value()), false))
		.set_tooltip("走正常出场流程（计入本关僵尸数、接死亡 / 魅惑 / 换行信号）")
		.set_category(CATEGORY_BATTLE)
		.set_order(30))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_spawn_all_lane", "每行各刷一只",
		func() -> void: _spawn_zombies(String(type_entry.get_value()), int(lane_entry.get_value()), true))
		.set_tooltip("逐行刷；水行只接受水生僵尸，刷不出来的行会被跳过并提示")
		.set_category(CATEGORY_BATTLE)
		.set_order(40))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_next_wave", "下一波", _next_wave)
		.set_tooltip("立刻推进一波（旗帜波会先播预警）。有专属出怪器的关卡无效")
		.set_category(CATEGORY_BATTLE)
		.set_order(50))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_kill_all_zombie", "清场（跳过僵王）",
		_kill_all_zombie)
		.set_tooltip("与 Ctrl+K 同一入口：僵尸走正常死亡流程，最后一波清完同样会触发结算")
		.set_category(CATEGORY_BATTLE)
		.set_order(60))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_instant_kill_all", "秒杀全屏（含僵王）",
		_instant_kill_all)
		.set_tooltip("对场上每只僵尸（含僵王）发一次秒杀伤害，走正常死亡 / 亡语 / 掉落流程")
		.set_category(CATEGORY_BATTLE)
		.set_order(70))

	_add(builder, parent, ConsoleEntry.create_toggle(&"debug_plant_invincible", "植物无敌")
		.set_tooltip("所有植物免疫伤害；铲子铲除与关卡脚本强制致死仍然有效")
		.set_category(CATEGORY_BATTLE)
		.set_order(80)
		.bind(func() -> bool: return _plant_invincible, _set_plant_invincible))

	_add(builder, parent, ConsoleEntry.create_toggle(&"debug_infinite_sun", "无限阳光")
		.set_tooltip("每秒把出战卡槽的阳光顶回 %d（传送带关卡没有阳光）" % INFINITE_SUN_VALUE)
		.set_category(CATEGORY_BATTLE)
		.set_order(90)
		.bind(func() -> bool: return _infinite_sun, _set_infinite_sun))
#endregion


#region 资源
static func _register_resource_entries(builder: ConsoleEntryControl, parent: Control) -> void:
	## 阳光 / 金币共用一根「增量」滑条：改一次，两个按钮都按这个数走
	var amount_entry := ConsoleEntry.create_slider(&"debug_resource_amount", "增量", 0.0, 5000.0, 50.0) \
		.set_tooltip("下面「加阳光 / 加金币」一次加多少（滑到 0 再加 = 只刷新，不加）") \
		.set_category(CATEGORY_RESOURCE) \
		.set_order(10) \
		.bind_config("debug_window.amount", 1000.0)
	_add(builder, parent, amount_entry)

	_add(builder, parent, ConsoleEntry.create_button(&"debug_add_sun",
		"加阳光", func() -> void: _add_sun(int(amount_entry.get_value())))
		.set_tooltip("按滑条上的数字加阳光（负数就是扣）。只在关卡里生效")
		.set_category(CATEGORY_RESOURCE)
		.set_order(20))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_add_coin",
		"加金币", func() -> void: _add_coin(int(amount_entry.get_value())))
		.set_tooltip("按滑条上的数字加金币（负数就是扣）")
		.set_category(CATEGORY_RESOURCE)
		.set_order(30))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_sun_to_max", "阳光拉满", _sun_to_max)
		.set_tooltip("直接把出战卡槽阳光写成 %d（≈无限，一次性）" % INFINITE_SUN_VALUE)
		.set_category(CATEGORY_RESOURCE)
		.set_order(40))
#endregion


#region 开关
## 与控制台同一批字段：这里只是把调试常改的几项集中一份入口（改的是同一个 `ConfigService`）
static func _register_switch_entries(builder: ConsoleEntryControl, parent: Control) -> void:
	_add(builder, parent, _config_toggle(&"debug_display_plant_hp", "显示植物血量",
		"display_plant_HP_label", "在每个植物头顶显示当前血量", 10))
	_add(builder, parent, _config_toggle(&"debug_display_zombie_hp", "显示僵尸血量",
		"display_zombie_HP_label", "在每个僵尸头顶显示当前血量", 20))
	_add(builder, parent, _config_toggle(&"debug_open_all_level", "开放所有关卡",
		"open_all_level", "解锁全部分支模式关卡与主菜单的花园 / 图鉴 / 商店入口（冒险模式不受影响）", 30))
	_add(builder, parent, _config_toggle(&"debug_auto_collect_sun", "自动收集阳光",
		"auto_collect_sun", "掉落的阳光不用手动点，自动收取", 40))
	_add(builder, parent, _config_toggle(&"debug_auto_collect_coin", "自动收集金币",
		"auto_collect_coin", "掉落的金币不用手动点，自动收取（功能未实现，仅占位）", 50))
	_add(builder, parent, _config_toggle(&"debug_track_bullet_mouse", "追踪子弹跟随鼠标",
		"track_bullet_mouse", "追踪类子弹没有目标时，改为追着鼠标飞", 60))
	_add(builder, parent, _config_toggle(&"debug_fog_is_static", "静态浓雾",
		"fog_is_static", "关卡有浓雾时改用静态浓雾（关掉 = 动态浓雾）", 70))
	_add(builder, parent, _config_toggle(&"debug_hide_spare_card", "隐藏未选择植物卡槽",
		"disappear_spare_card_Placeholder", "选的卡片没填满卡槽时，把多出来的空卡槽隐藏", 80))
	_add(builder, parent, _config_toggle(&"debug_card_slot_top", "焦点卡槽自动置顶",
		"card_slot_top_mouse_focus", "鼠标移到卡槽上时把该卡槽置顶，避免被其它 UI 挡住", 90))
	_add(builder, parent, _config_toggle(&"debug_shovel_front", "预铲除植物置顶",
		"plant_be_shovel_front", "铲子指向某株植物时把它高亮并置顶", 100))

	_add(builder, parent, ConsoleEntry.create_toggle(&"debug_fullscreen", "游戏全屏")
		.set_tooltip("在全屏与窗口之间切换")
		.set_category(CATEGORY_SWITCH)
		.set_order(110)
		.bind(func() -> bool:
			return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
			func(value: bool) -> void: DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if value
				else DisplayServer.WINDOW_MODE_WINDOWED)))

	_add(builder, parent, ConsoleEntry.create_toggle(&"debug_trace_events", "事件追踪（死事件检测）")
		.set_tooltip("记录被 push 过的事件名，供 EventBus.get_never_pushed_subscribed_events() 用；"
			+ "关掉后死事件检测没有信息")
		.set_category(CATEGORY_SWITCH)
		.set_order(120)
		.bind(func() -> bool: return EventBus.is_trace_pushed_events,
			func(value: bool) -> void:
				EventBus.is_trace_pushed_events = value
				notify("事件追踪：%s" % ("开" if value else "关"))))

	_add(builder, parent, ConsoleEntry.create_toggle(&"debug_event_history", "记录事件历史")
		.set_tooltip("EventBus 保留最近 %d 条 push 记录（排查「到底有没有发过这条事件」用）"
			% EventBus.max_history_length)
		.set_category(CATEGORY_SWITCH)
		.set_order(130)
		.bind(func() -> bool: return EventBus.enable_history,
			func(value: bool) -> void:
				EventBus.enable_history = value
				notify("事件历史：%s" % ("开" if value else "关"))))
#endregion


#region 运行
static func _register_runtime_entries(builder: ConsoleEntryControl, parent: Control) -> void:
	_add(builder, parent, ConsoleEntry.create_slider(&"debug_time_scale", "游戏倍速", 0.25, 8.0, 0.25)
		.set_tooltip("改 Engine.time_scale，全局生效。超过 8 倍会因为代码执行顺序出现莫名的 bug")
		.set_category(CATEGORY_RUNTIME)
		.set_order(10)
		.bind(func() -> float: return Global.time_scale,
			func(value: float) -> void:
				Global.time_scale = value
				Engine.time_scale = value))

	_add(builder, parent, ConsoleEntry.create_toggle(&"debug_pause_game", "暂停游戏")
		.set_tooltip("等价于打开暂停菜单（树暂停）；调试窗口自己标了 PROCESS_MODE_ALWAYS，暂停时照样能点")
		.set_category(CATEGORY_RUNTIME)
		.set_order(20)
		.bind(func() -> bool: return _get_scene_tree().paused,
			func(value: bool) -> void: _get_scene_tree().paused = value))
#endregion


#region 状态
static func _register_state_entries(builder: ConsoleEntryControl, parent: Control) -> void:
	## 全是只读行（Readout）：值随手在变，由 `debug_window.gd` 的定时器统一刷
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_fps", "FPS", _text_fps)
		.set_category(CATEGORY_STATE).set_order(10))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_user", "当前账号", _text_user)
		.set_category(CATEGORY_STATE).set_order(20))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_scene", "当前场景", _text_scene)
		.set_category(CATEGORY_STATE).set_order(30))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_progress", "关卡状态", _text_progress)
		.set_category(CATEGORY_STATE).set_order(40))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_wave", "波次", _text_wave)
		.set_category(CATEGORY_STATE).set_order(50))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_zombie", "僵尸数量", _text_zombie_num)
		.set_category(CATEGORY_STATE).set_order(60))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_plant", "场上植物", _text_plant_num)
		.set_category(CATEGORY_STATE).set_order(70))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_sun", "阳光", _text_sun)
		.set_category(CATEGORY_STATE).set_order(80))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_coin", "金币", _text_coin)
		.set_category(CATEGORY_STATE).set_order(90))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_time_scale", "倍速", _text_time_scale)
		.set_category(CATEGORY_STATE).set_order(100))
#endregion


#region 动作
static func _win_level() -> void:
	if not GameContext.is_in_main_game():
		notify("不在关卡里，「通关本关」没生效", true)
		return
	Global.debug_win_main_game()
	notify("已请求结算本关")


static func _restart_level() -> void:
	if not GameContext.is_in_main_game():
		notify("不在关卡里，「重开本关」没生效", true)
		return
	GameContext.curr_main_game.save_manager.re_main_game()
	_get_scene_tree().reload_current_scene()
	notify("正在重开本关…")


static func _jump_adventure_level(level_num: int) -> void:
	var level := clampi(level_num, 1, MAX_ADVENTURE_LEVEL)
	var para := Global.global_game_state.build_adventure_level_para(level)
	if para == null:
		notify("冒险第 %d 关取不到关卡数据" % level, true)
		return
	if GlobalUtils.enter_level_gate.is_valid() and not bool(GlobalUtils.enter_level_gate.call()):
		notify("进关被闸门拦下（联机客户端由房主开）", true)
		return
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	notify("正在进入冒险第 %d 关…" % level)


static func _spawn_zombies(type_text: String, lane_value: int, all_lanes: bool) -> void:
	if not GameContext.is_in_main_game():
		notify("不在关卡里，「刷僵尸」没生效", true)
		return
	var manager := GameContext.curr_main_game.zombie_manager
	if manager == null:
		notify("拿不到僵尸管理器", true)
		return
	## 选卡 / 准备阶段不允许出怪（`create_skill_zombie()` 自己会拒绝，这里先给一句人话）
	if not manager.is_game_running():
		notify("还没开战（选卡 / 准备阶段不能刷僵尸）", true)
		return
	var zombie_type := StringName(type_text.strip_edges().to_lower())
	if not _is_known_zombie(zombie_type):
		notify("未知僵尸类型：%s" % type_text, true)
		return
	var lane_count: int = manager.all_zombie_rows.size()
	if lane_count <= 0:
		notify("本关没有僵尸行", true)
		return
	var success := 0
	var failed := 0
	if all_lanes:
		for lane in lane_count:
			if _spawn_one_zombie(manager, zombie_type, lane):
				success += 1
			else:
				failed += 1
	else:
		var lane := clampi(lane_value - 1, 0, lane_count - 1)
		if _spawn_one_zombie(manager, zombie_type, lane):
			success += 1
		else:
			failed += 1

	if success == 0:
		notify("刷僵尸失败：这一行不接受该类型（水行只能出水生僵尸）", true)
	elif failed > 0:
		notify("刷出 %d 只 %s，%d 行不接受该类型" % [success, zombie_type, failed], true)
	else:
		notify("刷出 %d 只 %s" % [success, zombie_type])


static func _is_known_zombie(zombie_type: StringName) -> bool:
	if zombie_type == &"":
		return false
	if ZombieIds.is_valid(zombie_type):
		return true
	return Global.character_registry.can_instantiate_zombie(zombie_type)


static func _spawn_one_zombie(manager: ZombieManager, zombie_type: StringName, lane: int) -> bool:
	if lane < 0 or lane >= manager.all_zombie_rows.size():
		return false
	var row: ZombieRow = manager.all_zombie_rows[lane]
	if not is_instance_valid(row) or not is_instance_valid(row.zombie_create_position):
		return false
	var spawn_x: float = row.zombie_create_position.global_position.x
	return manager.create_skill_zombie(zombie_type, lane, spawn_x) != null


static func _next_wave() -> void:
	if not GameContext.is_in_main_game():
		notify("不在关卡里，「下一波」没生效", true)
		return
	var manager := GameContext.curr_main_game.zombie_manager
	if manager == null:
		notify("拿不到僵尸管理器", true)
		return
	if manager.wave_source != null:
		notify("本关由专属出怪器接管，「下一波」无效", true)
		return
	var wave_manager := manager.zombie_wave_manager
	if wave_manager == null:
		notify("拿不到波次管理器", true)
		return
	if not wave_manager.is_battle_started():
		notify("还没开战，「下一波」没生效", true)
		return
	wave_manager.start_next_wave()
	notify("已请求下一波（旗帜波会先播预警）")


static func _kill_all_zombie() -> void:
	if not GameContext.is_in_main_game():
		notify("不在关卡里，「清场」没生效", true)
		return
	GameContext.curr_main_game.shortcut_kill_all_zombie()
	notify("已清场（僵王不受影响）")


## 秒杀全屏：对每只僵尸（含僵王）发一次 `is_instant_kill` 伤害 —— 走完整伤害管线，
## 死亡流程 / 亡语 / 掉落与被打死完全一致（与「清场」的 `character_death_disappear()` 不同）。
static func _instant_kill_all() -> void:
	if not GameContext.is_in_main_game():
		notify("不在关卡里，「秒杀全屏」没生效", true)
		return
	var manager := GameContext.curr_main_game.zombie_manager
	if manager == null:
		notify("拿不到僵尸管理器", true)
		return
	var count := 0
	for zombie: Zombie000Base in manager.all_zombies_1d.duplicate():
		if not is_instance_valid(zombie) or zombie.is_queued_for_deletion():
			continue
		var info := DamageInfo.create(zombie, 0,
			ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Script)
		info.is_instant_kill = true
		DamageSystem.apply(info)
		count += 1
	notify("秒杀 %d 只僵尸（含僵王）" % count)


static func _set_plant_invincible(value: bool) -> void:
	_plant_invincible = value
	if value:
		_ensure_damage_modifier()
		notify("植物无敌：开（铲子 / 脚本致死仍然有效）")
	else:
		_release_damage_modifier()
		notify("植物无敌：关")


static func _ensure_damage_modifier() -> void:
	if _damage_modifier == null:
		_damage_modifier = DebugDamageModifierScript.new()
	DamageSystem.register_modifier(_damage_modifier)


static func _release_damage_modifier() -> void:
	if _damage_modifier == null:
		return
	DamageSystem.unregister_modifier(_damage_modifier)


static func _set_infinite_sun(value: bool) -> void:
	_infinite_sun = value
	if value:
		_pin_sun()
		notify("无限阳光：开（阳光锁在 %d）" % INFINITE_SUN_VALUE)
	else:
		notify("无限阳光：关")


static func _pin_sun() -> void:
	var slot := _get_card_slot_battle()
	if slot == null:
		return
	if int(slot.sun_value) < INFINITE_SUN_VALUE:
		slot.sun_value = INFINITE_SUN_VALUE


static func _sun_to_max() -> void:
	var slot := _get_card_slot_battle()
	if slot == null:
		notify("本关没有常规卡槽（传送带关卡没有阳光）", true)
		return
	slot.sun_value = INFINITE_SUN_VALUE
	notify("阳光已拉满：%d" % INFINITE_SUN_VALUE)


static func _get_card_slot_battle() -> CardSlotBattle:
	if not GameContext.is_in_main_game():
		return null
	var card_manager := GameContext.curr_main_game.card_manager
	if card_manager == null:
		return null
	return card_manager.card_slot_battle


static func _blood_moon() -> void:
	if not GameContext.is_in_main_game():
		notify("不在关卡里，「触发血月」没生效", true)
		return
	var manager := GameContext.curr_main_game.blood_moon_manager
	if manager == null:
		notify("本关没有血月管理器", true)
		return
	if manager.game_para == null or not manager.game_para.is_blood_moon:
		notify("本关没开血月（要月夜屋顶场景）", true)
		return
	if manager.is_active:
		manager.end_blood_moon()
		notify("血月：已结束")
	else:
		manager.start_blood_moon()
		notify("血月：已开始")


static func _success_all_adventure() -> void:
	var num: int = Global.global_game_state.success_all_adventure_level()
	notify("通关所有冒险关卡，本次新通关 %d 关" % num)


static func _unlock_all_shop_goods() -> void:
	var num: int = Global.global_game_state.unlock_all_shop_goods()
	notify("解锁商店全部商品，本次新拥有 %d 件" % num)


static func _save_now() -> void:
	Global.save_service.save_now()
	notify("全局存档已落盘")


static func _open_save_dir() -> void:
	Global.debug_open_save_dir()
	notify("已打开存档文件夹")


## 加阳光走 EventBus "add_sun_value"（与玩家点掉一颗阳光同一入口），
## 卡槽会自己刷新数字并重新判定每张卡够不够钱
static func _add_sun(value: int) -> void:
	if not GameContext.is_in_main_game():
		notify("不在关卡里，「加阳光」没生效", true)
		return
	EventBus.push_event(ConstEventName.ADD_SUN_VALUE, [value])
	notify("阳光 %+d" % value)


static func _add_coin(value: int) -> void:
	Global.global_game_state.coin_value += value
	notify("金币 %+d（当前 %d）" % [value, Global.global_game_state.coin_value])


static func _get_scene_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
#endregion


#region 状态行文本
static func _text_fps() -> String:
	return "%d" % Engine.get_frames_per_second()


static func _text_user() -> String:
	var name: String = Global.user_manager.curr_user_name
	return name if not name.is_empty() else "-"


static func _text_scene() -> String:
	var scene := _get_scene_tree().current_scene
	if scene == null:
		return "-"
	return scene.scene_file_path.get_file()


static func _text_progress() -> String:
	if not GameContext.is_in_main_game():
		return "不在关卡内"
	match GameContext.curr_main_game.main_game_progress:
		MainGameManager.E_MainGameProgress.CHOOSE_CARD:
			return "选卡界面"
		MainGameManager.E_MainGameProgress.PREPARE:
			return "准备阶段"
		MainGameManager.E_MainGameProgress.MAIN_GAME:
			return "游戏阶段"
		MainGameManager.E_MainGameProgress.GAME_OVER:
			return "结算阶段"
		MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD:
			return "重新选卡"
		_:
			return "无"


static func _text_wave() -> String:
	if not GameContext.is_in_main_game():
		return "-"
	var manager := GameContext.curr_main_game.zombie_manager
	if manager == null:
		return "-"
	if manager.wave_source != null:
		return "专属出怪器"
	var wave_manager := manager.zombie_wave_manager
	if wave_manager == null:
		return "-"
	return "%d / %d" % [maxi(wave_manager.curr_wave + 1, 0), wave_manager.max_wave]


static func _text_zombie_num() -> String:
	if not GameContext.is_in_main_game():
		return "-"
	var zombie_manager := GameContext.curr_main_game.zombie_manager
	if not is_instance_valid(zombie_manager):
		return "-"
	return str(zombie_manager.curr_zombie_num)


static func _text_plant_num() -> String:
	if not GameContext.is_in_main_game():
		return "-"
	var cell_manager := GameContext.curr_main_game.plant_cell_manager
	if cell_manager == null:
		return "-"
	return str(cell_manager.get_cell_have_plant().size())


static func _text_sun() -> String:
	var slot := _get_card_slot_battle()
	if slot == null:
		return "-"
	return str(slot.sun_value)


static func _text_coin() -> String:
	return str(Global.global_game_state.coin_value)


static func _text_time_scale() -> String:
	return "%.2f" % Engine.time_scale
#endregion


#region 工具
## 绑一个 `ConfigService` 的布尔字段（读内存、改内存、顺手落盘）
## [param property] 就是 `config_service` 上的字段名（与内置控制台条目改的是同一个）
static func _config_toggle(entry_id: StringName, entry_text: String, property: String,
		tooltip: String, order: int) -> ConsoleEntry:
	return ConsoleEntry.create_toggle(entry_id, entry_text) \
		.set_tooltip(tooltip) \
		.set_category(CATEGORY_SWITCH) \
		.set_order(order) \
		.bind(
			func() -> bool: return bool(Global.config_service.get(property)),
			func(value: bool) -> void:
				Global.config_service.set(property, value)
				Global.config_service.save_config())
#endregion


## 统一走这里登记：造控件 + 加进当前这一页 + 记进搜索索引
static func _add(builder: ConsoleEntryControl, parent: Control, entry: ConsoleEntry) -> void:
	if builder == null or parent == null or entry == null:
		return
	var control: Control = builder.create_control(entry)
	parent.add_child(control)
	_rows.append({
		"control": control,
		"text": ("%s %s" % [entry.text, entry.id]).to_lower(),
	})
