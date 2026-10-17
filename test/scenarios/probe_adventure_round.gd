extends RefCounted
## 探针：冒险模式二周目（通关 5-10 后从 1-1 重打一轮）
## 覆盖：
##   1. 存档默认值 / 老存档兼容：记录里没有 "Round" 键时当周目 1（旧档不会被判成"没过过"）
##   2. 「本周目进度」与「历史最高」两条口径分家：进二周目后本周目回到 0，历史最高仍是 50
##      （解锁门——铲子 / 图鉴 / 花园 / 商店 / 迷你 / 解谜 / 生存——一个都不掉）
##   3. `advance_adventure_round()` 的前置（本周目全通）与幂等
##   4. 主菜单木牌：一周目不显示「N周目」，二周目显示且文案跟周目数一致
##   5. 二周目起 1-1 / 1-2 / 1-3 换成满 5 行草皮那张图（原版口径），
##      且**不泄漏**到 1-4（本来就满草皮）与 5-10（僵王关用 map_boss）
##
## 为什么值得单开一条：二周目的「进度清零」不是删记录、而是按 Round 过滤算出来的（见
## GlobalGameState.get_adventure_round_cleared_level）。算错的表现全是**静默**的：
## 要么二周目一进去又被丢回 5-10，要么已解锁的东西被清光，要么草皮换错关卡。
## 机器可读汇总：最后一行 [ADVROUND] result=PASS|FAIL failed=<n>

