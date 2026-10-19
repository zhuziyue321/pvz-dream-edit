extends ComponentNormBase
class_name CanAttackStatusComponent

## 可攻击敌人状态掩码组件
## 攻击来源（攻击检测\跳跃\炸弹\子弹\溅射\窝瓜）持有该组件，
## 统一保存「可以攻击的植物/僵尸受击状态」掩码，并提供判定方法

## 可以攻击的植物状态掩码
@export_flags("1 正常", "2 悬浮", "4 地刺", "8 低矮") var can_attack_plant_status:int = 1
## 可以攻击的僵尸状态掩码
## 注意：僵王的免疫位（64）刻意不在任何角色的默认值里，谁都不勾就永远打不到抬头的僵王。
## 128 灌木：DLC 版第 7 章 Woods 里藏在灌木丛中的僵尸。默认掩码 1 不含它 ⇒ 普通攻击天然打不到；
## 爆杀类（樱桃 / 毁灭菇 / 小丑盒 / 柠檬榴弹）与蜂射手显式勾上 128 才能打到灌木里的僵尸
@export_flags("1 正常", "2 跳跃", "4 水下", "8 空中", "16 地下", "32 跳入泳池", "64 僵王抬头", "128 灌木") var can_attack_zombie_status:int = 1

## 敌人受击状态是否在掩码内（可被攻击）
func can_attack(enemy:Character000Base) -> bool:
	## 僵王优先判定：ZB000Base 现在是 Zombie000Base 的子类，若不先短路会被上面的
	## 僵尸分支命中，而那里用「组合掩码」比较，抬头的僵王会被某些大掩码误判为可攻击
	## （典型：仙人掌低姿态那句 can_attack_zombie_status = ~8 是全掩码，能命中任意位）。
	## 僵王的受击窗口只用 IsNorm 一位表达，见 ZB000Base.set_hurt_window()。
	if enemy is ZB000Base:
		return enemy.character_init_type == Character000Base.E_CharacterInitType.IsNorm \
			and (enemy.curr_be_attack_status & Zombie000Base.E_BeAttackStatusZombie.IsNorm) != 0
	if enemy is Plant000Base:
		return (enemy.curr_be_attack_status & can_attack_plant_status) != 0
	elif enemy is Zombie000Base:
		return (enemy.curr_be_attack_status & can_attack_zombie_status) != 0
	return false
