extends RefCounted
## 探针：迷你游戏第 3 关「拉霸」(Slot Machine)
##
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_slot_machine -Windowed
##
## 覆盖：
##   ① UI 落位：只服务这一关的 UI 已挪到关卡脚本同目录
##      `src/levels/mode_minigame/minigame_03_slot_machine_ui.gd` —— 旧路径不存在、新路径能实例化出
##      SlotMachineUI，且它没有被 LevelRegistry 当成一关（识别走继承链白名单，见 is_level_script）
##   ② 开局：本关不选卡 / 没铲子 / 没小推车 / 没 zombies；UI 挂在 CanvasLayerUI 下，
##      本金 2000 阳光、目标「累计收集 2000」
##   ③ 拉杆：真点一次拉杆（屏幕中心真实鼠标）→ 扣 25 阳光、转轮停下、结果必居其一
##      （加阳光 / 免费植物 / 提示「再拉一次！」）
##   ④ 通关：累计收集到 2000 → 拉杆禁用、提示「目标达成！」→ 掉奖杯 → 点奖杯进结算（切场景）
## 机器可读汇总：最后一行 [SLOT] result=PASS|FAIL failed=<n>
##
## 注：转轮结果是随机的（7 种符号），断言只写**确定性**的那部分
##     （见 docs/AI调试通道.md 踩坑表：不要把断言压在随机结果上）。

const LEVEL := "res://src/levels/mode_minigame/minigame_03_slot_machine.gd"
## 本次搬家后的 UI 路径（验收项：src/ui/ 下不再有它的踪影）
const UI_PATH := "res://src/levels/mode_minigame/minigame_03_slot_machine_ui.gd"
const OLD_UI_PATH := "res://src/ui/mini_game/slot_machine_ui.gd"
const TARGET_SUN := 2000
const SPIN_COST := 25

