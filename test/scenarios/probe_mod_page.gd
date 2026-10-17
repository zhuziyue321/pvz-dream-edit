extends RefCounted

## 妯＄粍鎼埌 `user://mods/` 鍚?class_name 涓嶅啀娉ㄥ唽涓哄叏灞€绫伙紝鎺㈤拡杩欓噷 preload 鎴愬父閲忓啀寮曠敤
const GloveMod := preload("res://mods_builtin/glove/glove_mod.gd")
const ModBase := preload("res://mods_builtin/mod_base.gd")
## 探针：模组页面（`src/ui/mod_page/`）
##
## 验七件事：
##   1. 入口：主菜单 → 选项 → 控制台（`StartMenuOptionDialog/Button4`，按钮文字就是「控制台」），
##      本页面挂在这个控制台上（`StartMenuOptionDialog/Button4/ModPage`，默认隐藏），
##      控制台的入口页会多一个「模组」按钮；选项面板里不再有单独的「模组」按钮
##   2. 左列：登记过几个模组就列几条（`ModManager.all_mods` 是唯一来源）
##   3. 右侧详情：名称 / 开关 / 说明由页面造，**下面那一块是模组自己给的**
##      （手套给了三行解锁进度与用法 + 冷却两件套；联机没启用时只给一句话，启用后是整块联机面板）
##   4. 模组**没启用**时它那一块**整块禁用**（页面统一处理，模组自己不用判），
##      页面自己造的「启用这个模组」按钮不受影响；启用之后那一块恢复可操作
##   5. 开关：点详情里的开关按钮能真的开 / 关模组，列表上的状态跟着变
##   6. 存档文件：开关与模组自己的设置**同段**落在 `user://<用户名>/mod_config.ini`，
##      再读回来（换用户 / 重开游戏那条路）开关与设置都要还在
##      （外加一条反断言：控制台里已经没有「模组」「联机」这两栏）
##   7. 依赖列表：详情**末尾**有「依赖的模组」一块；没声明依赖时写一句
##      「不依赖其它模组」（现役只有生态版声明了依赖：依赖「紫卡直接种植」，先核对这条真实声明）；
##      再给手套临时换一份「依赖锤子」的脚本，验未登记 id 被剔除、
##      依赖按钮点了跳转到锤子的详情、打开手套时锤子被一并打开（跑完还原脚本与开关）

