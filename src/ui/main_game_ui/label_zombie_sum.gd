extends Label
class_name LabelZombieSum
## 屏幕左下角的「当前僵尸数量：N」那一行
##
## 是否显示有两个条件同时满足，见 `_refresh_visible()`：
##   1. 菜单 → 控制台 →「显示」里的「显示当前僵尸数量」开关（`ConfigService.display_zombie_sum_label`，**默认关**）
##   2. 当前不在选卡阶段（选卡时草坪还没开始，这一行没意义）
##
## 开关改动要立刻生效，所以订阅 `ConfigService` 的信号，而不是只在 `_ready()` 读一次。

## 当前阶段是否允许显示（选卡阶段不允许）
var _is_show_in_progress := true


func _ready() -> void:
	EventBus.subscribe(ConstEventName.MAIN_GAME_PROGRESS_UPDATE, _on_main_game_progress_update)
	Global.config_service.signal_change_display_zombie_sum_label.connect(
		_on_change_display_zombie_sum_label)
	_refresh_visible()


func _on_main_game_progress_update(main_game_progress :MainGameManager.E_MainGameProgress):
	_is_show_in_progress = not (main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD
		or main_game_progress == MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD)
	_refresh_visible()


## 控制台开关被改动（参数用不上，只关心当前值）
func _on_change_display_zombie_sum_label(_value: bool) -> void:
	_refresh_visible()


func _refresh_visible() -> void:
	visible = _is_show_in_progress and Global.config_service.display_zombie_sum_label
