extends MainGameSubManager
class_name MgmRewardManager
## 主游戏的「通关结算线」子管理器：奖杯 -> 通关奖励掉落 -> 通关结算 -> 跳商店
## （原 MainGameManager 的 `#region 奖杯与通关奖励` + 通关结算几块，
##   见 docs/参考存档/重构拆分方案.md 的 B2）
##
## **胜利条件 = 关卡流程跑完**（不再由「战斗打完」判胜）：
##   · 战斗打完（最后一波清完 / 罐子全砸开 / 僵王倒下后清场）推的是 EventBus "battle_finished"，
##     **只负责「还有下一轮就切轮」**（多轮关卡），最后一轮打完什么都不做 —— 见 on_battle_finished()
##   · 关卡流程跑完（run_flow / 老时间轴事件数组）由 LevelTimelineManager 调
##     force_win_on_flow_finished()：**强制胜利并给奖杯**
##   · 关卡流程内想提前判胜：LevelScriptBase.win_with_trophy()（给奖杯）/ win_with_item()（给物品）
##   · 玩法自己判胜的关卡（僵尸迷阵 / 水族馆 / 观星 / 拉霸 / 我是僵尸的脑子全吃掉）
##     照旧推 EventBus "create_trophy"，走的也是下面这条胜利线
##
## 谁在用它：
##   EventBus "battle_finished" —— 本轮战斗打完由 ZombieManager / PlantCellManager 推送
##   EventBus "create_trophy"   —— 玩法自己判胜 / 关卡流程判胜
##   MainGameManager            —— 快捷键 Ctrl+D **直接调** `shortcut_win_main_game()`
##                                 （不是走 EventBus：那个 "win_main_game" 事件全仓 0 处 push，已删）
##   LevelTimelineManager       —— 关卡流程跑完强制胜利
##   关卡脚本 `await gain("taco")` —— LevelScriptBase.gain() 转到这里
##
## **战利品（奖杯 / 玉米卷 / 种子包…）统一按名字生产**：名字 -> 贴图那张表在 LootRegistry，
## 生产在 DropItemManager.create_loot_drop，掉落 + 等点开 + 收尾表演 + 结算在 gain_loot()
##
## 事件订阅放在 init_manager()：由 MainGameManager.init_manager() 统一调用，
## 不能在 _ready 里订阅 —— 那时 game_para 还没初始化完。

## 等通关解锁道具被拾取的兜底秒数（道具自己 15 秒后自动消失，这里只防止意外情况卡住流程）
const UNLOCK_DROP_WAIT_TIME := 20.0
## 等解锁道具时的轮询间隔秒数
const UNLOCK_DROP_WAIT_STEP := 0.25
## 等「居中 -> 发光 -> 白屏」这段收尾表演的兜底秒数（表演层正常跑完只要几秒）
const PICKUP_PERFORM_WAIT_TIME := 12.0
## 等收尾表演的轮询间隔秒数（白屏到底就该切场景，轮询要比解锁道具那套细）
const PICKUP_PERFORM_WAIT_STEP := 0.05

## 本关的胜利流程是否已经启动（防重复：流程内已经判过胜时，run_flow 结束不再重复结算）
var is_win_started := false
## 本关是否已经结算过（写通关存档 + 切场景的那一步只走一次）
var is_win_settled := false
## 最近一次「本轮战斗打完」的位置：关卡流程跑完强制胜利时，奖杯就掉在这个位置
var last_battle_finish_glo_pos := Vector2.ZERO
## 本关的通关解锁道具是否已经掉过（防止同一关重复掉落）
var is_unlock_drop_on_level_complete_done := false
## 通关掉落物的收尾表演是否已经播完（屏幕已经全白，可以切场景了）
var is_pickup_perform_finished := false


func init_manager() -> void:
	## 本轮战斗打完（只切下一轮，不判胜）
	EventBus.subscribe(ConstEventName.BATTLE_FINISHED, on_battle_finished)
	## 创建奖杯
	EventBus.subscribe(ConstEventName.CREATE_TROPHY, create_trophy)
	## 通关掉落物被点开后的收尾表演播完（见 CanvasLayerWhiteScreen）
	EventBus.subscribe(ConstEventName.LEVEL_COMPLETE_PICKUP_FINISHED, _on_level_complete_pickup_finished)


## 本轮战斗打完 —— **只切下一轮，不判胜**（EventBus "battle_finished"）
## 胜利条件已经是「关卡流程跑完」，清场自己不再结算（见本文件头的三条说明）
func on_battle_finished(glo_pos:Vector2) -> void:
	last_battle_finish_glo_pos = glo_pos
	if not is_instance_valid(main_game) or game_para == null:
		return
	if main_game.curr_game_round == game_para.game_round:
		return
	main_game.start_next_round_game()


