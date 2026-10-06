extends ResourceLevelTimelineEvent
class_name LevelTimelineEventStartBattle
## 开战：启动战斗流程（BGM / 战斗卡槽 / 天降阳光 / 出怪），再等到这一段打完
##
## 「打完」的判定按玩法写在本脚本的 _is_battle_finished() 里，不在事件上配参数：
##   砸罐子：罐子全砸开 + 场上僵尸清空
##   出怪关：最后一波刷完 + 场上僵尸清空（清场那一刻原流程会推 create_trophy）
##
## 参数：
##   timeout —— 兜底秒数，超过就不管打没打完直接进下一个事件；0 = 一直等
##               （砸罐子这类要等玩家自己砸完的关卡就该一直等）
##   max_wave —— 本段波数，> 0 时改写关卡数据上的 max_wave；-1 = 沿用关卡数据
##   zombie_refresh_types —— 本段出怪表，非空时改写关卡数据上的出怪表；空 = 沿用关卡数据
##               （关卡脚本里 `await start_battle(10, [1])` 就把这两条一并带过来）

@export var timeout: float = 0.0
@export var max_wave: int = -1
@export var zombie_refresh_types: Array[CharacterRegistry.ZombieType] = []


func run(main_game: MainGameManager) -> void:
	_apply_battle_para(main_game)
	await main_game.main_game_start()
	await wait_until(main_game, func(): return _is_battle_finished(main_game), timeout)
	if not is_instance_valid(main_game):
		return
	## 一批打完还有下一批时，等轮次切换完再走下一个事件：
	## 切换由 create_trophy -> start_next_round_game 触发（轮次 +1，中间等 3 秒），
	## 下一个戴夫对话要取的是新一轮的对话，不能抢在切轮之前播
	if main_game.curr_game_round < main_game.game_para.game_round:
		var from_round: int = main_game.curr_game_round
		await wait_until(main_game, func(): return main_game.curr_game_round > from_round, 0.0)


## 把「开战」上带的出怪参数写进关卡数据，并同步到已经初始化过的僵尸管理器
##
## **为什么要补后面那一步**：子管理器在 MainGameManager._ready 的 init_manager() 里
## 就按关卡数据读过一遍出怪参数了，而关卡流程（run_flow）跑在它之后 —— 只改关卡数据，
## 本关还是会按旧波数 / 旧出怪表打。所以这里改完必须把那一遍读出来的状态一起改掉。
func _apply_battle_para(main_game: MainGameManager) -> void:
	var para := main_game.game_para
	if para == null:
		return
	if max_wave > 0:
		para.max_wave = max_wave
		var zombie_manager := main_game.zombie_manager
		if is_instance_valid(zombie_manager) and is_instance_valid(zombie_manager.zombie_wave_manager):
			zombie_manager.zombie_wave_manager.apply_max_wave(max_wave)
	main_game.apply_level_zombie_refresh_types(zombie_refresh_types)


## 本段战斗是否打完（按玩法分派）
func _is_battle_finished(main_game: MainGameManager) -> bool:
	## 关卡已经被销毁（玩家中途退出）时算打完：不再访问已释放的管理器
	if not is_instance_valid(main_game) or not is_instance_valid(main_game.zombie_manager):
		return true
	var zombie_manager := main_game.zombie_manager
	if main_game.plant_cell_manager.is_pot_mode:
		return main_game.plant_cell_manager.curr_pot_num == 0 and zombie_manager.curr_zombie_num == 0
	return zombie_manager.is_end_wave and zombie_manager.curr_zombie_num == 0
