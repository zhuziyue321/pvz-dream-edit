extends Zombie000Base
class_name Zombie034Jalapeno
## 火爆辣椒僵尸（原版 ZomBotany）：碰到植物就烧掉**整行**，烧完自己也消失（和辣椒一样是一次性的）
##
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Jalapeno_Zombie)

## 烧毁伤害（原版火爆辣椒 1800）
@export var burn_attack_value: int = 1800

## 是否已经用过（一次性）
var is_used := false


func ready_norm_signal_connect() -> void:
	super()
	attack_component.signal_change_is_attack.connect(_on_change_is_attack)


## 检测到植物（进入攻击状态）就烧掉本行
func _on_change_is_attack(value: bool) -> void:
	if not value or is_used or is_death:
		return
	is_used = true
	_burn_lane()
	SoundManager.play_character_SFX(&"explosion")
	## 烧完自身消失（原版消耗品）
	character_death_disappear()


## 烧掉本行所有植物
func _burn_lane() -> void:
	var all_plant_cells: Array = Global.main_game.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= all_plant_cells.size():
		Log.error("火爆辣椒僵尸的行号越界：" + str(lane))
		return
	for cell in all_plant_cells[lane]:
		if not is_instance_valid(cell):
			continue
		for key in cell.plant_in_cell:
			var plant = cell.plant_in_cell[key]
			if is_instance_valid(plant) and not plant.is_death:
				plant.be_attacked_bullet(burn_attack_value, BulletRegistry.AttackMode.Penetration, false, false)
