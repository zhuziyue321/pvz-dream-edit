extends Plant000Base
class_name Plant007Chomper

@onready var detect_component: DetectComponent = $DetectComponent

## 咀嚼时间计时器
@onready var chew_timer: Timer = $ChewTimer
## 吞噬小体型僵尸后的咀嚼时间
@export var eat_CD :float = 40

@export_group("动画状态")
## 是否啃咬
@export var is_bite := false
## 是否咀嚼（只有整只吞下小体型僵尸才会进入）
@export var is_chewing = false


func ready_norm() -> void:
	super()
	## 咀嚼计时器
	chew_timer.wait_time = eat_CD
	## 啃咬伤害取角色攻击力（场景里配 20），漏配会静默打不出伤害
	if attack_value <= 0:
		Log.error(name, "大嘴花攻击力未配置（attack_value <= 0），啃咬将不造成伤害")

func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(owner_update_speed)
	detect_component.signal_can_attack.connect(change_is_attack.bind(true))
	detect_component.signal_not_can_attack.connect(change_is_attack.bind(false))

## 速度改变
## ⚠️ `wait_time` 必须**无条件**更新：关卡倍率（speed_factor_plant）在植物刚进场、
## 计时器还没启动时就下发，只在「计时器跑着」时才改会把这次倍率漏掉
## （同 `AttackComponentBulletBase.owner_update_speed` 的那条注释）
func owner_update_speed(speed_product:float):
	if speed_product == 0:
		chew_timer.paused = true
		return
	chew_timer.paused = false
	## 剩余时间按新倍率折算；计时器没跑（还没开始咀嚼）时不用管
	if not chew_timer.is_stopped():
		chew_timer.start(chew_timer.time_left / speed_product)
	chew_timer.wait_time = eat_CD / speed_product

## 改变是否正在攻击,即攻击范围内是否有敌人
## [param is_attack] true: 检测到可攻击敌人；false: 范围内已经没有目标（敌人死了 / 走了）
func change_is_attack(is_attack:bool):
	if is_attack:
		## 不在咀嚼状态,并且不在啃咬状态
		if not is_chewing and not is_bite:
			is_bite = true
	elif not is_chewing:
		## 目标消失就把咬的意图收回去，避免对着空气咬一口
		is_bite = false

## 咀嚼完成
func _on_chew_timer_timeout() -> void:
	is_chewing = false
#endregion

#region 动画轨道调用
## 吞咽动画结束
func swallow_end():
	if is_instance_valid(detect_component.enemy_can_be_attacked):
		is_bite = true

## 啃咬动画结束
func bite_end():
	is_bite = false
	## 如果没有啃咬到僵尸
	if not is_chewing:
		if is_instance_valid(detect_component.enemy_can_be_attacked):
			is_bite = true
#endregion

## 大嘴花咬一口,动画调用
##
## 小 / 中体型僵尸整只吞下（秒杀 + 咀嚼）；大体型（巨人）只咬一口，伤害取角色攻击力 `attack_value`。
## ⚠️ `is_chewing` 只在**真的吞下去**时才置真：目标在咬的前摇里被别的植物打死 / 走出检测框时，
## 计时器不会启动，置真就再也回不来了（状态机永远停在咀嚼循环）。
func _eat_zombie():
	## 播放音效
	SoundManager.play_character_SFX(&"BigChomp")
	## 取当前最靠前的敌人：检测框的重叠列表顺序不保证按 x 排序，
	## 直接读 `enemy_can_be_attacked` 可能吃到后面那只（本方法会顺带刷新它）
	var zombie := detect_component.update_first_enemy() as Zombie000Base
	if not is_instance_valid(zombie):
		return
	if zombie.is_small_or_medium_body():
		## 吞噬：伤害值不参与结算，由伤害管线的秒杀把防具与本体一起清空
		zombie.be_chomper_eat(0, true)
		chew_timer.start()
		is_chewing = true
	else:
		## 啃咬：伤害就是角色攻击力，不进入咀嚼
		zombie.be_chomper_eat(attack_value)
