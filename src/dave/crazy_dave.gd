extends Node2D
class_name CrazyDave

## 戴夫发疯动画设置为无法停止：
## crazy动画状态过度到idle动画时，
## 有渐变动画时，平底锅帽子会旋转360，因此跳过crazy对话时，动画结束才改变动画

@onready var animation_tree: AnimationTree = $AnimationTree

@onready var bubble_2: Panel = $SpeechBubble/Bubble2
@onready var speech_text_label: Label = $SpeechBubble/Bubble2/MarginContainer/SpeechTextLabel
@onready var dave_dialog_mouse_press_panel: DaveDialogMousePress = $DaveDialogMousePressPanel

@export var dialog_resource:CrazyDaveDialogResource
@export_group("资源文件赋值参数,初始化时更新赋值(动画使用)")
## 出现时是否从下往上出现
@export var is_enter_up := false
## 离开时是否被蹦极僵尸带走
@export var is_grab:=false
## 手上是否有展示物品（是否为展示物品动画）
@export var is_hand := false

@export_group("其余参数")
## 是否为激活状态，false戴夫退出
@export var is_activate := true
## 戴夫是否为idle状态，idle状态下，动画循环播放，需要等待用户点击
@export var is_idle:= true

## 说话时间长短，1,2,3，控制动画播放
var talk_time :int = 0
## 鼠标点击跳过的对话id
var mouse_skip_talk_id :int = -1
## 当前对话的id
var curr_talk_id :int = 0
## 是否为疯言疯语
var is_crazy := false
## 手上展示物品的容器节点，展示物品放置在该节点下
@export var hand_container: Node2D
## 当前手持物品id
var curr_hand_item_id:int = -1
## 所有手持物品道具
var all_hand_items:Array[Node2D]

## 选项节点
@onready var choose_node: Control = $ChooseNode
## 选项题目
@onready var choose_content: Label = $ChooseNode/Panel/MarginContainer/ChooseContent


@export_group("长时间存在戴夫参数（商店）")
## 开始长时间存在（戴夫开局讲完开场白之后）
var start_long_time_dave := false
## 开场白结束后第一次挂机闲话的间隔（原版 mAmbientSpeechCountDown = 200 tick ≈ 2 秒）
const IDLE_FIRST_INTERVAL := 2.0
## 挂机闲话的随机间隔区间（原版 RandRangeInt(500, 1000) tick = 5~10 秒）
const IDLE_MIN_INTERVAL := 5.0
const IDLE_MAX_INTERVAL := 10.0
## 鼠标移出商品后气泡的驻留时间（原版 SetBubbleText(..., 100) = 100 tick ≈ 1 秒）
const HOVER_LINGER_TIME := 1.0
## 长时间idle计时器，闲话间隔随机（5~10 秒），若有与玩家交互，交互结束重新启动计时器
@onready var timer_long_time_idle: Timer = $TimerLongTimeIdle
## 说话结束信号
signal talk_end_signal
## 开场白（click-to-continue 那几段）讲完的信号：商店用它解锁货架交互
signal signal_intro_dialog_end
## 是否正在念开场白（原版 mBubbleClickToContinue：期间货架不可点）
var is_in_intro_dialog := false
## 当前气泡正在念的那一句（挂机 / 悬停通用），同句悬停只刷新驻留不重念（原版比对 mCrazyDaveMessageIndex）
var curr_dialog_detail: CrazyDaveDialogDetailResource = null
## 上一次挂机闲话念的那句（原版：上次说过的权重归零，不连续重复）
var _last_idle_detail: CrazyDaveDialogDetailResource = null
## 外部对话（悬停 / 买后念白）收起协程的代次：每次新对话 / 收起都自增，旧协程作废
var _external_close_generation := 0
## 台词里的玩家名占位符（原版 CRAZY_DAVE_201 等台词带该占位符，见 data/strings/lawn_strings.txt）
const PLACEHOLDER_PLAYER_NAME := "{PLAYER_NAME}"
## 当前用户名取不到时的兜底称呼
const DEFAULT_PLAYER_NAME := "我的邻居"

## 戴夫离场信号，离场动画最后发射该信号
signal signal_dave_leave_end
## 当前外部触发对话的id
var curr_external_trigger_talk_id

## 同意选项信号
signal signal_agree_choose
## 不同意选项信号
signal signal_disagree_choose


