extends RefCounted
## 探针：调试窗口（Ctrl+Q）热键链路诊断
##
## 回答四件事：
##   1. 打开**调试模组**之后，`Global/DebugWindow` 有没有被创建、在不在树里、
##      `_unhandled_key_input` 有没有被启用；
##   2. 合成一个真实的 Ctrl+Q（走 `Input.parse_input_event`）之后，内部 Panel 会不会变可见；
##   3. 它**真的画到屏幕上**了吗（几何矩形 + 截一张图）；
##   4. 再按一次会不会收起来（toggle）。
##
## 注意：跑批会把 user 目录重定向到干净临时目录，`mod_config.ini` 不存在 ——
## 调试模组默认关着，所以这里先 `ModManager.set_mod_enabled(ModIds.DEBUG, true)`。
##
## 截图落在 `user://debug_win_shot.png`（= 临时重定向目录下的 app_userdata/<项目>/）。

const SHOT_PATH := "user://debug_win_shot.png"


func run(a) -> void:
	a.log("=== 调试窗口热键诊断 ===")
	await a.wait(1.0)

	a.log("STEP1 打开调试模组")
	if not ModManager.is_mod_enabled(ModIds.DEBUG):
		ModManager.set_mod_enabled(ModIds.DEBUG, true)
	await a.frames(2)
	a.log("STEP1b 模组 enabled=" + str(ModManager.is_mod_enabled(ModIds.DEBUG)))

	var dw = Global.get_node_or_null("DebugWindow")
	a.log("STEP2 Global/DebugWindow=" + str(dw))
	if dw == null:
		a.log("[DW] result=FAIL 窗口从未被创建")
		a.quit_game()
		return

	a.log("STEP3 in_tree=" + str(dw.is_inside_tree())
		+ " process_mode=" + str(dw.process_mode)
		+ " unhandled_key_enabled=" + str(dw.is_processing_unhandled_key_input())
		+ " win_visible=" + str(dw._window.visible)
		+ " layer=" + str(dw.layer)
		+ " action_mapped=" + str(InputMap.has_action("ShortcutKeys_DebugWindow")))

	await _press_ctrl_q(a)
	a.log("STEP4 第一次 Ctrl+Q → win_visible=" + str(dw._window.visible)
		+ " in_tree_visible=" + str(dw._window.is_visible_in_tree())
		+ " rect=" + str(dw._window.get_global_rect()))
	a.log("STEP4b size=" + str(dw._window.size)
		+ " anchor=" + str(Vector4(dw._window.anchor_left, dw._window.anchor_top,
			dw._window.anchor_right, dw._window.anchor_bottom))
		+ " offset=" + str(Vector4(dw._window.offset_left, dw._window.offset_top,
			dw._window.offset_right, dw._window.offset_bottom))
		+ " grow=" + str(Vector2(dw._window.grow_horizontal, dw._window.grow_vertical)))
	a.log("STEP4c min=" + str(dw._window.get_combined_minimum_size())
		+ " viewport=" + str(dw._window.get_viewport().get_visible_rect()))

	await a.frames(2)
	## 无头模式没有渲染帧：`frame_post_draw` 永远不会发，等它会一路等到看门狗超时
	## （本探针原先是「必须带窗口」的，加这个分支后无头也能跑到 result 行）
	if DisplayServer.get_name() == "headless":
		a.log("STEP5 无头模式 → 跳过截图（没有渲染帧）")
	else:
		await RenderingServer.frame_post_draw
		var vp: Viewport = (Engine.get_main_loop() as SceneTree).root
		var img: Image = vp.get_texture().get_image()
		var err := img.save_png(SHOT_PATH)
		a.log("STEP5 截图 err=" + str(err) + " 尺寸=" + str(img.get_size()) + " → " + SHOT_PATH)

	await _press_ctrl_q(a)
	a.log("STEP6 第二次 Ctrl+Q → win_visible=" + str(dw._window.visible))

	await _press_ctrl_q(a)
	a.log("STEP7 第三次 Ctrl+Q → win_visible=" + str(dw._window.visible))

	## 关掉模组 = 窗口连同节点一起消失（模组化的核心语义：关掉就不装载）
	## ⚠️ 先取 visible：下一帧窗口就被 queue_free 了，之后再读 `dw._window` 是访问已释放对象
	var was_visible: bool = dw._window.visible
	ModManager.set_mod_enabled(ModIds.DEBUG, false)
	await a.frames(2)
	var after = Global.get_node_or_null("DebugWindow")
	a.log("STEP8 关掉模组 → Global/DebugWindow=" + str(after)
		+ " trace=" + str(EventBus.is_trace_pushed_events)
		+ " zombie_card=" + str(Global.global_game_state.is_zombie_card_enabled()))

	if was_visible and after == null:
		a.log("[DW] result=PASS 合成 Ctrl+Q 能开能关；关掉模组后窗口被释放")
	else:
		a.log("[DW] result=FAIL 第三次 Ctrl+Q 之后仍没弹出来，或关掉模组后窗口还在")
	a.quit_game()


func _press_ctrl_q(a) -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_Q
	down.physical_keycode = KEY_Q
	down.ctrl_pressed = true
	down.pressed = true
	Input.parse_input_event(down)
	await a.frames(6)

	var up := InputEventKey.new()
	up.keycode = KEY_Q
	up.physical_keycode = KEY_Q
	up.ctrl_pressed = true
	up.pressed = false
	Input.parse_input_event(up)
	await a.frames(4)
