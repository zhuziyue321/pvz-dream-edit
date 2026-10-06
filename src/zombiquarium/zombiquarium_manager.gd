extends Node2D
class_name ZombiquariumManager
## 僵尸水族馆（Zombiquarium，迷你游戏第 8 关）玩法总控
##
## 原版本关没有草坪、没有植物、没有出怪：整个关卡就是一口鱼缸 + 几只潜水僵尸（见 ConstZombiquarium）。
## 玩法闭环：
##   点鱼缸花 5 阳光造一个脑子 -> 脑子下沉，僵尸游过来吃掉 -> 僵尸定时产 25 阳光（点了才算收到）
##   -> 阳光够 100 买僵尸、够 1000 买奖杯 -> 买下奖杯通关；僵尸 20 秒没吃到脑子就饿死，全死光判负。
##
## **买东西的入口**：出战卡槽里的两张自定义种子包 —— 100 阳光买潜水僵尸、1000 阳光买奖杯，
## 由关卡脚本用通用口子 `create_custom_seed_packet()` 放上去（见 minigame_08_zombie_aquarium）；
## 本节点自己只提供买东西的方法（`try_buy_pet()` / `try_buy_trophy()`），不认识「卡片」。
##
## 落位说明：本节点挂在主游戏场景（MainGameManager）下、覆盖整屏（z_index 4000，压住草坪但压不住
## 产出阳光的 Suns 层 4002），位置对齐相机左上角（camera_2d.position 就是可见区左上角的世界坐标，
## 见 main_game_camera.gd 的口径）。文案这一类 UI 挂在本节点下的 CanvasLayer 里，走屏幕坐标。
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

## 点鱼缸造脑子的范围（相对本节点的水域矩形）：点在水域里才造脑子
@export var water_rect := Rect2(110.0, 115.0, 640.0, 435.0)
## 僵尸游动范围（相对本节点）：比水域小一圈，免得僵尸贴着缸壁
@export var swim_rect := Rect2(150.0, 150.0, 550.0, 330.0)
## 脑子沉到这个 y（相对本节点）就算到缸底，白花一份阳光
@export var brain_bottom_y := 545.0

## 本关结束（true = 买下奖杯通关，false = 宠物僵尸全死光判负）
signal signal_finished(is_win: bool)
## 阳光变了（入口场景的 HUD / 调试通道显示用；直接改出战卡槽的数值不会触发，够用即可）
signal signal_sun_value_changed(sun: int)

## 文案取自原版 lawn_strings.txt（见 ConstZombiquarium 头部的来源注释）
const ADVICE_CLICK_TO_FEED := "点击鱼缸给僵尸喂食"
const ADVICE_BUY_SNORKEL := "点击购买更多的潜水僵尸！"
const ADVICE_CLICK_TROPHY := "点击奖杯来完成关卡！"
const ADVICE_DEATH := "你的宠物僵尸已经全部死亡了！"

## 「可以买更多僵尸了」这句只提示一次，停留秒数
const ADVICE_BUY_SNORKEL_TIME := 4.0

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
## 玩家是否已经造过脑子（造过之后就不用再提示「点击鱼缸」了）
var _is_brain_created := false
## 「可以买更多僵尸了」是否已经提示过（只提示一次）
var _is_buy_snorkel_adviced := false
var _advice_timer := 0.0


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
	for _i in range(ConstZombiquarium.PET_NUM_START):
		_create_pet(_random_point_in_rect(swim_rect))
	_refresh_hud()
	_emit_sun_changed()
	Log.debug("僵尸水族馆：开局 %d 阳光、%d 只潜水僵尸，攒够 %d 阳光买奖杯通关" % [
		get_sun_value(), _pets.size(), ConstZombiquarium.TROPHY_SUN_COST
	])


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
	if not water_rect.has_point(local_pos):
		return
	create_brain(local_pos)
	get_viewport().set_input_as_handled()


## 造一个脑子：花一份阳光，脑子从落点往下沉（沉到缸底还没被吃就白花）
func create_brain(local_pos: Vector2) -> void:
	if _brains.size() >= ConstZombiquarium.BRAIN_MAX_NUM:
		Log.debug("僵尸水族馆：水缸里已经有 %d 个脑子了" % ConstZombiquarium.BRAIN_MAX_NUM)
		SoundManager.play_other_SFX("buzzer")
		return
	if not spend_sun(ConstZombiquarium.BRAIN_SUN_COST):
		SoundManager.play_other_SFX("buzzer")
		return
	var brain: ZombiquariumBrain = SceneRegistry.ZOMBIQUARIUM_BRAIN.instantiate()
	brain.bottom_y = brain_bottom_y
	brains_root.add_child(brain)
	brain.position = _clamp_point_in_rect(water_rect, local_pos)
	brain.signal_brain_gone.connect(_on_brain_gone)
	_brains.append(brain)
	_is_brain_created = true
	SoundManager.play_other_SFX("plant_water")
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
	pet.position = _clamp_point_in_rect(swim_rect, local_pos)
	## 先入场景树再初始化：僵尸是本节点的子节点，@onready 的那些引用要等入树才拿得到
	pet.init_pet(swim_rect)
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
	var sun: Sun = SceneRegistry.SUN.instantiate()
	sun.init_sun(ConstZombiquarium.PET_SUN_VALUE, _mg.suns.to_local(sun_global_pos))
	_mg.suns.add_child(sun)
	var tween := sun.create_tween()
	tween.tween_property(sun, "position:y", -15.0, 0.3).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sun, "position:y", 45.0, 0.6).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sun.spawn_sun_tween = get_tree().create_tween()
	sun.spawn_sun_tween.set_parallel()
	sun.spawn_sun_tween.tween_subtween(tween)
	sun.spawn_sun_tween.tween_property(sun, "position:x", randf_range(-30.0, 30.0), 0.9).as_relative()
	sun.spawn_sun_tween.finished.connect(sun.on_sun_tween_finished)