const START_MENU_SCENE := "res://src/menus/start_menu/start_menu.tscn"
## 木牌上的周目标记（见 start_menu.tscn / StartMenuRoot._apply_adventure_round_text）
const ROUND_LABEL_PATH := "/root/StartMenu/BG_Right/Menu/Button1/LevelText/RoundText"
const LEVEL_VIEW_PATH := "/root/StartMenu/BG_Right/Menu/Button1/LevelText"
## 抽查的各关地图（一周目 / 二周目两列）：
##   1-1 一周目 1 行草皮、1-2 / 1-3 三行草皮、二周目全给满（map_front）；
##   1-4 本来就是满草皮（不指定 map_data，走 game_sences 的默认图）；
##   5-10 是僵王关（map_boss），二周目也不该被换成草坪图。
const MAP_CASES: Array[Dictionary] = [
	{"level": 1, "first": "map_front_1row.tres", "second": "map_front.tres"},
	{"level": 2, "first": "map_front_5row.tres", "second": "map_front.tres"},
	{"level": 3, "first": "map_front_5row.tres", "second": "map_front.tres"},
	{"level": 4, "first": "map_front.tres", "second": "map_front.tres"},
	{"level": 50, "first": "map_boss.tres", "second": "map_boss.tres"},
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 冒险模式：二周目 ==========")
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)

	var state := Global.global_game_state
	var menu: Node = a.get_node_or_null("/root/StartMenu")

	# ------------------------------------------------ STEP1 存档字段与老档兼容
	a.log("STEP1 周目字段：默认值 / 老存档兼容 / 清回默认")
	_check(a, "默认周目 = 1", state.DEFAULT_ADVENTURE_ROUND == 1, str(state.DEFAULT_ADVENTURE_ROUND))
	_check(a, "老存档记录（没有 Round 键）当周目 1",
		GlobalGameState.get_round_on_level_state_data({"IsSuccess": true}) == 1,
		str(GlobalGameState.get_round_on_level_state_data({"IsSuccess": true})))
	_check(a, "带 Round 的记录按记录算",
		GlobalGameState.get_round_on_level_state_data(
			{"IsSuccess": true, GlobalGameState.LEVEL_STATE_DATA_ROUND_KEY: 3}) == 3)

	## 一份「一周目全通」的老存档：每条记录都不带 Round 键（模拟旧档）
	state.curr_adventure_round = GlobalGameState.DEFAULT_ADVENTURE_ROUND
	state.curr_all_level_state_data = {}
	for i in range(1, ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL + 1):
		state.curr_all_level_state_data[state.get_adventure_save_game_name(i)] = {"IsSuccess": true}
	_check(a, "旧档在一周目下算全通（本周目进度 = 50）",
		state.get_adventure_round_cleared_level() == 50, str(state.get_adventure_round_cleared_level()))

	# ------------------------------------------------ STEP2 两条口径分家
	a.log("STEP2 进二周目：本周目进度归零、历史最高与解锁门全保留")
	_check(a, "一周目不算「二周目及以后」", not state.is_from_second_round())
	_check(a, "本周目全通判定为真", state.is_adventure_round_finished())
	_check(a, "进下一周目返回 true", state.advance_adventure_round())
	_check(a, "周目数 = 2", state.curr_adventure_round == 2, str(state.curr_adventure_round))
	_check(a, "已是二周目", state.is_from_second_round())
	_check(a, "本周目进度归零", state.get_adventure_round_cleared_level() == 0,
		str(state.get_adventure_round_cleared_level()))
	_check(a, "历史最高仍 = 50", state.get_max_success_adventure_level() == 50,
		str(state.get_max_success_adventure_level()))
	_check(a, "该打的是 1-1", state.get_curr_adventure_level_to_play() == 1,
		str(state.get_curr_adventure_level_to_play()))

	## 解锁门一个都不能掉（二周目继承：这些读的都是历史最高）
	_check(a, "铲子仍解锁（1-4）", state.is_shovel_unlocked())
	_check(a, "图鉴仍解锁（2-4）", state.is_almanac_unlocked())
	_check(a, "花园仍解锁（5-5）", state.is_garden_unlocked())
	_check(a, "商店仍解锁（3-4）", state.is_shop_unlocked())
	_check(a, "商店扩展到顶（5-10）", state.get_shop_expand_stage() == 3,
		str(state.get_shop_expand_stage()))
	_check(a, "迷你游戏仍解锁", state.is_mode_unlocked(MainSceneRegistry.MainScenes.ChooseLevelMiniGame))
	_check(a, "解谜模式仍解锁", state.is_mode_unlocked(MainSceneRegistry.MainScenes.ChooseLevelPuzzle))
	_check(a, "生存模式仍解锁", state.is_mode_unlocked(MainSceneRegistry.MainScenes.ChooseLevelSurvival))

	# ------------------------------------------------ STEP3 幂等
	a.log("STEP3 advance 的前置与幂等")
	_check(a, "本周目没全通时再进一次不生效", not state.advance_adventure_round())
	_check(a, "周目数没有继续往上加", state.curr_adventure_round == 2, str(state.curr_adventure_round))
	## 二周目通了 1-1（写 Round = 2）后：本周目进度 1、但离全通还差得远
	state.curr_all_level_state_data[state.get_adventure_save_game_name(1)] = {
		"IsSuccess": true, GlobalGameState.LEVEL_STATE_DATA_ROUND_KEY: 2,
	}
	_check(a, "二周目通关 1-1 后本周目进度 = 1",
		state.get_adventure_round_cleared_level() == 1, str(state.get_adventure_round_cleared_level()))
	_check(a, "本周目没全通（1-1 而已）", not state.is_adventure_round_finished())
	_check(a, "该打的是 1-2", state.get_curr_adventure_level_to_play() == 2,
		str(state.get_curr_adventure_level_to_play()))

	# ------------------------------------------------ STEP4 木牌文案
	## 现场只用「老档全通（记录不带 Round 键）」这一份存档，逐周目看木牌：
	##   周目 1 -> 本周目进度 50 -> 显示 5-10、不显示周目标记；
	##   周目 2 / 3 -> 本周目进度 0 -> 显示 1-1、显示「N周目」。
	## （一周目里「历史最高 50」与「显示 1-1」不可能同时成立：周目 1 时所有老记录都算本周目通过）
	a.log("STEP4 主菜单木牌上的周目标记")
	if menu == null:
		_check(a, "（前置）主菜单在场上", false)
	else:
		var label: Label = a.get_node_or_null(ROUND_LABEL_PATH) as Label
		var level_view: Control = a.get_node_or_null(LEVEL_VIEW_PATH) as Control
		var first: Label = a.get_node_or_null(LEVEL_VIEW_PATH + "/FirstNumber") as Label
		var second: Label = a.get_node_or_null(LEVEL_VIEW_PATH + "/SecondNumber") as Label
		if label == null or level_view == null or first == null or second == null:
			_check(a, "（前置）木牌上的节点在（LevelText / FirstNumber / SecondNumber / RoundText）", false,
				str(label) + " / " + str(level_view) + " / " + str(first) + " / " + str(second))
		else:
			## 先看新档：一关没通 -> 整块 LevelText 不显示（"开始冒险模式"那块木牌）
			state.curr_all_level_state_data = {}
			state.curr_adventure_round = 1
			menu._update_mode_lock_state()
			_check(a, "新档：木牌不显示关卡号（还没开打冒险模式）", not level_view.visible)

			## 老档全通
			state.curr_all_level_state_data = {}
			for i in range(1, ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL + 1):
				state.curr_all_level_state_data[state.get_adventure_save_game_name(i)] = {"IsSuccess": true}
			state.curr_adventure_round = 1
			menu._update_mode_lock_state()
			_check(a, "一周目：显示关卡号", level_view.visible)
			_check(a, "一周目：关卡号 = 5-10", first.text == "5" and second.text == "10",
				first.text + "-" + second.text)
			_check(a, "一周目：不显示周目标记", not label.visible)

			state.curr_adventure_round = 2
			menu._update_mode_lock_state()
			_check(a, "二周目：显示周目标记", label.visible)
			_check(a, "二周目：文案 = 2周目", label.text == "2周目", label.text)
			_check(a, "二周目：关卡号回到 1-1（本周目一关没通）",
				first.text == "1" and second.text == "1", first.text + "-" + second.text)

			state.curr_adventure_round = 3
			menu._update_mode_lock_state()
			_check(a, "三周目：文案跟着变（3周目）", label.text == "3周目", label.text)
			_check(a, "三周目：关卡号仍是 1-1", first.text == "1" and second.text == "1",
				first.text + "-" + second.text)

	# ------------------------------------------------ STEP5 二周目换底图
	a.log("STEP5 二周目起 1-1 / 1-2 / 1-3 满 5 行草皮（不泄漏到 1-4 与 5-10）")
	for case_data: Dictionary in MAP_CASES:
		var adventure_level: int = int(case_data["level"])
		state.curr_adventure_round = 1
		var first_map := _resolved_map_file(adventure_level)
		state.curr_adventure_round = 2
		var second_map := _resolved_map_file(adventure_level)
		_check(a, "%s 一周目地图 = %s" % [ConstUnlockLevel.get_adventure_level_name(adventure_level),
			str(case_data["first"])], first_map == str(case_data["first"]), first_map)
		_check(a, "%s 二周目地图 = %s" % [ConstUnlockLevel.get_adventure_level_name(adventure_level),
			str(case_data["second"])], second_map == str(case_data["second"]), second_map)

	# ------------------------------------------------ STEP6 端到端：真通关 5-10
	## 前面的 advance_adventure_round() 都是直接调的；这一步走真实结算入口
	## （GameContext.curr_main_game.shortcut_win_main_game() = Ctrl+D 0），看 win_main_game() 到底认不认得 5-10。
	a.log("STEP6 端到端：真打完 5-10 -> 进第 2 周目（并落盘）")
	state.curr_adventure_round = 1
	state.curr_all_level_state_data = {}
	for i in range(1, ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL):
		state.curr_all_level_state_data[state.get_adventure_save_game_name(i)] = {
			"IsSuccess": true, GlobalGameState.LEVEL_STATE_DATA_ROUND_KEY: 1,
		}
	_check(a, "现场：本周目打到 5-10（进度 = 49）",
		state.get_curr_adventure_level_to_play() == 50, str(state.get_curr_adventure_level_to_play()))
	var boss_para: ResourceLevelData = state.build_curr_adventure_level_para()
	if boss_para == null:
		_check(a, "（前置）拼得出 5-10 的进关参数", false)
		_finish(a)
		return
	Global.game_para = boss_para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(boss_para.game_sences))
	if not await a.wait_scene("main_game", 25.0):
		_check(a, "（前置）进得了 5-10", false, str(a.get_tree().current_scene.scene_file_path))
		_finish(a)
		return
	## 僵王关初始化慢（屋顶 + 僵王），等到主游戏真正建起来再通关
	var waited := 0.0
	while GameContext.curr_main_game == null and waited < 15.0:
		await a.wait(0.5)
		waited += 0.5
	if GameContext.curr_main_game == null:
		_check(a, "（前置）5-10 的主游戏已就绪", false)
		_finish(a)
		return
	await a.wait(2.0)
	GameContext.curr_main_game.shortcut_win_main_game()
	## 首次通关 5-10 会先跳商店（商店第三批扩展就在 5-10），周目应该已经 +1 了
	if not await a.wait_scene("store", 25.0):
		_check(a, "（前置）首次通关 5-10 进商店", false, str(a.get_tree().current_scene.scene_file_path))
	else:
		_check(a, "首次通关 5-10 进商店（原有行为不变）", true)
	_check(a, "win_main_game 自己进了第 2 周目", state.curr_adventure_round == 2,
		str(state.curr_adventure_round))
	_check(a, "第 2 周目进度归零", state.get_adventure_round_cleared_level() == 0,
		str(state.get_adventure_round_cleared_level()))
	_check(a, "历史最高 = 50", state.get_max_success_adventure_level() == 50,
		str(state.get_max_success_adventure_level()))
	_check(a, "第 2 周目该打的是 1-1", state.get_curr_adventure_level_to_play() == 1,
		str(state.get_curr_adventure_level_to_play()))

	## 落盘：重读一次存档，周目与进度都得还在（不能只改内存）
	Global.save_service.load_global_game_data()
	_check(a, "重读存档后周目仍是 2", state.curr_adventure_round == 2, str(state.curr_adventure_round))
	_check(a, "重读存档后该打的还是 1-1", state.get_curr_adventure_level_to_play() == 1,
		str(state.get_curr_adventure_level_to_play()))
	_check(a, "重读存档后历史最高仍是 50（解锁门不掉）",
		state.get_max_success_adventure_level() == 50, str(state.get_max_success_adventure_level()))
	## 5-10 的通关记录带上了本周目的轮次（进二周目前写的那一笔是 Round = 1）
	_check(a, "5-10 的通关记录已写入（Round = 1）",
		GlobalGameState.get_round_on_level_state_data(
			state.curr_all_level_state_data.get(state.get_adventure_save_game_name(50), {})) == 1)

	_finish(a)


#region 断言与工具
## 这一关在第 curr_adventure_round 周目真正会用的地图文件名
## （走 resolve_map_data()：与主游戏场景 _enter_tree 里那次调用是同一条路）
func _resolved_map_file(adventure_level: int) -> String:
	var para: ResourceLevelData = Global.global_game_state.build_adventure_level_para(adventure_level)
	if para == null:
		return "<拼不出进关参数>"
	para.resolve_map_data()
	if para.map_data == null:
		return "<没有地图数据>"
	return para.map_data.resource_path.get_file()


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[ADVROUND] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
