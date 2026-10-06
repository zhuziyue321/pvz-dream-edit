extends LevelProgressBattleProvider
class_name SeeingStarsProgressProvider
## 观星（Seeing Stars）的关卡进度条数据源：**进度条 = 已种上杨桃的轮廓点数 / 轮廓点总数**
##
## 本关的通关条件是「轮廓点全种上杨桃」而不是「打完波次」，所以进度条不再代表波次走到哪：
## 种满一个轮廓点涨一格，全种满 = 100%（也就是掉奖杯那一刻）。
## 种植进度的本体在关卡脚本上（`star_cells` / `get_unplanted_num()`），这里每帧读一次换算成百分比。
##
## **进度条上不画旗帜**：本关的波次只是「4 面旗帜内没种满算输」的倒计时，
## 进度条已经被种植进度占满了，再画 4 面旗只会让人误以为进度跟波次有关
## （口径同「没有波次概念」的 `ZombossProgressProvider` / `BeghouledProgressProvider`）。
##
## 继承 `LevelProgressBattleProvider` 只为复用「开第一波之后才显示」这一条；
## 旗帜相关的三个查询全部在这里关掉（画 0 面 / 不升旗 / 不收旗）。
##
## 谁在用它：**只有 minigame_07_seeing_stars 一关**（硬约束 §1-8：一关专属的口径不进游戏本体），
## 与观星其它代码同放在 `src/levels/mode_minigame/`。
## 关卡脚本在 `create_progress_provider()` 里返回本源实例。


## 进度百分比：已种上的轮廓点数 / 轮廓点总数（对照组是原版那种「种满就赢」的玩法）
func get_progress() -> float:
	var level_script := _level_script()
	if level_script == null:
		return 0.0
	var total: int = level_script.star_cells.size()
	if total <= 0:
		return 0.0
	var planted: int = total - level_script.get_unplanted_num()
	return clampf(float(planted) / float(total) * 100.0, 0.0, 100.0)


## 一个轮廓点都没有时不显示：那是「本关没配星星」，不该在主界面留一条 0% 的孤儿进度条
## （口径同 `ZombossProgressProvider` / `BeghouledProgressProvider`）
func is_bar_visible() -> bool:
	if not super.is_bar_visible():
		return false
	var level_script := _level_script()
	if level_script == null:
		return false
	return not level_script.star_cells.is_empty()


## 不画旗帜（<= 0 = 清掉上一批）：本关的旗帜是波次倒计时，不占进度条
func get_flag_num() -> int:
	return 0


## 没有旗帜可升：波次照常走，但进度条上不表现（传 -1 = 本帧不升旗）
func take_flag_raise_index() -> int:
	return -1


## 关卡脚本：轮廓点与「还差几个没种」都在它身上，从控制器注入的 main_game 上取
func _level_script() -> LevelScriptBase:
	if controller == null or not is_instance_valid(controller.main_game):
		return null
	return controller.main_game.game_para as LevelScriptBase
