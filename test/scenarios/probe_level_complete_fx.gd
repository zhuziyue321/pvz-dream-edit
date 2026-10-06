extends RefCounted
## 探针：关卡掉落物被点开后的收尾表演（移向屏幕中央 -> 发光 -> 屏幕逐渐变白 -> 完全白了结算切场景）
## 覆盖：
##   1. 实机：进 1-4 —— 本关首次通关奖励是道具类（铲子），掉的是礼物盒 Present
##   2. 实机：这条掉落物被打上 is_level_complete_drop（说明它在本关的结算线上）
##   3. 实机：点开后 CanvasLayerWhiteScreen 亮起，掉落物的屏幕坐标逐渐逼近屏幕中心
##   4. 实机：白屏 alpha 单调涨到 1（完全白了）之后掉落物被释放、关卡切到选关界面（结算）
## 机器可读汇总：最后一行 [LEVELCOMPLETEFX] result=PASS|FAIL failed=<n>

const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_01_04 := "res://src/levels/mode_adventure/adventure_01_04.gd"
## 1-4 在选关界面上的位置：第 1 页（0 起 = 0）的第 4 关，关卡编号 0004
const PAGE_01 := 0
const ID_01_04 := "0004"
## 戴夫对话的点击位置（800x600 下的屏幕中心；戴夫的点击面板覆盖全屏，点哪都能推进）
const DAVE_CLICK_POS := Vector2(400, 300)
## 掉落物在世界坐标里的落点（草坪中段）
const DROP_POS := Vector2(500, 300)
## 等掉落物出现 / 等表演播完的上限秒数
const MAX_WAIT := 20.0

var _failed := 0
## 采样过程中白屏层是否露过面
var _max_visible_seen := false
## 采样过程中发光组是否露过面
var _max_light_visible := false


func run(a) -> void:
	a.log("")
	a.log("========== 探针 通关掉落物收尾表演（居中 -> 发光 -> 白屏 -> 结算） ==========")
	## 等主菜单自身初始化完再切场景，否则 change_scene_to_file 会撞上「父节点正忙」
	await a.wait(2.0)
	await _run_level(a)
	_finish(a)


#region 实机
## 进 1-4，走真正的结算入口掉出本关奖励，再点开它看收尾表演
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
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])

	if not await _wait_main_game(a, 90.0):
		_check(a, "1-4 进入 MAIN_GAME", false, "超时，阶段=%s" % str(_progress_name()))
		return
	_check(a, "1-4 进入 MAIN_GAME", true)

	var tree := Engine.get_main_loop() as SceneTree
	## 自动收集会把掉落物秒开，探针就没法走"点开"这一步了
	var cfg := Global.config_service
	if "auto_collect_coin" in cfg:
		cfg.auto_collect_coin = false

	var white_layer := _find_white_layer()
	_check(a, "（前置）主游戏里挂着白屏表演层", white_layer != null, str(white_layer))
	if white_layer == null:
		return
	_check(a, "白屏表演层开局是隐藏的（不挡画面）", not white_layer.visible, str(white_layer.visible))

	var parent := Global.main_game.drop_item_manager.dim_garden_plant.all_drop_garden_plant_parent
	_check(a, "（前置）掉落容器已就绪", parent != null)
	if parent == null:
		return

	_check_light_layer(a, white_layer, parent)

	## 走真正的结算线：这一条会掉出本关奖励并一直等到玩家点开后才切场景
	a.log("  触发本关结算线 drop_adventure_reward_on_level_complete(%s)" % str(DROP_POS))
	Global.main_game.reward_manager.drop_adventure_reward_on_level_complete(DROP_POS)

	var drop := await _wait_drop(a, parent, MAX_WAIT)
	_check(a, "结算线掉出了本关奖励", drop != null, str(drop))
	if drop == null:
		return
	_check(a, "掉落物被标记为「本关结算线」上的掉落", drop.is_level_complete_drop,
		str(drop.is_level_complete_drop))
	_check(a, "掉落物此刻还没被拾取", not drop.is_opened, str(drop.is_opened))

	var start_screen := _to_screen(drop.global_position)
	var center: Vector2 = tree.root.get_visible_rect().size / 2.0
	a.log("  掉落世界坐标=(%d,%d) 屏幕坐标=(%d,%d) 屏幕中心=(%d,%d)" % [
		int(drop.global_position.x), int(drop.global_position.y),
		int(start_screen.x), int(start_screen.y), int(center.x), int(center.y)])
	_check(a, "掉落物掉在画面内（点得到）", _is_in_view(start_screen), str(start_screen))

	## 点开：走真实鼠标点击，验证玩家点得动
	var btn := drop.texture_button
	if btn == null or not btn.visible:
		_check(a, "（前置）掉落物有可点区域", false, str(btn))
		return
	var click_pos := AutopilotProbe.screen_center_of(btn)
	await a.click(click_pos.x, click_pos.y)
	_check(a, "点开掉落物", await _wait_opened(a, drop, 3.0), str(drop.is_opened))

	await _watch_perform(a, white_layer, drop, start_screen, center)
