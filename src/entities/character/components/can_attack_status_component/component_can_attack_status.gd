extends ComponentNormBase
class_name CanAttackStatusComponent

## 可攻击敌人状态掩码组件
## 攻击来源（攻击检测\跳跃\炸弹\子弹\溅射\窝瓜）持有该组件，
## 统一保存「可以攻击的植物/僵尸受击状态」掩码，并提供判定方法

## 可以攻击的植物状态掩码
@export_flags("1 正常", "2 悬浮", "4 地刺", "8 低矮") var can_attack_plant_status:int = 1
## 可以攻击的僵尸状态掩码
@export_flags("1 正常", "2 跳跃", "4 水下", "8 空中", "16 地下", "32 跳入泳池") var can_attack_zombie_status:int = 1

## 敌人受击状态是否在掩码内（可被攻击）
func can_attack(enemy:Character000Base) -> bool:
	if enemy is Plant000Base:
		return (enemy.curr_be_attack_status & can_attack_plant_status) != 0
	elif enemy is Zombie000Base:
		return (enemy.curr_be_attack_status & can_attack_zombie_status) != 0
	elif enemy is ZB000Base:
		## 僵王没有受击状态枚举，受击窗口由状态机直接控制（见 ZB000Base.hurt_box_component）；
		## 这里只校验出战状态，并要求攻击者至少能打到「正常」状态的僵尸。
		return enemy.character_init_type == Character000Base.E_CharacterInitType.IsNorm \
			and (can_attack_zombie_status & Zombie000Base.E_BeAttackStatusZombie.IsNorm) != 0
	return false
