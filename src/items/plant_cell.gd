extends Control
class_name PlantCell

## 植物的父节点为对应位置的容器节点 plant_container_node
## 底部植物会上下移动
## 如果使用tween控制移动，每帧计算差值控制中间植物上下移动会卡#
## 因此放置底部植物时：
## 将中间植物（norm和shell）的容器节点放到底部植物的容器（底部植物自带的子节点，与植物格子的底部植物容器无关）中
## 底部植物容器会上下移动，从而带动中间植物上下移动
## 中间植物的位置与底部植物的容器位置无关

signal click_cell
signal cell_mouse_enter
signal cell_mouse_exit
## 删除墓碑信号
signal signal_cell_delete_tombstone(plant_cell:PlantCell, tombstone:TombStone)

@onready var button: Button = $Button
## 植物碰撞器位置节点
@onready var plant_area_2d_position: Control = $PlantArea2dPosition

## 植物格子类型
enum PlantCellType{
	Grass,		## 草地
	Pool,		## 水池
	Roof,		## 屋顶/裸地
	Unsodded,	## 无草皮：原版前几关没铺草皮的行，不能种植任何植物
}
## 当前格子类型
@export var plant_cell_type :PlantCellType = PlantCellType.Grass

## 行和列，由 PlantCellManager 在 _ready 中赋值
## row = 行号（与僵尸行/小推车行号同源），col = 列号（0 = 最左列，= all_plant_cells[row] 的下标）
## 不要加 @export：它由地图结构算出，写进场景会覆盖运行时的正确值
var row_col: Vector2i
## 屋顶斜面阶梯偏移（该列相对行基准 y 的额外 y），由 PlantCellManager 按地图数据赋值。
## 检测层面用它做反向补偿（见 GlobalUtils.update_plant_cell_slope_y*），非屋顶地图恒为 0。
## 注意：不要用 position.y 代替它 —— 数据驱动地图后 position.y 是格子的绝对 y（含 row_y）。
var slope_step_y: float = 0.0

@export_group("当前格子的条件")
@export_subgroup("植物种植")
#@export_flags("1 无", "2 草地", "4 花盆", "8 水", "16 睡莲", "32 屋顶/裸地")
var ori_condition:int = 3
## 植物种植地形条件（满足一个即可），默认（无1 + 草地2 = 3）
var curr_condition:int = 3

## 在当前格子中对应位置的植物
@export var plant_in_cell:Dictionary[CharacterRegistry.PlacePlantInCell, Plant000Base] =  {
	CharacterRegistry.PlacePlantInCell.Norm: null,
	CharacterRegistry.PlacePlantInCell.Float: null,
	CharacterRegistry.PlacePlantInCell.Down: null,
	CharacterRegistry.PlacePlantInCell.Shell: null,
	## 模仿者当前位置（与 plant_container_node 的槽位保持一致）。
	## 历史上这个键被注释掉，导致按 Imitater 下标取值越界崩溃。
	CharacterRegistry.PlacePlantInCell.Imitater: null,
}


## 安全读取某个槽位的植物：
##   · 键缺失 → 返回 null（不会抛 "Out of bounds get index"）
##   · 槽位里是「已释放对象」的残留引用 → 当作空槽返回 null，并顺手清空该槽位
## 所有对 plant_in_cell 的【读取】都走这里，不要再直接下标（写入仍可直接赋值）。
##
## 为什么必须在这里兜底：植物死亡并不会立刻清空槽位，槽位里留下的是已释放对象。
## 把这种引用交给【类型化】的变量或返回值，GDScript 会直接报
## "Trying to return/assign a previously freed instance"。
## 历史表现：切植物 / 频繁点击时偶发，栈顶固定是 create_plant() 里这次读取。
func get_plant(place: CharacterRegistry.PlacePlantInCell) -> Plant000Base:
	## 必须用无类型局部变量接：类型化赋值本身就会触发 "previously freed instance"
	var plant = plant_in_cell.get(place)
	if plant == null:
		return null
	if not is_instance_valid(plant):
		## 顺手清空，让字典自愈，后续任何读取都不再需要重复判断
		plant_in_cell[place] = null
		return null
	return plant

## 在当前格子中对应位置的容器节点
@onready var plant_container_node:Dictionary =  {
	CharacterRegistry.PlacePlantInCell.Norm: $PlantNormContainer,
	CharacterRegistry.PlacePlantInCell.Shell: $PlantShellContainer,
	CharacterRegistry.PlacePlantInCell.Float: $PlantFloatContainer,
	CharacterRegistry.PlacePlantInCell.Down: $PlantDownContainer,
	CharacterRegistry.PlacePlantInCell.Imitater: $PlantImitaterContainer,
}

## 在当前格子中对应容器位置的节点初始全局位置,
var plant_postion_node_ori_global_position:Dictionary =  {}