## 开始对话（出场动画结束时动画调用）
func start_dialog():
	is_in_intro_dialog = true
	if dialog_resource:
		dave_dialog_mouse_press_panel.visible = true
		for i in range(dialog_resource.dialog_detail_list.size()):
			var dialog_detail:CrazyDaveDialogDetailResource = dialog_resource.dialog_detail_list[i]
			once_dialog(dialog_detail)
			## 等待鼠标点击一次
			await dave_dialog_mouse_press_panel.signal_dave_dialog_press
			mouse_skip_talk_id = curr_talk_id

		## 讲完话之后隐藏对话气泡
		bubble_2.visible = false
		dave_dialog_mouse_press_panel.visible = false

		if not dialog_resource.is_long_time_dave:
			is_activate = false
			bubble_2.visible = false
		else:
			is_idle = true
			## 开场白结束后停止检测
			set_process_unhandled_input(false)
			start_long_time_dave = true
			timer_long_time_idle.timeout.connect(long_time_idle_auto_dialog)
			## 启动长时间idle检测计时器（原版：开场白结束后 200 tick ≈ 2 秒出第一句闲话）
			restart_idle_timer(IDLE_FIRST_INTERVAL)

	else:
		is_activate = false
	## 开场白讲完（有没有台词都广播）：商店用它解锁货架交互（原版 CanInteractWithButtons）
	is_in_intro_dialog = false
	signal_intro_dialog_end.emit()


## 原版：click-to-continue 的气泡可以用空格 / 回车推进（StoreScreen::KeyDown 的 SPACE / RETURN）
func _unhandled_input(event: InputEvent) -> void:
	if not dave_dialog_mouse_press_panel.visible:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_SPACE \
			or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		dave_dialog_mouse_press_panel.signal_dave_dialog_press.emit()

#region 选项同意与否,button信号连接
func choose_agree():
	signal_agree_choose.emit()
	dave_dialog_mouse_press_panel.signal_dave_dialog_press.emit()
	choose_node.visible = false

func choose_disagree():
	signal_disagree_choose.emit()
	dave_dialog_mouse_press_panel.signal_dave_dialog_press.emit()
	choose_node.visible = false
#endregion


## 外部调用对话,如：描述商品，鼠标移动到商品上出现
func external_trigger_dialog(dialog_detail:CrazyDaveDialogDetailResource):
	## 如果此时开场白说完
	if start_long_time_dave:
		curr_external_trigger_talk_id = once_dialog(dialog_detail)

## 原版悬停口径（StoreScreen::UpdateMouse）：同一句重复悬停只刷新驻留时间，换句才重新念
func show_goods_dialog(dialog_detail: CrazyDaveDialogDetailResource) -> void:
	if not start_long_time_dave:
		return
	_external_close_generation += 1		## 取消还在等待的「收气泡」协程
	if curr_dialog_detail == dialog_detail and curr_external_trigger_talk_id == curr_talk_id:
		return
	curr_external_trigger_talk_id = once_dialog(dialog_detail)

## 鼠标移出商品：气泡按驻留时间再停一会儿才收（原版移出后 100 tick 才到点）
func schedule_goods_dialog_end() -> void:
	if curr_external_trigger_talk_id != curr_talk_id:
		return
	_external_close_generation += 1
	var generation := _external_close_generation
	await get_tree().create_timer(HOVER_LINGER_TIME).timeout
	if generation != _external_close_generation:
		return
	_close_external_dialog(generation)

## 外部调用对话结束
func external_trigger_dialog_end():
	if curr_external_trigger_talk_id != curr_talk_id:
		return
	_external_close_generation += 1
	_close_external_dialog(_external_close_generation)

## 收起外部触发的气泡并重排挂机计时
## 原版：气泡计时到点后如果戴夫的语音还在播就继续等（StoreScreen.cpp 734~743 的 IsFoleyPlaying）
func _close_external_dialog(generation: int) -> void:
	var player: AudioStreamPlayer = SoundManager.crazy_dave_player
	while player != null and player.playing:
		await get_tree().create_timer(0.1).timeout
		if generation != _external_close_generation:
			return
	if generation != _external_close_generation or curr_external_trigger_talk_id != curr_talk_id:
		return
	is_idle = true
	## 当前索引为0表示外部未调用动画
	curr_external_trigger_talk_id = 0
	## 讲完话之后隐藏对话气泡,重新开始计时器
	bubble_2.visible = false
	restart_idle_timer()