## 僵尸死透了：全部死光就判负
func _on_pet_death(pet: ZombiquariumPet) -> void:
	_pets.erase(pet)
	if _is_finished or not _pets.is_empty():
		return
	await _lose_game()


## 脑子没了（沉到缸底 / 被吃掉）
func _on_brain_gone(brain: ZombiquariumBrain) -> void:
	_brains.erase(brain)
	for pet in _pets:
		pet.clear_target_brain(brain)
#endregion


#region 每帧
func _process(delta: float) -> void:
	if _is_finished:
		return
	_assign_brains()
	_consume_eaten_brain()
	if _advice_timer > 0.0:
		_advice_timer -= delta
		if _advice_timer <= 0.0:
			_advice_timer = 0.0
	_refresh_hud()


## 每帧给每只僵尸派一个最近的脑子（原版：脑子沉在哪，僵尸就往哪游）
func _assign_brains() -> void:
	for pet in _pets:
		if pet.state != ZombiquariumPet.E_PetState.Swim and pet.state != ZombiquariumPet.E_PetState.Chase:
			continue
		var nearest: ZombiquariumBrain = null
		var nearest_distance := INF
		for brain in _brains:
			var distance := pet.position.distance_to(brain.position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = brain
		if nearest != null:
			pet.set_target_brain(nearest)


## 僵尸咬住脑子的那一刻就把脑子吃掉（别的僵尸盯着的同一个脑子要同时失效）
func _consume_eaten_brain() -> void:
	for pet in _pets:
		if pet.state != ZombiquariumPet.E_PetState.Eat:
			continue
		var brain := pet.get_eating_brain()
		if is_instance_valid(brain) and not brain.is_eaten:
			brain.be_eaten()


## 刷新按钮可用状态与提示文案
func _refresh_hud() -> void:
	var sun := get_sun_value()
	button_buy_pet.disabled = _is_finished or sun < ConstZombiquarium.PET_SUN_COST
	button_buy_trophy.disabled = _is_finished or sun < ConstZombiquarium.TROPHY_SUN_COST
	if _is_finished:
		return
	if sun >= ConstZombiquarium.TROPHY_SUN_COST:
		_set_advice(ADVICE_CLICK_TROPHY, 0.0)
		return
	if _advice_timer > 0.0:
		return
	if not _is_brain_created:
		_set_advice(ADVICE_CLICK_TO_FEED, 0.0)
		return
	if not _is_buy_snorkel_adviced and sun >= ConstZombiquarium.PET_SUN_COST:
		_is_buy_snorkel_adviced = true
		_set_advice(ADVICE_BUY_SNORKEL, ADVICE_BUY_SNORKEL_TIME)
		return
	_set_advice("", 0.0)


## 写提示文案；stay_time > 0 表示停留这么多秒后自动清空
func _set_advice(text: String, stay_time: float) -> void:
	if advice_label.text == text:
		return
	advice_label.text = text
	_advice_timer = stay_time
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
	if not spend_sun(ConstZombiquarium.PET_SUN_COST):
		return false
	_create_pet(_random_point_in_rect(swim_rect))
	SoundManager.play_other_SFX("points")
	Log.debug("僵尸水族馆：买了一只潜水僵尸，当前 %d 只" % _pets.size())
	return true


## 买奖杯：这是本关的通关方式（原版：攒够 1000 阳光点奖杯过关）
## [param trophy_screen_pos] 奖杯抛出来的位置，**屏幕坐标**（见规范 S-03：
## canvas_layer_temp 那一层走屏幕坐标，UI 的屏幕坐标要用 `get_global_transform_with_canvas()` 取）
func try_buy_trophy(trophy_screen_pos: Vector2) -> bool:
	if _is_finished:
		return false
	if not spend_sun(ConstZombiquarium.TROPHY_SUN_COST):
		return false
	Log.debug("僵尸水族馆：买下奖杯，通关")
	_finish(true)
	EventBus.push_event("create_trophy", [trophy_screen_pos])
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
## 原版本关的失败提示是 lawn_strings 的 [ZOMBIQUARIUM_DEATH_MESSAGE]「你的宠物僵尸已经全部死亡了！」
func _lose_game() -> void:
	Log.debug("僵尸水族馆：宠物僵尸全部死亡，判负")
	_set_advice(ADVICE_DEATH, 0.0)
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


## 当前水缸里的脑子（探针 / 调试通道用）
func get_brains() -> Array[ZombiquariumBrain]:
	return _brains


func _random_point_in_rect(rect: Rect2) -> Vector2:
	return Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y)
	)


func _clamp_point_in_rect(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)
#endregion
