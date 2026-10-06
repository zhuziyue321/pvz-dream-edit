extends RefCounted
## 探针：冒险 4-6 中途掉落礼盒解锁解谜模式（照 3-2 掉礼盒解锁迷你游戏的同一套机制）
## 覆盖：
##   1. 常量：解谜模式门槛 = 冒险 4-6（序号 36），35 未解锁 / 36 已解锁
##   2. 关卡资源：4-6 配的是「中途第 5 波携带」而不是「通关掉落」——走通关掉落会抢先占用
##      本关的首次通关奖励槽位（4-6 奖励是杨桃种子包），所以必须与通关掉落互斥
##   3. 关卡资源：3-2（迷你游戏）仍是中途第 10 波，两处配置互不干扰
##   4. 实机：进 4-6 → 快进到携带波 → 打死该波僵尸 → 草坪上掉出礼盒
##   5. 实机：点开礼盒弹出解谜模式解锁提示；礼盒是解锁类（不计花园植物、不写存档）
## 机器可读汇总：最后一行 [PUZZLEUNLOCK] result=PASS|FAIL failed=<n>

const ADV := MainSceneRegistry.MainScenes.ChooseLevelAdventure
const LEVEL_04_06 := "res://src/levels/mode_adventure/adventure_04_06.gd"
const LEVEL_03_02 := "res://src/levels/mode_adventure/adventure_03_02.gd"
const PUZZLE := MainSceneRegistry.MainScenes.ChooseLevelPuzzle
const MINI_GAME := MainSceneRegistry.MainScenes.ChooseLevelMiniGame
## 4-6 在选关界面上的位置：第 4 页（0 起 = 3）的第 6 关，关卡编号 0036
const PAGE_04 := 3
const ID_04_06 := "0036"
## 戴夫对话的点击位置（800x600 下的屏幕中心；戴夫的点击面板覆盖全屏，点哪都能推进）
const DAVE_CLICK_POS := Vector2(400, 300)
## 4-6 配置的解锁道具携带波次（0 起；本关 max_wave=10，有效范围 0..9）
const EXPECT_WAVE := 5
const EXPECT_TIP := "解谜模式解锁！可以从主菜单中进入该模式！"
## 3-2 仍然是迷你游戏那条：中途第 10 波
const EXPECT_0302_WAVE := 10

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针 冒险 4-6 礼盒解锁解谜模式 ==========")
	## 等主菜单自身初始化完再切场景，否则 change_scene_to_file 会撞上「父节点正忙」
	await a.wait(2.0)
	_check_const(a)
	_check_level_resource(a)
	await _run_level(a, 35)
	_finish(a)


#region 静态
## 模式解锁门槛：解谜 = 冒险 4-6（序号 36），与迷你游戏 3-2（22）各占一行
func _check_const(a) -> void:
	a.log("")
	a.log("--- 1. 解谜模式解锁常量 ---")
	_check(a, "解谜门槛 = 4-6（序号 36）", ConstUnlockLevel.PUZZLE_UNLOCK_ADVENTURE_LEVEL == 36,
		str(ConstUnlockLevel.PUZZLE_UNLOCK_ADVENTURE_LEVEL))
	_check(a, "35（通关到 4-5）未解锁解谜", not ConstUnlockLevel.is_mode_unlocked(PUZZLE, 35))
	_check(a, "36（通关 4-6）已解锁解谜", ConstUnlockLevel.is_mode_unlocked(PUZZLE, 36))
	_check(a, "35 未解锁迷你游戏（门槛比 22 早已过，这里只确认两条表互不干扰）",
		ConstUnlockLevel.is_mode_unlocked(MINI_GAME, 35))
	_check(a, "门槛名称显示为 4-6", ConstUnlockLevel.get_adventure_level_name(36) == "4-6",
		ConstUnlockLevel.get_adventure_level_name(36))


