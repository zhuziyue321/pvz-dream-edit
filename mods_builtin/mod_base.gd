@abstract
extends RefCounted
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
##   `create_detail_control()`  —— 模组页面选中本模组时调一次：**右半边的界面**（显示什么、
##                                 能改什么全由模组决定，玩法相关的界面都写在这）
##   `uninstall()`              —— 目前只手动调用：运行期关掉开关时，新的主游戏不再安装
##
## 关闭的模组 = 完全不安装：主游戏场景里不会多出任何一个节点，也不需要本体留分支。

## 「模组页面」右侧详情控件的**刷新回调** meta 键（见 `create_detail_control()`）
const DETAIL_REFRESH_META := &"mod_detail_refresh"

## 模组 id（必须返回 `ModIds` 里的常量）
@abstract
func get_mod_id() -> StringName

## 模组显示名（给将来的模组列表界面 / 日志用）
func get_mod_name() -> String:
	return str(get_mod_id())

## 模组说明：一句话写清它改了什么、为什么不属于原版
func get_mod_description() -> String:
	return ""


## 读本模组**自己的素材**（贴图 / 场景 / 资源）：`rel_path` 相对**模组目录**
## （例：`"tongtong.png"` / `"bonkchoy/bonkchoy_88x73.png"`），读不到给 null。
##
## 内部转调 `ModManager.load_mod_asset(get_mod_id(), rel_path)`：自动按本模组**当前加载根**
## （`user://mods/` 优先 / `res://mods_builtin/` 兜底）解析，`user://` 下的图片自动退回
## `Image` 解码 —— 所以模组素材与模组同目录即可，**不用**再往本体 `res://assets/` 塞
## （那样既不自包含，导出后在 `user://` 下也读不到）。
##
## ⚠️ 只有 `ModBase` 子类能用这个方法：角色 / 组件 / 规则脚本不是 `ModBase` 子类，
## 它们直接写 `ModManager.load_mod_asset(ModIds.XXX, "xxx.png")`。
func load_asset(rel_path: String) -> Resource:
	return ModManager.load_mod_asset(get_mod_id(), rel_path)


## 「模组页面」右侧详情里**模组自己那一块**：显示什么、能改什么，全由模组决定
##
## 页面只保证三样东西（名称 / 开 / 关 / 说明），下面这一块交给模组 ——
## 想放几行状态、几个开关、一个按钮，就在这里 `add_child` 好再返回。
## 不重写 = 返回 null，页面在详情区写一句「这个模组没有要显示的东西」。
##
## 值会变的（如联机状态那一栏）挂一个刷新回调，页面会在条目值变化时调它一次：
##   control.set_meta(ModBase.DETAIL_REFRESH_META, func() -> void: 刷新())
##
## 想复用控制台那套「条目 → 控件」（勾选框 / 按钮 / 滑条 / 输入框 / 只读行）就用
## `ConsoleEntryControl`：一个实例造一堆控件、`refresh()` 一次刷全部值。
func create_detail_control() -> Control:
	return null


## 造一行详情正文（给 `create_detail_control()` 用：页面上说明文字的样式统一在这里，
## 模组只管往自己的 VBoxContainer 里 add_child）
static func create_detail_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

## 全局安装（游戏启动，只调一次）
func install() -> void:
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
