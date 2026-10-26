extends AttackComponentBulletPultBase
class_name AttackComponentBulletCorn
## 玉米投手攻击行为组件

## 动画事件名：开火动画开始时决定这一发是玉米粒还是黄油
const ANIM_EVENT_CHOOSE_BULLET := &"choose_butter_or_corn"

## 投射黄油的概率
@export_range(0,1,0.01) var p_butter:float = 0.5
## body中的黄油节点
@export var sprite_2d_butter_in_body:Sprite2D


## 动画事件分发：本组件专属事件自己接，其余交回基类（开火等）
func _on_anim_event(event:StringName) -> void:
	if event == ANIM_EVENT_CHOOSE_BULLET:
		random_choose_butter_or_corn()
		return
	super(event)


## 随机选择黄油子弹或玉米子弹,攻击动画开始时调用
func random_choose_butter_or_corn():
	var p = randf()
	if p < p_butter:
		attack_bullet_type = BulletIds.BUTTER
		sprite_2d_butter_in_body.visible = true
	else:
		attack_bullet_type = BulletIds.CORN
		sprite_2d_butter_in_body.visible = false


func _shoot_bullet():
	super()
	sprite_2d_butter_in_body.visible = false
