extends ComponentNormBase
class_name BombComponentBase

## 爆炸检测区域,部分爆炸组件(火爆辣椒\寒冰菇)没有
## 爆炸检测区域检测敌人的受击检测框而不是受击真实框,角色移动y时,更新爆炸组件位置,更新检测框位置
@onready var area_2d_bomb: Area2D = get_node_or_null("Area2DBomb")

## 爆炸的行范围，-1 表示所有行，0表示当前行，1表示包含上下一行
@export var bomb_lane:int=-1
## 爆炸伤害
@export var bomb_value:int = 1800
## 是否为灰烬炸弹（非土豆雷）
@export var is_cherry_bomb:= true
## 死亡时是否自动引爆
@export var is_auto_bomb_in_death:bool = true
## 已经爆炸过，植物死亡时检测是否爆炸过，若没有且死亡时爆炸，则爆炸
var is_bomb:= false
## 可以攻击的敌人状态掩码组件（未在场景中配置时按炸弹组件默认值创建）
@onready var can_attack_status_component: CanAttackStatusComponent = get_node_or_null(^"CanAttackStatusComponent")

@export_group("爆炸音效")
## 攻击音效名字
@export var bomb_sfx:StringName = &"CherryBomb"

## 爆炸一次信号,毁灭菇使用
signal signal_bomb_once

func _ready() -> void:
	super()
	_ensure_can_attack_status_component()


## 确保存在可攻击状态掩码组件（未在场景中配置时按炸弹组件默认掩码创建）
func _ensure_can_attack_status_component() -> void:
	if is_instance_valid(can_attack_status_component):
		return
	can_attack_status_component = CanAttackStatusComponent.new()
	can_attack_status_component.name = "CanAttackStatusComponent"
	can_attack_status_component.can_attack_plant_status = 15
	can_attack_status_component.can_attack_zombie_status = 1
	add_child(can_attack_status_component)


## 死亡时判断是否爆炸过
func judge_death_bomb():
	if is_enabling and not is_bomb and is_auto_bomb_in_death:
		bomb_once()

## 爆炸一次
func bomb_once():
	## 可以爆炸并且还没爆炸
	if is_enabling and not is_bomb:
		is_bomb = true
		_play_bome_sfx()
		_start_bomb_fx()
		_bomb_all_enemy()
		signal_bomb_once.emit()

## 播放音效
func _play_bome_sfx():
	## 播放音效
	SoundManager.play_character_SFX(bomb_sfx)

## 爆炸特效
func _start_bomb_fx():
	pass

## 炸死所有敌人
func _bomb_all_enemy():
	pass
