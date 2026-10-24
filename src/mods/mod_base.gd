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

## 本模组伤害修饰器的优先级（**数字大的先跑**，见 `DamageModifier.priority`）。
## 多个模组各挂一条修饰规则时，用它定彼此的叠加顺序（先过滤 / 再倍率 / 最后夹上下限…）。
var damage_modifier_priority: int = 0
## 把 `modify_damage()` 转发进 `DamageSystem` 修饰器链的包装体（框架注册 / 注销，见文末 #region）
var _damage_modifier: DamageModifier = null
## 模组用 `register_damage_modifier()` 手动挂的**额外**修饰器（一个模组想要多条独立规则时用）
var _extra_modifiers: Array[DamageModifier] = []

## 模组 id（必须返回 `ModIds` 里的常量）
@abstract
func get_mod_id() -> StringName

## 模组显示名（给将来的模组列表界面 / 日志用）
func get_mod_name() -> String:
	return str(get_mod_id())

## 模组说明：一句话写清它改了什么、为什么不属于原版
func get_mod_description() -> String:
	return ""

## 模组分类（维度 C：内容性质）。**多标签**：一个模组可同时归属多个分类，
## 返回 `ModCategory` 常量数组（如 `[ModCategory.ADD_UNIT]`）。
## 默认空 = 未分类；模组页面里没选中任何分类时所有模组都显示（OR 语义）。
func get_mod_categories() -> Array[StringName]:
	return []


## 本模组**依赖**哪些模组（`ModIds` 常量数组，如 `[ModIds.ARKNIGHTS]`）：
##   · **打开本模组时，依赖会被一并打开**（`ModManager.set_mod_enabled()` 里递归补开，
##     带环保护；存档文件里也是开着，下次启动照旧）；
##   · 模组页面详情**末尾**会列出它们，每个依赖一个按钮，点了跳过去看那个模组。
## 默认空数组 = 不依赖任何模组。**只用来表达"缺了它就装不起来 / 跑不对"** ——
## "顺便建议开哪个模组"别写在这里：那会把别人开关的状态强行改掉。
func get_mod_dependencies() -> Array[StringName]:
	return []


## 读本模组**自己的素材**（贴图 / 场景 / 资源）：`rel_path` 相对**模组目录**
## （例：`"tongtong.png"` / `"bonkchoy/bonkchoy_88x73.png"`），读不到给 null。
##
## 内部转调 `ModManager.load_mod_asset(get_mod_id(), rel_path)`：自动按本模组**当前加载根**
## （`user://mods/` 优先 / `res://mods_builtin/` 兜底）解析，`user://` 下的图片自动退回
## `Image` 解码 —— 所以模组素材与模组同目录即可，**不用**再往本体 `res://assets_custom/` 塞
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


#region 伤害修饰器链（可选接入）
## 把本模组接进 `DamageSystem` 的伤害修饰器链（②-c，**最终结算前**）。
##
## 只想加一条全局伤害规则：**重写 `modify_damage()`** 即可 —— 框架在 `install()` 之后
## 自动注册、`uninstall()` 之后自动注销，**不用**自己调 `DamageSystem.register_modifier()`，
## 也不必管切关残留（修饰器注册后跨关持续，关开关 / 换用户时由 `ModManager` 统一摘掉）。
## 多个模组各贡献一条，按 `damage_modifier_priority` 降序串成链。
##
## 例：给带「防御力」属性的目标做物理减伤
## [codeblock]
## const KEY_DMG_TYPE := &"meta_dmg_type"
## const TYPE_PHYSICAL := &"physical"
##
## func modify_damage(info: DamageInfo) -> bool:
##     ## 没标类型的一概按物理处理（覆盖原版子弹：它们不会打这个标记）
##     if info.get_effect(KEY_DMG_TYPE, TYPE_PHYSICAL) != TYPE_PHYSICAL:
##         return true                                  ## 非物理，不动
##     var defense: int = _defense_of(info.target)      ## 从目标读本模组加的防御力
##     info.amount = maxi(0, info.amount - defense)     ## 只改包，系统③按剩下的扣
##     return true
## [codeblock]

## 本模组对**每一次伤害**的统一加工（可改 `info.amount` / `info.mode`，或整包取消）。
## 默认什么都不做；重写时**不要**在这里再调 `DamageSystem.apply()`（嵌套伤害，见 `DamageModifier`）。
## [return] true = 继续结算；false = 取消这次伤害（一滴血都不掉）
func modify_damage(_info: DamageInfo) -> bool:
	return true


## 手动注册一个**额外**修饰器（一个模组想要多条独立规则时用；转发 `modify_damage()`
## 的那条由框架自动管，不经过这里）。切关不清修饰器，关开关 / 换用户时由框架统一摘。
func register_damage_modifier(modifier: DamageModifier) -> void:
	if modifier == null or _extra_modifiers.has(modifier):
		return
	_extra_modifiers.append(modifier)
	DamageSystem.register_modifier(modifier)


## 摘掉一个 `register_damage_modifier()` 挂上的修饰器
func unregister_damage_modifier(modifier: DamageModifier) -> void:
	if modifier == null:
		return
	_extra_modifiers.erase(modifier)
	DamageSystem.unregister_modifier(modifier)


## 注册本模组的伤害修饰器（**由 `ModManager` 在 `install()` 之后调用**，模组不要自己调）
func _install_damage_modifiers() -> void:
	if _damage_modifier == null:
		_damage_modifier = _ModDamageModifier.new(self)
	DamageSystem.register_modifier(_damage_modifier)


## 注销本模组的全部伤害修饰器（**由 `ModManager` 在 `uninstall()` 之后调用**，模组不要自己调）
func _uninstall_damage_modifiers() -> void:
	if _damage_modifier != null:
		DamageSystem.unregister_modifier(_damage_modifier)
		_damage_modifier = null
	for modifier in _extra_modifiers:
		DamageSystem.unregister_modifier(modifier)
	_extra_modifiers.clear()
#endregion


## 转发体：让「模组」能以「修饰器」的身份进 `DamageSystem` 的修饰器链。
## 为什么不直接让 ModBase 继承 DamageModifier：ModBase 是 `RefCounted` 基类、要被
## `ModManager` 当模组入口用，GDScript 没有多继承，只能包一层（同 `DamageModifierComponent`）。
class _ModDamageModifier extends DamageModifier:
	## 指向宿主模组实例（`ModBase` 无 class_name，用 Variant 动态转发）
	var _owner: Variant

	func _init(owner: Variant) -> void:
		_owner = owner
		priority = owner.damage_modifier_priority

	func modify(info: DamageInfo) -> bool:
		if _owner == null:
			return true
		return _owner.modify_damage(info)