#endregion


#region 表演观测
## 采样整段表演：掉落物向屏幕中心逼近 -> 白屏渐亮 -> 全白后释放掉落物 -> 切场景结算
func _watch_perform(a, white_layer: CanvasLayerWhiteScreen, drop: Node2D,
		start_screen: Vector2, center: Vector2) -> void:
	a.log("")
	a.log("--- 2. 收尾表演采样（0.25 秒一次）---")
	var tree := Engine.get_main_loop() as SceneTree
	var start_dist := start_screen.distance_to(center)
	var min_dist := start_dist
	var last_alpha := -1.0
	var alpha_monotonic := true
	var max_alpha := 0.0
	var drop_freed := false
	var scene_switched := false
	var waited := 0.0
	var logged := 0
	while waited < MAX_WAIT:
		var visible_now := is_instance_valid(white_layer) and white_layer.visible
		if visible_now:
			_max_visible_seen = true
		if is_instance_valid(white_layer) and is_instance_valid(white_layer.award_light) \
				and white_layer.award_light.visible:
			_max_light_visible = true
		var alpha := 0.0
		if is_instance_valid(white_layer):
			alpha = white_layer.color_rect_white.modulate.a
		var dist := -1.0
		if is_instance_valid(drop):
			dist = _to_screen(drop.global_position).distance_to(center)
			if dist < min_dist:
				min_dist = dist
		else:
			drop_freed = true
		if tree.current_scene != null and not _is_main_game(tree.current_scene):
			scene_switched = true
		## 单调性只在「表演还在跑」的这段时间里判定：
		## 关卡一切场景，MainGame 连同白屏层一起被释放，取到的 alpha 会回落成 0，不能拿来算忽明忽暗
		if not scene_switched:
			if alpha > max_alpha:
				max_alpha = alpha
			if alpha + 0.001 < last_alpha:
				alpha_monotonic = false
			last_alpha = alpha
		if logged < 40 and int(waited * 4) % 4 == 0:
			logged += 1
			a.log("  t=%.1fs 白屏可见=%s alpha=%.2f 距中心=%.0f 掉落仍在=%s 已切场景=%s" % [
				waited, str(visible_now), alpha, dist, str(is_instance_valid(drop)), str(scene_switched)])
		if scene_switched:
			break
		await a.wait(0.25)
		waited += 0.25

	a.log("")
	a.log("--- 3. 断言 ---")
	_check(a, "发现光了（发光组在中途亮起来过）", _max_light_visible, "详见上方采样")
	_check(a, "点开后白屏层显示出来了", _max_visible_seen, "详见上方采样")
	_check(a, "掉落物向屏幕中心移动了（%.0f -> %.0f）" % [start_dist, min_dist],
		min_dist < start_dist - 10.0, "最近时距中心 %.0f 像素" % min_dist)
	_check(a, "掉落物最终落在屏幕中心附近", min_dist <= 40.0, "%.0f 像素" % min_dist)
	_check(a, "白屏 alpha 单调上涨（没有忽明忽暗）", alpha_monotonic, "最高 %.2f" % max_alpha)
	_check(a, "屏幕全白了（alpha 到 1）", max_alpha >= 0.99, "%.3f" % max_alpha)
	_check(a, "全白之后才切场景结算（表演播完才结束关卡）", scene_switched, str(scene_switched))
	_check(a, "切场景前掉落物已被释放（被光收走）", drop_freed, str(not is_instance_valid(drop)))
