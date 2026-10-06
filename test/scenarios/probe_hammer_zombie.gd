extends RefCounted
## 锤僵尸玩法实机冒烟：迷你游戏 15「打僵尸」+ 冒险 2-5「打地鼠」
##
## 这两关共用一条玩法规则 `LevelRuleHammerZombie`：
##   ① 锤子做成手持物：常驻 `canvas_layer_temp` 的 RealHammer 由 `HandComponentHammer` 拿着，
##      并被设成本关的「空闲手持物」取代空手（进主游戏自动在手上、放下手持物回到锤子），
##      本体只留一个「自定义光标」通用开关
##   ② 出怪器由规则注入 ZombieManager（不再常驻主场景）
## 本探针验的就是这两件事装上了，且与搬家前一样能出怪。
##
## 机器可读汇总：最后一行 [HAMMER] result=PASS|FAIL failed=<n>

const LEVEL_MINI_15 := "res://src/levels/mode_minigame/minigame_15_hammer_zombie.gd"
const MINI := MainSceneRegistry.MainScenes.ChooseLevelMiniGame
const PAGE_MINI := 0
const ID_MINI_15 := "0014"
## 迷你游戏 15 的存档键（关卡脚本里写死的老值，见 minigame_15_hammer_zombie.save_key）
const ID_MINI_SAVE_KEY := "102_0_0002"
const CARDS_MINI_15: Array[int] = [15, 12, 5]

const LEVEL_ADV_2_5 := "res://src/levels/mode_adventure/adventure_02_05.gd"
const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const PAGE_02 := 1
const ID_02_05 := "0015"
const CARDS_ADV_2_5: Array[int] = [5, 12, 3]

## 戴夫对话的点击位置（设计分辨率 800x600 的屏幕中心；戴夫的点击面板覆盖全屏，点哪都能推进）
const DAVE_CLICK_POS := Vector2(400, 300)
## 出怪器固定延迟 2 秒开第一波，给足富余
const WAIT_ZOMBIE := 25.0

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 锤僵尸玩法实机（迷你游戏 15 / 冒险 2-5） ==========")
	## 先写成「这两关都通关过」：没通关记录时 #首次通关# 会掉植物奖励**代替**奖杯，这里要验的是奖杯
	_mark_cleared()
	await _check_level(a, "迷你游戏 15", LEVEL_MINI_15, MINI, PAGE_MINI, ID_MINI_15, 10, CARDS_MINI_15)
	await _check_level(a, "冒险 2-5", LEVEL_ADV_2_5, ADV, PAGE_02, ID_02_05, 9, CARDS_ADV_2_5)
	await _check_lose(a, LEVEL_MINI_15, MINI, PAGE_MINI, ID_MINI_15)
	_finish(a)


