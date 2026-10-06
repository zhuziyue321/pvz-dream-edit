extends ResourceLevelTimelineEvent
class_name LevelTimelineEventHint
## 提示快捷工具：在屏幕下方显示一段文本
##
## **不依赖任何管理器**：任何关卡都能用（没有教程管理器也照样出提示条），
## 提示条按名字挂在 CanvasLayerUI 下，与「箭头快捷工具」共用同一个实例
## （见 TutorialAdviceUI.ensure_level_hint）。
##
## 传空串 = **关掉提示条**（只收文本；箭头归箭头工具管，想一起收起就再调一次 hide_arrow()）。

## 提示文本；留空表示关掉提示条
@export_multiline var text: String = ""


func run(main_game: MainGameManager) -> void:
	var hint := TutorialAdviceUI.ensure_level_hint(main_game)
	if hint == null:
		return
	if text.is_empty():
		hint.hide_advice()
		return
	hint.show_advice(text)
