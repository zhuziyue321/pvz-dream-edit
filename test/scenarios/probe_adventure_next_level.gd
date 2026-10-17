extends RefCounted
## 探针：冒险模式「没有选关界面，按进度只能打下一关」
## 覆盖（都是「编译门禁抓不到、只能跑起来才知道」的那类）：
##   1. 新档点主菜单的冒险木牌（走完整僵尸手过场）-> 直接进 1-1，不再经过选关界面
##   2. 通关 1-1 后再点 -> 进的是 1-2（进度 +1），且存档键沿用老口径
##   3. 本周目全通（5-10）后 `advance_adventure_round()` -> 第 2 周目：该打的那一关回到 1-1，
##      历史最高仍停在 50（解锁一个都不丢），再点木牌真进得去 1-1
##   4. 木牌上显示的关卡号 == 点下去实际进的那一关（进度换算只有一套口径）
##   5. 二周目进的是这一关**自己的脚本**（adventure_XX_YY_round2.gd），用满 5 行草皮那张地图
##      （原版口径，见 docs/参考存档/二周目.md）
##
## 为什么值得单开一条：**没有选关界面之后，「进哪一关」这件事只剩代码里一句换算**
## （GlobalGameState.build_curr_adventure_level_para），玩家看不到、点不选；
## 换算写错（页码 / 关卡号算错 / 拿历史最高当本周目进度）会静默把玩家的通关进度挪位 ——
## 存档键错了照样能玩，只是「通关 1-2 写成了 1-3」，没有任何报错。
## 机器可读汇总：最后一行 [ADVNEXT] result=PASS|FAIL failed=<n>

