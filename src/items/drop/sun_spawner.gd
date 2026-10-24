class_name SunSpawner
## **阳光的生成口**：实例化 -> 入树 -> 记落点 -> 起下落 -> 广播，全在这一处
##
## 以前这段在七个地方各抄了一遍（天降 / 向日葵 / 宝石迷阵 / 锤子 / 水族馆 / DLC 荧光蘑菇 /
## 联机客户端的重放），其中「弹起来再落下」那四段 tween 几乎逐字相同 —— 改一个忘三个。
## 现在生成点只管说清「长在哪儿、值多少」，表现与联机广播由这里统一。
##
## 两条入口：
##   `pop_up()`       —— 弹起来再落下（向日葵吐的、消除掉的、锤出来的…）
##   `fall_from_sky()`—— 天降（从天上匀速落下，用时按距离 / 速度算）
##   `replay_fall()`  —— 联机客户端照主机下发的数据重放那一段下落（不新长一颗）
##
## 闸门（`GlobalUtils.sun_spawn_gate`）：客户端不长自己的那一份，天上掉哪一颗由主机说了算 ——
## 判在**生成口**而不是 `Sun` 自己身上：挂到 Sun 里要在已经 add_child 之后才拦得下来
## （与 `DropItemBase` / DIM_Base 同一套思路）。

## 弹起来的高度（负值 = 往上）与落下去的距离
const RISE_Y := -15.0
const FALL_Y := 45.0
## 弹起 / 落下各占的秒数（合计 = 一趟的用时）
const RISE_DURATION := 0.3
const FALL_DURATION := 0.6
## 落地点的横向随机偏移范围
const OFFSET_X_RANGE := Vector2(-30.0, 30.0)
## 阳光的默认价值（天降那颗不带值）
const DEFAULT_SUN_VALUE := 25


## **弹起来再落下**地长一颗阳光（向日葵 / 宝石迷阵 / 锤子 / 水族馆 / 荧光蘑菇都走这一条）
##
## [param parent] 阳光挂到哪个节点下（一般是 `MainGameManager.suns`）
## [param local_pos] **父节点的本地坐标**（与旧的生成点同口径：调用方自己 to_local）
## 返回长出来的那一颗；被闸门拦住 / 父节点没配时返回 null
static func pop_up(parent: Node2D, local_pos: Vector2, value: int) -> Sun:
	if _is_gate_blocked():
		return null
	var sun := _instantiate(parent)
	if sun == null:
		return null
	sun.init_sun(value, local_pos)
	parent.add_child(sun)
	var offset_x := randf_range(OFFSET_X_RANGE.x, OFFSET_X_RANGE.y)
	## 记下这一趟的落点与用时（联机要带着下发；净位移 / 用时见 `Sun.mark_pop_up`）
	sun.mark_pop_up(offset_x, RISE_Y, FALL_Y, RISE_DURATION + FALL_DURATION)
	_play_pop_up(sun, offset_x)
	_notify_spawned(sun)
	return sun


## **天降**：从 [param local_pos] 匀速落到 [param target_y]，用时由调用方按「距离 / 速度」算
## 返回长出来的那一颗；被闸门拦住 / 父节点没配时返回 null
static func fall_from_sky(parent: Node2D, local_pos: Vector2, target_y: float,
		duration: float, value := DEFAULT_SUN_VALUE) -> Sun:
	if _is_gate_blocked():
		return null
	var sun := _instantiate(parent)
	if sun == null:
		return null
	sun.init_sun(value, local_pos)
	parent.add_child(sun)
	## 记下这一趟的落点与用时（联机要带着下发）
	sun.spawn_target = Vector2(local_pos.x, target_y)
	sun.spawn_fall = maxf(duration, 0.05)
	sun.spawn_sun_tween = sun.create_tween()
	sun.spawn_sun_tween.tween_property(sun, "position:y", target_y, sun.spawn_fall)
	sun.spawn_sun_tween.finished.connect(sun.on_sun_tween_finished)
	_notify_spawned(sun)
	return sun


## 联机客户端照主机下发的两个点重放那一段下落（起终点一致，两端才落在同一处）
##
## ⚠️ 时长也照主机给的来：天降是「距离 / 速度」（慢悠悠），向日葵吐的是固定 0.9 秒（弹一下），
## 客户端自己按速度算会把后者变成 0.15 秒 —— 位置对得上，看着对不上
static func replay_fall(sun: Sun) -> void:
	if sun == null or not is_instance_valid(sun):
		return
	var to := sun.spawn_target
	if to == Vector2.ZERO:
		return
	var duration := maxf(sun.spawn_fall, 0.05)
	sun.spawn_sun_tween = sun.create_tween()
	sun.spawn_sun_tween.set_parallel()
	if absf(to.x - sun.position.x) > 0.5:
		sun.spawn_sun_tween.tween_property(sun, "position:x", to.x, duration)
	sun.spawn_sun_tween.tween_property(sun, "position:y", to.y, duration)
	sun.spawn_sun_tween.finished.connect(sun.on_sun_tween_finished)


## 「弹起来再落下」那一趟：垂直两段（先弹起后落下）+ 横向匀速
static func _play_pop_up(sun: Sun, offset_x: float) -> void:
	var vertical := sun.create_tween()
	vertical.tween_property(sun, "position:y", RISE_Y, RISE_DURATION) \
		.as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	vertical.tween_property(sun, "position:y", FALL_Y, FALL_DURATION) \
		.as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sun.spawn_sun_tween = sun.create_tween()
	sun.spawn_sun_tween.set_parallel()
	sun.spawn_sun_tween.tween_subtween(vertical)
	sun.spawn_sun_tween.tween_property(sun, "position:x", offset_x, RISE_DURATION + FALL_DURATION).as_relative()
	sun.spawn_sun_tween.finished.connect(sun.on_sun_tween_finished)


static func _instantiate(parent: Node2D) -> Sun:
	if parent == null or not is_instance_valid(parent):
		Log.error("生成阳光但没有配置父节点")
		return null
	return SceneRegistry.SUN.instantiate() as Sun


static func _is_gate_blocked() -> bool:
	return GlobalUtils.sun_spawn_gate.is_valid() and bool(GlobalUtils.sun_spawn_gate.call())


## 落点已经写进去了，这时候才广播"多了这一颗"（联机主机靠它下发；单机没人连，发了也无事）
static func _notify_spawned(sun: Sun) -> void:
	EventBus.push_event(ConstEventName.SUN_SPAWNED, [sun])