#endregion


#region 工具
## 光的图层：必须跟掉落物同一层，且排在掉落容器之前（本体才画在光之上，不会被光糊掉）；
## 白屏则在更高的层级，最后才吃掉画面（跨画布层时 z_index 不起作用，只有 layer 值和树序说了算）
func _check_light_layer(a, white_layer: CanvasLayerWhiteScreen, drop_parent: Node) -> void:
	var light := white_layer.award_light
	_check(a, "发光组挂在掉落物所在的画布层（不压在最上层）",
		light != null and light.get_parent() == drop_parent.get_parent(),
		"父=" + str(light.get_parent().name if light != null else "null"))
	if light == null:
		return
	_check(a, "光排在掉落容器之前绘制（本体在光之上）",
		light.get_index() < drop_parent.get_index(),
		"光序号=%d 容器序号=%d" % [light.get_index(), drop_parent.get_index()])
	var ui_layer := _find_layer_by_name("CanvasLayerUI")
	if ui_layer == null:
		a.log("  （跳过）没找到 CanvasLayerUI，无法比对白屏层级")
		return
	var light_layer := light.get_parent() as CanvasLayer
	_check(a, "白屏层在 UI 层之上（最后才吃掉画面）", white_layer.layer > ui_layer.layer,
		"白屏=%d UI=%d 光所在层=%d" % [white_layer.layer, ui_layer.layer,
			light_layer.layer if light_layer != null else -1])


func _find_layer_by_name(layer_name: String) -> CanvasLayer:
	if Global.main_game == null:
		return null
	for c in Global.main_game.get_children():
		if c is CanvasLayer and c.name == layer_name:
			return c as CanvasLayer
	return null


## 把世界坐标换算成屏幕坐标（关卡里有 Camera2D，画布有偏移）
func _to_screen(world_pos: Vector2) -> Vector2:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return world_pos
	return tree.root.get_canvas_transform() * world_pos


func _is_main_game(scene: Node) -> bool:
	return scene.name.to_lower().begins_with("maingame")


func _is_in_view(pos: Vector2) -> bool:
	var size := Vector2(800, 600)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		size = tree.root.get_visible_rect().size
	return pos.x >= 0.0 and pos.y >= 0.0 and pos.x <= size.x and pos.y <= size.y


## 白屏表演层：主游戏场景里的 CanvasLayerWhiteScreen
func _find_white_layer() -> CanvasLayerWhiteScreen:
	if Global.main_game == null:
		return null
	for c in Global.main_game.get_children():
		if c is CanvasLayerWhiteScreen:
			return c as CanvasLayerWhiteScreen
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


## 把通关记录写成「第 1 关 ~ 第 max_level 关全部通关」
func _mark_cleared(max_level: int) -> void:
	var state := Global.global_game_state
	state.curr_all_level_state_data = {}
	for i in range(1, max_level + 1):
		state.curr_all_level_state_data["%d_0_%04d" % [ADV, i]] = {"IsSuccess": true}


func _progress_name() -> String:
	if Global.main_game == null:
		return "main_game=null"
	return str(Global.main_game.main_game_progress)


## 等进 MAIN_GAME：中途出现戴夫就逐句点完，停在选卡 / 准备阶段就替玩家点「开始游戏」
func _wait_main_game(a, timeout: float) -> bool:
	var started := false
	var waited := 0.0
	while waited < timeout:
		if Global.main_game == null:
			await a.wait(0.5)
			waited += 0.5
			continue
		if _find_dave() != null:
			await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
			await a.wait(0.4)
			waited += 0.4
			continue
		if Global.main_game.is_timeline_waiting_choose_card and not started:
			a.log("  点「开始游戏」（当前阶段=%d）" % Global.main_game.main_game_progress)
			started = true
			Global.main_game.main_game_start()
			await a.wait(1.5)
			waited += 1.5
			continue
		if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


func _find_dave() -> CrazyDave:
	var mg = Global.main_game
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
	a.log("[LEVELCOMPLETEFX] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
