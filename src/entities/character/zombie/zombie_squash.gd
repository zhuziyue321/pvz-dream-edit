extends Zombie000Base
class_name Zombie033Squash
## 窝瓜僵尸（原版 ZomBotany）：碰到玩家的植物就压下去，压完自己也消失（和窝瓜一样是一次性的）
##
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Squash_Zombie)

## 压扁伤害（原版窝瓜 1800，一下压死除巨人外的目标）
@export var squash_attack_value: int = 1800

## 是否已经用过（一次性）
var is_used := false


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
	target.be_attacked_bullet(squash_attack_value, BulletRegistry.AttackMode.Penetration, false, false)
	SoundManager.play_character_SFX(&"gargantuar_thump")
	## 压完自身消失（原版消耗品），不算被玩家打死，所以不掉落战利品
	character_death_disappear()
