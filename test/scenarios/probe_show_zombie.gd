extends RefCounted
## 探针：开场「僵尸预览」在屏幕上的落点
## 覆盖：进 1-1 → 主动触发 create_prepare_show_zombies() + move_look_zombie()，
##       dump 预览面板（ShowZombiePanel）与每只预览僵尸的**屏幕坐标**，判断它们是不是整体偏左 / 被裁。
## 背景：面板是 CanvasLayerBG（follow_viewport）下的右锚 Control，层坐标 ≡ 世界坐标，
##       屏幕 x = 世界 x - 相机 x；改设计分辨率后这块最容易跑偏。
## 机器可读汇总：最后一行 [SHOWZOMBIE] result=PASS|FAIL failed=<n>

const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_01_01.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 开场僵尸预览 ==========")
	var para: Resource = (load(LEVEL_PATH) as GDScript).new()
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(3.0)

	var mg := Global.main_game
	_check(a, "已进入主游戏", mg != null, "Global.main_game 为空")
	if mg == null:
		_finish(a)
		return
	if mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		mg.main_game_start()
	await a.wait(2.0)

	## 主动触发预览（不等时间轴）：先造僵尸，再走相机看僵尸那段位移
	mg.zombie_manager.create_prepare_show_zombies()
	await mg.camera_2d.move_look_zombie()
	await a.wait(0.5)

	var vp: Vector2 = a.get_tree().root.get_visible_rect().size
	var cam := mg.camera_2d.global_position
	a.log("视口 = " + str(vp) + "  相机 = " + str(cam))

	var panel := mg.get_node_or_null("CanvasLayerBG/ShowZombiePanel") as Control
	if panel == null:
		_check(a, "ShowZombiePanel 存在", false, "节点缺失")
		_finish(a)
		return
	var pr := panel.get_global_rect()
	a.log("  [INFO] ShowZombiePanel 层坐标 rect=" + str(pr) \
		+ "  => 屏幕 x " + str(pr.position.x - cam.x) + " .. " + str(pr.end.x - cam.x))

	var zs := mg.zombie_manager.zombie_show_in_start.show_zombies_array
	a.log("  [INFO] 预览僵尸数 = " + str(zs.size()))
	var min_x := 9999.0
	var max_x := -9999.0
	for z in zs:
		if not is_instance_valid(z):
			continue
		var screen := z.get_global_transform_with_canvas() * Vector2.ZERO
		min_x = min(min_x, screen.x)
		max_x = max(max_x, screen.x)
		a.log("  [INFO]   " + str(z.name) + " 层坐标 x=" + str(snappedf(z.global_position.x, 0.1)) \
			+ " 屏幕 x=" + str(snappedf(screen.x, 0.1)))

	if zs.is_empty():
		_check(a, "有预览僵尸", false, "一只都没有")
	else:
		a.log("  [INFO] 僵尸屏幕 x 区间 = " + str(snappedf(min_x, 0.1)) + " .. " + str(snappedf(max_x, 0.1)))
		## 僵尸本体宽约 60~80，这里只做「是否落在屏幕内 / 是否贴左」的提示，不硬断言
		_check(a, "预览僵尸都在视口内", min_x >= 0.0 and max_x <= vp.x,
			"x 区间=" + str(snappedf(min_x, 0.1)) + ".." + str(snappedf(max_x, 0.1)) + " 视口宽=" + str(vp.x))

	_finish(a)


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[SHOWZOMBIE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
