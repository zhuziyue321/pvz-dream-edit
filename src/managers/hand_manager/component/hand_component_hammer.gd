extends HandComponentBase
class_name HandComponentHammer
## 手持物组件：锤子（迷你游戏 15「打僵尸」/ 冒险 2-5「打地鼠」两关共用）
##
## **默认禁用**：绝大多数关卡没有锤子。只有装了「锤僵尸」玩法的那两关，
## 由玩法规则 `LevelRuleHammerZombie.install()` 启用本组件，并把它设成**本关的空闲手持物**
## 取代空手（见 HandManager.set_idle_hand_type）—— 进 MAIN_GAME 自动拿在手上、种完植物
## 或放下铲子后也回到锤子、非游玩阶段由本体统一收起（硬约束 §1-8）。
##
## **挥锤不走格子的 click_cell**：锤子是跟着鼠标走的光标类道具，点屏幕任意非 UI 处都能挥
## （见 hammer.gd 的 _unhandled_input），所以这里永远返回 false（这一下不用完手持物）。

## 跟随鼠标的真锤子（挂在 CanvasLayerTemp 下，与真铲子 / 真手套同层）
@onready var real_hammer: Hammer = %RealHammer


func get_hand_component_type() -> E_HandComponentType:
	return E_HandComponentType.Hammer


func _ready_component() -> void:
	## 能不能用由玩法规则决定：规则没启用就是禁用（不在那两关里）
	change_is_enabling(false, E_IsEnableFactor.HandItem)


func enter_hand(_payload: Variant = null) -> bool:
	if is_instance_valid(real_hammer):
		real_hammer.set_is_used(true)
	return true


## 必须幂等：拿卡片 / 铲子时会先走这里，冷却收起时也可能被连调
func exit_hand() -> void:
	if is_instance_valid(real_hammer):
		real_hammer.set_is_used(false)


## 锤子不靠点格子挥（见类注释），点完格子锤子还在手上
func click_cell(_plant_cell: PlantCell) -> bool:
	return false
