extends MainGameItemBase
class_name BrainOnZombieMode
## 我是僵尸模式下的脑子

@onready var area_2d_detect: Area2D = $Area2DDetect

@onready var drop_item_component: DropItemComponent = %DropItemComponent
@onready var brain_body: BrainBody = $BrainBody

## 原版口径：脑子 70 口、每口 4 tick（100 Hz）= 2.8 秒吃完（`Challenge::IZombieEatBrain`）；
## 仓库僵尸啃食是连续 DPS 100（见 AttackComponentZombieNorm），按时间换算 = **280 HP**
@export var max_hp:= 280
var curr_hp :int = 280

## 第一格的植物格子，屋顶时移动y
var first_plant_cell:PlantCell
## 是否已经死亡
var is_death:=false

## 脑子死亡信号
signal signal_brain_death

func _ready() -> void:
	curr_hp = max_hp
	## 斜面与水平面的差值
	var diff_slope_flat:float = 0
	if is_instance_valid(first_plant_cell):
		diff_slope_flat = first_plant_cell.slope_step_y
	position.y += diff_slope_flat
	area_2d_detect.position.y -= diff_slope_flat

## 初始化脑子
func init_brain(curr_first_plant_cell:PlantCell):
	first_plant_cell = curr_first_plant_cell
	lane = first_plant_cell.row_col.x

## 被啃食（与植物同一口径的连续掉血：僵尸攻击组件每 8 帧结算一次 DPS）
## 原版 IZombieEatBrain 每口 -1（每 4 tick 一口），长期平均就是这条连续 DPS 路线
func be_zombie_eat(damage:int):
	_hp_loss(damage)

## 被压扁
func be_flattened():

	brain_body.be_flattened_body()
	hp_loss_to_death()

## 掉血至死亡
func hp_loss_to_death():
	_hp_loss(curr_hp)

## 掉血
func _hp_loss(value:int):
	curr_hp -= value
	if curr_hp <= 0:
		_brain_death()

## 死亡
func _brain_death():
	if is_death:
		return

	is_death = true
	drop_item_component.drop_coin()
	signal_brain_death.emit()
	queue_free()

