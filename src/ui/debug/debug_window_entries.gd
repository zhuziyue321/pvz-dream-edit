extends RefCounted
class_name DebugWindowEntries
## 调试窗口里的条目：一条一行，写法与 `ConsoleBuiltinEntries` 一致
##
## 为什么单独一个文件：调试窗口（`DebugWindow`）只负责「把条目渲染成控件、按分组分页、定时刷新」，
## 它不该认识「通关本关」这种具体操作 —— 加 / 删一个调试功能只改这里。
##
## 条目形态复用控制台那套：`ConsoleEntry`（数据）+ `ConsoleEntryControl`（渲染器），
## 见 [控制台](../../../docs/参考存档/控制台.md) —— 控制台与模组页面用的也是这两个。
## 但**这些条目不登记进 `ConsoleRegistry`**，而是直接交给调试窗口自己的渲染器，
## 所以控制台面板上不会多出这些按钮，两边互不干扰。
##
## ⚠️ 与内置控制台条目一样：**不要在登记时读 `Global.config_service`** —— 一律写进 lambda，
##    等面板真取值时才去读（`bind_config()` 已经这么做了）。
##
## 关联：[调试窗口](../../../docs/参考存档/调试窗口.md) ｜ DebugWindow ｜ ConsoleEntry ｜ ConsoleEntryControl


## 一次性动作（按钮）
const CATEGORY_COMMON := "常用"
## 阳光 / 金币
const CATEGORY_RESOURCE := "资源"
## 运行期控制（倍速等）
const CATEGORY_RUNTIME := "运行"
## 只读状态行（定时刷新）
const CATEGORY_STATE := "状态"


## 登记某一组的全部条目（[param parent] 是这一页的容器，控件直接加进去）
static func register_all(builder: ConsoleEntryControl, category: String, parent: Control) -> void:
	if builder == null or parent == null:
		return
	match category:
		CATEGORY_COMMON:
			_register_common_entries(builder, parent)
		CATEGORY_RESOURCE:
			_register_resource_entries(builder, parent)
		CATEGORY_RUNTIME:
			_register_runtime_entries(builder, parent)
		CATEGORY_STATE:
			_register_state_entries(builder, parent)
		_:
			Log.warn("调试窗口：没有「%s」这一组" % category)


## 四页的顺序 = 这里返回的顺序
static func get_categories() -> Array[String]:
	return [CATEGORY_COMMON, CATEGORY_RESOURCE, CATEGORY_RUNTIME, CATEGORY_STATE]


#region 四组条目
static func _register_common_entries(builder: ConsoleEntryControl, parent: Control) -> void:
	_add(builder, parent, ConsoleEntry.create_button(&"debug_win_level", "通关本关", _win_level)
		.set_tooltip("立刻结算本关（与 Ctrl+D 然后按 0 同一入口）。只在关卡里生效")
		.set_category(CATEGORY_COMMON)
		.set_order(10))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_blood_moon", "触发血月", _blood_moon)
		.set_tooltip("立刻开始一次血月（全场僵尸 ×2、画面变红 15 秒）。只在开了血月的关卡（月夜屋顶）里生效")
		.set_category(CATEGORY_COMMON)
		.set_order(25))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_kill_all_zombie", "清场（杀死所有僵尸）", _kill_all_zombie)
		.set_tooltip("与 Ctrl+K 同一入口：僵尸走正常死亡流程，最后一波清完同样会触发结算")
		.set_category(CATEGORY_COMMON)
		.set_order(20))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_success_all_adventure", "通关所有冒险关卡", _success_all_adventure)
		.set_tooltip("1-1 ~ 5-10 一次全写成已通关并解锁沿途植物。只动全局存档，菜单里按也生效")
		.set_category(CATEGORY_COMMON)
		.set_order(30))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_unlock_all_shop_goods", "解锁所有商品", _unlock_all_shop_goods)
		.set_tooltip("商店货架上的商品全部置为已拥有（不扣金币、不动关卡进度）")
		.set_category(CATEGORY_COMMON)
		.set_order(40))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_save_now", "立即写存档", _save_now)
		.set_tooltip("把当前全局存档立刻落盘（平时由业务节点在关键时机自己调）")
		.set_category(CATEGORY_COMMON)
		.set_order(50))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_open_save_dir", "打开存档文件夹", _open_save_dir)
		.set_tooltip("用系统文件管理器定位到当前账号的存档目录（与 Ctrl+D 然后按 2 同一入口）")
		.set_category(CATEGORY_COMMON)
		.set_order(60))


static func _register_resource_entries(builder: ConsoleEntryControl, parent: Control) -> void:
	## 阳光 / 金币共用一根「增量」滑条：改一次，两个按钮都按这个数走
	var amount_entry := ConsoleEntry.create_slider(&"debug_resource_amount", "增量", 0.0, 5000.0, 50.0) \
		.set_tooltip("下面「加阳光 / 加金币」一次加多少（滑到 0 再加 = 只刷新，不加）") \
		.set_category(CATEGORY_RESOURCE) \
		.set_order(10) \
		.bind_config("debug_window.amount", 1000.0)
	_add(builder, parent, amount_entry)

	_add(builder, parent, ConsoleEntry.create_button(&"debug_add_sun", "加阳光", func() -> void:
		_add_sun(int(amount_entry.get_value())))
		.set_tooltip("按滑条上的数字加阳光（负数就是扣）。只在关卡里生效")
		.set_category(CATEGORY_RESOURCE)
		.set_order(20))

	_add(builder, parent, ConsoleEntry.create_button(&"debug_add_coin", "加金币", func() -> void:
		_add_coin(int(amount_entry.get_value())))
		.set_tooltip("按滑条上的数字加金币（负数就是扣）")
		.set_category(CATEGORY_RESOURCE)
		.set_order(30))


