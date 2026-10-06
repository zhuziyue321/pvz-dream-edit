extends RefCounted
## 探针：冒险选关界面 x-10「本关看点」图标 = 纸条
## 覆盖：1-10 ~ 5-10 的 Panel/TextureRect 下只挂 Sprite2D(ZombieNote)，
##       贴图 res://assets/image/zombie_note/ZombieNoteSmall.png，不再实例化僵尸
## 机器可读汇总：最后一行 [X10NOTE] result=PASS|FAIL failed=<n>

const NOTE_PATH := "res://assets/image/zombie_note/ZombieNoteSmall.png"
const X10_TEXT_RECTS: Array[String] = [
	"AllPage/GridContainer/ChooseLevelButton10/Panel/TextureRect",
	"AllPage/GridContainer2/ChooseLevelButton10/Panel/TextureRect",
	"AllPage/GridContainer3/ChooseLevelButton10/Panel/TextureRect",
	"AllPage/GridContainer4/ChooseLevelButton10/Panel/TextureRect",
	"AllPage/GridContainer5/ChooseLevelButton10/Panel/TextureRect",
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE x-10 看点图标 = 纸条 ==========")
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)
	await a.click_first("Menu/Button1")
	if not await a.wait_scene("choose_level", 12.0):
		a.log("!! 进不了选关界面")
		_finish(a)
		return
	await a.wait(1.0)

	var root: Node = a.get_node_or_null("/root/ChooseLevel")
	_check(a, "选关界面已加载", root != null, "找不到 /root/ChooseLevel")
	if root == null:
		_finish(a)
		return

	for rel: String in X10_TEXT_RECTS:
		_check_x10(a, root, rel)
	_finish(a)


## 单个 x-10 看点：只应有 1 个 Sprite2D 子节点，且贴图是纸条
func _check_x10(a, root: Node, rel: String) -> void:
	var tr: Node = root.get_node_or_null(rel)
	if tr == null:
		_check(a, rel + " 存在", false, "节点缺失")
		return
	_check(a, rel + " 只有 1 个子节点", tr.get_child_count() == 1, "实际 " + str(tr.get_child_count()))
	if tr.get_child_count() < 1:
		return
	var icon: Node = tr.get_child(0)
	_check(a, rel + " 子节点是 Sprite2D", icon is Sprite2D, icon.get_class())
	var sp := icon as Sprite2D
	if sp == null:
		return
	var tex: Texture2D = sp.texture
	var tex_path := "" if tex == null else tex.resource_path
	_check(a, rel + " 贴图是纸条", tex_path == NOTE_PATH, tex_path)
	a.log("  [INFO] " + rel + " -> " + str(icon.name) \
		+ " 位置=" + str(sp.position) \
		+ " 可见=" + str(sp.is_visible_in_tree()) \
		+ " 屏幕=" + str(sp.get_global_transform_with_canvas() * Vector2.ZERO))


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[X10NOTE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
