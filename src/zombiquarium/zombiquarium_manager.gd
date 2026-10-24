extends Node2D
class_name ZombiquariumManager
## 僵尸水族馆（Zombiquarium，原版迷你游戏第 8 关）玩法总控
##
## 原版本关没有草坪、没有植物、没有出怪：整关就是一口鱼缸 + 几只潜水僵尸（见 ConstZombiquarium）。
## 玩法闭环（口径全部来自原版源码 `../PvZ-Portable-main/src/Lawn/Challenge.cpp`）：
##   点鱼缸花 5 阳光造一个脑子（Challenge.cpp:3375）-> 脑子下沉，僵尸游过来吃掉（Zombie.cpp:3103）
##   -> 僵尸定时吐 25 阳光（Zombie.cpp:3246）-> 阳光够 100 买僵尸、够 1000 买奖杯（Plant.cpp:5004/5005）
##   -> 买下奖杯通关；僵尸不喂会掉血掉到 0 就死，全死光判负（Challenge.cpp:3383）。
##
## **买东西的入口**：出战卡槽里的两张自定义种子包 —— 100 阳光买潜水僵尸、1000 阳光买奖杯，
## 由关卡脚本用通用口子 `create_custom_seed_packet()` 放上去（见 minigame_08_zombie_aquarium）；
## 本节点自己只提供买东西的方法（`try_buy_pet()` / `try_buy_trophy()`），不认识「卡片」。
##
## 落位说明：本节点挂在主游戏场景（MainGameManager）下、覆盖整屏（z_index 4000，压住草坪但压不住
## 产出阳光的 Suns 层 4002），位置对齐相机左上角（camera_2d.position 就是可见区左上角的世界坐标，
## 见 main_game_camera.gd 的口径）。**本节点的局部坐标 = 原版的棋盘坐标**（800x600），
## 所以原版那些绝对坐标（点击范围 80~720 / 90~430、游动范围 0~680 / 100~400…）可以原样用。
## 文案这一类 UI 挂在本节点下的 CanvasLayer 里，走屏幕坐标。
##
## 阳光仍然走主游戏那一份（CardSlotBattle.sun_value）：点了阳光自动进账，本关只负责花
## （造脑子 / 买僵尸 / 买奖杯），这样已有的收阳光表现、存档与结算都不用另起一套。
##
## **独立预览**：`init_zombiquarium(null)` 时不挂主游戏（见入口场景 `src/zombiquarium/zombiquarium.tscn`），
## 此时没有出战卡槽、没有 Suns 层、没有相机，于是：
##   - 阳光改用本节点自带的一份 `_local_sun`，产出的阳光直接进账（没有「点了才算收到」那一步）；
##   - 位置停在原点（整屏左上角就是鱼缸左上角），不再按相机对齐；
##   - 判负不走存档 / 红字演出，只给结论。
## 玩法数值与规则两种模式完全一致，差别只在「阳光打哪儿记」「结算交给谁」。

## 本关结束（true = 买下奖杯通关，false = 宠物僵尸全死光判负）
signal signal_finished(is_win: bool)
## 阳光变了（入口场景的 HUD / 调试通道显示用；直接改出战卡槽的数值不会触发，够用即可）
signal signal_sun_value_changed(sun: int)

## 原版的教学步骤（Challenge.cpp:3400-3427 的 mTutorialState）
enum E_TutorialState {
	Off,			## 原版 TUTORIAL_OFF
	BuySnorkel,		## 原版 TUTORIAL_ZOMBIQUARIUM_BUY_SNORKEL：教玩家买潜水僵尸
	BoughtSnorkel,	## 原版 TUTORIAL_ZOMBIQUARIUM_BOUGHT_SNORKEL
	ClickTrophy,	## 原版 TUTORIAL_ZOMBIQUARIUM_CLICK_TROPHY：教玩家点奖杯
}

@onready var pets_root: Node2D = $Pets
@onready var brains_root: Node2D = $Brains
@onready var advice_label: Label = $UI/Hud/AdviceLabel
## 购买按钮：**只给独立预览用** —— 那时没有卡槽，这一排按钮是唯一的买东西入口；
## 挂在主游戏下时被 `_setup_ui()` 藏掉，玩家改在出战卡槽里买（那两张自定义种子包，
## 见 `minigame_08_zombie_aquarium._create_seed_packets`）
@onready var button_buy_pet: Button = $UI/Hud/ButtonBuyPet
@onready var button_buy_trophy: Button = $UI/Hud/ButtonBuyTrophy

