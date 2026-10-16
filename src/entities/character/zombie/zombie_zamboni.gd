extends Zombie000Base
class_name Zombie013Zamboni

## 状态三阶段时损毁烟雾
@onready var smoke: GPUParticles2D = %Smoke
@onready var death_bomb: ZamboniDeathBomb = $Body/DeathBomb

## 冰道
@onready var ice_road: IceRoad = $IceRoad

@export_group("动画状态")
@export var is_caltrop:= false

## 僵尸上一帧和当前帧位置(更新冰道使用)
var zombie_last_x:float
var zombie_curr_x:float

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	hp_stage_change_component.signal_hp_stage_change.connect(hp_stage_zamboni_change)
	hp_component.signal_hp_component_death.connect(func():ice_road.start_disappear_timer())

## 初始化正常出战角色
func ready_norm():
	super()
	## 将冰道放置于游戏背景上
	var main_game :MainGameManager = get_tree().current_scene
	ice_road.reparent(main_game.background_manager.background)
	ice_road.ice_road_init(lane)
	zombie_last_x = global_position.x

## 初始化展示角色
func ready_show():
	super()
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
	zombie_last_x = global_position.x

func _process(_delta: float) -> void:
	zombie_curr_x = global_position.x
	if zombie_curr_x != zombie_last_x and is_instance_valid(ice_road):
		ice_road.expand_size(zombie_last_x - zombie_curr_x)
		zombie_last_x = zombie_curr_x


## 血量状态变化时zamboni的特殊变化
## 共4个变化阶段
## 0:无变化
## 1:损毁烟雾\速度减半
## 2:停止移动\车身抖动
## 3:爆炸死亡
func hp_stage_zamboni_change(curr_hp_stage:int):
	match curr_hp_stage:
		1:
			smoke.emitting = true
			update_speed_factor(0.5, E_Influence_Speed_Factor.ZamboniHp)
		2:
			update_speed_factor(0, E_Influence_Speed_Factor.ZamboniHp)
			## 停止移动,抖动
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

## 【受击方加工包】地刺扎我 = 当场报废（原版行为：洗冰车压到地刺上直接散架）。
##
## 把这张便条翻译成"秒杀"（`is_instant_kill`），剩下的交给系统正常结算 —— 死亡流程、
## 爆炸特效、冰道消失全按正常死亡走一遍。改前是 `character_death_not_disappear()`
## 直接清空血量，那条路绕过了管线（免疫 / 统计 / 联机都会漏），现在统一走 `DamageSystem`。
func process_damage(info: DamageInfo) -> bool:
	if info.has_effect(ConstDamage.EFFECT_CALTROP):
		info.is_instant_kill = true
	return super(info)

## 报废表现放在**管线末端**而不是加工阶段：加工阶段只决定"伤害该是多少"，
## 这里才是"伤害真的结算了"。否则修饰器取消掉这次伤害时，动画已经切成报废状态，
## 会留下"车还在跑却是散架姿势"的视觉 bug。
func take_damage(info: DamageInfo) -> int:
	if info.has_effect(ConstDamage.EFFECT_CALTROP):
		is_caltrop = true
		move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsAnimGap)
		_be_vehicle_backlash(info)
	return super(info)


## 【载具反伤】被地刺类扎到 → 反过来对**发起方**打一下（**0 伤害**，只是递一张便条）。
##
## 0 伤害不是"打不动"，是"我不决定后果"：车压根不知道扎它的是地刺还是钢地刺，
## 受损多少是**受击方**在加工阶段自己写进 `effects[EFFECT_DAMAGE]` 的（硬约束 §1-8）。
## 没有发起者（天降 / 脚本伤害）就不反伤 —— 没得可打。
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