## 原版 CrazyDaveStopTalking：立刻收声、关气泡、回到 idle 并重排挂机计时
## （买商品 / 翻页关箱时调用，见 StoreScreen::PurchaseItem 与关箱分支）
func stop_talking() -> void:
	if not start_long_time_dave:
		return
	_external_close_generation += 1		## 作废等待中的收气泡协程
	SoundManager.crazy_dave_player.stop()
	curr_external_trigger_talk_id = 0
	is_idle = true
	bubble_2.visible = false
	restart_idle_timer()

## 弹窗期间冻结挂机计时（原版 mWaitForDialog 冻结整个 Update，闲话不会弹出来）
func pause_idle_timer() -> void:
	timer_long_time_idle.stop()

## 重排挂机计时；delay <= 0 时用随机区间（原版 500~1000 tick）
func restart_idle_timer(delay: float = -1.0) -> void:
	if not start_long_time_dave:
		return
	timer_long_time_idle.start(delay if delay > 0.0 else randf_range(IDLE_MIN_INTERVAL, IDLE_MAX_INTERVAL))


## 长时间idle自动说句屁话
func long_time_idle_auto_dialog():
	## idle状态，外部未触发对话，长时间挂机状态
	if is_idle and curr_external_trigger_talk_id == 0 and start_long_time_dave:
		var dialog_detail := _pick_idle_detail()
		if dialog_detail == null:
			restart_idle_timer()
			return
		var talk_id = once_dialog(dialog_detail)
		## 等待开始idle动画
		await talk_end_signal
		## 如果当前交谈id和本次说话动画id一致，有可能被别的动画打断
		if talk_id == curr_talk_id and curr_external_trigger_talk_id == 0:
			## 气泡要等戴夫的语音播完才收（原版 StoreScreen.cpp 734~743 的 IsFoleyPlaying）
			await _wait_dave_voice_end()
			if talk_id != curr_talk_id or curr_external_trigger_talk_id != 0:
				return
			## 说话完成 开始idle
			## 讲完话之后隐藏对话气泡,重新开始计时器
			bubble_2.visible = false
			restart_idle_timer()


## 挑一句挂机闲话（原版 StoreScreen.cpp 751~770 的加权随机）：
##   · 上一次说过的权重归零 —— 不连续重复同一句
##   · need_adventure_finished 的句子（2018「我吃掉在地上的东西」）通关冒险后才会出现
func _pick_idle_detail() -> CrazyDaveDialogDetailResource:
	var pool: Array = []
	for detail in dialog_resource.dialog_detail_long_time_idle_list:
		if detail.need_adventure_finished and not _is_adventure_finished():
			continue
		pool.append(detail)
	if pool.is_empty():
		return null
	if pool.size() > 1:
		pool.erase(_last_idle_detail)
	var picked: CrazyDaveDialogDetailResource = pool.pick_random()
	_last_idle_detail = picked
	return picked


## 冒险模式是否已通关（原版 HasFinishedAdventure，口径同 Goods.is_adventure_finished）
func _is_adventure_finished() -> bool:
	return Global.global_game_state.get_max_success_adventure_level() \
		>= ConstUnlockLevel.ADVENTURE_FINAL_ADVENTURE_LEVEL


## 等戴夫的语音播完（气泡不许先于语音消失）
func _wait_dave_voice_end() -> void:
	var player: AudioStreamPlayer = SoundManager.crazy_dave_player
	while player != null and player.playing:
		await get_tree().create_timer(0.1).timeout



## 说完当前这段话，动画调用
func _talk_end():
	is_idle = true
	talk_end_signal.emit()

## 手持物品时说完当前这段话，动画调用
func _talk_end_is_hand():
	is_idle = true
	talk_time -= 1
	if talk_time <= 0:
		talk_end_signal.emit()

## 播放指定主题的对话气泡内容
## 功能说明：
## - 如果对话气泡当前不可见，则将其设为可见；
func once_dialog(dialog_detail:CrazyDaveDialogDetailResource) -> int:
	curr_talk_id += 1
	curr_dialog_detail = dialog_detail
	if not bubble_2.visible:
		bubble_2.visible = true

	speech_text_label.text = _resolve_text_placeholder(dialog_detail.text)
	_speech_anim_from_dialog_detail(dialog_detail)
	## 这一句配了触发事件：念到这句的同时推给订阅方（原版 1-5：说到保龄球时红线出现）
	if not dialog_detail.on_talk_event.is_empty():
		EventBus.push_event(dialog_detail.on_talk_event)

	## 如果这句话之前有手持物品,先隐藏
	if curr_hand_item_id != -1:
		all_hand_items[curr_hand_item_id].visible = false
	## 如果有手持物品 并且 编号合法
	if is_hand and dialog_detail.hand_item_id >= 0 and dialog_detail.hand_item_id < all_hand_items.size():
		curr_hand_item_id = dialog_detail.hand_item_id
		all_hand_items[curr_hand_item_id].visible = true
	else:
		curr_hand_item_id = -1

	if dialog_detail.is_choosed:
		choose_node.visible = true

	return curr_talk_id

