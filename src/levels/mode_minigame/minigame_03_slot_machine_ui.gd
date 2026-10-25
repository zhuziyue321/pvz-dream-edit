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
##   · 根 Control 不吃鼠标（mouse_filter = IGNORE）：它只是全屏坐标系，挡住它就点不到菜单；
##   · 转轮贴图 = 种子包卡面：植物符号走 AllCards 的卡面工厂（包底 + 植物立绘，与出战卡同源），
##     太阳 / 钻石用 seeds.png（原版 IMAGE_SEEDS 包底图集）的专用整图格；
##     滚动只画在包自身 50x70 矩形里（SeedPacket::Draw 的 ClipRect(0,0,mWidth,mHeight)），
##     上一个包向上滑出、下一个包只从底边露头；
##   · 拉杆 = SlotMachine.reanim 关键帧（含 kx 旋转角，摆臂式拉杆），拉下 / 回弹各播一段；
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
## 种子包 x = index * 59 + 257。
## 注意：PvZ-Portable 的 GetSeedPacketPositionX 写的是 247，但原版实机截图
## （wiki PC 版 w1/w3/w4/w5）面板红框 200..480、窗口/包整体在 +10 处 ——
## 整条机器系（覆盖层 / 种子包 / 拉杆 / 阳光数字）按截图统一 +10 校准
const PACKET_START_X := 257
const PACKET_STEP_X := 59
## 种子包 y = 8（Board.cpp InitLevel: aPacket->mY = 8）
const PACKET_Y := 8
## 阳光银行底图位置与尺寸（SeedBank::Draw: IMAGE_SUNBANK 画在 (0,0)；贴图自带左边距）
const SUN_BANK_SIZE := Vector2(78, 87)
## 阳光数值文字位置（原版 PvzpDrawString(..., 34, 78, 居中)；按截图 +8 校准 → 中心 47）
const SUN_VALUE_LABEL_RECT := Rect2(12, 68, 70, 18)
## 拉霸覆盖层位置与尺寸（SeedBank::Draw: IMAGE_SLOTMACHINE_OVERLAY 画在 (189,-2)，截图校准 +10）
const OVERLAY_POS := Vector2(199, -2)
const OVERLAY_SIZE := Vector2(285, 108)
## 拉杆可点区域（Challenge.cpp SlotMachineGetHandleRect，截图校准 +10）
const HANDLE_RECT := Rect2(483, 0, 55, 80)
## 拉杆三块零件（pak/reanim/SlotMachine.reanim 的 base / shaft / ball 三条轨）：
## reanim 摆放原点 = 机器坐标 (106,-20)（Challenge.cpp AddReanimation(handleRect.mX-377, mY-20)
## 的口径 + 上述 +10 校准），下面全部是换算到机器坐标后的**中心点**；缩放直接用轨道值（已含 0.6），
## 摆放 / 旋转 / 缩放全部围绕贴图中心（对齐 Reanimator.cpp MatrixFromTransform 的矩阵口径）
const LEVER_BASE_CENTER := Vector2(484.5, 14.3)
const LEVER_BASE_SIZE := Vector2(57, 156)
const LEVER_BASE_SCALE := 0.6
const LEVER_SHAFT_SIZE := Vector2(95, 18)
const LEVER_BALL_SIZE := Vector2(44, 44)
## shaft / ball 的 9 帧关键帧（换算自 reanim 轨道，帧序与轨道一致）：
##   shaft 每帧 = [中心点, 旋转角(=轨道 kx 度, Godot rotation 同口径), 缩放(sx, sy)]
##   ball  每帧 = [中心点, 整体缩放]
## 动画段：anim_pull = 帧 0..5（拉下并带回弹）、anim_return = 帧 4..0（环绕回位）
## 球的待机帧（0 / 8）y 按原版截图再校 +13（原版待机球心 (505,21)、杆上端 (497,38)，
## 球要压住杆端才不会有缝；其余帧保持轨道值，中段本来就与杆相连）
const LEVER_SHAFT_FRAMES: Array = [
	[Vector2(484.3, 63.3), 296.0, Vector2(0.599, 0.599)],
	[Vector2(482.4, 60.3), 317.7, Vector2(0.355, 0.598)],
	[Vector2(484.4, 56.1), 356.0, Vector2(0.263, 0.599)],
	[Vector2(489.4, 53.8), 400.8, Vector2(0.336, 0.598)],
	[Vector2(494.0, 53.4), 422.2, Vector2(0.464, 0.598)],
	[Vector2(489.4, 53.8), 400.8, Vector2(0.336, 0.598)],
	[Vector2(484.4, 56.1), 356.0, Vector2(0.263, 0.599)],
	[Vector2(482.4, 60.3), 317.7, Vector2(0.355, 0.598)],
	[Vector2(484.3, 63.3), 296.0, Vector2(0.599, 0.599)],
]
const LEVER_BALL_FRAMES: Array = [
	[Vector2(496.4, 24.4), 0.6],
	[Vector2(494.9, 26.4), 0.67],
	[Vector2(493.3, 41.6), 0.741],
	[Vector2(497.0, 67.7), 0.643],
	[Vector2(496.4, 81.1), 0.6],
	[Vector2(497.0, 67.7), 0.643],
	[Vector2(493.3, 41.6), 0.741],
	[Vector2(494.9, 26.4), 0.67],
	[Vector2(496.4, 24.4), 0.6],
]
const LEVER_FRAME_COUNT := 9
## 拉杆拉下 / 回弹用时（原版 PlayReanim 速率 36 / 24，定义 fps=12：两段各跨 5 格）
const LEVER_PULL_DURATION := 5.0 / 36.0
const LEVER_RETURN_DURATION := 5.0 / 24.0
## 前 3 次拉杆之前手柄闪烁（Challenge::DrawSlotMachine：待机时整个拉杆 reanim
## 用 GetFlashingColor(mMainCounter, 75) 着色 —— 灰度三角波在 55..255 间脉动
## （PvzpCommon.cpp 969，1 tick = 10ms），滚动 / 奖杯掉落时不着色）
const LEVER_FLASH_ROLL_COUNT := 3
const LEVER_FLASH_TICKS := 75
const LEVER_FLASH_GRAY_MIN := 55.0
const LEVER_FLASH_GRAY_MAX := 255.0
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
## pak/images/seeds.png = 原版 IMAGE_SEEDS 包底图集（50x70 一格），格号口径 =
## SeedPacket.cpp DrawSeedPacket 的 aPacketBackground：2 普通包底 / 5 太阳 / 6 钻石
## （0 模仿者底、1 升级底、3 弹坑、4 刷新、7 潜水、8 奖杯 —— 都不是转轮符号，别拿来当卡面）。
## 植物符号的卡面 = 包底 + 植物立绘，走 AllCards 卡面工厂，见 _make_symbol_face()
const SEEDS_BG_CELL_NORMAL := 2
const SEEDS_BG_CELL_SUN := 5
const SEEDS_BG_CELL_DIAMOND := 6
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
## 六种符号的 50x70 卡面（植物 = AllCards 卡面实例，太阳 / 钻石 = 包底整图）
var _symbol_faces: Array[Control] = []
## 每个转轮的「当前包 / 下一个包」两个槽位容器（滚动 = 移动槽位，裁剪由 Reel 承担）
var _reel_curr_slots: Array[Control] = []
var _reel_next_slots: Array[Control] = []
## 两个槽位当前显示的符号（-1 = 全藏；与滚动状态同步，避免每帧翻可见性）
var _curr_slot_shown: Array[int] = []
var _next_slot_shown: Array[int] = []
var _lever_base: TextureRect
var _lever_shaft: TextureRect
var _lever_ball: TextureRect
## 拉杆动画的当前 tween（拉杆只在静止时能拉，同时只有一段在跑）
var _lever_tween: Tween
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
	## 全屏根节点只当坐标系用：默认 STOP 会把整个屏幕的点击吞掉
	## （菜单按钮、阳光、草坪全点不到，实机悬停探测证实过），改成穿透
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_apply_lever_pose(0.0)
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
## 单个符号的 50x70 卡面（原版转轮 = SeedPacket::Draw 的 DrawSeedPacket：
## 包底 + 植物立绘；太阳 / 钻石是专用整图，不叠立绘）。
## 植物符号直接复用 AllCards 的卡面工厂 —— 与出战卡 / 传送带同一套，
## 不再从 seeds.png 的包底格硬凑（那里根本没有植物立绘，之前寒冰豆错显示成刷新箭头）。
func _make_symbol_face(symbol: int) -> Control:
	if SYMBOL_PLANTS[symbol] == PlantIds.NULL:
		var cell := SEEDS_BG_CELL_SUN if symbol == Symbol.SUN else SEEDS_BG_CELL_DIAMOND
		return _make_ignore_texture_rect("Face%d" % symbol, _make_seeds_cell(cell),
			Vector2(PACKET_SIZE))
	var reference := ResourceCardReference.create(
		ResourceCardReference.CardType.Plant, SYMBOL_PLANTS[symbol])
	var card := AllCards.create_card(reference, Card.CardContext.Catalog)
	if card == null:
		Log.error("拉霸：植物卡面建不出来，植物 = " + str(SYMBOL_PLANTS[symbol]))
		return _make_ignore_texture_rect("Face%d" % symbol,
			_make_seeds_cell(SEEDS_BG_CELL_NORMAL), Vector2(PACKET_SIZE))
	return card


