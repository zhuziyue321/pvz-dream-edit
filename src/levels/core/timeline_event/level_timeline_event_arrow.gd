extends ResourceLevelTimelineEvent
class_name LevelTimelineEventArrow
## 箭头快捷工具：让箭头指向某样东西，并**每帧跟着它走**（阳光会飘、卡片会位移）
##
## 目标解析走 PointerTargetResolver（与提示条共用一份判定），关卡侧不需要任何管理器 ——
## 有没有教程都能指。
##
## 目标与植物类型的配合：
##   · Card（种子包）—— plant_type 必填，指到那张卡的外侧
##   · Lawn（草地）—— plant_type 给了才知道「哪一格能种它」（地图是数据驱动的，不能取几何中心）
##   · Sun / Shovel / Plant 不需要 plant_type
## 传 None = 收起箭头（玩家该用的东西已经在手上时就别再指了）。

## 箭头指向的目标；None = 收起箭头
@export var target: PointerTargetResolver.E_PointerTarget = PointerTargetResolver.E_PointerTarget.None
## 目标对应的植物类型（Card / Lawn 两个目标用得上）
@export var plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null


func run(main_game: MainGameManager) -> void:
	var hint := TutorialAdviceUI.ensure_level_hint(main_game)
	if hint == null:
		return
	if target == PointerTargetResolver.E_PointerTarget.None:
		hint.hide_arrow()
		return
	hint.point_to_level_target(main_game, target, plant_type)
