extends ModBase
class_name GloveMod
## 模组「手套」：把场上已种下的植物搬到另一个格子（不铲除、不重种，实例与状态全保留）
##
## ★ 为什么是模组：原版没有这个玩法 —— 原版的手套是禅境花园工具（商店买断、用来搬花园植物），
##   关卡内"拎起植物换个地方放下"是同人加的。所以它整条链路都在本模组里，
##   本体（`main_game_base.tscn` / `HandManager` / 卡槽）**不认识手套**，
##   关掉模组时主游戏里不会多出任何一个手套节点。
##
## 装了什么（三件，都在 `install_to_main_game()` 里现场造）：
##   1. `HM_Glove`   —— 手持物组件 `HandComponentGlove`，挂到 `HandManager` 下
##                      （随后被 `HandManager.init_manager()` 登记，类型槽位 `E_HandComponentType.Glove`）
##   2. `UIGlove`    —— 卡槽里的手套按钮，插到 `ShovelContainer`（铲子右边，不占卡牌槽）
##   3. `RealGlove`  —— 跟随鼠标的真手套，挂到 `CanvasLayerTemp`
##
## 还管两件本体做不到的事：
##   1. **解锁进度**（`UNLOCK_ADVENTURE_LEVEL`）：原本写在 `ConstUnlockLevel`（本体）里，
##      现在跟着模组走，本体不再有"手套解锁"这个概念。
##   2. **冷却设置**（有没有冷却 / 冷却几秒）：原版没有手套，也就没有冷却 —— 默认关。
##      值落在**模组存档文件**里本模组那一段（`user://<用户名>/mod_config.ini` 的 `[glove]`，
##      键名见下面两个 `SETTING_KEY_*`，读写走 `ModManager.get/set_mod_value()`），
##      入口在模组页面（主菜单 → 选项 → 控制台 →「模组」→ 手套），读值口是 `is_cooldown_enabled()`
##      与 `get_cooldown_time()`（静态，给每局的 `HandComponentGlove` 用）。
##
## 唯一留在本体里的东西：`adventure_04_06.gd` 开场那段"戴夫送手套"的赠礼对话 ——
## 它是 4-6 的关卡内容（台词与戴夫手上举的手套是关卡演出资源），
## 由关卡脚本按 `ModManager.is_mod_enabled(ModIds.GLOVE)` 决定是否播。

## 卡槽手套按钮插在哪：以铲子槽为锚点（UIShovel 是本体场景的唯一名节点），
## 这样卡槽布局改了也不用改这里
const SHOVEL_SLOT_NODE := "%UIShovel"
## 跟随鼠标的手套挂这一层（layer 20，跟随画布变换，与真铲子 / 真锤子同层）
const TEMP_LAYER_NODE := "%CanvasLayerTemp"
## 取鼠标全局位置的锚点（与草坪同一坐标系）
const TEMP_CHARACTER_NODE := "%TemporaryCharacter"

const GLOVE_SLOT_SCENE := preload("res://src/mods/glove/glove_slot.tscn")
const GLOVE_TEXTURE := preload("res://assets/image/garden/Zen_GardenGlove.png")
## 真手套在屏幕上的初始位置（与真铲子同排，进手持后才跟着鼠标走）
const REAL_GLOVE_POSITION := Vector2(687, 67)

## 解锁：通关冒险 4-5（关卡序号 35）后戴夫把手套交给玩家，4-6 起卡槽才出现手套。
## 选点理由同旧实现：4-6 是矿工僵尸首次登场的关卡，矿工从后排钻出，
## 玩家第一次需要挪动已种下的植物，赠送即教学；更早给会削弱"种下即定"的布局压力。
const UNLOCK_ADVENTURE_LEVEL := 35

