extends Control
class_name SlotMachineUI
## 拉霸（Slot Machine）小游戏 UI
##
## 使用方式：由关卡脚本实例化后 add_child 到主游戏的 CanvasLayerUI，
## 再调用 init(main_game, start_sun, target_sun)。
## 当从拉杆/植物中累计收集的阳光达到 target_sun 时发出 game_finished 信号。

signal game_finished

const SPIN_COST := 25
const REEL_COUNT := 3
const SEED_FRAME_SIZE := Vector2i(50, 70)
const OVERLAY_POS := Vector2(80, 220)
const OVERLAY_SIZE := Vector2(285, 108)
const REEL_SIZE := Vector2(42, 42)
const REEL_OFFSETS: Array[Vector2] = [
	Vector2(72, 15),
	Vector2(124, 15),
	Vector2(176, 15),
]

enum Symbol {
	PEASHOOTER,
	SUNFLOWER,
	WALLNUT,
	SNOWPEA,
	CHOMPER,
	SUN,
	DIAMOND,
	MAX,
}

const SYMBOL_FRAMES: Array[int] = [2, 1, 3, 4, 0, 5, 6]
const SYMBOL_NAMES: Array[String] = ["豌豆", "向日葵", "坚果", "冰豆", "大嘴", "", ""]
const SYMBOL_PLANTS: Array[CharacterRegistry.PlantType] = [
	CharacterRegistry.PlantType.P001PeaShooterSingle,
	CharacterRegistry.PlantType.P002SunFlower,
	CharacterRegistry.PlantType.P004WallNut,
	CharacterRegistry.PlantType.P006SnowPea,
	CharacterRegistry.PlantType.P007Chomper,
	CharacterRegistry.PlantType.Null,
	CharacterRegistry.PlantType.Null,
]

const JACKPOT_SUN := 500
const JACKPOT_DIAMOND := 300
const TWO_SUN := 100
const TWO_DIAMOND := 100

const SEEDS_ATLAS := preload("res://assets/image/ui/ui_card/seeds.png")
const OVERLAY_TEXTURE := preload("res://assets/image/ui/ui_card/SlotMachine_Overlay.png")
const CHINESE_FONT := preload("res://assets/fonts/SIMSUN.TTC")

var _mg: MainGameManager
var _sun_value: int = 0
var _total_earned: int = 0
var _target_sun: int = 0
var _is_spinning := false
var _has_won := false

var _symbol_textures: Array[Texture2D] = []

var _reel_icon: Array[TextureRect] = []
var _reel_label: Array[Label] = []
var _pull_button: Button
var _sun_label: Label
var _advice_label: Label

var _spin_timer: Timer = null
var _spin_tick: int = 0


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_build_ui()
	EventBus.subscribe("add_sun_value", _on_sun_added)


func _exit_tree() -> void:
	EventBus.unsubscribe("add_sun_value", _on_sun_added)
	if _spin_timer != null and is_instance_valid(_spin_timer):
		_spin_timer.queue_free()


func init(main_game: MainGameManager, start_sun: int, target_sun: int) -> void:
	_mg = main_game
	_sun_value = start_sun
	_total_earned = 0
	_target_sun = target_sun
	_update_sun_label()
	_advice_label.text = "拉动手柄就有新的种子！"
	_pull_button.disabled = _sun_value < SPIN_COST or _has_won


