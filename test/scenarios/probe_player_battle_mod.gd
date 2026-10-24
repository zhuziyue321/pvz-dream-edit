extends RefCounted

## 探针 玩家对战模组：木牌入口 → 玩家对战选关界面（页里有一关「玩家对战：白天」）
##
## 五段：
##   1. 模组**关着**时：木牌上那块「MULTIPLAYER」牌不显示（没开模组就没有这个入口）
##   2. 模组**开着**时：牌出现了，且注册表槽位 `ChooseLevelPlayerBattle` 注入的是玩家对战选关界面
##   3. 那块牌的常态 / 按下贴图都是多人版，按下能进那一页
##   4. 那一页：标题是「玩 家 对 战」，页里挂着**一个**对局条目「玩家对战：白天」
##   5. 点那一关 ⇒ 进白天的空关卡（草坪上没有僵尸），退回主菜单也没崩
##
## 无头可跑：`powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_player_battle_mod`

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 玩家对战模组 ==========")
	await a.wait_stable("/root/StartMenu", 8.0)
	await a.wait(1.0)

	var mode := MainSceneRegistry.MainScenes.ChooseLevelPlayerBattle
	var map: Dictionary = Global.main_scene_registry.MainScenesMap
	var root := (Engine.get_main_loop() as SceneTree).root

	var start_menu := root.get_node_or_null("StartMenu")
	_check(a, "主菜单已加载", start_menu != null)
	if start_menu == null:
		_finish(a)
		return

	var sign_btn := start_menu.get_node_or_null("WoodSign/ButtonMultiplayer") as TextureButton
	_check(a, "木牌上有「MULTIPLAYER」牌这个节点", sign_btn != null)
	if sign_btn == null:
		_finish(a)
		return

	## ---- 模组关着时：那块牌不该显示 ----
	## （模组默认开着（工程默认 mod_config.tres 里含 &"player_battle"），但玩家存档可能把它关了，
	##   所以这里先显式关一遍、再显式开一遍，两种状态都看一眼）
	ModManager.set_mod_enabled(ModIds.PLAYER_BATTLE, false)
	await a.wait(0.5)
	_check(a, "模组关着时木牌上那块「MULTIPLAYER」牌不显示", not sign_btn.visible)

	## ---- 模组装上：牌出现 + 注册表槽位被注入 ----
	ModManager.set_mod_enabled(ModIds.PLAYER_BATTLE, true)
	await a.wait(0.5)
	_check(a, "模组打开后那块牌出现了", sign_btn.visible)
	var scene_path := str(map.get(mode, ""))
	_check(a, "模组开着时槽位 ChooseLevelPlayerBattle 注入的是玩家对战选关界面",
		scene_path.ends_with("player_battle_choose_level.tscn"), scene_path)

	## ---- 木牌上的「MULTIPLAYER」牌 ----
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

	## ---- 按下那张牌 ⇒ 进玩家对战选关界面 ----
	sign_btn.emit_signal("pressed")
	await a.wait(2.0)

	var page = root.get_node_or_null("ChooseLevel")
	_check(a, "按下木牌进了玩家对战选关界面", page != null)
	if page == null:
		_finish(a)
		return
	_check(a, "那一页的 game_mode 就是玩家对战槽位",
		int(page.get("game_mode")) == int(mode), str(page.get("game_mode")))
	var title := page.get_node_or_null("Label") as Label
	_check(a, "标题写着「玩 家 对 战」",
		title != null and title.text == "玩 家 对 战",
		"" if title == null else title.text)

	## ---- 页里的对局条目 ----
	var grid := page.get_node_or_null("AllPage/GridContainer")
	var buttons: Array = []
	if grid != null:
		for child in grid.get_children():
			if child is ChooseLevelButton:
				buttons.append(child)
	_check(a, "页里只有一个对局条目", buttons.size() == 1, "数到 %d 个" % buttons.size())
	if buttons.size() != 1:
		_finish(a)
		return
	var btn: ChooseLevelButton = buttons[0]
	var btn_label := btn.get_node_or_null("TextureButton/Label") as Label
	_check(a, "那个条目写着「玩家对战：白天」",
		btn_label != null and btn_label.text == "玩家对战：白天",
		"" if btn_label == null else btn_label.text)
	_check(a, "条目挂的是本模组自己的关卡脚本",
		btn.level_script != null and btn.level_script.resource_path.ends_with("player_battle_day.gd"),
		"" if btn.level_script == null else btn.level_script.resource_path)
	_check(a, "关卡存档名是 106_0_0001（玩家对战 + 第 0 页 + 第 1 关）",
		btn.curr_level_data_game_para != null \
			and btn.curr_level_data_game_para.save_game_name == "106_0_0001",
		"" if btn.curr_level_data_game_para == null else btn.curr_level_data_game_para.save_game_name)

	## ---- 点那一关 ⇒ 进白天的空关卡 ----
	btn.get_node("TextureButton").emit_signal("pressed")
	var entered: bool = await a.wait_scene("main_game", 20.0)
	_check(a, "点了那一关进了主游戏", entered)
	var mg = await _wait_main_game(a, 10.0)
	_check(a, "主游戏已起来", mg != null and is_instance_valid(mg))
	if mg != null and is_instance_valid(mg):
		_check(a, "这一局的关卡数据就是那个空关卡",
			mg.game_para != null and mg.game_para.save_game_name == "106_0_0001",
			"" if mg.game_para == null else mg.game_para.save_game_name)
		_check(a, "这一关不出怪（monster_mode = Null）",
			mg.game_para != null and mg.game_para.monster_mode == ConstLevelData.E_MonsterMode.Null,
			"" if mg.game_para == null else str(mg.game_para.monster_mode))
		var znum := 0
		if mg.zombie_manager != null:
			znum = mg.zombie_manager.all_zombies_1d.size()
		_check(a, "草坪上没有僵尸", znum == 0, "场上 %d 只" % znum)

	## ---- 退回主菜单（空关卡没有结束条件，玩家只能自己退出）----
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.StartMenu))
	await a.wait(3.0)
	_check(a, "退回主菜单", root.get_node_or_null("StartMenu") != null)
	_check(a, "退出后主游戏已释放", not is_instance_valid(GameContext.curr_main_game))

	_finish(a)


## 等主游戏起来（场景切过去之后管理器还要一会儿才建好）
func _wait_main_game(a, timeout: float):
	var waited := 0.0
	while waited < timeout:
		var mg = GameContext.curr_main_game
		if mg != null and is_instance_valid(mg):
			return mg
		await a.wait(0.25)
		waited += 0.25
	return null


func _check(a, desc: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + desc)
	else:
		_failed += 1
		a.log("  [NG] " + desc + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[PLAYERBATTLE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
