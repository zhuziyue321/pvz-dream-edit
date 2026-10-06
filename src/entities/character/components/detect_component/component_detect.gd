extends ComponentNormBase
## 攻击射线检测组件,根据owner自动选择敌人层
class_name DetectComponent

## 每帧判断是否检测当前敌人
## 敌人进入\离开\状态变化时检测
## 敌人进入时连接状态变化函数，离开时不断开
## **植物和僵尸通用**
#region 检测层以及对应的值
## 层类型
enum E_LayType{
	PlantEnemy,		## 植物的敌人
	ZombieEnemy,	## 僵尸的敌人
	Item,			## 道具
}
## 可以检测的道具
enum E_ItemType{
	Brain = 1,	## 脑子（我是僵尸模式）
	Pot = 2,	## 罐子
	Other = 4,	## 占位
}

## 层类型对应的值（检测）
## 注意：魅惑僵尸与普通僵尸同在 layer 3（位值 4），所以僵尸方必须把 4 也放进 mask，
## 再由 _judge_enemy_is_can_be_attack 用归属阵营把非魅惑的同伴过滤掉（见 get_owner_camp）
const C_LayTypeValueDetection:Dictionary[E_LayType, int]={
	E_LayType.PlantEnemy:4,		## 僵尸
	E_LayType.ZombieEnemy:2+4,	## 植物+僵尸（含魅惑僵尸）
	E_LayType.Item:2048,		## 道具
}
## 层类型对应的值（真实）
const C_LayTypeValueReal:Dictionary[E_LayType, int]={
	E_LayType.PlantEnemy:512,		## 僵尸
	E_LayType.ZombieEnemy:256+512,	## 植物+僵尸（含魅惑僵尸）
	E_LayType.Item:4096,			## 道具
}
#endregion

## 是否使用行属性进行攻击判断
@export var is_lane:=true
## 检测组件是否为检测层(否时为检测真实层,杨桃)
@export var is_dectection := true
@export_group("可检测道具")
## 是否检测脑子
@export_flags("1 脑子", "2 罐子", "4 占位") var is_detect_items:int = 0
## 检测到的道具
var brain:BrainOnZombieMode
## 罐子
var pot:ScaryPot

## 当前检测层
var curr_collision_lay:int = 0
## 更新当前检测层，同时改所有的检测节点的检测层
## curr_character[int]: 当前角色，用于判断敌人类型，1:植物的敌人，2:僵尸的敌人, 3:两者都有
func update_curr_collision_lay(curr_character:int):
	## 如果检测层面
	if is_dectection:
		_set_curr_collision_lay_value(curr_character, C_LayTypeValueDetection)
	else:
		_set_curr_collision_lay_value(curr_character, C_LayTypeValueReal)

	## 更新所有检测区域的敌人mask层
	for node in get_children():
		if node is Area2D:
			var area_2d = node as Area2D
			area_2d.collision_mask = curr_collision_lay
## 设置当前检测层
## curr_character[int]: 当前角色，用于判断敌人类型，1:植物的敌人，2:僵尸的敌人, 3:两者都有
## lay_type_value[Dictionary]: 检测层面\真实层面对应的检测层数值
func _set_curr_collision_lay_value(curr_character:int, lay_type_value:Dictionary[E_LayType, int]):
	curr_collision_lay = 0
	if curr_character & 1:
		curr_collision_lay |= lay_type_value[E_LayType.PlantEnemy]
	if curr_character & 2:
		curr_collision_lay |= lay_type_value[E_LayType.ZombieEnemy]
	## 检测道具
	if is_detect_items != 0:
		curr_collision_lay |= lay_type_value[E_LayType.Item]

## 是否攻击梯子下的植物,僵尸初始化时根据is_ignore_ladder更新该值，默认攻击，僵尸一般不攻击，只有巨人和冰车攻击
var is_attack_ladder_plant:=true

