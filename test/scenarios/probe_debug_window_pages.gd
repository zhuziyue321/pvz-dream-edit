extends RefCounted
## 探针：调试窗口的「分页 / 搜索 / 日志 / 反馈 / 调宽」链路
##
## 无头可跑（不截图），user 目录由跑批重定向到临时目录，不动真实存档；
## 只有「加金币」那一下会临时改全局金币，探针会自己还原。
##
## 校验：
##   1. 七页齐全（常用 / 战斗 / 资源 / 开关 / 运行 / 状态 / 日志），最后一页是只读文本框；
##   2. 窗口打开时 **Ctrl+2** 能切到第 2 页（走 `_input`，不会漏给卡槽的数字键）；
##   3. 搜索框按文字过滤会真的藏行，清空后全部回来；
##   4. `Log.info()` 写一行后，日志页能读到（`Log` 的内存环形缓冲）；
##   5. 点「加金币」之后底部反馈条出现文字（动作成功 / 失败都有反馈）；
##   6. 拖宽接口把面板宽度改到 520，复位后回默认 460。
##
## 注意：跑批会把 user 目录重定向到干净临时目录，`mod_config.ini` 不存在 ——
## 调试模组默认关着，所以这里先 `ModManager.set_mod_enabled(ModIds.DEBUG, true)`。

## 同目录外的模组脚本（模组脚本不写 `class_name`，一律 preload）
const DebugWindowEntries := preload("res://mods_builtin/debug/debug_window_entries.gd")
const DebugWindowScript := preload("res://mods_builtin/debug/debug_window.gd")

## 日志页里要找到的标记
const LOG_MARKER := "PROBE_DEBUG_WINDOW_LOG_MARKER"


func run(a) -> void:
	var ok := true
	a.log("=== 调试窗口分页 / 搜索 / 日志诊断 ===")
	await a.wait(0.5)

	if not ModManager.is_mod_enabled(ModIds.DEBUG):
		ModManager.set_mod_enabled(ModIds.DEBUG, true)
	await a.frames(3)

	var dw = Global.get_node_or_null("DebugWindow")
	if dw == null:
		a.log("[DWP] result=FAIL 窗口从未被创建")
		a.finish(true)
		return

	#region 1 七页齐全
	var categories: Array = DebugWindowEntries.get_categories()
	var page_count: int = dw._pages.size()
	a.log("[DWP] 分组=%s 页数=%d" % [str(categories), page_count])
	if page_count != categories.size() or page_count != 7:
		ok = false
		a.log("[DWP] !! 页数应为 7，实际 %d" % page_count)
	var log_page: Control = dw._pages[page_count - 1]
	var log_view = log_page.get_node_or_null("LogView")
	a.log("[DWP] 日志页文本框=%s" % str(log_view))
	if log_view == null:
		ok = false
		a.log("[DWP] !! 日志页没有 LogView")
	#endregion

	#region 2 窗口打开 + Ctrl+2 切页
	dw.set_window_visible(true)
	await a.frames(2)
	await _press_ctrl_number(a, KEY_2)
	var visible_index: int = dw._get_visible_page_index()
	a.log("[DWP] Ctrl+2 后可见页=%d tab=%d" % [visible_index, dw._tab_bar.current_tab])
	if visible_index != 1 or dw._tab_bar.current_tab != 1:
		ok = false
		a.log("[DWP] !! Ctrl+2 应切到第 2 页（下标 1）")
	#endregion

	#region 3 搜索过滤
	var total: int = DebugWindowEntries.apply_filter("")
	var matched: int = DebugWindowEntries.apply_filter("僵尸")
	var restored: int = DebugWindowEntries.apply_filter("")
	a.log("[DWP] 行数 总=%d 命中「僵尸」=%d 还原=%d" % [total, matched, restored])
	if total <= 0:
		ok = false
		a.log("[DWP] !! 一个条目都没登记")
	if matched <= 0 or matched >= total:
		ok = false
		a.log("[DWP] !! 「僵尸」应只命中一部分行")
	if restored != total:
		ok = false
		a.log("[DWP] !! 清空搜索后没有还原全部行")
	#endregion

	#region 4 日志页
	Log.info(LOG_MARKER)
	dw._show_page(page_count - 1)
	await a.wait(0.6)
	var log_text: String = log_view.text
	a.log("[DWP] 日志页文本长度=%d 含标记=%s" % [log_text.length(), str(LOG_MARKER in log_text)])
	if not LOG_MARKER in log_text:
		ok = false
		a.log("[DWP] !! 日志页没读到刚写的 Log.info")
	#endregion

	#region 5 动作反馈（加金币）
	var coin_before: int = Global.global_game_state.coin_value
	var clicked := _press_button_by_text(dw, "加金币")
	await a.wait(0.5)
	var feedback: String = dw._status_label.text
	a.log("[DWP] 点「加金币」=%s 反馈=%s" % [str(clicked), feedback])
	if not clicked:
		ok = false
		a.log("[DWP] !! 找不到「加金币」按钮")
	elif not "金币" in feedback:
		ok = false
		a.log("[DWP] !! 动作之后底部反馈条没有文字")
	Global.global_game_state.coin_value = coin_before
	#endregion

	#region 6 拖宽 / 复位
	dw._set_panel_width(520.0)
	await a.frames(2)
	var widened: float = dw._window.size.x
	dw._reset_layout()
	await a.frames(2)
	var restored_width: float = dw._window.size.x
	a.log("[DWP] 宽度 拖宽后=%.0f 复位后=%.0f" % [widened, restored_width])
	if not is_equal_approx(widened, 520.0):
		ok = false
		a.log("[DWP] !! 拖宽后宽度应为 520")
	if not is_equal_approx(restored_width, DebugWindowScript.WINDOW_WIDTH):
		ok = false
		a.log("[DWP] !! 复位后应回默认宽度 %.0f" % DebugWindowScript.WINDOW_WIDTH)
	#endregion

	#region 7 关掉模组：窗口与副作用一起撤
	var was_visible: bool = dw._window.visible
	ModManager.set_mod_enabled(ModIds.DEBUG, false)
	await a.frames(3)
	var after = Global.get_node_or_null("DebugWindow")
	a.log("[DWP] 关掉模组 窗口=%s" % str(after))
	if was_visible and after != null:
		ok = false
		a.log("[DWP] !! 关掉模组后窗口还在")
	#endregion

	a.log("[DWP] result=%s" % ("PASS" if ok else "FAIL"))
	a.finish(true)


## 合成 Ctrl+数字（窗口开着时走 `_input` 的切页分支）
func _press_ctrl_number(a, keycode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.ctrl_pressed = true
	down.pressed = true
	Input.parse_input_event(down)
	await a.frames(4)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.ctrl_pressed = true
	up.pressed = false
	Input.parse_input_event(up)
	await a.frames(2)


## 按文字点一个按钮（含子页里藏起来的那些）
func _press_button_by_text(root: Node, text: String) -> bool:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or button is CheckBox or button.text != text:
			continue
		button.pressed.emit()
		return true
	return false