## 进一关并跑一遍锤僵尸玩法的验收点
## [expect_tombstone] 开局墓碑数（迷你游戏 15 = 10，冒险 2-5 = 9，见各自的关卡脚本）
## [expect_cards] 固定出战卡（本类玩法玩家不选卡）
func _check_level(
	a, label: String, level_path: String, scene: MainSceneRegistry.MainScenes,
	page: int, level_id: String, expect_tombstone: int, expect_cards: Array[int]
) -> void:
	a.log("")
	a.log("---- %s ----" % label)
	var para: ResourceLevelData = (load(level_path) as GDScript).new()
	para.set_choose_level(scene, page, level_id)
	Global.game_para = para
	await a.wait(2.0)
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])

	if not await _wait_main_game(a, 60.0):
		_check(a, label + " 进入 MAIN_GAME", false, "超时")
		return
	_check(a, label + " 进入 MAIN_GAME", true)

	var mg = Global.main_game
	await a.wait(1.0)

	## 固定出战卡（玩家不选卡）
	var battle = mg.card_manager.card_slot_battle
	var got: Array[int] = []
	if battle != null:
		for c in battle.curr_cards:
			got.append(c.card_plant_type)
	got.sort()
	var want: Array[int] = expect_cards.duplicate()
	want.sort()
	_check(a, label + " 出战卡固定 %s" % str(want), got == want, str(got))

	## 锤子：美术常驻 canvas_layer_temp（RealHammer），由手持物组件拿在手上
	var hammer: Hammer = null
	for node in mg.canvas_layer_temp.get_children():
		if node is Hammer:
			hammer = node
			break
	_check(a, label + " 主场景里有锤子美术", hammer != null, str(hammer))
	if hammer != null:
		_check(a, label + " 锤子拿在手上（主游戏阶段）", hammer.is_used, str(hammer.is_used))
		_check(a, label + " 锤子美术可见", hammer.is_visible_in_tree(), str(hammer.visible))
	_check(a, label + " 本体打开了自定义光标开关", mg.is_custom_cursor_mode,
		str(mg.is_custom_cursor_mode))

	## 锤子是本关的「空闲手持物」：取代空手，放下手持物回到的是锤子
	var hm = mg.hand_manager
	_check(a, label + " 锤子手持物组件已启用",
		hm.get_hand_component(HandComponentBase.E_HandComponentType.Hammer).is_enabling,
		str(hm.get_hand_component(HandComponentBase.E_HandComponentType.Hammer)))
	_check(a, label + " 空闲手持物 = 锤子",
		hm.idle_hand_type == HandComponentBase.E_HandComponentType.Hammer, str(hm.idle_hand_type))
	_check(a, label + " 当前手上就是锤子",
		hm.get_curr_hand_type() == HandComponentBase.E_HandComponentType.Hammer,
		str(hm.get_curr_hand_type()))
	hm.drop_hand()
	_check(a, label + " 放下手持物回到锤子而不是空手",
		hm.get_curr_hand_type() == HandComponentBase.E_HandComponentType.Hammer,
		str(hm.get_curr_hand_type()))

	## 出怪器：不再常驻主场景，由玩法规则注入
	var zm = mg.zombie_manager
	_check(a, label + " 出怪器已注入 ZombieManager", zm.wave_source != null, str(zm.wave_source))
	_check(a, label + " 注入的是锤僵尸出怪器", zm.wave_source is HammerZombieManager, str(zm.wave_source))

	## 开局墓碑
	_check(a, label + " 开局墓碑 = %d" % expect_tombstone,
		mg.plant_cell_manager.tomb_stone_manager.tombstone_num == expect_tombstone,
		str(mg.plant_cell_manager.tomb_stone_manager.tombstone_num))

	## 出怪（锤僵尸模式固定 2 秒后开波，僵尸从墓碑冒头）
	var seen := false
	var waited := 0.0
	while waited < WAIT_ZOMBIE:
		if zm.zombies_root.get_child_count() > 0 \
			or mg.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
			seen = true
			break
		await a.wait(0.5)
		waited += 0.5
	_check(a, label + " %.0f 秒内出现了僵尸" % WAIT_ZOMBIE, seen,
		"num=" + str(zm.zombies_root.get_child_count()))

	## 奖杯：把本波僵尸打死出奖杯并点它 —— 奖杯的鼠标进入回调现在走本体的自定义光标开关
	## （用 be_attack_to_death 而不是 test_death_all_zombie：后者是「直接消失」，不走死亡信号，
	##  出不了奖杯，见 docs/AI调试通道.md 踩坑表同类的「绕过信号就验不到结算」）
	zm.is_end_wave = true
	## 停掉出怪（出怪器每小组都肯的下一个 Timer 是自己管的），否则永远清不干净场
	if zm.wave_source != null:
		var source_timer: Timer = zm.wave_source.get_node_or_null("HammerZombieTimer") as Timer
		if source_timer != null:
			source_timer.stop()
	var trophy: Trophy = null
	for round_i in range(4):
		for z: Zombie000Base in zm.all_zombies_1d.duplicate():
			if is_instance_valid(z) and not z.is_death:
				z.be_attack_to_death()
		await a.wait(3.0)
		trophy = _find_trophy(mg)
		if trophy != null:
			break
	_check(a, label + " 清场后出奖杯", trophy != null,
		"curr_zombie_num=" + str(zm.curr_zombie_num) + " is_end_wave=" + str(zm.is_end_wave))
	if trophy != null:
		await a.click(trophy.global_position.x, trophy.global_position.y)
		await a.wait(1.0)
		_check(a, label + " 点奖杯没报错（奖杯可见、回调跑通）",
			is_instance_valid(trophy) and trophy.is_visible_in_tree(), str(trophy))


