extends RefCounted
## 探针：僵尸水族馆的入口场景 res://src/zombiquarium/zombiquarium.tscn 能**脱离主游戏**单独跑
## 覆盖：
##   ① 切到入口场景后没任何人调 init —— 自己判定进独立预览（预览 HUD 显示出来）
##   ② 壳里拿得到玩法本体：开局 2 只宠物、自带 50 阳光（这条路没有出战卡槽可依赖）
##   ③ 造脑子扣 5 阳光，HUD 的阳光数字跟着更新
##   ④ 宠物全饿死 -> 壳转发 signal_finished(false)，HUD 给出失败结论
## 关卡里那条路径（壳挂到 MainGameManager 上）由 probe_zombiquarium.gd 覆盖。
## 机器可读汇总：最后一行 [ZQSTAND] result=PASS|FAIL failed=<n>

const SHELL_SCENE := "res://src/zombiquarium/zombiquarium.tscn"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵尸水族馆入口场景（脱离主游戏） ==========")
	a.get_tree().change_scene_to_file(SHELL_SCENE)
	await a.wait_scene("zombiquarium")
	await a.wait(1.5)

	var scene: ZombiquariumScene = a.get_tree().current_scene
	_check(a, "① 已进入水族馆入口场景", scene != null, "current_scene 不是 ZombiquariumScene")
	if scene == null:
		_finish(a)
		return
	_check(a, "①b 没人 init -> 自动进独立预览", scene.standalone_hud.visible, "预览 HUD 没显示")

	var manager: ZombiquariumManager = scene.get_manager()
	_check(a, "② 壳里有玩法本体", manager != null, "get_manager() 为空")
	if manager == null:
		_finish(a)
		return
	_check(a, "②b 开局 2 只宠物僵尸", manager.get_pets().size() == 2,
		"实际=" + str(manager.get_pets().size()))
	_check(a, "②c 自带 50 阳光（没有出战卡槽）", manager.get_sun_value() == 50,
		"实际=" + str(manager.get_sun_value()))

	## ③ 造脑子：独立模式扣的是管理器自带的那份阳光
	manager.create_brain(Vector2(400.0, 300.0))
	await a.frames(2)
	_check(a, "③ 造脑子扣 5 阳光", manager.get_sun_value() == 45, "实际=" + str(manager.get_sun_value()))
	_check(a, "③b HUD 阳光数字跟上", "45" in scene.sun_label.text, "实际=" + scene.sun_label.text)

	## ④ 判负：全部饿死（死亡动画 + 淡出约 3.6 秒）
	var result: Array = []
	scene.signal_finished.connect(func(is_win: bool) -> void: result.append(is_win))
	for pet in manager.get_pets().duplicate():
		pet.die()
	await a.wait(5.0)
	_check(a, "④ 宠物全部死亡", manager.get_pets().is_empty(),
		"还剩 " + str(manager.get_pets().size()) + " 只")
	_check(a, "④b 壳转发了判负信号", result == [false], "实际=" + str(result))
	_check(a, "④c HUD 给出失败结论", scene.tip_label.text == ZombiquariumScene.RESULT_LOSE,
		"实际=" + scene.tip_label.text)
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
	a.log("[ZQSTAND] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
