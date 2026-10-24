extends RefCounted
## 探针：原版「新植物领奖屏」+ 结算线战利品**不过期**
##
## 覆盖：
##   1. 实机：进 1-4，触发结算线掉一个**新植物种子包**（豌豆射手）
##   2. 实机：结算线上的战利品**不会自己消失**（原版口径：关卡奖励不自动过期）
##   3. 实机：点开 -> 白屏收尾表演 -> 弹出**领奖屏**（标题 / 植物名 / 植物说明 / 继续按钮）
##   4. 实机：点「继续」-> 关卡才切走（领奖屏是结算之后、切场景之前的一步）
## 机器可读汇总：最后一行 [AWARDSCREEN] result=PASS|FAIL failed=<n>

const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_01_04 := "res://src/levels/mode_adventure/adventure_01_04.gd"
const PAGE_01 := 0
const ID_01_04 := "0004"
const DAVE_CLICK_POS := Vector2(400, 300)
const DROP_POS := Vector2(500, 300)
## 本次掉的战利品：种子包类 = 「拿到一株新植物」
const LOOT_NAME := "peashooter_seed_packet"
## 期望显示的植物名（与 data/almanac/almanac_data.json 一致）
const EXPECT_PLANT_NAME := "豌豆射手"
const MAX_WAIT := 20.0

var _failed := 0
## 探针流程有没有跑到最后（中途报错会让协程直接停掉，_finish 仍会执行，没这道兜底就会假 PASS）
var _reached_end := false


func run(a) -> void:
	a.log("")
	a.log("========== 探针 原版新植物领奖屏 + 战利品不过期 ==========")
	await a.wait(2.0)
	await _run_level(a)
	_finish(a)


#region 实机
func _run_level(a) -> void:
	a.log("")
	a.log("--- 1. 实机 1-4（首次通关，掉新植物种子包）---")
	var para: ResourceLevelData = (load(LEVEL_01_04) as GDScript).new()
	if para == null:
		_check(a, "（前置）1-4 关卡资源可加载", false, LEVEL_01_04)
		return
	_mark_cleared(3)
	Global.game_para = para
	para.set_choose_level(ADV, PAGE_01, ID_01_04)
	a.log("[场景] 进入 1-4（%s）" % para.save_game_name)
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))

	if not await _wait_main_game(a, 90.0):
		_check(a, "1-4 进入 MAIN_GAME", false, "超时，阶段=%s" % str(_progress_name()))
		return
	_check(a, "1-4 进入 MAIN_GAME", true)

	var cfg := Global.config_service
	if "auto_collect_coin" in cfg:
		cfg.auto_collect_coin = false

	## 种子包掉在**种子包自己的容器**里（不是花园礼包那个，见 DIM_SeedPacket）
	var parent := GameContext.curr_main_game.drop_item_manager.dim_seed_packet.all_drop_seed_packet_parent
	_check(a, "（前置）掉落容器已就绪", parent != null)
	if parent == null:
		return

	a.log("触发本关结算线 gain(%s) @ %s" % [LOOT_NAME, str(DROP_POS)])
	GameContext.curr_main_game.reward_manager.gain(LOOT_NAME, DROP_POS)

	var drop := await _wait_drop(a, parent, MAX_WAIT)
	_check(a, "结算线掉出了种子包", drop != null, str(drop))
	if drop == null:
		return
	_check(a, "掉落物被标记为「本关结算线」上的掉落", drop.is_level_complete_drop)
	## 原版：关卡奖励不自动过期（Coin::IsLevelAward 的东西不走 mDisappearCounter）
	_check(a, "结算线战利品不会自己消失（存在时长 0）",
		is_instance_valid(drop) and drop.auto_free_time <= 0.0,
		"存在时长 %s" % str(drop.auto_free_time))
	await a.wait(2.0)
	_check(a, "等了两秒它还在场上", is_instance_valid(drop) and not drop.is_queued_for_deletion())

	a.log("")
	a.log("--- 2. 点开 -> 白屏 -> 领奖屏 ---")
	var screen_pos := _to_screen(drop.global_position)
	await a.click(screen_pos.x, screen_pos.y)
	if not await _wait_opened(a, drop, 3.0):
		_check(a, "点开掉落物", false)
		return
	_check(a, "点开掉落物", true)

	var award := await _wait_award_screen(a, MAX_WAIT)
	_check(a, "白屏之后弹出了领奖屏", award != null, str(award))
	if award == null:
		return
	_check(a, "领奖屏标题是「新植物」", award.title_label.text == "新植物", award.title_label.text)
	_check(a, "领奖屏显示的是新植物（%s）" % EXPECT_PLANT_NAME,
		award.plant_name_label.text == EXPECT_PLANT_NAME, award.plant_name_label.text)
	_check(a, "领奖屏有植物说明", not award.description_label.text.is_empty(),
		award.description_label.text)
	_check(a, "领奖屏有「继续」按钮", award.continue_button != null)
	## 截一张图（**开窗口跑时**才有内容，无头模式下是空图）
	_screenshot(a, "award_screen")

	a.log("")
	a.log("--- 3. 点「继续」-> 关卡切走 ---")
	var btn_screen := AutopilotProbe.screen_center_of(award.continue_button)
	await a.click(btn_screen.x, btn_screen.y)
	var tree := Engine.get_main_loop() as SceneTree
	var waited := 0.0
	var scene_switched := false
	while waited < 10.0:
		if tree.current_scene != null and not _is_main_game(tree.current_scene):
			scene_switched = true
			break
		await a.wait(0.25)
		waited += 0.25
	_check(a, "点「继续」之后关卡才切走", scene_switched, str(tree.current_scene))
	_reached_end = true
