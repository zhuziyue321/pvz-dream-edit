extends Control
class_name SlotMachineUI
## 拉霸（Slot Machine）小游戏 UI —— 从原版 C++ 参照移植
##
## 使用方式：由关卡脚本实例化后 add_child 到主游戏的 CanvasLayerUI，
## 再调用 init(main_game, start_sun, target_sun)。
## 当前阳光达到 target_sun 时发出 game_finished 信号。
##
## 原版口径（行号见各常量注释，来源：本机 `../PvZ-Portable-main`）：
##   · 机器排在屏幕左上角：阳光银行 + 3 个种子包当转轮 + 覆盖层 + 右侧拉杆
##     （SeedBank::Draw / Board::GetSeedPacketPositionX / Challenge::SlotMachineGetHandleRect）；
##   · 点拉杆扣 25 阳光，三个转轮同时开转（各 300 帧，每秒翻转 5 → 2 次），
##     全部停下后按「三个相同 / 两个相同」结算（Challenge::UpdateSlotMachine）；
##   · 符号权重：向日葵 / 豌豆 / 寒冰豆 / 坚果 / 太阳各 100、钻石 30，
##     豌豆权重随场上豌豆数从 200 降到 100，第 3 个转轮偏向前两个转轮即将出现的符号
##     （SeedPacket::PickNextSlotMachineSeed）；
##   · 奖励：两个相同 = 1 钻石 / 4 颗太阳 / 1 株免费植物；三个相同 = 5 钻石 / 20 颗太阳 / 3 株免费植物；
##   · 当前阳光（0~2000 截断）达到 2000 过关，奖杯掉在原地（Challenge::UpdateSlotMachine）。

signal game_finished

## ---------- 原版数值 ----------
## 拉一次杆扣的阳光（Challenge.cpp MouseDown: TakeSunMoney(25)）
const SPIN_COST := 25
## 转轮个数（SeedBank 里 3 个种子包当转轮，Board.cpp InitLevel 有断言）
const REEL_COUNT := 3
## 转轮滚动帧数（SeedPacket.cpp SlotMachineStart: mSlotMachineCountDown = 300）
const SPIN_COUNTDOWN := 300
## 翻转速度曲线的定义域（SeedPacket.cpp: SLOT_MACHINE_TIME = 400）
const SPIN_TIME := 400.0
## 每秒翻转次数：曲线两端（countdown = 400 → 6.0，countdown = 0 → 2.0）
const FLIPS_PER_SEC_FAST := 6.0
const FLIPS_PER_SEC_SLOW := 2.0
## 过关阳光（Challenge.cpp: SLOT_MACHINE_WINNING_SCORE = 2000）
const WINNING_SCORE := 2000
## 距过关 100 点以内的提示线（Challenge.cpp UpdateSlotMachine）
const ALMOST_THERE_SCORE := 1900
## 转轮（种子包）尺寸：50x70，与出战卡片一致
const PACKET_SIZE := Vector2i(50, 70)
## 种子包 x = index * 59 + 247（Board.cpp GetSeedPacketPositionX）
const PACKET_START_X := 247
const PACKET_STEP_X := 59
## 种子包 y = 8（Board.cpp InitLevel: aPacket->mY = 8）
const PACKET_Y := 8
## 阳光银行底图位置与尺寸（SeedBank::Draw: IMAGE_SUNBANK 画在 (0,0)）
const SUN_BANK_SIZE := Vector2(78, 87)
## 阳光数值文字位置（SeedBank::Draw: PvzpDrawString(..., 34, 78, ...居中)）
const SUN_VALUE_LABEL_RECT := Rect2(4, 68, 70, 18)
## 拉霸覆盖层位置与尺寸（SeedBank::Draw: IMAGE_SLOTMACHINE_OVERLAY 画在 (189,-2)）
const OVERLAY_POS := Vector2(189, -2)
const OVERLAY_SIZE := Vector2(285, 108)
## 拉杆可点区域（Challenge.cpp SlotMachineGetHandleRect）
const HANDLE_RECT := Rect2(473, 0, 55, 80)
## 拉杆三块零件（pak/reanim/SlotMachine.reanim 的 base / shaft / ball 三条轨，
## reanim 原点在机器坐标 (96,-20)，下面是换算到机器坐标后的中心点与缩放）
const LEVER_SCALE := 0.6
const LEVER_BASE_CENTER := Vector2(474.5, 14.3)
const LEVER_BASE_SIZE := Vector2(57, 156)
const LEVER_SHAFT_CENTER := Vector2(474.3, 63.3)
const LEVER_SHAFT_SIZE := Vector2(95, 18)
## 连杆拉下时的横向压缩（reanim shaft 轨：静止 0.599、拉下 0.464）
const LEVER_SHAFT_SCALE_PULLED := 0.464
const LEVER_BALL_CENTER_REST := Vector2(486.4, 11.2)
const LEVER_BALL_CENTER_PULLED := Vector2(486.4, 81.1)
const LEVER_BALL_SIZE := Vector2(44, 44)
## 拉杆拉下 / 回弹用时（原版 anim_pull 速率 36、anim_return 速率 24，12fps）
const LEVER_PULL_DURATION := 0.15
const LEVER_RETURN_DURATION := 0.25
## 前 3 次拉杆之前手柄闪烁（Challenge::DrawSlotMachine 的 GetFlashingColor）
const LEVER_FLASH_ROLL_COUNT := 3
const LEVER_FLASH_COLOR := Color(1.5, 1.35, 0.9)
const LEVER_FLASH_PERIOD := 1.25
## 一颗太阳币的价值（原版 COIN_SUN）
const SUN_COIN_VALUE := 25
## 一枚钻石的价值（原版 COIN_DIAMOND = 100 阳光）
const DIAMOND_VALUE := 100
## 奖励硬币的出生位置（Challenge.cpp UpdateSlotMachine 里 AddCoin 的坐标，屏幕坐标）
const REWARD_POS := Vector2(320, 85)
## 免费植物卡 / 钻石币的存在时间（Coin.cpp: 拉霸关种子包硬币 1500 帧 = 25 秒）
const REWARD_EXIST_TIME := 25.0
## 钻石币的显示尺寸（pak/reanim/Diamond.png 是 68x52，缩到硬币大小）
const DIAMOND_COIN_SIZE := Vector2(30, 23)
## 结果提示停留时长（原版 MessageWidget 的显示时长量级）
const ADVICE_HOLD_TIME := 2.5