var _mg: MainGameManager
var _card_slot_battle: CardSlotBattle
## 独立预览时的阳光（没有出战卡槽可记账，就记在自己身上）
var _local_sun := 0
## 玩法是否还在进行中（没通关也没判负）：关卡进度条数据源靠它决定「本关有进度可算吗」
var is_running := false
var _pets: Array[ZombiquariumPet] = []
var _brains: Array[ZombiquariumBrain] = []
var _is_finished := false
## 奖杯已经掉下来（原版 `HasLevelAwardDropped()`）
var _is_award_dropped := false
## 原版 mHelpDisplayed：「攒够阳光」那条提示只出一次
var _is_collect_sun_advised := false
## 原版 mTutorialState
var _tutorial_state: E_TutorialState = E_TutorialState.Off
## 当前提示文案（原版同一时刻只显示一条 advice）
var _advice_text := ""


#region 初始化
## 初始化本关玩法（由关卡流程在 add_child 之后调用）
## main_game 为 null = 独立预览（没有主游戏，见本文件头部的「独立预览」小节）
func init_zombiquarium(main_game: MainGameManager) -> void:
	_mg = main_game
	if _mg == null:
		## 独立预览：没有出战卡槽与相机，阳光自备、位置就停在原点
		_local_sun = ConstZombiquarium.SUN_START
	else:
		_card_slot_battle = _mg.card_manager.card_slot_battle
		if _card_slot_battle == null:
			Log.error("僵尸水族馆：取不到出战卡槽，阳光经济不可用")
		## 对齐相机左上角：camera_2d.position 就是可见区左上角的世界坐标
		position = _mg.camera_2d.position
		_hide_lawn_ui()
	is_running = true
	_setup_ui()
	## 原版 Challenge.cpp:311-312：开局送两只潜水僵尸
	for _i in range(ConstZombiquarium.PET_NUM_START):
		_create_pet(_random_pet_pos())
	_refresh_hud()
	_emit_sun_changed()


## 藏掉草坪那一套 UI：本关没有选卡、没有铲子、没有待选区，出战卡槽上只留下两样东西
## —— 阳光计数（本关的阳光就走主游戏那一份）和它的两个卡位
## （那两个卡位放着「买潜水僵尸 / 买奖杯」两张自定义种子包，是本关唯一的操作入口，不能藏）
func _hide_lawn_ui() -> void:
	## 卡槽容器里，除了出战卡槽（阳光条 + 两张种子包）之外全是铲子 / 手套，逐个藏掉
	for child in _mg.card_manager.card_slot_container.get_children():
		if child != _card_slot_battle:
			child.visible = false
	var card_slot_norm := _mg.card_manager.card_slot_norm
	if card_slot_norm != null:
		card_slot_norm.card_slot_candidate.visible = false
	## 前景层（草坪前景装饰）在 CanvasLayer 上，会盖在水族馆之上，一并藏掉
	var frontground := _mg.get_node_or_null("%Frontground")
	if frontground != null:
		frontground.visible = false


func _setup_ui() -> void:
	## 主游戏里买东西全部走出战卡槽里那两张自定义种子包，这一排按钮只服务独立预览
	button_buy_pet.visible = _mg == null
	button_buy_trophy.visible = _mg == null
	button_buy_pet.text = "购买潜水僵尸（%d）" % ConstZombiquarium.PET_SUN_COST
	button_buy_trophy.text = "购买奖杯（%d）" % ConstZombiquarium.TROPHY_SUN_COST
	button_buy_pet.pressed.connect(_on_buy_pet_pressed)
	button_buy_trophy.pressed.connect(_on_buy_trophy_pressed)
	## 按钮音效走主游戏那一套（SoundManager.setup_ui_main_game_sound 会递归挂上）
	SoundManager.setup_ui_main_game_sound($UI/Hud)
#endregion


