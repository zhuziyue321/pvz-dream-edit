extends RefCounted
## 探针：迷你游戏第 5 关「僵尸迷阵」(Beghouled)
## 覆盖：
##   ① 关卡数据：夜晚关（蘑菇不睡觉）/ 无限波（100 波）/ 没有小推车 / 没有选卡权；三消管理器由**关卡脚本**持有（本体不再创建）
##   ② 摆场：棋盘（去掉最右一列）铺满植物、最右一列留空、**蘑菇不睡觉**、开局没有现成的连线、有步可走
##   ③ 交换三消：按住一株拖到相邻株（原版口径）→ 凑成连线 → 植物被消掉 + 阳光掉在被消掉的格子上（点了才进账）+ 空位补满
##   ③.1 单击不再交换（本关改成拖动之后单击不做事）
##   ④ 棋盘上的植物被啃掉留弹坑 + 点卡槽里的填坑种子包填坑（没有坑时那张卡是封住的）
##   ⑤ 花阳光买升级：场上旧植物全换成升级版 + 随机池跟着换 + 换完盘面仍「无现成连线 + 有步可走」
##   ⑥ 通关判定：配对次数达标 → 出奖杯进 GAME_OVER（不是靠打完波次）
##   ⑦ 关卡进度条：本关口径 = 配对次数 / 75（不画旗帜、开战才显示、通关后自己收起）
## 机器可读汇总：最后一行 [BEGHOULED] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_minigame/minigame_05_beghouled.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵尸迷阵（Beghouled） ==========")

	## 不标类型：下面要取子类才有的字段 beghouled（标成 Resource 会取不到）
	var para = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	Global.game_para = para
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)

	var mg := Global.main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "Global.main_game 为空")
		_finish(a)
		return

	# ------------------------------------------------ STEP1 关卡数据
	a.log("STEP1 关卡数据")
	_check(a, "波数配成 100（无限波）", mg.game_para.max_wave == 100, str(mg.game_para.max_wave))
	_check(a, "没有小推车", not mg.game_para.is_lawn_mover, str(mg.game_para.is_lawn_mover))
	_check(a, "没有选卡权", mg.game_para.is_no_choose_permission())
	_check(a, "夜晚关：is_day = false（蘑菇不睡觉）", not mg.game_para.is_day, str(mg.game_para.is_day))
	## 本体上取不到 beghouled_manager（字段已删；Object.get 取不存在的属性返回 null）
	_check(a, "本体不再持有三消管理器", mg.get("beghouled_manager") == null,
		"MainGameManager 上不该再有 beghouled_manager 字段")

	## 三消管理器由**关卡脚本**自己创建并持有（硬约束 §1-8：一关专属机制不进本体）
	var mgr = para.beghouled
	if mgr == null:
		_check(a, "关卡脚本创建了三消管理器", false, "para.beghouled 为空")
		_finish(a)
		return
	_check(a, "关卡脚本创建了三消管理器", true)

	## 关卡流程：展示僵尸 → 相机归位 → 摆场 → 开战
	if not await _wait_progress(a, mg, MainGameManager.E_MainGameProgress.MAIN_GAME, 60.0):
		_finish(a)
		return

	# ------------------------------------------------ STEP2 摆场
	a.log("STEP2 摆场")
	_check(a, "玩法已接管本关", mgr.is_running, str(mgr.is_running))
	var col_num: int = mg.plant_cell_manager.row_col.y
	_check(a, "棋盘列数 = 总列数 - 1（最右列留给僵尸入场）",
		mgr.board_col_num == col_num - 1, str(mgr.board_col_num))

	var empty_num := 0
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			if mgr.get_cell_plant(mgr.get_cell(row, col)) == null:
				empty_num += 1
	_check(a, "棋盘上没有空格子", empty_num == 0, "空格数=" + str(empty_num))

	var right_col_plants := 0
	for row in range(mgr.board_row_num):
		if mgr.get_cell_plant(mgr.get_cell(row, col_num - 1)) != null:
			right_col_plants += 1
	_check(a, "最右一列是空的", right_col_plants == 0, "有植物行数=" + str(right_col_plants))
	_check(a, "开局没有现成的连线", mgr._find_match_groups(mgr._build_type_grid()).is_empty())
	_check(a, "开局有步可走", mgr._has_possible_move())
	_check(a, "三消界面已挂上并显示", mgr.ui != null and mgr.ui.visible, "ui=" + str(mgr.ui))

	## 本关是夜晚关：盘面里的小喷菇 / 磁力菇都不该睡觉（is_day = true 会全程睡觉且攻击组件被禁）
	## 蘑菇数是随机铺场的结果，只进 detail；断言只写确定性的「睡觉数 = 0」
	var mushroom_num := 0
	var sleeping_num := 0
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			var p = mgr.get_cell_plant(mgr.get_cell(row, col))
			if p == null:
				continue
			if p.plant_type == CharacterRegistry.PlantType.P009PuffShroom \
				or p.plant_type == CharacterRegistry.PlantType.P032MagnetShroom:
				mushroom_num += 1
				if p.is_sleeping:
					sleeping_num += 1
	_check(a, "夜晚关蘑菇不睡觉", sleeping_num == 0,
		"蘑菇数=" + str(mushroom_num) + " 睡觉数=" + str(sleeping_num))

	# ------------------------------------------------ STEP2.5 进度条 = 配对次数 / 75
	a.log("STEP2.5 进度条口径（配对次数 / 75）")
	var lpc = mg.level_progress_controller
	var provider = lpc.provider if lpc != null else null
	_check(a, "进度条数据源是本关的三消口径", provider is BeghouledProgressProvider, str(provider))
	if provider is BeghouledProgressProvider:
		_check(a, "数据源已绑上三消管理器", provider.beghouled == mgr, str(provider.beghouled))
		_check(a, "本关进度条不画旗帜", provider.get_flag_num() == 0, str(provider.get_flag_num()))
	_check(a, "开战后进度条可见", lpc.progress_bar.visible, str(lpc.progress_bar.visible))
	_check(a, "还没配对时进度 = 0%", lpc.progress_bar.real_value == 0.0, str(lpc.progress_bar.real_value))

	# ------------------------------------------------ STEP3 交换三消
	a.log("STEP3 拖动交换相邻两株做三消")
	var swap_pair := _find_valid_swap(mgr)
	if swap_pair.is_empty():
		_check(a, "找到一步有效交换", false, "null")
		_finish(a)
		return
	var cell_a: PlantCell = swap_pair[0]
	var cell_b: PlantCell = swap_pair[1]
	var sun_before: int = mgr.get_sun()
	var match_before: int = mgr.match_num
	## 阳光是掉在盘面上、玩家点了才进账：探针里先关掉自动收集，才能稳定验「掉在哪儿 + 点了才加」
	var auto_collect_before := Global.config_service.auto_collect_sun
	Global.config_service.auto_collect_sun = false
	## 原版口径是「按住不放再拖到相邻株」（不是点两下），这里用**真实鼠标事件**走一遍：
	## 按下 → 中途几帧移动 → 松手，全程过 GUI 命中测试，不直接调管理器的方法
	var drag_ok: bool = await a.drag_plant_cell(cell_a.row_col.x, cell_a.row_col.y,
		cell_b.row_col.x, cell_b.row_col.y)
	_check(a, "拖动被受理（按住起点 → 拖到相邻株）", drag_ok and mgr.is_resolving,
		"is_resolving=" + str(mgr.is_resolving))
	await a.wait(3.0)
	_check(a, "配对次数增加了", mgr.match_num > match_before,
		str(match_before) + " -> " + str(mgr.match_num))
	var dropped := _collect_dropped_suns(mg)
	_check(a, "消除在被消掉的格子那儿掉了阳光", not dropped.is_empty(),
		"掉落数=" + str(dropped.size()))
	if not dropped.is_empty():
		var first: Sun = dropped[0]
		_check(a, "掉下来的阳光是 25 一颗", first.sun_value == ConstBeghouled.SUN_UNIT_VALUE,
			str(first.sun_value))
		_check(a, "阳光掉在棋盘的格子上", _is_sun_on_board(mgr, first), str(first.global_position))
		var drop_sum := 0
		for one_sun in dropped:
			drop_sum += one_sun.sun_value
			one_sun._on_button_pressed()
		await a.wait(1.0)
		_check(a, "点了阳光才进账", mgr.get_sun() == sun_before + drop_sum,
			str(sun_before) + " + " + str(drop_sum) + " -> " + str(mgr.get_sun()))
	Global.config_service.auto_collect_sun = auto_collect_before
	var expect_progress: float = float(mgr.match_num) / float(ConstBeghouled.TARGET_MATCH_NUM) * 100.0
	_check(a, "进度条 = 配对次数 / 75", absf(lpc.progress_bar.real_value - expect_progress) < 0.01,
		"进度=" + str(lpc.progress_bar.real_value) + " 期望=" + str(expect_progress))

	empty_num = 0
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			if mgr.get_cell_plant(mgr.get_cell(row, col)) == null:
				empty_num += 1
	_check(a, "消除后空位被补满", empty_num == 0, "空格数=" + str(empty_num))
	## 结算收尾可能在跑「死局提示 → 4 秒后刷新」，下面 STEP4 要靠 _can_operate() 通过，先等它跑完
	await _wait_unlocked(a, mgr)

	# ------------------------------------------------ STEP3.1 单击不再交换
	a.log("STEP3.1 单击不再交换（本关改成拖动）")
	var match_before_click: int = mgr.match_num
	mgr._on_click_cell(cell_a)
	await a.wait(0.4)
	_check(a, "单击一株植物既不交换也不结算",
		mgr.match_num == match_before_click and not mgr.is_resolving,
		"配对=" + str(mgr.match_num) + " is_resolving=" + str(mgr.is_resolving))

	# ------------------------------------------------ STEP4 被啃掉留弹坑
	a.log("STEP4 植物没了会留弹坑")
	## 填一个坑要 200 阳光，先把阳光补给够（STEP3 只消了一组，攒不到 200）
	EventBus.push_event("add_sun_value", [300])
	var victim: PlantCell = mgr.get_cell(0, 0)
	var victim_plant = mgr.get_cell_plant(victim)
	victim_plant.character_death()
	await a.wait(0.5)
	_check(a, "棋盘上的植物没了会留弹坑", mgr.is_crater(victim), str(mgr.is_crater(victim)))
	## 填坑走卡槽里那张种子包（底部按钮条已全部移除）
	var battle0 = mg.card_manager.card_slot_battle
	var fill_card = battle0.curr_cards[4] if battle0.curr_cards.size() >= 5 else null
	_check(a, "第五张是填坑种子包（200 阳光）",
		fill_card != null and fill_card.sun_cost == ConstBeghouled.CRATER_FILL_SUN,
		str(fill_card.sun_cost if fill_card != null else "没有第五张"))
	_check(a, "有坑时填坑卡是亮的", fill_card != null and fill_card.is_can_click,
		str(fill_card.is_can_click if fill_card != null else "null"))
	if fill_card != null:
		fill_card._on_button_pressed()
	await a.wait(0.5)
	_check(a, "点填坑卡填掉了弹坑", not mgr.is_crater(victim), str(mgr.is_crater(victim)))
	_check(a, "填完坑那格长出新植物", mgr.get_cell_plant(victim) != null)
	_check(a, "没坑了填坑卡被封住（置灰且点不动）",
		fill_card != null and fill_card.is_blocked and not fill_card.is_can_click,
		str(fill_card.is_blocked) if fill_card != null else "null")

	# ------------------------------------------------ STEP5 买升级
	a.log("STEP5 花阳光买升级（豌豆射手 → 双重射手）")
	EventBus.push_event("add_sun_value", [2000])
	var upgrade_ok: bool = mgr.try_buy_upgrade(0)
	_check(a, "阳光够时买升级成功", upgrade_ok, str(upgrade_ok))
	## 换场要等两帧，之后若摆出死局还要「提示 4 秒再刷新」；一律等到锁解开再验（上限 10 秒）
	await _wait_unlocked(a, mgr)
	_check(a, "升级被记成已购买", mgr.purchased_upgrades[0], str(mgr.purchased_upgrades[0]))
	_check(a, "阳光被扣掉 1000", mgr.get_sun() <= 2000, "阳光=" + str(mgr.get_sun()))
	var old_num := 0
	var new_num := 0
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			var t = mgr.get_cell_type(mgr.get_cell(row, col))
			if t == CharacterRegistry.PlantType.P001PeaShooterSingle:
				old_num += 1
			elif t == CharacterRegistry.PlantType.P008PeaShooterDouble:
				new_num += 1
	_check(a, "场上不再有豌豆射手", old_num == 0, "剩余=" + str(old_num))
	_check(a, "场上出现了双重射手", new_num > 0, "数量=" + str(new_num))
	## 换场那两帧里棋盘是半空的（不许玩家插手），换完必须还能玩：没有现成的连线 + 有步可走
	_check(a, "换场后没有现成的连线", mgr._find_match_groups(mgr._build_type_grid()).is_empty())
	_check(a, "换场后还有步可走", mgr._has_possible_move())
	_check(a, "同一档升级不能买第二次", not mgr.try_buy_upgrade(0), "第二次购买该返回 false")
	## 换 plants 期间 / 结算期间锁操作：is_resolving 为真时不该受理点击
	_check(a, "换场已完成（锁已解开）", not mgr._is_replacing, "_is_replacing=" + str(mgr._is_replacing))

	# ------------------------------------------------ STEP5.5 卡槽里的自定义种子包
	a.log("STEP5.5 卡槽里的自定义种子包（三档升级 + 刷新盘面 + 填坑）")
	var battle = mg.card_manager.card_slot_battle
	var packets = battle.curr_cards
	_check(a, "出战卡槽里有 5 张自定义种子包", packets.size() == 5, "数量=" + str(packets.size()))
	if packets.size() == 5:
		_check(a, "五张卡的阳光消耗是 1000 / 500 / 250 / 100 / 200",
			packets[0].sun_cost == 1000 and packets[1].sun_cost == 500
			and packets[2].sun_cost == 250 and packets[3].sun_cost == 100
			and packets[4].sun_cost == 200,
			str(packets.map(func(c): return c.sun_cost)))
		## 第二张：500 阳光把场上（以及以后长出来的）小喷菇全换成大喷菇，买完这张卡永久置灰
		EventBus.push_event("add_sun_value", [1000])
		await a.wait(0.3)
		var sun_before_upgrade: int = mgr.get_sun()
		packets[1]._on_button_pressed()
		await _wait_unlocked(a, mgr)
		_check(a, "点第二张卡买成了那一档升级", mgr.purchased_upgrades[1], str(mgr.purchased_upgrades[1]))
		_check(a, "买升级扣掉 500 阳光", mgr.get_sun() == sun_before_upgrade - 500,
			str(sun_before_upgrade) + " -> " + str(mgr.get_sun()))
		_check(a, "买过的卡被永久置灰（再点不动）",
			packets[1].is_disabled_forever and not packets[1].is_can_click)
		## 第四张：100 阳光刷新（重排）场上所有植物
		var sun_before_refresh: int = mgr.get_sun()
		packets[3]._on_button_pressed()
		await a.wait(0.5)
		_check(a, "点第四张卡刷新盘面花掉 100 阳光", mgr.get_sun() == sun_before_refresh - 100,
			str(sun_before_refresh) + " -> " + str(mgr.get_sun()))
		_check(a, "刷新后盘面仍可玩（无现成连线 + 有步可走）",
			mgr._find_match_groups(mgr._build_type_grid()).is_empty() and mgr._has_possible_move())

	# ------------------------------------------------ STEP5.6 死局：先提示，隔几秒再刷新
	a.log("STEP5.6 死局提示（提示 → 等待 NO_MOVE_TIP_WAIT 秒 → 刷新）")
	## 摆一个「怎么换都凑不出连线」的死局：三种植物按对角线排（横竖都没有三连，
	## 且**任意相邻两格交换都换不出三连** —— 两种植物隔格排的棋盘格是有步可走的，不能用来验死局）
	## 先整盘清（连弹坑一起清，否则坑占着格子摆不出完整图案）
	var dead_types := [
		ConstBeghouled.BASE_PLANT_TYPES[0],
		ConstBeghouled.BASE_PLANT_TYPES[1],
		ConstBeghouled.BASE_PLANT_TYPES[2],
	]
	mgr._clear_board()
	await a.wait(0.6)
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			mgr.get_cell(row, col).create_plant(dead_types[(row + col) % 3],
				false, false, false, false)
	await a.wait(0.3)
	var is_dead: bool = mgr._find_match_groups(mgr._build_type_grid()).is_empty() \
		and not mgr._has_possible_move()
	_check(a, "摆出来的是死局（无连线可消 + 无步可走）", is_dead)
	if not is_dead:
		## 摆场被中途干扰（比如僵尸啃出弹坑）就自洗一遍，别让 STEP6 卡在「找不到一步交换」上
		a.log("  [skip] 摆场被干扰，改走直接重排，不再验提示")
		mgr._shuffle_plants()
		await a.wait(0.6)
	else:
		mgr._ensure_board_playable()
		await a.wait(1.0)
		## 提示走**教程那条屏幕下方的提示条**（TutorialAdviceUI），三消自己不再有居中 label
		var hint_ui := TutorialAdviceUI.find_level_hint(mgr.main_game)
		_check(a, "死局时先出提示（走教程提示条，文案 ConstBeghouled.NO_MOVE_TIP_TEXT）",
			hint_ui != null and hint_ui.is_advice_visible() \
				and hint_ui.get_advice_text() == ConstBeghouled.NO_MOVE_TIP_TEXT,
			"提示文案=" + str(hint_ui.get_advice_text() if hint_ui != null else "无提示条"))
		_check(a, "等待期间盘面没有被刷新", not mgr._has_possible_move())
		## 提示要停 NO_MOVE_TIP_WAIT 秒才动手刷盘：这里等的是「又有步可走」，
		## 不能等 is_resolving —— 直接调 _ensure_board_playable() 的那条路不置这个锁
		var waited_dead := 0.0
		while waited_dead < 12.0 and not mgr._has_possible_move():
			await a.wait(0.5)
			waited_dead += 0.5
		_check(a, "提示结束后盘面已刷新（又有步可走了）", mgr._has_possible_move())
		_check(a, "刷新后提示自己收起", hint_ui != null and not hint_ui.is_advice_visible(),
			"提示条可见=" + str(hint_ui.is_advice_visible() if hint_ui != null else "无提示条"))
	await _wait_unlocked(a, mgr, 12.0)

	# ------------------------------------------------ STEP6 达标通关
	a.log("STEP6 配对达标 → 出奖杯（不看波次）")
	mgr.match_num = ConstBeghouled.TARGET_MATCH_NUM - 1
	var swap_pair2 := _find_valid_swap(mgr)
	if swap_pair2.is_empty():
		_check(a, "再找到一步有效交换", false, "null")
		_finish(a)
		return
	_drag_swap(mgr, swap_pair2[0], swap_pair2[1])
	await a.wait(3.0)
	_check(a, "达标后进入 GAME_OVER（掉奖杯结算）",
		mg.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER,
		str(mg.main_game_progress))
	await a.wait(0.5)
	_check(a, "通关后进度条自己收起（不留孤儿条）", not lpc.progress_bar.visible,
		str(lpc.progress_bar.visible))

	_finish(a)