const MOD_PAGE_TSCN := "res://src/ui/mod_page/mod_page.tscn"
## 模组存档文件里手套那一段的键名（与 `GloveMod.SETTING_KEY_COOLDOWN_TIME` 同值，探针自带一份，
## 免得哪天模组的键名换了、探针还跟着旧名字走却看不出来）
const SETTING_TIME_KEY := "cooldown_time"
## 模组存档文件名（与 `ModManager.MOD_SAVE_FILE` 同值，在**当前用户**目录下）
const MOD_SAVE_FILE := "mod_config.ini"
## 详情末尾那块「依赖的模组」的名字（与 `ModPage.DEPENDENCY_BOX_NAME` 同值；
## 页面自己造的，探针靠名字找它 —— 它前面有几行随模组而变，靠下标不稳）
const DEPENDENCY_BOX_NAME := "DependencyBox"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 模组页面 ==========")
	## 等主菜单自身初始化完（按钮滑入动画）再动场景
	await a.wait(2.0)
	var root := (Engine.get_main_loop() as SceneTree).root

	#region 1 入口
	var start_menu := root.get_node_or_null("StartMenu")
	_check(a, "主菜单已起来", start_menu != null)
	if start_menu == null:
		_finish(a)
		return

	var entry_label := start_menu.get_node_or_null("StartMenuOptionDialog/Button4/Label")
	_check(a, "选项面板里的入口按钮改名为「控制台」", entry_label != null and entry_label.text == "控制台")
	var console := start_menu.get_node_or_null("StartMenuOptionDialog/Button4/CanvasLayer")
	_check(a, "「控制台」按钮上挂着控制台，且默认隐藏", console != null and not console.visible)
	var page_in_menu := start_menu.get_node_or_null("StartMenuOptionDialog/Button4/ModPage")
	_check(a, "控制台上挂着模组页面，且默认隐藏", page_in_menu != null and not page_in_menu.visible)
	_check(a, "控制台认得模组页面（入口页才有「模组」按钮）", console != null and console.mod_page == page_in_menu)
	_check(a, "选项面板里不再有单独的「模组」按钮",
		start_menu.get_node_or_null("StartMenuOptionDialog/Button5") == null)
	## 光挂上不算数：控制台入口页要真的有「模组」按钮，点了要真的能打开本页面
	if console != null and page_in_menu != null:
		console.appear_canvas_layer_control()
		var nav := _find_nav_button(console, "模组")
		_check(a, "控制台入口页有「模组」按钮", nav != null)
		if nav != null:
			nav.pressed.emit()
			_check(a, "点「模组」按钮能打开模组页面", page_in_menu.visible)
			_check(a, "模组页面是盖在控制台上的（控制台没被关掉）", console.visible)
			page_in_menu._on_close_button_pressed()
			_check(a, "关掉模组页面后回到控制台（页面隐藏、控制台还在）",
				not page_in_menu.visible and console.visible)
			nav.pressed.emit()
			console._on_texture_button_pressed()
			_check(a, "关掉控制台时模组页面一起收掉",
				not console.visible and not page_in_menu.visible)
	#endregion

	#region 2 左列
	## ★ 模组开关是**持久化**的：上一次跑探针（或玩家自己）可能把某个模组留在开着的状态，
	##   下面几节是按"手套关着"这一端验的，先把它归零，别让上一次的存档把本次探针带歪
	if ModManager.is_mod_enabled(ModIds.GLOVE):
		ModManager.set_mod_enabled(ModIds.GLOVE, false)
		ModManager.save_mods()
	var page: ModPage = load(MOD_PAGE_TSCN).instantiate()
	root.add_child(page)
	page.build_mod_page()
	var list_buttons := _list_buttons(page)
	var texts := _button_texts(list_buttons)
	a.log("[MODPAGE] 列表=%s" % str(texts))
	_check(a, "列表条数 = 登记的模组数（%d）" % ModManager.all_mods.size(),
		list_buttons.size() == ModManager.all_mods.size())
	_check(a, "列表里的名字取自 ModBase.get_mod_name()", texts.any(func(t: String) -> bool:
		return t.contains("手套")))
	_check(a, "列表上带着开关状态", texts.any(func(t: String) -> bool:
		return t.contains("未启用")))
	#endregion

	#region 3 右侧详情：模组自己给的那一块
	_click(_find_list_button(page, "手套"))
	var glove_detail := _mod_control(page)
	_check(a, "选中手套后详情里有模组自己给的那一块", glove_detail != null)
	if glove_detail != null:
		var lines := _label_texts(glove_detail)
		a.log("[MODPAGE] 手套详情=%s" % str(lines))
		_check(a, "手套详情里写着解锁条件与用法", lines.any(func(t: String) -> bool:
			return t.contains("解锁")))
		## 模组没启用 = 它那一块整块禁用（关着的模组下一局不装载，里面的设置改了也不生效）
		var glove_inputs := _collect_interactive(glove_detail)
		a.log("[MODPAGE] 手套那一块的可交互控件=%d" % glove_inputs.size())
		_check(a, "手套没启用时，它那一块里的控件全被禁用",
			glove_inputs.size() > 0 and glove_inputs.all(func(c: Control) -> bool:
				return not _is_enabled(c)))
		## 开关按钮是页面自己造的（启用模组用的），**不能**跟着一起被禁
		var page_toggle := _toggle_button(page)
		_check(a, "「启用这个模组」按钮不受影响（还能点）",
			page_toggle != null and not page_toggle.disabled)

	## 联机那块跟着开关走：没启用 = 一句话，启用了 = 整块面板（6 条控件）
	## （存档文件里它是开着还是关着都算对，所以两端都认）
	_click(_find_list_button(page, "联机"))
	var net_detail := _mod_control(page)
	if ModManager.is_mod_enabled(ModIds.NETPLAY):
		_check(a, "联机启用时详情里是整块面板（6 条控件）",
			net_detail is VBoxContainer and net_detail.get_child_count() == 6)
	else:
		_check(a, "联机没启用时详情里先给一句话（不是空面板）", net_detail != null and net_detail is Label)
	#endregion

	#region 4 开关
	_click(_find_list_button(page, "手套"))
	var toggle := _toggle_button(page)
	_check(a, "详情里有开 / 关按钮", toggle != null)
	if toggle != null:
		_check(a, "手套初始是关的", not ModManager.is_mod_enabled(ModIds.GLOVE))
		toggle.pressed.emit()
		_check(a, "点了开关之后模组被打开", ModManager.is_mod_enabled(ModIds.GLOVE))
		_check(a, "列表上的状态跟着变成已启用", _button_texts(_list_buttons(page)).any(
			func(t: String) -> bool: return t.contains("手套（已启用）")))
		## 启用之后它那一块要能用了（冷却开关 / 时长那两行）
		var enabled_block := _mod_control(page)
		_check(a, "手套启用后，它那一块里的控件恢复可操作",
			_collect_interactive(enabled_block).all(func(c: Control) -> bool: return _is_enabled(c)))
		## 关回去，别把后面的探针带歪
		var toggle2 := _toggle_button(page)
		if toggle2 != null:
			toggle2.pressed.emit()
		_check(a, "再点一次又关回去", not ModManager.is_mod_enabled(ModIds.GLOVE))
		_check(a, "关回去之后那一块又整块禁用",
			_collect_interactive(_mod_control(page)).all(func(c: Control) -> bool:
				return not _is_enabled(c)))
	#endregion

	#region 5 存档文件：开关与设置都在 `user://<用户名>/mod_config.ini`
	## 页面上的开 / 关与模组自己的设置**都落进同一份存档文件**（下次启动照旧，不用再改 data/ 里的资源）
	var save_path := _mod_save_path()
	a.log("[MODPAGE] 模组存档=%s" % save_path)
	_check(a, "拿得到模组存档路径（要有登录用户）", not save_path.is_empty())
	if not save_path.is_empty():
		ModManager.set_mod_enabled(ModIds.GLOVE, true)
		ModManager.set_mod_value(ModIds.GLOVE, GloveMod.SETTING_KEY_COOLDOWN_TIME, 7.0)
		ModManager.save_mods()
		var config := ConfigFile.new()
		var err := config.load(save_path)
		_check(a, "存档文件写出来了", err == OK)
		if err == OK:
			_check(a, "手套的开关写在 [glove] 段的 enabled",
				config.has_section_key("glove", "enabled") \
					and bool(config.get_value("glove", "enabled", false)))
			_check(a, "模组自己的设置与开关同段（[glove] cooldown_time=7.0）",
				float(config.get_value("glove", SETTING_TIME_KEY, 0.0)) == 7.0)
		## 再读回来：开关与设置都要能还原（`reload_for_current_user()` = 换用户 / 重开游戏那条路）
		ModManager.reload_for_current_user()
		_check(a, "重新读档后手套还是开着的", ModManager.is_mod_enabled(ModIds.GLOVE))
		_check(a, "重新读档后设置值还在",
			float(ModManager.get_mod_value(ModIds.GLOVE, SETTING_TIME_KEY, 0.0)) == 7.0)
		## 还原：别把后面 / 下一次的探针带歪
		ModManager.set_mod_value(ModIds.GLOVE, SETTING_TIME_KEY, GloveMod.COOLDOWN_TIME_DEFAULT)
		ModManager.set_mod_enabled(ModIds.GLOVE, false)
		ModManager.save_mods()
	#endregion

	#region 6 控制台已交棒：那里不再有「模组 / 联机」
	## 界面搬到本页面之后，`ModManager` / 模组都不再往控制台挂条目 ——
	## 留个**反断言**：哪天又有人把模组的开关挂回控制台，这里会立刻叫。
	var registry := Global.console_registry if Global != null else null
	if registry == null:
		a.log("[MODPAGE] 拿不到控制台注册表（Global 不可用），跳过反断言")
	else:
		var leftover := registry.get_entries("模组")
		leftover.append_array(registry.get_entries("联机"))
		a.log("[MODPAGE] 控制台里的模组 / 联机条目=%d（应为 0）" % leftover.size())
		_check(a, "控制台里已经没有「模组」「联机」这两栏", leftover.is_empty())
	#endregion

	#region 7 依赖列表（详情末尾）
	## 模组可在 `ModBase.get_mod_dependencies()` 里声明依赖哪些模组：
	##   · 详情**末尾**有一块「依赖的模组」，每个依赖一个按钮，点了跳过去；
	##   · 打开本模组时依赖被一并打开（`ModManager.set_mod_enabled()` 里递归补开）。
	## 现役模组里只有**生态版**声明了依赖（依赖「紫卡直接种植」，2026-10-17 加）——
	## 先核对该真实声明（管理器过滤过的：未登记 id / 依赖自己会被剔除），
	## 再给手套**临时**换一份「依赖锤子 + 一个未登记 id」的脚本把这三端都跑一遍，
	## 跑完还原脚本与开关，不把后面的探针带歪。
	_click(_find_list_button(page, "手套"))
	var dep_box := _dependency_box(page)
	_check(a, "详情末尾有「依赖的模组」那一块", dep_box != null)
	if dep_box != null:
		var dep_lines := _label_texts(dep_box)
		a.log("[MODPAGE] 依赖块=%s" % str(dep_lines))
		_check(a, "没声明依赖时写一句（不依赖其它模组）", dep_lines.any(func(t: String) -> bool:
			return t.contains("不依赖其它模组")))
	var others_with_deps: Array = []
	for mod_id in ModManager.all_mods:
		if mod_id == ModIds.ECO:
			continue
		if not ModManager.get_mod_dependencies(mod_id).is_empty():
			others_with_deps.append(str(mod_id))
	var eco_deps := ModManager.get_mod_dependencies(ModIds.ECO)
	a.log("[MODPAGE] 生态版声明的依赖=%s" % str(eco_deps))
	_check(a, "只有生态版声明依赖，且依赖正是「紫卡直接种植」",
		others_with_deps.is_empty()
		and eco_deps.size() == 1 and eco_deps[0] == ModIds.PURPLE_DIRECT_PLANT)

	## 锤子可能被上一次探针 / 玩家留在开着状态：先归零（下面「自动补开」那一端要按未启用起跑）
	if ModManager.is_mod_enabled(ModIds.HAMMER):
		ModManager.set_mod_enabled(ModIds.HAMMER, false)
		ModManager.save_mods()

	## 给手套临时换一份脚本：声明依赖**锤子** + 一个未登记的 id（后者应被管理器剔除）。
	## id 用字面量写（这份脚本是探针临场造的，引用不到本文件的常量）——
	## 下面的断言拿 `ModIds.*` 比，写歪了会当场 FAIL，不会静默混过去。
	var glove_mod = ModManager.get_mod(ModIds.GLOVE)
	var glove_script: Script = glove_mod.get_script()
	var dep_script := GDScript.new()
	dep_script.source_code = """
extends "res://mods_builtin/mod_base.gd"

func get_mod_id() -> StringName:
	return &"glove"

func get_mod_dependencies() -> Array[StringName]:
	return [&"no_such_mod", &"hammer"]
"""
	var reload_err := dep_script.reload()
	_check(a, "临时依赖脚本能编译", reload_err == OK)
	if reload_err == OK and glove_mod != null:
		glove_mod.set_script(dep_script)
		var glove_deps := ModManager.get_mod_dependencies(ModIds.GLOVE)
		a.log("[MODPAGE] 手套声明的依赖（未登记的已剔除）=%s" % str(glove_deps))
		_check(a, "未登记的依赖 id 被剔除，只剩锤子",
			glove_deps.size() == 1 and glove_deps[0] == ModIds.HAMMER)
		## 页面是换脚本之前建的：重建一次，依赖块才按新声明长出来
		page.build_mod_page()
		var dep_button: Button = null
		for button in _buttons_in(_dependency_box(page)):
			if button.text.contains("锤子"):
				dep_button = button
		_check(a, "依赖块里列出锤子（带开关状态）", dep_button != null)
		if dep_button != null:
			_check(a, "依赖按钮上带着锤子的开关状态（未启用）", dep_button.text.contains("未启用"))
			dep_button.pressed.emit()
			_check(a, "点依赖按钮跳转到锤子的详情", page._selected_mod_id == ModIds.HAMMER)
			var hammer_name: String = ModManager.get_mod(ModIds.HAMMER).get_mod_name()
			var detail_title := page.detail_box.get_child(0) as Label
			_check(a, "跳过去后详情标题就是锤子", detail_title != null and detail_title.text == hammer_name)
		## 自动补开：打开手套 → 锤子被一并打开（列表状态与依赖按钮上的状态都跟着变）
		## ⚠️ 这里不能再按名字点列表按钮：换了临时脚本后手套的显示名变成 "glove"
		## （临时脚本没重写 get_mod_name()）—— 按 id 直接选中，与页面跳转同一条路
		page._selected_mod_id = ModIds.GLOVE
		page.build_mod_page()
		ModManager.set_mod_enabled(ModIds.GLOVE, true)
		_check(a, "打开手套时依赖的锤子被一并打开", ModManager.is_mod_enabled(ModIds.HAMMER))
		page.build_mod_page()
		## 「已启用」是「未启用」的子串：断言要带括号写全，不然两端都算过
		_check(a, "依赖按钮上的状态跟着变成已启用", _buttons_in(_dependency_box(page)).any(
			func(b: Button) -> bool: return b.text.contains("锤子") and b.text.contains("（已启用）")))
		## 还原：脚本换回去 → 两个模组都关掉 → 存档照旧 → 页面按还原后的样子重建
		glove_mod.set_script(glove_script)
		ModManager.set_mod_enabled(ModIds.GLOVE, false)
		ModManager.set_mod_enabled(ModIds.HAMMER, false)
		ModManager.save_mods()
		page.build_mod_page()
		_check(a, "还原脚本后又回到「不依赖其它模组」", _label_texts(_dependency_box(page)).any(
			func(t: String) -> bool: return t.contains("不依赖其它模组")))
		## 真实声明也走同一套渲染：选中生态版，依赖块里应列出「紫卡直接种植」（带开关状态）——
		## 顺带盯住 id 有没有写歪（写歪了管理器会剔除，按钮上就变成「模组不存在」）
		page._selected_mod_id = ModIds.ECO
		page.build_mod_page()
		var eco_dep_button: Button = null
		for button in _buttons_in(_dependency_box(page)):
			if button.text.contains("紫卡直接种植"):
				eco_dep_button = button
		_check(a, "生态版的依赖块列出「紫卡直接种植」", eco_dep_button != null)
		#endregion

	page.queue_free()
	_finish(a)