## 检测到的敌人
## (不能攻击是因为敌人状态不在攻击状态中，连接状态变化信号)
## 检测到的可以被攻击的一个敌人,给特殊植物\僵尸\抛物线子弹使用
## 僵王也是正式角色（ZB000Base 继承 Character000Base），复用同一个字段
var enemy_can_be_attacked :Character000Base = null
## 是否需要判断检测敌人
var need_judge := false

## 检测区域列表
var all_ray_area:Array[Area2D]
## 检测区域的方向,部分植物发射子弹使用
var ray_area_direction:Array[Vector2]
## 可以攻击的敌人状态掩码组件（未在场景中配置时按检测组件默认值创建）
@onready var can_attack_status_component: CanAttackStatusComponent = get_node_or_null(^"CanAttackStatusComponent")

## 外部需要的组件（攻击行为组件）连接该信号
## 检测到可攻击敌人，可以攻击信号
signal signal_can_attack
## 无可攻击敌人，取消攻击信号
signal signal_not_can_attack

func _ready() -> void:
	## 必须调 super：ComponentNormBase._ready() 负责「场景里配了 is_enable_default = false 就禁用组件」，
	## 不调的话这条会丢，配了默认禁用的检测组件一进关就开始检测敌人
	super._ready()
	_ensure_can_attack_status_component()
	## 魅惑不再切换碰撞层，周围已经重叠着的检测组件收不到 area_entered，
	## 靠这条广播让全场重新判定一次敌我（见 _on_character_be_hypno）
	EventBus.subscribe("character_be_hypno", _on_character_be_hypno)
	if owner is Plant000Base:
		update_curr_collision_lay(1)
	elif owner is Zombie000Base:
		update_curr_collision_lay(2)
	elif owner is MainGameManager:
		update_curr_collision_lay(1)
	else:
		Log.error("组件owner不是植物或者僵尸基类角色")

	## 连接所有子节点（area2d）的信号[三线、杨桃等有多个射线area2d]
	## 注意：本组件自身会新增 CanAttackStatusComponent 子节点，必须过滤非 Area2D
	for child in get_children():
		if child is Area2D:
			var area_2d: Area2D = child
			area_2d.area_entered.connect(_on_area_2d_area_entered)
			area_2d.area_exited.connect(_on_area_2d_area_exited)
			all_ray_area.append(area_2d)
			ray_area_direction.append(Vector2(cos(area_2d.rotation), sin(area_2d.rotation)))

	## 如果是角色类型(世界有一个全局检测组件,用于追踪型子弹检查敌人)
	if owner is Character000Base and owner.lane == -1 and owner.character_init_type == Character000Base.E_CharacterInitType.IsNorm:
		Log.error(owner.name + "lane == -1且为正常出战初始化类型")


func _exit_tree() -> void:
	EventBus.unsubscribe("character_be_hypno", _on_character_be_hypno)


## 僵王状态变化（受击窗口开关）只标记重查；受击框启停产生的进入/退出事件还会再刷新一次
func _on_enemy_boss_status_update() -> void:
	need_judge = true


## 场上任一角色被魅惑：敌我关系变了，下一帧重新判定目标
## （原实现靠切换受击层触发 area_entered / area_exited，层简化后没有这个副作用了）
func _on_character_be_hypno(_payload: Variant = null) -> void:
	need_judge = true

## 确保存在可攻击状态掩码组件（未在场景中配置时按检测组件默认掩码创建）
func _ensure_can_attack_status_component() -> void:
	if is_instance_valid(can_attack_status_component):
		return
	can_attack_status_component = CanAttackStatusComponent.new()
	can_attack_status_component.name = "CanAttackStatusComponent"
	can_attack_status_component.can_attack_plant_status = 9
	can_attack_status_component.can_attack_zombie_status = 1
	add_child(can_attack_status_component)


func _process(_delta: float) -> void:
	if need_judge and is_enabling:
		need_judge = false
		judge_is_have_enemy()

## 启用组件
func enable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)
	if is_enabling:
		need_judge = true

## 禁用组件
func disable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)
	enemy_can_be_attacked = null
	signal_not_can_attack.emit()
	need_judge = false