const START_MENU_SCENE := "res://src/menus/start_menu/start_menu.tscn"
const ADVENTURE_LEVEL_DIR := "res://src/levels/mode_adventure/"
## 一周目 / 二周目的 1-1 各该用哪张地图：二周目起满 5 行草皮（map_front）
const MAP_1_1_FIRST_ROUND := "res://data/map/map_front_1row.tres"
const MAP_1_1_SECOND_ROUND := "res://data/map/map_front.tres"
## 主游戏场景槽位：进关后必须落在其中之一（关卡自己按地图数据挑槽位）
const MAIN_GAME_SLOTS: Array[MainSceneRegistry.MainScenes] = [
	MainSceneRegistry.MainScenes.MainGameFront,
	MainSceneRegistry.MainScenes.MainGameBack,
	MainSceneRegistry.MainScenes.MainGameRoof,
]
## 抽查的关卡存档键（**写死**，不用 get_adventure_save_game_name 反推 —— 那样算错也照样过）：
##   1-1 是 V2 关卡（save_key 写在关卡脚本里）；1-2 起是 V1，靠「页码 + 4 位关卡号」现场拼；
##   5-10 的页码必须是 4（"101_4_0050"），页码算错在这里就会露出来。
const SAMPLE_SAVE_NAMES: Dictionary[int, String] = {
	1: "101_0_0001",
	2: "101_0_0002",
	50: "101_4_0050",
}
## STEP4 抽查的进度档位：新档 / 刚通关 1-1 / 2-4 / 4-4 / 5-9 / 本周目全通
const SAMPLE_CLEARED: Array[int] = [0, 1, 13, 33, 49, 50]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 冒险模式：按进度只能打下一关 ==========")
	## 等主菜单自身初始化完（按钮滑入动画）再动它
	await a.wait_stable("/root/StartMenu/BG_Right/Menu/Button1", 8.0)

	var state := Global.global_game_state
	## 探针自己写档前先把周目钉在首周目：万一跑批复用了一份进过二周目的存档，后面的断言会全部错位
	state.curr_adventure_round = GlobalGameState.DEFAULT_ADVENTURE_ROUND

	# ------------------------------------------------ STEP1 新档：真点木牌
	a.log("STEP1 新档点冒险木牌（先播 3 秒过场，再切场景）")
	_mark_cleared(state, 0)
	await a.click_first("Menu/Button1")
	if not await a.wait_scene("main_game", 20.0):
		_check(a, "新档点木牌直接进关卡", false,
			"当前场景 = " + str(a.get_tree().current_scene.scene_file_path))
		_finish(a)
		return
	_check(a, "新档点木牌直接进关卡（不再经过选关界面）", true)
	_check_level_para(a, 1, "新档")
	_check_map_data(a, MAP_1_1_FIRST_ROUND, "一周目 1-1")

	## 回主菜单：后面几步从主菜单那一侧问，不必反复等 3 秒过场
	if not await _back_to_start_menu(a):
		_finish(a)
		return

	# ------------------------------------------------ STEP2 通关 1-1 后 -> 1-2
	a.log("STEP2 通关 1-1 后再点木牌（应进 1-2）")
	_mark_cleared(state, 1)
	_check(a, "本周目已通关的最大冒险关卡序号 = 1",
		state.get_adventure_round_cleared_level() == 1,
		str(state.get_adventure_round_cleared_level()))
	if not _press_adventure(a):
		_finish(a)
		return
	_check_level_para(a, 2, "通关 1-1 后")

	## 点一次木牌就会切去关卡：下一步要再点，先回主菜单
	if not await _back_to_start_menu(a):
		_finish(a)
		return

	# ------------------------------------------------ STEP3 本周目全通 -> 进第 2 周目
	a.log("STEP3 本周目全通（5-10）后进第 2 周目（应回到 1-1，解锁全保留）")
	_mark_cleared(state, 50)
	_check(a, "全通后本周目进度 = 50",
		state.get_adventure_round_cleared_level() == 50, str(state.get_adventure_round_cleared_level()))
	_check(a, "全通后该打的仍是 5-10（夹到最后一关，不会算出 6-1）",
		state.get_curr_adventure_level_to_play() == 50, str(state.get_curr_adventure_level_to_play()))

	_check(a, "进下一周目返回 true", state.advance_adventure_round())
	_check(a, "周目数 = 2", state.curr_adventure_round == 2, str(state.curr_adventure_round))
	_check(a, "第 2 周目本周目进度归零", state.get_adventure_round_cleared_level() == 0,
		str(state.get_adventure_round_cleared_level()))
	_check(a, "历史最高仍是 50（解锁门全都不受影响）",
		state.get_max_success_adventure_level() == 50, str(state.get_max_success_adventure_level()))
	_check(a, "第 2 周目该打的是 1-1", state.get_curr_adventure_level_to_play() == 1,
		str(state.get_curr_adventure_level_to_play()))
	_check(a, "本周目没全通时再进一次不生效（幂等）", not state.advance_adventure_round())
	_check(a, "幂等调用不会把周目继续往上加", state.curr_adventure_round == 2,
		str(state.curr_adventure_round))

	## 真点一次木牌：二周目从 1-1 开打
	if not _press_adventure(a):
		_finish(a)
		return
	if not await a.wait_scene("main_game", 20.0):
		_check(a, "第 2 周目点木牌进得了关卡", false,
			"当前场景 = " + str(a.get_tree().current_scene.scene_file_path))
		_finish(a)
		return
	_check_level_para(a, 1, "第 2 周目")
	_check_map_data(a, MAP_1_1_SECOND_ROUND, "二周目 1-1")

	## 回主菜单（STEP4 纯换算，不碰场景，但留个干净现场）
	await _back_to_start_menu(a)

	# ------------------------------------------------ STEP4 木牌号 == 实际进的那一关
	a.log("STEP4 木牌上显示的关卡号 == 点下去进的那一关（抽查几档进度）")
	state.curr_adventure_round = GlobalGameState.DEFAULT_ADVENTURE_ROUND
	for cleared: int in SAMPLE_CLEARED:
		_mark_cleared(state, cleared)
		var round_cleared: int = state.get_adventure_round_cleared_level()
		var board_level: int = ConstUnlockLevel.get_adventure_button_level(round_cleared)
		var para: ResourceLevelData = state.build_curr_adventure_level_para()
		var entered: int = para.get_adventure_level_index() if para != null else -1
		_check(a, "通关到 %d 关时：木牌显示 %s，实际进 %s" % [
			cleared,
			ConstUnlockLevel.get_adventure_level_name(board_level),
			ConstUnlockLevel.get_adventure_level_name(entered)],
			entered == board_level)

	_finish(a)


