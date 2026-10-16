extends RefCounted

## 模组搬到 `user://mods/` 后，class_name 不再注册为全局类，探针这里 preload 成常量再引用
const GloveMod := preload("res://mods_builtin/glove/glove_mod.gd")
const GloveSettings := preload("res://mods_builtin/glove/glove_settings.gd")
const HandComponentGlove := preload("res://mods_builtin/glove/hand_component_glove.gd")
## 探针 PROBE12：关卡内手套的**解锁口径** —— 与商店里的园艺手套同时获取
## 覆盖：
##   1. 静态：解锁跟着商店的园艺手套买断记录走（GloveSettings.GLOVE_GARDEN_TOOL）
##   2. 静态：没买园艺手套时 is_unlocked() = false，买断之后 = true
##   3. 实机（未买园艺手套）：4-6 手套组件禁用、卡槽不出现手套
##   4. 实机（已买园艺手套）：4-6 手套组件启用、卡槽出现手套图标
## 机器可读汇总：最后一行 [GLOVEUNLOCK] result=PASS|FAIL failed=<n>

const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_04_06 := "res://src/levels/mode_adventure/adventure_04_06.gd"
## 4-6 在选关界面上的位置：第 4 个页（0 起 = 3）的第 6 关，关卡编号 0036
const PAGE_04 := 3
const ID_04_06 := "0036"
const GLOVE_SLOT := "/root/MainGame/CanvasLayerCardSlot/CardSlotRoot/CardSlotContainer/ShovelContainer/UIGlove"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE12 手套解锁口径（与商店园艺手套同时获取）==========")
	## 手套是模组，默认关闭（本体 = 原版体验）：主游戏里不会装手套节点，
	## 所以探针自己打开模组再跑（关着跑整支必挂 —— 这是模组机制最容易漏的一步）
	if not ModManager.is_mod_enabled(ModIds.GLOVE):
		ModManager.set_mod_enabled(ModIds.GLOVE, true)
		a.log("  已启用手套模组（ModIds.GLOVE）：本探针跑在模组开启状态下")
	_check_const(a)
	## 未买园艺手套：手套不该出现
	await _run_level(a, false)
	## 已买园艺手套：手套同时到手
	await _run_level(a, true)
	## ★ 还原：模组开关是**持久化**的（写进 user://<用户名>/mod_config.ini），
	##   本探针把它打开了，不关回去会污染同一份存档目录下的其它探针（probe_hand / probe_mod_page）
	ModManager.set_mod_enabled(ModIds.GLOVE, false)
	ModManager.save_mods()
	_finish(a)


#region 断言与收尾
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[GLOVEUNLOCK] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion


#region 静态
## 解锁口径：买断记录 = 解锁记录，两者是同一只手套（原版手套只用于禅境花园）
## （口径归手套模组自己，本体的 ConstUnlockLevel 里没有"手套解锁"这一项）
func _check_const(a) -> void:
	a.log("")
	a.log("--- 1. 手套解锁口径（GloveMod）---")
	_check(a, "解锁跟着商店的园艺手套走",
		GloveSettings.GLOVE_GARDEN_TOOL == GardenManager.E_GardenTool.GardeningGlove,
		"tool=%d" % int(GloveSettings.GLOVE_GARDEN_TOOL))
	_set_garden_glove_bought(false)
	_check(a, "未买园艺手套时未解锁", not GloveMod.is_unlocked())
	_set_garden_glove_bought(true)
	_check(a, "买下园艺手套后已解锁", GloveMod.is_unlocked())


## 直接改存档里的园艺手套买断记录（等价于在商店买下 / 撤掉它），
## 绕开商店的钱与"花园未解锁不可购买"两道门控 —— 探针只关心买断记录本身
func _set_garden_glove_bought(bought: bool) -> void:
	var state := Global.global_game_state
	if bought:
		state.buy_garden_tool(GardenManager.E_GardenTool.GardeningGlove)
		return
	var tools: Array = state.garden_data.get(GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY, [])
	## 存档走 JSON，读回来可能是 float，必须逐个 int() 比（见 global_garden_state.gd 的读法）
	for i in range(tools.size() - 1, -1, -1):
		if int(tools[i]) == int(GardenManager.E_GardenTool.GardeningGlove):
			tools.remove_at(i)
	state.garden_data[GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY] = tools
#endregion


#region 实机
## 进 4-6，按「园艺手套买没买」核对手套的启用与卡槽显隐
func _run_level(a, expect_unlocked: bool) -> void:
	a.log("")
	a.log("--- 2. 实机 4-6（园艺手套%s）---" % ("已买" if expect_unlocked else "未买"))
	Global.global_game_state.curr_plant.assign([PlantIds.PEA_SHOOTER_SINGLE])
	_set_garden_glove_bought(expect_unlocked)
	a.log("  园艺手套买断=%s 手套解锁=%s" % [str(expect_unlocked), str(GloveMod.is_unlocked())])

	var para: ResourceLevelData = (load(LEVEL_04_06) as GDScript).new()
	para.set_choose_level(ADV, PAGE_04, ID_04_06)
	Global.game_para = para
	a.log("[场景] 进入 4-6（%s）" % para.save_game_name)
	await a.wait(2.0)
	## ★ 上一局还活着时，`change_scene` 是**帧末才真正切**的：不等到"换了个新局"就往下走，
	##   拿到的会是上一局的手套组件（它在上一局的买断记录下判定过了），表现为「买了却没启用」。
	##   所以记住旧局，等到 `curr_main_game` 换成另一个实例为止
	var old_mg = GameContext.curr_main_game
	GlobalUtils.change_scene(
		Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.MainGameFront)
	)
	if not await _wait_main_game(a, 60.0, old_mg):
		_check(a, "4-6 进入 MAIN_GAME", false, "超时")
		return
	_check(a, "4-6 进入 MAIN_GAME", true)

	var comp := _glove_comp()
	if comp == null:
		_check(a, "（前置）手套组件已注册", false)
		return
	_check(a, "手套组件 is_enabling=%s" % str(expect_unlocked), comp.is_enabling == expect_unlocked,
		"is_enabling=%s" % str(comp.is_enabling))
	var slot: CanvasItem = a.get_node_or_null(GLOVE_SLOT)
	if slot == null:
		_check(a, "（前置）手套卡槽存在", false)
		return
	_check(a, "手套卡槽显示=%s" % str(expect_unlocked), slot.visible == expect_unlocked,
		"visible=%s" % str(slot.visible))
	if expect_unlocked:
		var icon: CanvasItem = a.get_node_or_null(GLOVE_SLOT + "/Glove")
		_check(a, "空手时显示手套图标", icon != null and icon.visible)


func _glove_comp() -> HandComponentGlove:
	if GameContext.curr_main_game == null or GameContext.curr_main_game.hand_manager == null:
		return null
	return GameContext.curr_main_game.hand_manager.get_hand_component(
		HandComponentBase.E_HandComponentType.Glove) as HandComponentGlove


## 等进 MAIN_GAME；old_mg：上一局的管理器（>1 次进关时必传）—— `change_scene` 是帧末才切的，
## 不排除旧实例就会把上一局的组件当成这一局的来断言
func _wait_main_game(a, timeout: float, old_mg = null) -> bool:
	var waited := 0.0
	while waited < timeout:
		if GameContext.curr_main_game != null and GameContext.curr_main_game != old_mg:
			if GameContext.curr_main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
				return true
		await a.wait(0.5)
		waited += 0.5
	return false
#endregion
