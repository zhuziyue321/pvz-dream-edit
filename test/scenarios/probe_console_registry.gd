extends RefCounted
## 探针：控制台的可扩展性（条目注册表 + 面板动态渲染 + 通用键值持久化）
##
## 无头可跑，不写用户存档（只动内存里的值，不调 save_config）。
## 校验：
##   1. 注册表在 Global 上可用，内置 12 条都在
##   2. 分组齐全（自动 / 显示 / 调试）；**没有「模组」那一组** ——
##      模组的列表与开 / 关已经搬到「模组页面」，控制台不再替模组挂开关
##   3. 内置条目真的读写到了 ConfigService（勾一下「开放所有关卡」）
##   4. 运行期登记一条 toggle(button/slider) → 面板立刻多出对应控件 → 值落到通用键值区
##   5. 撤销登记方后，面板上的控件与注册表里的条目一起消失


## 本探针登记临时条目用的标记（跑完按这个整组撤销）
const TEMP_SOURCE := &"probe_console_registry"
## 临时按钮被点到的次数
var _button_clicked := 0


func run(a) -> void:
	var ok := true
	var registry := Global.console_registry
	if registry == null:
		a.log("[CONSOLE] !! Global.console_registry 为空")
		a.finish(true)
		return

	#region 1 / 2 内置条目与分组
	var builtin_count := 0
	for category in [ConsoleBuiltinEntries.CATEGORY_AUTO, ConsoleBuiltinEntries.CATEGORY_DISPLAY,
			ConsoleBuiltinEntries.CATEGORY_DEBUG]:
		builtin_count += registry.get_entries(category).size()
	a.log("[CONSOLE] 内置条目=%d 分组=%s" % [builtin_count, str(registry.get_categories())])
	if builtin_count != 12:
		ok = false
		a.log("[CONSOLE] !! 内置条目数应为 12，实际 %d" % builtin_count)

	## 模组开关已经搬到「模组页面」（主菜单 → 选项 → 控制台 →「模组」）：控制台里不该再留任何模组条目，
	## 模组的名单与详情由 `ModManager.all_mods` + `ModBase.create_detail_control()` 供货
	var leftover_entries := registry.get_entries("模组")
	a.log("[CONSOLE] 控制台里的「模组」条目=%d（应为 0）" % leftover_entries.size())
	if not leftover_entries.is_empty():
		ok = false
		a.log("[CONSOLE] !! 控制台里仍有模组条目：%s" % str(leftover_entries.map(
			func(item) -> String: return str((item as ConsoleEntry).id))))
	var mod_count := ModManager.all_mods.size()
	a.log("[CONSOLE] 模组管理器里的模组=%d" % mod_count)
	if mod_count == 0:
		ok = false
		a.log("[CONSOLE] !! 一个模组都没有，模组页面会空着")
	#endregion

	#region 3 内置条目读写到 ConfigService
	var open_all := registry.get_entry(&"open_all_level")
	if open_all == null:
		ok = false
		a.log("[CONSOLE] !! 找不到内置条目 open_all_level")
	else:
		var before := Global.config_service.open_all_level
		open_all.set_value(not before)
		if Global.config_service.open_all_level == before:
			ok = false
			a.log("[CONSOLE] !! 内置条目写值没有落到 config_service")
		open_all.set_value(before)
	#endregion

	#region 4 运行期登记三种形态
	## 先造面板数一份基线：开着几个模组、还有谁登记了条目，都不该影响本探针 ——
	## 本探针只认「我加的这批带来的增量」（曾经按绝对数量断言，联机模组一开就误报 FAIL）
	var tree := Engine.get_main_loop() as SceneTree
	var panel: CanvasLayerConsole = load("res://src/ui/control_canvas_layer.tscn").instantiate()
	tree.root.add_child(panel)
	panel.build_console_panel()
	var base := _count_controls(panel)
	a.log("[CONSOLE] 基线 勾选框=%d 滑条=%d 按钮=%d" % [
		base["boxes"].size(), base["sliders"].size(), base["buttons"].size()])

	registry.register_entry(ConsoleEntry.create_toggle(&"probe_temp_toggle", "探针开关")
		.set_category("探针")
		.bind_config("probe.toggle", false), TEMP_SOURCE)
	registry.register_entry(ConsoleEntry.create_button(&"probe_temp_button", "探针按钮",
			func() -> void: _button_clicked += 1)
		.set_category("探针"), TEMP_SOURCE)
	registry.register_entry(ConsoleEntry.create_slider(&"probe_temp_slider", "探针滑条", 0.0, 10.0, 1.0)
		.set_category("探针")
		.bind_config("probe.slider", 3.0), TEMP_SOURCE)

	var temp_entries := registry.get_entries("探针")
	a.log("[CONSOLE] 临时条目=%d" % temp_entries.size())
	if temp_entries.size() != 3:
		ok = false
		a.log("[CONSOLE] !! 临时条目应为 3 条，实际 %d" % temp_entries.size())

	var temp_toggle := registry.get_entry(&"probe_temp_toggle")
	temp_toggle.set_value(true)
	if Global.config_service.get_console_value("probe.toggle", false) != true:
		ok = false
		a.log("[CONSOLE] !! bind_config 的值没有落到 ConfigService.console_values")
	#endregion

	#region 5 面板按条目动态渲染（按基线的增量断言）
	panel.build_console_panel()
	var after := _count_controls(panel)
	a.log("[CONSOLE] 登记后 勾选框=%d 滑条=%d 按钮=%d" % [
		after["boxes"].size(), after["sliders"].size(), after["buttons"].size()])
	if after["boxes"].size() != base["boxes"].size() + 1:
		ok = false
		a.log("[CONSOLE] !! 勾选框应比基线多 1，实际多 %d" % [after["boxes"].size() - base["boxes"].size()])
	if after["sliders"].size() != base["sliders"].size() + 1:
		ok = false
		a.log("[CONSOLE] !! 滑条应比基线多 1，实际多 %d" % [after["sliders"].size() - base["sliders"].size()])
	if after["buttons"].size() != base["buttons"].size() + 1:
		ok = false
		a.log("[CONSOLE] !! 按钮应比基线多 1，实际多 %d" % [after["buttons"].size() - base["buttons"].size()])

	var boxes: Array = after["boxes"]
	var buttons: Array = after["buttons"]

	## 勾一下面板上的「探针开关」，值应写回 ConfigService
	for box in boxes:
		if box.text == "探针开关":
			box.button_pressed = true
	if Global.config_service.get_console_value("probe.toggle", false) != true:
		ok = false
		a.log("[CONSOLE] !! 面板勾选没有写回条目")

	## 点一下「探针按钮」，动作应被执行
	for button in buttons:
		if button.text == "探针按钮":
			button.pressed.emit()
	if _button_clicked != 1:
		ok = false
		a.log("[CONSOLE] !! 按钮动作执行次数=%d" % _button_clicked)

	## 拖一下滑条（按行首的名字标签定位到自己那条），值应落进通用键值区
	var temp_slider := _find_slider_by_text(after["sliders"], "探针滑条")
	if temp_slider == null:
		ok = false
		a.log("[CONSOLE] !! 面板上找不到「探针滑条」")
	else:
		temp_slider.value = 7.0
	if Global.config_service.get_console_value("probe.slider", 3.0) != 7.0:
		ok = false
		a.log("[CONSOLE] !! 滑条值=%s" % str(Global.config_service.get_console_value("probe.slider", 3.0)))
	#endregion

	#region 6 撤销登记方：条目与控件一起消失
	registry.unregister_source(TEMP_SOURCE)
	panel.build_console_panel()
	var after_unreg := _count_controls(panel)
	a.log("[CONSOLE] 撤销后 勾选框=%d 滑条=%d 临时条目=%d" % [
		after_unreg["boxes"].size(), after_unreg["sliders"].size(), registry.get_entries("探针").size()])
	if after_unreg["boxes"].size() != base["boxes"].size() or after_unreg["sliders"].size() != base["sliders"].size():
		ok = false
		a.log("[CONSOLE] !! 撤销后面板控件没有回到基线")
	if not registry.get_entries("探针").is_empty():
		ok = false
		a.log("[CONSOLE] !! 撤销后注册表里仍有临时条目")
	#endregion

	panel.queue_free()
	a.log("[CONSOLE] result=%s" % ("PASS" if ok else "FAIL"))
	a.finish(true)


