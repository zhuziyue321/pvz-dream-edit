extends Plant000Base
class_name Plant047SpikeRock

@onready var detect_component: DetectComponent = $DetectComponent

## 攻击力沿用角色基类 `Character000Base.attack_value`（本场景 .tscn 里配 20）
@export_group("动画状态")
@export var is_attack:=false

@onready var hp_stage_change_component: HpStageChangeComponent = $HpStageChangeComponent

## 载具反伤（扎爆一辆车）时自己掉的血：原版口径 —— 钢地刺扛得住，不像地刺那样直接报废。
## 走 `@export` 而不是脚本常量：数值归场景配，与 `attack_value` 同一层
@export var vehicle_backlash_damage: int = 50
## 被碾压时自己掉的血占血量上限的比例（原版 1/9）：`off_ice_road` 一类的持续 / 比例掉血同理归场景配
@export var flatten_self_damage_ratio: float = 1.0 / 9.0

## 一轮攻击的周期（秒）：原版 `UpdateSpikeweed()` 固定 100 tick = **1 秒**
## （`Plant.cpp:1277`，钢地刺走同一个函数）
const ATTACK_PERIOD := 1.0
## 一轮内的结算时刻（秒）：钢地刺在第 70 / 32 tick 各结算一次 = 0.3 秒 / 0.68 秒，
## 即 20 + 20 点 / 秒（`Plant.cpp:1292`）
@export var attack_hit_times: Array[float] = [0.3, 0.68]

## 周期计时器
var _cycle_timer: Timer
## 一轮内的结算计时器（每个时刻一个）
var _hit_timers: Array[Timer] = []


func ready_norm():
	super()
	_setup_attack_timers()


## 按原版 tick 口径搭计时器：动画只负责表现，结算时刻由这里排
func _setup_attack_timers() -> void:
	_cycle_timer = Timer.new()
	_cycle_timer.one_shot = false
	_cycle_timer.wait_time = ATTACK_PERIOD
	_cycle_timer.timeout.connect(_on_cycle_timeout)
	add_child(_cycle_timer)

	for hit_time: float in attack_hit_times:
		var hit_timer := Timer.new()
		hit_timer.one_shot = true
		hit_timer.wait_time = hit_time
		hit_timer.timeout.connect(_deal_damage)
		add_child(hit_timer)
		_hit_timers.append(hit_timer)


## 初始化正常出战角色信号连接
##
## ★ 动画状态由本脚本点名（该植物动画树两条转换已改为手动 travel，
##   见 `plant_spike_rock.tscn`），不再由 `is_attack` 表达式自动推导。
func ready_norm_signal_connect():
	super()
	detect_component.signal_can_attack.connect(_on_can_attack)
	detect_component.signal_not_can_attack.connect(_on_not_can_attack)

	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)

## 检测到可攻击目标：播扎击（结算时机由 `_deal_damage` 按原版 tick 口径排）
func _on_can_attack():
	if is_attack:
		return
	is_attack = true
	request_anim_state(&"SpikeRock_attack")
	_start_attack_cycle()

## 没有可攻击目标：回待机
func _on_not_can_attack():
	is_attack = false
	_stop_attack_cycle()
	request_anim_state(&"SpikeRock_idle")


## 开一轮：周期计时 + 本轮每一拍的结算计时同时起步
func _start_attack_cycle() -> void:
	if not is_instance_valid(_cycle_timer):
		return
	_cycle_timer.start()
	_restart_hit_timers()


## 停一轮（没有目标 / 植物不在战斗场景时）
func _stop_attack_cycle() -> void:
	if is_instance_valid(_cycle_timer):
		_cycle_timer.stop()
	for hit_timer: Timer in _hit_timers:
		hit_timer.stop()


## 一轮到点：重开本轮结算
func _on_cycle_timeout() -> void:
	if not is_attack:
		return
	_restart_hit_timers()


func _restart_hit_timers() -> void:
	for hit_timer: Timer in _hit_timers:
		hit_timer.start()


## 动画方法轨的调用点：**只做表现，不结算**（同 `Plant022Caltrop`，
## 一轮内的结算由 `attack_hit_times` 排，避免同一次扎击被结算两次）
func _attack_once() -> void:
	pass


## 结算一拍：扎当前检测框里所有能扎的敌人
func _deal_damage():
	SoundManager.play_character_SFX("Throw")
	var all_enemy_can_be_attacked = detect_component.get_all_enemy_can_be_attacked()
	for i in range(all_enemy_can_be_attacked.size() - 1, -1, -1):
		var enemy:Character000Base = all_enemy_can_be_attacked[i]
		if enemy is Zombie000Base:
			var zombie = enemy as Zombie000Base
			## 【伤害方写包】同地刺：伤害 + "我是地刺"便条，后果由受击方自己翻译
			var info := DamageInfo.create(zombie, attack_value,
				ConstDamage.E_DamageMode.Real, ConstDamage.E_DamageCause.Bullet)
			info.set_effect(ConstDamage.EFFECT_CALTROP, true)
			## 写上发起者：车辆挨扎后会照 `attacker` 打回来一下（载具反伤）
			info.attacker = self
			var result := zombie.apply_damage(info)
			if result.is_applied:
				zombie.be_hit_light()
				## 扎爆车会引来回一下反伤 → 本棵钢地刺可能被自己扎死，那就别再扎后面的了
				if is_death:
					break

## 【受击方加工包】载具反伤（原版行为：钢地刺扎爆车辆后自己掉一截血）。
##
## 车打回来的是**0 伤害** —— 它只递一张 `EFFECT_VEHICLE_BACKLASH` 便条，不决定后果；
## 受损多少是**我自己**填进包里的（`effects[EFFECT_DAMAGE]`）：钢地刺结实，按
## `vehicle_backlash_damage` 扣一截就行。车不知道它扎的是谁（硬约束 §1-8）。
##
## 只改包、不碰血量：真正的扣血由系统在 ③ 做，死亡 / 掉落 / 联机事件一样都不少。
func process_damage(info: DamageInfo) -> bool:
	if info.has_effect(ConstDamage.EFFECT_VEHICLE_BACKLASH):
		info.amount = vehicle_backlash_damage
		info.mode = ConstDamage.E_DamageMode.Norm
		info.is_drop_on_death = false
	return super(info)

## 被压扁
## [character:Character000Base] 发动攻击的角色
func be_flattened_from_enemy(character:Character000Base):
	## 【伤害方写包】与地刺同一张便条：后果由受击方自己翻译（见 Plant022Caltrop 的同名方法）。
	## 洗冰车 / 投石车不会压到钢地刺（碾压检测不勾"地刺"位），它们是被 `_attack_once()` 扎爆的
	var info := DamageInfo.create(character, attack_value,
		ConstDamage.E_DamageMode.Real, ConstDamage.E_DamageCause.Script)
	info.set_effect(ConstDamage.EFFECT_CALTROP, true)
	info.attacker = self
	info.trigger_sfx = false
	info.is_drop_on_death = false
	character.apply_damage(info)
	## 被碾压按比例掉上限血：走伤害管线（碾压语义），别直接调血量组件的结算函数
	var self_info := DamageInfo.create(self, int(hp_component.max_hp * flatten_self_damage_ratio),
		ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Crush)
	apply_damage(self_info)