## seeds.png 的某一格 50x70 包底
func _make_seeds_cell(cell: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SEEDS_ATLAS
	atlas.region = Rect2(Vector2(cell * PACKET_SIZE.x, 0), Vector2(PACKET_SIZE))
	return atlas


## 卡面入树后的收尾：拉霸关的种子包不画阳光费用（SeedPacket.cpp aDrawCost = false），
## 也不吃任何点击（原版机器只吃拉杆）
func _configure_face(face: Control) -> void:
	if face is Card:
		(face as Card).cost.visible = false
	_set_mouse_ignore_recursive(face)


func _set_mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)


func _build_ui() -> void:
	for _i in range(REEL_COUNT):
		_curr_symbols.append(0)
		_next_symbols.append(0)
		_scroll_positions.append(0.0)
		_countdowns.append(0)

	_build_sun_bank()
	_build_reels()
	_build_lever()
	_build_overlay()
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


## 三个转轮：每个转轮是「当前包 + 下一个包」两个槽位，滚动时一起位移；
## 裁剪在转轮容器（= 包自身 50x70 矩形，原版 ClipRect 口径），
## 槽位里预放 6 种卡面、按需翻可见性（同一符号可能同时出现在当前 / 下一个槽位）
func _build_reels() -> void:
	for i in range(REEL_COUNT):
		var reel := Control.new()
		reel.name = "Reel%d" % (i + 1)
		reel.position = Vector2(PACKET_START_X + i * PACKET_STEP_X, PACKET_Y)
		reel.size = Vector2(PACKET_SIZE)
		reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reel.clip_contents = true
		add_child(reel)

		for slot_i in range(2):
			var slot := Control.new()
			slot.name = "Curr" if slot_i == 0 else "Next"
			slot.size = Vector2(PACKET_SIZE)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if slot_i == 1:
				slot.position = Vector2(0, PACKET_SIZE.y)
			reel.add_child(slot)
			if slot_i == 0:
				_reel_curr_slots.append(slot)
				_curr_slot_shown.append(-1)
			else:
				_reel_next_slots.append(slot)
				_next_slot_shown.append(-1)
			for symbol in range(SYMBOL_COUNT):
				var face := _make_symbol_face(symbol)
				slot.add_child(face)
				_configure_face(face)
				face.visible = false


