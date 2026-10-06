extends Control
class_name TutorialAdviceUI
## 提示条（屏幕下方的横幅文字 + 指向目标的箭头）
##
## 只负责「显示什么、指哪里」：谁在什么时候显示、指哪、等多久，全由关卡流程（事件）决定，
## 本节点挂在 CanvasLayerUI 下（层 50），不受主游戏场景的鼠标拦截影响。
##
## 提示条**固定在屏幕底部**（tscn 里 Bottom Wide 锚点 + 底部外边距），高度按文本行数算：
## 教学台词、一次性提示、关卡的两个快捷工具一律走这一条屏幕下方的提示，
## 不再有飘在草坪上的小框。所以没有「指定位置」的接口 —— 位置由锚点决定，改样式请改 tscn。
##
## 关卡的两个快捷工具都在用本节点：
##   · **提示快捷工具**（LevelTimelineEventHint）：显示 / 关掉一段文本
##   · **箭头快捷工具**（LevelTimelineEventArrow）：箭头指向某样东西并跟着它走
## 两者共用一个实例（按名字挂在 CanvasLayerUI 下，见 ensure_level_hint）；
## 一次性提示（第一次掉落金币那条）也挂一个自己的实例。

## 关卡「提示 / 箭头」两个快捷工具共用的提示条节点名
const LEVEL_HINT_NODE_NAME := "LevelHintUI"

@onready var advice_panel: Control = $AdvicePanel
@onready var advice_label: Label = $AdvicePanel/MarginContainer/AdviceLabel
@onready var pointer: TutorialPointer = $Pointer

## 提示文本变化（调试通道 / 自动测试跟踪「说到哪一句」用；空串 = 收起提示）
signal signal_advice_changed(text: String)

## 一次性提示模式下箭头要跟随的节点（例如第一次掉出来的金币）
var _once_target: Node2D
## 当前显示的文本（Label 拿到布局宽度后要按它重算一次高度）
var _curr_text := ""
## 箭头快捷工具：每帧要重新解析的目标（None = 没有在指东西）
var _follow_target: PointerTargetResolver.E_PointerTarget = PointerTargetResolver.E_PointerTarget.None
## 箭头快捷工具：目标对应的植物类型（Card / Lawn 两个目标用得上）
var _follow_plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null
## 箭头快捷工具：解析目标要用的主游戏（目标可能是阳光 / 卡片 / 草坪格子）
var _follow_main_game: MainGameManager

## 提示条最小高度（单行短提示够用）
const ADVICE_PANEL_MIN_HEIGHT := 64.0
## 面板上下 content_margin 之和（tscn 里各 10）
const ADVICE_PANEL_MARGIN_Y := 20.0
## 面板左右 content_margin 之和（tscn 里各 14）
const ADVICE_PANEL_MARGIN_X := 28.0
## 提示条左右各留的边距（与 tscn 的 offset_left / offset_right 一致）
const ADVICE_PANEL_SIDE_MARGIN := 24.0
## Label 还没拿到布局宽度时（节点刚 add_child、还没跑过一次布局）用它兜底：
## 800 设计分辨率下 屏幕宽 - 左右边距共 48 - content_margin 28
const ADVICE_LABEL_FALLBACK_WIDTH := 724.0


## 显示提示文本（箭头由 update_pointer / hide_pointer 单独控制）
func show_advice(text: String) -> void:
	_curr_text = text
	advice_label.text = text
	advice_panel.visible = true
	_ensure_label_width()
	_refresh_advice_height()
	signal_advice_changed.emit(text)


#region 关卡快捷工具：提示条与箭头的取用
## 关卡「提示 / 箭头」两个快捷工具用的提示条：挂在 CanvasLayerUI 下，**已经建了就直接拿**
## （两个工具共用一个实例，否则一次提示会挂出两条提示条）
static func find_level_hint(main_game: MainGameManager) -> TutorialAdviceUI:
	if main_game == null or not is_instance_valid(main_game):
		return null
	if main_game.canvas_layer_ui == null:
		return null
	return main_game.canvas_layer_ui.get_node_or_null(LEVEL_HINT_NODE_NAME) as TutorialAdviceUI