## 可能出现的所有结算提示（与 slot_machine_ui.gd 的文案一一对应）
const EXPECTED_ADVICE: Array[String] = [
	"阳光大奖！",
	"钻石大奖！",
	"三个图案相同！三株免费植物！",
	"两个图案相同！奖励阳光！",
	"两个图案相同！钻石！",
	"两个图案相同！一株免费植物！",
	"再拉一次！",
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 拉霸（迷你游戏 03）==========")

	# ---------------------------------------------- STEP1 UI 落位
	a.log("STEP1 拉霸 UI 已挪到关卡侧")
	_check(a, "旧路径 " + OLD_UI_PATH + " 已不存在",
		not ResourceLoader.exists(OLD_UI_PATH, "Script"), OLD_UI_PATH)
	var script = load(UI_PATH) as GDScript
	_check(a, "新路径能加载出脚本 " + UI_PATH, script != null, UI_PATH)
	if script == null:
		_finish(a)
		return
	var probe_inst: Node = script.new()
	_check(a, "脚本实例化出来是 Control（能当 UI 节点用）", probe_inst is Control,
		str(script.get_instance_base_type()))
	probe_inst.free()
	LevelRegistry.rescan()
	_check(a, "本关仍在注册表里",
		LevelRegistry.has_level("minigame_03_slot_machine"),
		LevelRegistry.get_level_path("minigame_03_slot_machine"))
	_check(a, "UI 脚本没被 LevelRegistry 当成一关（script/ 被扫描器跳过）",
		not LevelRegistry.has_level("slot_machine_ui"), "slot_machine_ui")
	_check(a, "src/ui/ 下没有 mini_game 目录的残留",
		not DirAccess.dir_exists_absolute("res://src/ui/mini_game"), "res://src/ui/mini_game")

	# ---------------------------------------------- STEP2 关卡数据
	a.log("STEP2 关卡数据：不选卡 / 没铲子 / 没推车 / 没僵尸")
	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	_check(a, "存档键沿用 " + para.save_key, para.save_key == "102_1_0021", para.save_key)
	_check(a, "不能选卡", para.can_choosed_card == false, str(para.can_choosed_card))
	_check(a, "卡槽模式 Null", para.card_mode == ConstLevelData.E_CardMode.Null, str(para.card_mode))
	_check(a, "不给铲子", para.is_shovel == false, str(para.is_shovel))
	_check(a, "没有小推车", para.is_lawn_mover == false, str(para.is_lawn_mover))
	_check(a, "没有僵尸", para.monster_mode == ConstLevelData.E_MonsterMode.Null, str(para.monster_mode))
	_check(a, "本金阳光 = " + str(TARGET_SUN), para.start_sun == TARGET_SUN, str(para.start_sun))

	# ---------------------------------------------- STEP3 进关卡
	a.log("STEP3 进关卡（本关自己跳过选卡，不用点「开始游戏」）")
	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)
	var mg = Global.main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "Global.main_game 为空")
		_finish(a)
		return

	var ui := await _wait_ui(a, mg, 40.0)
	if ui == null:
		_check(a, "拉霸 UI 已挂到 CanvasLayerUI 下", false, "40 秒内没等到")
		_finish(a)
		return
	a.log("  UI 节点: " + str(ui.get_path()))
	_check(a, "拉霸 UI 挂在主游戏的 CanvasLayerUI 下", ui.get_parent() == mg.canvas_layer_ui,
		str(ui.get_parent()))
	_check(a, "UI 的脚本就是新路径那份", ui.get_script() == script, str(ui.get_script().resource_path))

	# ---------------------------------------------- STEP4 开局状态
	a.log("STEP4 开局状态：三列转轮 + 阳光 / 目标")
	_check(a, "三列转轮都在", ui.get_node_or_null("Overlay/Reel1") != null
		and ui.get_node_or_null("Overlay/Reel2") != null
		and ui.get_node_or_null("Overlay/Reel3") != null)
	_check(a, "本金 " + str(TARGET_SUN) + " 阳光", ui._sun_value == TARGET_SUN, str(ui._sun_value))
	_check(a, "累计收集从 0 起算", ui._total_earned == 0, str(ui._total_earned))
	_check(a, "目标是累计收集 " + str(TARGET_SUN), ui._target_sun == TARGET_SUN, str(ui._target_sun))
	_check(a, "转轮初始都有图案", ui._reel_icon[0].texture != null and ui._reel_icon[1].texture != null
		and ui._reel_icon[2].texture != null)
	a.log("  阳光标签: " + str(ui._sun_label.text))
	a.log("  提示: " + str(ui._advice_label.text))

	# ---------------------------------------------- STEP5 拉一次
	a.log("STEP5 真点一次拉杆：扣 " + str(SPIN_COST) + " 阳光 → 转起来 → 停下 → 结果生效")
	var btn: Button = ui.get_node_or_null("Overlay/PullButton")
	if btn == null:
		_check(a, "找得到拉杆按钮", false, "Overlay/PullButton 不存在")
		_finish(a)
		return
	var sun_before: int = ui._sun_value
	var earned_before: int = ui._total_earned
	var plants_before := _count_plants(mg)

	var center: Vector2 = a.screen_center(btn)
	a.log("  拉杆按钮屏幕中心: " + str(center))
	await a.click(center.x, center.y)

	## 先等这一下真的被吃到（阳光少了 25）；点不到就退回直接触发 pressed
	var got_pull := await _wait_pull_started(a, ui, sun_before, 6.0)
	if not got_pull:
		a.log("  !! 真实点击没生效，退回直接触发 pressed")
		await a.press_first("PullButton")
		got_pull = await _wait_pull_started(a, ui, sun_before, 6.0)
	_check(a, "点下拉杆：阳光扣了 " + str(SPIN_COST), got_pull,
		"扣前=%d 扣后=%d" % [sun_before, ui._sun_value])

	var stopped := await _wait_spin_end(a, ui, 20.0)
	_check(a, "转轮会自己停下来（约 1 秒）", stopped, "20 秒内没停")

	var plants_after := _count_plants(mg)
	var advice: String = ui._advice_label.text
	a.log("  结果提示: " + advice)
	a.log("  阳光 %d -> %d，累计收集 %d -> %d，场上植物 %d -> %d"
		% [sun_before, ui._sun_value, earned_before, ui._total_earned, plants_before, plants_after])
	_check(a, "结算提示是拉霸那套文案之一", EXPECTED_ADVICE.has(advice), advice)
	_check(a, "阳光不会变成负数", ui._sun_value >= 0, str(ui._sun_value))
	_check(a, "结果生效：加阳光 或 免费植物 或 提示再拉一次",
		ui._sun_value > sun_before - SPIN_COST
		or plants_after > plants_before
		or advice == "再拉一次！",
		"阳光=%d 植物=%d 提示=%s" % [ui._sun_value, plants_after, advice])

	# ---------------------------------------------- STEP6 再拉一次（多拉几把看结论稳不稳）
	a.log("STEP6 再连拉两次，逐把记账（结果随机，只核对记账与可用性）")
	for i in range(2):
		if btn.disabled:
			a.log("  拉杆已禁用（第 %d 把），跳过" % (i + 1))
			break
		var s0: int = ui._sun_value
		var e0: int = ui._total_earned
		var p0 := _count_plants(mg)
		var c2: Vector2 = a.screen_center(btn)
		await a.click(c2.x, c2.y)
		var ok2 := await _wait_pull_started(a, ui, s0, 6.0)
		if ok2:
			await _wait_spin_end(a, ui, 20.0)
		a.log("  第 %d 把：点击生效=%s 阳光 %d -> %d，累计收集 %d -> %d，植物 %d -> %d，提示=%s"
			% [i + 1, str(ok2), s0, ui._sun_value, e0, ui._total_earned, p0, _count_plants(mg),
				ui._advice_label.text])
		_check(a, "第 %d 把的结算提示合法" % (i + 1), EXPECTED_ADVICE.has(ui._advice_label.text),
			ui._advice_label.text)

	# ---------------------------------------------- STEP7 达标 -> 奖杯 -> 结算
	a.log("STEP7 补满累计收集 -> 目标达成 -> 奖杯 -> 通关结算")
	EventBus.push_event("add_sun_value", [TARGET_SUN])
	var won := await _wait_win(a, ui, 10.0)
	_check(a, "累计收集达标后判胜利", won, "total_earned=%d/%d" % [ui._total_earned, ui._target_sun])
	_check(a, "达标后拉杆禁用", btn.disabled, str(btn.disabled))
	a.log("  提示: " + str(ui._advice_label.text))

	var trophy: Node = await _wait_trophy(a, 15.0)
	_check(a, "掉出了奖杯", trophy != null, "15 秒内没等到奖杯")
	if trophy != null:
		var tb: BaseButton = trophy.get_node_or_null("TrophyButton")
		if tb == null:
			_check(a, "奖杯上有可点的按钮", false, "TrophyButton 不存在")
		else:
			var ui_gone := await _wait_ui_gone(a, mg, ui, 5.0)
			_check(a, "拉霸 UI 已经收走（queue_free 生效）", ui_gone,
				"5 秒后 CanvasLayerUI 下还有它")
			await a.press_first("TrophyButton")
			var scene_before: Node = a.get_tree().current_scene
			var settled := await _wait_scene_left(a, scene_before, 30.0)
			_check(a, "点开奖杯后进通关结算（场景切走）", settled,
				str(a.get_tree().current_scene))
	else:
		_failed += 1

	_finish(a)