## 三进迷你游戏 15：验失败流程 —— 僵尸进家后进入 GAME_OVER，
## 锤子由手持物调度按游戏阶段收起（非游玩阶段一律回空手，失败流程里没有再手动收锤子的代码）
func _check_lose(
	a, level_path: String, scene: MainSceneRegistry.MainScenes, page: int, level_id: String
) -> void:
	a.log("")
	a.log("---- 失败流程（再进一次迷你游戏 15） ----")
	var para: ResourceLevelData = (load(level_path) as GDScript).new()
	para.set_choose_level(scene, page, level_id)
	Global.game_para = para
	await a.wait(2.0)
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	if not await _wait_main_game(a, 60.0):
		_check(a, "失败流程 进入 MAIN_GAME", false, "超时")
		return

	var mg = Global.main_game
	var zm = mg.zombie_manager
	var victim: Zombie000Base = null
	var waited := 0.0
	while waited < WAIT_ZOMBIE and victim == null:
		for z: Zombie000Base in zm.all_zombies_1d.duplicate():
			if is_instance_valid(z) and not z.is_death:
				victim = z
				break
		if victim == null:
			await a.wait(0.5)
			waited += 0.5
	_check(a, "失败流程 场上抓到一只僵尸", victim != null, str(victim))
	if victim == null:
		return

	EventBus.push_event("zombie_go_home", [victim])
	await a.wait(2.0)
	_check(a, "失败流程 进入 GAME_OVER",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER,
		str(mg.main_game_progress))
	var hammer: Hammer = null
	for node in mg.canvas_layer_temp.get_children():
		if node is Hammer:
			hammer = node
			break
	if hammer != null:
		_check(a, "失败流程 锤子已收起（系统鼠标交还）", not hammer.is_used, str(hammer.is_used))
	_check(a, "失败流程 回到空手",
		mg.hand_manager.get_curr_hand_type() == HandComponentBase.E_HandComponentType.Null,
		str(mg.hand_manager.get_curr_hand_type()))


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[HAMMER] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 等主游戏进入 MAIN_GAME 阶段：2-5 有开场戴夫对话，要逐句点完才进得去
func _wait_main_game(a, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game != null:
			if _find_dave() != null and not await _skip_dave_dialog(a):
				return false
			if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
				return true
		await a.wait(0.5)
		waited += 0.5
	return false


## 把这两关的通关记录写进存档：迷你游戏 15 的存档键是在关卡脚本里写死的老值 102_0_0002，
## 冒险 2-5 走运行时拼出来那份（模式_页_关卡编号）
func _mark_cleared() -> void:
	var state := Global.global_game_state
	state.curr_all_level_state_data = {}
	state.curr_all_level_state_data[ID_MINI_SAVE_KEY] = {"IsSuccess": true}
	state.curr_all_level_state_data["%d_%d_%s" % [ADV, PAGE_02, ID_02_05]] = {"IsSuccess": true}


## 草坪上的奖杯（挂在 canvas_layer_temp 下，见 MgmRewardManager.create_trophy）
func _find_trophy(mg) -> Trophy:
	if mg == null:
		return null
	for node in mg.canvas_layer_temp.get_children():
		if node is Trophy:
			return node as Trophy
	return null


## 界面上正在说话的戴夫（挂在 canvas_layer_ui 下），没有则返回 null
func _find_dave() -> CrazyDave:
	var mg = Global.main_game
	if mg == null:
		return null
	for child in mg.canvas_layer_ui.get_children():
		if child is CrazyDave:
			return child as CrazyDave
	return null


## 点掉戴夫对话：戴夫的点击面板覆盖全屏，每点一次推进一句，说到最后一句后自动离场
func _skip_dave_dialog(a, timeout: float = 40.0) -> bool:
	var waited := 0.0
	while waited < timeout:
		if _find_dave() == null:
			return true
		await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
		await a.wait(0.5)
		waited += 0.5
	return _find_dave() == null