@export_subgroup("特殊状态，特殊状态下无法种植")
## 是否可以种植普通植物
@export var can_common_plant := true
#var is_can_common_plant
enum E_SpecialStatePlant {
	IsTombstone,	# 墓碑
	IsCrater,		# 坑洞
	IsIceRoad,		# 冰道
	IsPot,			# 罐子
	IsNoPlantBowling,		# 不能种植（保龄球红线模式不能种植）
}

## 当前特殊状态
@export var curr_special_state_plant:Dictionary[E_SpecialStatePlant, bool]

## 当前格子冰道
var curr_ice_roads:Array[IceRoad] = []
## 当前cell的墓碑
var tombstone:TombStone
## 当前cell的坑洞
var crater:DoomShroomCrater

@export_subgroup("特殊状态，特殊状态下无法种植僵尸")
## 是否可以种植僵尸
@export var can_common_zombie := true
enum E_SpecialStateZombie {
	IsNoPlantBowling,		## 不能种植（保龄球红线模式不能种植）
}
## 当前特殊状态
@export var curr_special_state_zombie:Dictionary[E_SpecialStateZombie, bool]

## 梯子
var ladder:Ladder

## 植物种植和死亡信号
signal signal_plant_create(plant_cell:PlantCell, plant_type:CharacterRegistry.PlantType)
signal signal_plant_free(plant_cell:PlantCell, plant_type:CharacterRegistry.PlantType)

#region 植物格子初始化
func _ready() -> void:
	## 隐藏按钮样式
	var new_stylebox_normal = $Button.get_theme_stylebox("pressed").duplicate()
	$Button.add_theme_stylebox_override("normal", new_stylebox_normal)

	## 根据格子类型初始化植物种植地形条件
	init_condition()

## 根据当前格子类型初始化当前格子状态
func init_condition():
	match plant_cell_type:
		PlantCellType.Grass:
			ori_condition = 3
			curr_condition = 3

		PlantCellType.Pool:
			ori_condition = 9
			curr_condition = 9

		PlantCellType.Roof:
			ori_condition = 33
			curr_condition = 33

		PlantCellType.Unsodded:
			## 无草皮：地形条件置 0，任何植物的种植条件与之相与都为 0，即种不进去。
			## 不用 can_common_plant 标记：它会被 _update_state_plant() 按特殊状态重算。
			ori_condition = 0
			curr_condition = 0

	### 在当前格子中对应位置的节点初始全局位置,植物放在该节点下
	for place_plant_in_cell in plant_container_node.keys():
		plant_postion_node_ori_global_position[place_plant_in_cell] = plant_container_node[place_plant_in_cell].global_position
#endregion


#region 伽刚特尔攻击当前植物格子
func be_gargantuar_attack(zombie_gargantuar:Zombie000Base):
	for place_plant_in_cell in plant_in_cell:
		var curr_plant := get_plant(place_plant_in_cell)
		if is_instance_valid(curr_plant) and curr_plant.hurt_box_component.is_enabling:
			## 被压扁
			curr_plant.be_flattened_from_enemy(zombie_gargantuar)
	if is_instance_valid(pot):
		pot.open_pot_be_gargantuar()


func plant_be_flattened():
	for place_plant_in_cell in plant_in_cell:
		var curr_plant := get_plant(place_plant_in_cell)
		if is_instance_valid(curr_plant):
			## 被压扁
			curr_plant.be_flattened()
			Log.debug(str(curr_plant.name) + str("被压扁"))

#endregion

#region 植物(僵尸)种植(死亡)
## 模仿者变身：种下它模仿的那株植物
## 看起来只是 create_plant 的一层包装，**不要内联到 Plant999Imitater.update_imitater()**，原因有两个：
## 1、本体走的是 queue_free，必须等这一帧结束对象真正释放、格子腾空，
##    否则 create_plant 里「非紫卡且该位置已有植物就返回」的判据会命中模仿者本体，变身直接失败；
## 2、await 必须在 plant_cell 上挂起 —— 模仿者本体马上就要 queue_free，
##    挂在它自己身上的协程会被 Godot 连同对象一起取消，下一株植物永远不会出现。
func imitater_create_plant(plant_type:CharacterRegistry.PlantType, is_plant_start_effect:=true):
	await get_tree().process_frame
	return create_plant(plant_type, false, is_plant_start_effect, true)