#region 断言与工具
## 进关参数逐项核对：进的是哪一关、存档键是什么、落在哪个主游戏场景
func _check_level_para(a, expect_level: int, label: String) -> void:
	var para: ResourceLevelData = Global.game_para
	if para == null:
		_check(a, label + "：拼出了进关参数", false, "Global.game_para = null")
		return
	var level_name := ConstUnlockLevel.get_adventure_level_name(expect_level)

	var script_path := ""
	var para_script := para.get_script() as Script
	if para_script != null:
		script_path = para_script.resource_path
	## 期望的脚本**按当前周目**取：二周目及以后这一关加载的是它自己的脚本
	## （adventure_XX_YY_round2.gd，见 LevelRegistry.ROUND_VARIANT_SUFFIX 与 docs/参考存档/二周目.md）
	var expect_script := ADVENTURE_LEVEL_DIR + LevelRegistry.get_adventure_level_id(
		expect_level, Global.global_game_state.curr_adventure_round) + ".gd"
	_check(a, "%s：进的是 %s（%s）" % [label, level_name, expect_script.get_file()],
		script_path == expect_script, script_path)

	_check(a, "%s：关卡序号 = %d" % [label, expect_level],
		para.get_adventure_level_index() == expect_level, str(para.get_adventure_level_index()))
	_check(a, "%s：mode 仍是冒险模式" % label,
		para.game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure, str(para.game_mode))

	var expect_save := str(SAMPLE_SAVE_NAMES.get(expect_level, ""))
	if expect_save != "":
		_check(a, "%s：存档键 = %s" % [label, expect_save],
			para.save_game_name == expect_save, para.save_game_name)

	_check(a, "%s：落在主游戏场景槽位（%s）" % [label, str(para.game_sences)],
		MAIN_GAME_SLOTS.has(para.game_sences))


## 进关后地图数据该是哪一张：主游戏场景在 _enter_tree 就 resolve_map_data() 换过图了，
## 所以站在关卡里读 game_para.map_data 拿到的就是真正在用的那张
func _check_map_data(a, expect_path: String, label: String) -> void:
	var para: ResourceLevelData = Global.game_para
	var actual := ""
	if para != null and para.map_data != null:
		actual = para.map_data.resource_path
	_check(a, "%s：地图 = %s" % [label, expect_path.get_file()], actual == expect_path, actual)


## 从主菜单那一侧进关：调木牌点下去真正走的那一段（过场已在 STEP1 验过）
func _press_adventure(a) -> bool:
	var menu: Node = a.get_node_or_null("/root/StartMenu")
	if menu == null or not menu.has_method("_start_adventure_level"):
		_check(a, "（前置）主菜单在场上", false, str(menu))
		return false
	menu._start_adventure_level()
	return true


## 主菜单点木牌会真的切去关卡：想再点一次就先回主菜单
func _back_to_start_menu(a) -> bool:
	GlobalUtils.change_scene(START_MENU_SCENE)
	if not await a.wait_scene("start_menu", 20.0):
		_check(a, "（前置）回得到主菜单", false)
		return false
	await a.wait(1.0)
	return true


## 把冒险模式写成「本周目通关到第 upto 关」（upto = 0 即本周目一关没通）
## Round 键与真通关写的是同一个（见 MgmSaveManager.update_level_state_data_success）
func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data[state.get_adventure_save_game_name(i)] = {
			"IsSuccess": true,
			GlobalGameState.LEVEL_STATE_DATA_ROUND_KEY: state.curr_adventure_round,
		}


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[ADVNEXT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