## 收尾：打一行机器可读汇总再退出
func _finish(a) -> void:
	a.log("")
	a.log("[MODPAGE] result=%s failed=%d" % ["FAIL" if _failed > 0 else "PASS", _failed])
	a.quit_game()


#region 取控件
## 模组存档文件的路径（`user://<用户名>/mod_config.ini`；没有登录用户 = 空串）
func _mod_save_path() -> String:
	if Global == null or Global.user_manager == null or Global.user_manager.curr_user_name.is_empty():
		return ""
	return "user://%s/%s" % [Global.user_manager.curr_user_name, MOD_SAVE_FILE]


func _list_buttons(page: ModPage) -> Array[Button]:
	var result: Array[Button] = []
	if page == null or page.list_box == null:
		return result
	for node in page.list_box.get_children():
		if node is Button:
			result.append(node as Button)
	return result


func _button_texts(buttons: Array) -> Array[String]:
	var result: Array[String] = []
	for button in buttons:
		if button is Button:
			result.append((button as Button).text)
	return result


## 控制台入口页上的翻页导航按钮（面板自己造的，带 `NAV_META`）
func _find_nav_button(console: CanvasLayerConsole, text: String) -> Button:
	if console == null:
		return null
	for node in console.find_children("*", "Button", true, false):
		if node.text == text and node.get_meta(CanvasLayerConsole.NAV_META, false):
			return node
	return null