## 新植物种植（本格子里创建植物的唯一入口：卡片种植 / 预种植 / 模仿者变身 / 读档都走这里）
##[is_imitater:bool] 植物是否为模仿者（true = 先造 P999Imitater 本体，再由它变身成目标植物）
##[is_plant_start_effect:bool] 是否有种植特效
##[is_imitater_material:bool] 是否为模仿者材质（只是套模仿者的灰色材质，植物本体就是 plant_type。
##   模仿者变身 / 预种植 / 读档走这一档；注意它和上一个参数的语义不同，别传错位）
##[is_zombie_mode:bool] 是否为我是僵尸模式
func create_plant(plant_type:CharacterRegistry.PlantType, is_imitater:=false, is_plant_start_effect:=true, is_imitater_material:=false, is_zombie_mode:=false) -> Plant000Base:
	var plant_condition:ResourcePlantCondition
	var plant :Plant000Base
	plant_condition = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	## 创建植物
	if is_imitater:
		## 创建植物
		#plant_condition = Global.character_registry.get_plant_info(CharacterRegistry.PlantType.P999Imitater, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
		plant = Global.character_registry.get_plant_info(CharacterRegistry.PlantType.P999Imitater, CharacterRegistry.PlantInfoAttribute.PlantScenes).instantiate()
		plant = plant as Plant999Imitater
		plant.imitater_plant_type = plant_type
	else:
		## 如果该植物为紫卡
		if plant_condition.is_purple_card:
			## 删除紫卡前置植物,创建新植物
			var condition_pre_plant :ResourcePlantCondition = Global.character_registry.get_plant_info(Global.character_registry.AllPrePlantPurple[plant_type], CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
			var pre_plant := get_plant(condition_pre_plant.place_plant_in_cell)
			if is_instance_valid(pre_plant):
				pre_plant.character_death_disappear()
				#await get_tree().process_frame
		else:
			## 非紫卡 如果该位置已经存在植物,返回
			var exist_plant := get_plant(plant_condition.place_plant_in_cell)
			if is_instance_valid(exist_plant):
				Log.debug(str("当前位置") + str(row_col) + str("已经有植物：") + str(exist_plant.name))
				return

		plant = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantScenes).instantiate()

	var plant_init_para = {
		Plant000Base.E_PInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
		Plant000Base.E_PInitAttr.PlantCell:self,
		Plant000Base.E_PInitAttr.IsImitaterMaterial:is_imitater_material,
		Plant000Base.E_PInitAttr.IsZombieMode:is_zombie_mode
	}
	plant.init_plant(plant_init_para)
	if is_imitater:
		plant_container_node[CharacterRegistry.PlacePlantInCell.Imitater].add_child(plant)
	else:
		plant_container_node[plant_condition.place_plant_in_cell].add_child(plant)

	## 关卡全场加速（「僵尸快跑」关 speed_factor_plant = 2）：
	## 必须在 add_child 之后 —— 攻击组件是在 _ready 里才连上 signal_update_speed 的
	var main_game: MainGameManager = Global.main_game
	if is_instance_valid(main_game) and main_game.game_para != null:
		main_game.game_para.apply_speed_factor_to_plant(plant)

	plant_in_cell[plant_condition.place_plant_in_cell] = plant
	plant.signal_character_death.connect(one_plant_free.bind(plant))

	if is_plant_start_effect:
		## 种植特效
		var plant_start_effect_scene:Node2D
		## 当前地形为水或者睡莲
		if curr_condition & 8 or curr_condition & 16:
			plant_start_effect_scene = SceneRegistry.PLANT_START_EFFECT_WATER.instantiate()
		else:
			plant_start_effect_scene = SceneRegistry.PLANT_START_EFFECT.instantiate()
		plant.body.add_child(plant_start_effect_scene)

	if not is_imitater:

		## 如果是down位置植物，修改中间植物节点顺序， 提高中间植物和壳的位置,
		## （与手套搬入底部植物共用同一段逻辑，见 _attach_down_plant_container）
		if plant_condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Down:
			_attach_down_plant_container(plant)

	signal_plant_create.emit(self, plant.plant_type)

	return plant

## 坚果包扎术：当前格子里"手持同种坚果卡片可以直接补种修复"的植物
## 原版口径（见 ConstShop.WALL_NUT_FIRST_AID_PRICE 的来源注释）：
##   只修坚果 / 高坚果 / 南瓜头，且必须已经掉手或裂开（血量阶段 >= 1）才允许补种；
##   只是掉了点血、外观还完好的视为完好，不能补种；没买包扎术也不能补种
## [plant_type] 手持卡片的植物类型；返回可被修复的植物，没有则返回 null
func get_first_aid_plant(plant_type: CharacterRegistry.PlantType) -> Plant000Base:
	if not ConstShop.is_first_aid_plant(plant_type):
		return null
	if not Global.global_game_state.is_wall_nut_first_aid_owned():
		return null
	var plant_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	var plant := get_plant(plant_condition.place_plant_in_cell)
	## 必须同种：拿南瓜头不能去补坚果；模仿者的 plant_type 是模仿者自己，同样不算
	if plant == null or plant.plant_type != plant_type:
		return null
	## 外观还没受损（血量阶段 < 1）的坚果不能补种
	## 血量阶段组件由坚果类植物各自声明，这里按节点名取（见 Plant000Base.be_first_aid_heal）
	var stage_component := plant.get_node_or_null(^"HpStageChangeComponent") as HpStageChangeComponent
	if not is_instance_valid(stage_component):
		return null
	if stage_component.curr_hp_stage < 1:
		return null
	return plant


## 咖啡豆唤醒在睡眠中的植物
func coffee_bean_awake_up():
	var norm_plant := get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	if is_instance_valid(norm_plant):
		norm_plant.coffee_bean_awake_up()
	else:
		Log.debug("没有睡眠植物")