static func _register_runtime_entries(builder: ConsoleEntryControl, parent: Control) -> void:
	_add(builder, parent, ConsoleEntry.create_slider(&"debug_time_scale", "游戏倍速", 0.25, 8.0, 0.25)
		.set_tooltip("改 Engine.time_scale，全局生效。超过 8 倍会因为代码执行顺序出现莫名的 bug")
		.set_category(CATEGORY_RUNTIME)
		.set_order(10)
		.bind(func() -> float: return Global.time_scale,
			func(value: float) -> void:
				Global.time_scale = value
				Engine.time_scale = value))


static func _register_state_entries(builder: ConsoleEntryControl, parent: Control) -> void:
	## 全是只读行（Readout）：值随手在变，由 `DebugWindow` 的定时器统一刷
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_fps", "FPS", _text_fps)
		.set_category(CATEGORY_STATE).set_order(10))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_user", "当前账号", _text_user)
		.set_category(CATEGORY_STATE).set_order(20))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_scene", "当前场景", _text_scene)
		.set_category(CATEGORY_STATE).set_order(30))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_progress", "关卡状态", _text_progress)
		.set_category(CATEGORY_STATE).set_order(40))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_zombie", "僵尸数量", _text_zombie_num)
		.set_category(CATEGORY_STATE).set_order(50))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_sun", "阳光", _text_sun)
		.set_category(CATEGORY_STATE).set_order(60))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_coin", "金币", _text_coin)
		.set_category(CATEGORY_STATE).set_order(70))
	_add(builder, parent, ConsoleEntry.create_readout(&"debug_state_time_scale", "倍速", _text_time_scale)
		.set_category(CATEGORY_STATE).set_order(80))
#endregion


#region 动作
static func _win_level() -> void:
	Global.debug_win_main_game()


static func _blood_moon() -> void:
	if not GameContext.is_in_main_game():
		Log.warn("调试窗口：不在关卡里，「触发血月」没生效")
		return
	var manager := GameContext.curr_main_game.blood_moon_manager
	if manager == null:
		return
	if manager.game_para == null or not manager.game_para.is_blood_moon:
		Log.warn("调试窗口：本关没开血月（要月夜屋顶场景），「触发血月」没生效")
		return
	if manager.is_active:
		manager.end_blood_moon()
	else:
		manager.start_blood_moon()


static func _kill_all_zombie() -> void:
	if not GameContext.is_in_main_game():
		Log.warn("调试窗口：不在关卡里，「清场」没生效")
		return
	GameContext.curr_main_game.shortcut_kill_all_zombie()


static func _success_all_adventure() -> void:
	var num: int = Global.global_game_state.success_all_adventure_level()
	Log.info("调试窗口：通关所有冒险关卡，本次新通关 %d 关" % num)


static func _unlock_all_shop_goods() -> void:
	var num: int = Global.global_game_state.unlock_all_shop_goods()
	Log.info("调试窗口：解锁商店全部商品，本次新拥有 %d 件" % num)


static func _save_now() -> void:
	Global.save_service.save_now()


static func _open_save_dir() -> void:
	Global.debug_open_save_dir()


## 加阳光走 EventBus "add_sun_value"（与玩家点掉一颗阳光同一入口），
## 卡槽会自己刷新数字并重新判定每张卡够不够钱
static func _add_sun(value: int) -> void:
	if not GameContext.is_in_main_game():
		Log.warn("调试窗口：不在关卡里，「加阳光」没生效")
		return
	EventBus.push_event(ConstEventName.ADD_SUN_VALUE, [value])


static func _add_coin(value: int) -> void:
	Global.global_game_state.coin_value += value
#endregion


#region 状态行文本
static func _text_fps() -> String:
	return "%d" % Engine.get_frames_per_second()


static func _text_user() -> String:
	var name: String = Global.user_manager.curr_user_name
	return name if not name.is_empty() else "-"


static func _text_scene() -> String:
	var scene := (Engine.get_main_loop() as SceneTree).current_scene
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


static func _text_zombie_num() -> String:
	if not GameContext.is_in_main_game():
		return "-"
	var zombie_manager := GameContext.curr_main_game.zombie_manager
	if not is_instance_valid(zombie_manager):
		return "-"
	return str(zombie_manager.curr_zombie_num)


static func _text_sun() -> String:
	if not GameContext.is_in_main_game():
		return "-"
	var card_slot := GameContext.curr_main_game.card_manager.card_slot_battle
	if card_slot == null:
		return "-"
	return str(card_slot.sun_value)


static func _text_coin() -> String:
	return str(Global.global_game_state.coin_value)


static func _text_time_scale() -> String:
	return "%.2f" % Engine.time_scale
#endregion


## 统一走这里登记：造控件 + 加进当前这一页
static func _add(builder: ConsoleEntryControl, parent: Control, entry: ConsoleEntry) -> void:
	if builder == null or parent == null or entry == null:
		return
	parent.add_child(builder.create_control(entry))