## 关卡资源上的掉落配置（手写的 .tres 只有真加载才知道对不对）
func _check_level_resource(a) -> void:
	a.log("")
	a.log("--- 2. 4-6 / 3-2 关卡资源的掉落配置 ---")
	var p_0406: ResourceLevelData = (load(LEVEL_04_06) as GDScript).new()
	if p_0406 == null:
		_check(a, "（前置）4-6 关卡资源可加载", false, LEVEL_04_06)
		return
	_check(a, "4-6 配的是中途掉落（不是通关掉落）", not p_0406.drop_unlock_on_level_complete,
		str(p_0406.drop_unlock_on_level_complete))
	_check(a, "4-6 携带波次 = %d（本关波 0..9）" % EXPECT_WAVE, p_0406.drop_unlock_wave == EXPECT_WAVE,
		str(p_0406.drop_unlock_wave))
	_check(a, "4-6 掉落提示提到解谜模式", "解谜模式" in p_0406.drop_unlock_tip, p_0406.drop_unlock_tip)
	_check(a, "4-6 掉落提示与实机断言用的文案一致", p_0406.drop_unlock_tip == EXPECT_TIP, p_0406.drop_unlock_tip)
	_check(a, "4-6 不指定贴图（用默认礼物盒）", p_0406.drop_unlock_icon == null,
		str(p_0406.drop_unlock_icon))
	_check(a, "携带波次落在本关波数范围内", p_0406.drop_unlock_wave >= 0
		and p_0406.drop_unlock_wave < p_0406.max_wave,
		"wave=%d max_wave=%d" % [p_0406.drop_unlock_wave, p_0406.max_wave])

	## 走通关掉落会被 create_adventure_reward_drop 抢先用掉，本关的杨桃种子包就没了
	var lvl := Global.global_game_state.get_adventure_level_on_save_game_name("101_0_0036")
	var reward: Dictionary = ConstAdventureReward.get_reward(lvl)
	_check(a, "（前置）4-6 的首次通关奖励仍是植物（序号 %d）" % lvl,
		not reward.is_empty() and int(reward.get(ConstAdventureReward.KEY_TYPE, -1)) == ConstAdventureReward.E_RewardType.Plant,
		str(reward))
	_check(a, "4-6 的通关奖励是杨桃", int(reward.get(ConstAdventureReward.KEY_PLANT_TYPE, -1))
		== CharacterRegistry.PlantType.P030StarFruit,
		str(reward.get(ConstAdventureReward.KEY_PLANT_TYPE, -1)))

	var p_0302: ResourceLevelData = (load(LEVEL_03_02) as GDScript).new()
	if p_0302 == null:
		_check(a, "（前置）3-2 关卡资源可加载", false, LEVEL_03_02)
		return
	_check(a, "3-2 仍是中途第 %d 波携带（迷你游戏）" % EXPECT_0302_WAVE,
		p_0302.drop_unlock_wave == EXPECT_0302_WAVE, str(p_0302.drop_unlock_wave))
	_check(a, "3-2 掉落提示提到迷你游戏", "迷你游戏" in p_0302.drop_unlock_tip, p_0302.drop_unlock_tip)
	_check(a, "3-2 与 4-6 用不同的波次配置", p_0302.drop_unlock_wave != p_0406.drop_unlock_wave)
#endregion


