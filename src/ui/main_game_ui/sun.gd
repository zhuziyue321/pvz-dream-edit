extends DropItemBase
class_name Sun
## 阳光（天降 / 向日葵产 / 小游戏掉…）
##
## 生到死那套公共骨架（编号 / 点击 / 超时淡出）在 `DropItemBase`；
## **生成**统一走 `SunSpawner`（七个生成点以前各抄了一遍"弹起来再落下"）。
##
## 与钱那类的两点不同：
##   · 下落那一段不叫"抛物线"：天降是匀速、生成点是弹起再落下，都由 `SunSpawner` 驱动
##     （所以 has_launch_animation() = false，落地回调挂在 `on_sun_tween_finished()` 上）
##   · 自动收集看的是 `auto_collect_sun` 而不是金币那个开关（见 `on_sun_tween_finished`）

## 这一颗的价值
@export var sun_value := 25

## 缩放基准：25 价值的阳光 = 原尺寸（以前这个 /25.0 写在 `_sun_scale()` 里）
const BASE_SUN_VALUE := 25.0

## 生产阳光移动的 tween（由 SunSpawner 起，拾取时要打断）
var spawn_sun_tween:Tween
## 掉这一趟用了多少秒（由 SunSpawner 写入；联机下发时带着，主机那一趟的用时）
var spawn_fall:float = 0.0


func drop_ready() -> void:
	_sun_scale(sun_value)


## 下落那一段由 SunSpawner 驱动（天降 / 弹起都是），不归基类的抛物线管
func has_launch_animation() -> bool:
	return false


## 自动收集看的是阳光自己的开关，且要等落地（见 `on_sun_tween_finished`）
func should_auto_pick_on_landed() -> bool:
	return false


func get_player_action() -> int:
	return GlobalUtils.E_PlayerAction.PickSun


## 记下**"弹起来再落下"**这一趟的落点与用时
##
## 生成点只管说清偏移，净位移是 `rise + fall`、用时 `duration` —— 把这几个数收在这里，
## 免得七个生成点各抄一遍"净位移是 +30、用时 0.9 秒"，改一个忘六个。
## 天降那一趟由 `SunSpawner.fall_from_sky()` 直接写 `spawn_target` / `spawn_fall`。
func mark_pop_up(offset_x: float, rise: float = -15.0, fall: float = 45.0, duration: float = 0.9) -> void:
	spawn_target = position + Vector2(offset_x, rise + fall)
	spawn_fall = duration


func init_sun(curr_sun_value:int, pos:Vector2):
	sun_value = curr_sun_value
	position = pos


func _sun_scale(new_sun_value:int):
	var new_scale = float(new_sun_value) / BASE_SUN_VALUE
	scale = Vector2(new_scale,new_scale)


## 把这一颗收走（拾取的公共入口：按钮 / 自动收集 / 联机重放都走这里，**不过闸门**）
func pick() -> void:
	if spawn_sun_tween != null:
		if spawn_sun_tween.is_valid():
			spawn_sun_tween.kill()
		spawn_sun_tween = null
	kill_launch_tween()
	if is_opened:
		return
	is_opened = true
	SoundManager.play_other_SFX("points")
	## 收走了就不能再点
	var button := get_pick_button()
	if button != null:
		button.queue_free()
	var target_position = Vector2()
	if is_instance_valid(GameContext.curr_main_game):
		if is_instance_valid(GameContext.curr_main_game.marker_2d_sun_target):
			## 出战卡槽在canvaslayer中，位置和摄像头位置有偏移
			target_position = GameContext.curr_main_game.marker_2d_sun_target.global_position \
				+ GameContext.curr_main_game.camera_2d.global_position
		else:
			target_position = GameContext.curr_main_game.marker_2d_sun_target_default.global_position
		EventBus.push_event(ConstEventName.ADD_SUN_VALUE, [sun_value])
	fly_to_target(target_position, Callable(), 0.3)


## 老名字的入口（联机重放在调）：一律走 `pick()`
func collect() -> void:
	pick()


## 老名字的入口（按钮按下 / 探针直接点阳光时调）：走 `request_pick()` —— 玩家点的那一下要过上报口
func _on_button_pressed() -> void:
	request_pick()


## 落地那一刻（由 SunSpawner 的 tween finished 调）：开了自动收集阳光就当场收走
func on_sun_tween_finished():
	if Global.config_service.auto_collect_sun:
		request_pick()


## 超时消失：阳光淡得比掉落物慢一点（1 秒），与旧实现同一步伐
func fade_and_delete(_fade_duration := 1.0) -> void:
	super.fade_and_delete(1.0)
