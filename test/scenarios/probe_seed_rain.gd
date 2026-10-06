extends RefCounted
## 探针：迷你游戏第 4 关「种子雨」的**天降种子卡**
## 覆盖：
##   ① 发卡器挂在本关自己身上：卡片前景层上有一个 CardSlotSeedRain，定时器在跑
##      （card_manager 里已经没有任何 is_seed_rain 分支，发卡器由关卡脚本建）
##   ② 出卡节奏：一段时间内发卡器累计出卡数持续增长（卡槽自带 3~5 秒一张的定时器）
##   ③ 卡片可用：点一下能拿到手上（手持类型 = Character），点草坪能种下去
##   ④ 通关正常：走通关结算后进入 GAME_OVER，流程不卡死
## 机器可读汇总：最后一行 [SEEDRAIN] result=PASS|FAIL failed=<n>

const LEVEL_SEED_RAIN := "res://src/levels/mode_minigame/minigame_04_seed_rain.gd"

## 等开战的秒数上限（本关流程：展示僵尸 → 等 3 秒 → 相机归位 → 小推车 → 准备安放 → 开战）
const WAIT_MAIN_GAME := 60.0
## 采节奏的窗口秒数（卡槽定时器 3~5 秒一张，窗口内至少该出 2 张）
const RHYTHM_WINDOW := 12.0

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 种子雨（天降种子卡 / 迷你游戏 04） ==========")
	var para = (load(LEVEL_SEED_RAIN) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL_SEED_RAIN)
		_finish(a)
		return
	Global.game_para = para
	## 让上一场景的收尾走完再切，否则 remove_child 会撞上 busy
	await a.frames(3)
	a.get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[para.game_sences])
	await a.wait(3.0)

	var mg := Global.main_game
	_check(a, "已进入主游戏", mg != null, "Global.main_game 为空")
	if mg == null:
		_finish(a)
		return

	## 等本关流程走到开战（不能选卡，流程自己往下走）
	var waited := 0.0
	while waited < WAIT_MAIN_GAME and mg.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		await a.wait(1.0)
		waited += 1.0
	_check(a, "关卡流程走到 MAIN_GAME（等了 %.0f 秒）" % waited,
		mg.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME,
		"main_game_progress=%d" % mg.main_game_progress)
	if mg.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		_finish(a)
		return

	## ① 发卡器在卡片前景层上（本关自己挂的，通用管理器不认识种子雨）
	var front := mg.card_manager.canvas_layer_card_slot_front
	var slot: CardSlotSeedRain = null
	for child in front.get_children():
		if child is CardSlotSeedRain:
			slot = child
			break
	_check(a, "卡片前景层上挂着天降种子卡的发卡器", slot != null,
		"前景层子节点=%d" % front.get_child_count())
	if slot == null:
		_finish(a)
		return
	_check(a, "发卡定时器已启动且未暂停",
		not slot.create_new_card_timer.is_stopped() and not slot.create_new_card_timer.paused,
		"stopped=%s paused=%s" % [str(slot.create_new_card_timer.is_stopped()), str(slot.create_new_card_timer.paused)])

	## ② 出卡节奏：累计出卡数在窗口内持续增长
	var num_start: int = slot.all_num_card
	await a.wait(RHYTHM_WINDOW)
	var num_end: int = slot.all_num_card
	var created: int = num_end - num_start
	a.log("  出卡节奏：%.0f 秒内发了 %d 张（累计 %d → %d）" % [RHYTHM_WINDOW, created, num_start, num_end])
	_check(a, "天降卡片按节奏持续生成（%.0f 秒内 ≥ 2 张）" % RHYTHM_WINDOW, created >= 2, "实际 %d 张" % created)
	_check(a, "场上有还没被用掉的临时卡片", mg.card_manager.curr_temp_cards.size() > 0,
		"curr_temp_cards=%d" % mg.card_manager.curr_temp_cards.size())

	## ③ 卡片可用：点一下拿到手上 → 点草坪种下去
	var card: Card = null
	for temp_card in mg.card_manager.curr_temp_cards:
		if is_instance_valid(temp_card) and temp_card.card_plant_type != CharacterRegistry.PlantType.Null:
			card = temp_card
			break
	_check(a, "场上有一张植物类的天降卡片", card != null, "没有找到植物卡")
	if card != null:
		var center: Vector2 = a.screen_center(card)
		a.log("  卡片 %s 屏幕中心=(%.0f, %.0f)" % [card.name, center.x, center.y])
		await a.click(center.x, center.y)
		await a.wait(0.6)
		var holding: bool = mg.hand_manager.is_holding_hand()
		_check(a, "点卡片后拿到手上", holding,
			"手持类型=%d" % mg.hand_manager.get_curr_hand_type())
		if holding:
			await a.click_plant_cell(2, 3)
			await a.wait(0.6)
			var cell = mg.plant_cell_manager.all_plant_cells[2][3]
			_check(a, "草坪 (2,3) 上种出了植物", cell.get_curr_plant_num() > 0,
				"格子植物数=%d" % cell.get_curr_plant_num())
			a.log("  草坪摘要：" + a.describe_plant_cells())

	## ④ 通关：走一遍结算（Ctrl+D + 0 的入口）
	## 结算会写通关存档再切回选关 / 主菜单，所以「进到 GAME_OVER」和「已经切出主游戏」都算跑通
	mg.shortcut_win_main_game()
	var is_over := false
	for _i in range(12):
		await a.wait(0.5)
		if not is_instance_valid(mg):
			is_over = true
			break
		if mg.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER:
			is_over = true
			break
	_check(a, "通关结算跑完（进到 GAME_OVER / 已切出主游戏）", is_over,
		"mg有效=%s progress=%s" % [str(is_instance_valid(mg)),
			str(mg.main_game_progress if is_instance_valid(mg) else -1)])

	_finish(a)


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[SEEDRAIN] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