#region 实机
## 进 4-6（已通关到 4-5），快进到携带解锁道具的那一波，打死那里的僵尸看礼盒掉不掉
func _run_level(a, max_level: int) -> void:
	a.log("")
	a.log("--- 3. 实机 4-6（模拟已通关到 %s）---" % ConstUnlockLevel.get_adventure_level_name(max_level))
	_mark_cleared(max_level)
	Global.global_game_state.curr_plant.assign([CharacterRegistry.PlantType.P001PeaShooterSingle])

	var para: ResourceLevelData = (load(LEVEL_04_06) as GDScript).new()
	para.set_choose_level(ADV, PAGE_04, ID_04_06)
	Global.game_para = para
	a.log("[场景] 进入 4-6（%s）" % para.save_game_name)
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])

	if not await _wait_main_game(a, 90.0):
		_check(a, "4-6 进入 MAIN_GAME", false, "超时，阶段=%s" % str(_progress_name()))
		return
	_check(a, "4-6 进入 MAIN_GAME", true)
	_check(a, "此刻解谜模式仍未解锁（没通关 4-6）",
		not Global.global_game_state.is_mode_unlocked(PUZZLE),
		str(Global.global_game_state.get_max_success_adventure_level()))

	var zm = Global.main_game.zombie_manager
	var zwm = zm.zombie_wave_manager
	_check(a, "波次管理器读到了携带波次 = %d" % EXPECT_WAVE, zwm.drop_unlock_wave == EXPECT_WAVE,
		str(zwm.drop_unlock_wave))

	var parent := Global.main_game.drop_item_manager.dim_garden_plant.all_drop_garden_plant_parent
	_check(a, "（前置）掉落容器已就绪", parent != null)
	if parent == null:
		return
	_check_clamp(a)
	## 自动收金币会把礼包秒开，探针就没法验证「点击打开提示」了
	var cfg := Global.config_service
	if "auto_collect_coin" in cfg:
		cfg.auto_collect_coin = false

	## 开场有一趟「相机从左扫到右再回来」的展示动画，动画期间掉落的礼盒会在相机归位后
	## 跑出画面，点不到。先等相机停稳再推进波次，让掉落落在玩家真正看得到的那块草坪上
	var camera_still := await _wait_camera_still(a, 25.0)
	_check(a, "（前置）开场相机已归位（画布原点不再变化）", camera_still, str(_canvas_origin()))

	## 把波次推到携带道具的那一波：start_next_wave() 里 curr_wave += 1 后与 drop_unlock_wave 比对，
	## 所以先站到前一波再刷一次，正好命中配置的那波
	a.log("  当前波次=%d，快进到携带波 %d" % [zwm.curr_wave, EXPECT_WAVE])
	if zwm.curr_wave >= EXPECT_WAVE:
		a.log("  !! 关卡自己已经刷过第 %d 波了，无法重放" % EXPECT_WAVE)
	zwm.curr_wave = EXPECT_WAVE - 1
	zwm.start_next_wave()
	await a.wait(1.0)
	_check(a, "推进到第 %d 波" % EXPECT_WAVE, zwm.curr_wave == EXPECT_WAVE, str(zwm.curr_wave))

	var zombie_num := 0
	for _i in range(20):
		zombie_num = zm.curr_zombie_num
		if zombie_num > 0:
			break
		await a.wait(0.5)
	_check(a, "第 %d 波刷出了僵尸" % EXPECT_WAVE, zombie_num > 0, str(zombie_num))
	if zombie_num <= 0:
		return

	## 清场：僵尸走正常死亡流程（与 Ctrl+K 同一个入口），携带道具的那只死了就地掉出来
	## 场上没有植物，僵尸会一路走到家、关卡直接失败，所以这里一发现僵尸就清，不给它走的机会
	var dropped := await _kill_until_drop(a, parent, 25.0)
	_check(a, "打死该波僵尸后草坪上掉出礼盒", dropped != null, str(dropped))
	if dropped == null:
		## 区分「掉落链路坏了」和「僵尸没死透 / 关卡已经失败」
		if Global.main_game != null:
			Global.main_game.drop_item_manager.create_unlock_drop(Vector2(500, 300))
			await a.wait(1.0)
			_check(a, "（诊断）掉落入口本身可用（不是配置问题）", _find_present(parent) != null,
				"剩余僵尸=%d 阶段=%s" % [
					Global.main_game.zombie_manager.curr_zombie_num, _progress_name()])
		return
	_check(a, "礼盒是解锁类（不计花园植物、不写存档）", not dropped.is_garden_plant,
		str(dropped.is_garden_plant))
	_check(a, "礼盒文案是关卡配置的那句解谜模式提示", dropped.open_tip_text == EXPECT_TIP, dropped.open_tip_text)
	_check(a, "礼盒掉在可视范围内", _is_in_view(dropped.global_position),
		"(%d,%d)" % [int(dropped.global_position.x), int(dropped.global_position.y)])

	## 点开礼盒：应弹出解锁提示
	## 关卡里有 Camera2D，global_position 是**世界坐标**，不是屏幕上能点到的位置，
	## 必须过 AutopilotProbe.screen_center_of() 换算，而且要在点下去的那一刻现算
	## （相机一动，同一个世界坐标对应的屏幕位置就变了，见 docs/AI调试通道.md 第六节）
	var btn: TextureButton = dropped.texture_button
	if btn == null or not btn.visible or not is_instance_valid(dropped):
		_check(a, "（前置）礼盒有可点区域", false, str(btn))
		return
	var pos := AutopilotProbe.screen_center_of(btn)
	a.log("  画布原点=%s 礼盒世界坐标=(%d,%d) 屏幕坐标=(%d,%d) 窗口=%s" % [
		str(_canvas_origin()), int(dropped.global_position.x), int(dropped.global_position.y),
		int(pos.x), int(pos.y), str(_window_size())])
	if not _is_in_view(pos):
		_check(a, "礼盒在画面外，点不到（相机归位后跑出去了）", false, str(pos))
		return
	await a.click(pos.x, pos.y)
	var tip := await _wait_reminder_text(a, 4.0)
	_check(a, "点开礼盒弹出解锁提示", tip == EXPECT_TIP, str(tip))


