extends RefCounted
## 探针：坚果保龄球红线（WallnutBowlingStripe）是不是真的画得出来
## 覆盖：
##   1. 关卡配了 is_bowling_stripe 时，红线节点被创建并挂到 CanvasLayerBG/GameItemsInBg 下
##   2. 红线画在背景之上（背景子场景是运行期挂到 CanvasLayerBG 末尾的，
##      两者 z_index 都是 0 时后加入的背景会盖住红线 —— 见 BackgroundManager.init_background）
##   3. 红线落在草坪范围内（屏幕坐标在草坪左右边界之间）
## 机器可读汇总：最后一行 [BOWLINGSTRIPE] result=PASS|FAIL failed=<n>

var _failed := 0
const LEVEL_PATH := "res://src/levels/mode_minigame/minigame_02_bowling.gd"


func run(a) -> void:
	a.log("")
	a.log("========== 探针：坚果保龄球红线 ==========")

	var para = (load(LEVEL_PATH) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败")
		_finish(a)
		return
	para.set_choose_level(MainSceneRegistry.MainScenes.ChooseLevelMiniGame, 0, "0001")
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[para.game_sences]
	)
	if not await _wait_main_game(a, 40.0):
		a.log("!! 进不了关卡")
		_finish(a)
		return
	await a.wait(1.0)

	var mg = Global.main_game

	# ------------------------------------------------ STEP1 关卡配置
	a.log("STEP1 关卡配置了保龄球红线")
	_check(a, "minigame_01_bowling 打开了 is_bowling_stripe", para.is_bowling_stripe,
		str(para.is_bowling_stripe))
	a.log("   红线所在列 plant_cell_col_j=%d" % para.plant_cell_col_j)

	# ------------------------------------------------ STEP2 红线节点
	a.log("STEP2 红线节点已创建")
	var bg_layer: CanvasLayer = mg.get_node_or_null("CanvasLayerBG")
	_check(a, "取到 CanvasLayerBG", bg_layer != null, "null" if bg_layer == null else str(bg_layer.get_path()))
	var items: Node2D = mg.get_node_or_null("CanvasLayerBG/GameItemsInBg")
	_check(a, "取到 GameItemsInBg", items != null, "null" if items == null else str(items.get_path()))
	if bg_layer == null or items == null:
		_finish(a)
		return
	var stripe: WallnutBowlingStripe = null
	for c in items.get_children():
		if c is WallnutBowlingStripe:
			stripe = c as WallnutBowlingStripe
	_check(a, "红线节点已挂在 GameItemsInBg 下", stripe != null,
		"null" if stripe == null else str(stripe.get_path()))
	if stripe == null:
		_finish(a)
		return
	_check(a, "红线可见", stripe.visible, str(stripe.visible))
	var tex: Texture2D = stripe.texture
	a.log("   红线贴图=%s 尺寸=%s" % [str(tex.resource_path if tex != null else "null"),
		str(tex.get_size() if tex != null else Vector2.ZERO)])
	a.log("   红线世界坐标=%s 缩放=%s" % [str(stripe.global_position), str(stripe.scale)])

	# ------------------------------------------------ STEP3 绘制顺序
	a.log("STEP3 红线画在背景之上")
	var bg: Node2D = mg.background_manager.background if mg.background_manager != null else null
	_check(a, "取到背景节点", bg != null, "null" if bg == null else str(bg.get_path()))
	a.log("   CanvasLayerBG 子节点顺序：")
	for i in range(bg_layer.get_child_count()):
		var c := bg_layer.get_child(i)
		a.log("     [%d] %s  z_index=%d  类型=%s" % [i, c.name, c.z_index, c.get_class()])
	if bg != null:
		var items_z: int = items.z_index
		var bg_z: int = bg.z_index
		var items_index: int = items.get_index()
		var bg_index: int = bg.get_index()
		## 兄弟节点之间：先比 z_index，相同再比树顺序
		var above: bool = (items_z > bg_z) or (items_z == bg_z and items_index > bg_index)
		_check(a, "红线容器画在背景之后（不会被背景盖住）", above,
			"GameItemsInBg(z=%d,idx=%d) vs Background(z=%d,idx=%d)" % [items_z, items_index, bg_z, bg_index])

	# ------------------------------------------------ STEP4 位置在草坪范围内
	a.log("STEP4 红线落在草坪范围内")
	var rows: Array = mg.plant_cell_manager.all_plant_cells
	if rows.is_empty() or (rows[0] as Array).is_empty():
		_check(a, "取到草坪格子", false, "空")
		_finish(a)
		return
	var first_cell: PlantCell = (rows[0] as Array)[0]
	var last_cell: PlantCell = (rows[0] as Array)[(rows[0] as Array).size() - 1]
	var left_x: float = first_cell.global_position.x
	var right_x: float = last_cell.global_position.x + last_cell.size.x
	_check(a, "红线 x 落在草坪左右边界之间", left_x <= stripe.global_position.x and stripe.global_position.x <= right_x,
		"红线x=%.1f 左=%.1f 右=%.1f" % [stripe.global_position.x, left_x, right_x])
	var top_y: float = (rows[0] as Array)[0].global_position.y
	var bottom_row: Array = rows[rows.size() - 1] as Array
	var bottom_y: float = bottom_row[0].global_position.y + bottom_row[0].size.y
	_check(a, "红线 y 落在草坪上下边界之间", top_y - 40 <= stripe.global_position.y and stripe.global_position.y <= bottom_y,
		"红线y=%.1f 上=%.1f 下=%.1f" % [stripe.global_position.y, top_y, bottom_y])

	_finish(a)


#region 断言与工具
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[BOWLINGSTRIPE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 等主游戏进入 MAIN_GAME 阶段
func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null and Global.main_game.main_game_progress == 3:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false
#endregion
