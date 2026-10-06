extends RefCounted
## 探针：冒险选关界面「关卡网格」的布局
## 覆盖：主菜单 → 冒险模式 → 选关界面，dump 关卡按钮 / 网格 / 翻页按钮的实际 rect，
##       并断言「关卡网格左右都留边、整块在视口内」（改设计分辨率后网格常在这里跑偏）。
## 机器可读汇总：最后一行 [LEVELGRID] result=PASS|FAIL failed=<n>

## 顶层节点：用来对照「关卡该往哪摆」的参照物
const TOP_NODES: Array[String] = [
	"BG",
	"Label",
	"AllPage",
	"MainMenu",
	"Last",
	"Next",
	"LabelPage",
]
## 5 页网格（冒险 5 个世界）
const GRIDS: Array[String] = [
	"AllPage/GridContainer",
	"AllPage/GridContainer2",
	"AllPage/GridContainer3",
	"AllPage/GridContainer4",
	"AllPage/GridContainer5",
]
## 每页取第 1 / 5 / 6 / 10 关（左端、第一排右端、第二排左端、右端）
const BUTTON_INDEXES: Array[int] = [1, 5, 6, 10]
## 关卡网格左右至少要留的边距（像素）
const MIN_MARGIN := 16.0

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 冒险选关关卡网格 ==========")
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

	var vp: Vector2 = a.get_tree().root.get_visible_rect().size
	a.log("视口尺寸 = " + str(vp))

	for rel: String in TOP_NODES:
		_info(a, root, rel)

	for grid: String in GRIDS:
		var gc := root.get_node_or_null(grid) as Control
		if gc == null:
			_check(a, grid + " 存在", false, "节点缺失")
			continue
		var gr := gc.get_global_rect()
		a.log("  [INFO] " + grid + " rect=" + str(gr))
		for i: int in BUTTON_INDEXES:
			_info(a, gc, _btn_name(i))
		## 关卡整块必须在视口内，且左右都留边
		_check(a, grid + " 左右都留边",
			gr.position.x >= MIN_MARGIN and vp.x - gr.end.x >= MIN_MARGIN,
			"左留=" + str(gr.position.x) + " 右留=" + str(vp.x - gr.end.x) + " 视口=" + str(vp.x))

	_finish(a)


func _btn_name(i: int) -> String:
	return "ChooseLevelButton" if i == 1 else "ChooseLevelButton" + str(i)


func _info(a, parent: Node, rel: String) -> void:
	var n := parent.get_node_or_null(rel)
	if n == null:
		a.log("  [INFO] " + rel + " 缺失")
		return
	if n is Control:
		var c := n as Control
		a.log("  [INFO] " + rel + " rect=" + str(c.get_global_rect()) \
			+ " visible=" + str(c.is_visible_in_tree()))
	else:
		a.log("  [INFO] " + rel + " 不是 Control: " + str(n.get_class()))


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[LEVELGRID] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
