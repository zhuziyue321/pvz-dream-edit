extends RefCounted
class_name LevelProgressProvider
## 关卡进度条的数据源 —— 「进度条现在代表什么」这一件事的唯一答案
##
## 控制器（LevelProgressBarController）每帧问一次：进度多少 / 要不要显示 / 画几面旗。
## 数据源只管算数、不碰进度条节点：**换数据源 = 换进度条的口径**。
##   · 默认（战斗）：`LevelProgressBattleProvider` —— 波次走完多少
##   · 僵王战：`ZombossProgressProvider` —— 僵王血量百分比
##
## 关卡脚本要换口径：覆写 `LevelScriptBase.create_progress_provider()` 返回自己的实例
## （一关专属的进度口径留在关卡脚本里，本体不认识任何具体玩法，硬约束 §1-8）。

## 宿主控制器：绑定后可用（要拿主游戏就 `controller.main_game`）
var controller: LevelProgressBarController


## 绑定：被控制器装上时调用一次（建旗帜这类一次性准备写在这里）
func on_bind() -> void:
	pass


## 解绑：换源 / 关卡退出时调用（断信号、清缓存）
func on_unbind() -> void:
	pass


## 进度百分比（0~100）：控制器每帧取一次
func get_progress() -> float:
	return 0.0


## 进度条要不要显示：本源没有可显示的东西时返回 false（比如还没开第一波 / 僵王还没出场）
## 控制器在外面还叠了一层「关卡整体开关」（见 LevelProgressBarController.set_enabled）
func is_bar_visible() -> bool:
	return true


## 进度条上要画几面旗帜（<= 0 = 不画）：控制器发现数字变了才重建一次
func get_flag_num() -> int:
	return 0


## 取走「本帧要升旗」的旗帜下标（-1 = 不升）：取走后本源自己清掉
func take_flag_raise_index() -> int:
	return -1


## 取走「本帧要把所有旗帜收起」的请求（多轮游戏切新一轮）：取走后本源自己清掉
func take_flag_reset() -> bool:
	return false
