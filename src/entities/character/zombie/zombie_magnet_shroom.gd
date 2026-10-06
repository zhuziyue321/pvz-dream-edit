extends Zombie000Base
class_name Zombie038MagnetShroom
## 磁力菇僵尸（原版 ZomBotany）：定期把玩家的磁力菇吸走
##
## 原版这一只吸的是玩家的 Magnet-shroom（对上磁力菇才有用，所以本行没有磁力菇时它就是个普通僵尸）。
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Magnet-shroom_Zombie)

## 吸的间隔（秒）
@export var magnet_cd: float = 15.0
## 被吸走的植物类型（原版：磁力菇）
@export var magnet_plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.P032MagnetShroom

var magnet_timer: Timer


func ready_norm() -> void:
	super()
	magnet_timer = Timer.new()
	magnet_timer.wait_time = magnet_cd
	magnet_timer.timeout.connect(_on_magnet_timer_timeout)
	add_child(magnet_timer)
	magnet_timer.start()


func ready_norm_signal_connect() -> void:
	super()
	## 头顶植物被打掉后就没有磁力了（和原版表现一致：植物掉了能力也跟着没了）
	hp_component.signal_armor1_death.connect(_on_plant_head_broken)


## 头顶植物被打掉：停止吸磁力菇
func _on_plant_head_broken() -> void:
	if is_instance_valid(magnet_timer):
		magnet_timer.stop()


## 到点吸走本行玩家的磁力菇
func _on_magnet_timer_timeout() -> void:
	if is_death:
		return
	var target := _find_magnet_plant()
	if not is_instance_valid(target):
		return
	SoundManager.play_character_SFX(&"magnetshroom")
	target.be_attacked_bullet(9999, BulletRegistry.AttackMode.Penetration, false, false)


## 找到本行玩家的磁力菇（没有返回 null）
func _find_magnet_plant() -> Plant000Base:
	var all_plant_cells: Array = Global.main_game.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= all_plant_cells.size():
		return null
	for cell in all_plant_cells[lane]:
		if not is_instance_valid(cell):
			continue
		for key in cell.plant_in_cell:
			var plant := cell.plant_in_cell[key] as Plant000Base
			if is_instance_valid(plant) and not plant.is_death and plant.plant_type == magnet_plant_type:
				return plant
	return null