#endregion


#region 观测
func _wait_drop(a, parent: Node, timeout: float) -> SeedPacket:
	var waited := 0.0
	while waited < timeout:
		for c in parent.get_children():
			if c is SeedPacket:
				return c as SeedPacket
		await a.wait(0.25)
		waited += 0.25
	return null


func _wait_opened(a, drop: Node2D, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if drop.is_opened:
			return true
		await a.wait(0.2)
		waited += 0.2
	return drop.is_opened


## 领奖屏：主游戏底下挂着的那一层
func _wait_award_screen(a, timeout: float) -> AwardScreen:
	var waited := 0.0
	while waited < timeout:
		var found := _find_award_screen()
		if found != null:
			## 等淡入跑完（原版 180 帧 = 3 秒）再断言内容 / 截图
			await a.wait(3.4)
			return found
		await a.wait(0.25)
		waited += 0.25
	return null


func _find_award_screen() -> AwardScreen:
	var mg := GameContext.curr_main_game
	if mg == null:
		return null
	for c in mg.get_children():
		if c is AwardScreen:
			return c as AwardScreen
	return null


## 把世界坐标换算成屏幕坐标（关卡里有 Camera2D，画布有偏移）
func _to_screen(world_pos: Vector2) -> Vector2:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return world_pos
	return tree.root.get_canvas_transform() * world_pos


func _is_main_game(scene: Node) -> bool:
	return scene.name.to_lower().begins_with("maingame")


## 截一张当前画面（**开窗口跑时**才有内容；无头模式下是空图，存了也没用）
func _screenshot(a, tag: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var tex := tree.root.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		return
	var path := "user://autopilot_reports/shot_%s.png" % tag
	var err := img.save_png(path)
	if err != OK:
		return
	a.log("  [截图] " + ProjectSettings.globalize_path(path))
#endregion


#region 工具
## 把通关记录写成「第 1 关 ~ 第 max_level 关全部通关」
func _mark_cleared(max_level: int) -> void:
	var state := Global.global_game_state
	state.curr_all_level_state_data = {}
	for i in range(1, max_level + 1):
		state.curr_all_level_state_data["%d_0_%04d" % [ADV, i]] = {"IsSuccess": true}


func _progress_name() -> String:
	if GameContext.curr_main_game == null:
		return "main_game=null"
	return str(GameContext.curr_main_game.main_game_progress)


## 等进 MAIN_GAME：中途出现戴夫就逐句点完，停在选卡 / 准备阶段就替玩家点「开始游戏」
func _wait_main_game(a, timeout: float) -> bool:
	var started := false
	var waited := 0.0
	while waited < timeout:
		if GameContext.curr_main_game == null:
			await a.wait(0.5)
			waited += 0.5
			continue
		if _find_dave() != null:
			await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
			await a.wait(0.4)
			waited += 0.4
			continue
		if GameContext.curr_main_game.is_timeline_waiting_choose_card and not started:
			a.log("  点「开始游戏」（当前阶段=%d）" % GameContext.curr_main_game.main_game_progress)
			started = true
			GameContext.curr_main_game.main_game_start()
			await a.wait(1.5)
			waited += 1.5
			continue
		if GameContext.curr_main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


func _find_dave() -> CrazyDave:
	var mg = GameContext.curr_main_game
	if mg == null:
		return null
	for child in mg.canvas_layer_ui.get_children():
		if child is CrazyDave:
			return child as CrazyDave
	return null
#endregion


#region 断言与收尾
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	## 流程中途报错的话协程会直接停掉，这里补一道「有没有跑到最后」的兜底，别假 PASS
	if not _reached_end:
		_failed += 1
		a.log("  [NG] 探针流程没跑完（中途报错，看上面的 stderr）")
	a.log("")
	a.log("[AWARDSCREEN] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
