extends Node2D
class_name  TombStone

@onready var tombstone: Sprite2D = $TombstoneMask/tombstone
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D
@onready var mound: Sprite2D = $MoundMask/mound
@onready var tombstone_mask: Panel = $TombstoneMask

@export var zombie_candidate_list :Array[CharacterRegistry.ZombieType]

var plant_cell:PlantCell
var new_zombie:Zombie000Base
var row_col:Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_init_tombstone()

## 初始化赋值
func init_tombstone(curr_plant_cell:PlantCell):
	self.plant_cell = curr_plant_cell
	self.row_col = plant_cell.row_col

## 随机生成一种墓碑（一共5种）
func _init_random_frame():
	var random_frame = randi_range(0,4)
	tombstone.frame = random_frame
	mound.frame = random_frame
	SoundManager.play_other_SFX("gravestone_rumble")

## 初始化墓碑
func _init_tombstone():
	_init_random_frame()
	gpu_particles_2d.emitting = true
	var mound_ori_position = mound.position
	var tombstone_ori_position = tombstone.position
	mound.position = Vector2(39, 84)
	tombstone.position = Vector2(39, 136)
	await get_tree().create_timer(0.5).timeout
	var tween := create_tween()
	tween.tween_property(mound, "position", mound_ori_position, 0.1)
	tween.tween_property(tombstone, "position", tombstone_ori_position, 0.5)


## 被墓碑吞吃时修改mask位置
func start_be_grave_buster_eat():
	tombstone_mask.position.y += 30
	tombstone.position.y -= 30

func failure_eat_tombstone():
	tombstone_mask.position.y -= 30
	tombstone.position.y += 30

## 当前是否正在出怪（有僵尸正从这块墓碑冒头）
##
## **不要用「上一次出怪的协程跑完没有」判断占用**：冒头表现会 await 到 body 节点上的一个 tween，
## 僵尸在冒头途中被销毁时那个 tween 随之消失、finished 不会发，协程就**不再返回**，
## 收尾那句 `new_zombie = null` 也就到不了。这里改成实时看「那只僵尸还在不在树上、死没死」，
## 与协程收尾彻底解耦。
func is_creating_zombie() -> bool:
	if not is_instance_valid(new_zombie):
		new_zombie = null
		return false
	return new_zombie.is_inside_tree() and not new_zombie.is_death

## 生成僵尸
## [new_zombie_type] 僵尸种类
## [anim_multiply] 起身动画倍率（锤僵尸玩法用它做难度爬升）
## 返回是否真的放出去一只（墓碑正忙着出怪时返回 false）
func create_new_zombie(new_zombie_type:CharacterRegistry.ZombieType, anim_multiply:float=1.0) -> bool:
	if is_creating_zombie():
		Log.debug("当前墓碑正在生产僵尸")
		return false

	var zombie_init_para:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane:row_col.x,
	}

	var zombie: Zombie000Base = Global.main_game.zombie_manager.create_norm_zombie(
		new_zombie_type,
		Global.main_game.zombie_manager.all_zombie_rows[row_col.x],
		zombie_init_para,
		Vector2(global_position.x,Global.main_game.zombie_manager.all_zombie_rows[row_col.x].zombie_create_position.global_position.y)
	)
	if not is_instance_valid(zombie):
		return false

	new_zombie = zombie
	## 僵尸离场时顺手把引用清干净（会不会解锁不靠这里，靠 is_creating_zombie 的实时判定）
	zombie.tree_exited.connect(_on_new_zombie_exited.bind(zombie))
	_up_from_tombstone(zombie, anim_multiply)
	return true

## 上一次出怪的僵尸已经离场，墓碑恢复空闲
func _on_new_zombie_exited(zombie:Zombie000Base) -> void:
	if new_zombie == zombie:
		new_zombie = null

## 僵尸从墓碑冒头的表现
## 协程本身只管收尾：中途僵尸被销毁时它可能永远返回，解锁由 `_on_new_zombie_exited` 兜底
func _up_from_tombstone(zombie:Zombie000Base, anim_multiply:float) -> void:
	await zombie.zombie_up_from_tombstone(anim_multiply)
	if new_zombie == zombie:
		new_zombie = null

## 墓碑死亡(只有墓碑吞噬者啃完才会走到这里)
func tombstone_death():
	## 原版:墓碑被清除后会掉一个银币($10),偶尔掉更值钱的(金币 / 巧克力 / 钻石 / 禅境花园植物)
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Grave_(PvZ))
	## 待核实: 更值钱掉落物的具体概率未查到,暂只实现「必掉一个银币」
	EventBus.push_event("create_coin", [[1.0, 0.0, 0.0], global_position])
	plant_cell.tombstone.plant_cell.tombstone_death_update_plant_cell_data()
	queue_free()
