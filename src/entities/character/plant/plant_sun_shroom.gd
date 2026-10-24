extends Plant000Base
class_name Plant010SunShroom

@onready var create_sun_component: CreateSunComponent = $CreateSunComponent
@onready var grow_timer: Timer = $GrowTimer

## 成长所需时间（游戏秒）：原版 `mStateCountdown = 12000` tick @100 Hz = **120 秒**（`Plant.cpp:388`）
@export var time_grow:float = 120
## 小阳光价值
@export var mini_sun_value := 15
## 正常阳光价值
@export var norm_sun_value := 25

@export_group("动画状态")
## 成长
@export var is_grow:=false

func ready_norm():
	super()
	grow_timer.wait_time = time_grow
	grow_timer.start()
	create_sun_component.change_sun_value(mini_sun_value)

	if is_zombie_mode:
		create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)


func ready_norm_signal_connect():
	super()
	## 角色速度改变
	signal_update_speed.connect(update_grow_speed)
	signal_update_speed.connect(create_sun_component.owner_update_speed)

## 成长结束
##
## ★ 动画状态由本脚本点名（该转换已改为手动 travel，见 `plant_sun_shroom.tscn`）
func _on_grow_timer_timeout() -> void:
	self.is_grow = true
	request_anim_state(&"SunShroom_grow")
	create_sun_component.change_sun_value(norm_sun_value)

## 更新成长的速度
func update_grow_speed(speed_factor:float):
	if not grow_timer.is_stopped():
		if speed_factor == 0:
			grow_timer.paused = true
		else:
			grow_timer.paused = false

			grow_timer.start(grow_timer.time_left / speed_factor)


## 被僵尸啃食（连续掉血结算前按原版口径检查要不要掉阳光）
func be_zombie_eat(damage: int, attack_zombie: Zombie000Base) -> void:
	if is_zombie_mode:
		create_sun_component.drop_sun_on_zombie_mode_hp_loss(hp_component_plant.curr_hp, damage)
	super(damage, attack_zombie)

## 植物死亡
func character_death():
	if is_zombie_mode:
		create_sun_component.drop_sun_on_zombie_mode_death(hp_component_plant.curr_hp)
	super()

## 获取植物存档数据
func gat_save_game_data_plant()->Dictionary:
	var save_game_data_plant:Dictionary = super()
	save_game_data_plant["is_grow"] = is_grow

	return save_game_data_plant

## 读档植物数据
func load_game_data_plant(save_game_data_plant:Dictionary):
	super(save_game_data_plant)
	is_grow = save_game_data_plant.get("is_grow", false)
	if is_grow:
		grow_timer.stop()
		create_sun_component.change_sun_value(norm_sun_value)
		## 读档时状态机已经按初始值选过 idle 了，这里补一次显式切换
		request_anim_state(&"SunShroom_grow")
