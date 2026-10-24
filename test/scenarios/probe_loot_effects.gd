extends RefCounted
## 探针：原版「战利品」那套表现（上方弹跳箭头 + 周期闪光 + 拾取时的星星爆裂）
##
## 覆盖：
##   1. 实机：进 1-4 —— 本关首次通关奖励是道具类（铲子），掉的是礼物盒 Present
##   2. 实机：战利品**落地后**上方出现弹跳的黄色箭头（原版 PARTICLE_AWARD_PICKUP_ARROW）
##      · 箭头贴在战利品中心 + (40, -40)（原版礼物盒口径）
##      · 箭头在上下弹跳（原版位置场 0 → 10 → 0，40 帧一个来回）
##   3. 实机：战利品在**周期闪光**（原版 GetFlashingColor：灰度 255 ↔ 55，1.25 秒一个来回）
##   4. 实机：点开后弹一次**星星爆裂**（原版 PARTICLE_STARBURST），箭头随之收起
## 机器可读汇总：最后一行 [LOOTFX] result=PASS|FAIL failed=<n>

const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_01_04 := "res://src/levels/mode_adventure/adventure_01_04.gd"
## 1-4 在选关界面上的位置：第 1 页（0 起 = 0）的第 4 关，关卡编号 0004
const PAGE_01 := 0
const ID_01_04 := "0004"
## 戴夫对话的点击位置（800x600 下的屏幕中心；戴夫的点击面板覆盖全屏，点哪都能推进）
const DAVE_CLICK_POS := Vector2(400, 300)
## 掉落物在世界坐标里的落点（草坪中段）
const DROP_POS := Vector2(500, 300)
## 等掉落物出现 / 等落地 / 等拾取的上限秒数
const MAX_WAIT := 20.0
## 等落地后采样箭头与闪光的秒数
const SAMPLE_TIME := 1.6
## 采样间隔
const SAMPLE_STEP := 0.1

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 原版战利品表现（弹跳箭头 + 周期闪光 + 星星爆裂） ==========")
	## 等主菜单自身初始化完再切场景，否则切场景会撞上「父节点正忙」
	await a.wait(2.0)
	await _run_level(a)
	_finish(a)