## 覆盖层：画在转轮与拉杆之后 = 盖住两者
## （原版 Board::Draw：DrawBackdrop（含拉杆 reanim）先画、种子银行（含覆盖层）后画 —— 拉杆被机器面板挡住）
func _build_overlay() -> void:
	var overlay := _make_ignore_texture_rect("Overlay", OVERLAY_TEXTURE, OVERLAY_SIZE)
	overlay.position = OVERLAY_POS
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(overlay)


## 拉杆三块：底座 / 摆臂 / 球柄（原版是 SlotMachine.reanim：
## 摆臂绕自身中心旋转 kx 度、球柄骑在摆臂上端，拉动时整体摆下一个来回；
## 关键帧见 LEVER_SHAFT_FRAMES / LEVER_BALL_FRAMES）
func _build_lever() -> void:
	_lever_base = _make_lever_part("LeverBase", LEVER_BASE_TEXTURE, LEVER_BASE_SIZE,
		LEVER_BASE_CENTER, LEVER_BASE_SCALE)
	add_child(_lever_base)

	_lever_shaft = _make_lever_part("LeverShaft", LEVER_SHAFT_TEXTURE, LEVER_SHAFT_SIZE,
		LEVER_SHAFT_FRAMES[0][0], 1.0)
	add_child(_lever_shaft)

	_lever_ball = _make_lever_part("LeverBall", LEVER_BALL_TEXTURE, LEVER_BALL_SIZE,
		LEVER_BALL_FRAMES[0][0], 1.0)
	add_child(_lever_ball)
	_apply_lever_pose(0.0)


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


## 拉杆零件：中心点摆位、pivot = 贴图中心（旋转 / 缩放围绕中心，缩放值由关键帧驱动）
func _make_lever_part(node_name: String, texture: Texture2D, part_size: Vector2,
		center: Vector2, part_scale: float) -> TextureRect:
	var part := TextureRect.new()
	part.name = node_name
	part.size = part_size
	part.texture = texture
	part.pivot_offset = part_size * 0.5
	part.scale = Vector2(part_scale, part_scale)
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.position = center - part_size * 0.5
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