#region 敌人进入、离开或状态更新（植物：梯子状态、僵尸：状态）
## 敌人进入当前区域，若为同一行，当前帧进行判断是否可以攻击
func _on_area_2d_area_entered(area: Area2D) -> void:
	var enemy = area.owner
	## 僵王跨行由检测框覆盖范围决定，普通角色仍保留同行限制。
	if not enemy is ZB000Base and is_lane and owner.lane != enemy.lane:
		return
	if enemy is ZB000Base:
		if not enemy.signal_status_update.is_connected(_on_enemy_boss_status_update):
			enemy.signal_status_update.connect(_on_enemy_boss_status_update)
	elif enemy is Plant000Base:
		if not enemy.signal_ladder_update.is_connected(_on_enemy_plant_ladder_update.bind(enemy)):
			enemy.signal_ladder_update.connect(_on_enemy_plant_ladder_update.bind(enemy))
	elif enemy is Zombie000Base:
		if not enemy.signal_status_update.is_connected(_on_enemy_zombie_status_update.bind(enemy)):
			enemy.signal_status_update.connect(_on_enemy_zombie_status_update.bind(enemy))
		if not enemy.signal_lane_update.is_connected(_on_enemy_zombie_lane_update.bind(enemy)):
			enemy.signal_lane_update.connect(_on_enemy_zombie_lane_update.bind(enemy))
	need_judge = true

## 敌人离开当前射线检测区域
@warning_ignore("unused_parameter")
func _on_area_2d_area_exited(area: Area2D) -> void:
	need_judge = true

## 植物敌人梯子状态变化
@warning_ignore("unused_parameter")
func _on_enemy_plant_ladder_update(plant:Plant000Base):
	need_judge = true

## 僵尸敌人状态变化时函数，与状态变化信号连接
@warning_ignore("unused_parameter")
func _on_enemy_zombie_status_update(zombie:Zombie000Base):
	need_judge = true

## 僵尸敌人行变化时函数，与行变化信号连接
@warning_ignore("unused_parameter")
func _on_enemy_zombie_lane_update(zombie:Zombie000Base):
	need_judge = true
#endregion

#region 检测是否有敌人\道具
## 如果检测到可以被攻击的敌人\道具，发射信号,保存当前敌人，return,若到最后没有检测到敌人，发射信号，重置当前敌人，return
func judge_is_have_enemy():
	#Log.debug("判定敌人")
	## 僵王是正式角色，与普通僵尸走同一条判定链（跨行由检测框几何决定）
	for ray_area in all_ray_area:
		var all_enemy_area = ray_area.get_overlapping_areas()
		for enemy_area in all_enemy_area:
			## 先检测角色
			if enemy_area.owner is Character000Base:
				if _on_detect_character(enemy_area.owner):
					signal_can_attack.emit()
					return true
			## 检测到道具
			elif enemy_area.owner is MainGameItemBase:
				if _on_detect_main_game_item(enemy_area.owner):
					signal_can_attack.emit()
					return true

	## 如果循环结束还未return,未找到敌人
	enemy_can_be_attacked = null
	signal_not_can_attack.emit()
	return false

## 当检测到道具
func _on_detect_main_game_item(curr_main_game_item:MainGameItemBase)->bool:
	## 可以检测罐子 并且 检测到罐子
	if is_detect_items & E_ItemType.Pot and curr_main_game_item is ScaryPot:
		Log.debug("检测到罐子")
		pot = curr_main_game_item
		return true
	## 可以检测脑子 并且 检测到脑子
	elif is_detect_items & E_ItemType.Brain and curr_main_game_item is BrainOnZombieMode:
		Log.debug("检测到脑子")
		brain = curr_main_game_item
		return true
	else:
		#Log.debug("未检测到道具")
		return false

