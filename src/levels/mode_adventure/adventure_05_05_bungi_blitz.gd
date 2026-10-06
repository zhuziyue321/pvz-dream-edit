extends Node
## 蹦极闪电战（冒险 5-5 专属）—— 只由 adventure_05_05.gd 创建并驱动
class_name Adventure0505BungiBlitz

"""
蹦极闪电战（原版冒险 5-5 传送带关，见 docs/参考存档/特殊关卡.md「蹦极闪电战」）：
本关**不直接出怪**，僵尸全部由蹦极僵尸「空投」进场。

	正常波次 -> 空投僵尸的蹦极僵尸 Z026BungiDrop 把僵尸吊到场上再放下
	大波     -> 本波照常空投，另外还来一批**偷植物**的蹦极僵尸 Z021Bungi
	            （走 ResourceLevelData.is_bungi 的大波空投，见 ZombieWaveCreateManager.spawn_bungi_zombies）

本关的僵尸清单还是按原版的战力上限来算（见 ZombieWaveCreateManager），
只是「进场方式」从场地边缘走进来改成空投 —— 改的是怎么进场，不是出什么怪。

挂在关卡脚本这一侧的理由（硬约束 §1-8）：只有 5-5 这一关用，本体不该常驻这个玩法。
"""

## 空投落点最靠左的允许列（再靠左就直接贴脸房子，玩家来不及反应）
@export var min_drop_col := 2

## 宿主僵尸管理器：由关卡脚本在 init_level_items() 里接进来
var zombie_manager: ZombieManager


## 接上本关的僵尸管理器（关卡脚本创建本节点后调用一次）
func init_bungi_blitz(zm: ZombieManager) -> void:
	zombie_manager = zm
	Log.debug("蹦极闪电战开启：本关僵尸全部由蹦极僵尸空投进场")


#region 空投本波僵尸

## 生成本波僵尸：不从场地边缘走进来，每只都由一只空投蹦极僵尸吊进来
## [wave_spawn] 本波按战力算出来的僵尸清单
## 返回本波真正参战的僵尸，交给波次管理器统计血量、判定提前刷新
## （空投蹦极僵尸本身也算僵尸数，所以它没离场前本波不会清完）
func create_drop_wave_zombies(
	create_manager: ZombieWaveCreateManager,
	wave_spawn: Array[CharacterRegistry.ZombieType], wave: int
) -> Array[Zombie000Base]:
	var carry_zombies: Array[Zombie000Base] = []
	for i in range(wave_spawn.size()):
		var zombie_type: CharacterRegistry.ZombieType = wave_spawn[i]
		var cell: PlantCell = pick_drop_cell()
		## 找不到空投落点时退化成普通进场，保证本波僵尸不会凭空消失
		if cell == null:
			carry_zombies.append(
				create_manager.wave_create_zombie(zombie_type, pick_lane(zombie_type), wave, Callable(), i)
			)
			continue
		var lane: int = cell.row_col.x
		var carry_zombie: Zombie000Base = create_carry_zombie(zombie_type, lane, wave, cell)
		create_drop_bungi(cell, lane, wave, carry_zombie)
		carry_zombies.append(carry_zombie)
	return carry_zombies


## 随机挑一个空投落点（植物格子）
func pick_drop_cell() -> PlantCell:
	var plant_cell_manager := zombie_manager.main_game.plant_cell_manager
	var candidates: Array[PlantCell] = []
	for row_cells in plant_cell_manager.all_plant_cells:
		for cell: PlantCell in row_cells:
			if not is_instance_valid(cell) or not cell.can_common_zombie:
				continue
			if cell.row_col.y < min_drop_col:
				continue
			candidates.append(cell)
	if candidates.is_empty():
		Log.warn("蹦极闪电战：没有可空投的格子，本波僵尸改为普通进场")
		return null
	return candidates.pick_random()


## 创建被吊着的僵尸（先建真僵尸，血量 / 僵尸数都记在本波头上）
func create_carry_zombie(
	zombie_type: CharacterRegistry.ZombieType, lane: int, wave: int, cell: PlantCell
) -> Zombie000Base:
	return zombie_manager.create_norm_zombie(
		zombie_type,
		zombie_manager.all_zombie_rows[lane],
		create_init_para(lane, wave),
		drop_global_pos(cell, lane)
	)


## 创建空投蹦极僵尸，把上面那只僵尸吊下来
func create_drop_bungi(cell: PlantCell, lane: int, wave: int, carry_zombie: Zombie000Base) -> void:
	zombie_manager.create_norm_zombie(
		CharacterRegistry.ZombieType.Z026BungiDrop,
		zombie_manager.all_zombie_rows[lane],
		create_init_para(lane, wave),
		drop_global_pos(cell, lane),
		GlobalUtils.create_bungi_drop.bind(cell, carry_zombie)
	)


## 僵尸初始化参数
func create_init_para(lane: int, wave: int) -> Dictionary:
	return {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrWave: wave,
	}


## 空投落点的全局坐标（格子中心 x + 该行地面的 y）
func drop_global_pos(cell: PlantCell, lane: int) -> Vector2:
	return Vector2(
		cell.global_position.x + cell.size.x / 2.0,
		zombie_manager.all_zombie_rows[lane].zombie_create_position.global_position.y
	)


## 退化成普通进场时挑一条行
func pick_lane(zombie_type: CharacterRegistry.ZombieType) -> int:
	var row_type = Global.character_registry.get_zombie_info(
		zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType
	)
	return zombie_manager.zombie_wave_manager.zombie_wave_create_manager.zombie_choose_row_system.select_spawn_row(row_type)

#endregion
