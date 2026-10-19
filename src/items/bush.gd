extends Node2D
class_name Bush
## 灌木丛（DLC 版《植物大战僵尸 DLC Edition》第 7 章 Woods 的场景障碍物）
##
## 机制口径（DLC 官方维基 pvz-dlc-edition.fandom.com/wiki/Woods）：
##   · 灌木长在草坪上，占一格，不能种植物（与墓碑同款的「特殊状态」）；
##   · **藏僵尸**：僵尸走进灌木时大多数植物打不到它（本仓用受击状态位 IsInBush = 128 表达，
##     默认掩码 1 的攻击来源天然打不到；蜂射手 / 爆杀类的掩码显式含 128 就能打到）；
##   · **爆杀克制灌木**：樱桃 / 毁灭菇 / 火爆辣椒这类瞬间杀伤植物能连带摧毁灌木；
##   · **小推车撞灌木会爆炸**，只炸掉那丛灌木前面的僵尸（DLC 里要靠商店的 Wood Chipper
##     撕碎灌木才能推到底，Wood Chipper 本身不在本文件范围内）；
##   · 大波（尤其是最终波）会有僵尸从灌木里冒出来。
##
## 表现层：灌木本体贴图 / 摧毁碎屑粒子（`BushesParticles`）的 DLC 素材是加密的
## `.reanim.compiled`，正走 PopStudio 反编译（见 docs/参考存档/灌木丛.md §5）。
## 贴图没到位之前灌木只是「看不见但摸得着」—— 占位 / 藏僵尸 / 被炸 / 被撞的逻辑全部照常。

@onready var body: Sprite2D = %Body
@onready var area_2d_hide: Area2D = %Area2DHide

## 灌木本体贴图（缺哪张就用剩下来的那几张，全缺就不显示）
const BUSH_TEXTURE_PATHS: Array[String] = [
	"res://pak/images/woods_bush1.png",
	"res://pak/images/woods_bush2.png",
	"res://pak/images/woods_bush3.png",
]

var plant_cell: PlantCell
var row_col: Vector2i
## 上一次灌木出怪放出去的那只僵尸（同时只能冒一只）
var new_zombie: Zombie000Base
## 当前藏在本灌木里的僵尸
var hide_zombies: Array[Zombie000Base] = []


func _ready() -> void:
	_init_random_body()
	area_2d_hide.area_entered.connect(_on_area_2d_hide_area_entered)
	area_2d_hide.area_exited.connect(_on_area_2d_hide_area_exited)


## 初始化赋值（由 PlantCell.create_bush 调用）
func init_bush(curr_plant_cell: PlantCell) -> void:
	self.plant_cell = curr_plant_cell
	self.row_col = plant_cell.row_col


## 随机换一种灌木外观（三种 bushes3/4/5 的静态帧）
## 素材没反编译出来时保持无贴图：不拿别的图顶上（缺图只报日志，绝不退化）
func _init_random_body() -> void:
	var usable: Array[String] = []
	for path in BUSH_TEXTURE_PATHS:
		if ResourceLoader.exists(path):
			usable.append(path)
	if usable.is_empty():
		Log.info("[Bush] 灌木贴图还没导入（等 PopStudio 反编译），这次只占位不出图")
		return
	body.texture = load(usable[GameRng.randi_range(0, usable.size() - 1)])


#region 藏僵尸

## 僵尸走进灌木：藏起来（僵尸本身照常前进 / 啃植物，只是大多数植物打不到它）
func _on_area_2d_hide_area_entered(area: Area2D) -> void:
	var area_owner = area.owner
	if area_owner is Zombie000Base:
		var zombie: Zombie000Base = area_owner
		if zombie.lane == row_col.x:
			_hide_zombie(zombie)


## 僵尸走出灌木：恢复成普通受击状态
func _on_area_2d_hide_area_exited(area: Area2D) -> void:
	var area_owner = area.owner
	if area_owner is Zombie000Base:
		var zombie: Zombie000Base = area_owner
		if zombie.lane == row_col.x:
			_show_zombie(zombie)


