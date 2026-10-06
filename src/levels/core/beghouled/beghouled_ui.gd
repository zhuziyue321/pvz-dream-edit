extends Control
class_name BeghouledUI
## 僵尸迷阵（Beghouled）的玩法界面
##
## 只剩文字：顶部一行「已完成配对数 / 通关需要的总数」
## （原版 ADSCORE 口径「完成 N 次配对以完成关卡」）。
## 提示语（比如死局后自动重排那句）不走这里 —— 全项目只有一条提示条，
## 就是屏幕下方那条教程提示条（TutorialAdviceUI，见 BeghouledManager._ensure_board_playable）。
##
## **玩家能按的东西都在出战卡槽里**（三档升级 + 刷新盘面 + 填坑，见
## `minigame_05_beghouled.gd` 的 `_create_seed_packets()`）：
## 这块界面原来还有一排底部按钮（升级 / 重置 / 填坑），已全部移除 —— 同一种操作不该有两个入口。
##
## **节点在脚本里建，不做 .tscn**：这一块没有美术资源（就是两行文字），
## 做成场景文件反而要跟着维护一份没有内容的 .tscn。主题沿用主界面主题 pvz_theme。
##
## 谁在用它：BeghouledManager._create_ui()（挂在 MainGameManager 的 CanvasLayerUI 下）

const UI_THEME_PATH := "res://data/ui/themes/pvz_theme.tres"

var progress_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := load(UI_THEME_PATH) as Theme
	if ui_theme != null:
		theme = ui_theme
	_build_progress_label()


func _build_progress_label() -> void:
	progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	progress_label.offset_left = -120.0
	progress_label.offset_top = 6.0
	progress_label.offset_right = 120.0
	progress_label.offset_bottom = 36.0
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 18)
	add_child(progress_label)


## 刷新进度（消除 / 结算收尾后由 BeghouledManager 调用）
func refresh_view(match_num: int) -> void:
	if progress_label != null:
		progress_label.text = "配对 %d / %d" % [match_num, ConstBeghouled.TARGET_MATCH_NUM]
