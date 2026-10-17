extends Plant000Base
class_name Plant022Caltrop

@onready var detect_component: DetectComponent = $DetectComponent

## 攻击力沿用角色基类 `Character000Base.attack_value`（本场景 .tscn 里配 20）
@export_group("动画状态")
@export var is_attack:=false
var is_flattened := false


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	detect_component.signal_can_attack.connect(func():is_attack = true)
	detect_component.signal_not_can_attack.connect(func():is_attack = false)

## 攻击一次
func _attack_once():
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