func _hide_zombie(zombie: Zombie000Base) -> void:
	if zombie.is_death or hide_zombies.has(zombie):
		return
	hide_zombies.append(zombie)
	zombie.curr_be_attack_status = Zombie000Base.E_BeAttackStatusZombie.IsInBush
	## 僵尸在灌木里被清除（被炸死 / 被推车碾）时不会走 area_exited，这里兜底摘掉引用
	if not zombie.tree_exited.is_connected(_on_hide_zombie_exited):
		zombie.tree_exited.connect(_on_hide_zombie_exited.bind(zombie), CONNECT_ONE_SHOT)


func _show_zombie(zombie: Zombie000Base) -> void:
	hide_zombies.erase(zombie)
	if is_instance_valid(zombie) and not zombie.is_death:
		zombie.curr_be_attack_status = Zombie000Base.E_BeAttackStatusZombie.IsNorm


## 藏着的僵尸离场（死亡 / 被移除）：从名单里摘掉，不再等 area_exited
func _on_hide_zombie_exited(zombie: Zombie000Base) -> void:
	hide_zombies.erase(zombie)


## 当前灌木里藏着僵尸
func is_hiding_zombie() -> bool:
	for zombie: Zombie000Base in hide_zombies:
		if is_instance_valid(zombie) and not zombie.is_death:
			return true
	return false

#endregion


#region 出怪

## 当前是否正在出怪（有僵尸正从这丛灌木冒头）
## 与墓碑同款：不要用「上一次出怪的协程跑完没有」判断，改成实时看那只僵尸还在不在
func is_creating_zombie() -> bool:
	if not is_instance_valid(new_zombie):
		new_zombie = null
		return false
	return new_zombie.is_inside_tree() and not new_zombie.is_death


## 从灌木里放出一只僵尸（大波伏击）
## [new_zombie_type] 僵尸种类
## 返回是否真的放出去一只（灌木正忙着出怪时返回 false）
func create_new_zombie(new_zombie_type: StringName) -> bool:
	if is_creating_zombie():
		return false

	var zombie_init_para: Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: row_col.x,
	}
	var zombie_row = GameContext.curr_main_game.zombie_manager.all_zombie_rows[row_col.x]
	var zombie: Zombie000Base = GameContext.curr_main_game.zombie_manager.create_norm_zombie(
		new_zombie_type,
		zombie_row,
		zombie_init_para,
		Vector2(global_position.x, zombie_row.zombie_create_position.global_position.y)
	)
	if not is_instance_valid(zombie):
		return false

	new_zombie = zombie
	zombie.tree_exited.connect(_on_new_zombie_exited.bind(zombie), CONNECT_ONE_SHOT)
	_up_from_bush(zombie)
	return true


## 上一次出怪的僵尸已经离场，灌木恢复空闲
func _on_new_zombie_exited(zombie: Zombie000Base) -> void:
	if new_zombie == zombie:
		new_zombie = null


## 僵尸从灌木里冒头的表现（协程本身只管收尾，中途被打断也不影响解锁）
func _up_from_bush(zombie: Zombie000Base) -> void:
	await zombie.zombie_up_from_tombstone(1.0)
	if new_zombie == zombie:
		new_zombie = null

#endregion


#region 摧毁

## 灌木被摧毁（爆杀植物 / 小推车撞上）
func bush_death() -> void:
	## 先把检测框从物理空间摘掉再 free：摧毁发生在炸弹 / 推车遍历重叠区域的过程中，
	## 同一个灌木对象会在本帧里被后续代码再拿到一次，那时它已经释放了一半
	## （读 .lane / .row_col 会刷 "Invalid access to property or key"）
	if is_instance_valid(area_2d_hide):
		area_2d_hide.monitoring = false
		area_2d_hide.monitorable = false
		remove_child(area_2d_hide)
		area_2d_hide.queue_free()
	## 灌木没了，藏在里头的僵尸就藏不住了
	for zombie: Zombie000Base in hide_zombies:
		if is_instance_valid(zombie) and not zombie.is_death:
			zombie.curr_be_attack_status = Zombie000Base.E_BeAttackStatusZombie.IsNorm
	hide_zombies.clear()
	if is_instance_valid(plant_cell):
		plant_cell.bush_death_update_plant_cell_data()
	queue_free()

#endregion
