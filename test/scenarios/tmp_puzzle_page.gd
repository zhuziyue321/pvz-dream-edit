extends RefCounted
## 一次性探针：解谜模式 20 关合并成一页后的选关场景结构与存档键
##
## 校验：
##   1. AllPage 下只有 1 个 GridContainer（单页），里面 20 个 ChooseLevelButton
##   2. 按钮顺序 = 砸罐子 01~10 → 我是僵尸 01~10
##   3. 每个按钮的 save_game_name == 写死的 save_key（玩家老存档不丢）
##   4. 翻页节点 Last / Next / LabelPage 已删除

const PUZZLE := MainSceneRegistry.MainScenes.ChooseLevelPuzzle

var _failed := 0


func run(a) -> void:
	var scene: PackedScene = load("res://src/menus/choose_level/puzzle_choose_level.tscn")
	var root := scene.instantiate()
	a.get_tree().root.add_child(root)

	var all := root.get_node("AllPage")
	_check(a, "AllPage 下只剩 1 页", all.get_child_count() == 1)
	_check(a, "翻页节点已删除", not root.has_node("Last") and not root.has_node("Next")
		and not root.has_node("LabelPage"))

	var grid := all.get_child(0)
	var buttons := []
	for c in grid.get_children():
		if c is ChooseLevelButton:
			buttons.append(c)
	_check(a, "单页共 20 个选关按钮", buttons.size() == 20)
	_check(a, "GridContainer 列数 = 5", grid.columns == 5)

	var expect: Array[String] = []
	for i in range(1, 11):
		expect.append("103_0_%04d" % i)
	for i in range(1, 11):
		expect.append("103_1_%04d" % i)

	for i in buttons.size():
		var btn: ChooseLevelButton = buttons[i]
		var para = btn.curr_level_data_game_para
		if para == null:
			a.log("[PUZZLEPAGE] FAIL 第 %d 个按钮没挂关卡脚本" % (i + 1))
			_failed += 1
			continue
		var key: String = para.save_game_name
		var name_ok := key == expect[i]
		if not name_ok:
			_failed += 1
		a.log("[PUZZLEPAGE] %s %2d %s -> %s" % [
			"PASS" if name_ok else "FAIL", i + 1,
			btn.level_script.resource_path.get_file(), key])
		a.log("[PUZZLEPAGE]      icon=%s" % (
			btn.preview_icon.resource_path.get_file() if btn.preview_icon else "<null>"))

	a.log("")
	a.log("[PUZZLEPAGE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _check(a, label: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	a.log("[PUZZLEPAGE] %s %s" % ["PASS" if ok else "FAIL", label])