## ---------- 转轮符号（与原版 SLOT_SEED_TYPES 一一对应，SeedPacket.cpp）----------
enum Symbol {
	SUNFLOWER,
	PEASHOOTER,
	SNOWPEA,
	WALLNUT,
	SUN,
	DIAMOND,
}
const SYMBOL_COUNT := 6
## seeds.png 里的帧号（与原版种子包图标一一对应）
const SYMBOL_FRAMES: Array[int] = [1, 2, 4, 3, 5, 6]
## 植物符号对应的植物（太阳 / 钻石不是植物，用 NULL 占位）
const SYMBOL_PLANTS: Array[StringName] = [
	PlantIds.SUN_FLOWER,
	PlantIds.PEA_SHOOTER_SINGLE,
	PlantIds.SNOW_PEA,
	PlantIds.WALL_NUT,
	PlantIds.NULL,
	PlantIds.NULL,
]
## 初始三个转轮的符号（Board.cpp InitLevel: 向日葵 / 豌豆 / 寒冰豆）
const INIT_SYMBOLS: Array[int] = [Symbol.SUNFLOWER, Symbol.PEASHOOTER, Symbol.SNOWPEA]

## ---------- 符号权重（SeedPacket.cpp PickNextSlotMachineSeed）----------
const WEIGHT_BASE := 100
const WEIGHT_DIAMOND := 30
## 豌豆权重：场上豌豆 0 株时 200，满 5 株时 100（线性）
const PEASHOOTER_WEIGHT_MAX := 200
const PEASHOOTER_WEIGHT_MIN := 100
const PEASHOOTER_WEIGHT_FULL_PLANTS := 5
## 第 3 个转轮偏向：与前两个转轮即将出现的符号一致时权重 x1.5（钻石除外）
const THIRD_REEL_MATCH_BONUS := 1.5

## ---------- 提示文案（data/strings/lawn_strings.txt 同 key）----------
const ADVICE_PULL := "拉动手柄就有新的种子！"
const ADVICE_SPIN_AGAIN := "再拉一次！"
const ADVICE_COLLECT_SUN := "收集2000点阳光即可过关"
const ADVICE_ALMOST_THERE := "就要成功了！"
const ADVICE_TWO_DIAMONDS := "两个图案相同！钻石！"
const ADVICE_TWO_SUNS := "两个图案相同！奖励阳光！"
const ADVICE_TWO_OF_A_KIND := "两个图案相同！一株免费植物！"
const ADVICE_DIAMOND_JACKPOT := "钻石大奖！"
const ADVICE_SUN_JACKPOT := "阳光大奖！"
const ADVICE_THREE_OF_A_KIND := "三个图案相同！三株免费植物！"

