extends LevelProgressProvider
class_name SlotMachineProgressProvider
## 拉霸（Slot Machine，迷你游戏第 3 关）的关卡进度条数据源：**进度 = 当前阳光 / 过关目标（2000）**
##
## 本关没有波次、没有旗帜，玩家的「进度」就是攒到多少阳光 —— 原版
## `Challenge::UpdateSlotMachine` 把 `mProgressMeterWidth` 按阳光 / 2000 映射，
## 奖杯在阳光到 2000 时掉（口径完全一致）。
## 阳光本体在拉霸 UI 上（`SlotMachineUI.get_sun_value()`），这里每帧读一次换算成百分比。
##
## 谁在用它：**只有 minigame_03_slot_machine 一关**（硬约束 §1-8：一关专属的口径不进游戏本体），
## 与拉霸其它代码同放在 `src/levels/mode_minigame/`。
## 关卡脚本在 `create_progress_provider()` 里返回本源实例，拉霸 UI 挂上之后由它 `bind_ui()`。


## 玩法本体：比本源建得晚（要等拉霸 UI 实例化），所以绑一次而不是构造时给
var slot_ui: SlotMachineUI = null
## 最后一次读到的阳光 / 目标：拉霸 UI 在判胜后会被关卡流程收走，
## 进度条那一下（100%）要留住，不能跟着 UI 一起归零
var _last_sun_value: int = 0
var _last_target_sun: int = 0


## 拉霸 UI 挂上时绑一次（见 minigame_03_slot_machine.run_flow）
func bind_ui(ui: SlotMachineUI) -> void:
	slot_ui = ui


func get_progress() -> float:
	var target_sun: int = _last_target_sun
	if _is_ready():
		_last_sun_value = slot_ui.get_sun_value()
		_last_target_sun = slot_ui.get_target_sun()
		target_sun = _last_target_sun
	if target_sun <= 0:
		return 0.0
	return clampf(float(_last_sun_value) / float(target_sun) * 100.0, 0.0, 100.0)


## 只在拉霸 UI 真的在跑时显示：挂上来之前 / 已经通关都藏起来，
## 免得主界面上留一条 0% 的孤儿进度条（口径同 ZombiquariumProgressProvider）
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
	return slot_ui != null and is_instance_valid(slot_ui)