## 同上，但**没有就当场建一个**（提示条属于界面层，挂在主游戏 CanvasLayerUI 下，层号 50）
static func ensure_level_hint(main_game: MainGameManager) -> TutorialAdviceUI:
	var hint := find_level_hint(main_game)
	if hint != null and is_instance_valid(hint):
		return hint
	if main_game == null or not is_instance_valid(main_game) or main_game.canvas_layer_ui == null:
		return null
	hint = SceneRegistry.TUTORIAL_ADVICE.instantiate()
	hint.name = LEVEL_HINT_NODE_NAME
	main_game.canvas_layer_ui.add_child(hint)
	return hint
#endregion


#region 关卡快捷工具：箭头跟随目标
## 箭头指到 target 那类东西上，并**每帧跟着它走**（阳光会飘、卡片会位移）
## target 传 None = 收起箭头（见 hide_arrow）
func point_to_level_target(main_game: MainGameManager,
		target: PointerTargetResolver.E_PointerTarget,
		plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	_follow_main_game = main_game
	_follow_target = target
	_follow_plant_type = plant_type
	if target == PointerTargetResolver.E_PointerTarget.None:
		hide_arrow()
		return
	set_process(true)
	_update_follow_pointer()


## 收起箭头（玩家该用的东西已经在手上时不该再指）
## **必须同时停掉按帧处理**：否则下一帧的 _process 又会把箭头按原目标点亮回来
func hide_arrow() -> void:
	_follow_target = PointerTargetResolver.E_PointerTarget.None
	set_process(false)
	hide_pointer()


func _update_follow_pointer() -> void:
	if _follow_target == PointerTargetResolver.E_PointerTarget.None:
		return
	## 关卡中途被销毁（玩家退回主菜单）：主游戏一释放，解析目标就是访问已释放对象
	if not is_instance_valid(_follow_main_game):
		_follow_target = PointerTargetResolver.E_PointerTarget.None
		set_process(false)
		hide_pointer()
		return
	var target_pos: Variant = PointerTargetResolver.resolve(
		_follow_main_game, _follow_target, _follow_plant_type, self)
	if target_pos == null:
		## 目标还没出现（例如阳光还没掉下来）：先收起来，下一帧再问一次
		hide_pointer()
		return
	update_pointer(target_pos)
#endregion


func _ready() -> void:
	## 布局还没跑过时 Label 的宽度是 1px，minimum_size 会按「一个字一行」把提示条撑到几千高。
	## 这里先把宽度钉上，容器随后会给出同样的值
	_ensure_label_width()
	## Label 拿到真实宽度后会 resized：再按实际行数定一次高度
	advice_label.resized.connect(_refresh_advice_height)


## Label 尺寸变化（= 拿到可用宽度）后按实际行数重定一次高度
func _refresh_advice_height() -> void:
	if _curr_text.is_empty() or not is_instance_valid(advice_panel):
		return
	var height := maxf(ADVICE_PANEL_MIN_HEIGHT, _measure_advice_height(_curr_text))
	## 锚点在底部：**改上端偏移**就等于「贴着底部往上长」。
	## 不要直接写 `advice_panel.size.y`：锚点布局下一布局就被 offsets 覆盖回去
	advice_panel.offset_top = advice_panel.offset_bottom - height


## Label 的可用宽度：提示条宽 - 左右 content_margin
##
## **不要**读 `advice_label.size.x`：容器还没给它分配宽度时它是 **1px**（不是 0），
## 拿 1px 去算折行 / 让 Godot 算 minimum_size，一句 12 字的提示会算出几千高的条。
func _advice_label_width() -> float:
	var width := advice_panel.size.x - ADVICE_PANEL_MARGIN_X
	if width <= 0.0:
		width = maxf(0.0, get_viewport_rect().size.x - ADVICE_PANEL_SIDE_MARGIN * 2.0) - ADVICE_PANEL_MARGIN_X
	if width <= 0.0:
		width = ADVICE_LABEL_FALLBACK_WIDTH
	return width


## Label 必须知道自己多宽：Godot 会把 Control 的 size 钳到不小于 minimum_size，
## 而 minimum_size 是按 Label 的可用宽度折行算出来的
func _ensure_label_width() -> void:
	var width := _advice_label_width()
	if advice_label.size.x < width:
		advice_label.size.x = width


## 按「显式 \n + 可用宽度内的自动折行」估文本高度
##
## **不要**直接问 `advice_panel.get_minimum_size()`：Label 还没拿到布局宽度时会按
## 「一个字一行」算 —— 一句 12 字的提示能算出 300 多高（第一次显示必踩）。
func _measure_advice_height(text: String) -> float:
	var font := advice_label.get_theme_font("font")
	var font_size := advice_label.get_theme_font_size("font_size")
	if font == null:
		return ADVICE_PANEL_MIN_HEIGHT
	var width := _advice_label_width()
	var line_height := font.get_height(font_size)
	var lines := 0
	for line in text.split("\n"):
		lines += maxi(1, ceili(font.get_string_size(line, font_size).x / width))
	return lines * line_height + ADVICE_PANEL_MARGIN_Y


## 一次性提示：显示 text，箭头跟着 target 节点走，show_time 秒后自动隐藏并释放自身
## 用于「全局只提示一次」的场合（第一次掉落金币）；
## 教学那种「一句话一个等待」的场合不用它，走「提示 / 箭头」两个快捷工具
func show_advice_once(text: String, target: Node2D, show_time: float) -> void:
	show_advice(text)
	_once_target = target
	set_process(true)
	_update_once_pointer()
	await get_tree().create_timer(show_time, false).timeout
	## 等待期间节点可能已经被场景切换带走
	if not is_instance_valid(self):
		return
	_once_target = null
	set_process(false)
	hide_advice()
	queue_free()


## 每帧刷新箭头：一次性提示（跟着金币走）与关卡箭头快捷工具（跟着目标走）共用这一个入口
func _process(_delta: float) -> void:
	## 一次性提示优先：目标没了就收一次箭头并停掉按帧处理。
	## 关卡箭头那条路每帧由 _update_follow_pointer 喂 update_pointer，这里要是也去碰
	## hide_pointer，就会每帧把刚点亮的箭头按回去 —— 症状是「箭头刚点出来又被收起」。
	if is_instance_valid(_once_target):
		_update_once_pointer()
		return
	## 关卡箭头快捷工具：指着的那一刻起每帧重解析，目标移动 / 稍后才出现都能跟上
	if _follow_target != PointerTargetResolver.E_PointerTarget.None:
		_update_follow_pointer()
		return
	hide_pointer()
	set_process(false)


func _update_once_pointer() -> void:
	if not is_instance_valid(_once_target):
		hide_pointer()
		return
	update_pointer(_once_target.get_global_transform_with_canvas().origin)


## 隐藏提示条（关卡「提示快捷工具」传空串时走这里）
## **只收文本，不动箭头**：箭头归「箭头快捷工具」管，想一起收起就再调一次 hide_arrow()。
## 一并清空文本：get_advice_text() 是「当前有没有在提示」的判定依据，藏着旧文本会误判
func hide_advice() -> void:
	_curr_text = ""
	advice_label.text = ""
	advice_panel.visible = false
	signal_advice_changed.emit("")


## 更新箭头：指向画布坐标 target_canvas_pos；箭尾朝向底部的提示条
func update_pointer(target_canvas_pos: Vector2) -> void:
	pointer.point_to(target_canvas_pos, get_advice_box_center())


## 隐藏箭头（该步骤没有指向目标，或目标暂时不存在：例如场上还没有阳光）
func hide_pointer() -> void:
	pointer.visible = false


## 提示条在画布上的中心点（箭头从这里出发）
##
## 走画布变换而不是 `position + size * 0.5`：提示条是锚点布局，
## position 落在锚点上（`Vector2.ZERO` 那一侧），跟屏幕上的真实位置不是一回事
func get_advice_box_center() -> Vector2:
	return advice_panel.get_global_transform_with_canvas() * (advice_panel.size * 0.5)


## 当前提示文本（调试 / 自动测试取用）
func get_advice_text() -> String:
	return advice_label.text


## 提示条当前是否可见（调试 / 自动测试取用）
func is_advice_visible() -> bool:
	return advice_panel.visible


## 箭头当前是否可见（调试 / 自动测试取用）
func is_pointer_visible() -> bool:
	return pointer.visible


## 提示面板当前尺寸（调试 / 自动测试取用：多行长提示会不会把提示条撑爆）
func get_advice_panel_size() -> Vector2:
	return advice_panel.size
