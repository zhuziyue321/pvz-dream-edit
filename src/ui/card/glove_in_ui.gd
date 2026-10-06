extends TextureRect
class_name UIGlove
## 卡槽里的手套
## 本体是卡槽背景（与铲子同款底板），$Glove 才是可以被「拿走」的手套图标。
## 显隐规则统一由 HandComponentGlove 决定，本节点只负责按规则刷新，不自己改状态。

@onready var glove_icon: TextureRect = $Glove


## 鼠标点击手套：交给手持物组件处理（拿到手上）
func _on_button_pressed() -> void:
	EventBus.push_event("main_game_click_glove")


## 刷新增手套界面
## is_slot_visible：整个手套卡槽（背景 + 按钮）是否显示
## is_icon_visible：手套图标是否显示（手套被拿到手上时只留背景）
func refresh_glove_ui(is_slot_visible: bool, is_icon_visible: bool) -> void:
	visible = is_slot_visible
	glove_icon.visible = is_icon_visible