## 展开台词里的占位符：{PLAYER_NAME} 替换为当前用户名
## 用户名取不到（未选择 / 未创建用户）时用兜底称呼，避免把占位符原样念出来
func _resolve_text_placeholder(text: String) -> String:
	if not text.contains(PLACEHOLDER_PLAYER_NAME):
		return text
	var player_name: String = "" if Global.user_manager == null else Global.user_manager.curr_user_name
	if player_name.is_empty():
		player_name = DEFAULT_PLAYER_NAME
	return text.replace(PLACEHOLDER_PLAYER_NAME, player_name)


## 根据说话的文本，计算使用什么动画
## 如果不是crazy
## 根据文本长度，选择动画
## 小于8个字(汉字，字符，不考虑英文)smalltalk动画
## 小于16个字 mediumtalk
## 其余 blahblah
func _speech_anim_from_dialog_detail(dialog_detail:CrazyDaveDialogDetailResource):
	is_idle = false
	is_crazy = dialog_detail.is_crazy
	is_hand = dialog_detail.is_hand
	if is_crazy:
		SoundManager.play_crazy_dave_SFX("crazydavescream")
		talk_time = 0
	else:
		var text = dialog_detail.text
		if text.length() < 8:
			SoundManager.play_crazy_dave_SFX("crazydaveshort")
			talk_time = 1
		elif text.length() < 16:
			SoundManager.play_crazy_dave_SFX("crazydavelong")
			talk_time = 2
		else:
			SoundManager.play_crazy_dave_SFX("crazydaveextralong")
			talk_time = 3

## 初始化戴夫相关参数
## @param dialog_resource (CrazyDaveDialogResource) - 本次对话的戴夫资源文件。
## @param hand_node (Node) - 代码初始化戴夫时的手持物品，在该函数中添加到戴夫手中
func init_dave(curr_dialog_resource:CrazyDaveDialogResource, hand_node:Node = null) -> void:
	dialog_resource = curr_dialog_resource
	if hand_node:
		hand_container.add_child(hand_node)

	## 从场景中创建所有的手持物品
	for hand_itme_scene:PackedScene in curr_dialog_resource.all_hand_itmes_scene:
		var new_hand_item:Node2D = hand_itme_scene.instantiate()
		new_hand_item.visible = false
		hand_container.add_child(new_hand_item)
		all_hand_items.append(new_hand_item)

	## 第一句话是否手持物品
	is_hand = dialog_resource.dialog_detail_list[0].is_hand
	if is_hand and dialog_resource.dialog_detail_list[0].hand_item_id >= 0 and dialog_resource.dialog_detail_list[0].hand_item_id < all_hand_items.size():
		curr_hand_item_id = dialog_resource.dialog_detail_list[0].hand_item_id
		all_hand_items[curr_hand_item_id].visible = true

	is_enter_up = dialog_resource.is_enter_up
	is_grab = dialog_resource.is_grab


func reset_dave(new_dialog_resource:CrazyDaveDialogResource, hand_node:Node = null) -> void:
	## 重新播放动画
	animation_tree.set("parameters/playback", null)  # 断开当前播放
	animation_tree.active = false  # 停止播放
	animation_tree.active = true   # 重启播放

	## 是否为激活状态，false戴夫退出
	is_activate = true
	## 戴夫是否为idle状态，idle状态下，动画循环播放，需要等待用户点击
	is_idle= true
	## 说话时间长短，1,2,3，控制动画播放
	talk_time = 0
	## 鼠标点击跳过的对话id
	mouse_skip_talk_id = -1
	## 当前对话的id
	curr_talk_id = 0
	## 是否为疯言疯语
	is_crazy = false
	## 开始长时间存在（戴夫开局讲完开场白之后）
	start_long_time_dave = false
	init_dave(new_dialog_resource, hand_node)

## 戴夫离场
func dave_leave_end():
	signal_dave_leave_end.emit()
