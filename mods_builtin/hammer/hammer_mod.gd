extends "../mod_base.gd"
## 模组「锤子」：点一下草坪，对以点击点为中心的小范围内的僵尸造成伤害
##
## ★ 为什么是模组：原版没有这个玩法 —— 原版的锤子只属于「锤僵尸」迷你游戏
##   （`src/items/mini_game/` + `HandComponentHammer`，单锤 1800 点且只打最左边一只）。
##   本模组的锤子是独立的范围伤害工具，整条链路都在本模组里，
##   本体（`main_game_base.tscn` / `HandManager` / 卡槽）**不认识它**，
##   关掉模组时主游戏里不会多出任何一个节点。
##
## 装了什么（三件，都在 `install_to_main_game()` 里现场造）：
##   1. `HM_HammerMod`   —— 手持物组件 `HandComponentHammerMod`，挂到 `HandManager` 下
##                          （手持物类型槽位 `E_HandComponentType.HammerMod`，
##                          与迷你游戏占用的 `Hammer` 槽位互不相干）
##   2. `UIHammer`       —— 卡槽里的锤子按钮，插到 `ShovelContainer`（手套右边，不占卡牌槽）
##   3. `RealHammerMod`  —— 跟随鼠标的真锤子（美术与挥锤动画复用迷你游戏的锤子资源），挂到 `CanvasLayerTemp`
##
## 交互：卡槽点锤子（或按 H）→ 拿到手上（锤子跟着鼠标走）→ 点草坪 → 挥一锤，
## 对范围内的僵尸按设置造成伤害（固定数值，或一键秒杀）；右键或点空白收回锤子。
##
## **解锁**：装着还不够 —— 要通关冒险 2-4（关卡序号 14）之后锤子才归玩家，2-5 起卡槽里有它
## （跟着模组走：解锁口径属于模组自己，本体不再有"锤子解锁"这个概念，与手套同款处理）。
##
## 可设置（都落在**模组存档文件**里本模组那一段：`user://<用户名>/mod_config.ini` 的 `[hammer]`，
## 读写走 `ModManager.get/set_mod_value()`，入口在模组页面
## 主菜单 → 选项 → 控制台 →「模组」→ 锤子；读值口是下面的静态函数，给每局的组件用）：
##   · `kill_mode`         一键秒杀（开着就忽略伤害数值）
##   · `damage_value`      伤害数值
##   · `radius`            范围半径（像素）
##   · `cooldown_enabled`  挥完之后有没有冷却
##   · `cooldown_time`     冷却时长（秒）

## 卡槽锤子按钮插在哪：以铲子槽为锚点（UIShovel 是本体场景的唯一名节点），
## 手套占 70~140，锤子接着排 140~210
## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以同目录 / 上级的文件一律 preload 成常量再引用，不能写 `extends Xxx` / `var x: Xxx`
const ModBase := preload("../mod_base.gd")
const HandComponentHammerMod := preload("hand_component_hammer_mod.gd")

const SHOVEL_SLOT_NODE := "%UIShovel"
## 跟随鼠标的锤子挂这一层（layer 20，跟随画布变换，与真铲子 / 真手套同层）
const TEMP_LAYER_NODE := "%CanvasLayerTemp"
## 取鼠标全局位置的锚点（与草坪同一坐标系）
const TEMP_CHARACTER_NODE := "%TemporaryCharacter"

const HAMMER_SLOT_SCENE := preload("hammer_slot.tscn")
const REAL_HAMMER_SCENE := preload("real_hammer_mod.tscn")
## 真锤子在屏幕上的初始位置（不手持时不显示，进手持后跟着鼠标走）
const REAL_HAMMER_POSITION := Vector2(687, 67)

## 设置（秒杀 / 伤害 / 范围 / 冷却）的**定义与读值口**单独在 `hammer_settings.gd`
## （`hammer_mod.gd` 与 `hand_component_hammer_mod.gd` 都要读，两边互相 preload 会成环）
const HammerSettings := preload("hammer_settings.gd")

