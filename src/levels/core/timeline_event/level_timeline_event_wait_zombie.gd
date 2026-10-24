extends ResourceLevelTimelineEvent
class_name LevelTimelineEventWaitZombie
## 等场上出现第一只僵尸（我是僵尸模式的开场提示挂在这一步收起：
## 原版 ADVICE_I_ZOMBIE_EAT_ALL_BRAINS 一直挂着，直到玩家放下第一只僵尸才 ClearAdvice）
##
## 轮询 `zombie_manager.curr_zombie_num` 而不是订阅某个创建信号：放僵尸的入口不止
## 卡槽一条路（模组 / 调试通道都能放），数量归零后再放也算「第一只」。
## 没有参数

## 最多等多久（秒）：超过就当提示已看完，避免玩家一直不放僵尸把流程卡死
@export var timeout: float = 30.0


func run(main_game: MainGameManager) -> void:
	await wait_until(main_game,
		func(): return is_instance_valid(main_game.zombie_manager) \
			and main_game.zombie_manager.curr_zombie_num > 0, timeout)
