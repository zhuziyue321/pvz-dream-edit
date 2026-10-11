extends MainGameSubManager
class_name DaySunsManagner
## 天降阳光管理器

@export var production_interval: float  # 生产间隔(毫秒)
@export var curr_sun_sum_value := 0

@onready var production_timer: Timer = $ProductionTimer

@export var sun_x_min : float = 50
@export var sun_x_max : float = 750

@export var sun_y_min : float = 130
@export var sun_y_max : float = 550

@export var sun_y_ori : float = -40

@export var sun_y_speed : float = 200

## ⚠️ 天降的"不掉"闸门在 `GlobalUtils.sun_spawn_gate`（**全局**那一个），不在这上面
##
## 为什么不在本管理器上开一个：植物产阳光（`CreateSunComponent`）也要能被同一个闸门挡住，
## 两个同名的口必然有一个被忘装 —— 上一版就因为这个**天降根本没被拦住**（模组只装了全局那个）。
## 放在**生成点**而不是 `Sun` 自己身上：挂到 `Sun` 里要在已经 `add_child` 之后才拦得下来。
##
## ★ 判在 `spawn_sun()` **里面**，不是判在定时器回调里：本方法有**两条入口** ——
## 定时器（天降）与关卡时间轴（`LevelTimelineEventSpawnSun` 教学掉的那颗直接调 `spawn_sun()`）。
## 只守定时器那一条，客户端的教学阳光就会照旧本地长出来：它领走本地自增的 `entity_id`
## （与角色共用同一个分配器），后面客户端生成的植物编号整体错位 —— 正是
## [联机模组](../../docs/参考存档/联机模组.md) §4.9 警告的"编号错位"，只是落在植物上。
## 判在一个被两条入口共用的方法里，加第三条入口也不会漏。


func _ready():
	production_timer.timeout.connect(_on_production_timer_timeout)

func init_manager() -> void:
	pass

func start_day_sun():
	# 如果计时器是暂停状态，取消暂停
	if production_timer.paused:
		production_timer.paused = false

	if production_timer.is_stopped():
		change_production_interval()
		production_timer.start(production_interval/100)

func pause_day_sun():
	production_timer.paused = true


func _on_production_timer_timeout():
	## ⚠️ 闸门不在这里判 —— 在 `spawn_sun()` 里（见文件头）：关卡时间轴那条入口
	## 直接调 `spawn_sun()`，只守定时器这一条会漏掉教学掉的那颗。
	## 被拦住时定时器照旧继续摇间隔（`change_production_interval()` 照跑）。
	spawn_sun()
	change_production_interval()

## 创建阳光
func spawn_sun():
	## 闸门被占住时（联机客户端）这一颗不长：天上掉哪一颗由**主机**下发，本地只管继续摇定时器
	if GlobalUtils.sun_spawn_gate.is_valid() and bool(GlobalUtils.sun_spawn_gate.call()):
		return
	var new_sun = SceneRegistry.SUN.instantiate()
	if new_sun is Sun:
		GameContext.curr_main_game.suns.add_child(new_sun)
		curr_sun_sum_value += new_sun.sun_value
		# 控制阳光下落
		new_sun.spawn_sun_tween = get_tree().create_tween()
		new_sun.position = Vector2(randf_range(sun_x_min, sun_x_max), sun_y_ori)
		var target_y = randf_range(sun_y_min, sun_y_max)
		## 记下落点：联机要把"从哪儿掉到哪儿"一起下发，两端才落在同一处
		new_sun.spawn_target = Vector2(new_sun.position.x, target_y)
		var distance = float(abs(target_y - sun_y_ori))
		var duration = distance / sun_y_speed
		new_sun.spawn_fall = duration
		new_sun.spawn_sun_tween.tween_property(new_sun, "position:y", target_y, duration)

		new_sun.spawn_sun_tween.finished.connect(new_sun.on_sun_tween_finished)
		## 落点已经写进去了，这时候才广播"多了这一颗"（联机主机靠它下发；单机没人连，发了也无事）
		EventBus.push_event(ConstEventName.SUN_SPAWNED, [new_sun])



func change_production_interval():
	var A : float = 10 * curr_sun_sum_value + 425
		# 下次天降阳光时间
	if A<950:
		production_interval = (A + randf_range(0,274))
	else:
		production_interval = 950 + randf_range(0,274)

	production_timer.start(production_interval/100)
