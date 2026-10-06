extends ResourceLevelTimelineEvent
class_name LevelTimelineEventStartFirstWave
## 启动第一波僵尸（不等开战）
##
## 原版 1-2：僵尸在玩家种下第一株向日葵之后出动 —— 教学还没走完就该让僵尸先来，
## 所以流程里要能在「开战」之前单独开第一波（开战事件见 LevelTimelineEventStartBattle）。
## 只开第一次：后面开战事件调 `ZombieManager.start_game()` 时看到第一波已开就跳过，
## 不会把第一波开两遍。
##
## 与「开战」开波的区别：**不读 `first_wave_delay`**（说开就开）、**不自动放僵王**
## （`try_auto_spawn_boss()` 归开战管）—— 本事件只补「这一刻该来第一波了」这一件事。
## 没有参数

func run(main_game: MainGameManager) -> void:
	var zombie_manager := main_game.zombie_manager
	if not is_instance_valid(zombie_manager) or zombie_manager.is_first_wave_started:
		return
	var wave_manager := zombie_manager.zombie_wave_manager
	if not is_instance_valid(wave_manager):
		return
	zombie_manager.is_first_wave_started = true
	wave_manager.start_next_wave()
	## 第一波落定之后才让进度条走起来、把进度条亮出来（与开战时同一套收尾）
	wave_manager.every_wave_progress_timer.start()
	wave_manager.is_wave_started = true