#region 工具
## 盘面上还没被收走的掉落阳光
func _collect_dropped_suns(mg) -> Array[Sun]:
	var list: Array[Sun] = []
	for child in mg.suns.get_children():
		if child is Sun and not child.collected:
			list.append(child)
	return list


## 这颗阳光是不是掉在棋盘某个格子上（掉落动画有 ±30 的偏移，判「离最近格子中心 60 以内」）
func _is_sun_on_board(mgr, sun: Sun) -> bool:
	var best := 1.0e9
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			var cell = mgr.get_cell(row, col)
			if cell == null:
				continue
			best = minf(best, sun.global_position.distance_to(cell.global_position))
	return best <= 60.0


## 模拟一次拖动：按住起点 → 把光标拖到目标格 → 松手（与玩家按住拖过去等价）。
## 探针里改不动真实光标位置，这里把「按下时光标的位置」往反方向挪一格，
## 让 _check_drag_swap() 算出来的位移正好指向目标格（够 DRAG_SWAP_RATIO 的半格线）
func _drag_swap(mgr, from_cell: PlantCell, to_cell: PlantCell) -> bool:
	mgr._on_press_cell(from_cell)
	if mgr._drag_from_cell == null:
		return false
	var offset: Vector2i = to_cell.row_col - from_cell.row_col
	var delta := Vector2(offset.y * from_cell.size.x, offset.x * from_cell.size.y) * 0.9
	mgr._drag_start_pos = from_cell.get_local_mouse_position() - delta
	return mgr._check_drag_swap()