## 冷却设置在**模组存档文件**里的键名（`[glove]` 段；与开关同一份文件，不用改 `ConfigService`）
const SETTING_KEY_COOLDOWN_ENABLED := "cooldown_enabled"
const SETTING_KEY_COOLDOWN_TIME := "cooldown_time"
## 冷却时长的可调范围与默认值（秒）
const COOLDOWN_TIME_MIN := 0.5
const COOLDOWN_TIME_MAX := 60.0
const COOLDOWN_TIME_STEP := 0.5
const COOLDOWN_TIME_DEFAULT := 5.0
## 冷却开关的默认值：**关** —— 原版没有这个玩法，旧行为就是"搬完一株接着搬"
const COOLDOWN_ENABLED_DEFAULT := false
## 模组页面里这一组条目的分组名（只出现在模组页面，不进控制台）
const PANEL_CATEGORY := "手套"


## 通关进度是否已够拿到手套（静态：解锁口径属于模组，本体不需要知道）
static func is_unlocked(max_success_adventure_level: int) -> bool:
	return max_success_adventure_level >= UNLOCK_ADVENTURE_LEVEL


## 手套搬完之后是否要冷却（模组页面里的开关；值落在模组存档文件里本模组那一段）
## 静态：冷却口径属于模组，`HandComponentGlove` 每局都要读它，本体完全不认识这回事
static func is_cooldown_enabled() -> bool:
	return bool(ModManager.get_mod_value(
			ModIds.GLOVE, SETTING_KEY_COOLDOWN_ENABLED, COOLDOWN_ENABLED_DEFAULT))


## 冷却时长（秒）：搬完一株之后要等多少秒才能再用手套
static func get_cooldown_time() -> float:
	return clampf(float(ModManager.get_mod_value(
			ModIds.GLOVE, SETTING_KEY_COOLDOWN_TIME, COOLDOWN_TIME_DEFAULT)),
			COOLDOWN_TIME_MIN, COOLDOWN_TIME_MAX)


func get_mod_id() -> StringName:
	return ModIds.GLOVE


func get_mod_name() -> String:
	return "手套"


func get_mod_description() -> String:
	return "关卡内把已种下的植物搬到另一个格子（原版没有，原版手套只用于禅境花园）"


## 模组页面右侧：解锁进度 + 怎么用 + 冷却设置
## （这三件事都属于模组自己，本体不知道"手套解锁"「手套冷却」这回事）
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"解锁：通关冒险 4-5（关卡序号 %d）之后，戴夫在 4-6 开场把手套交给你" % UNLOCK_ADVENTURE_LEVEL))
	box.add_child(ModBase.create_detail_label("进度：" + _progress_text()))
	box.add_child(ModBase.create_detail_label(
		"用法：卡槽里点手套（或按 G）→ 点要搬的植物 → 点目标格子；植物实例与状态原样保留，不铲除也不重种"))

	## 冷却两件套照 `ConsoleEntry` 的写法造（与联机面板同一套渲染器，不新做界面）
	var builder := ConsoleEntryControl.new()
	for item in _build_panel_entries():
		var entry := item as ConsoleEntry
		if entry == null:
			continue
		var control := builder.create_control(entry)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(control)
	## 开关一动，下面那条滑条的「可用 / 置灰」要跟着变：挂刷新回调让页面替我们刷一遍
	box.set_meta(ModBase.DETAIL_REFRESH_META, func() -> void:
		builder.refresh()
	)
	return box


## 冷却那两行条目（**只喂给模组页面**，不往控制台登记 —— 见 [控制台](../../docs/参考存档/控制台.md) §3.2）
func _build_panel_entries() -> Array[ConsoleEntry]:
	return [
		ConsoleEntry.create_toggle(&"glove_cooldown_enabled", "搬完之后有冷却")
			.set_category(PANEL_CATEGORY)
			.set_tooltip("开 = 成功搬完一株植物之后，手套要等一会儿才能再用；关 = 想搬就搬（原版没有手套，默认关）")
			.bind(_get_cooldown_enabled, _set_cooldown_enabled),
		ConsoleEntry.create_slider(&"glove_cooldown_time", "冷却时长（秒）",
				COOLDOWN_TIME_MIN, COOLDOWN_TIME_MAX, COOLDOWN_TIME_STEP)
			.set_category(PANEL_CATEGORY)
			.set_tooltip("搬完一株之后要等多少秒（上面那个开关关掉时这一条置灰，不起作用）")
			.bind(_get_cooldown_time, _set_cooldown_time)
			.set_enabled_getter(func() -> bool: return is_cooldown_enabled()),
	]