## 按模组名在列表里找那个按钮（页面是靠名字显示的，探针也只能按名字认）
func _find_list_button(page: ModPage, mod_name: String) -> Button:
	for button in _list_buttons(page):
		if button.text.contains(mod_name):
			return button
	return null


## 详情里「模组自己那一块」= 详情区里排在「依赖的模组」那一块**前面**的那个子节点
## （页面造的是 名称 / 开关 / 说明，模组没启用时中间还会插一句「先启用上面的开关」的提示，
##  末尾恒有页面自己造的依赖列表 `DependencyBox` —— 取它前一个才稳）
func _mod_control(page: ModPage) -> Control:
	if page == null or page.detail_box == null:
		return null
	var children := page.detail_box.get_children()
	for i in children.size():
		if children[i].name == DEPENDENCY_BOX_NAME and i > 0:
			return children[i - 1] as Control
	## 没有依赖块（不该发生）：退回最后一个
	if children.is_empty():
		return null
	return children[-1] as Control


## 详情末尾那块「依赖的模组」（页面自己造的，名字固定）
func _dependency_box(page: ModPage) -> Node:
	if page == null or page.detail_box == null:
		return null
	return page.detail_box.get_node_or_null(NodePath(DEPENDENCY_BOX_NAME))


## 一棵控件树里所有按钮（依赖块里按文字认那个依赖按钮）
func _buttons_in(root: Node) -> Array[Button]:
	var result: Array[Button] = []
	if root is Button:
		result.append(root as Button)
	for child in root.get_children():
		result.append_array(_buttons_in(child))
	return result


## 一棵控件树里所有**能交互**的控件（按钮 / 勾选框 / 输入框 / 滑条）
func _collect_interactive(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	if root is Control and (root is Button or root is LineEdit or root is TextEdit or root is Range):
		result.append(root as Control)
	for child in root.get_children():
		result.append_array(_collect_interactive(child))
	return result


## 这个控件现在是「能操作」的吗（与 `ModPage._set_controls_enabled()` 的口径一致）
func _is_enabled(control: Control) -> bool:
	if control is Button:
		return not control.disabled
	if control is LineEdit or control is TextEdit:
		return control.editable
	if control is Range:
		return control.editable
	return true


func _toggle_button(page: ModPage) -> Button:
	if page == null or page.detail_box == null or page.detail_box.get_child_count() < 2:
		return null
	return page.detail_box.get_child(1) as Button


func _label_texts(root_node: Node) -> Array[String]:
	var result: Array[String] = []
	for node in root_node.get_children():
		if node is Label:
			result.append((node as Label).text)
	return result


func _click(button: Button) -> void:
	if button != null:
		button.pressed.emit()
#endregion


func _check(a, desc: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	a.log("[MODPAGE] %s %s" % ["OK  " if ok else "FAIL", desc])
