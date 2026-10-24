extends RefCounted
## 探针：迷你游戏第 3 关「拉霸」(Slot Machine) —— 原版机制移植版
##
## 用法：powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_slot_machine -Windowed
##
## 覆盖（括号里是原版出处，见 minigame_03_slot_machine_ui.gd 头部）：
##   ① UI 落位：只服务这一关的 UI 在关卡脚本同目录，且没被 LevelRegistry 当成一关
##   ② 关卡数据：不选卡 / 没铲子 / 没推车 / 没僵尸；本金 50 阳光（Board.cpp InitLevel）
##   ③ 机器构成：阳光银行 + 3 个种子包转轮（初始 向日葵/豌豆/寒冰豆）+ 覆盖层 + 拉杆
##   ④ 权重公式：豌豆权重随场上豌豆数 200→100、钻石 30、第 3 轮偏向前两轮 x1.5（确定性命中）
##   ⑤ 拉杆：真点一次拉杆 → 扣 25 阳光 → 转轮滚动约 5 秒后停 → 结算提示合法；
##      阳光不足 25 时拉杆不动（原版 TakeSunMoney 失败）
##   ⑥ 通关：阳光到 2000 → 判胜 → 掉奖杯 → 点奖杯进结算（切场景）；进度条口径 = 阳光/2000
## 机器可读汇总：最后一行 [SLOT] result=PASS|FAIL failed=<n>
##
## 注：转轮结果是随机的（6 种符号 + 权重随机），断言只写**确定性**的那部分
##     （见 docs/AI调试通道.md 踩坑表：不要把断言压在随机结果上）。

const LEVEL := "res://src/levels/mode_minigame/minigame_03_slot_machine.gd"
## 本次搬家后的 UI 路径（验收项：src/ui/ 下不再有它的踪影）
const UI_PATH := "res://src/levels/mode_minigame/minigame_03_slot_machine_ui.gd"
const OLD_UI_PATH := "res://src/ui/mini_game/slot_machine_ui.gd"
const PROVIDER_PATH := "res://src/levels/mode_minigame/minigame_03_slot_machine_progress_provider.gd"
const TARGET_SUN := 2000
const START_SUN := 50
const SPIN_COST := 25

