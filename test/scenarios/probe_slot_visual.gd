extends RefCounted
## 临时诊断探针：拉霸关三个症状取证（裁剪 / 菜单点不到 / 拉杆）
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Windowed -Scenario probe_slot_visual
## 截图落在 user:// 下（临时重定向目录），stdout 会打出绝对路径

const LEVEL := "res://src/levels/mode_minigame/minigame_03_slot_machine.gd"
const UI_PATH := "res://src/levels/mode_minigame/minigame_03_slot_machine_ui.gd"


func run(a) -> void:
	a.log("========== 诊断：拉霸关视觉三症状 ==========")
	var para: Resource = (load(LEVEL) as GDScript).new()
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)
	var mg = GameContext.curr_main_game
	if mg == null:
		a.log("[NG] 没进主游戏")
		a.quit_game()
		return

	var ui := await _wait_ui(a, mg, 20.0)
	if ui == null:
		a.log("[NG] 没等到拉霸 UI")
		a.quit_game()
		return

	a.log("STEP1 画布原点(非0说明有相机): " + str(a.canvas_origin()))
	a.log("STEP2 UI 根: pos=%s size=%s mouse_filter=%d(0STOP/1PASS/2IGNORE)"
		% [str(ui.position), str(ui.size), ui.mouse_filter])
	a.log("STEP2b viewport visible_rect: " + str(a.get_tree().root.get_visible_rect()))
	_dump_tree(a, ui, 0)

	## 菜单按钮命中探测
	var menu_btn: Node = mg.canvas_layer_ui.get_node_or_null("All_UI/MainGameMenuButton")
	if menu_btn != null:
		a.log("STEP3 菜单按钮: global_rect=%s screen_center=%s"
			% [str(menu_btn.get_global_rect()), str(a.screen_center(menu_btn))])
		await a.probe_hover(a.screen_center(menu_btn).x, a.screen_center(menu_btn).y)
	else:
		a.log("STEP3 菜单按钮没找到")

	## 拉杆热区命中探测
	var handle: Button = ui.get_node_or_null("HandleButton")
	if handle != null:
		var hc: Vector2 = a.screen_center(handle)
		a.log("STEP4 拉杆热区: rect=%s screen_center=%s" % [str(handle.get_global_rect()), str(hc)])
		await a.probe_hover(hc.x, hc.y)

	## 截图：待机一张
	await a.frames(2)
	await _shot(a, "slot_rest.png")

	## 拉一次杆，滚动中截图（看裁剪泄漏），再停稳截一张
	if handle != null:
		await a.press_first("HandleButton")
		await a.wait(0.8)
		await _shot(a, "slot_spinning.png")
		await a.wait(6.0)
		await _shot(a, "slot_stopped.png")

	a.log("[SLOTVIS] done")
	a.quit_game()


func _wait_ui(a, mg, timeout: float) -> Control:
	var waited := 0.0
	while waited < timeout:
		if is_instance_valid(mg) and mg.canvas_layer_ui != null:
			for c in mg.canvas_layer_ui.get_children():
				if is_instance_valid(c) and c.get_script() != null \
					and c.get_script().resource_path == UI_PATH:
					return c as Control
		await a.wait(0.5)
		waited += 0.5
	return null


func _dump_tree(a, node: Node, depth: int) -> void:
	var pad := ""
	for _i in range(depth):
		pad += "  "
	var info := "%s%s" % [pad, node.name]
	if node is Control:
		var c := node as Control
		info += " [pos=%s size=%s visible=%s mf=%d]" % [str(c.position), str(c.size), str(c.visible), c.mouse_filter]
		if node is TextureRect:
			var tex: Texture2D = (node as TextureRect).texture
			if tex != null:
				info += " tex=%s %sx%s scale=%s" % [tex.resource_path.get_file(), str(tex.get_width()), str(tex.get_height()), str((node as TextureRect).scale)]
	a.log(info)
	for child in node.get_children():
		_dump_tree(a, child, depth + 1)


func _shot(a, file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var vp: Viewport = (Engine.get_main_loop() as SceneTree).root
	var img: Image = vp.get_texture().get_image()
	var path := "user://" + file_name
	var err := img.save_png(path)
	var abs_path := path.replace("user://", OS.get_user_data_dir() + "/")
	a.log("  截图 %s err=%d → %s" % [file_name, err, abs_path])
