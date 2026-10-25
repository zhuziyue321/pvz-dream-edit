extends PanelContainer
## 僵尸侧的**银行视图**（纯外观，不存卡）：右上的反转种子银行
##
## ⚠️ 对战的「12 槽合一」之后，卡与冷却都存在本体那张**出战卡槽**里
## （前 6 格植物 / 后 6 格僵尸与僵王，分块规则见 `card_slot_battle.gd` 的
## `card_type_blocks`）。本节点只剩三件事：
##
##   1. 底图换成 PVZ2 的 `ZombieSeedBank` 并**水平翻转**（StyleBoxTexture 翻不动，
##      运行期把 Image 翻了再包成 ImageTexture），脑子图标与计数区翻到**右面**；
##   2. 当**占位格 6~11 的宿主**：接线把那 6 个占位格从本体卡槽挪进
##      `CardUiList`（卡仍挂在占位格里，选卡 / 冷却 / 点卡全走本体那套）；
##   3. 出场 / 收场 0.2s 平移 —— **出场是跟拍**（盯着本体待选区，它开始上滑
##      就跟着滑；进度事件在主游戏 `_ready` 一进来就发过了，挂上去会「出早了」），
##      收场仍走进度事件（与本体待选区滑出同一拍）。
##
## 脑子计数由接线喂（`set_brains`）—— 分池：收的阳光只进左边植物那半，
## 僵尸卡花的是脑子（起始 150，见 `zombie_card_settings.gd`）。

## 底图九宫格边距：翻转后左边只剩素边（原版右端 12），右边整块是脑区（原版左端 78）
const BANK_MARGIN_LEFT := 12.0
const BANK_MARGIN_TOP := 10.0
const BANK_MARGIN_RIGHT := 78.0
const BANK_MARGIN_BOTTOM := 10.0

## 出场 / 收场（照本体 `CardSlotNorm.move_card_slot_battle` 的 0.2s 平移）
const APPEAR_TIME := 0.2
## 收场停靠位：屏幕上方外（本体那张卡槽的初始 offset_top 就是 -100）
const HIDE_OFFSET_Y := -100.0
## 本体待选区的隐藏停靠位是 y=600（offset_top），离开它 = 选卡界面开始滑入
const CHOOSE_UI_TRIGGER_Y := 595.0

## 进行中的平移动画（新动画来了先杀旧的，避免两个 tween 抢 position）
var _move_tween: Tween = null

@onready var card_ui_list: HBoxContainer = $CardUiList
@onready var curr_brains_value: Label = $SunLabelControl/CurrSunValue
## 脑光的收集落点：脑子计数正上方（与植物卡槽的 `Marker2DSunTarget` 同一套口径 ——
## 植物阳光飞它自己的计数器，脑光飞这里的脑子计数器；换算公式见接线 `get_brain_fly_target()`）
@onready var marker_2d_brain_target: Marker2D = %Marker2DBrainTarget


func _ready() -> void:
	EventBus.subscribe(ConstEventName.MAIN_GAME_PROGRESS_UPDATE, _on_main_game_progress_update)
	## 跳过选卡的局（无选卡界面 / 系统预选）：进场直接就位；选卡局等跟拍
	match _curr_progress():
		MainGameManager.E_MainGameProgress.PREPARE, MainGameManager.E_MainGameProgress.MAIN_GAME:
			position.y = 0.0
		_:
			pass


## 喂脑子计数（分池：僵尸卡花的是这笔，由接线管账）
func set_brains(value: int) -> void:
	curr_brains_value.text = str(value)


## 底图：PVZ2 的 `ZombieSeedBank` 水平翻转后做九宫格 —— 脑区（原在左端）翻到右端
func set_bank_texture(bank_tex: Texture2D) -> void:
	if bank_tex == null:
		return
	var image := bank_tex.get_image()
	if image.is_compressed():
		image.decompress()
	image.flip_x()
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.texture_margin_left = BANK_MARGIN_LEFT
	style.texture_margin_top = BANK_MARGIN_TOP
	style.texture_margin_right = BANK_MARGIN_RIGHT
	style.texture_margin_bottom = BANK_MARGIN_BOTTOM
	add_theme_stylebox_override("panel", style)


#region 出场 / 收场（与本体待选区同一套：选卡界面滑入时跟拍，选卡收尾后滑出）
## 跟拍本体待选区：它开始向上滑（y 离开 600 的隐藏位）就跟着滑入
func _process(_delta: float) -> void:
	var candidate := _find_candidate()
	if candidate == null:
		return
	if candidate.position.y < CHOOSE_UI_TRIGGER_Y:
		set_process(false)
		if _is_shown_progress(_curr_progress()):
			_slide_to(0.0)


func _find_candidate() -> Control:
	var main_game = GameContext.curr_main_game
	if not is_instance_valid(main_game) or main_game.card_manager == null:
		return null
	var card_slot_norm = main_game.card_manager.card_slot_norm
	return card_slot_norm.card_slot_candidate if card_slot_norm != null else null


func _curr_progress() -> MainGameManager.E_MainGameProgress:
	var main_game = GameContext.curr_main_game
	return main_game.main_game_progress if is_instance_valid(main_game) \
		else MainGameManager.E_MainGameProgress.NONE


func _on_main_game_progress_update(main_game_progress: MainGameManager.E_MainGameProgress) -> void:
	_slide_to(0.0 if _is_shown_progress(main_game_progress) else HIDE_OFFSET_Y)


## 哪些阶段要在场（照植物出战卡槽的口径：选卡阶段就滑进来，一直停到本局结束）
func _is_shown_progress(main_game_progress: MainGameManager.E_MainGameProgress) -> bool:
	match main_game_progress:
		MainGameManager.E_MainGameProgress.CHOOSE_CARD, \
		MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD, \
		MainGameManager.E_MainGameProgress.PREPARE, \
		MainGameManager.E_MainGameProgress.MAIN_GAME:
			return true
		_:
			return false


func _slide_to(target_y: float) -> void:
	if is_equal_approx(position.y, target_y):
		return
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:y", target_y, APPEAR_TIME)
#endregion