## 解锁所需的冒险模式关卡序号（2-4 = 14）：通关它之后才有锤子
## 定义与读值口都在 `hammer_settings.gd`（`hammer_mod.gd` 与 `hand_component_hammer_mod.gd` 都要读）
const UNLOCK_ADVENTURE_LEVEL := HammerSettings.UNLOCK_ADVENTURE_LEVEL

## 设置在**模组存档文件**里的键名（`[hammer]` 段）
const SETTING_KEY_KILL_MODE := HammerSettings.SETTING_KEY_KILL_MODE
const SETTING_KEY_DAMAGE := HammerSettings.SETTING_KEY_DAMAGE
const SETTING_KEY_RADIUS := HammerSettings.SETTING_KEY_RADIUS
const SETTING_KEY_COOLDOWN_ENABLED := HammerSettings.SETTING_KEY_COOLDOWN_ENABLED
const SETTING_KEY_COOLDOWN_TIME := HammerSettings.SETTING_KEY_COOLDOWN_TIME

## 伤害数值的可调范围与默认值
const DAMAGE_VALUE_MIN := HammerSettings.DAMAGE_VALUE_MIN
const DAMAGE_VALUE_MAX := HammerSettings.DAMAGE_VALUE_MAX
const DAMAGE_VALUE_STEP := HammerSettings.DAMAGE_VALUE_STEP
const DAMAGE_VALUE_DEFAULT := HammerSettings.DAMAGE_VALUE_DEFAULT
## 范围半径的可调范围与默认值（像素）
const RADIUS_MIN := HammerSettings.RADIUS_MIN
const RADIUS_MAX := HammerSettings.RADIUS_MAX
const RADIUS_STEP := HammerSettings.RADIUS_STEP
const RADIUS_DEFAULT := HammerSettings.RADIUS_DEFAULT
## 冷却时长的可调范围与默认值（秒）
const COOLDOWN_TIME_MIN := HammerSettings.COOLDOWN_TIME_MIN
const COOLDOWN_TIME_MAX := HammerSettings.COOLDOWN_TIME_MAX
const COOLDOWN_TIME_STEP := HammerSettings.COOLDOWN_TIME_STEP
const COOLDOWN_TIME_DEFAULT := HammerSettings.COOLDOWN_TIME_DEFAULT
## 各开关的默认值：数值伤害（不秒杀）、无冷却 —— 与手套模组同口径
const KILL_MODE_DEFAULT := HammerSettings.KILL_MODE_DEFAULT
const COOLDOWN_ENABLED_DEFAULT := HammerSettings.COOLDOWN_ENABLED_DEFAULT
## 模组页面里这一组条目的分组名（只出现在模组页面，不进控制台）
const PANEL_CATEGORY := "锤子"


## 通关进度是否已够拿到锤子（静态：解锁口径属于模组，本体不需要知道）
static func is_unlocked(max_success_adventure_level: int) -> bool:
	return HammerSettings.is_unlocked(max_success_adventure_level)


## 是否一键秒杀（模组页面里的开关；开着就忽略伤害数值）
static func is_kill_mode() -> bool:
	return HammerSettings.is_kill_mode()


## 伤害数值：一锤对范围内每只僵尸造成的伤害（秒杀开关打开时不看这个值）
static func get_damage_value() -> int:
	return HammerSettings.get_damage_value()


## 范围半径（像素）：以点击点为圆心，圆内（按僵尸受击框）都挨这一锤
static func get_radius() -> float:
	return HammerSettings.get_radius()


## 挥完之后是否要冷却
static func is_cooldown_enabled() -> bool:
	return HammerSettings.is_cooldown_enabled()


## 冷却时长（秒）：挥完一锤之后要等多少秒才能再挥
static func get_cooldown_time() -> float:
	return HammerSettings.get_cooldown_time()


func get_mod_id() -> StringName:
	return ModIds.HAMMER


func get_mod_name() -> String:
	return "锤子"


func get_mod_description() -> String:
	return "点一下草坪，对小范围内的僵尸造成伤害（伤害数值可调，也可一键秒杀；原版没有）"


