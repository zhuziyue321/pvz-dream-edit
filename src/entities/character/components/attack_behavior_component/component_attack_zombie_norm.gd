extends AttackComponentBase
class_name AttackComponentZombieNorm
## 普通僵尸攻击组件
##
## 啃食是**持续伤害**：每 `EAT_SETTLE_FRAME_INTERVAL` 帧把这段时间累积的伤害一次性结算
## （走 `be_zombie_eat()` → `DamageSystem`，不是每帧都发一个伤害包）。

@export_group("每秒伤害值")
## 啃食**每秒伤害**（HP/秒）。
##
## 原版口径（`../PvZ-Portable-main/src/Lawn/Zombie.cpp`）：`DAMAGE_PER_EAT = 4` 点、
## 每 `TICKS_BETWEEN_EATS = 4` tick 咬一口，游戏固定 100 Hz（`mFrameTime = 10`）
## → 4 × 100 ÷ 4 = **100 点/秒**（300 HP 的植物 3 秒吃完、坚果 4000 HP 40 秒）。
##
## ⚠️ 本字段 2026-10-23 前叫 `init_attack_value_per_min`（"每分钟"），那是**误称**：
## 见 `settle_eat_damage()` —— `curr * delta * EAT_SETTLE_FRAME_INTERVAL` 每 8 帧结算一次，
## 8/60 秒打 8/60 × curr 点，长期平均正好是**每秒** curr 点。
@export var init_attack_value_per_sec :int = 100

## 当前每秒伤害（受死亡 / 速度 / 报纸掉落 / 舞王入场 / 缩小等因子影响）
var curr_attack_value_per_sec :int = 100

enum E_AttackValueFactor{
	Death,			## 死亡，攻击力置为0
	Speed,			## 攻击速度，
	PaperDrop,		## 报纸掉落，攻击力翻倍
	JacksonEnter,	## 舞王入场时,攻击值为0
	Shrink,			## 缩小紫罗兰：被缩小时啃咬伤害降低
}

var attack_value_factor:Dictionary[E_AttackValueFactor, float] = {}

## 旧名兼容（**已废弃**）：第三方模组 / 探针仍可能读写 `curr_attack_value_per_min`，
## 这里转发到新字段，保证旧模组不炸。新代码一律用 `curr_attack_value_per_sec`。
var curr_attack_value_per_min :int:
	get:
		return curr_attack_value_per_sec
	set(value):
		curr_attack_value_per_sec = value

## 啃食结算的帧间隔：不是每帧都走伤害管线，而是每 N 帧把这 N 帧累积的伤害一次性结算。
## `wrapi` 的周期与下面的 `delta * N` 必须同源，否则实际 DPS 会偏 —— 见 docs/TODO清单.md U-44。
const EAT_SETTLE_FRAME_INTERVAL := 8

## 间隔帧数
var frame_counter := 0

## 两次结算之间被 `int()` 截掉的零头（不足 1 点的一部分）：
## 下一次补上，保证长期平均正好等于 `curr_attack_value_per_sec`
## （不攒的话 100 点/秒每次结算 13.33 被截成 13，实际只有 97.5 点/秒）。
var _eat_damage_carry := 0.0


func component_ready() -> void:
	super()
	curr_attack_value_per_sec = init_attack_value_per_sec

## 修改攻击速度,通过修改攻击值实现
func owner_update_speed(speed_product:float):
	update_attack_value(speed_product, E_AttackValueFactor.Speed)

## 修改攻击值
func update_attack_value(value:float, influence_factor:E_AttackValueFactor):
	attack_value_factor[influence_factor] = value
	var res_product = GlobalUtils.get_dic_product(attack_value_factor)
	curr_attack_value_per_sec = int(init_attack_value_per_sec * res_product)

func _physics_process(delta: float) -> void:
	if is_enabling and is_attack_res:
		frame_counter = wrapi(frame_counter + 1, 0, EAT_SETTLE_FRAME_INTERVAL)
		## 目标既不是植物也不是脑子时不结算（与原来「没有目标就整帧跳过」等价）
		if not is_instance_valid(detect_component.enemy_can_be_attacked) \
				and not is_instance_valid(detect_component.brain):
			return
		if frame_counter == 0:
			var eat_damage := settle_eat_damage(delta)
			## 0 点不发包：`DamageSystem` 那边同样会以 ZeroAmount 取消，这里省一次派发
			if eat_damage > 0:
				if is_instance_valid(detect_component.enemy_can_be_attacked):
					detect_component.enemy_can_be_attacked.be_zombie_eat(eat_damage, owner)
				else:
					## 目标是脑子：原版 `Challenge::IZombieEatBrain` 每口 -1（每 4 tick 一口），
					## 长期平均与啃植物的连续 DPS 同源 —— 走同一条结算路线，脑子按时间掉血
					detect_component.brain.be_zombie_eat(eat_damage)


## 结算本轮啃食伤害（**含零头累加**），返回这次该打进伤害管线的点数（可能为 0）。
##
## 梯子僵尸那份复制过去的 `_physics_process()` 也调本函数，避免两处各算一套 DPS。
func settle_eat_damage(delta: float) -> int:
	_eat_damage_carry += curr_attack_value_per_sec * delta * EAT_SETTLE_FRAME_INTERVAL
	var damage := int(_eat_damage_carry)
	_eat_damage_carry -= float(damage)
	return damage


## 攻击一次发亮，动画调用
func attack_once():
	if is_instance_valid(detect_component.enemy_can_be_attacked) and not owner.is_death:
		detect_component.enemy_can_be_attacked.be_zombie_eat_once(owner)
		SoundManager.play_character_SFX("Chomp")
	elif is_instance_valid(detect_component.brain):
		#detect_component = detect_component as DetectComponentZombie
		## 啃咬伤害已走上面的连续结算（原版口径），这里只剩音效 —— 动画方法轨的一次「口」
		SoundManager.play_character_SFX("Chomp")