## 获取种植新植物时植物虚影的位置
func get_new_plant_static_shadow_global_position(place_plant_in_cell:CharacterRegistry.PlacePlantInCell):
	return plant_container_node[place_plant_in_cell].global_position

## 植物死亡
func one_plant_free(plant:Plant000Base):
	var curr_plant_condition :ResourcePlantCondition = Global.character_registry.get_plant_info(plant.plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)

	if is_instance_valid(ladder):
		if curr_plant_condition.place_plant_in_cell in [CharacterRegistry.PlacePlantInCell.Down, CharacterRegistry.PlacePlantInCell.Norm, CharacterRegistry.PlacePlantInCell.Shell]:
			ladder.ladder_death()

	#plant_in_cell[curr_plant_condition.place_plant_in_cell] = null
	## 如果是down位置植物，下降中间植物和壳的位置，修改节点结构
	## （与手套搬出底部植物共用同一段逻辑，见 _detach_down_plant_container）
	if curr_plant_condition.place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Down:
		_detach_down_plant_container(plant)
	## 玉米加农炮只有后轮plantcell发射信号更新植物数据
	if plant.plant_type == CharacterRegistry.PlantType.P048CobCannon:
		if plant.plant_cell == self:
			signal_plant_free.emit(self, plant.plant_type)
	else:
		signal_plant_free.emit(self, plant.plant_type)

	##如果植物死亡时鼠标在当前植物格子中，等待一帧后重新发射鼠标进入格子信号检测种植
	if is_mouse_in_ui(button):
		await get_tree().process_frame
		_on_button_mouse_entered()

## 改变特殊状态(植物)
func update_special_state_plant(value:bool, change_specila_state:E_SpecialStatePlant):
	curr_special_state_plant[change_specila_state] = value
	_update_state_plant()

## 改变特殊状态(僵尸)
func update_special_state_zombie(value:bool, change_specila_state:E_SpecialStateZombie):
	curr_special_state_zombie[change_specila_state] = value
	_update_state_zombie()

## 更新状态
func _update_state_plant():
	##是否全为false(无特殊状态，可以种植)
	can_common_plant = curr_special_state_plant.values().all(func(v): return not v)
	##如果更新状态时鼠标在当前植物格子中，重新发射鼠标进入格子信号检测种植
	if is_mouse_in_ui(button):
		_on_button_mouse_entered()

## 更新状态
func _update_state_zombie():
	##是否全为false(无特殊状态，可以种植)
	can_common_zombie = curr_special_state_zombie.values().all(func(v): return not v)
	##如果更新状态时鼠标在当前植物格子中，重新发射鼠标进入格子信号检测种植
	if is_mouse_in_ui(button):
		_on_button_mouse_entered()

## 荷叶种植/死亡时调用
func _lily_pad_change_condition():
	## 切换荷叶地形
	curr_condition = curr_condition ^ 16
	## 切换水池地形
	curr_condition = curr_condition ^ 8

## 花盆种植/死亡时调用
func _flower_pot_change_condition():
	## 如果当前是花盆地形，设置地形为原始地形
	if curr_condition & 4:
		curr_condition = ori_condition
	## 如果当前不是花盆地形，设置当前地形为花盆地形
	else:
		curr_condition = 4

## 底部植物种植或死亡时改变地形
func down_plant_change_condition(is_water:bool):
	if is_water:
		_lily_pad_change_condition()
	else:
		_flower_pot_change_condition()
#endregion

#region 手套搬运
## 手套把场上的植物搬到另一个格子：不铲除、不重种，植物实例与全部状态（血量 / 成长 / 攻击 / 产阳光）都保留，
## 只换格子。搬运期间植物**不摘出场景树**（只开 top_level 做视觉位移），否则 Timer / _process 会中断。
## 本区只提供「格子侧」的取放 API，搬运状态机在 HandComponentGlove 里（见 docs/参考存档/手持物实现.md）。

## 手套：本格子中可以被搬走的植物（按鼠标位置优先，与铲子的选取规则一致）
func glove_get_carry_plant() -> Plant000Base:
	if get_curr_plant_num() <= 0:
		return null
	return return_plant_null_res(get_plant_place_from_mouse_pos())


## 手套：查找植物在本格子中占的槽位；不在本格子返回 -1
## （PlacePlantInCell 没有「空」成员，只能用 -1 表示没找到）
func glove_get_plant_place(plant: Plant000Base) -> int:
	for place in plant_in_cell:
		if get_plant(place) == plant:
			return int(place)
	return -1