func _build_ui() -> void:
	_symbol_textures.clear()
	for i in range(Symbol.MAX):
		var atlas := AtlasTexture.new()
		atlas.atlas = SEEDS_ATLAS
		var frame_x := SYMBOL_FRAMES[i] * SEED_FRAME_SIZE.x
		atlas.region = Rect2(Vector2(frame_x, 0), Vector2(SEED_FRAME_SIZE))
		_symbol_textures.append(atlas)

	var overlay := TextureRect.new()
	overlay.name = "Overlay"
	overlay.position = OVERLAY_POS
	overlay.size = OVERLAY_SIZE
	overlay.texture = OVERLAY_TEXTURE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(overlay)

	for i in range(REEL_COUNT):
		var reel := Control.new()
		reel.name = "Reel%d" % (i + 1)
		reel.position = REEL_OFFSETS[i]
		reel.size = REEL_SIZE
		overlay.add_child(reel)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.size = REEL_SIZE
		icon.texture = _symbol_textures[0]
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		reel.add_child(icon)
		_reel_icon.append(icon)

		var name_label := Label.new()
		name_label.name = "Name"
		name_label.size = REEL_SIZE
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.label_settings = _make_label_settings(12, Color.BLACK, 1, Color.WHITE)
		reel.add_child(name_label)
		_reel_label.append(name_label)

	_pull_button = Button.new()
	_pull_button.name = "PullButton"
	_pull_button.position = Vector2(0, 66)
	_pull_button.size = Vector2(OVERLAY_SIZE.x, 42)
	_pull_button.text = ""
	var empty_style := StyleBoxEmpty.new()
	_pull_button.add_theme_stylebox_override("normal", empty_style)
	_pull_button.add_theme_stylebox_override("pressed", empty_style)
	_pull_button.add_theme_stylebox_override("hover", empty_style)
	_pull_button.add_theme_stylebox_override("disabled", empty_style)
	_pull_button.add_theme_stylebox_override("focus", empty_style)
	_pull_button.pressed.connect(_on_pull)
	overlay.add_child(_pull_button)

	var pull_label := Label.new()
	pull_label.name = "PullLabel"
	pull_label.position = Vector2(0, 66)
	pull_label.size = Vector2(OVERLAY_SIZE.x, 42)
	pull_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pull_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pull_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pull_label.text = "拉杆 (-25阳光)"
	pull_label.label_settings = _make_label_settings(16, Color.WHITE, 1, Color.BLACK)
	overlay.add_child(pull_label)

	_sun_label = Label.new()
	_sun_label.name = "SunLabel"
	_sun_label.position = Vector2(10, 10)
	_sun_label.size = Vector2(260, 30)
	_sun_label.label_settings = _make_label_settings(18, Color.YELLOW, 1, Color.BLACK)
	add_child(_sun_label)

	_advice_label = Label.new()
	_advice_label.name = "AdviceLabel"
	_advice_label.position = OVERLAY_POS + Vector2(0, OVERLAY_SIZE.y + 10)
	_advice_label.size = Vector2(OVERLAY_SIZE.x, 30)
	_advice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_advice_label.label_settings = _make_label_settings(14, Color.WHITE, 1, Color.BLACK)
	add_child(_advice_label)


