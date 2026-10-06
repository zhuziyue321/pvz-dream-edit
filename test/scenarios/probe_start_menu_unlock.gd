extends RefCounted
## 探针：主菜单「未解锁入口」的表现 —— 花园 / 图鉴 / 商店未解锁时直接隐藏,模式按钮置灰保留
## 覆盖：
##   1. 新档（0 关）：花园、图鉴、商店 visible=false
##   2. 通关到 2-3(13) 图鉴仍隐藏 / 2-4(14) 图鉴出现 —— 门槛 14
##   3. 通关到 3-3(23) 商店仍隐藏 / 3-4(24) 商店出现 —— 门槛 24
##   4. 通关到 5-4(44) 花园仍隐藏 / 5-5(45) 花园出现 —— 门槛 45
##   5. 模式按钮（迷你游戏 22 / 解谜 36 / 生存 50）未解锁时是置灰而不是隐藏
## 机器可读汇总：最后一行 [MENUUNLOCK] result=PASS|FAIL failed=<n>

const PATH_GARDEN := "BG_Right/Item/TextureButton"
const PATH_ALMANAC := "BG_Right/Item/TextureButton2"
const PATH_SHOP := "BG_Right/Item/TextureButton3"

## 模式按钮节点 -> 解锁所需关卡序号(与 ConstUnlockLevel 对齐)
const MODE_BUTTONS: Dictionary[String, int] = {
	"BG_Right/Menu/Button2": 22,
	"BG_Right/Menu/Button3": 36,
	"BG_Right/Menu/Button4": 50,
}
const LOCKED_COLOR := Color(0.687, 0.687, 0.687, 1.0)

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 主菜单未解锁入口的表现 ==========")
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)
	await a.wait(1.0)

	var menu: Node = a.get_node_or_null("/root/StartMenu")
	if menu == null:
		_check(a, "主菜单已加载", false, "找不到 /root/StartMenu")
		_finish(a)
		return

	var state = Global.global_game_state

	# ------------------------------------------------ STEP1 新档
	a.log("STEP1 新档：花园 / 图鉴 / 商店都不该出现")
	_mark_cleared(state, 0)
	menu._update_mode_lock_state()
	_check_visible(a, menu, PATH_GARDEN, false)
	_check_visible(a, menu, PATH_ALMANAC, false)
	_check_visible(a, menu, PATH_SHOP, false)
	_check_mode(a, menu, 0)

	# ------------------------------------------------ STEP2 图鉴门槛 2-4
	a.log("STEP2 图鉴门槛 = 2-4（序号 14）")
	_mark_cleared(state, 13)
	menu._update_mode_lock_state()
	_check_visible(a, menu, PATH_ALMANAC, false, "通关到 2-3")
	_mark_cleared(state, 14)
	menu._update_mode_lock_state()
	_check_visible(a, menu, PATH_ALMANAC, true, "通关到 2-4")
	_check_visible(a, menu, PATH_SHOP, false, "2-4 时商店仍未解锁")

	# ------------------------------------------------ STEP3 商店门槛 3-4
	a.log("STEP3 商店门槛 = 3-4（序号 24）")
	_mark_cleared(state, 23)
	menu._update_mode_lock_state()
	_check_visible(a, menu, PATH_SHOP, false, "通关到 3-3")
	_mark_cleared(state, 24)
	menu._update_mode_lock_state()
	_check_visible(a, menu, PATH_SHOP, true, "通关到 3-4")

	# ------------------------------------------------ STEP4 花园门槛 5-5
	a.log("STEP4 花园门槛 = 5-5（序号 45）")
	_mark_cleared(state, 44)
	menu._update_mode_lock_state()
	_check_visible(a, menu, PATH_GARDEN, false, "通关到 5-4")
	_mark_cleared(state, 45)
	menu._update_mode_lock_state()
	_check_visible(a, menu, PATH_GARDEN, true, "通关到 5-5")

	# ------------------------------------------------ STEP5 模式按钮置灰不隐藏
	a.log("STEP5 模式按钮未解锁时置灰保留")
	_mark_cleared(state, 0)
	menu._update_mode_lock_state()
	_check_mode(a, menu, 0)
	_mark_cleared(state, 22)
	menu._update_mode_lock_state()
	_check_mode(a, menu, 22)
	_mark_cleared(state, 50)
	menu._update_mode_lock_state()
	_check_mode(a, menu, 50)
	_check_visible(a, menu, PATH_ALMANAC, true, "通关 5-10")
	_check_visible(a, menu, PATH_SHOP, true, "通关 5-10")

	# ------------------------------------------------ STEP6 切换用户后按新存档重算
	a.log("STEP6 切到 0 进度的新用户：花园 / 图鉴 / 商店必须重新隐藏")
	var panel := menu.get_node_or_null("User") as User
	if panel == null:
		_check(a, "找到 User 面板", false, "节点缺失")
		_finish(a)
		return
	## 走真实的新建流程:输入名字 -> 建档(建完应自动选中) -> 点「好」切换
	panel.panel_create_new_user.line_edit.text = "probe_new_user"
	panel.panel_create_new_user._on_button_ok_pressed()
	await a.wait(0.2)
	_check(a, "新用户已创建", Global.user_manager.all_user_name.has("probe_new_user"),
		str(Global.user_manager.all_user_name))
	if panel.curr_user_button == null:
		_check(a, "新用户已被自动选中", false, "curr_user_button 为空")
		_finish(a)
		return
	_check(a, "新用户已被自动选中（否则点「好」会切回旧档）",
		panel.curr_user_button.user_name_on_curr_button == "probe_new_user",
		str(panel.curr_user_button.user_name_on_curr_button))
	panel._on_button_ok_pressed()
	await a.wait(0.3)
	_check(a, "已切到新用户", Global.user_manager.curr_user_name == "probe_new_user",
		str(Global.user_manager.curr_user_name))
	_check(a, "新用户进度为 0", state.get_max_success_adventure_level() == 0,
		str(state.get_max_success_adventure_level()))
	_check_visible(a, menu, PATH_GARDEN, false, "切到 0 进度新用户")
	_check_visible(a, menu, PATH_ALMANAC, false, "切到 0 进度新用户")
	_check_visible(a, menu, PATH_SHOP, false, "切到 0 进度新用户")

	_finish(a)


## 逐个模式按钮核对「置灰而非隐藏」
func _check_mode(a, menu: Node, cleared: int) -> void:
	for path: String in MODE_BUTTONS:
		var btn := menu.get_node_or_null(path) as TextureButton
		if btn == null:
			_check(a, path + " 存在", false, "节点缺失")
			continue
		var need: int = MODE_BUTTONS[path]
		var unlocked: bool = cleared >= need
		_check(a, "%s 始终可见（门槛 %d）" % [path, need], btn.visible, str(btn.visible))
		var want_color: Color = Color.WHITE if unlocked else LOCKED_COLOR
		_check(a, "%s 通关 %d 关时的颜色" % [path, cleared], btn.modulate == want_color,
			"实际=%s 期望=%s" % [str(btn.modulate), str(want_color)])


func _check_visible(a, menu: Node, path: String, want: bool, tag: String = "") -> void:
	var btn := menu.get_node_or_null(path) as TextureButton
	if btn == null:
		_check(a, path + " 存在", false, "节点缺失")
		return
	var label := "%s visible=%s" % [path, str(want)]
	if tag != "":
		label += "（%s）" % tag
	_check(a, label, btn.visible == want, "实际 visible=" + str(btn.visible))


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[MENUUNLOCK] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 把当前存档改写成「已通关冒险模式 1-1 ~ 第 upto 关」
func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}
#endregion
