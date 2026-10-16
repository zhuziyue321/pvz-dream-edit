extends Plant000Base
class_name Plant047SpikeRock

@onready var detect_component: DetectComponent = $DetectComponent

@export var attack_value:=20
@export_group("动画状态")
@export var is_attack:=false

@onready var hp_stage_change_component: HpStageChangeComponent = $HpStageChangeComponent

## 载具反伤（扎爆一辆车）时自己掉的血：原版口径 —— 钢地刺扛得住，不像地刺那样直接报废。
## 走 `@export` 而不是脚本常量：数值归场景配，与 `attack_value` 同一层
@export var vehicle_backlash_damage: int = 50


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	detect_component.signal_can_attack.connect(func():is_attack = true)
	detect_component.signal_not_can_attack.connect(func():is_attack = false)

	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)

## 攻击一次
func _attack_once():
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
	## 被碾压掉 1/9 上限血：走伤害管线（碾压语义），别直接调血量组件的结算函数
	var self_info := DamageInfo.create(self, int(hp_component.max_hp / 9.0),
		ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Crush)
	apply_damage(self_info)