## 创建奖杯（EventBus "create_trophy"：玩法自己判胜的关卡，见本文件头）
## 冒险模式首次通关时掉的是本关奖励（不是奖杯）—— 那一句写在关卡脚本的 run_flow() 末尾
## （`await gain(level_complete_loot)`，见 LevelScriptBase.gain），本条只管奖杯兜底
func create_trophy(glo_pos:Vector2):
	## 如果不是最后一轮游戏，触发下一轮
	if main_game.curr_game_round != game_para.game_round:
		main_game.start_next_round_game()
		return
	await win_with_trophy(glo_pos)


## **关卡流程跑完：强制胜利并给奖杯** —— 胜利条件 = 关卡流程跑完
## 由 LevelTimelineManager 在 run_flow() / 老时间轴事件数组跑完后调用（那是关卡流程的唯一终点）
func force_win_on_flow_finished() -> void:
	if not is_instance_valid(main_game) or main_game.game_para == null:
		return
	## 已经判过胜（流程内自己调了 win_*）/ 已经结算 / 已经失败：都不再重复判胜
	if is_win_started or is_win_settled \
			or main_game.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER:
		return
	## 多轮关卡：本轮跑完还有下一轮，切轮由「本轮战斗打完」负责（见 on_battle_finished）
	if main_game.curr_game_round != main_game.game_para.game_round:
		return
	await win_with_trophy(get_default_glo_pos())


## **本关收尾的掉落链**（= 解锁道具 + 奖杯兜底），顺序固定两步：
##   1. 掉通关解锁道具（drop_unlock_item_on_level_complete）：本关配了才掉，点开后还要往下抛奖杯；
##   2. 抛奖杯（_spawn_trophy）—— **只是 fallback**：本关没有奖励可掉时（绝大多数关卡 / 重打已通关的关）
##      走这一步，玩家点开奖杯再结算。
## **本关奖励不在这条链上**：冒险模式「首次通关掉本关奖励」由关卡脚本自己收尾
## （run_flow() 末尾 `await gain(level_complete_loot)`），本关掉什么写在那一关的脚本上。
## 调用方：start_win_on_level_complete() / force_win_on_flow_finished() /
##         EventBus "create_trophy" / 关卡流程内 LevelScriptBase.win_with_trophy()
func win_with_trophy(glo_pos:Vector2) -> void:
	if not _try_start_win():
		return
	## 本关的解锁道具是"通关时掉落"（关卡数据 drop_unlock_on_level_complete）：
	## 先掉道具，等玩家点开再抛奖杯
	await drop_unlock_item_on_level_complete(glo_pos)
	## 等道具那几秒里玩家可能已经退出关卡：主游戏没了就不抛了
	if not is_instance_valid(main_game):
		return
	await _spawn_trophy(glo_pos)


## **胜利并给物品**：掉本关的通关解锁道具，**不出奖杯**，发完直接结算
## 由关卡流程在 run_flow() 内调用（LevelScriptBase.win_with_item）
## 本关没有可掉的物品时也要结算，不能把玩家一直卡在场上
func win_with_item(glo_pos:Vector2) -> void:
	if not _try_start_win():
		return
	await drop_unlock_item_on_level_complete(glo_pos)
	if not is_instance_valid(main_game):
		return
	win_main_game()


## **关卡流程末尾的收尾判胜**（LevelScriptBase.win_on_level_complete 调它）：
## 走的是上面 win_with_trophy() 那条掉落链 —— 掉通关解锁道具，然后掉奖杯
##
## **不是协程**：胜利线要等玩家点开奖励 / 奖杯，最后还会切场景；挂在关卡流程的协程上会把
## 主游戏卡在 _ready()，切场景时协程还会醒在已释放的对象上（见 LevelTimelineManager 那条注释）
func start_win_on_level_complete(glo_pos:Vector2) -> void:
	if not is_instance_valid(main_game):
		return
	## 已经判过胜 / 已经结算 / 已经失败（僵尸进屋）：都不再判胜
	if is_win_started or is_win_settled \
			or main_game.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER:
		return
	win_with_trophy(glo_pos)