## 找一对「交换后能凑成连线」的相邻格子（与玩家拖一下等价）
func _find_valid_swap(mgr) -> Array:
	var grid: Array[Array] = mgr._build_type_grid()
	## 只试右邻与下邻（左 / 上邻会被反过来试到，试两次就够了）
	var neighbor_offsets: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0)]
	for row in range(mgr.board_row_num):
		for col in range(mgr.board_col_num):
			for offset in neighbor_offsets:
				var row2: int = row + offset.x
				var col2: int = col + offset.y
				if row2 >= mgr.board_row_num or col2 >= mgr.board_col_num:
					continue
				var t1 = grid[row][col]
				var t2 = grid[row2][col2]
				if t1 == CharacterRegistry.PlantType.Null or t2 == CharacterRegistry.PlantType.Null:
					continue
				grid[row][col] = t2
				grid[row2][col2] = t1
				var matched: bool = mgr._has_match_at(grid, row, col) or mgr._has_match_at(grid, row2, col2)
				grid[row][col] = t1
				grid[row2][col2] = t2
				if matched:
					return [mgr.get_cell(row, col), mgr.get_cell(row2, col2)]
	return []


## 等三消解锁：结算 / 换场 / 死局刷新期间 _can_operate() 为假，后面要靠玩家操作的断言得先等它跑完
func _wait_unlocked(a, mgr, timeout: float = 10.0) -> void:
	var waited := 0.0
	while waited < timeout:
		if not mgr.is_resolving and not mgr._is_replacing:
			return
		await a.wait(0.5)
		waited += 0.5


## 等主游戏推进到某个阶段
func _wait_progress(a, mg, progress, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if mg.main_game_progress == progress:
			return true
		await a.wait(0.5)
		waited += 0.5
	_check(a, "等到阶段 " + str(progress), false, "当前阶段=" + str(mg.main_game_progress))
	return false


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[BEGHOULED] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