#region 工具
## 等拉霸 UI 出现（它挂在 CanvasLayerUI 下，脚本是新路径那份）
func _wait_ui(a, mg, timeout: float) -> Control:
	var waited := 0.0
	while waited < timeout:
		if is_instance_valid(mg) and mg.canvas_layer_ui != null:
			for c in mg.canvas_layer_ui.get_children():
				if is_instance_valid(c) and c.get_script() != null \
					and c.get_script().resource_path == UI_PATH:
					return c as Control
		await a.wait(0.5)
		waited += 0.5
	return null


## 等拉霸 UI 被 queue_free 掉（_queue_free 是延后的，掉奖杯那一刻可能还挂在树上）
func _wait_ui_gone(a, mg, ui: Node, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		## 先判实例还活着：对象已经被 free 掉之后再去 Arrays.has() 它会报
		## "TypedArray 里塞了失效实例"（引擎按值校验，连 free 过一次也算）
		if not is_instance_valid(ui) or not is_instance_valid(mg) or mg.canvas_layer_ui == null:
			return true
		if not mg.canvas_layer_ui.get_children().has(ui):
			return true
		await a.wait(0.25)
		waited += 0.25
	return false


## 等这一下拉杆真的被吃到（阳光少了 SPIN_COST）
func _wait_pull_started(a, ui, sun_before: int, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if ui._sun_value == sun_before - SPIN_COST or ui._is_spinning:
			return true
		await a.wait(0.25)
		waited += 0.25
	return false


## 等转轮停稳
func _wait_spin_end(a, ui, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if not ui._is_spinning and ui._spin_timer == null:
			return true
		await a.wait(0.2)
		waited += 0.2
	return false


## 等累计收集达标后的胜利判定
func _wait_win(a, ui, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if ui._has_won:
			return true
		await a.wait(0.25)
		waited += 0.25
	return false


## 等奖杯掉出来
func _wait_trophy(a, timeout: float) -> Node:
	var waited := 0.0
	while waited < timeout:
		var found := _find_trophy(a.get_tree().root)
		if found != null:
			return found
		await a.wait(0.5)
		waited += 0.5
	return null


func _find_trophy(root: Node) -> Node:
	for c in root.get_children():
		if c is Trophy:
			return c
		var deeper := _find_trophy(c)
		if deeper != null:
			return deeper
	return null


## 等场景离开 MainGame（通关结算会切走）
func _wait_scene_left(a, scene_before: Node, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		var now: Node = a.get_tree().current_scene
		if now != scene_before:
			return true
		if Global.main_game == null:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 场上种着的植物数
func _count_plants(mg) -> int:
	var n := 0
	if mg == null or mg.plant_cell_manager == null:
		return 0
	for row in mg.plant_cell_manager.all_plant_cells:
		for cell in row:
			if is_instance_valid(cell) and cell.get_curr_plant_num() > 0:
				n += 1
	return n


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[SLOT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
