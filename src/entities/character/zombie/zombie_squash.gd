extends Zombie001Norm
class_name Zombie033Squash
## 窝瓜僵尸（原版 ZomBotany）：碰到玩家的植物就压下去，
## 压死**目标那一格的所有植物**，压完自己也消失（和窝瓜一样是一次性的）
##
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Squash_Zombie)
##          + 原版 `Zombie::UpdateZombieSquashHead`（跳起后走 `SquishAllInSquare`，压的是整格）

## 压扁伤害（原版窝瓜 1800，一下压死除巨人外的目标）
@export var squash_attack_value: int = 1800

## 移速倍率（相对普通僵尸的均值）
##
## 原版 `Zombie::PickRandomSpeed()` 对 `ZOMBIE_SQUASH_HEAD` 单独给 0.79~0.81，
## 普通僵尸是 0.23~0.37（均值 0.3）—— 也就是 **2.6~2.7 倍速**，窝瓜僵尸是冲过来压人的。
## 走 `InitRandomSpeed` 档：它同时驱动移动 / 动画 / 啃食；普通僵尸是动画驱动位移
## （`MoveComponent.E_MoveMode.Ground`），只改 `ori_speed` 是跑不起来的。
const C_SPEED_FACTOR_RANGE := Vector2(2.6, 2.7)

## 是否已经用过（一次性）
var is_used := false


## 随机初始化角色速度（整段覆盖父类：窝瓜僵尸比普通僵尸快得多）
##
## 父类在 `ready_norm()` 里 `call_deferred("init_random_speed")`，所以覆盖这里**不会**被父类的
## 随机速度盖掉（同一档只写一次）。不要改成 `super()` 之后再改 —— 那样会白算一次随机值。
func init_random_speed() -> void:
	update_speed_factor(
		randf_range(C_SPEED_FACTOR_RANGE.x, C_SPEED_FACTOR_RANGE.y),
		E_Influence_Speed_Factor.InitRandomSpeed)


func ready_norm_signal_connect() -> void:
	super()
	attack_component.signal_change_is_attack.connect(_on_change_is_attack)


## 检测到植物（进入攻击状态）就压下去
func _on_change_is_attack(value: bool) -> void:
	if not value or is_used or is_death:
		return
	var target := attack_component.detect_component.enemy_can_be_attacked
	if not is_instance_valid(target):
		return
	is_used = true
	_squash_target_cell(target)
	SoundManager.play_character_SFX(&"gargantuar_thump")
	## 压完自身消失（原版消耗品），不算被玩家打死，所以不掉落战利品
	character_death_disappear()


## 压死**目标所在那一格的所有植物**（原版 `SquishAllInSquare`）：
## 一格可能叠着多株（南瓜壳 + 里面那株、模仿者、花盆 / 荷叶 + 植物），
## 只打检测到的那一株会漏掉其余几株。
## 拿不到格子信息时退回「只压检测到的这一株」，不因为格子缺失就白压一次。
## 读 `plant_in_cell` 一律走 `PlantCell.get_plant()`：槽位里可能是已释放对象的残留引用。
func _squash_target_cell(target: Character000Base) -> void:
	var target_plant := target as Plant000Base
	var target_cell: PlantCell = target_plant.plant_cell if target_plant != null else null
	if target_cell == null:
		target.be_attacked_bullet(squash_attack_value, ConstDamage.E_DamageMode.Penetration, false, false)
		return
	for place in target_cell.plant_in_cell:
		var plant := target_cell.get_plant(place)
		if is_instance_valid(plant) and not plant.is_death:
			plant.be_attacked_bullet(squash_attack_value, ConstDamage.E_DamageMode.Penetration, false, false)