func _make_label_settings(font_size: int, font_color: Color, outline: int, outline_color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = CHINESE_FONT
	ls.font_size = font_size
	ls.font_color = font_color
	ls.outline_size = outline
	ls.outline_color = outline_color
	return ls


func _set_reel_symbol(reel_index: int, symbol: int) -> void:
	if reel_index < 0 or reel_index >= REEL_COUNT:
		return
	if symbol < 0 or symbol >= Symbol.MAX:
		symbol = 0
	_reel_icon[reel_index].texture = _symbol_textures[symbol]
	_reel_label[reel_index].text = SYMBOL_NAMES[symbol]


func _update_sun_label() -> void:
	_sun_label.text = "阳光：%d  已收集：%d / %d" % [_sun_value, _total_earned, _target_sun]


func _on_sun_added(amount: int) -> void:
	_sun_value += amount
	_total_earned += amount
	_update_sun_label()
	_pull_button.disabled = _sun_value < SPIN_COST or _has_won
	_check_win()


func _on_pull() -> void:
	if _is_spinning or _has_won:
		return
	if _sun_value < SPIN_COST:
		SoundManager.play_other_SFX("buzzer")
		_advice_label.text = "阳光不足！"
		return

	SoundManager.play_other_SFX("tap")
	_sun_value -= SPIN_COST
	_update_sun_label()
	_advice_label.text = ""
	_spin()


func _spin() -> void:
	_is_spinning = true
	_pull_button.disabled = true

	var final_symbols: Array[int] = []
	for i in range(REEL_COUNT):
		final_symbols.append(randi() % Symbol.MAX)

	var stop_at: Array[int] = [
		randi_range(10, 16),
		randi_range(14, 20),
		randi_range(18, 26),
	]

	_spin_tick = 0
	_spin_timer = Timer.new()
	_spin_timer.name = "SpinTimer"
	_spin_timer.wait_time = 0.08
	_spin_timer.one_shot = false
	_spin_timer.timeout.connect(func() -> void:
		for i in range(REEL_COUNT):
			if _spin_tick < stop_at[i]:
				_set_reel_symbol(i, randi() % Symbol.MAX)
			elif _spin_tick == stop_at[i]:
				_set_reel_symbol(i, final_symbols[i])
		_spin_tick += 1
		if _spin_tick > stop_at.max():
			_spin_timer.stop()
			_spin_timer.queue_free()
			_spin_timer = null
			_resolve_result(final_symbols)
	)
	add_child(_spin_timer)
	_spin_timer.start()


func _resolve_result(symbols: Array[int]) -> void:
	_is_spinning = false

	var counts: Dictionary = {}
	for s in symbols:
		counts[s] = counts.get(s, 0) + 1

	var has_three := false
	var has_two := false
	var match_symbol := -1
	for s in counts.keys():
		if counts[s] == 3:
			has_three = true
			match_symbol = s
			break
		if counts[s] == 2:
			has_two = true
			match_symbol = s

	if has_three:
		_give_three_reward(match_symbol)
	elif has_two:
		_give_two_reward(match_symbol)
	else:
		_advice_label.text = "再拉一次！"

	_pull_button.disabled = _sun_value < SPIN_COST or _has_won
	_check_win()


func _give_three_reward(symbol: int) -> void:
	match symbol:
		Symbol.SUN:
			_add_sun(JACKPOT_SUN)
			_advice_label.text = "阳光大奖！"
		Symbol.DIAMOND:
			_add_sun(JACKPOT_DIAMOND)
			_advice_label.text = "钻石大奖！"
		_:
			_place_plants(SYMBOL_PLANTS[symbol], 3)
			_advice_label.text = "三个图案相同！三株免费植物！"


func _give_two_reward(symbol: int) -> void:
	match symbol:
		Symbol.SUN:
			_add_sun(TWO_SUN)
			_advice_label.text = "两个图案相同！奖励阳光！"
		Symbol.DIAMOND:
			_add_sun(TWO_DIAMOND)
			_advice_label.text = "两个图案相同！钻石！"
		_:
			_place_plants(SYMBOL_PLANTS[symbol], 1)
			_advice_label.text = "两个图案相同！一株免费植物！"


func _add_sun(amount: int) -> void:
	_sun_value += amount
	_total_earned += amount
	_update_sun_label()


func _place_plants(plant_type: CharacterRegistry.PlantType, count: int) -> void:
	if not is_instance_valid(_mg) or _mg.plant_cell_manager == null:
		return
	var all_cells: Array = _mg.plant_cell_manager.all_plant_cells
	if all_cells.is_empty():
		return

	var candidates: Array[PlantCell] = []
	for row in all_cells:
		for cell: PlantCell in row:
			if cell.can_common_plant and cell.get_curr_plant_num() == 0:
				candidates.append(cell)

	candidates.shuffle()
	var placed := 0
	for i in range(mini(count, candidates.size())):
		candidates[i].create_plant(plant_type)
		placed += 1

	if placed < count:
		Log.debug("拉霸：格子不足，%d 株 %s 只种下 %d 株" % [count, SYMBOL_NAMES[SYMBOL_PLANTS.find(plant_type)], placed])


func _check_win() -> void:
	if _has_won:
		return
	if _total_earned >= _target_sun:
		_has_won = true
		_pull_button.disabled = true
		_advice_label.text = "目标达成！"
		SoundManager.play_other_SFX("points")
		game_finished.emit()


func _process(_delta: float) -> void:
	if not _is_spinning:
		_check_win()