## 手套：把植物从本格子取出（不杀死植物，只断开本格子的关联）
func glove_take_plant(plant: Plant000Base) -> bool:
	var place_int := glove_get_plant_place(plant)
	if place_int == -1:
		return false
	var place: CharacterRegistry.PlacePlantInCell = place_int as CharacterRegistry.PlacePlantInCell
	## 从本格子的植物表中摘除（植物实例本身不动，仍在场景树里）
	plant_in_cell[place] = null
	## 结束被道具关注的高亮：拿起前的高亮由手套组件发起，这里配对结束（不能由组件重复结束）
	plant.be_shovel_look_end()
	## 断开与本格子的死亡回调：植物放到新格子后会重新连接
	var death_callback := one_plant_free.bind(plant)
	if plant.signal_character_death.is_connected(death_callback):
		plant.signal_character_death.disconnect(death_callback)
	## 底部植物（花盆 / 睡莲）离开本格子：把中间 / 壳容器搬回本格子，并还原地形
	if place == CharacterRegistry.PlacePlantInCell.Down:
		_detach_down_plant_container(plant)
		down_plant_change_condition(plant_cell_type == PlantCellType.Pool)
	return true


## 手套：该植物放进本格子时应占的槽位
func glove_get_put_place(plant: Plant000Base) -> CharacterRegistry.PlacePlantInCell:
	if plant is Plant999Imitater:
		return CharacterRegistry.PlacePlantInCell.Imitater
	var condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant.plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	if condition == null:
		return CharacterRegistry.PlacePlantInCell.Imitater
	return condition.place_plant_in_cell


## 手套：判断植物能否放进本格子（与种植条件同源：格子无特殊状态 + 地形符合 + 槽位为空）
## 不发 signal_plant_create / signal_plant_free：搬运不改变场上植物总数
func glove_judge_can_put(plant: Plant000Base) -> bool:
	if not is_instance_valid(plant):
		return false
	if not can_common_plant:
		return false
	if is_instance_valid(get_plant(glove_get_put_place(plant))):
		return false
	var condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant.plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	if condition == null:
		return false
	## 地形条件：睡莲不能搬到草地，花盆不能搬到水池
	if condition.plant_condition & curr_condition == 0:
		return false
	return true


## 手套：把植物放进本格子的指定槽位
func glove_put_plant(plant: Plant000Base, place: CharacterRegistry.PlacePlantInCell) -> bool:
	if not is_instance_valid(plant):
		return false
	if is_instance_valid(get_plant(place)):
		return false
	## 底部植物（花盆 / 睡莲）进入本格子：把中间 / 壳容器收进它的上下移动容器，并切换地形
	if place == CharacterRegistry.PlacePlantInCell.Down:
		_attach_down_plant_container(plant)
		down_plant_change_condition(plant_cell_type == PlantCellType.Pool)

	var target_container: Node = plant_container_node[place]
	## ⚠️ 搬运期间植物一直留在场景树里，放回时必须先无条件摘出，
	## 否则「原父节点 == 目标容器」时会报 "already has a parent"
	var ori_parent: Node = plant.get_parent()
	if ori_parent != null:
		ori_parent.remove_child(plant)
	## 关闭 top_level，让植物重新跟随格子容器
	plant.top_level = false
	target_container.add_child(plant)
	plant_in_cell[place] = plant

	## 更新植物的位置引用
	plant.plant_cell = self
	plant.row_col = row_col
	plant.lane = row_col.x
	## 死亡回调重新连到本格子
	plant.signal_character_death.connect(one_plant_free.bind(plant))

	## 位置归位：容器本身就在格子的正确位置，植物相对容器归零即可
	plant.position = Vector2.ZERO
	GlobalUtils.update_plant_cell_slope_y_array(self, plant.node2d_detect_in_slope)
	return true


## 手套：把中间 / 壳容器收进底部植物的上下移动容器（与 create_plant 放置底部植物一致）
func _attach_down_plant_container(plant: Plant000Base) -> void:
	var down_plant := plant as Plant000DownBase
	if down_plant == null or not is_instance_valid(down_plant.down_plant_container):
		return
	for place in [CharacterRegistry.PlacePlantInCell.Norm, CharacterRegistry.PlacePlantInCell.Shell]:
		var container: Control = plant_container_node[place]
		remove_child(container)
		down_plant.down_plant_container.add_child(container)
		container.global_position = plant_postion_node_ori_global_position[place] - down_plant.plant_up_position


## 手套：把中间 / 壳容器从底部植物搬回本格子（与 one_plant_free 处理底部植物一致）
## 不做这一步，搬运花盆 / 睡莲时上面的植物会跟着一起飞走
func _detach_down_plant_container(plant: Plant000Base) -> void:
	var down_plant := plant as Plant000DownBase
	if down_plant == null or not is_instance_valid(down_plant.down_plant_container):
		return
	for place in [CharacterRegistry.PlacePlantInCell.Norm, CharacterRegistry.PlacePlantInCell.Shell]:
		var container: Control = plant_container_node[place]
		down_plant.down_plant_container.remove_child(container)
		add_child(container)
		container.global_position = plant_postion_node_ori_global_position[place]
#endregion