#region 控件统计
## 数一遍面板上的三类控件（给出节点数组，方便后面按文字定位到具体某一条）
##
## 面板上的控件是运行时 add_child 的（owner 为 null），`find_children` 第四个参数必须传 false 才找得到。
## 面板改成翻页之后控件分布在多页上，但 `find_children` 不看 visible，藏起来的那几页照样数得到。
func _count_controls(panel: CanvasLayerConsole) -> Dictionary:
	var boxes := panel.find_children("*", "CheckBox", true, false)
	var sliders := panel.find_children("*", "HSlider", true, false)
	## CheckBox 也是 Button，按类型查会把勾选框一起算进来，这里排除掉；
	## 入口页的分组按钮 / 分组页的「返回」是面板自己造的翻页按钮（带 `NAV_META`），
	## 数量随分组多少变，不跟着条目走，统计「条目带来的控件」时必须跳过。
	var buttons: Array[Node] = []
	for node in panel.find_children("*", "Button", true, false):
		if node is CheckBox:
			continue
		if node.get_meta(CanvasLayerConsole.NAV_META, false):
			continue
		buttons.append(node)
	return {"boxes": boxes, "sliders": sliders, "buttons": buttons}


## 按「行首名字标签」找滑条（滑条自己没有文本，名字在它所在的那一行的第一个子节点上）
func _find_slider_by_text(sliders: Array, name_text: String) -> HSlider:
	for item in sliders:
		var slider := item as HSlider
		if slider == null:
			continue
		var row := slider.get_parent()
		if row == null or row.get_child_count() == 0:
			continue
		var label := row.get_child(0) as Label
		if label != null and label.text == name_text:
			return slider
	return null
#endregion
