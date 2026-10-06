extends LevelProgressProvider
class_name ZombiquariumProgressProvider
## 僵尸水族馆（Zombiquarium）的关卡进度条数据源：**进度 = 当前阳光 / 奖杯价格（1000）**
##
## 本关没有波次、没有旗帜，玩家的「进度」就是攒了多少阳光：攒到 `TROPHY_SUN_COST`
## （1000）就能买下奖杯通关，所以进度条到这里就是「离通关还差多少阳光」。
## 口径跟着出战卡槽上的那一份阳光走（`ZombiquariumManager.get_sun_value()`），
## 买了潜水僵尸会把进度打回去 —— 那是真实现金减少了，进度条本来就该退。
##
## 谁在用它：**只有 minigame_08_zombie_aquarium 一关**（硬约束 §1-8：一关专属的口径不进游戏本体），
## 与水族馆其它代码同放在 `src/zombiquarium/`。
## 关卡脚本在 `create_progress_provider()` 里返回本源实例，水族馆挂上之后由它 `bind_manager()`。

## 玩法本体：比本源建得晚（要等水族馆实例化），所以绑一次而不是构造时给
var aquarium: ZombiquariumManager = null


## 水族馆挂上时绑一次（见 `minigame_08_zombie_aquarium.run_flow`）
func bind_manager(manager: ZombiquariumManager) -> void:
	aquarium = manager


func get_progress() -> float:
	if not _is_ready():
		return 0.0
	return clampf(
		float(aquarium.get_sun_value()) / float(ConstZombiquarium.TROPHY_SUN_COST) * 100.0,
		0.0, 100.0
	)


## 只在水族馆真的在跑时显示：挂上来之前 / 通关判负之后都藏起来，
## 免得主界面上留一条 0% 的孤儿进度条（口径同 `BeghouledProgressProvider`）
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
	return is_instance_valid(aquarium) and aquarium.is_running
