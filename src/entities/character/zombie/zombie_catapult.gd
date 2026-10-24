extends Zombie000Base
class_name Zombie023Catapult

## 状态三阶段时损毁烟雾
@onready var smoke: GPUParticles2D = %Smoke
@onready var death_bomb: ZamboniDeathBomb = $Body/DeathBomb

## 位置x小于该值时可以攻击：原版 `mPosX <= 650` 才进入投掷（`Zombie.cpp:1578`）
@export var global_pos_x_can_attack:float = 650
## 血量阶段 2（半血以下）的速度系数
@export var speed_factor_hp_stage_2:float = 0.5

@export_group("子弹相关")
## 最大子弹数量
@export_range(1, 100, 1) var MaxNumBullet :int = 20
## 当前发射的子弹数量
var curr_num_shoot_bullet = 0
## 子弹节点,根据发射子弹隐藏部分子弹
@export var node_bullet:Array[Node2D]
## 每颗body中的子弹代表的真实子弹数量
var num_real_bullet_node_bullet:int

@export_group("动画状态")
@export var is_caltrop:= false
## 是否到达攻击位置
var is_attack_pos := false

## 状态1时改变精灵节点
@export_group("攻击动画时pole节点变化")
@export var body_change_0:Dictionary[StringName, ResourceBodyChange] = {}
@export var body_change_1:Dictionary[StringName, ResourceBodyChange] = {}
var curr_body_pole_change_dic:Dictionary[StringName, ResourceBodyChange]

func ready_norm():
	super()
	## 默认禁用攻击组件,到达可以攻击的位置后,启用攻击组件
	attack_component.update_is_attack_factors(false, AttackComponentBase.E_IsAttackFactors.Character)
	curr_body_pole_change_dic = body_change_0
	if node_bullet.is_empty():
		num_real_bullet_node_bullet = 0
	else:
		num_real_bullet_node_bullet = int(ceil(float(MaxNumBullet) / float(node_bullet.size())))
	## 移动到攻击位置后解禁攻击（位置判定下沉到移动组件）
	move_component.watch_position_x(global_pos_x_can_attack, _on_reach_attack_pos)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	## 血量变化
	hp_stage_change_component.signal_hp_stage_change.connect(hp_stage_zamboni_change)
	attack_component = attack_component as AttackComponentBulletPultBase
	attack_component.signal_shoot_bullet.connect(update_bullet_data)

## 到达可以攻击的位置（位置判定下沉到移动组件，不再自己写 `_process`）
func _on_reach_attack_pos():
	is_attack_pos = true
	## 到达可以攻击的位置后,启用攻击组件
	attack_component.update_is_attack_factors(true, AttackComponentBase.E_IsAttackFactors.Character)

#region 攻击精灵图片变化
func update_pole_sprite_no_bullet():
	change_body_pole(curr_body_pole_change_dic["no_bullet"])

func update_pole_sprite_have_bullet():
	## 没有子弹
	if curr_num_shoot_bullet >= MaxNumBullet:
		update_pole_sprite_no_bullet()
	else:
		change_body_pole(curr_body_pole_change_dic["have_bullet"])

func change_body_pole(curr_body_pole_change:ResourceBodyChange):
	var sprite_change:Sprite2D = get_node(curr_body_pole_change.sprite_change[0])
	sprite_change.texture = curr_body_pole_change.sprite_change_texture[0]
#endregion

#region 血量变化
## 血量状态变化时zamboni的特殊变化
## 共4个变化阶段
## 0:无变化
## 1:改变body pole\损毁烟雾
## 2:速度减半\车身抖动
## 3:爆炸死亡
func hp_stage_zamboni_change(curr_hp_stage:int):
	match curr_hp_stage:
		1:
			curr_body_pole_change_dic = body_change_1
			update_pole_sprite_have_bullet()
			smoke.emitting = true
		2:
			update_speed_factor(speed_factor_hp_stage_2, E_Influence_Speed_Factor.ZamboniHp)
			## 抖动
			var tween = create_tween()
			tween.tween_property(body, "position", body.position + Vector2(1, 1), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(body, "position", body.position, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.set_loops()
		3:
			zamboni_death_effect()

## 死亡爆炸特效
func zamboni_death_effect():
	death_bomb.activate_it()
	SoundManager.play_character_SFX(&"explosion")
	queue_free()
#endregion

## 更新子弹相关
func update_bullet_data():
	curr_num_shoot_bullet += 1
	if curr_num_shoot_bullet >= MaxNumBullet:
		for n in node_bullet:
			n.visible = false
			attack_component.update_is_attack_factors(false, AttackComponentBase.E_IsAttackFactors.Character)
	else:
		if num_real_bullet_node_bullet == 0:
			return
		if curr_num_shoot_bullet % num_real_bullet_node_bullet == 0:
			node_bullet[int(float(curr_num_shoot_bullet)/num_real_bullet_node_bullet)].visible = false

## 【受击方加工包】地刺扎我 = 当场报废（同洗冰车，见 Zombie013Zamboni 的同名方法）
func process_damage(info: DamageInfo) -> bool:
	if info.has_effect(ConstDamage.EFFECT_CALTROP):
		info.is_instant_kill = true
	return super(info)

## 报废表现放在管线末端（同洗冰车，见 Zombie013Zamboni 的同名方法）
func take_damage(info: DamageInfo) -> int:
	if info.has_effect(ConstDamage.EFFECT_CALTROP):
		is_caltrop = true
		move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsAnimGap)
		_be_vehicle_backlash(info)
	return super(info)


## 【载具反伤】同洗冰车：对**发起方**打一下 0 伤害 + 一张便条，后果由它自己翻译
## （见 `Zombie013Zamboni._be_vehicle_backlash()` 的注释）
func _be_vehicle_backlash(info: DamageInfo) -> void:
	if not is_instance_valid(info.attacker):
		return
	## 显式转角色：`DamageInfo.attacker` 声明成 `Node`（它可能不是角色，也可能已经 free）
	var attacker_character := info.attacker as Character000Base
	if attacker_character == null:
		return
	var backlash := DamageInfo.create(attacker_character, 0,
		ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Crush)
	backlash.attacker = self
	backlash.trigger_sfx = false
	backlash.set_effect(ConstDamage.EFFECT_VEHICLE_BACKLASH, true)
	attacker_character.apply_damage(backlash)