## 模组页面右侧：怎么用 + 五个设置
## （设置属于模组自己，本体不知道「锤子伤害」「锤子冷却」这回事）
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"解锁：通关冒险 2-4（关卡序号 %d）之后获得，2-5 起可操作草坪的关卡卡槽里就有锤子" % UNLOCK_ADVENTURE_LEVEL))
	box.add_child(ModBase.create_detail_label("进度：" + _progress_text()))
	box.add_child(ModBase.create_detail_label(
		"用法：卡槽里点锤子（或按 H）→ 点草坪任意位置 → 挥一锤，范围内（按僵尸受击框）的僵尸一起挨打；右键或点空白收回"))

	## 设置五件套照 `ConsoleEntry` 的写法造（与手套 / 联机面板同一套渲染器，不新做界面）
	var builder := ConsoleEntryControl.new()
	for item in _build_panel_entries():
		var entry := item as ConsoleEntry
		if entry == null:
			continue
		var control := builder.create_control(entry)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(control)
	## 开关一动，下面几条滑条的「可用 / 置灰」要跟着变：挂刷新回调让页面替我们刷一遍
	box.set_meta(ModBase.DETAIL_REFRESH_META, func() -> void:
		builder.refresh()
	)
	return box


## 设置那几行条目（**只喂给模组页面**，不往控制台登记 —— 见 [控制台](../../docs/参考存档/控制台.md) §3.2）
func _build_panel_entries() -> Array[ConsoleEntry]:
	return [
		ConsoleEntry.create_toggle(&"hammer_kill_mode", "一键秒杀")
			.set_category(PANEL_CATEGORY)
			.set_tooltip("开 = 范围内的僵尸直接被锤死（忽略下面的伤害数值）；关 = 按下面的数值扣血")
			.bind(_get_kill_mode, _set_kill_mode),
		ConsoleEntry.create_slider(&"hammer_damage_value", "伤害数值",
				DAMAGE_VALUE_MIN, DAMAGE_VALUE_MAX, DAMAGE_VALUE_STEP)
			.set_category(PANEL_CATEGORY)
			.set_tooltip("一锤对范围内每只僵尸造成的伤害（上面那个开关打开时这一条置灰，不起作用）")
			.bind(_get_damage_value, _set_damage_value)
			.set_enabled_getter(func() -> bool: return not is_kill_mode()),
		ConsoleEntry.create_slider(&"hammer_radius", "范围半径（像素）",
				RADIUS_MIN, RADIUS_MAX, RADIUS_STEP)
			.set_category(PANEL_CATEGORY)
			.set_tooltip("以点击点为圆心，圆内的僵尸都挨这一锤")
			.bind(_get_radius, _set_radius),
		ConsoleEntry.create_toggle(&"hammer_cooldown_enabled", "挥完之后有冷却")
			.set_category(PANEL_CATEGORY)
			.set_tooltip("开 = 挥完一锤之后，锤子要等一会儿才能再用；关 = 想挥就挥")
			.bind(_get_cooldown_enabled, _set_cooldown_enabled),
		ConsoleEntry.create_slider(&"hammer_cooldown_time", "冷却时长（秒）",
				COOLDOWN_TIME_MIN, COOLDOWN_TIME_MAX, COOLDOWN_TIME_STEP)
			.set_category(PANEL_CATEGORY)
			.set_tooltip("挥完一锤之后要等多少秒（上面那个开关关掉时这一条置灰，不起作用）")
			.bind(_get_cooldown_time, _set_cooldown_time)
			.set_enabled_getter(func() -> bool: return is_cooldown_enabled()),
	]


func _get_kill_mode() -> Variant:
	return is_kill_mode()


## 改秒杀开关：落到模组存档文件之后发一次刷新 —— 伤害滑条的置灰状态要跟着这一下变
func _set_kill_mode(value: Variant) -> void:
	ModManager.set_mod_value(ModIds.HAMMER, SETTING_KEY_KILL_MODE, bool(value))
	if Global != null and Global.console_registry != null:
		Global.console_registry.request_refresh()