## 掉落位置夹紧：僵尸死在哪是随机的，这里直接喂极端坐标做确定性断言
## ——画布有偏移时（本关 x 偏 150）把掉落点夹到 [0, 视口宽] 会让右边一截掉到画面外，
##   玩家只能眼看礼盒 15 秒后自己消失，所以必须夹到**看得见的那块世界矩形**里
func _check_clamp(a) -> void:
	var manager := Global.main_game.drop_item_manager
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		_check(a, "（前置）能取到根视口", false)
		return
	var visible_rect := manager.get_viewport_visible_rect()
	a.log("  可视世界矩形=%s 画布原点=%s" % [str(visible_rect), str(_canvas_origin())])
	var to_screen := tree.root.get_canvas_transform()
	var probes := {
		"右侧溢出": Vector2(9999, 200),
		"左侧溢出": Vector2(-9999, 200),
		"下方溢出": Vector2(500, 9999),
		"上方溢出": Vector2(500, -9999),
	}
	for label in probes:
		var clamped: Vector2 = manager.get_clamp_drop_position(probes[label])
		var screen: Vector2 = to_screen * clamped
		_check(a, "夹紧后仍在画面内（%s）" % label, _is_in_view(screen),
			"世界%s -> 屏幕%s" % [str(clamped), str(screen)])


## 把通关记录写成「第 1 关 ~ 第 max_level 关全部通关」
func _mark_cleared(max_level: int) -> void:
	var state := Global.global_game_state
	state.curr_all_level_state_data = {}
	for i in range(1, max_level + 1):
		state.curr_all_level_state_data["%d_0_%04d" % [ADV, i]] = {"IsSuccess": true}


func _progress_name() -> String:
	if Global.main_game == null:
		return "main_game=null"
	return str(Global.main_game.main_game_progress)


## 等进 MAIN_GAME：中途出现戴夫就逐句点完（4-6 开场有一段赠礼对话），
## 停在选卡 / 准备阶段就替玩家点「开始游戏」—— 卡片不足时关卡会自己跳过选卡，
## 但仍然停在 PREPARE 等这个按钮，不点它就永远进不了游戏阶段（僵尸打赢了也是白打）
func _wait_main_game(a, timeout: float) -> bool:
	var started := false
	var waited := 0.0
	while waited < timeout:
		if Global.main_game == null:
			await a.wait(0.5)
			waited += 0.5
			continue
		if _find_dave() != null:
			await a.click(DAVE_CLICK_POS.x, DAVE_CLICK_POS.y)
			await a.wait(0.4)
			waited += 0.4
			continue
		var progress := Global.main_game.main_game_progress
		## 时间轴停在选卡上等玩家点「开始游戏」才按 —— 提前按会让后续事件（准备安放植物）
		## 在已经开战之后补跑一遍，把关卡塞回 PREPARE，僵尸再怎么打也走不到下一步
		if Global.main_game.is_timeline_waiting_choose_card and not started:
			a.log("  点「开始游戏」（当前阶段=%d）" % progress)
			started = true
			Global.main_game.main_game_start()
			await a.wait(1.5)
			waited += 1.5
			continue
		if progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
			return true
		await a.wait(0.5)
		waited += 0.5
	return false


