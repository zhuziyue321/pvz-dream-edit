extends LevelProgressBattleProvider
class_name LevelProgressChainedBattleProvider
## 多场战斗拼接进度条 —— **把 N 场战斗按等分拼成一条进度条**
##
## 默认的 `LevelProgressBattleProvider` 只认「本场战斗」：多轮关卡（生存 5 轮 / 砸罐子 3 批）
## 每切一轮，进度条就从 0 重来、旗帜全部收起 —— 玩家看不出「一共打到第几成了」。
## 本源把当前轮次折进总进度：
##
##   总进度 = (已完成场次数 + 本场进度 / 100) / 总场次数 × 100
##   第 r 场第 i 面旗 → 全局下标 = r × 每场旗数 + i
##
## 于是「第 3 轮打到一半」= 50%（5 场里前 2 场已完 + 本场一半），切轮时进度**连着走**、
## 已升起的旗**留着**（底层每轮发的「收起全部旗帜」请求在这里吞掉）。
##
## **用法**
##   · 自动：`LevelProgressBarController._pick_provider()` 在 `game_para.game_round > 1`
##     时直接装这一份，关卡不用写代码；
##   · 手动：关卡脚本 `create_progress_provider()` 返回 `LevelProgressChainedBattleProvider.new(3)`
##     （段数写死，用于「一场战斗由 3 波不同玩法组成」这种非轮次的场合），
##     或运行期 `mg.level_progress_controller.set_provider(...)`。
##
## 注意：段数取**等分**权重。各场波数不同时，进度条按「场次」而不是「波数」均分；
## 真要按波数加权，得另给每段权重（当前没有这种关卡，不预留假接口）。

## 写死的场次数（0 = 跟关卡配置走：`game_para.game_round`）
var _battle_count_override := 0
## 写死的当前场次（-1 = 跟关卡轮次走；一场战斗内部分段时由关卡脚本自己推进）
var _battle_index_override := -1


func _init(battle_count: int = 0) -> void:
	_battle_count_override = battle_count


## 手动推进场次（一场战斗内部再分段时用；传 -1 回到「跟关卡轮次走」）
func set_curr_battle_index(index: int) -> void:
	_battle_index_override = index


## 总场次数：手动指定优先，否则读关卡的多轮配置（`-1` = 无尽，按 1 场处理）
func get_battle_count() -> int:
	if _battle_count_override > 0:
		return _battle_count_override
	var game_para := _game_para()
	if game_para == null or game_para.game_round <= 1:
		return 1
	return game_para.game_round


## 当前是第几场（0 起算）：默认跟主游戏的 `curr_game_round` 走，手动推进时以手动值为准
func get_curr_battle_index() -> int:
	var index := _battle_index_override
	if index < 0:
		var main_game := _main_game()
		## ⚠️ 轮次在 MainGameManager 上，关卡配置（ResourceLevelData）只有总轮数 `game_round`
		index = (main_game.curr_game_round - 1) if main_game != null else 0
	return clampi(index, 0, get_battle_count() - 1)


func get_progress() -> float:
	var local := super.get_progress()
	var count := get_battle_count()
	if count <= 1:
		return local
	return (float(get_curr_battle_index()) + local * 0.01) / float(count) * 100.0


## 切场那一刻 `is_battle_started()` 会短暂变回 false；已经打完至少一场时不能让进度条消失
func is_bar_visible() -> bool:
	return super.is_bar_visible() or get_curr_battle_index() > 0


## 旗帜总数 = 每场旗数 × 场次数（按场次均分排布）
func get_flag_num() -> int:
	return _flag_num_per_battle() * get_battle_count()


## 本场第 i 面旗 → 全局第 (已打完的场次 × 每场旗数 + i) 面
func take_flag_raise_index() -> int:
	var local_index := super.take_flag_raise_index()
	if local_index < 0:
		return -1
	return get_curr_battle_index() * _flag_num_per_battle() + local_index


## 底层每轮开打时会请求「收起全部旗帜」；拼接模式下前面几场的旗要留着 —— 取走并丢弃
func take_flag_reset() -> bool:
	super.take_flag_reset()
	return false


## 单场（单轮）要画几面旗
func _flag_num_per_battle() -> int:
	return super.get_flag_num()


func _game_para() -> ResourceLevelData:
	var main_game := _main_game()
	return main_game.game_para if main_game != null else null


func _main_game() -> MainGameManager:
	if controller == null or not is_instance_valid(controller.main_game):
		return null
	return controller.main_game