func _get_cooldown_enabled() -> Variant:
	return is_cooldown_enabled()


## 改冷却开关：落到模组存档文件之后发一次刷新 —— 滑条的置灰状态要跟着这一下变
func _set_cooldown_enabled(value: Variant) -> void:
	ModManager.set_mod_value(ModIds.GLOVE, SETTING_KEY_COOLDOWN_ENABLED, bool(value))
	if Global != null and Global.console_registry != null:
		Global.console_registry.request_refresh()


func _get_cooldown_time() -> Variant:
	return get_cooldown_time()


func _set_cooldown_time(value: Variant) -> void:
	ModManager.set_mod_value(ModIds.GLOVE, SETTING_KEY_COOLDOWN_TIME,
			clampf(float(value), COOLDOWN_TIME_MIN, COOLDOWN_TIME_MAX))


## 当前存档打到哪了、够不够解锁
func _progress_text() -> String:
	if Global == null or Global.global_game_state == null:
		return "还没进游戏，读不到通关进度"
	var max_level := Global.global_game_state.get_max_success_adventure_level()
	if is_unlocked(max_level):
		return "已通关 %d 关 —— 手套已解锁（下一局卡槽里就有它）" % max_level
	return "已通关 %d 关 —— 还差 %d 关解锁" % [max_level, UNLOCK_ADVENTURE_LEVEL - max_level]


## 每局安装：造出三件套并接好线（本体场景里没有手套节点，全靠这里现场装）
func install_to_main_game(main_game: MainGameManager) -> void:
	var hand_manager: HandManager = main_game.hand_manager
	var shovel_slot: Node = main_game.get_node_or_null(SHOVEL_SLOT_NODE)
	var temp_layer: Node = main_game.get_node_or_null(TEMP_LAYER_NODE)
	var temp_character: Node = main_game.get_node_or_null(TEMP_CHARACTER_NODE)
	if hand_manager == null or shovel_slot == null or temp_layer == null or temp_character == null:
		Log.error("手套模组：主游戏缺少挂载点，本局不安装（HandManager=%s 卡槽=%s 临时层=%s 锚点=%s）" % [
			str(hand_manager != null), str(shovel_slot != null),
			str(temp_layer != null), str(temp_character != null)
		])
		return

	## 1. 跟随鼠标的真手套
	var real_glove := RealGlove.new()
	real_glove.name = "RealGlove"
	real_glove.texture = GLOVE_TEXTURE
	real_glove.position = REAL_GLOVE_POSITION
	real_glove.visible = false
	temp_layer.add_child(real_glove)

	## 2. 卡槽里的手套按钮（与铲子同一排，紧贴铲子右侧）
	var glove_slot: UIGlove = GLOVE_SLOT_SCENE.instantiate()
	glove_slot.name = "UIGlove"
	shovel_slot.get_parent().add_child(glove_slot)

	## 3. 手持物组件（HandManager.init_manager() 紧接着就会把它登记进去）
	var glove_component := HandComponentGlove.new()
	glove_component.name = "HM_Glove"
	glove_component.set_visual_nodes(glove_slot, real_glove, temp_character)
	hand_manager.add_child(glove_component)

	## 4. 卡槽按钮 → 组件（模组内部的连线，不走 EventBus）
	glove_slot.glove_clicked.connect(glove_component.on_click_glove)
