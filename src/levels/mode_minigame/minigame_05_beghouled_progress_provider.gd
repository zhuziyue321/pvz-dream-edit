extends LevelProgressProvider
class_name BeghouledProgressProvider
## 僵尸迷阵（Beghouled）的关卡进度条数据源：**进度条 = 配对次数 / 75**
##
## 配对计数本体在 `BeghouledManager.match_num` 上（消掉一组连线 +1），这里每帧读一次换算成百分比：
## 0 次 = 0%，凑满 `ConstBeghouled.TARGET_MATCH_NUM`（75）= 100%。
## 原版本关没有波次也没有旗帜（无限波），进度条在这里就是配对进度。
##
## 谁在用它：**只有 minigame_05_beghouled 一关**（硬约束 §1-8：一关专属的口径不进游戏本体），
## 所以与关卡脚本同目录、文件名带本关前缀；与 09 共用的三消代码在 `src/levels/core/beghouled/`。
## 关卡脚本在 `create_progress_provider()` 里返回本源实例，三消管理器建好后由它 `bind_manager()`。

## 三消管理器：由关卡脚本在初始化回调里建好之后绑进来（它建得比本源晚，所以要等一拍）
var beghouled: BeghouledManager = null


## 三消管理器建好时绑一次（见 `minigame_05_beghouled._init_beghouled`）
func bind_manager(manager: BeghouledManager) -> void:
	beghouled = manager


func get_progress() -> float:
	if not _is_ready():
		return 0.0
	return clampf(float(beghouled.match_num) / float(ConstBeghouled.TARGET_MATCH_NUM) * 100.0, 0.0, 100.0)


## 只在本关玩法进行中显示：开战前（展示僵尸 / 铺盘）与通关之后都藏起来，
## 免得主界面上留一条 0% 的孤儿进度条（口径同 `ZombossProgressProvider`）
func is_bar_visible() -> bool:
	if not _is_ready():
		return false
	if controller == null or not is_instance_valid(controller.main_game):
		return false
	return controller.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME


## 本关没有波次 → 进度条上不画旗帜
func get_flag_num() -> int:
	return 0


func _is_ready() -> bool:
	return beghouled != null and is_instance_valid(beghouled) and beghouled.is_running