## ---------- 贴图 / 字体（统一走 AssetRegistry 缓存）----------
var SEEDS_ATLAS: Texture2D = AssetRegistry.get_texture("res://pak/images/seeds.png")
var SUN_BANK_TEXTURE: Texture2D = AssetRegistry.get_texture("res://pak/images/SunBank.png")
var OVERLAY_TEXTURE: Texture2D = AssetRegistry.get_texture("res://pak/images/SlotMachine_Overlay.png")
var LEVER_BASE_TEXTURE: Texture2D = AssetRegistry.get_texture("res://pak/reanim/SlotMachine_base.png")
var LEVER_SHAFT_TEXTURE: Texture2D = AssetRegistry.get_texture("res://pak/reanim/SlotMachine_shaft.png")
var LEVER_BALL_TEXTURE: Texture2D = AssetRegistry.get_texture("res://pak/reanim/SlotMachine_ball.png")
var DIAMOND_TEXTURE: Texture2D = AssetRegistry.get_texture("res://pak/reanim/Diamond.png")
var CHINESE_FONT: Font = AssetRegistry.get_font("res://assets_custom/fonts/SIMSUN.TTC")

## ---------- 运行期状态 ----------
var _mg: MainGameManager
var _sun_value: int = 0
var _target_sun: int = WINNING_SCORE
## 是否正在转轮（原版 STATECHALLENGE_SLOT_MACHINE_ROLLING）
var _is_spinning: bool = false
## 是否已经过关
var _has_won: bool = false
## 已拉杆次数（原版 mSlotMachineRollCount：前 3 次之前手柄闪烁）
var _roll_count: int = 0
## 每个转轮：当前符号 / 下一个符号 / 滚动位置(0~1) / 剩余帧数
var _curr_symbols: Array[int] = []
var _next_symbols: Array[int] = []
var _scroll_positions: Array[float] = []
var _countdowns: Array[int] = []
## 按 60fps 累计的整帧步进（原版转轮是逐帧驱动的）
var _frame_accumulator: float = 0.0

## ---------- 节点 ----------
var _symbol_textures: Array[Texture2D] = []
var _reel_current_icons: Array[TextureRect] = []
var _reel_next_icons: Array[TextureRect] = []
var _lever_base: TextureRect
var _lever_shaft: TextureRect
var _lever_ball: TextureRect
var _handle_button: Button
var _sun_value_label: Label
## 结果提示的停留计时器（到点回到待机提示）
var _advice_timer: Timer
## 当前显示中的提示文本（相同就不重复刷，避免每 2.5 秒重设一次）
var _curr_advice: String = ""
## 「收集阳光」/「就要成功了」这两条一次性提示发过没有（原版 mHelpDisplayed 口径）
var _collect_sun_advice_shown: bool = false
var _almost_there_advice_shown: bool = false


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_build_symbol_textures()
	_build_ui()
	EventBus.subscribe(ConstEventName.ADD_SUN_VALUE, _on_sun_added)


func _exit_tree() -> void:
	EventBus.unsubscribe(ConstEventName.ADD_SUN_VALUE, _on_sun_added)


## 关卡脚本调用：给足主游戏 / 本金 / 过关目标
func init(main_game: MainGameManager, start_sun: int, target_sun: int) -> void:
	_mg = main_game
	_sun_value = start_sun
	_target_sun = target_sun
	_is_spinning = false
	_has_won = false
	_roll_count = 0
	for i in range(REEL_COUNT):
		_curr_symbols[i] = INIT_SYMBOLS[i]
		_next_symbols[i] = INIT_SYMBOLS[i]
		_scroll_positions[i] = 0.0
		_countdowns[i] = 0
	_update_reel_visuals()
	_update_sun_value_label()
	_handle_button.disabled = false
	## 开场提示（原版 TUTORIAL_SLOT_MACHINE_PULL，第一次拉杆后清掉）
	_set_advice(ADVICE_PULL)


## 进度条数据源用：当前阳光 / 过关目标
func get_sun_value() -> int:
	return _sun_value


func get_target_sun() -> int:
	return _target_sun


func _process(_delta: float) -> void:
	if _is_spinning:
		_step_reels(_delta)
	_update_lever_flash()
	_check_almost_there()
	_check_win()


