extends ComponentNormBase
class_name CreateSunComponent

## 生产阳光计时器
@onready var create_sun_timer: Timer = $CreateSunTimer
## 身体, 控制发光
@onready var body: BodyCharacter = %Body


## 生产阳光价值
@export var sun_value := 25
## 生产光位置
@export var marker_2d_create_sun: Marker2D
## 生产阳光的个数
@export var num_create_sun:int=1
@export_group("生产间隔时间")
## 第一个阳光生产时间范围
@export var create_time_range_first:Vector2 = Vector2(3, 12.5)
## 后续生产阳光的时间范围
@export var create_time_range_other:Vector2 = Vector2(23.5,25)
## 阳光生产速度
var create_speed := 1.0

## 阳光生产间隔
var create_interval :float
## 创建阳光时的发光颜色
var create_sun_color: Color = Color(1, 1, 1)


#region 我是僵尸模式
## 原版口径的「掉阳光血量档」（`Zombie.cpp::EatPlant` 的 I_ZOMBIE 分支：health / 40）
const SUN_DROP_STAGE_HP := 40

## 被啃掉一段血量：每被打掉一档血量（40）当场掉一颗；打死的那一口（血量归零）也算一档
## [param before_hp] 这次结算**前**的当前血量
## [param damage] 这次结算打掉的血量
func drop_sun_on_zombie_mode_hp_loss(before_hp:int, damage:int):
	var after_hp := before_hp - damage
	@warning_ignore("integer_division")
	if after_hp / SUN_DROP_STAGE_HP < before_hp / SUN_DROP_STAGE_HP or after_hp <= 0:
		_spawn_sun()

## 被啃死了：把剩下的阳光全掉出来
## 原版 `Challenge::IZombiePlantDropRemainingSun`：死亡时掉「剩余血量 / 40 + 1」颗
## （正常啃死时剩余血量 ≤ 0，即固定补 1 颗；被秒杀时按剩余血量折算）
func drop_sun_on_zombie_mode_death(remain_hp:int):
	@warning_ignore("integer_division")
	var count := maxi(remain_hp, 0) / SUN_DROP_STAGE_HP + 1
	for _i in count:
		_spawn_sun()

#endregion
func component_ready() -> void:
	if not get_tree().current_scene is MainGameManager:
		return
	create_interval = randf_range(create_time_range_first.x, create_time_range_first.y)
	create_sun_timer.start(create_interval)

	EventBus.subscribe(ConstEventName.MAIN_GAME_PROGRESS_UPDATE, _on_main_game_progress_update)

## 主游戏进程改变时,修改生产阳光组件
func _on_main_game_progress_update(curr_main_game_progress:MainGameManager.E_MainGameProgress):
	if curr_main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		enable_component(E_IsEnableFactor.MainGameProgress)
	else:
		disable_component(E_IsEnableFactor.MainGameProgress)

## 启用组件
func enable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)
	if is_enabling:
		create_sun_timer.start(create_sun_timer.wait_time / create_speed)

## 禁用组件
func disable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)
	if not is_enabling:
		create_sun_timer.stop()

func owner_update_speed(speed_product:float):
	if is_enabling:
		if not create_sun_timer.is_stopped():
			if speed_product == 0:
				create_sun_timer.paused = true
			else:
				create_sun_timer.paused = false

				create_sun_timer.start(create_sun_timer.time_left / speed_product)

	create_speed = speed_product


## 生产阳光后、改变阳光生产时间，重新启动计时器
func change_production_interval():
	create_interval = randf_range(create_time_range_other.x / create_speed, create_time_range_other.y / create_speed)
	create_sun_timer.start(create_interval)


## 创建阳光：闸门 / 实例化 / 落点 / 弹起再落下 / 广播那套在 `SunSpawner.pop_up`
## （弹起高度与用时以前写在这里，现在与宝石迷阵 / 锤子 / 水族馆共用同一份）
func _spawn_sun():
	var main_game := get_main_game()
	if main_game == null or not is_instance_valid(main_game.suns):
		return
	## 播放音效
	SoundManager.play_character_SFX(&"Throw1")
	for _i in range(num_create_sun):
		SunSpawner.pop_up(main_game.suns,
			main_game.suns.to_local(marker_2d_create_sun.global_position), sun_value)


## 创建阳光全流程：身体发光、生产阳光、身体不发光
func create_sun():
	# 创建新的 tween
	var tween = create_tween()
	tween.tween_method(func(val): body.set_other_color(BodyCharacter.E_ChangeColors.CreateSunColor, val), Color(1, 1, 1), Color(2, 2, 2), 0.5)
	# 在第一个 tween 完成后、第二个 tween 开始前调用函数
	tween.tween_callback(Callable(self, "_spawn_sun"))
	tween.tween_method(func(val): body.set_other_color(BodyCharacter.E_ChangeColors.CreateSunColor, val), Color(2, 2, 2), Color(1, 1, 1), 0.5)


func _on_create_sun_timer_timeout() -> void:
	create_sun()
	change_production_interval()

## 改变阳光生产价值
func change_sun_value(new_sun_value:int):
	self.sun_value = new_sun_value