#region 蹦极僵尸偷植物
## 返回当前可偷取的第一层植物；选择目标与实际偷取共用此顺序，失效或死亡实例不参与。
## 僵王的蹦极技能也通过本接口筛选目标（见 z_b_001_doctor_skill_bungee.gd）
func get_bungi_target() -> Plant000Base:
	# 各种植层的偷取优先级；一次只取一株，不连带移除整格植物。
	for place in [
		CharacterRegistry.PlacePlantInCell.Norm,
		CharacterRegistry.PlacePlantInCell.Shell,
		CharacterRegistry.PlacePlantInCell.Down,
		CharacterRegistry.PlacePlantInCell.Float
	]:
		# 先以 Variant 检查可能已释放的引用，再转换植物类型。
		var plant_reference: Variant = get_plant(place)
		if not is_instance_valid(plant_reference):
			continue
		# 只有仍在场景中的存活植物才能成为偷取目标。
		var plant := plant_reference as Plant000Base
		if plant != null and plant.is_inside_tree() and not plant.is_queued_for_deletion() and not plant.is_death:
			return plant
	return null


## 被蹦极僵尸偷植物,返回被偷的植物body复制体
func be_bungi()->Node2D:
	# 执行时重新读取格内植物，避免使用准备阶段已死亡的植物引用。
	var plant: Plant000Base = get_bungi_target()
	return plant.be_bungi() if plant != null else null
#endregion

#region 特殊状态
#region 墓碑相关
## 创建墓碑
func create_tombstone():
	if is_instance_valid(tombstone):
		Log.debug(str("当前植物格子") + str(row_col) + str("已经有墓碑， 创建墓碑失败"))
		return
	## 被墓碑顶掉的植物
	var all_place_plant_in_cell_be_tombstone = [
		CharacterRegistry.PlacePlantInCell.Norm,
		CharacterRegistry.PlacePlantInCell.Down,
		CharacterRegistry.PlacePlantInCell.Shell
	]
	## 删除对应位置植物
	for place_plant_in_cell in all_place_plant_in_cell_be_tombstone:
		## 如果存在植物
		var curr_plant := get_plant(place_plant_in_cell)
		if is_instance_valid(curr_plant):
			curr_plant.character_death()

	tombstone = SceneRegistry.TOMBSTONE.instantiate()
	tombstone.init_tombstone(self)
	add_child(tombstone)
	tombstone.position = Vector2(size.x / 2, size.y)
	update_special_state_plant(true, E_SpecialStatePlant.IsTombstone)

	Global.main_game.plant_cell_manager.tombstone_list.append(tombstone)


## 刪除墓碑，墓碑死亡时调用该函数
func tombstone_death_update_plant_cell_data():
	signal_cell_delete_tombstone.emit(self, tombstone)
	Global.main_game.plant_cell_manager.tombstone_list.erase(tombstone)
	## 等到墓碑被删除后，下一帧更新（如果鼠标拿着新植物在当前格子中，可以更新）
	await get_tree().process_frame
	update_special_state_plant(false, E_SpecialStatePlant.IsTombstone)

#endregion

#region 坑洞相关
## 创建坑洞
func create_crater():
	## 与墓碑/罐子一致的重入保护：重复创建会覆盖 crater 引用，
	## 旧坑洞的计时器到点后还会把新坑洞的特殊状态一起清掉
	if is_instance_valid(crater):
		return
	self.crater = SceneRegistry.DOOM_SHROOM_CRATER.instantiate()
	add_child(crater)
	crater.init_crater(1, self)

	update_special_state_plant(true, E_SpecialStatePlant.IsCrater)

## 创建一个**永久**弹坑：与 create_crater() 的唯一区别是不起消失计时器，
## 只能由 remove_crater() 主动填平（「填坑要花钱 / 不填就一直在」这类规则由调用方自己定，
## 本文件只提供「能起一个不会自己消失的坑」的通用能力）
func create_crater_permanent():
	if is_instance_valid(crater):
		return
	crater = SceneRegistry.DOOM_SHROOM_CRATER.instantiate()
	add_child(crater)
	crater.init_crater(1, self, 0.0)
	update_special_state_plant(true, E_SpecialStatePlant.IsCrater)


## 填平弹坑（永久坑也走这里）
## 与坑自己到点消失走的是同一套状态清理，只是不经过计时器
func remove_crater():
	if not is_instance_valid(crater):
		return
	crater.queue_free()
	crater = null
	update_special_state_plant(false, E_SpecialStatePlant.IsCrater)


## 坑洞调用该函数，坑洞是自己消失后调用该函数
func delete_crater_update_plant_cell_data():
	update_special_state_plant(false, E_SpecialStatePlant.IsCrater)

#endregion

#region 冰道相关
func add_new_ice_road(new_ice_road:IceRoad):
	curr_ice_roads.append(new_ice_road)
	update_special_state_plant(true, E_SpecialStatePlant.IsIceRoad)
	new_ice_road.signal_ice_road_disappear.connect(del_new_ice_road_update_plant_cell_data.bind(new_ice_road))

