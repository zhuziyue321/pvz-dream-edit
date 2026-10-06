extends Node
class_name ZombieWaveSourceBase
## 出怪器基类 —— 不走默认波次表出怪的关卡从这里派生
##
## 谁在用它：
##   · 关卡侧的**玩法规则**：实例化自己的出怪器，交给 `ZombieManager.set_wave_source()` 注入
##   · `ZombieManager`：只认这个基类 —— `init_source()` 初始化、`start_first_wave()` 开第一波、
##     波次走到第几波 / 是不是最后一波由 `signal_wave_refresh` 通知回来
##
## 有了这个注入口子，「本关怎么出怪」留在关卡脚本那一侧，本体不需要为某个玩法
## 常驻一个管理器，也不用认识任何具体玩法名（硬约束 §1-8，
## 见 [D-07](../../../docs/参考存档/规范细则存档.md#d-07-关卡脚本-vs-游戏本体一次性机制的落位)）

## 波次刷新信号（参数：当前是不是最后一波）
## 由子类在刷出每一波时 emit，本体侧 `ZombieManager` 统一 connect，基类自身不 emit
@warning_ignore("unused_signal")
signal signal_wave_refresh(is_end_wave: bool)


## 初始化出怪器（由 `ZombieManager.init_manager()` 在 monster_mode 指定的分支里调用）
## [game_para] 关卡数据
func init_source(_game_para: ResourceLevelData) -> void:
	pass


## 开第一波：调用时机由 `ZombieManager.start_game()` 统一管（整局只开一次），
## 开局要不要先等几秒由出怪器自己决定
func start_first_wave() -> void:
	pass


#region 战斗进度（关卡进度条的数据源从这里取；出怪器不碰进度条节点本身）
## 当前战斗进度百分比（0~100）：出怪器自己算，默认 0（没有进度概念）
func get_battle_progress() -> float:
	return 0.0


## 本玩法的波次是否已经开打（开打前进度条不显示）
func is_battle_started() -> bool:
	return false


## 进度条上要画几面旗帜（<= 0 = 不画）
func get_flag_num() -> int:
	return 0


## 取走「本帧要升旗」的旗帜下标（-1 = 不升）
func take_flag_raise_index() -> int:
	return -1


## 取走「本帧要收起所有旗帜」的请求
func take_flag_reset() -> bool:
	return false
#endregion