## **只掉奖杯**：本关奖励那两步一步都不走 —— 重打**已经通关过**的关卡用这条
## （关卡脚本里 `if is_curr_level_success(): win_with_trophy_only()` 那条分支，
##  关卡脚本自己就把「给不给奖励」判明白了，这里不必再查一次存档）
## 判据与 start_win_on_level_complete() 同一套，同样**不是协程**
func start_trophy_only(glo_pos:Vector2) -> void:
	if not is_instance_valid(main_game):
		return
	if is_win_started or is_win_settled \
			or main_game.main_game_progress == MainGameManager.E_MainGameProgress.GAME_OVER:
		return
	if not _try_start_win():
		return
	_spawn_trophy(glo_pos)


## 本关胜利流程的入口闸门：一关只判一次胜（流程内判过就不再重复）
func _try_start_win() -> bool:
	if is_win_started:
		return false
	is_win_started = true
	return true


## 抛一个奖杯出来（**奖杯也是一种战利品**：按名字取贴图生产掉落物，见 LootRegistry）
## 玩家点开 -> CanvasLayerWhiteScreen 播「居中 -> 发光 -> 白屏」-> 屏幕全白了结算切场景
func _spawn_trophy(glo_pos:Vector2) -> void:
	Log.info("=======================游戏结束，您获胜了=======================")
	await gain_loot(LootRegistry.TROPHY, glo_pos)


## **掉一个战利品给玩家** —— 关卡脚本里 `await gain("taco")` 走的就是这一条（见 LevelScriptBase.gain）
##
## [param loot_name] 战利品名字（见 LootRegistry）；[param glo_pos] 掉落位置。
## 一关只生效一次（_try_start_win）：先调的那条说了算，之后流程跑完不再重复结算。
func gain(loot_name:String, glo_pos:Vector2) -> void:
	if not _try_start_win():
		return
	await gain_loot(loot_name, glo_pos)


## 掉战利品的整条线：**生产掉落物 -> 等玩家点开 -> 等收尾表演 -> 结算切场景**
## 掉落物是「本关结算线」上的（mark_level_complete_drop），点开后走
## CanvasLayerWhiteScreen 那段「移向屏幕中央 -> 发光 -> 屏幕逐渐变白」，全白了才结算。
## 战利品没被点开（超时自动消失）也要结算，不能把玩家一直卡在场上。
## 名字没登记 / 掉落物没建出来时直接结算 —— 掉落物建不出来比「少看一次表演」严重得多。
func gain_loot(loot_name:String, glo_pos:Vector2) -> void:
	if not is_instance_valid(main_game) or main_game.drop_item_manager == null:
		return
	var new_drop := main_game.drop_item_manager.create_loot_drop(loot_name, glo_pos)
	if new_drop == null:
		Log.error("战利品没建出来，直接结算：" + loot_name)
		win_main_game()
		return
	main_game.drop_item_manager.mark_level_complete_drop(new_drop)
	main_game.main_game_progress = MainGameManager.E_MainGameProgress.GAME_OVER
	Log.info("=======================掉落战利品：" + loot_name + "=======================")
	## 礼物盒类战利品（奖杯 / 玉米卷）照旧被抛到画面内的落点上；
	## 种子包自己有抛物线弹出（SeedPacket.launch），不要再抛一次
	if new_drop is Present:
		throw_to(new_drop, _get_loot_throw_target(new_drop))
	if await wait_reward_drop_opened(new_drop):
		await wait_pickup_perform_finished()
	else:
		await wait_unlock_drop_closed(new_drop)
	## 等战利品这几秒里玩家可能已经退出关卡：主游戏没了就不结算了
	if not is_instance_valid(main_game):
		return
	win_main_game()


## 战利品的抛掷落点：掉在画面左右边缘时往里收，免得半个身子在屏幕外点不中
func _get_loot_throw_target(loot:Node2D) -> Vector2:
	if loot.global_position.x >= 750:
		var x_diff = loot.global_position.x - 700
		return loot.position - Vector2(x_diff + randf_range(-50,50), 0)
	if loot.global_position.x <= 50:
		var x_diff = loot.global_position.x - 100
		return loot.position - Vector2(x_diff + randf_range(-50,50), 0)
	return loot.position - Vector2(randf_range(-50,50), 0)


## 奖杯 / 通关奖励的默认落点：本轮战斗打完的位置（清场那一刻 = 最后一只僵尸死的地方），
## 本关压根没打过仗（水族馆这类）就掉屏幕中心
## 关卡流程里调 win_*() 不传位置时用这一个（见 LevelScriptBase.win_with_trophy）
func get_default_glo_pos() -> Vector2:
	if last_battle_finish_glo_pos != Vector2.ZERO:
		return last_battle_finish_glo_pos
	if not is_instance_valid(main_game):
		return Vector2(400, 300)
	return main_game.get_viewport_rect().size * 0.5


