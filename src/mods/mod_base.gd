@abstract
extends RefCounted
class_name ModBase
## 模组基类：原版之外的玩法一律继承本类做成模组
##
## ★ 模组的边界：本体只认 `ModManager` 与 `ModIds`，**不 import 任何模组里的类**；
##   本体需要知道「某个模组开没开」时只调 `ModManager.is_mod_enabled(ModIds.XXX)`。
##   反过来模组可以用本体的一切（注册表的枚举槽位、格子 API、单例…），
##   因为它是装在现有扩展点上的。
##
## 生命周期（都由 ModManager 调用，子类按需重写）：
##   `install()`                —— 游戏启动时对已启用的模组调一次（全局的一次性安装）
##   `on_level_para_ready(mg)`   —— 每局：关卡数据算完之后、子管理器建之前
##                                 （**要改关卡数据就只能在这里改**，见该方法的注释）
##   `install_to_main_game(mg)`  —— 每局主游戏 `init_manager()` 里、`HandManager` 注册组件
##                                 之前调一次（要加手持物 / 卡槽按钮就在这里加）
##   `register_console_entries()` —— `install()` 之后调一次：往控制台加自己的调试开关 / 按钮
##   `uninstall()`              —— 目前只手动调用：运行期关掉开关时，新的主游戏不再安装
##                                 （顺带会把本模组登记的控制台条目整组撤销）
##
## 关闭的模组 = 完全不安装：主游戏场景里不会多出任何一个节点，也不需要本体留分支。

## 模组 id（必须返回 `ModIds` 里的常量）
@abstract
func get_mod_id() -> StringName

## 模组显示名（给将来的模组列表界面 / 日志用）
func get_mod_name() -> String:
	return str(get_mod_id())

## 模组说明：一句话写清它改了什么、为什么不属于原版
func get_mod_description() -> String:
	return ""

## 全局安装（游戏启动，只调一次）
func install() -> void:
	pass


## 往控制台登记本模组的快捷项（可选重写）
##
## 这是模组开发的**快捷工具**：不用改面板、不用改场景、不用改 `ConfigService`，
## 在这里加一行就多一个开关：
##   registry.register_entry(ConsoleEntry.create_toggle(&"xxx_free_move", "无视冷却")
##       .set_category(get_mod_name())
##       .bind_config("xxx.free_move", false))
##
## 想要持久化就用 `bind_config()`（值落在 `ConfigService.console_values`，关控制台时存盘）；
## 只想一次性触发一个动作就用 `ConsoleEntry.create_button()`。
##
## 模组被关掉时，这里登记过的条目会被 `ModManager` 整组撤销（按模组 id 匹配 `source`）。
func register_console_entries(_registry: ConsoleRegistry) -> void:
	pass


## 卸载（运行期关开关时调用；已经装进主游戏的节点随场景一起消失）
func uninstall() -> void:
	pass


## 关卡数据就绪的那一刻（`MainGameManager._ready()` 里 `game_para.init_para()` 之后、
## `init_manager()` 之前）：想**改关卡数据**就必须在这里改
##
## 晚了就来不及：`card_manager.init_manager()` 已经照着 `prechosen_cards` 把出战卡槽填好、
## 待选区对应的卡也藏起来了（见 `CardSlotNorm.init_pre_choosed_card()`），再改字段也没人看。
func on_level_para_ready(_main_game: MainGameManager) -> void:
	pass


## 每局安装：把本模组的东西挂进这一局主游戏
## 调用时机见 `MainGameManager.init_manager()`（排在 `hand_manager.init_manager()` 之前，
## 所以这里加进 `HandManager` 的手持物组件能被正常登记）
func install_to_main_game(_main_game: MainGameManager) -> void:
	pass