#region 输入：点鱼缸造脑子
func _unhandled_input(event: InputEvent) -> void:
	if _is_finished:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local_pos := get_local_mouse_position()
	## 原版 Challenge.cpp:3362：点在这块矩形里才造脑子
	if not ConstZombiquarium.CLICK_AREA.has_point(local_pos):
		return
	create_brain(local_pos)
	get_viewport().set_input_as_handled()


## 造一个脑子：花一份阳光，脑子从落点往下沉（沉到缸底还没被吃就白花）
## [param local_pos] 点击位置（鱼缸局部坐标 = 原版棋盘坐标）
func create_brain(local_pos: Vector2) -> void:
	## 原版 Challenge.cpp:3375：缸里最多 3 个脑子，且要先扣得起 5 阳光
	if _brains.size() >= ConstZombiquarium.BRAIN_MAX_NUM:
		SoundManager.play_other_SFX("buzzer")
		return
	if not spend_sun(ConstZombiquarium.BRAIN_SUN_COST):
		SoundManager.play_other_SFX("buzzer")
		return
	var brain: ZombiquariumBrain = SceneRegistry.ZOMBIQUARIUM_BRAIN.instantiate()
	brains_root.add_child(brain)
	## 原版 Challenge.cpp:3355-3356：脑子的落点 = 点击点 - (15,15)
	brain.position = local_pos - ConstZombiquarium.BRAIN_OFFSET
	## 原版脑子画在宠物之上（Challenge.cpp:3351 `mRenderOrder = 400000`）
	brain.z_index = 1
	brain.signal_brain_gone.connect(_on_brain_gone)
	_brains.append(brain)
	## 原版 Challenge.cpp:3348：投了脑子就别再提示「点击鱼缸给僵尸喂食」
	if _advice_text == ConstZombiquarium.ADVICE_CLICK_TO_FEED:
		_set_advice("")
	## 原版 Challenge.cpp:3357 投脑子是 tap 音
	SoundManager.play_other_SFX("tap")
#endregion


#region 经济：一律走主游戏出战卡槽的阳光
func get_sun_value() -> int:
	if _card_slot_battle == null:
		## 独立预览：走出战卡槽那份的替代品
		return _local_sun
	return _card_slot_battle.sun_value


## 花阳光：不够就返回 false（调用方自己决定要不要播「买不起」的音效）
func spend_sun(value: int) -> bool:
	if get_sun_value() < value:
		return false
	if _card_slot_battle == null:
		_local_sun -= value
	else:
		_card_slot_battle.sun_value -= value
	_emit_sun_changed()
	return true


## 通知阳光变化（入口场景 HUD / 调试通道用）
func _emit_sun_changed() -> void:
	signal_sun_value_changed.emit(get_sun_value())
#endregion


#region 僵尸与脑子
func _create_pet(local_pos: Vector2) -> ZombiquariumPet:
	var pet: ZombiquariumPet = SceneRegistry.ZOMBIQUARIUM_PET.instantiate()
	pets_root.add_child(pet)
	pet.position = local_pos
	## 先入场景树再初始化：僵尸是本节点的子节点，@onready 的那些引用要等入树才拿得到
	## 找脑子由宠物自己去板子上找（原版就是这么干的），这里只把「脑子列表怎么取」告诉它
	pet.init_pet(get_brains)
	pet.signal_produce_sun.connect(_on_pet_produce_sun)
	pet.signal_pet_death.connect(_on_pet_death)
	_pets.append(pet)
	return pet


## 僵尸产阳光：与 CreateSunComponent 同一套「弹起来再落下」的表现
func _on_pet_produce_sun(_pet: ZombiquariumPet, sun_global_pos: Vector2) -> void:
	if _mg == null:
		## 独立预览：没有 Suns 层，产出即入账（省掉「点了才算收到」那一步）
		_local_sun += ConstZombiquarium.PET_SUN_VALUE
		_emit_sun_changed()
		return
	if not is_instance_valid(_mg):
		return
	## 与 CreateSunComponent 同一套「弹起来再落下」（见 `SunSpawner.pop_up`）
	SunSpawner.pop_up(_mg.suns, _mg.suns.to_local(sun_global_pos), ConstZombiquarium.PET_SUN_VALUE)