## 可能出现的所有结算提示（与 slot_machine_ui.gd 的文案一一对应）+ 没中时的待机提示
const EXPECTED_ADVICE: Array[String] = [
	"钻石大奖！",
	"阳光大奖！",
	"三个图案相同！三株免费植物！",
	"两个图案相同！钻石！",
	"两个图案相同！奖励阳光！",
	"两个图案相同！一株免费植物！",
	"收集2000点阳光即可过关",
	"再拉一次！",
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 拉霸（迷你游戏 03，原版移植版）==========")

	# ---------------------------------------------- STEP1 UI 落位
	a.log("STEP1 拉霸 UI / 进度条数据源都在关卡侧")
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
	_check(a, "进度条数据源能加载 " + PROVIDER_PATH,
		load(PROVIDER_PATH) != null, PROVIDER_PATH)
	LevelRegistry.rescan()
	_check(a, "本关仍在注册表里",
		LevelRegistry.has_level("minigame_03_slot_machine"),
		LevelRegistry.get_level_path("minigame_03_slot_machine"))
	_check(a, "UI 脚本没被 LevelRegistry 当成一关",
		not LevelRegistry.has_level("slot_machine_ui"), "slot_machine_ui")
	_check(a, "进度条数据源没被 LevelRegistry 当成一关",
		not LevelRegistry.has_level("slot_machine_progress_provider"), "slot_machine_progress_provider")
	_check(a, "src/ui/ 下没有 mini_game 目录的残留",
		not DirAccess.dir_exists_absolute("res://src/ui/mini_game"), "res://src/ui/mini_game")

	# ---------------------------------------------- STEP2 关卡数据
	a.log("STEP2 关卡数据：不选卡 / 没铲子 / 没推车 / 没僵尸 / 本金 50")
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
	_check(a, "本金阳光 = " + str(START_SUN) + "（原版 Board.cpp InitLevel）",
		para.start_sun == START_SUN, str(para.start_sun))

	# ---------------------------------------------- STEP3 进关卡
	a.log("STEP3 进关卡（本关自己跳过选卡，不用点「开始游戏」）")
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)
	var mg = GameContext.curr_main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "GameContext.curr_main_game 为空")
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

	# ---------------------------------------------- STEP4 机器构成
	a.log("STEP4 机器构成：阳光银行 + 三个种子包转轮 + 覆盖层 + 拉杆")
	_check(a, "阳光银行在", ui.get_node_or_null("SunBank") != null)
	_check(a, "覆盖层在", ui.get_node_or_null("Overlay") != null)
	_check(a, "三个转轮都在", ui.get_node_or_null("Reel1") != null
		and ui.get_node_or_null("Reel2") != null
		and ui.get_node_or_null("Reel3") != null)
	_check(a, "拉杆热区在", ui.get_node_or_null("HandleButton") != null)
	_check(a, "初始符号 = 向日葵 / 豌豆 / 寒冰豆（Board.cpp InitLevel）",
		ui._curr_symbols[0] == 0 and ui._curr_symbols[1] == 1 and ui._curr_symbols[2] == 2,
		str(ui._curr_symbols))
	_check(a, "阳光标签显示本金 " + str(START_SUN),
		ui._sun_value_label.text == str(START_SUN), ui._sun_value_label.text)
	_check(a, "拉杆初始可用", not ui._handle_button.disabled, str(ui._handle_button.disabled))

	# ---------------------------------------------- STEP5 权重公式（确定性）
	a.log("STEP5 权重公式：豌豆 200→100 / 钻石 30 / 第 3 轮偏向 x1.5")
	var weights_no_peas: Array = ui._symbol_weights(0, 0)
	var weights_five_peas: Array = ui._symbol_weights(0, 5)
	_check(a, "场上 0 株豌豆时豌豆权重 = 200（原版 AnimateCurve 起点）",
		weights_no_peas[1] == 200, str(weights_no_peas[1]))
	_check(a, "场上 5 株豌豆时豌豆权重 = 100（原版 AnimateCurve 终点）",
		weights_five_peas[1] == 100, str(weights_five_peas[1]))
	_check(a, "钻石权重 = 30（原版写死）", weights_no_peas[5] == 30, str(weights_no_peas[5]))
	_check(a, "其余符号权重 = 100", weights_no_peas[0] == 100 and weights_no_peas[2] == 100
		and weights_no_peas[3] == 100 and weights_no_peas[4] == 100, str(weights_no_peas))
	ui._next_symbols[0] = 3
	ui._next_symbols[1] = 3
	var weights_third: Array = ui._symbol_weights(2, 0)
	_check(a, "第 3 个转轮：与前两轮即将出现的符号一致时权重 x1.5（坚果 100→150）",
		weights_third[3] == 150, str(weights_third[3]))
	_check(a, "第 3 个转轮：不一致的符号不吃加成（坚果已占用，向日葵仍 100）",
		weights_third[0] == 100, str(weights_third[0]))
	_check(a, "第 3 个转轮：钻石不吃加成（仍 30）", weights_third[5] == 30, str(weights_third[5]))
	ui._next_symbols[0] = 0
	ui._next_symbols[1] = 1

	# ---------------------------------------------- STEP6 真拉一次
	a.log("STEP6 真点一次拉杆：扣 25 阳光 → 转起来 → 停下 → 结果生效")
	var btn: Button = ui.get_node_or_null("HandleButton")
	if btn == null:
		_check(a, "找得到拉杆按钮", false, "HandleButton 不存在")
		_finish(a)
		return
	var sun_before: int = ui._sun_value

	var center: Vector2 = a.screen_center(btn)
	a.log("  拉杆热区屏幕中心: " + str(center))
	await a.click(center.x, center.y)

	## 先等这一下真的被吃到（阳光少了 25）；点不到就退回直接触发 pressed
	var got_pull := await _wait_pull_started(a, ui, sun_before, 6.0)
	if not got_pull:
		a.log("  !! 真实点击没生效，退回直接触发 pressed")
		await a.press_first("HandleButton")
		got_pull = await _wait_pull_started(a, ui, sun_before, 6.0)
	_check(a, "点下拉杆：阳光扣了 " + str(SPIN_COST), got_pull,
		"扣前=%d 扣后=%d" % [sun_before, ui._sun_value])

	var stopped := await _wait_spin_end(a, ui, 15.0)
	_check(a, "转轮会自己停下来（原版 300 帧 ≈ 5 秒）", stopped, "15 秒内没停")

	var advice: String = str(ui._curr_advice)
	a.log("  结果提示: " + advice)
	a.log("  阳光 %d -> %d，场上植物 %d 株"
		% [sun_before, ui._sun_value, _count_plants(mg)])
	_check(a, "结算提示是拉霸那套文案之一", EXPECTED_ADVICE.has(advice), advice)
	_check(a, "阳光不会变成负数", ui._sun_value >= 0, str(ui._sun_value))
	_check(a, "三个转轮停稳后都停在合法符号上",
		ui._curr_symbols[0] >= 0 and ui._curr_symbols[0] < 6
		and ui._curr_symbols[1] >= 0 and ui._curr_symbols[1] < 6
		and ui._curr_symbols[2] >= 0 and ui._curr_symbols[2] < 6, str(ui._curr_symbols))

	# ---------------------------------------------- STEP7 阳光不足
	a.log("STEP7 阳光不足 25 时拉杆拉不动（原版 TakeSunMoney 失败）")
	var sun_now: int = ui._sun_value
	if sun_now >= SPIN_COST:
		## 再拉一把把阳光花到 25 以下
		await a.click(center.x, center.y)
		await _wait_pull_started(a, ui, sun_now, 6.0)
		await _wait_spin_end(a, ui, 15.0)
		sun_now = ui._sun_value
	if sun_now < SPIN_COST:
		await a.click(center.x, center.y)
		await a.wait(0.5)
		_check(a, "阳光不足时点击不扣阳光", ui._sun_value == sun_now,
			"%d -> %d" % [sun_now, ui._sun_value])
	else:
		a.log("  阳光仍有 %d，跳过不足分支" % sun_now)

	# ---------------------------------------------- STEP8 达标 -> 奖杯 -> 结算
	a.log("STEP8 阳光补到 2000 -> 判胜 -> 奖杯 -> 通关结算")
	## 先把要用的数缓存下来：判胜后拉霸 UI 会被关卡流程收走，之后再读就是空引用
	var sun_before_win: int = ui._sun_value
	var target_sun: int = ui._target_sun
	EventBus.push_event("add_sun_value", [maxi(target_sun - sun_before_win, 0)])
	var won := await _wait_win(a, ui, 10.0)
	_check(a, "阳光达标后判胜利（UI 被收走 = 流程走完）", won,
		"sun=%d/%d" % [sun_before_win, target_sun])
	var progress_provider = para.progress_provider
	_check(a, "进度条口径 = 阳光 / 2000（过关时 100%）",
		progress_provider != null and absf(progress_provider.get_progress() - 100.0) < 0.01,
		str(progress_provider.get_progress() if progress_provider != null else -1.0))

	var trophy: Node2D = await _wait_trophy(a, 15.0)
	_check(a, "掉出了奖杯", trophy != null, "15 秒内没等到奖杯")
	if trophy != null:
		## 等奖杯抛到位再点（礼物盒会被抛一下，位置在变）
		await a.wait(1.5)
		var ui_gone := await _wait_ui_gone(a, mg, ui, 5.0)
		_check(a, "拉霸 UI 已经收走（queue_free 生效）", ui_gone,
			"5 秒后 CanvasLayerUI 下还有它")
		## 奖杯现在是一种战利品（LootRegistry 按名字取贴图生产的一个掉落物），
		## 没有 TrophyButton 了 —— 直接点它本体（见 Present.apply_icon_texture 的点击区）
		var scene_before: Node = a.get_tree().current_scene
		var settled := false
		for _attempt in range(3):
			if not is_instance_valid(trophy):
				break
			await a.click(trophy.global_position.x, trophy.global_position.y)
			settled = await _wait_scene_left(a, scene_before, 8.0)
			if settled:
				break
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
## ui 不加类型标注：判胜后它已经被释放，带类型的参数在传参那一步就会报
## "previously freed"（引擎按类型校验，连 free 过一次也算）
func _wait_ui_gone(a, mg, ui, timeout: float) -> bool:
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
		if not ui._is_spinning:
			return true
		await a.wait(0.2)
		waited += 0.2
	return false


## 等阳光达标后的胜利判定
func _wait_win(a, ui, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		## 拉霸 UI 被关卡流程收走 = 已经判胜（run_flow 在 game_finished 之后 queue_free 它）
		if not is_instance_valid(ui):
			return true
		if ui._has_won:
			return true
		await a.wait(0.25)
		waited += 0.25
	return false


## 等奖杯掉出来（奖杯现在是一种战利品：掉在掉落容器里，见 LootRegistry / gain_loot）
func _wait_trophy(a, timeout: float) -> Node2D:
	var waited := 0.0
	while waited < timeout:
		var found := _find_trophy(a.get_tree().root)
		if found != null:
			return found
		await a.wait(0.5)
		waited += 0.5
	return null


## 整棵树里「本关结算线」上的那个掉落物（is_level_complete_drop，见 mark_level_complete_drop）
func _find_trophy(root: Node) -> Node2D:
	for c in root.get_children():
		if "is_level_complete_drop" in c and bool(c.get("is_level_complete_drop")):
			return c as Node2D
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
		if GameContext.curr_main_game == null:
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
		a.log("  [NG] " + label + " " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[SLOT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
