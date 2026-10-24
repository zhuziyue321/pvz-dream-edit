extends Plant000Base
class_name Plant027Cactus

@export_group("动画状态")
@export var is_rise:= false
@onready var attack_component: AttackComponentBulletCactus = $AttackComponent


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)

	attack_component.signal_change_is_attack.connect(
		func(_value):
			## ★ 起 / 落动画由本脚本点名（两条转换已改为手动 travel，见 `plant_cactus.tscn`）
			## ⚠️ 只在 `is_rise` **真的变化**时切换：`Cactus_rise` 只能从低位攻击状态
			##    （BlendTree）过去、`Cactus_lower` 只能从高位（BlendTree 2）过去，
			##    每帧都 request 会在另一个状态下 travel 失败（静默）
			var rise_now: bool = attack_component.detect_component.judge_zombie_in_sky()
			if rise_now != is_rise:
				is_rise = rise_now
				request_anim_state(&"Cactus_rise" if is_rise else &"Cactus_lower")
			attack_component.on_cactus_update_is_rise(is_rise)
	)


## 起落动画开始，设置不能攻击
func anim_rise_start():
	attack_component.update_is_attack_factors(false, AttackComponentBase.E_IsAttackFactors.Anim)


## 起落动画结束，设置可以攻击
func anim_rise_end():
	attack_component.update_is_attack_factors(true, AttackComponentBase.E_IsAttackFactors.Anim)
	attack_component.update_bullet_can_attack_zombie_status(is_rise)