## 僵尸死透了：全部死光就判负（原版 Challenge.cpp:3383 `mZombies.mSize == 0`）
func _on_pet_death(pet: ZombiquariumPet) -> void:
	_pets.erase(pet)
	if _is_finished or not _pets.is_empty():
		return
	await _lose_game()


## 脑子没了（沉到缸底 / 被吃掉）
func _on_brain_gone(brain: ZombiquariumBrain) -> void:
	_brains.erase(brain)
#endregion


#region 每帧
func _process(_delta: float) -> void:
	if _is_finished:
		return
	_update_advice()
	_refresh_hud()


## 提示与教学：原版 Challenge.cpp:3381-3427（ZombiquariumUpdate）
func _update_advice() -> void:
	## 原版 Challenge.cpp:3394：进度口径 = 阳光，封顶 1000
	var score := clampi(get_sun_value(), 0, ConstZombiquarium.WINNING_SCORE)
	## ① 原版 Challenge.cpp:3388-3392：一条提示都没显示过 → 先教玩家攒阳光
	if _advice_text.is_empty() and not _is_collect_sun_advised:
		_is_collect_sun_advised = true
		_set_advice(ConstZombiquarium.ADVICE_COLLECT_SUN % ConstZombiquarium.WINNING_SCORE)
	## ② 原版 Challenge.cpp:3396-3399：离通关差 100 点以内 → 「就要成功了！」
	if score >= ConstZombiquarium.WINNING_SCORE - 100:
		_set_advice(ConstZombiquarium.ADVICE_ALMOST_THERE)
	## ③ 原版 Challenge.cpp:3400-3413：阳光够多就教玩家买潜水僵尸；掉回 100 以下就取消这一步
	if score >= ConstZombiquarium.ADVICE_BUY_SNORKEL_SCORE \
			and _tutorial_state == E_TutorialState.Off:
		_tutorial_state = E_TutorialState.BuySnorkel
		_set_advice(ConstZombiquarium.ADVICE_BUY_SNORKEL)
	elif score < ConstZombiquarium.ADVICE_BUY_SNORKEL_SCORE - 10 \
			and _tutorial_state == E_TutorialState.BuySnorkel:
		_tutorial_state = E_TutorialState.Off
		_set_advice("")
	## ④ 原版 Challenge.cpp:3414-3427：阳光满了就教玩家点奖杯；阳光不够就退回上一步
	if score >= ConstZombiquarium.WINNING_SCORE \
			and _tutorial_state == E_TutorialState.BoughtSnorkel:
		_tutorial_state = E_TutorialState.ClickTrophy
		_set_advice(ConstZombiquarium.ADVICE_CLICK_TROPHY)
	elif score < ConstZombiquarium.WINNING_SCORE \
			and _tutorial_state == E_TutorialState.ClickTrophy:
		_tutorial_state = E_TutorialState.BoughtSnorkel


## 刷新按钮可用状态
func _refresh_hud() -> void:
	var sun := get_sun_value()
	button_buy_pet.disabled = _is_finished or sun < ConstZombiquarium.PET_SUN_COST
	button_buy_trophy.disabled = _is_finished or sun < ConstZombiquarium.TROPHY_SUN_COST


## 写提示文案（原版同一时刻只显示一条 advice，后写的覆盖先写的）
func _set_advice(text: String) -> void:
	_advice_text = text
	advice_label.text = text
#endregion


#region 买东西
## 买一只潜水僵尸 —— **买东西的唯一入口**
##
## 调用方有两个：出战卡槽里的「购买潜水僵尸」种子包（主游戏，见
## `minigame_08_zombie_aquarium._create_seed_packets`）和右下角那个按钮（独立预览）。
## 阳光不够 / 本关已经结束时返回 false，由调用方决定要不要播「买不起」的音效。
func try_buy_pet() -> bool:
	if _is_finished:
		return false
	## 原版 Challenge.cpp:3322：场上僵尸超过 100 只就不给买了
	if _pets.size() > ConstZombiquarium.PET_MAX_NUM:
		return false
	if not spend_sun(ConstZombiquarium.PET_SUN_COST):
		return false
	_create_pet(_random_pet_pos())
	## 原版 Challenge.cpp:3325-3330：正在教「买潜水僵尸」这一步 → 这一步教完了
	if _tutorial_state == E_TutorialState.BuySnorkel:
		_tutorial_state = E_TutorialState.BoughtSnorkel
	## 原版 Challenge.cpp:3333-3334：入水声 + 水花
	SoundManager.play_other_SFX("zombiesplash")
	return true


