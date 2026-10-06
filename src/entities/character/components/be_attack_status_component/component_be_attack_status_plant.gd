extends ComponentNormBase
class_name BeAttackStatusComponentPlant

## 植物受击状态组件
## 僵尸攻击检测时，根据当前受击状态判断该植物是否可以被攻击

## 检测攻击时，根据状态判断是否可以攻击
enum E_BeAttackStatusPlant{
	IsNorm = 1,		## 正常
	IsFloat = 2,	## 悬浮
	IsDown = 4, 	## 地刺
	IsShort = 8,	## 低矮
}

## 植物初始化受击状态（从1[IsNorm] 开始）
@export var init_be_attack_status :E_BeAttackStatusPlant = E_BeAttackStatusPlant.IsNorm
## 植物当前受击状态，僵尸攻击检测时判断是否可以攻击
var curr_be_attack_status :E_BeAttackStatusPlant = E_BeAttackStatusPlant.IsNorm

## 初始化为配置的受击状态（正常出战角色初始化时调用）
func init_status() -> void:
	curr_be_attack_status = init_be_attack_status
