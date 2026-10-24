extends Plant000Base
class_name Plant022Caltrop

@onready var detect_component: DetectComponent = $DetectComponent

## 攻击力沿用角色基类 `Character000Base.attack_value`（本场景 .tscn 里配 20）
@export_group("动画状态")
@export var is_attack:=false
var is_flattened := false

## 一轮攻击的周期（秒）：原版 `UpdateSpikeweed()` 固定把 `mStateCountdown` 设成 100 tick
## = **1 秒**，与动画长度无关（`Plant.cpp:1277`）。
const ATTACK_PERIOD := 1.0
## 一轮内的结算时刻（秒）：地刺在第 75 tick（0.25 秒）结算一次（`Plant.cpp:1297`）
@export var attack_hit_times: Array[float] = [0.25]

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
## ★ 动画状态由本脚本**点名**（这是"单人由植物代码控制动画"的试点）：
##   该植物动画树里 `Caltrop_idle ↔ BlendTree` 两条转换的 `advance_expression` 已清空
##   （见 `plant_caltrop.tscn`），不再由动画树自己读 `is_attack` 推导。
##   状态名就是动画树里状态名，写错会在 `request_state()` 里打 WARN，而不是静默不动。
func ready_norm_signal_connect():
	super()
	detect_component.signal_can_attack.connect(_on_can_attack)
	detect_component.signal_not_can_attack.connect(_on_not_can_attack)


## 检测到可攻击目标：播扎击（`is_attack` 保留给外部查询与旧逻辑兼容）
func _on_can_attack():
	if is_attack:
		return
	is_attack = true
	request_anim_state(&"BlendTree")
	_start_attack_cycle()


## 没有可攻击目标：回到待机
func _on_not_can_attack():
	is_attack = false
	_stop_attack_cycle()
	request_anim_state(&"Caltrop_idle")


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


## 动画方法轨的调用点：**只做表现，不结算**。
## 结算时机由 `_deal_damage()` 按原版 tick 口径排（原版同样把动画和结算拆开），
## 这里留空是为了让一轮不被结算两次。
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
			## 【伤害方写包】伤害 + 一张"我是地刺"的便条 `EFFECT_CALTROP`。
			## 便条本身不产生任何后果 —— 谁怕地刺谁自己翻译（见各僵尸的 `process_damage()`）：
			## 洗冰车 / 投石车 → 秒杀，并反过来打发起者一下（载具反伤）；巨人 → 整个包取消；
			## 其余（含雪橇车小队）不认识 → 只正常挨 20 点。
			## 地刺自己从头到尾不知道"洗冰车"是谁（硬约束 §1-8）。
			var info := DamageInfo.create(zombie, attack_value,
				ConstDamage.E_DamageMode.Real, ConstDamage.E_DamageCause.Bullet)
			info.set_effect(ConstDamage.EFFECT_CALTROP, true)
			## 必须写上发起者：车辆挨扎后会照 `attacker` 打回来一下（载具反伤），
			## 没写它就没得可打，扎爆车的自损也就不会发生
			info.attacker = self
			var result := zombie.apply_damage(info)
			## 打中了才闪白光（原来是无条件闪，被免疫了也闪）
			if result.is_applied:
				zombie.be_hit_light()
				## 扎爆车会引来回一下反伤 → 本棵地刺可能当场报废，那就别再扎后面的了
				if is_death:
					break

## 【受击方加工包】载具反伤（原版行为：地刺扎爆车辆后自己也报废）。
##
## 车打回来的是**0 伤害** —— 它不决定后果，只递一张 `EFFECT_VEHICLE_BACKLASH` 便条；
## 受损多少是**我自己**写进包里的：地刺扛不住，直接置秒杀，走正常死亡流程消失。
## 车从头到尾不知道它是把"地刺"扎废了（硬约束 §1-8）。
func process_damage(info: DamageInfo) -> bool:
	if info.has_effect(ConstDamage.EFFECT_VEHICLE_BACKLASH):
		info.is_instant_kill = true
		info.is_drop_on_death = false
	return super(info)

## 被压扁
## [character:Character000Base] 发动攻击的角色
func be_flattened_from_enemy(character:Character000Base):
	if not is_flattened:
		is_flattened = true
		## 【伤害方写包】被压扁时反扎：同样是塞 `EFFECT_CALTROP` 便条，后果由受击方翻译。
		## 洗冰车 / 投石车**不会**压到地刺（它们的碾压检测刻意不勾"地刺"位，
		## 见 `AttackComponentZombieZamboni` 文件头），它们是被上面的 `_attack_once()`
		## 主动扎爆的 —— 那条路不压扁地刺。目前会压到地刺的只剩巨人，而它自己
		## 在 `process_damage()` 里取消了整包（免疫地刺），所以这里只是留着通用语义：
		## 谁压我我就扎谁，加一种怕地刺的角色只要它自己重写 `process_damage()`（硬约束 §1-8）。
		var info := DamageInfo.create(character, attack_value,
			ConstDamage.E_DamageMode.Real, ConstDamage.E_DamageCause.Script)
		info.set_effect(ConstDamage.EFFECT_CALTROP, true)
		info.attacker = self
		info.trigger_sfx = false
		## 被压扁是"连带伤害"不是"被打死"，沿用原 `be_caltrop()` 的不掉落口径
		info.is_drop_on_death = false
		character.apply_damage(info)
		super(character)
