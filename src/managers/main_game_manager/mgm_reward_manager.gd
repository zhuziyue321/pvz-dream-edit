extends MainGameSubManager
class_name MgmRewardManager
## 主游戏的「通关结算线」子管理器：奖杯 -> 通关奖励掉落 -> 通关结算 -> 跳商店
## （原 MainGameManager 的 `#region 奖杯与通关奖励` + 通关结算几块，
##   见 docs/参考存档/重构拆分方案.md 的 B2）
##
## 谁在用它：
##   EventBus "create_trophy"   —— 最后一波清完由 ZombieManager / PlantCellManager 推送
##   EventBus "win_main_game"   —— 玩家点开奖杯（src/ui/main_game_ui/trophy.gd）
##   MainGameManager 快捷键 Ctrl+D —— shortcut_win_main_game() 走这里结算
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

## 本关的通关解锁道具是否已经掉过（防止同一关重复掉落）
var is_unlock_drop_on_level_complete_done := false
## 本关的首次通关奖励是否已经掉过（奖励接管结算后就不再出奖杯，也防重复掉落）
var is_adventure_reward_drop_done := false
## 通关掉落物的收尾表演是否已经播完（屏幕已经全白，可以切场景了）
var is_pickup_perform_finished := false


func init_manager() -> void:
	## 创建奖杯
	EventBus.subscribe("create_trophy", create_trophy)
	## 游戏胜利
	EventBus.subscribe("win_main_game", win_main_game)
	## 通关掉落物被点开后的收尾表演播完（见 CanvasLayerWhiteScreen）
	EventBus.subscribe("level_complete_pickup_finished", _on_level_complete_pickup_finished)


## 创建奖杯（冒险模式首次通关时改成掉本关奖励，见 drop_adventure_reward_on_level_complete）
func create_trophy(glo_pos:Vector2):
	Log.debug("胜利条件达成，创建奖杯")
	## 如果不是最后一轮游戏，触发下一轮
	if main_game.curr_game_round != game_para.game_round:
		main_game.start_next_round_game()
		return
	## 本关结算已经交给首次通关奖励，不再重复出奖杯
	if is_adventure_reward_drop_done:
		return

	## 冒险模式首次通关：掉本关奖励代替奖杯，玩家点开后直接结算
	if await drop_adventure_reward_on_level_complete(glo_pos):
		return

	## 本关的解锁道具是"通关时掉落"（关卡数据 drop_unlock_on_level_complete）：
	## 先掉道具，等玩家点开再抛奖杯
	await drop_unlock_item_on_level_complete(glo_pos)

	Log.debug("=======================游戏结束，您获胜了=======================")
	var trophy = SceneRegistry.TROPHY.instantiate()
	main_game.canvas_layer_temp.add_child(trophy)
	trophy.global_position = glo_pos
	if trophy.global_position.x >= 750:
		var x_diff = trophy.global_position.x - 700
		throw_to(trophy, trophy.position - Vector2(x_diff + randf_range(-50,50), 0))
	elif trophy.global_position.x <= 50:
		var x_diff = trophy.global_position.x - 100
		throw_to(trophy, trophy.position - Vector2(x_diff + randf_range(-50,50), 0))

	else:
		throw_to(trophy, trophy.position - Vector2(randf_range(-50,50), 0))


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
		Log.debug("本关已通关过，不再掉落通关解锁道具")
		return
	is_unlock_drop_on_level_complete_done = true
	var new_drop := main_game.drop_item_manager.create_unlock_drop_on_level_complete(glo_pos)
	await wait_unlock_drop_closed(new_drop)


## 冒险模式首次通关掉落本关奖励（原版：戴夫给的礼物盒 / 铲子 / 车钥匙 / 玉米卷）
## 奖励内容查 ConstAdventureReward，与选关界面「本关看点」是同一套表；本关没有奖励时返回 false
## 植物类奖励掉的是种子包（SeedPacket，僵尸掉落、逻辑同金币），道具类奖励仍是礼物盒（Present）
## 奖励**完全代替奖杯**：玩家点开（或道具自动消失）后直接走通关结算，本关不再出奖杯
## 返回 true 表示结算已由奖励接管，调用方不要再抛奖杯
func drop_adventure_reward_on_level_complete(glo_pos:Vector2) -> bool:
	if game_para == null or is_adventure_reward_drop_done:
		return false
	## 只有冒险模式的首次通关掉奖励：重打已通关过的关卡仍按原样出奖杯
	if _get_curr_adventure_level() <= 0 or main_game.is_curr_level_success():
		return false
	var new_drop := main_game.drop_item_manager.create_adventure_reward_drop(glo_pos)
	if new_drop == null:
		return false
	is_adventure_reward_drop_done = true
	main_game.main_game_progress = MainGameManager.E_MainGameProgress.GAME_OVER
	Log.debug("=======================首次通关，掉落本关奖励代替奖杯=======================")
	if await wait_reward_drop_opened(new_drop):
		## 点开后由 CanvasLayerWhiteScreen 播「居中 -> 发光 -> 白屏」，屏幕全白了才结算
		await wait_pickup_perform_finished()
	else:
		## 没被点开（自动消失）也要结算，不能把玩家一直卡在场上
		await wait_unlock_drop_closed(new_drop)
	win_main_game()
	return true


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


## 当前关卡完成
func win_main_game():
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

	if is_need_goto_store_on_win(is_shop_unlocked_before, shop_expand_stage_before):
		GlobalUtils.change_scene(
			Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Store]
		)
		return

	if is_need_goto_almanac_on_win(is_almanac_unlocked_before):
		GlobalUtils.change_scene(
			Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Almanac]
		)
		return

	GlobalUtils.change_scene(Global.main_scene_registry.MainScenesMap.get(game_para.game_mode, Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu]))


## 通关后是否需要直接进商店（原版：3-4 拿到车钥匙开张、4-4 拿到玉米卷扩充、5-1 / 5-10 分批上架）
## 用"写通关存档前后各取一次"的判定，只有本关打通才刚触发时为真，
## 重打同一关或打别的关卡不会重复跳商店
func is_need_goto_store_on_win(is_shop_unlocked_before: bool, shop_expand_stage_before: int) -> bool:
	if not is_shop_unlocked_before and Global.global_game_state.is_shop_unlocked():
		Log.debug("通关 3-4 拿到车钥匙，商店解锁，直接进入商店")
		return true
	if Global.global_game_state.get_shop_expand_stage() > shop_expand_stage_before:
		Log.debug(str("通关冒险模式 ") \
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
	Log.debug("通关 2-4 拿到大图鉴，图鉴解锁，直接打开图鉴")
	return true


## 本关的冒险模式关卡序号(1-1 = 1 …… 5-10 = 50)，非冒险模式返回 0
func _get_curr_adventure_level() -> int:
	if game_para == null:
		return 0
	return Global.global_game_state.get_adventure_level_on_save_game_name(game_para.save_game_name)
