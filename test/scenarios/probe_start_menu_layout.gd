extends RefCounted
## 探针：主菜单背景构图是否贴合当前设计分辨率
## 覆盖：开场滑入动画播完后，三段背景（BG_Left/Center/Right）的落点是否等于
##       各自锚点在当前视口宽下的解；挂在墓碑（BG_Right）上的按钮是否都在屏内。
## 背景位置写在 `StartMenu` 的 Idle 动画里（不是 tscn 静态 offset），
## 换设计分辨率后动画里的 x 会变成旧值 —— 这个探针就是抓这件事的。
## 机器可读汇总：最后一行 [MENULAYOUT] result=PASS|FAIL failed=<n>

## 三段背景的锚点算式：x = 视口宽 * anchor_left + offset_left（见 start_menu.tscn）
const BG_EXPECT: Dictionary[String, Vector2] = {
	## 左锚：x 恒为 0；y = -40（贴图 680 高，上下各溢出 40）
	"BG_Left": Vector2(0.0, -40.0),
	## 居中锚（anchor_left = 0.5，offset_left = -493）
	"BG_Center": Vector2(0.5, 250.0),
	## 右锚（anchor_left = 1.0，offset_left = -726）：墓碑右边缘贴屏幕右边
	"BG_Right": Vector2(1.0, 40.0),
}
## 锚点公式里的 offset_left（与上面 BG_EXPECT 一一对应）
const BG_OFFSET_LEFT: Dictionary[String, float] = {
	"BG_Left": 0.0,
	"BG_Center": -493.0,
	"BG_Right": -726.0,
}
## 挂在大墓碑上的按钮：滑入动画结束后必须整块在屏内（左移前它们会被右边缘裁掉）
const BUTTON_PATHS: Array[String] = [
	"BG_Right/Menu/Button1",
	"BG_Right/Menu/Button2",
	"BG_Right/Menu/Button3",
	"BG_Right/Menu/Button4",
	"BG_Right/Item/TextureButton",
	"BG_Right/Item/TextureButton2",
	"BG_Right/Item/TextureButton3",
	"BG_Right/Option/TextureButton",
	"BG_Right/Option/TextureButton2",
	"BG_Right/Option/TextureButton3",
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 主菜单背景构图 ==========")
	## 按钮从右侧滑入，必须等稳定；再等 2 秒让背景滑入动画（Idle, length=2.0）走完
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)
	await a.wait(2.0)

	var menu: Node = a.get_node_or_null("/root/StartMenu")
	_check(a, "主菜单已加载", menu != null, "找不到 /root/StartMenu")
	if menu == null:
		_finish(a)
		return

	var vp: Vector2 = a.get_tree().root.get_visible_rect().size
	a.log("视口尺寸 = " + str(vp))

	for bg_name: String in BG_EXPECT:
		_check_bg(a, menu, bg_name, vp)

	for rel: String in BUTTON_PATHS:
		var btn := menu.get_node_or_null(rel) as Control
		if btn == null:
			_check(a, rel + " 存在", false, "节点缺失")
			continue
		var r := btn.get_global_rect()
		a.log("  [INFO] " + rel + " rect=" + str(r))
		_check(a, rel + " 在屏内",
			r.position.x >= -1.0 and r.end.x <= vp.x + 1.0 and r.position.y >= -1.0 and r.end.y <= vp.y + 1.0,
			"rect=" + str(r) + " 视口=" + str(vp))

	_finish(a)


## 单段背景：动画落点必须等于「锚点 * 视口宽 + offset_left」
func _check_bg(a, menu: Node, bg_name: String, vp: Vector2) -> void:
	var bg := menu.get_node_or_null(bg_name) as Control
	if bg == null:
		_check(a, bg_name + " 存在", false, "节点缺失")
		return
	var exp: Vector2 = BG_EXPECT[bg_name]
	var exp_x: float = vp.x * exp.x + BG_OFFSET_LEFT[bg_name]
	var pos := bg.position
	a.log("  [INFO] " + bg_name + " position=" + str(pos) + " 期望 x=" + str(exp_x))
	_check(a, bg_name + " x 贴合锚点", absf(pos.x - exp_x) <= 1.0,
		"实际 x=" + str(pos.x) + " 期望 x=" + str(exp_x))
	_check(a, bg_name + " y 已滑入到位", absf(pos.y - exp.y) <= 1.0,
		"实际 y=" + str(pos.y) + " 期望 y=" + str(exp.y))


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[MENULAYOUT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
