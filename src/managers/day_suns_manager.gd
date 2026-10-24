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

## 创建阳光：实例化 / 落点 / 下落 / 广播那套在 `SunSpawner.fall_from_sky`
## （闸门判在那里：本方法有**两条入口** —— 定时器与关卡时间轴的教学阳光，见文件头）
func spawn_sun():
	if not is_instance_valid(GameContext.curr_main_game):
		return
	var target_y := randf_range(sun_y_min, sun_y_max)
	var new_sun := SunSpawner.fall_from_sky(
		GameContext.curr_main_game.suns,
		Vector2(randf_range(sun_x_min, sun_x_max), sun_y_ori),
		target_y,
		absf(target_y - sun_y_ori) / sun_y_speed)
	if new_sun == null:
		return
	curr_sun_sum_value += new_sun.sun_value



func change_production_interval():
	var A : float = 10 * curr_sun_sum_value + 425
		# 下次天降阳光时间
	if A<950:
		production_interval = (A + randf_range(0,274))
	else:
		production_interval = 950 + randf_range(0,274)

	production_timer.start(production_interval/100)