## 当检测到角色
func _on_detect_character(enemy:Character000Base) -> bool:
	## 如果角色可以被攻击，更新当前可以被攻击的角色
	if _judge_enemy_is_can_be_attack(enemy):
		if enemy is Plant000Base:
			enemy_can_be_attacked = get_first_be_hit_plant_in_cell(enemy)
		elif enemy is Zombie000Base or enemy is ZB000Base:
			enemy_can_be_attacked = enemy
		## 该格子可能没有可攻击的植物，此时直接返回，避免对 null 连接信号
		if enemy_can_be_attacked == null:
			return false
		## 用命名方法 + is_connected 判断，
		## 否则每帧都会新建一个 lambda 连上去，连接数无限增长
		if not enemy_can_be_attacked.signal_character_death.is_connected(_on_enemy_can_be_attacked_death):
			enemy_can_be_attacked.signal_character_death.connect(_on_enemy_can_be_attacked_death)
		return true
	else:
		return false


## 当前可攻击角色死亡时，下一帧重新判定
func _on_enemy_can_be_attacked_death() -> void:
	need_judge = true

## 获取应该被攻击的植物,在当前植物格子中
## 选择规则（Shell > Norm > Imitater > Down > Float）在 DetectTargetStrategy，这里是转发
func get_first_be_hit_plant_in_cell(plant:Plant000Base)->Plant000Base:
	return DetectTargetStrategy.get_first_be_hit_plant_in_cell(
		plant, can_attack_status_component.can_attack_plant_status
	)

## 判断敌人状态是否可以被攻击
func _judge_enemy_is_can_be_attack(enemy:Character000Base)->bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_death:
		return false
	## 僵王：状态机直接控制受击组件，不检查同行，也不需要僵王专属的检测开关。
	## 跨行能否打到完全由检测框的几何覆盖范围决定（见僵王说明文档「受击资格与植物交互」）。
	if enemy is ZB000Base:
		return enemy.character_init_type == Character000Base.E_CharacterInitType.IsNorm \
			and is_instance_valid(enemy.hurt_box_component) and enemy.hurt_box_component.is_enabling \
			and (can_attack_status_component.can_attack_zombie_status & Zombie000Base.E_BeAttackStatusZombie.IsNorm) != 0
	## 先判断行属性
	if is_lane and owner.lane != enemy.lane:
		return false
	## 敌我不再由碰撞层区分（魅惑变体层已废弃），改由归属阵营过滤：
	## 普通僵尸不会啃同伴，但会啃魅惑僵尸；植物不打魅惑僵尸；魅惑僵尸啃普通僵尸、不啃植物
	## owner 不是角色时（全局检测组件挂在 MainGameManager 上）跳过，敌我交给调用方的 camp 参数
	var owner_camp := BulletCampConfig.get_owner_camp(owner)
	if (owner_camp != CharacterRegistry.CharacterType.Null
	and not BulletCampConfig.is_enemy(owner_camp, enemy)):
		return false
	## 如果敌人为植物
	if enemy is Plant000Base:
		## 如果当前植物可以被攻击到
		if can_attack_status_component.can_attack(enemy):
			## 梯子
			if is_attack_ladder_plant:
				return true
			else:
				## 判断格子是否有梯子
				return not is_instance_valid(enemy.plant_cell.ladder)
		else:
			return false

	## 检测到僵尸
	elif enemy is Zombie000Base:
		if can_attack_status_component.can_attack(enemy):
			return true
		else:
			return false

	## 其余东西
	else:
		#Log.debug("检测到非角色类敌人")
		return false

#endregion

#region 检测组件提供的通用方法
## 更新可攻击敌人为第一个敌人(最前面的敌人),投手类使用
## 僵王是正式角色，与普通僵尸一起参与「最靠前」比较，不再单独兜底
func update_first_enemy()->Character000Base:
	enemy_can_be_attacked = null
	for ray_area in all_ray_area:
		var all_enemy_area = ray_area.get_overlapping_areas()
		for enemy_area in all_enemy_area:
			var enemy = enemy_area.owner
			if not enemy is Character000Base:
				continue
			## 如果敌人可以被攻击
			if _judge_enemy_is_can_be_attack(enemy):
				if is_instance_valid(enemy_can_be_attacked):
					if enemy_can_be_attacked.global_position.x > enemy.global_position.x:
						enemy_can_be_attacked = enemy
				else:
					enemy_can_be_attacked = enemy
	return enemy_can_be_attacked