#region 搭场景
func _build_symbol_textures() -> void:
	_symbol_textures.clear()
	for i in range(SYMBOL_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = SEEDS_ATLAS
		var frame_x := SYMBOL_FRAMES[i] * PACKET_SIZE.x
		atlas.region = Rect2(Vector2(frame_x, 0), Vector2(PACKET_SIZE))
		_symbol_textures.append(atlas)


func _build_ui() -> void:
	for _i in range(REEL_COUNT):
		_curr_symbols.append(0)
		_next_symbols.append(0)
		_scroll_positions.append(0.0)
		_countdowns.append(0)

	_build_sun_bank()
	_build_reels()
	_build_overlay()
	_build_lever()
	_build_handle_button()

	_advice_timer = Timer.new()
	_advice_timer.name = "AdviceTimer"
	_advice_timer.one_shot = true
	_advice_timer.wait_time = ADVICE_HOLD_TIME
	_advice_timer.timeout.connect(_show_idle_advice)
	add_child(_advice_timer)


## 阳光银行底图 + 上面的阳光数值（原版 SeedBank::Draw 最后那段文字）
func _build_sun_bank() -> void:
	var bank := _make_ignore_texture_rect("SunBank", SUN_BANK_TEXTURE, SUN_BANK_SIZE)
	bank.position = Vector2.ZERO
	add_child(bank)

	_sun_value_label = Label.new()
	_sun_value_label.name = "SunValue"
	_sun_value_label.position = SUN_VALUE_LABEL_RECT.position
	_sun_value_label.size = SUN_VALUE_LABEL_RECT.size
	_sun_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sun_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sun_value_label.label_settings = _make_label_settings(14, Color.BLACK, 0, Color.BLACK)
	_sun_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sun_value_label)


## 三个转轮：每个转轮是「当前包 + 下一个包」上下两块，滚动时一起位移
func _build_reels() -> void:
	for i in range(REEL_COUNT):
		var reel := Control.new()
		reel.name = "Reel%d" % (i + 1)
		reel.position = Vector2(PACKET_START_X + i * PACKET_STEP_X, PACKET_Y)
		reel.size = Vector2(PACKET_SIZE)
		reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(reel)

		var curr_icon := _make_ignore_texture_rect("Curr", _symbol_textures[0], Vector2(PACKET_SIZE))
		reel.add_child(curr_icon)
		_reel_current_icons.append(curr_icon)

		var next_icon := _make_ignore_texture_rect("Next", _symbol_textures[0], Vector2(PACKET_SIZE))
		next_icon.position = Vector2(0, PACKET_SIZE.y)
		reel.add_child(next_icon)
		_reel_next_icons.append(next_icon)


## 覆盖层：画在转轮之后 = 盖在转轮上（与原版绘制顺序一致）
func _build_overlay() -> void:
	var overlay := _make_ignore_texture_rect("Overlay", OVERLAY_TEXTURE, OVERLAY_SIZE)
	overlay.position = OVERLAY_POS
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(overlay)


## 拉杆三块：底座 / 连杆 / 球柄（原版是 SlotMachine.reanim，本仓没有转好的场景，
## 照 src/items/mini_game/portal.gd 的先例用贴图 + Tween 复现 pull / return）
func _build_lever() -> void:
	_lever_base = _make_lever_part("LeverBase", LEVER_BASE_TEXTURE, LEVER_BASE_SIZE,
		LEVER_BASE_CENTER)
	add_child(_lever_base)

	_lever_shaft = _make_lever_part("LeverShaft", LEVER_SHAFT_TEXTURE, LEVER_SHAFT_SIZE,
		LEVER_SHAFT_CENTER)
	## 连杆右端不动（原版 shaft 轨的旋转中心在右侧）：缩放时以右端为轴
	_lever_shaft.pivot_offset = Vector2(LEVER_SHAFT_SIZE.x, LEVER_SHAFT_SIZE.y * 0.5)
	var shaft_right_x: float = LEVER_SHAFT_CENTER.x + LEVER_SHAFT_SIZE.x * LEVER_SCALE * 0.5
	_lever_shaft.position = Vector2(shaft_right_x - LEVER_SHAFT_SIZE.x,
		LEVER_SHAFT_CENTER.y - LEVER_SHAFT_SIZE.y * 0.5)
	add_child(_lever_shaft)

	_lever_ball = _make_lever_part("LeverBall", LEVER_BALL_TEXTURE, LEVER_BALL_SIZE,
		LEVER_BALL_CENTER_REST)
	add_child(_lever_ball)


