extends Zombie000Base
class_name Zombie019Pogo
## 跳跳僵尸初始化时禁用攻击组件,使用DetectComponentPogo检测植物,若有植物,弹跳两次跳过该植物

## 我是僵尸模式取消跳跃的位置
@export var eat_brain_glo_pos_x_in_zombie_mode:float = 50

@onready var detect_component_pogo: DetectComponent = $DetectComponentPogo
@onready var body_correct: Node2D = $Body/BodyCorrect

var tween_pogo:Tween
## 一次弹跳的时间：原版 `POGO_BOUNCE_TIME = 80` tick @100 Hz = **0.8 秒**（`Zombie.cpp:60`）
@export var time_pogo_once_default:float = 0.8
## 一次弹跳需要的时间
var time_pogo_once:float = time_pogo_once_default
## 上下弹跳的值
@export var pogo_y_defalut :float= 30
var pogo_y :float= 30
## 当前跳跳僵尸的速度,影响弹跳tween
var speed_scale_pogo:float = 1
## 当遇到植物时弹跳的次数,弹跳两次触发大跳
var pogo_time_on_plant := 0
## 跳跃是否被高坚果停止
var is_jump_stop:=false
@export_group("动画状态")
## 是否为跳跳状态
@export var is_pogo := true
## 是否为大跳状态
var is_big_pogo := false

func ready_norm():
	super()
	time_pogo_once = time_pogo_once_default
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	## 跳跳状态下检测到植物停止移动,弹跳两次后移动
	detect_component_pogo.signal_can_attack.connect(pogo_ray_enemy)
	## 我是僵尸模式：跳到脑子位置就失去跳跳棒（位置判定下沉到移动组件，不再自己写 `_process`）
	if is_zombie_mode:
		move_component.watch_position_x(eat_brain_glo_pos_x_in_zombie_mode, _on_reach_eat_brain)


## 到达脑子位置
func _on_reach_eat_brain():
	if is_pogo:
		loss_iron_item()

## 检测到敌人时
func pogo_ray_enemy():
	## 非大跳状态并且敌人在左边时
	if not is_big_pogo and \
	detect_component_pogo.enemy_can_be_attacked.global_position.x < global_position.x:
		move_component.update_only_move_speed(0)


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	hp_component.signal_hp_component_death.connect(loss_iron_item)
	signal_update_speed.connect(_on_update_speed)

## 失去铁器道具的影响
func loss_iron_item():
	super()
	is_pogo = false
	move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
	attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)

## 开始起跳
func pogo_start():
	is_big_pogo = false
	## 如果有敌人
	if detect_component_pogo.enemy_can_be_attacked and \
	detect_component_pogo.enemy_can_be_attacked.global_position.x < global_position.x:
		pogo_time_on_plant += 1
		if pogo_time_on_plant > 2:
			pogo_time_on_plant = 0
			if is_jump_stop:
				loss_iron_item()
				return
			else:
				is_big_pogo = true
				move_component.update_only_move_speed(4)
				pogo_y = pogo_y_defalut * 2
		else:
			move_component.update_only_move_speed(0)
			pogo_y = pogo_y_defalut
	else:
		move_component.update_only_move_speed(1)
		pogo_y = pogo_y_defalut

	if tween_pogo != null:
		tween_pogo.kill()

	SoundManager.play_character_SFX(&"pogo_zombie")

	tween_pogo = get_tree().create_tween()
	tween_pogo.set_speed_scale(speed_scale_pogo)
	#tween_pogo.set_parallel()
	tween_pogo.tween_property(body_correct, ^"position:y", body_correct.position.y-pogo_y, time_pogo_once*2/5).set_ease(Tween.EASE_OUT)
	tween_pogo.tween_property(body_correct, ^"position:y", body_correct.position.y, time_pogo_once*3/5).set_ease(Tween.EASE_IN)

## 更新速度时同时修改弹跳的tween
func _on_update_speed(speed_factor_product:float):
	#time_pogo_once = time_pogo_once_default * speed_factor_product
	speed_scale_pogo = speed_factor_product

	if tween_pogo != null:
		tween_pogo.set_speed_scale(speed_scale_pogo)

## 跳跃被强行停止,高坚果调用
func jump_be_stop(_plant:Plant000Base):
	is_jump_stop = true