## 删除冰道
func del_new_ice_road_update_plant_cell_data(new_ice_road: IceRoad) -> void:
	curr_ice_roads.erase(new_ice_road)
	if curr_ice_roads.is_empty():
		update_special_state_plant(false, E_SpecialStatePlant.IsIceRoad)

#endregion

#region 保龄球种植限制
## 设置保龄球不能种植
func set_bowling_no_plant():
	update_special_state_plant(true, E_SpecialStatePlant.IsNoPlantBowling)

## 设置保龄球不能僵尸
func set_bowling_no_zombie():
	update_special_state_zombie(true, E_SpecialStateZombie.IsNoPlantBowling)
#endregion

#region 按植物类型限制种植（观星）
## 本格只允许种这些植物；空 = 不限制（观星的星星轮廓点：只能种杨桃 / 南瓜头）
var only_allow_plant_types: Array[CharacterRegistry.PlantType] = []
## 本格禁止种的植物（观星：把杨桃挡在星星轮廓点之外，免得 125 阳光的杨桃种到别处）
var forbidden_plant_types: Array[CharacterRegistry.PlantType] = []


## 本格是否允许种 plant_type —— 种植条件的**第一道闸**
## （消费方：ResourcePlantCondition.judge_is_can_plant，所有植物都过这一关）
func is_plant_type_allowed(plant_type: CharacterRegistry.PlantType) -> bool:
	if not only_allow_plant_types.is_empty() and not only_allow_plant_types.has(plant_type):
		return false
	return not forbidden_plant_types.has(plant_type)


## 设置本格「只允许种这些植物」（传空数组 = 解除限制）
func set_only_allow_plant_types(types: Array[CharacterRegistry.PlantType]) -> void:
	only_allow_plant_types.assign(types)


## 设置本格「禁止种这些植物」（传空数组 = 解除限制）
func set_forbidden_plant_types(types: Array[CharacterRegistry.PlantType]) -> void:
	forbidden_plant_types.assign(types)
#endregion

#region 罐子
var pot:ScaryPot
const SCARY_POT = preload("uid://bfhjvru3xr23t")

## 生成一个罐子
func create_pot(pot_para:Dictionary) -> ScaryPot:
	if is_instance_valid(pot):
		return
	pot = SCARY_POT.instantiate()
	pot.init_pot(pot_para)
	add_child(pot)
	pot.position = Vector2(size.x / 2, size.y)

	update_special_state_plant(true, E_SpecialStatePlant.IsPot)

	return pot

## 打开罐子后更新数据
func open_pot_update_plant_cell_data():
	update_special_state_plant(false, E_SpecialStatePlant.IsPot)
#endregion

#endregion

#region 鼠标交互相关
func _on_button_pressed() -> void:
	click_cell.emit(self)

func _on_button_mouse_entered() -> void:
	cell_mouse_enter.emit(self)

func _on_button_mouse_exited() -> void:
	cell_mouse_exit.emit(self)


func is_mouse_in_ui(control_node: Control) -> bool:
	return control_node.get_rect().has_point(control_node.get_local_mouse_position())

## 返回当前被铲子威胁的植物
func return_plant_be_shovel_look():
	## 如果当前格子有植物,根据位置选择植物，若位置没有植物，选择别的植物
	if get_curr_plant_num() > 0:
		var plant_place_be_shovel = get_plant_place_from_mouse_pos()
		return return_plant_null_res(plant_place_be_shovel)
	else:
		return null

## 如果当前位置没有植物时，返回顺位植物,递归调用，直到返回植物
## is_loop 表示上次是否判断过是否为norm，shell循环
## 写代码的时候没有float植物，不确定是否有问题
func return_plant_null_res(plant_place_be_shovel:CharacterRegistry.PlacePlantInCell, is_loop:=false):
	match plant_place_be_shovel:
		CharacterRegistry.PlacePlantInCell.Norm:
			var norm_plant := get_plant(CharacterRegistry.PlacePlantInCell.Norm)
			if is_instance_valid(norm_plant):
				return norm_plant
			else:
				if is_loop:
					return return_plant_null_res(CharacterRegistry.PlacePlantInCell.Down, true)
				else:
					return return_plant_null_res(CharacterRegistry.PlacePlantInCell.Shell, true)

		CharacterRegistry.PlacePlantInCell.Shell:
			var shell_plant := get_plant(CharacterRegistry.PlacePlantInCell.Shell)
			if is_instance_valid(shell_plant):
				return shell_plant
			else:
				if is_loop:
					return return_plant_null_res(CharacterRegistry.PlacePlantInCell.Down, true)
				else:
					return return_plant_null_res(CharacterRegistry.PlacePlantInCell.Norm, true)

		CharacterRegistry.PlacePlantInCell.Float:
			var float_plant := get_plant(CharacterRegistry.PlacePlantInCell.Float)
			if is_instance_valid(float_plant):
				return float_plant
			else:
				return return_plant_null_res(CharacterRegistry.PlacePlantInCell.Norm)

		CharacterRegistry.PlacePlantInCell.Down:
			var down_plant := get_plant(CharacterRegistry.PlacePlantInCell.Down)
			if is_instance_valid(down_plant):
				return down_plant
			else:
				return return_plant_null_res(CharacterRegistry.PlacePlantInCell.Float)