## 拉杆点热区：透明按钮 + 无文字（Button 不支持 label_settings，见工作记录踩坑）
func _build_handle_button() -> void:
	_handle_button = Button.new()
	_handle_button.name = "HandleButton"
	_handle_button.position = HANDLE_RECT.position
	_handle_button.size = HANDLE_RECT.size
	_handle_button.text = ""
	var empty_style := StyleBoxEmpty.new()
	_handle_button.add_theme_stylebox_override("normal", empty_style)
	_handle_button.add_theme_stylebox_override("pressed", empty_style)
	_handle_button.add_theme_stylebox_override("hover", empty_style)
	_handle_button.add_theme_stylebox_override("disabled", empty_style)
	_handle_button.add_theme_stylebox_override("focus", empty_style)
	_handle_button.pressed.connect(_on_handle_pressed)
	add_child(_handle_button)


func _make_ignore_texture_rect(node_name: String, texture: Texture2D,
		rect_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.size = rect_size
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## 拉杆零件：按原版缩放摆在机器坐标上（position 是左上角，要按中心点换算）
func _make_lever_part(node_name: String, texture: Texture2D, part_size: Vector2,
		center: Vector2) -> TextureRect:
	var part := TextureRect.new()
	part.name = node_name
	part.size = part_size
	part.texture = texture
	part.scale = Vector2(LEVER_SCALE, LEVER_SCALE)
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.position = center - part_size * LEVER_SCALE * 0.5
	return part


func _make_label_settings(font_size: int, font_color: Color, outline: int,
		outline_color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = CHINESE_FONT
	settings.font_size = font_size
	settings.font_color = font_color
	settings.outline_size = outline
	settings.outline_color = outline_color
	return settings
#endregion


#region 拉杆与转轮
## 拉杆被按下（原版 Challenge::MouseDown 的 OBJECT_TYPE_SLOT_MACHINE_HANDLE 分支）
func _on_handle_pressed() -> void:
	if _is_spinning or _has_won:
		return
	if _sun_value < SPIN_COST:
		## 阳光不够：原版 TakeSunMoney 失败会闪阳光数 + 提示 NOT_ENOUGH_SUN
		SoundManager.play_other_SFX(&"buzzer")
		_flash_sun_value_label()
		return

	SoundManager.play_other_SFX(&"slotmachine")
	_sun_value -= SPIN_COST
	_update_sun_value_label()
	_roll_count += 1
	_set_advice("")

	for i in range(REEL_COUNT):
		_countdowns[i] = SPIN_COUNTDOWN
		_scroll_positions[i] = 0.0
		_next_symbols[i] = _pick_next_symbol(i)
	_is_spinning = true
	_frame_accumulator = 0.0
	_play_lever_pull()


## 每秒翻转次数：原版 PvzpAnimateCurveFloat(400, 0, countdown, 6.0, 2.0)
func _flips_per_second(countdown: int) -> float:
	var progress := clampf((SPIN_TIME - float(countdown)) / SPIN_TIME, 0.0, 1.0)
	return lerpf(FLIPS_PER_SEC_FAST, FLIPS_PER_SEC_SLOW, progress)


## 按 60fps 步进转轮（原版 SeedPacket::Update 的逐帧逻辑）
func _step_reels(delta: float) -> void:
	_frame_accumulator += delta * 60.0
	var frames := int(_frame_accumulator)
	if frames <= 0:
		return
	_frame_accumulator -= float(frames)
	frames = mini(frames, 10)

	for _frame in range(frames):
		var any_spinning := false
		for i in range(REEL_COUNT):
			if _countdowns[i] <= 0:
				continue
			any_spinning = true
			_countdowns[i] -= 1
			_scroll_positions[i] += _flips_per_second(_countdowns[i]) / 60.0
			if _scroll_positions[i] >= 1.0:
				_curr_symbols[i] = _next_symbols[i]
				if _countdowns[i] <= 0:
					## 倒计时走完：这一格翻完就停
					_scroll_positions[i] = 0.0
				else:
					_scroll_positions[i] -= 1.0
					_next_symbols[i] = _pick_next_symbol(i)
			elif _countdowns[i] <= 0:
				## 原版：倒计时到了但这一格没翻完，再给一帧把它翻完
				_countdowns[i] = 1
		if not any_spinning:
			break

	_update_reel_visuals()
	if not _is_any_reel_spinning():
		_is_spinning = false
		_resolve_result()


func _is_any_reel_spinning() -> bool:
	for countdown in _countdowns:
		if countdown > 0:
			return true
	return false


## 把三个转轮的当前 / 下一个包画到位（原版 SeedPacket::Draw 的两层堆叠）
func _update_reel_visuals() -> void:
	for i in range(REEL_COUNT):
		var offset := -float(PACKET_SIZE.y) * _scroll_positions[i]
		_reel_current_icons[i].position = Vector2(0, offset)
		_reel_current_icons[i].texture = _symbol_textures[_curr_symbols[i]]
		_reel_next_icons[i].position = Vector2(0, PACKET_SIZE.y + offset)
		_reel_next_icons[i].texture = _symbol_textures[_next_symbols[i]]
		## 停稳之后不画下一个包（原版 countdown <= 0 时只画当前包）
		_reel_next_icons[i].visible = _countdowns[i] > 0


## 符号权重表（原版 SeedPacket::PickNextSlotMachineSeed）：按符号下标给出权重。
## 抽成纯函数是为了让探针能确定性地核对权重公式（随机部分另测）
func _symbol_weights(reel_index: int, peashooter_count: int) -> Array[int]:
	var weights: Array[int] = []
	for symbol in range(SYMBOL_COUNT):
		var weight := WEIGHT_BASE
		match symbol:
			Symbol.PEASHOOTER:
				## 场上豌豆越多越不容易出豌豆（原版 200 → 100）
				var ratio := clampf(float(peashooter_count) / float(PEASHOOTER_WEIGHT_FULL_PLANTS),
					0.0, 1.0)
				weight = int(round(lerpf(float(PEASHOOTER_WEIGHT_MAX), float(PEASHOOTER_WEIGHT_MIN),
					ratio)))
			Symbol.DIAMOND:
				weight = WEIGHT_DIAMOND
		if reel_index == 2 and symbol != Symbol.DIAMOND:
			## 第三个转轮偏向前两个转轮即将出现的符号（钻石除外）
			if symbol == _next_symbols[0] or symbol == _next_symbols[1]:
				weight = int(round(float(weight) * THIRD_REEL_MATCH_BONUS))
		weights.append(weight)
	return weights


## 加权随机下一个符号（原版 SeedPacket::PickNextSlotMachineSeed）
func _pick_next_symbol(reel_index: int) -> int:
	var peashooter_count := _count_plant(PlantIds.PEA_SHOOTER_SINGLE)
	var weights := _symbol_weights(reel_index, peashooter_count)

	var total_weight := 0
	for weight in weights:
		total_weight += weight
	var roll := randi() % total_weight
	for symbol in range(SYMBOL_COUNT):
		roll -= weights[symbol]
		if roll < 0:
			return symbol
	return SYMBOL_COUNT - 1


## 场上某种植物的数量（豌豆权重要用，原版 Board::CountPlantByType）
func _count_plant(plant_type: StringName) -> int:
	if not is_instance_valid(_mg) or _mg.plant_cell_manager == null:
		return 0
	return int(_mg.plant_cell_manager.curr_plant_num.get(plant_type, 0))
#endregion


#region 结算（原版 Challenge::UpdateSlotMachine 停轮后的分支）
func _resolve_result() -> void:
	_play_lever_return()
	var first: int = _curr_symbols[0]
	var second: int = _curr_symbols[1]
	var third: int = _curr_symbols[2]

	if first == second and second == third:
		SoundManager.play_other_SFX(&"chime")
		_give_three_of_a_kind(first)
	elif first == second or second == third or first == third:
		SoundManager.play_other_SFX(&"chime")
		## 原版：成对的那个取先配上的那个（aPacket1 优先）
		var matched: int = first if (first == second or first == third) else second
		_give_two_of_a_kind(matched)
	else:
		## 原版没中的时候不发提示，直接回到待机提示
		_show_idle_advice()


## 两个相同：1 钻石 / 4 颗太阳 / 1 株免费植物
func _give_two_of_a_kind(symbol: int) -> void:
	match symbol:
		Symbol.DIAMOND:
			_set_advice(ADVICE_TWO_DIAMONDS)
			_spawn_diamond_coin(REWARD_POS)
		Symbol.SUN:
			_set_advice(ADVICE_TWO_SUNS)
			for i in range(4):
				_spawn_sun_coin(REWARD_POS + Vector2(i * 15, 0))
		_:
			_set_advice(ADVICE_TWO_OF_A_KIND)
			_spawn_free_plant_card(SYMBOL_PLANTS[symbol], REWARD_POS)


## 三个相同：5 钻石 / 20 颗太阳 / 3 株免费植物
func _give_three_of_a_kind(symbol: int) -> void:
	match symbol:
		Symbol.DIAMOND:
			_set_advice(ADVICE_DIAMOND_JACKPOT)
			for i in range(5):
				_spawn_diamond_coin(REWARD_POS + Vector2(i * 12, 0))
		Symbol.SUN:
			_set_advice(ADVICE_SUN_JACKPOT)
			for i in range(20):
				_spawn_sun_coin(REWARD_POS + Vector2(i * 3, 0))
		_:
			_set_advice(ADVICE_THREE_OF_A_KIND)
			for i in range(3):
				_spawn_free_plant_card(SYMBOL_PLANTS[symbol], REWARD_POS + Vector2(i * 20, 0))


## 太阳币：走本体阳光生成口（弹起来再落下，与向日葵产的同一套）
func _spawn_sun_coin(screen_pos: Vector2) -> void:
	if not is_instance_valid(_mg) or _mg.suns == null:
		return
	var camera: Camera2D = _mg.camera_2d
	if not is_instance_valid(camera):
		return
	var global_pos: Vector2 = camera.global_position + screen_pos
	SunSpawner.pop_up(_mg.suns, _mg.suns.to_local(global_pos), SUN_COIN_VALUE)


## 钻石币：本关专属的可点掉落物（原版 COIN_DIAMOND，价值 100 阳光）。
## 挂在 UI 层：钻石图案不在本体阳光那一套里，且它要从机器上方掉出来
func _spawn_diamond_coin(screen_pos: Vector2) -> void:
	var coin := Control.new()
	coin.name = "DiamondCoin"
	coin.size = DIAMOND_COIN_SIZE
	coin.position = screen_pos - DIAMOND_COIN_SIZE * 0.5
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.size = DIAMOND_COIN_SIZE
	icon.texture = DIAMOND_TEXTURE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.add_child(icon)

	var button := Button.new()
	button.name = "PickButton"
	button.size = DIAMOND_COIN_SIZE
	button.text = ""
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("disabled", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.pressed.connect(_on_diamond_coin_picked.bind(coin))
	coin.add_child(button)

	## 从机器里抛出来再落地（原版 COIN_MOTION_COIN 的那一小段抛物线）
	var tween := coin.create_tween()
	tween.tween_property(coin, "position:y", coin.position.y - 15.0, 0.3) \
		.as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(coin, "position:y", coin.position.y + 45.0, 0.6) \
		.as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	## 超时消失（原版硬币也有消失计时，拉霸关种子包硬币是 1500 帧）
	var life_timer := Timer.new()
	life_timer.name = "LifeTimer"
	life_timer.one_shot = true
	life_timer.wait_time = REWARD_EXIST_TIME
	life_timer.timeout.connect(coin.queue_free)
	coin.add_child(life_timer)
	life_timer.start()


func _on_diamond_coin_picked(coin: Control) -> void:
	if not is_instance_valid(coin):
		return
	SoundManager.play_other_SFX(&"coin")
	## 与向日葵产的阳光同一条入账通道（SlotMachineUI 自己订阅了它）
	EventBus.push_event(ConstEventName.ADD_SUN_VALUE, [DIAMOND_VALUE])
	coin.queue_free()


## 免费植物：掉一张临时卡，玩家点起来自己找地方种（原版是种子包硬币变光标植物，
## 本仓等价物是 CardManager.create_temp_card，砸罐子关同款用法）
func _spawn_free_plant_card(plant_type: StringName, screen_pos: Vector2) -> void:
	if plant_type == PlantIds.NULL:
		return
	if not is_instance_valid(_mg) or _mg.card_manager == null:
		return
	var card_para: Dictionary = {
		CardManager.E_TempCardParaAttr.PlantType: plant_type,
		CardManager.E_TempCardParaAttr.GlobalPos: screen_pos,
		CardManager.E_TempCardParaAttr.ExistTime: REWARD_EXIST_TIME,
	}
	var card: Card = _mg.card_manager.create_temp_card(card_para)
	if card == null:
		Log.error("拉霸：免费植物卡没建出来，植物 = " + str(plant_type))
		return
	## 与原版硬币一样从小弹一下再落地
	var tween := card.create_tween()
	tween.tween_property(card, "position:y", card.position.y - 12.0, 0.25) \
		.as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position:y", card.position.y + 12.0, 0.35) \
		.as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
#endregion


#region 拉杆表现
## 拉杆拉下（原版 anim_pull）
func _play_lever_pull() -> void:
	var pulled_y: float = LEVER_BALL_CENTER_PULLED.y - LEVER_BALL_SIZE.y * LEVER_SCALE * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_lever_ball, "position:y", pulled_y, LEVER_PULL_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_lever_shaft, "scale:x", LEVER_SHAFT_SCALE_PULLED, LEVER_PULL_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 拉杆回弹（原版 anim_return）
func _play_lever_return() -> void:
	var rest_y: float = LEVER_BALL_CENTER_REST.y - LEVER_BALL_SIZE.y * LEVER_SCALE * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_lever_ball, "position:y", rest_y, LEVER_RETURN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_lever_shaft, "scale:x", LEVER_SCALE, LEVER_RETURN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 前 3 次拉杆之前手柄闪烁（原版 Challenge::DrawSlotMachine 的 GetFlashingColor）
func _update_lever_flash() -> void:
	var should_flash: bool = _roll_count < LEVER_FLASH_ROLL_COUNT \
		and not _is_spinning and not _has_won
	if not should_flash:
		_set_lever_modulate(Color.WHITE)
		return
	var phase: float = sin(Time.get_ticks_msec() / 1000.0 * TAU / LEVER_FLASH_PERIOD) * 0.5 + 0.5
	_set_lever_modulate(Color.WHITE.lerp(LEVER_FLASH_COLOR, phase))


func _set_lever_modulate(color: Color) -> void:
	_lever_base.modulate = color
	_lever_shaft.modulate = color
	_lever_ball.modulate = color
#endregion


#region 阳光 / 提示 / 过关
func _update_sun_value_label() -> void:
	_sun_value_label.text = str(maxi(_sun_value, 0))


## 阳光不够时把阳光数闪红（原版 mOutOfMoneyCounter 的红字）
func _flash_sun_value_label() -> void:
	var settings: LabelSettings = _sun_value_label.label_settings
	if settings == null:
		return
	var tween := create_tween()
	tween.tween_property(settings, "font_color", Color.RED, 0.1)
	tween.tween_property(settings, "font_color", Color.BLACK, 0.1).set_delay(0.4)


## 向日葵产的阳光 / 钻石币都走这条事件入账
func _on_sun_added(amount: int) -> void:
	_sun_value += amount
	_update_sun_value_label()


## 过关判定（原版 UpdateSlotMachine 每帧查一次阳光）
func _check_win() -> void:
	if _has_won or _sun_value < _target_sun:
		return
	_has_won = true
	_handle_button.disabled = true
	_set_lever_modulate(Color.WHITE)
	_set_advice("")
	game_finished.emit()


## 距过关 100 点以内时提示一次「就要成功了」（原版 ADVICE_ALMOST_THERE，发一次）
func _check_almost_there() -> void:
	if _has_won or _is_spinning or _almost_there_advice_shown:
		return
	if _sun_value >= ALMOST_THERE_SCORE:
		_almost_there_advice_shown = true
		_set_advice(ADVICE_ALMOST_THERE)


## 发一条提示（屏幕下方横幅，走本体的提示条；空串 = 收起）
func _set_advice(text: String) -> void:
	if text == _curr_advice:
		return
	_curr_advice = text
	var hint := TutorialAdviceUI.ensure_level_hint(_mg)
	if hint == null:
		return
	if text.is_empty():
		hint.hide_advice()
		return
	hint.show_advice(text)
	_advice_timer.start(ADVICE_HOLD_TIME)


## 待机提示：原版是「收集阳光」发一次、之后循环「再拉一次」
func _show_idle_advice() -> void:
	if _has_won:
		_set_advice("")
		return
	if _roll_count <= 0:
		## 开场那句「拉动手柄…」留着（原版 TUTORIAL_SLOT_MACHINE_PULL）
		return
	if not _collect_sun_advice_shown:
		_collect_sun_advice_shown = true
		_set_advice(ADVICE_COLLECT_SUN)
		return
	if _is_spinning:
		## 原版：转轮还在转的时候只显示「收集阳光」，「再拉一次」是停稳之后才给的
		return
	_set_advice(ADVICE_SPIN_AGAIN)
#endregion
