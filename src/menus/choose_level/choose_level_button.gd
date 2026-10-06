extends TextureRect
class_name ChooseLevelButton

@onready var texture_button: TextureButton = $TextureButton
@onready var success: TextureRect = $success
@onready var round_num: Label = $RoundNum
@onready var lock: TextureRect = $Lock
@onready var preview_icon_node: TextureRect = $PreviewIcon


## 预览图标: 从 Challenge_Thumbnails 图集裁出, 显示在窗框下 (留空则不显示)
@export var preview_icon: Texture2D


## 关卡脚本（.gd）：一个关卡 = 一个脚本（属性 + 流程），见 LevelScriptBase
@export var level_script: Script
## 当前关卡游戏参数：由 level_script.new() 得到（_ready 里做）
## 老的 .tres 关卡仍可直接挂在这里，两条路并存到迁移结束
var curr_level_data_game_para :ResourceLevelData


## 选关按钮信号信号
signal signal_choose_level_button(choose_level_button:ChooseLevelButton)


func _ready() -> void:
	if curr_level_data_game_para == null and level_script != null:
		curr_level_data_game_para = level_script.new() as ResourceLevelData
	if curr_level_data_game_para != null:
		texture_button.pressed.connect(_on_pressed)
		set_mouse_filter_recursive(self, Control.MOUSE_FILTER_IGNORE)
		texture_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		texture_button.visible= false
		success.visible= false
		round_num.visible= false
	_apply_preview_icon()


## 有自定义预览面板(Panel)时图标会被盖住, 不影响
func _apply_preview_icon() -> void:
	preview_icon_node.visible = preview_icon != null
	preview_icon_node.texture = preview_icon

func set_mouse_filter_recursive(root: Node, filter_value: int) -> void:
	# root 是你想从这个节点开始，递归设置 mouse_filter 的根节点
	for child in root.get_children():
		# 递归先对子节点做
		set_mouse_filter_recursive(child, filter_value)
		# 如果是 Control 类型，就设置 mouse_filter
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_pressed() -> void:
	signal_choose_level_button.emit(self)

## 更新当前关卡状态 (已通关, 多轮关卡轮数)
func update_curr_level_button_state(curr_level_state_data:Dictionary):
	success.visible = curr_level_state_data.get("IsSuccess", false)
	round_num.visible = curr_level_state_data.get("IsHaveMultiRoundSaveGameData", false)
	round_num.text = str(int(curr_level_state_data.get("CurrGameRound", 1))) + "轮"

## 锁住当前关卡选择按钮
func lock_choose_level_button():
	lock.visible = true
	texture_button.disabled = true
	modulate = Color(0.687, 0.687, 0.687, 1.0)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