## 奖杯抛出
func throw_to(node:Node2D, target_pos: Vector2, duration: float = 1.0):
	main_game.main_game_progress = MainGameManager.E_MainGameProgress.GAME_OVER
	var start_pos = node.position
	var peak_pos = start_pos.lerp(target_pos, 0.5)
	peak_pos.y -= 50  # 向上抛

	var tween = create_tween()
	tween.tween_property(node, "position:x", target_pos.x, duration).set_trans(Tween.TRANS_LINEAR)

	tween.parallel().tween_property(node, "position:y", peak_pos.y, duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "position:y", target_pos.y, duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(duration / 2)


## 通关时掉落本关的解锁道具（关卡数据 drop_unlock_on_level_complete，原版冒险 3-4 的车钥匙）
## 只在首次通关本关时掉：重打时解锁早就给过了，不再掉第二次
## 位置用最后一只僵尸的死亡处（也就是原版"清完最后一波掉在场上"的表现）
## 冒险模式首次通关走下面的 drop_adventure_reward_on_level_complete()，那里掉完直接结算、不出奖杯，
## 所以这条只在其它模式（或冒险模式没奖励的关卡）上生效
func drop_unlock_item_on_level_complete(glo_pos:Vector2) -> void:
	if not game_para.drop_unlock_on_level_complete or is_unlock_drop_on_level_complete_done:
		return
	if main_game.is_curr_level_success():
		return
	is_unlock_drop_on_level_complete_done = true
	var new_drop := main_game.drop_item_manager.create_unlock_drop_on_level_complete(glo_pos)
	await wait_unlock_drop_closed(new_drop)


## 收尾表演播完的通知（屏幕已经全白）
func _on_level_complete_pickup_finished() -> void:
	is_pickup_perform_finished = true


## 等「居中 -> 发光 -> 白屏」这段收尾表演播完
## 表演层播到全白会推 level_complete_pickup_finished，这里轮询等它；
## 表演层缺失 / 掉落物被别的逻辑提前干掉时靠超时兜底，避免把玩家一直卡在场上
func wait_pickup_perform_finished() -> void:
	var waited := 0.0
	while not is_pickup_perform_finished and waited < PICKUP_PERFORM_WAIT_TIME:
		await get_tree().create_timer(PICKUP_PERFORM_WAIT_STEP).timeout
		waited += PICKUP_PERFORM_WAIT_STEP


## 等奖励被玩家点开，返回是否被点开；没被点开时（自动消失）也要等上限秒数再返回
## 奖励可能是种子包（SeedPacket）也可能是礼物盒（Present），两者都有 is_opened / tip_show_time
func wait_reward_drop_opened(new_drop:Node2D) -> bool:
	if new_drop == null:
		return false
	var waited := 0.0
	while is_instance_valid(new_drop) and not new_drop.is_queued_for_deletion() and waited < UNLOCK_DROP_WAIT_TIME:
		if bool(new_drop.get("is_opened")):
			return true
		await get_tree().create_timer(UNLOCK_DROP_WAIT_STEP).timeout
		waited += UNLOCK_DROP_WAIT_STEP
	return false


## 等解锁道具被拾取或自动消失后再继续出奖杯，避免玩家还没看到解锁提示就点奖杯结算切场景走人
## 道具自己有存在秒数上限（DropItemManager.UNLOCK_DROP_EXIST_TIME），这里再加一个兜底上限
func wait_unlock_drop_closed(new_drop:Node2D) -> void:
	if new_drop == null:
		return
	var waited := 0.0
	while is_instance_valid(new_drop) and not new_drop.is_queued_for_deletion() and waited < UNLOCK_DROP_WAIT_TIME:
		await get_tree().create_timer(UNLOCK_DROP_WAIT_STEP).timeout
		waited += UNLOCK_DROP_WAIT_STEP


## 「本关现在该不该结算」的问询口：外部（联机这类「结算由别人驱动」的玩法）可以占这个位。
##
## 用法：给 `Callable` 赋值一个 `func() -> bool`，**返回 false 就先不结算** ——
## 不写通关存档、不切场景，本关停在原地，等外部拿到"该结算了"的信号后**自己再调一次**
## `win_main_game()`（`is_win_settled` 不会因为被推迟而置位，所以那一次调得进来）。
## 没被占的说明"没人替我做主"，照旧结算。本体自己**从不**给这一位赋值。
var level_settle_gate: Callable = Callable()


## 当前关卡完成
func win_main_game():
	## 已经结算过：不再写第二遍通关存档 / 不再切第二次场景
	if is_win_settled:
		return
	## 先看有没有人要替这一局定结算时机（见 `level_settle_gate`）：说了"再等等"就先停在场上
	if level_settle_gate.is_valid() and not level_settle_gate.call():
		return
	is_win_settled = true
	## 游戏暂停因素、游戏速度
	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale

	## 商店解锁 / 扩展状态要在写通关存档前后各取一次：只有在"这一关打通才刚解锁 / 刚扩展"时才直接进商店，
	## 重打 3-4 / 4-4 或打别的关卡时商店早就解锁了，仍按原流程回选关界面
	var is_shop_unlocked_before: bool = Global.global_game_state.is_shop_unlocked()
	var shop_expand_stage_before: int = Global.global_game_state.get_shop_expand_stage()
	var is_almanac_unlocked_before: bool = Global.global_game_state.is_almanac_unlocked()
	main_game.save_manager.update_level_state_data_success()
	## 多轮游戏，重置主游戏数据
	if game_para.game_round != 1:
		main_game.save_manager.re_main_game()

	## 二周目：本关是冒险模式的最后一关（5-10）-> 进下一周目（进度按周目过滤，见 GlobalGameState）
	## 先按「本关是不是 5-10」挡一道，免得迷你 / 解谜 / 生存关卡通关时也来碰周目；
	## advance_adventure_round() 自己还会再核一遍「本周目 1-1 ~ 5-10 全都通了」，所以：
	##   · 调试把存档写成"半通"时不会误进;   · 重打 5-10 也不会连着进两周目（进完周目进度就归零了）。
	## 放在跳商店 / 图鉴判定**之前**：进不进下一周目与商店那两跳各管各的。
	if _get_curr_adventure_level() == ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL:
		Global.global_game_state.advance_adventure_round()

	if is_need_goto_store_on_win(is_shop_unlocked_before, shop_expand_stage_before):
		GlobalUtils.change_scene(
			Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.Store)
		)
		return

	if is_need_goto_almanac_on_win(is_almanac_unlocked_before):
		GlobalUtils.change_scene(
			Global.main_scene_registry.get_scene_path(MainSceneRegistry.MainScenes.Almanac)
		)
		return

	## 通关后回哪：本模式的选关场景；**冒险模式没有选关界面**（它的槽位故意没登记场景，
	## 见 MainSceneRegistry），于是这里退回主菜单 —— 主菜单木牌上就是下一关的关卡号，
	## 再点一次木牌就进下一关（见 StartMenuRoot._apply_adventure_button_state / _start_adventure_level）。
	## 走访问器的 fallback 参数，不再自己读 MainScenesMap。
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(game_para.game_mode, MainSceneRegistry.MainScenes.StartMenu))


