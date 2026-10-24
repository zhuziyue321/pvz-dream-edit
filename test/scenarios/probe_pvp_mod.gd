extends RefCounted

## 探针 多人游戏(PVP)模组：木牌入口 → 多人游戏选关界面（页里没有任何对局）
##
## 三段：
##   1. 模组开着时：注册表槽位 `ChooseLevelPvp` 注入的是多人游戏选关界面
##   2. 主菜单木牌上的「MULTIPLAYER」牌：常态 / 按下贴图都换成了多人版，按下能进那一页
##   3. 那一页：标题是「多 人 游 戏」，**页里一个关卡都没有**（对战逻辑还没做）
##
## 无头可跑：`powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_pvp_mod`

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 多人游戏(PVP)模组 ==========")
	await a.wait_stable("/root/StartMenu", 8.0)
	await a.wait(1.0)

	var mode := MainSceneRegistry.MainScenes.ChooseLevelPvp
	var map: Dictionary = Global.main_scene_registry.MainScenesMap
	var root := (Engine.get_main_loop() as SceneTree).root

	## ---- 模组装上：注册表槽位被注入 ----
	## 模组默认开着（工程默认 mod_config.tres 里含 &"pvp"），但玩家存档可能把它关了，
	## 所以这里显式打开一遍（写进该用户的模组存档）
	ModManager.set_mod_enabled(ModIds.PVP, true)
	await a.wait(0.5)
	var scene_path := str(map.get(mode, ""))
	_check(a, "模组开着时槽位 ChooseLevelPvp 注入的是多人游戏选关界面",
		scene_path.ends_with("pvp_choose_level.tscn"), scene_path)

	## ---- 木牌上的「MULTIPLAYER」牌 ----
	var start_menu := root.get_node_or_null("StartMenu")
	_check(a, "主菜单已加载", start_menu != null)
	if start_menu == null:
		_finish(a)
		return

	var sign_btn := start_menu.get_node_or_null("WoodSign/ButtonMultiplayer") as TextureButton
	_check(a, "木牌上有「MULTIPLAYER」牌", sign_btn != null)
	if sign_btn == null:
		_finish(a)
		return

	var normal_tex := sign_btn.texture_normal
	_check(a, "牌的常态贴图是多人游戏那张（SelectorScreen_WoodSign3.png）",
		normal_tex != null and normal_tex.resource_path.ends_with("SelectorScreen_WoodSign3.png"),
		str(normal_tex))
	var press_tex := sign_btn.texture_pressed
	_check(a, "牌的按下贴图是多人游戏那张（SelectorScreen_WoodSign3_press.png）",
		press_tex != null and press_tex.resource_path.ends_with("SelectorScreen_WoodSign3_press.png"),
		str(press_tex))
	## 换贴图前那块牌是 TextureRect：它的最小尺寸就是贴图尺寸（279x83），
	## 所以牌面本来就是按贴图原大小画的（编辑器里存的 92x40 偏移运行时会被撑大）
	_check(a, "牌的尺寸没动（约 279x83，与换贴图前那张 TextureRect 同一口径）",
		absf(sign_btn.size.x - 279.0) < 1.0 and absf(sign_btn.size.y - 83.0) < 1.0,
		"实际=" + str(sign_btn.size))

	## ---- 按下那张牌 ⇒ 进多人游戏选关界面 ----
	sign_btn.emit_signal("pressed")
	await a.wait(2.0)

	var pvp_scene = root.get_node_or_null("ChooseLevel")
	_check(a, "按下木牌进了多人游戏选关界面", pvp_scene != null)
	if pvp_scene != null:
		_check(a, "那一页的 game_mode 就是多人游戏槽位",
			int(pvp_scene.get("game_mode")) == int(mode), str(pvp_scene.get("game_mode")))
		var title := pvp_scene.get_node_or_null("Label") as Label
		_check(a, "标题写着「多 人 游 戏」",
			title != null and title.text == "多 人 游 戏",
			"" if title == null else title.text)
		## 页里一个关卡都没有：网格里不该有任何一个关卡按钮
		var level_buttons := 0
		var grid := pvp_scene.get_node_or_null("AllPage/GridContainer")
		if grid != null:
			for child in grid.get_children():
				if child is ChooseLevelButton:
					level_buttons += 1
		_check(a, "页里没有任何关卡按钮", level_buttons == 0, "数到 %d 个" % level_buttons)
		_check(a, "能返回主菜单（复用本体选关页基类）", pvp_scene.has_method("back_start_menu"))

	_finish(a)


func _check(a, desc: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + desc)
	else:
		_failed += 1
		a.log("  [NG] " + desc + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[PVPMOD] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
