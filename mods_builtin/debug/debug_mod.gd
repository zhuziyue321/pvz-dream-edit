extends "res://src/mods/mod_base.gd"
## 模组「调试模式」：把调试用的那一整套从本体搬出来（原版没有，所以整条链路都在这里）
##
## 装 / 卸时做四件事（**关掉 = 一样都不留**）：
##   1. **僵尸卡片**：`GlobalGameState.set_runtime_zombie_card_enabled()` —— 选卡界面多一页僵尸
##      （含僵王），可以在关卡里直接放下僵尸；
##   2. **四株隐藏植物**：`ConstPlantUnlock.APPENDED_PLANT_TYPES`（三种保龄球 + 反向双发）
##      并进已解锁名单。**只解锁、不登记选卡页** —— 选卡界面里看不到它们；
##   3. **事件追踪**：`EventBus.is_trace_pushed_events` —— 死事件检测
##      （`get_never_pushed_subscribed_events()`）要先开着它才有信息；
##   4. **调试窗口**：Ctrl+Q 呼出 / 收起（`debug_window.gd`，现场 new 出来挂到 `Global` 下）。
##
## ★ 本体不认识本模组：它只留了几个**通用口子**（上面 1 / 3 与 `unlock_plants()` / `lock_plant()`），
##   本体自己从不置真。关掉本模组 = 主场景里不会多出调试窗口、僵尸卡与隐藏植物都回去了。
##
## ⚠️ 解锁与僵尸卡都会被**读档**覆盖（`curr_plant` / `selected_cards` 照存档重建）——
##   所以本模组还重写了 `on_session_reloaded()` 与 `install_to_main_game()` 各补一次。

## 基类只有框架一份（`mod_base.gd` 不写 `class_name`），要先 preload 成常量才能用它的静态方法
const ModBase := preload("res://src/mods/mod_base.gd")
## 同目录的窗口脚本（模组脚本不写 `class_name`，一律 preload 引用）
const DebugWindowScript := preload("debug_window.gd")

## 窗口节点名（排查 / 探针按名字找）
const WINDOW_NODE_NAME := &"DebugWindow"


## 本局正在用的调试窗口（`uninstall()` 时释放）
var _window: CanvasLayer = null


func get_mod_id() -> StringName:
	return ModIds.DEBUG


func get_mod_name() -> String:
	return "调试模式"


func get_mod_description() -> String:
	return "开放僵尸卡片、四株隐藏植物、事件追踪，以及 Ctrl+Q 调试窗口（刷僵尸 / 跳波 / 秒杀 / 无敌 / 跳关 / 日志）。原版没有这些，所以整件东西放在模组里"


func get_mod_categories() -> Array[StringName]:
	return [ModCategory.ADD_STRUCTURE]


func install() -> void:
	_set_debug_mode(true)


func uninstall() -> void:
	_set_debug_mode(false)


## 读档会按存档重建 `curr_plant` —— 解锁要补一遍（见 `ModBase.on_session_reloaded()`）
func on_session_reloaded() -> void:
	_sync_plants()


## 每局补一次解锁：读档 / 切关都按存档重建过 `curr_plant`（与 DLC 植物模组同一招）
func install_to_main_game(_main_game: MainGameManager) -> void:
	_sync_plants()


func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"僵尸卡片：选卡界面多一页（僵尸 + 僵王博士），可以在关卡里直接放下僵尸"))
	box.add_child(ModBase.create_detail_label(
		"四株隐藏植物：坚果保龄球 / 爆炸坚果保龄球 / 巨型坚果墙保龄球 / 反向双发射手"
		+ "——只进已解锁名单，**不进选卡界面**（它们没有卡位）"))
	box.add_child(ModBase.create_detail_label(
		"事件追踪：`EventBus.get_never_pushed_subscribed_events()` 只在开着本模组时才有信息"))
	box.add_child(ModBase.create_detail_label(
		"调试窗口：游戏里按 Ctrl+Q 呼出 / 收起（暂停时也能用）——"
		+ "常用（通关 / 重开 / 跳关 / 存档）、战斗（刷僵尸 / 跳波 / 秒杀 / 植物无敌 / 无限阳光）、"
		+ "资源、开关（与内置控制台同一批字段）、运行（倍速 / 暂停）、状态、日志"))
	box.add_child(ModBase.create_detail_label(
		"关掉本模组：僵尸页、解锁、追踪、窗口一并撤掉，回到原版"))
	return box


## 开 / 关的**全部副作用**都在这里：装与卸各调一次，别在别处零散改状态
func _set_debug_mode(value: bool) -> void:
	var state := Global.global_game_state
	state.set_runtime_zombie_card_enabled(value)
	EventBus.is_trace_pushed_events = value
	if value:
		_sync_plants()
		_spawn_window()
		return
	_lock_plants()
	_free_window()


## 把四株隐藏植物并进已解锁名单（幂等，读档 / 每局都补一次）
func _sync_plants() -> void:
	Global.global_game_state.unlock_plants(ConstPlantUnlock.APPENDED_PLANT_TYPES)


## 撤掉解锁时必须**真的从 curr_plant 里删**：读档会按存档记录重建那份列表
## （见 `SaveService._build_curr_plant`），只把开关置 false 的话下次读档植物又回来了
func _lock_plants() -> void:
	for plant_type: StringName in ConstPlantUnlock.APPENDED_PLANT_TYPES:
		Global.global_game_state.lock_plant(plant_type)


## 现场造调试窗口并常驻在 `Global` 下（本体场景里没有这个节点）
## `EventBus`（第 7 个 autoload）此时已经就绪，所以可以直接 add_child
func _spawn_window() -> void:
	if is_instance_valid(_window):
		return
	_window = DebugWindowScript.new()
	_window.name = WINDOW_NODE_NAME
	Global.add_child(_window)


func _free_window() -> void:
	if not is_instance_valid(_window):
		return
	## 窗口开着时要把「系统鼠标」那条事件撤掉，否则关掉模组后鼠标还留在系统光标模式
	if _window.has_method("set_window_visible"):
		_window.set_window_visible(false)
	_window.queue_free()
	_window = null
