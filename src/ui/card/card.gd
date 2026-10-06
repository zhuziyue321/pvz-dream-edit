extends CardBase
class_name Card

@onready var character_static: Node2D = $CardBg/CharacterStatic
@onready var short_cut: Label = $ShortCut
@onready var button: Button = $Button

## 是否为图鉴卡片
var is_almanac_card:bool= false

var _is_cooling : bool = false		# 是否正在冷却
var is_sun_enough: bool = true		# 阳光是否足够
var _cool_timer : float				# 冷却计时器
var is_can_click := true		## 是否可以点击
var tween_blink:Tween
#region 开局选卡相关
## 开局选择卡片时 是否被选中
var is_choosed_pre_card := false
var card_candidate_container:CardCandidateContainer
#endregion
## 模仿者材质
const IMITATER = preload("res://shaders/materials/imitater.tres")

## 卡片点击用途,由创建方在入树前指定
enum CardContext {
	Catalog,	## 源目录用途,不处理点击
	Selection,	## 选卡或取消选择
	Battle,		## 出战卡槽,交给手持管理器
	Almanac,	## 图鉴,点击打开详情
	Custom,		## 关卡自定义种子包,点击交给 custom_click 回调
}
## 当前点击用途;默认 Catalog
var card_context: CardContext = CardContext.Catalog

## 关卡自定义种子包的点击回调（仅 CardContext.Custom 生效，
## 由 LevelScriptBase.create_custom_seed_packet() 写入）。
## 回调收到本卡自己（card:Card）：扣不扣阳光、冷不冷却、要不要置灰都由回调决定，
## 本体不认识任何具体玩法（硬约束 §1-8），只负责「点到就把这张卡交给回调」。
var custom_click: Callable
## 是否已永久停用（一次性卡「买过一次」这类）：置灰且不再响应点击。
## 与冷却的区别是阳光变化 / 新一轮刷新都不会把它重新点亮（见 judge_card_ready）。
var is_disabled_forever := false
## 是否被关卡脚本封住（比如「现在没有弹坑可填」这类**条件不满足**）：
## 与 is_disabled_forever 的区别是它**可以解开**，见 set_card_blocked()
var is_blocked := false

## 点击信号,选卡时使用该信号(种植点击使用时间总线)
signal signal_card_click(card:Card)
## 卡片种植完成后信号，生成卡片所在卡槽连接该信号
@warning_ignore("unused_signal")
signal signal_card_use_end(card:Card)

func _ready() -> void:
	super()
	_cool_mask.value = 0
	if is_imitater:
		character_static.material = IMITATER.duplicate()
		for child in character_static.get_children():
			GlobalUtils.node_use_parent_material(child)

## 设置卡片为图鉴卡片
func set_almanac_card():
	is_almanac_card = true
	card_context = CardContext.Almanac

## 改变卡片的冷却时间（测试时使用）
func card_change_cool_time(new_cool_time:float):
	self.cool_time = new_cool_time
	_cool_mask.value = 0

## 设置卡片冷却时间并开始冷却
func set_card_cool_time_start_cool(new_cool_time:float):
	self.cool_time = new_cool_time
	_cool_mask.value = cool_time
	card_cool()

## 设置卡片禁用(不冷却)
func set_card_disable():
	self.cool_time = 1
	_cool_mask.value = cool_time
	_is_cooling = false
	_cool_mask.visible = true
	is_can_click = false

## 传送带卡槽初始化卡片
func card_init_conveyor_belt():
	_cool_mask.value = 0
	sun_cost = 0


## 卡片冷卻
func _process(delta: float) -> void:
	if _is_cooling:
		_cool_timer -= delta
		_cool_mask.value = _cool_timer
		# 卡片冷却完成
		if _cool_timer <= 0:
			_is_cooling = false
			judge_card_ready()

## 修改阳光时会调用
func judge_sun_enough(curr_sun_value):
	# 判断阳光是否足够
	is_sun_enough = curr_sun_value >= sun_cost
	judge_card_ready()

