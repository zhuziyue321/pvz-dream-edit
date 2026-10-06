extends Node
## 暂时僵尸节点
class_name ZombieShowInStart

@onready var zombie_manager: ZombieManager = %ZombieManager

@export_group("准备阶段展示僵尸")
## 按y轴顺序渲染
@onready var show_zombie_panel: Panel = %ShowZombiePanel
## 不按y轴顺序渲染
@onready var show_zombie_panel_2: Panel = %ShowZombiePanel2

## 展示僵尸总数 = 出怪类型数 + 该额外名额(再夹进 show_zombie_num_range)
## 原版口径: 预览僵尸的数量就是本关「出怪池」的长度,池里每个条目出一只。
##   池是按权重重复列出的,所以预览里普僵占多数,总数 1-1 是 5、多数关卡约 10、x-10 大波关 15。
## 数据来源: jspvz(https://github.com/ZhuZhengyi/jspvz)
##   js/Cfunction.js 的 DisplayZombie() 与 Level/*.js 的 ArZ(出怪池)
@export var show_zombie_extra_num := 5
## 展示僵尸总数范围(下限 / 上限;类型数超过上限时按类型数取,保证每种出怪类型都能露脸)
@export var show_zombie_num_range := Vector2i(5, 15)
## 不参与预览的僵尸类型: 原版出怪池里没有旗帜僵尸(旗帜是大波时才单独加进波次的)
@export var exclude_show_zombie_types: Array[CharacterRegistry.ZombieType] = [
	CharacterRegistry.ZombieType.Z002Flag,
]

var show_zombies_array :Array[Zombie000Base]


#region 生成关卡前展示僵尸
## 生成一个展示僵尸
func create_show_zombie(zombie_type:CharacterRegistry.ZombieType, parent_node:Panel) -> Zombie000Base:
	var zombie_pos :=Vector2(randf_range(0, parent_node.size.x), randf_range(0, parent_node.size.y))
	return CharacterShowFactory.create_show_zombie(
		zombie_type,
		parent_node,
		zombie_pos,
		{Zombie000Base.E_ZInitAttr.CurrZombieRowType:CharacterRegistry.ZombieRowType.Land}
	)

## 生成关卡前展示僵尸
## 原版展示的是「出怪池」的一份快照:每种僵尸按池里的重复次数出现,普僵最多、总数 5~15。
## 本仓库的出怪池是「类型 + 权重」两张表(zombie_refresh_types / zombie_weights),没有显式的池列表,
## 所以这里先给每种出怪类型 1 只(预览的作用就是让玩家看清本关有哪些僵尸),
## 剩下的名额按出怪权重抽样补足 —— 权重高的普僵 / 路障会多出几只,观感与原版一致。
func create_prepare_show_zombies():
	var show_types := get_show_zombie_types()
	for zombie_type in show_types:
		show_zombies_array.append(create_show_zombie(zombie_type, show_zombie_panel))
	## 剩余名额按出怪权重抽样补足
	for _i in range(get_show_zombie_num(show_types.size()) - show_types.size()):
		var zombie_type := pick_weighted_zombie_type()
		if zombie_type == CharacterRegistry.ZombieType.Null:
			break
		show_zombies_array.append(create_show_zombie(zombie_type, show_zombie_panel))
	## 蹦极僵尸不按y轴排序渲染,单独放一层
	if zombie_manager.is_bungi:
		show_zombies_array.append(create_show_zombie(CharacterRegistry.ZombieType.Z021Bungi, show_zombie_panel_2))

## 参与预览的出怪类型(原版出怪池不含旗帜僵尸)
func get_show_zombie_types() -> Array[CharacterRegistry.ZombieType]:
	var show_types: Array[CharacterRegistry.ZombieType] = []
	for zombie_type in zombie_manager.zombie_refresh_types:
		if zombie_type in exclude_show_zombie_types:
			continue
		show_types.append(zombie_type)
	return show_types

## 展示僵尸总数:类型数 + 额外名额,再夹进数量范围;类型数超过上限时按类型数取
func get_show_zombie_num(type_num:int) -> int:
	var num := type_num + show_zombie_extra_num
	var lower: int = max(show_zombie_num_range.x, type_num)
	var upper: int = max(show_zombie_num_range.y, type_num)
	return clamp(num, lower, upper)

## 按出怪权重抽一个展示僵尸类型(用的是波次生成管理器那一份出怪随机池),取不到时返回 Null
func pick_weighted_zombie_type() -> CharacterRegistry.ZombieType:
	var wave_manager := zombie_manager.zombie_wave_manager
	if wave_manager == null:
		return CharacterRegistry.ZombieType.Null
	var create_manager := wave_manager.zombie_wave_create_manager
	if create_manager == null or create_manager.zombie_choose_random_pool == null:
		return CharacterRegistry.ZombieType.Null
	for _i in range(PICK_WEIGHTED_RETRY_NUM):
		var zombie_type: Variant = create_manager.zombie_choose_random_pool.get_random_item()
		if zombie_type == null:
			break
		if zombie_type in exclude_show_zombie_types:
			continue
		return zombie_type
	return CharacterRegistry.ZombieType.Null

## 按权重抽类型时的重试次数(抽到不参与预览的类型时重抽)
const PICK_WEIGHTED_RETRY_NUM := 4

## 删除关卡前展示僵尸
func delete_prepare_show_zombies() -> void:
	for z in show_zombies_array:
		z.queue_free()
	show_zombies_array.clear()  # 清空数组
#endregion
