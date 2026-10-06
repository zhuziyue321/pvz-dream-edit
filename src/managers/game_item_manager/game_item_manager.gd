extends MainGameSubManager
## 游戏物品管理器
class_name GameItemManager

@onready var gim_brain: GIM_Brain = $GIM_Brain
@onready var gim_lawn_mover: GIM_LawnMover = $GIM_LawnMover
@onready var gim_rake: GIM_Rake = $GIM_Rake
@onready var gim_other: GIM_Other = $GIM_Other


func init_manager() -> void:
	## 我是僵尸模式
	if game_para.is_zombie_mode:
		gim_brain.create_all_brain_on_zombie_mode()
	## 小推车不在这里初始化：由关卡流程的「初始化小推车」事件负责
	## （LevelTimelineEventLawnMover，排在「准备…安放…植物」之前 ——
	##  推车出生在屏幕外左侧，再按从下到上的顺序逐一开到位，见 GIM_LawnMover）
	## 钉耙:手上还有剩余关数才放(见 GIM_Rake.init_rakes)
	gim_rake.init_rakes()
	gim_other.init_other_item()


## 开始下一轮游戏 模式管理器更新
func start_next_game_game_item_manager_update():
	if game_para.is_zombie_mode:
		gim_brain.create_all_brain_on_zombie_mode()