#region 实机
## 进 1-4，走真正的结算入口掉出本关奖励，再看它落地后的那套表现
func _run_level(a) -> void:
	a.log("")
	a.log("--- 1. 实机 1-4（首次通关）---")
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

	## 自动收集会把掉落物秒开，探针就没法看它落地后的表现了
	var cfg := Global.config_service
	if "auto_collect_coin" in cfg:
		cfg.auto_collect_coin = false

	var parent := GameContext.curr_main_game.drop_item_manager.dim_garden_plant.all_drop_garden_plant_parent
	_check(a, "（前置）掉落容器已就绪", parent != null)
	if parent == null:
		return

	a.log("触发本关结算线 gain(shovel) @ %s" % str(DROP_POS))
	GameContext.curr_main_game.reward_manager.gain("shovel", DROP_POS)

	var drop := await _wait_drop(a, parent, MAX_WAIT)
	_check(a, "结算线掉出了本关奖励", drop != null, str(drop))
	if drop == null:
		return
	_check(a, "掉落物被标记为「本关结算线」上的掉落", drop.is_level_complete_drop)

	a.log("")
	a.log("--- 2. 落地后的表现（箭头 + 闪光）---")
	## 落地之前不该有箭头（原版是 mHitGround 那一支才挂粒子）
	_check(a, "落地前没有箭头", not _arrow_visible(drop))

	if not await _wait_arrow(a, drop, MAX_WAIT):
		_check(a, "落地后出现了弹跳箭头", false, "等了 %.0f 秒还没出现" % MAX_WAIT)
		return
	_check(a, "落地后出现了弹跳箭头", true)

	var arrow := _arrow(drop)
	var offset := arrow.position
	_check(a, "箭头摆在该战利品算出来的位置",
		offset.distance_to(drop.get_level_award_arrow_offset()) < 2.0, str(offset))
	## 原版箭头在战利品的**右上**（贴图中心 + (宽/2, 高/2 - 60)）
	_check(a, "箭头在战利品右上方", offset.x > 0.0 and offset.y < 0.0, str(offset))
	## 截一张图（**开窗口跑时**才有内容，无头模式下是空图）
	_screenshot(a, "loot_arrow")

	## 采样箭头的高度与战利品的亮度：箭头要真的在上下动，亮度要真的在闪
	var arrow_ys: Array[float] = []
	var graynesses: Array[float] = []
	var waited := 0.0
	while waited < SAMPLE_TIME:
		if is_instance_valid(arrow) and is_instance_valid(arrow.arrow_sprite):
			arrow_ys.append(arrow.arrow_sprite.position.y)
		if is_instance_valid(drop):
			graynesses.append(drop.modulate.r)
		await a.wait(SAMPLE_STEP)
		waited += SAMPLE_STEP

	var bob_span := 0.0
	if arrow_ys.size() > 1:
		var lo := arrow_ys[0]
		var hi := arrow_ys[0]
		for y in arrow_ys:
			lo = min(lo, y)
			hi = max(hi, y)
		bob_span = hi - lo
	_check(a, "箭头在上下弹跳（幅度 > 2 像素）", bob_span > 2.0, "幅度 %.1f 像素" % bob_span)

	var min_gray := 1.0
	var max_gray := 0.0
	for g in graynesses:
		min_gray = min(min_gray, g)
		max_gray = max(max_gray, g)
	_check(a, "战利品在周期闪光（亮度有起伏）", max_gray - min_gray > 0.2,
		"亮度 %.2f ~ %.2f" % [min_gray, max_gray])
	_check(a, "闪光的最暗处接近原版的 55/255", min_gray < 0.5, "%.3f" % min_gray)

	a.log("")
	a.log("--- 3. 点开：星星爆裂 + 箭头收起 ---")
	var screen_pos := _to_screen(drop.global_position)
	await a.click(screen_pos.x, screen_pos.y)
	if not await _wait_opened(a, drop, 3.0):
		_check(a, "点开掉落物", false)
		return
	_check(a, "点开掉落物", true)

	## 星星爆裂是挂在掉落容器里的一次性特效（不挂在战利品身上）
	var starburst := _find_starburst(parent)
	_check(a, "拾取时弹了星星爆裂", starburst != null, str(starburst))
	_check(a, "拾取后箭头收起了", not _arrow_visible(drop))
#endregion


#region 观测
## 等箭头出现（落地那一刻起）
func _wait_arrow(a, drop: Node2D, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if _arrow_visible(drop):
			return true
		if not is_instance_valid(drop):
			return false
		await a.wait(0.1)
		waited += 0.1
	return false


func _arrow(drop: Node2D) -> LootPickupArrow:
	if not is_instance_valid(drop):
		return null
	return drop.get_node_or_null("PickUpArrow") as LootPickupArrow


func _arrow_visible(drop: Node2D) -> bool:
	var arrow := _arrow(drop)
	return arrow != null and arrow.visible


## 星星爆裂：掉落容器里的一次性特效节点
func _find_starburst(parent: Node) -> LootStarburst:
	for c in parent.get_children():
		if c is LootStarburst:
			return c as LootStarburst
	return null


func _wait_drop(a, parent: Node, timeout: float) -> Present:
	var waited := 0.0
	while waited < timeout:
		var found := _find_drop(parent)
		if found != null:
			return found
		await a.wait(0.25)
		waited += 0.25
	return null


func _find_drop(parent: Node) -> Present:
	for c in parent.get_children():
		if c is Present:
			return c as Present
	return null


func _wait_opened(a, drop: Node2D, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if drop.is_opened:
			return true
		await a.wait(0.2)
		waited += 0.2
	return drop.is_opened


## 把世界坐标换算成屏幕坐标（关卡里有 Camera2D，画布有偏移）
func _to_screen(world_pos: Vector2) -> Vector2:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return world_pos
	return tree.root.get_canvas_transform() * world_pos


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
	a.log("")
	a.log("[LOOTFX] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