## 铲子进入该shell时，判断当前格子是否有多个植物,蹦极僵尸判断是否有植物
## 有多个植物时，会随鼠标移动更新当前被铲子看的植物
func get_curr_plant_num()->int:
	var curr_plant_num = 0
	if is_instance_valid(get_plant(CharacterRegistry.PlacePlantInCell.Norm)):
		curr_plant_num += 1
	if is_instance_valid(get_plant(CharacterRegistry.PlacePlantInCell.Shell)):
		curr_plant_num += 1
	if is_instance_valid(get_plant(CharacterRegistry.PlacePlantInCell.Float)):
		curr_plant_num += 1
	if is_instance_valid(get_plant(CharacterRegistry.PlacePlantInCell.Down)):
		curr_plant_num += 1
	return curr_plant_num

## 鼠标移动检测
#func _input(event):
	#if event is InputEventMouseMotion:
		#_check_mouse_panel_region(event.position)
#
## 根据鼠标在当前格子中的位置，返回应该被铲除的植物
func get_plant_place_from_mouse_pos():
	var local_pos = button.get_local_mouse_position()
	var height = button.size.y
	if local_pos.y < height / 3:
		return CharacterRegistry.PlacePlantInCell.Float
	elif local_pos.y < height * 2 / 3:
		return CharacterRegistry.PlacePlantInCell.Norm
	else:
		return CharacterRegistry.PlacePlantInCell.Shell

#endregion

#region 梯子
## 被挂载梯子
## global_pos:挂载梯子精灵节点的全局位置
func be_ladder():
	ladder = SceneRegistry.LADDER.instantiate()
	ladder.init_ladder(self)
	add_child(ladder)
	for p in plant_in_cell:
		var curr_plant := get_plant(p)
		if is_instance_valid(curr_plant):
			curr_plant.signal_ladder_update.emit()

## 梯子消失
func ladder_loss():
	for p in plant_in_cell:
		var curr_plant := get_plant(p)
		if is_instance_valid(curr_plant):
			curr_plant.signal_ladder_update.emit()


## 获取当前植物格子可以挂载梯子的植物
func get_plant_ladder() -> Plant000Base:
	## 如果有壳类植物
	var shell_plant := get_plant(CharacterRegistry.PlacePlantInCell.Shell)
	if is_instance_valid(shell_plant):
		return shell_plant
	## 如果Norm植物挂载了可挂梯子组件
	var norm_plant:Plant000Base = get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	if is_instance_valid(norm_plant) and is_instance_valid(norm_plant.ladder_component):
		return norm_plant

	return null


#endregion


## 获取周围一圈(包括本身格子)的某个植物
## 网格查询在 PlantCellManager（all_plant_cells / row_col 都在那儿），这里只按 row_col 转发
func get_plant_surrounding(p_t:CharacterRegistry.PlantType) -> Array[Plant000Base]:
	return Global.main_game.plant_cell_manager.get_plant_surrounding(self, p_t)


## 获取周围一圈的植物格子，包括本身
func get_plant_cell_surrounding()->Array[PlantCell]:
	return Global.main_game.plant_cell_manager.get_plant_cell_surrounding(self)

#region 存档
## 植物格子存档
func get_save_game_data_plant_cell() -> ResourceSaveGamePlantCell:
	var save_game_data_plant_cell:ResourceSaveGamePlantCell = ResourceSaveGamePlantCell.new()
	save_game_data_plant_cell.row_col = row_col
	for place_plant_in_cell in plant_in_cell:
		var curr_plant := get_plant(place_plant_in_cell)
		if is_instance_valid(curr_plant):
			save_game_data_plant_cell.plant_type_in_cell[place_plant_in_cell] = curr_plant.gat_save_game_data_plant()

	if is_instance_valid(ladder):
		save_game_data_plant_cell.is_ladder = true

	return save_game_data_plant_cell

## 读档植物格子数据
func load_game_data_plant_cell(save_game_data_plant_cell:ResourceSaveGamePlantCell):
	for place_plant_in_cell in save_game_data_plant_cell.plant_type_in_cell:
		var game_data_plant:Dictionary = save_game_data_plant_cell.plant_type_in_cell[place_plant_in_cell]
		## 读档不带种植特效
		var plant := create_plant(game_data_plant["plant_type"], false, false, game_data_plant["is_imitater_material"])
		if plant != null:
			plant.load_game_data_plant(game_data_plant)

	if save_game_data_plant_cell.is_ladder:
		be_ladder()

## 清除当前植物格子数据
func clear_data_plant_cell():
	for place_plant_in_cell in plant_in_cell:
		var curr_plant := get_plant(place_plant_in_cell)
		if is_instance_valid(curr_plant):
			curr_plant.character_death_disappear()


#endregion
