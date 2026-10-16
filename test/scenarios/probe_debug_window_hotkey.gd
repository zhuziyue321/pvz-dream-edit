extends RefCounted
## 探针：调试窗口（Ctrl+Q）热键链路诊断
##
## 回答四件事：
##   1. `Global.debug_window` 有没有被创建、在不在树里、`_unhandled_key_input` 有没有被启用；
##   2. 合成一个真实的 Ctrl+Q（走 `Input.parse_input_event`）之后，内部 Panel 会不会变可见；
##   3. 它**真的画到屏幕上**了吗（几何矩形 + 截一张图）；
##   4. 再按一次会不会收起来（toggle）。
##
## 注意：跑批会把 user 目录重定向到干净临时目录，`config.ini` 不存在 ——
## 所以这里先手动把「调试模式」置 true，否则走的是「只打提示不弹窗」的分支。
##
## 截图落在 `user://debug_win_shot.png`（= 临时重定向目录下的 app_userdata/<项目>/）。

const DEBUG_MODE_KEY := "debug_mode"
const SHOT_PATH := "user://debug_win_shot.png"


func run(a) -> void:
	a.log("=== 调试窗口热键诊断 ===")
	await a.wait(1.0)

	Global.config_service.set_console_value(DEBUG_MODE_KEY, true)
	a.log("STEP1 debug_mode=" + str(Global.is_debug_mode_on()))

	var dw: DebugWindow = Global.debug_window
	a.log("STEP2 Global.debug_window=" + str(dw))
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
	await RenderingServer.frame_post_draw
	var vp: Viewport = (Engine.get_main_loop() as SceneTree).root
	var img: Image = vp.get_texture().get_image()
	var err := img.save_png(SHOT_PATH)
	a.log("STEP5 截图 err=" + str(err) + " 尺寸=" + str(img.get_size()) + " → " + SHOT_PATH)

	await _press_ctrl_q(a)
	a.log("STEP6 第二次 Ctrl+Q → win_visible=" + str(dw._window.visible))

	await _press_ctrl_q(a)
	a.log("STEP7 第三次 Ctrl+Q → win_visible=" + str(dw._window.visible))

	if dw._window.visible:
		a.log("[DW] result=PASS 合成 Ctrl+Q 能开能关")
	else:
		a.log("[DW] result=FAIL 第三次 Ctrl+Q 之后仍没弹出来")
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
