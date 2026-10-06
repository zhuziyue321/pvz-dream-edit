extends TextureRect
class_name UIShovel
## 卡槽里的铲子
## 本体是卡槽背景（ShovelBank），$Shovel 才是可以被「拿走」的那把铲子图标。
## 显隐规则统一由 HandComponentShovel 决定，本节点只负责按规则刷新，不自己改状态。

@onready var shovel_icon: TextureRect = $Shovel


## 鼠标点击铲子：交给手持物组件处理（拿到手上）
func _on_button_pressed() -> void:
	EventBus.push_event("main_game_click_shovel")


## 刷新增铲子界面
## is_slot_visible：整个铲子卡槽（背景 + 按钮）是否显示
## is_icon_visible：铲子图标是否显示（铲子被拿到手上时只留背景）
func refresh_shovel_ui(is_slot_visible: bool, is_icon_visible: bool) -> void:
	visible = is_slot_visible
	shovel_icon.visible = is_icon_visible
