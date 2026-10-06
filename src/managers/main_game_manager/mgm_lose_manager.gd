extends MainGameSubManager
class_name MgmLoseManager
## 主游戏的「僵尸进家 / 失败流程」子管理器
## （原 MainGameManager 的 `#region 游戏结束` 前半段，见 docs/参考存档/重构拆分方案.md 的 B2）
##
## 谁在用它：
##   EventBus "zombie_go_home" —— 僵尸走到房门口时由僵尸自己推送

## 僵尸进家panel（由 BackgroundManager 按地图数据装配，见 background_manager.gd）
var panel_zombie_go_home: Panel
## 僵尸进家后站的位置
var marker_2d_zombie_go_home: Marker2D

## 我是僵尸模式的失败检查计时器（只在 is_zombie_mode 关卡创建）
var zombie_mode_lose_check_timer: Timer
## 我是僵尸模式失败检查间隔（秒）
const ZOMBIE_MODE_LOSE_CHECK_INTERVAL := 1.0


func init_manager() -> void:
	## 僵尸进家
	EventBus.subscribe("zombie_go_home", on_zombie_go_home)
	## 我是僵尸模式：僵尸进家不判负（is_zombie_can_home = false），
	## 失败只能靠「僵尸死光 + 阳光不够再放一只」来判，见 _on_zombie_mode_lose_check_timeout
	if game_para.is_zombie_mode:
		_create_zombie_mode_lose_check_timer()


## 修改僵尸位置
func change_zombie_position(zombie:Zombie000Base):
	## 要删除碰撞器，不然会闪退(这里好像是因为暂停的时候会重复循环执行一些代码，不清楚为什么)
	zombie.hurt_box_component.free()
	zombie.get_parent().remove_child(zombie)
	panel_zombie_go_home.add_child(zombie)
	zombie.position = marker_2d_zombie_go_home.position
	## 屋顶与夜屋顶（僵王关）都是斜面，进家后僵尸要顺着斜面滑下去
	if game_para.game_BG == ConstLevelData.GameBg.Roof or game_para.game_BG == ConstLevelData.GameBg.Boss:
		roof_zombie_go_home(zombie)


func roof_zombie_go_home(zombie:Zombie000Base):
	Log.debug("禁用僵尸移动组件")
	zombie.move_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)
	await get_tree().create_timer(3).timeout
	var tween = zombie.create_tween()
	tween.tween_property(zombie, "position:y", 300, 10.0).as_relative()


## 僵尸进房
func on_zombie_go_home(zombie:Zombie000Base):
	main_game.save_manager.re_main_game()

	main_game.main_game_progress = MainGameManager.E_MainGameProgress.GAME_OVER
	main_game.card_slot_root.visible = false

	## 设置相机可以移动
	main_game.camera_2d.process_mode = Node.PROCESS_MODE_ALWAYS
	## 游戏暂停
	TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.GameOver)
	call_deferred("change_zombie_position", zombie)
	## 自定义光标（跟着鼠标走的道具）由道具自己按游戏阶段收起来：
	## 上面切到 GAME_OVER 时它已经收到 main_game_progress_update 把自己停用了，这里不用再管
	await get_tree().create_timer(1).timeout

	## 拍房子：回到背景左上角（房子在 world -181..-32，只有相机贴着背景左边界才拍得到）
	main_game.camera_2d.move_to(MainGameCamera.CAM_POS_INIT, 2)
	SoundManager.play_other_SFX("losemusic")
	await get_tree().create_timer(3).timeout
	SoundManager.play_other_SFX("scream")
	main_game.ui_remind_word.zombie_won_word_appear()


#region 我是僵尸模式的失败判定

## 原版规则：我是僵尸模式下僵尸进家不判负，唯一失败方式是
## 「场上没有僵尸 + 阳光不足以放下任何一只僵尸」（最便宜的僵尸 50 阳光），
## 失败提示为 lawn_strings.txt 的 [I_ZOMBIE_DEATH_MESSAGE]「你失去了所有的僵尸！」。
## 不判负的话玩家会卡在原地：没有僵尸就再也产不出阳光（阳光只来自啃食向日葵），关卡永远结束不了。
##
## 用 1 秒轮询而不是只挂僵尸数量变化信号：草坪上可能还躺着没捡的阳光（10 秒后自行消失），
## 捡起来就够再放一只僵尸了，此时不该判负；等它消失后再判，玩家不会莫名其妙就输。
func _create_zombie_mode_lose_check_timer() -> void:
	zombie_mode_lose_check_timer = Timer.new()
	zombie_mode_lose_check_timer.wait_time = ZOMBIE_MODE_LOSE_CHECK_INTERVAL
	zombie_mode_lose_check_timer.timeout.connect(_on_zombie_mode_lose_check_timeout)
	add_child(zombie_mode_lose_check_timer)
	zombie_mode_lose_check_timer.start()


func _on_zombie_mode_lose_check_timeout() -> void:
	## 只在游戏进行阶段判负：选卡 / 重新选卡阶段场上必然没有僵尸
	if main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		return
	if main_game.zombie_manager.curr_zombie_num != 0:
		return
	if get_can_use_sun_on_zombie_mode() >= get_min_zombie_sun_cost():
		return
	on_zombie_mode_lose()


## 当前还能用的阳光：已收集的 + 草坪上还没捡的（没捡的也算，捡起来就能用）
func get_can_use_sun_on_zombie_mode() -> int:
	var sun_sum: int = main_game.card_manager.card_slot_battle.sun_value
	for node in main_game.suns.get_children():
		var sun := node as Sun
		if sun != null:
			sun_sum += sun.sun_value
	return sun_sum


## 本关最便宜的一只僵尸要多少阳光（原版最便宜的僵尸 = 50，没有僵尸卡时返回 0 = 不判负）
func get_min_zombie_sun_cost() -> int:
	var min_cost := 0
	for card: Card in main_game.card_manager.card_slot_battle.curr_cards:
		if card.card_zombie_type == CharacterRegistry.ZombieType.Null:
			continue
		if min_cost == 0 or card.sun_cost < min_cost:
			min_cost = card.sun_cost
	return min_cost


## 我是僵尸模式失败：走与「僵尸进家」同一套失败流程（重开存档 + 失败音乐 + 红字）
func on_zombie_mode_lose() -> void:
	Log.debug("我是僵尸模式：僵尸全部阵亡且阳光不足，判负")
	if is_instance_valid(zombie_mode_lose_check_timer):
		zombie_mode_lose_check_timer.stop()

	main_game.save_manager.re_main_game()

	main_game.main_game_progress = MainGameManager.E_MainGameProgress.GAME_OVER
	main_game.card_slot_root.visible = false

	## 游戏暂停
	TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.GameOver)
	SoundManager.play_other_SFX("losemusic")
	await get_tree().create_timer(3).timeout
	SoundManager.play_other_SFX("scream")
	main_game.ui_remind_word.zombie_won_word_appear()

#endregion