## 通关后是否需要直接进商店（原版：3-4 拿到车钥匙开张、4-4 拿到玉米卷扩充、5-1 / 5-10 分批上架）
## 用"写通关存档前后各取一次"的判定，只有本关打通才刚触发时为真，
## 重打同一关或打别的关卡不会重复跳商店
func is_need_goto_store_on_win(is_shop_unlocked_before: bool, shop_expand_stage_before: int) -> bool:
	if not is_shop_unlocked_before and Global.global_game_state.is_shop_unlocked():
		Log.info("通关 3-4 拿到车钥匙，商店解锁，直接进入商店")
		return true
	if Global.global_game_state.get_shop_expand_stage() > shop_expand_stage_before:
		Log.info(str("通关冒险模式 ") \
			+ ConstUnlockLevel.get_adventure_level_name(_get_curr_adventure_level()) \
			+ str(" 商店扩充，直接进入商店"))
		return true
	return false


## 通关后是否需要直接打开图鉴（原版：2-4 掉落大图鉴后才开放图鉴）
## 与跳商店同一套「写通关存档前后各取一次」的判定：只有「打通 2-4 才刚解锁」时为真，
## 重打 2-4 或打别的关卡时图鉴早就解锁了，仍按原流程回选关界面（不会重复打开）
func is_need_goto_almanac_on_win(is_almanac_unlocked_before: bool) -> bool:
	if is_almanac_unlocked_before or not Global.global_game_state.is_almanac_unlocked():
		return false
	Log.info("通关 2-4 拿到大图鉴，图鉴解锁，直接打开图鉴")
	return true


## 本关的冒险模式关卡序号(1-1 = 1 …… 5-10 = 50)，非冒险模式返回 0
func _get_curr_adventure_level() -> int:
	if game_para == null:
		return 0
	return Global.global_game_state.get_adventure_level_on_save_game_name(game_para.save_game_name)