## 把三个转轮的当前 / 下一个包画到位（原版 SeedPacket::Draw 的两层堆叠；
## 溢出裁剪由 Reel 容器的 clip_contents 承担）
func _update_reel_visuals() -> void:
	for i in range(REEL_COUNT):
		var offset := -float(PACKET_SIZE.y) * _scroll_positions[i]
		_reel_curr_slots[i].position = Vector2(0, offset)
		_reel_next_slots[i].position = Vector2(0, PACKET_SIZE.y + offset)
		_show_slot_symbol(i, true, _curr_symbols[i])
		if _countdowns[i] > 0:
			_show_slot_symbol(i, false, _next_symbols[i])
		else:
			## 停稳之后不画下一个包（原版 countdown <= 0 时只画当前包）
			_show_slot_symbol(i, false, -1)


## 槽位里显示哪个符号（-1 = 全藏）；与上次相同就跳过，不在滚动时每帧翻可见性
func _show_slot_symbol(reel_index: int, is_curr_slot: bool, symbol: int) -> void:
	var shown: int = _curr_slot_shown[reel_index] if is_curr_slot else _next_slot_shown[reel_index]
	if shown == symbol:
		return
	var slot: Control = _reel_curr_slots[reel_index] if is_curr_slot else _reel_next_slots[reel_index]
	for symbol_i in range(SYMBOL_COUNT):
		slot.get_child(symbol_i).visible = symbol_i == symbol
	if is_curr_slot:
		_curr_slot_shown[reel_index] = symbol
	else:
		_next_slot_shown[reel_index] = symbol


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
## 摆到关键帧位置 frame_pos（0..8，小数 = 两帧间线性插值；回弹段经帧 8 环绕回 0）
func _apply_lever_pose(frame_pos: float) -> void:
	var f0 := clampi(int(floor(frame_pos)), 0, LEVER_FRAME_COUNT - 1)
	var frac := clampf(frame_pos - float(f0), 0.0, 1.0)
	var f1 := (f0 + 1) % LEVER_FRAME_COUNT
	var shaft_a: Array = LEVER_SHAFT_FRAMES[f0]
	var shaft_b: Array = LEVER_SHAFT_FRAMES[f1]
	_lever_shaft.position = (shaft_a[0] as Vector2).lerp(shaft_b[0], frac) - LEVER_SHAFT_SIZE * 0.5
	_lever_shaft.rotation_degrees = lerpf(shaft_a[1], shaft_b[1], frac)
	_lever_shaft.scale = (shaft_a[2] as Vector2).lerp(shaft_b[2], frac)
	var ball_a: Array = LEVER_BALL_FRAMES[f0]
	var ball_b: Array = LEVER_BALL_FRAMES[f1]
	_lever_ball.position = (ball_a[0] as Vector2).lerp(ball_b[0], frac) - LEVER_BALL_SIZE * 0.5
	_lever_ball.scale = Vector2.ONE * lerpf(ball_a[1], ball_b[1], frac)


## 拉杆拉下（原版 PlayReanim("anim_pull", ONCE_AND_HOLD, 0, 36) = 帧 0..5）
func _play_lever_pull() -> void:
	_run_lever_tween(_lever_pull_step, LEVER_PULL_DURATION)


func _lever_pull_step(progress: float) -> void:
	_apply_lever_pose(progress * 5.0)


## 拉杆回弹（原版 PlayReanim("anim_return", ONCE_AND_HOLD, 0, 24) = 帧 4..0 环绕）
func _play_lever_return() -> void:
	_run_lever_tween(_lever_return_step, LEVER_RETURN_DURATION)


func _lever_return_step(progress: float) -> void:
	_apply_lever_pose(4.0 + progress * 5.0)


func _run_lever_tween(step: Callable, duration: float) -> void:
	if _lever_tween != null and _lever_tween.is_valid():
		_lever_tween.kill()
	_lever_tween = create_tween()
	_lever_tween.tween_method(step, 0.0, 1.0, duration)


## 前 3 次拉杆之前手柄闪烁（原版 Challenge::DrawSlotMachine：
## 待机时整个拉杆 reanim 用 GetFlashingColor(mMainCounter, 75) 着色，
## 灰度三角波 55..255（PvzpCommon.cpp 969，1 tick = 10ms）；滚动 / 奖杯时不着色）
func _update_lever_flash() -> void:
	var should_flash: bool = _roll_count < LEVER_FLASH_ROLL_COUNT \
		and not _is_spinning and not _has_won
	if not should_flash:
		_set_lever_modulate(Color.WHITE)
		return
	@warning_ignore("integer_division")
	var age := (Time.get_ticks_msec() / 10) % LEVER_FLASH_TICKS
	var half := LEVER_FLASH_TICKS / 2.0
	var gray := clampf(LEVER_FLASH_GRAY_MIN \
		+ (LEVER_FLASH_GRAY_MAX - LEVER_FLASH_GRAY_MIN) * absf(half - age) / half,
		0.0, 255.0) / 255.0
	_set_lever_modulate(Color(gray, gray, gray))


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