func _find_dave() -> CrazyDave:
	var mg = Global.main_game
	if mg == null:
		return null
	for child in mg.canvas_layer_ui.get_children():
		if child is CrazyDave:
			return child as CrazyDave
	return null


## 反复清场直到礼盒掉出来：deadline 内每 0.3 秒看一次，
## 只要处于 MAIN_GAME 且场上还有僵尸就调 death_all_zombie()（与 Ctrl+K 同一个入口），
## 不用合成按键事件 —— 按键输入在开场那一段时间轴里不总是被处理，会让探针随机翻车
func _kill_until_drop(a, parent: Node, timeout: float) -> Present:
	var waited := 0.0
	while waited < timeout:
		if Global.main_game == null:
			return null
		## 关卡还停在选卡 / 准备阶段就想办法把它推下去
		if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD \
				or Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.PREPARE:
			Global.main_game.main_game_start()
		var zm = Global.main_game.zombie_manager
		if zm.curr_zombie_num > 0:
			zm.death_all_zombie()
		var found := _find_present(parent)
		if found != null:
			a.log("  掉落容器 礼盒数=%d" % _count_present(parent))
			return found
		await a.wait(0.3)
		waited += 0.3
	a.log("  掉落容器 礼盒数=%d（等到超时也没掉出来）" % _count_present(parent))
	return null


func _count_present(parent: Node) -> int:
	var n := 0
	for c in parent.get_children():
		if c is Present:
			n += 1
	return n


func _find_present(parent: Node) -> Present:
	for c in parent.get_children():
		if c is Present and (c as Present).open_tip_text == EXPECT_TIP:
			return c as Present
	return null


## 当前画布变换原点：非 (0,0) 说明相机偏移过，此时屏幕坐标不等于 global_position
func _canvas_origin() -> Vector2:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return Vector2.ZERO
	return tree.root.get_canvas_transform().origin


func _window_size() -> Vector2:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return Vector2.ZERO
	return tree.root.get_visible_rect().size


## 等开场那趟相机展示动画走完：画布原点连续几次采样不变就算停稳
## 必须在**掉落之前**等 —— 动画期间掉出来的礼盒会在相机归位后跑出画面，玩家点不到
func _wait_camera_still(a, timeout: float) -> bool:
	var last := Vector2.INF
	var still_time := 0.0
	var waited := 0.0
	while waited < timeout:
		var origin := _canvas_origin()
		if origin == last:
			still_time += 0.25
			if still_time >= 1.0:
				return true
		else:
			still_time = 0.0
			last = origin
		await a.wait(0.25)
		waited += 0.25
	return false


func _is_in_view(pos: Vector2) -> bool:
	var size := Vector2(800, 600)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		size = tree.root.get_visible_rect().size
	return pos.x >= 0.0 and pos.y >= 0.0 and pos.x <= size.x and pos.y <= size.y


## 等提示气泡弹出并返回它的文本
func _wait_reminder_text(a, timeout: float) -> String:
	var waited := 0.0
	while waited < timeout:
		var info := _find_reminder()
		if info != null:
			return info.label.text
		await a.wait(0.3)
		waited += 0.3
	return ""


func _find_reminder() -> ReminderInformation:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	for c in tree.current_scene.get_children():
		if c is ReminderInformation:
			return c as ReminderInformation
	return null
#endregion


#region 断言与收尾
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[PUZZLEUNLOCK] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