## 买奖杯：这是本关的通关方式（原版：攒够 1000 阳光点奖杯过关）
## [param trophy_screen_pos] 奖杯抛出来的位置，**屏幕坐标**（见规范 S-03：
## canvas_layer_temp 那一层走屏幕坐标，UI 的屏幕坐标要用 `get_global_transform_with_canvas()` 取）
func try_buy_trophy(trophy_screen_pos: Vector2) -> bool:
	if _is_finished:
		return false
	if not spend_sun(ConstZombiquarium.TROPHY_SUN_COST):
		return false
	## 原版 Challenge.cpp:3338：奖杯掉下来（SpawnLevelAward）—— 原版这时宠物就不再找脑子、
	## 不吐阳光、也不掉血了
	_is_award_dropped = true
	for pet in _pets:
		pet.is_award_dropped = true
	Log.info("僵尸水族馆：买下奖杯，通关")
	_finish(true)
	EventBus.push_event(ConstEventName.CREATE_TROPHY, [trophy_screen_pos])
	return true


## 按钮回调（只给独立预览用）：本体逻辑在 `try_buy_pet()`，这里只补「买不起」的音效
func _on_buy_pet_pressed() -> void:
	if not try_buy_pet():
		SoundManager.play_other_SFX("buzzer")


func _on_buy_trophy_pressed() -> void:
	if not try_buy_trophy(button_buy_trophy.get_global_transform_with_canvas().origin):
		SoundManager.play_other_SFX("buzzer")
#endregion


#region 结束
func _finish(is_win: bool) -> void:
	if _is_finished:
		return
	_is_finished = true
	is_running = false
	set_process(false)
	button_buy_pet.disabled = true
	button_buy_trophy.disabled = true
	signal_finished.emit(is_win)


## 宠物僵尸全死光：走与「僵尸进家」同一套失败流程（重开存档 + 失败音乐 + 红字）
## 原版本关的失败提示是 lawn_strings 的 [ZOMBIQUARIUM_DEATH_MESSAGE]
## 「你的宠物僵尸已经全部死亡了！」（原版 Challenge.cpp:3385 判负）
func _lose_game() -> void:
	Log.info("僵尸水族馆：宠物僵尸全部死亡，判负")
	_set_advice(ConstZombiquarium.ADVICE_DEATH)
	if _mg == null:
		## 独立预览：没有存档与失败演出，只给出结论
		SoundManager.play_other_SFX("losemusic")
		_finish(false)
		return
	_mg.save_manager.re_main_game()
	_mg.main_game_progress = MainGameManager.E_MainGameProgress.GAME_OVER
	_mg.card_slot_root.visible = false
	TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.GameOver)
	SoundManager.play_other_SFX("losemusic")
	await get_tree().create_timer(3).timeout
	SoundManager.play_other_SFX("scream")
	_mg.ui_remind_word.zombie_won_word_appear()
	_finish(false)
#endregion


#region 工具
## 当前活着的宠物僵尸（探针 / 调试通道用）
func get_pets() -> Array[ZombiquariumPet]:
	return _pets


## 当前水缸里的脑子（探针 / 调试通道用；宠物每 tick 自己来这里找最近的脑子）
## 返回副本：宠物遍历时可能正好吃掉其中一个（会把这一个从列表里摘掉），副本不受影响
func get_brains() -> Array[ZombiquariumBrain]:
	return _brains.duplicate()


## 宠物生成位置：原版 Challenge.cpp:3310-3311
func _random_pet_pos() -> Vector2:
	return Vector2(
		randf_range(ConstZombiquarium.PET_SPAWN_X.x, ConstZombiquarium.PET_SPAWN_X.y),
		randf_range(ConstZombiquarium.PET_SPAWN_Y.x, ConstZombiquarium.PET_SPAWN_Y.y)
	)
#endregion