## 判断卡片是否可以点击
func judge_card_ready():
	## 永久停用的卡（一次性卡买过一次）永远点不动
	if is_disabled_forever:
		card_not_can_click()
		return
	## 被关卡脚本封住的卡：条件还没满足（比如没有弹坑可填），等 set_card_blocked(false) 解开
	if is_blocked:
		card_not_can_click()
		return
	# 阳光充足 且 卡片冷却完成
	if is_sun_enough and not _is_cooling:
		## 紫卡并且不能种植
		if is_purple_card and not plant_condition.judge_purple_card_can_plant(Global.main_game.plant_cell_manager.all_plant_cells, card_plant_type):
			card_not_can_click()
		else:
			card_ready()
	else:
		card_not_can_click()

func set_card_cool_end():
	_cool_timer = 0
	_cool_mask.value = _cool_timer
	_is_cooling = false

## 卡片可以点击
func card_ready():
	_cool_mask.visible = false
	is_can_click = true

## 卡片不可以点击
func card_not_can_click():
	_cool_mask.visible = true
	is_can_click = false

## 永久停用本卡（一次性种子包买过一次就置灰）：
## 与 set_card_disable() 的区别是阳光变化 / 新一轮刷新都不会把它重新点亮
func set_card_disabled_forever() -> void:
	is_disabled_forever = true
	## 冷却遮罩拉满（画满 = 整张卡压暗）；本卡 cool_time 可能是 0，那时遮罩的 max 也是 0，
	## 画出来是空的、看着还像能点，这里按至少 1 秒算满
	_cool_mask.max_value = maxf(cool_time, 1.0)
	_cool_mask.value = _cool_mask.max_value
	card_not_can_click()

## 封住 / 解开本卡（关卡脚本说「现在条件不满足」时用，比如盘面上没有弹坑可填）：
## 与 set_card_disable() 的区别是**冲不掉** —— 阳光变化走 judge_card_ready() 时会单独判这一道
func set_card_blocked(blocked: bool) -> void:
	is_blocked = blocked
	judge_card_ready()

## 卡片开始冷却
func card_cool():
	_is_cooling = true
	_cool_mask.visible = true
	_cool_timer = cool_time
	_cool_mask.value = cool_time
	is_can_click = false

## 点击卡片时
func _on_button_pressed() -> void:
	## 如果为图鉴卡片
	if is_almanac_card:
		signal_card_click.emit()
		return

	## 如果时主游戏场景,并且游戏中
	var is_main_game: bool = is_instance_valid(Global.main_game) \
		and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME
	## 关卡自定义种子包：不交给手持管理器，点击行为由关卡脚本给的回调决定（本体不做玩法判断）
	if card_context == CardContext.Custom:
		if not is_main_game:
			return
		if not is_can_click:
			SoundManager.play_other_SFX("buzzer")
			return
		if custom_click.is_valid():
			custom_click.call(self)
		return

	if is_main_game:
		## 可以点击
		if is_can_click:
			EventBus.push_event("main_game_click_card", [self])
		else:
			SoundManager.play_other_SFX("buzzer")
	else:
		signal_card_click.emit()

## 快捷键设置
func set_shortcut(i:int):
	short_cut.text = str(i)
	short_cut.visible = true

func set_shortcut_disappear():
	short_cut.visible = false

#region 卡片闪烁
## 开始
func card_blink_start():
	# 如果已存在 tween，就先 kill 掉
	if tween_blink and tween_blink.is_valid():
		tween_blink.kill()
	tween_blink = create_tween()
	# 无限循环
	tween_blink.set_loops()  # 不传参数就是无限循环 :contentReference[oaicite:0]{index=0}

	# 淡出（透明度变为 0）
	tween_blink.tween_property(card_bg, "modulate:a", 0.5, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 淡入（透明度变为 1）
	tween_blink.tween_property(card_bg, "modulate:a", 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
#endregion

#region 鼠标检测
func mouse_filter_start():
	button.mouse_filter = Control.MOUSE_FILTER_PASS

func mouse_filter_stop():
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE

#endregion