## 获取所有可以被攻击的敌人
func get_all_enemy_can_be_attacked()->Array[Character000Base]:
	var all_enemy_can_be_attacked:Array[Character000Base]
	for ray_area in all_ray_area:
		var all_enemy_area = ray_area.get_overlapping_areas()
		for enemy_area in all_enemy_area:
			if enemy_area.owner is Character000Base:
				var enemy:Character000Base = enemy_area.owner
				## 如果敌人可以被攻击
				if _judge_enemy_is_can_be_attack(enemy) and not all_enemy_can_be_attacked.has(enemy):
					all_enemy_can_be_attacked.append(enemy)
	return all_enemy_can_be_attacked

#endregion

#region 被魅惑
## 僵尸被魅惑
func owner_be_hypno():
	update_curr_collision_lay(1)
	disable_component(ComponentNormBase.E_IsEnableFactor.Hypno)
	enable_component(ComponentNormBase.E_IsEnableFactor.Hypno)
#endregion

#region 特殊使用：仙人掌、全局攻击
## 判断是否有空中僵尸敌人（索敌规则在 DetectTargetStrategy.find_zombie_in_sky）
func judge_zombie_in_sky() -> bool:
	var sky_enemy := DetectTargetStrategy.find_zombie_in_sky(
		all_ray_area, owner.lane, is_lane, can_attack_status_component
	)
	if sky_enemy == null:
		return false
	enemy_can_be_attacked = sky_enemy
	return true



## 更新敌人 enemy_can_be_attacked,追踪型子弹
"""
追踪子弹首次检测敌人直接锁定,直到敌人死亡,在选择下一个敌人(当前检测组件保存敌人)，若敌人死亡，重新选择
第一次索敌时有空中敌人先攻击空中敌人
选择敌人时按本方推进方向靠前的优先（植物方 x 更小，僵尸方 x 更大）
发射子弹的植物,若前一格有敌人,优先索敌前一格敌人,不使用全局索敌
"""
## [camp] 索敌方阵营：只挑敌对阵营的候选（默认植物方，即打僵尸）
## 注意：全局检测组件（main_game_base.tscn 的 DetectComponentGlobal）目前仍是植物视角，
## 僵尸方追踪子弹要先补一个僵尸视角的全局检测组件，否则这里拿不到植物候选
func update_enemy_track_bullet(
	camp:CharacterRegistry.CharacterType = CharacterRegistry.CharacterType.Plant
) -> Character000Base:
	## 上一次锁定的目标可能已死亡并被 queue_free（本组件没连它的死亡信号），
	## 残留的已释放引用必须在传参前清成 null，否则类型化形参会在调用时报错
	if not is_instance_valid(enemy_can_be_attacked):
		enemy_can_be_attacked = null
	## 所有的可以攻击的敌人
	var all_enemy_can_be_attacked:Array[Character000Base] = get_all_enemy_can_be_attacked()
	## 空中优先、其余按推进方向靠前的顺序，规则在 DetectTargetStrategy
	enemy_can_be_attacked = DetectTargetStrategy.pick_enemy_for_track_bullet(
		all_enemy_can_be_attacked, enemy_can_be_attacked, camp
	)
	return enemy_can_be_attacked


## 本组件代表的阵营（owner 是植物 → 植物方；僵尸 → 僵尸方）
## 魅惑僵尸归属植物方，所以这里用「归属阵营」而不是类型阵营
## 全局检测组件的 owner 是 MainGameManager，返回 Null —— 它的阵营由调用方显式传入
func get_owner_camp() -> CharacterRegistry.CharacterType:
	return BulletCampConfig.get_owner_camp(owner)

#endregion