func _get_damage_value() -> Variant:
	return get_damage_value()


func _set_damage_value(value: Variant) -> void:
	ModManager.set_mod_value(ModIds.HAMMER, SETTING_KEY_DAMAGE,
			clampi(int(value), DAMAGE_VALUE_MIN, DAMAGE_VALUE_MAX))


func _get_radius() -> Variant:
	return get_radius()


func _set_radius(value: Variant) -> void:
	ModManager.set_mod_value(ModIds.HAMMER, SETTING_KEY_RADIUS,
			clampf(float(value), RADIUS_MIN, RADIUS_MAX))


func _get_cooldown_enabled() -> Variant:
	return is_cooldown_enabled()


## 改冷却开关：落到模组存档文件之后发一次刷新 —— 冷却滑条的置灰状态要跟着这一下变
func _set_cooldown_enabled(value: Variant) -> void:
	ModManager.set_mod_value(ModIds.HAMMER, SETTING_KEY_COOLDOWN_ENABLED, bool(value))
	if Global != null and Global.console_registry != null:
		Global.console_registry.request_refresh()


func _get_cooldown_time() -> Variant:
	return get_cooldown_time()


func _set_cooldown_time(value: Variant) -> void:
	ModManager.set_mod_value(ModIds.HAMMER, SETTING_KEY_COOLDOWN_TIME,
			clampf(float(value), COOLDOWN_TIME_MIN, COOLDOWN_TIME_MAX))


## 当前存档打到哪了、够不够解锁
func _progress_text() -> String:
	if Global == null or Global.global_game_state == null:
		return "还没进游戏，读不到通关进度"
	var max_level: int = Global.global_game_state.get_max_success_adventure_level()
	if is_unlocked(max_level):
		return "已通关 %d 关 —— 锤子已获得（下一局卡槽里就有它）" % max_level
	return "已通关 %d 关 —— 还差 %d 关获得（要通关 2-4）" % [
		max_level, UNLOCK_ADVENTURE_LEVEL - max_level]


## 每局安装：造出三件套并接好线（本体场景里没有锤子模组的节点，全靠这里现场装）
func install_to_main_game(main_game: MainGameManager) -> void:
	var hand_manager: HandManager = main_game.hand_manager
	var shovel_slot: Node = main_game.get_node_or_null(SHOVEL_SLOT_NODE)
	var temp_layer: Node = main_game.get_node_or_null(TEMP_LAYER_NODE)
	var temp_character: Node = main_game.get_node_or_null(TEMP_CHARACTER_NODE)
	if hand_manager == null or shovel_slot == null or temp_layer == null or temp_character == null:
		Log.error("锤子模组：主游戏缺少挂载点，本局不安装（HandManager=%s 卡槽=%s 临时层=%s 锚点=%s）" % [
			str(hand_manager != null), str(shovel_slot != null),
			str(temp_layer != null), str(temp_character != null)
		])
		return

	## 1. 跟随鼠标的真锤子
	var real_hammer = REAL_HAMMER_SCENE.instantiate()
	real_hammer.name = "RealHammerMod"
	real_hammer.position = REAL_HAMMER_POSITION
	real_hammer.visible = false
	temp_layer.add_child(real_hammer)

	## 2. 卡槽里的锤子按钮（与铲子同一排，手套右侧）
	var hammer_slot = HAMMER_SLOT_SCENE.instantiate()
	hammer_slot.name = "UIHammer"
	shovel_slot.get_parent().add_child(hammer_slot)

	## 3. 手持物组件（HandManager.init_manager() 紧接着就会把它登记进去）
	var hammer_component := HandComponentHammerMod.new()
	hammer_component.name = "HM_HammerMod"
	hammer_component.set_visual_nodes(hammer_slot, real_hammer, temp_character)
	hand_manager.add_child(hammer_component)

	## 4. 卡槽按钮 → 组件（模组内部的连线，不走 EventBus）
	hammer_slot.hammer_clicked.connect(hammer_component.on_click_hammer)
