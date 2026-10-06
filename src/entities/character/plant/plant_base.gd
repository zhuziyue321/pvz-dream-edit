extends Character000Base
class_name Plant000Base

@onready var sleep_component: SleepComponent = %SleepComponent
@onready var blink_component: BlinkComponent = %BlinkComponent
## 花园组件
@onready var garden_component: GardenComponent = %GardenComponent
## 受击状态组件
@onready var be_attack_status_component: BeAttackStatusComponentPlant = %BeAttackStatusComponentPlant
## 模仿者材质组件
@onready var imitater_material_component: ImitaterMaterialComponent = %ImitaterMaterialComponent
## 植物血量组件（植物专用，管理死亡是否直接删除）
@onready var hp_component_plant: HpComponentPlant = %HpComponent
## 可挂载梯子组件（只有可挂梯子的植物挂载，可能为空）
@onready var ladder_component: LadderComponent = get_node_or_null(^"LadderComponent")

#region 植物类基础属性

@export var plant_type:CharacterRegistry.PlantType
## 行和列
var row_col:Vector2i = Vector2i(-1, -1)
## 植物所在格子
var plant_cell:PlantCell
#endregion

#region 组件状态访问
## 植物当前受击状态（由受击状态组件拥有），僵尸攻击检测时判断是否可以攻击
var curr_be_attack_status:BeAttackStatusComponentPlant.E_BeAttackStatusPlant = BeAttackStatusComponentPlant.E_BeAttackStatusPlant.IsNorm:
	get:
		if is_instance_valid(be_attack_status_component):
			return be_attack_status_component.curr_be_attack_status
		return BeAttackStatusComponentPlant.E_BeAttackStatusPlant.IsNorm

## 是否正在睡觉（由睡眠组件拥有）
var is_sleeping:bool:
	get:
		return is_instance_valid(sleep_component) and sleep_component.is_sleeping

## 是否在花园水族馆（由花园组件拥有）
var is_garden_aquarium:bool:
	get:
		return is_instance_valid(garden_component) and garden_component.is_garden_aquarium
#endregion

#region 植物动画

## 植物梯子状态变化信号
@warning_ignore("unused_signal")
signal signal_ladder_update


#region 花园植物
## 花园初始化数据
var garden_date_init:Dictionary
#endregion


#region 初始化相关
func _ready() -> void:
	super()

	if plant_type == 0:
		Log.error(name, "植物类型未赋值")

## 植物初始化属性
enum E_PInitAttr{
	CharacterInitType,	## 角色初始化类型（正常、展示、花园）
	PlantCell,			## 植物格子
	IsImitaterMaterial,	## 是否为模仿者材质
	GardenDate,			## 花园数据
	IsZombieMode,			## 我是僵尸模式
}
## 植物初始化相关, 创建植物时 加入场景树之前赋值
func init_plant(plant_init_para:Dictionary):
	#init_type:E_CharacterInitType=E_CharacterInitType.IsNorm, plant_cell:PlantCell=null, garden_date:Dictionary={}) -> void:
	self.character_init_type = plant_init_para[E_PInitAttr.CharacterInitType]
	## 模仿者材质交给组件处理
	get_node(^"ImitaterMaterialComponent").init_imitater_material(plant_init_para.get(E_PInitAttr.IsImitaterMaterial, false))
	self.is_zombie_mode = plant_init_para.get(E_PInitAttr.IsZombieMode, false)
	match character_init_type:
		E_CharacterInitType.IsNorm:
			self.plant_cell = plant_init_para[E_PInitAttr.PlantCell]
			self.row_col = plant_cell.row_col
			self.lane = plant_cell.row_col.x
		E_CharacterInitType.IsShow:
			### 南瓜背景-1,这里所有植物+1
			#z_index += 1
			pass
		E_CharacterInitType.IsGarden:
			### 南瓜背景-1,这里所有植物+1
			#z_index += 1
			garden_date_init = plant_init_para[E_PInitAttr.GardenDate]

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	## 发射子弹攻击组件影响植物眨眼
	var attack_component :AttackComponentBulletBase = get_node_or_null(^"AttackComponent")
	if attack_component:
		attack_component.signal_change_is_attack.connect(
			## 可以攻击时禁用眨眼
			func(value):blink_component.change_is_enabling(not value, ComponentNormBase.E_IsEnableFactor.Attack)
		)

	## 植物睡眠影响的组件
	for sleep_influence_component in sleep_component.sleep_influence_components:
		sleep_component.signal_is_sleep.connect(sleep_influence_component.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Sleep))
		sleep_component.signal_not_is_sleep.connect(sleep_influence_component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Sleep))

## 初始化正常出战角色
func ready_norm():
	super()

	garden_component.queue_free()
	be_attack_status_component.init_status()
	## 睡眠组件内部判断是否白天睡觉
	sleep_component.judge_is_sleeping()

	GlobalUtils.update_plant_cell_slope_y_array(plant_cell, node2d_detect_in_slope)

## 初始化展示角色
func ready_show():
	super()
	garden_component.queue_free()



## 初始化花园角色
func ready_garden():
	super()
	garden_component.init_garden_component(garden_date_init)
	sleep_component.signal_is_sleep.connect(garden_component.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Sleep))
	sleep_component.signal_not_is_sleep.connect(garden_component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Sleep))
	## 睡眠组件内部判断是否白天睡觉
	sleep_component.judge_is_sleeping()
	shadow.visible = false

#endregion

#region 植物受伤、死亡
## 被蹦极僵尸偷走
func be_bungi()->Node2D:
	var body_copy:Node2D = body.duplicate()
	plant_cell.add_child(body_copy)
	body_copy.global_position = body.global_position
	## 死亡直接消失,复制一个body给蹦极
	character_death_disappear()
	return body_copy

## 被僵尸啃食
## attack_value:伤害
## attack_zombie:攻击的僵尸
func be_zombie_eat(attack_value:int, _attack_zombie:Zombie000Base):
	hp_component.Hp_loss(attack_value,BulletRegistry.AttackMode.Penetration, true, false)

## 被僵尸啃食一次发光
func be_zombie_eat_once(attack_zombie:Zombie000Base):
	body.body_light()
	_be_zombie_eat_once_special(attack_zombie)


## 被僵尸啃食一次特殊效果,魅惑\大蒜\我是僵尸生产阳光
func _be_zombie_eat_once_special(_attack_zombie:Zombie000Base):
	pass

## 植物死亡
func character_death():
	## 发射死亡信号
	super()
	if is_instance_valid(hurt_box_component):
		## 要先删除碰撞器，否则僵尸攻击检测组件有问题
		hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)
	if hp_component_plant.is_death_free:
		queue_free()

## 死亡不消失
func character_death_not_disappear():
	hp_component_plant.is_death_free = false
	hp_component.Hp_loss_death()

#endregion

#region 与铲子\种植交互
## 被铲子威胁
func be_shovel_look():
	if Global.config_service.plant_be_shovel_front:
		z_index += 10
	body.set_other_color(BodyCharacter.E_ChangeColors.BeShovelLookColor, Color(2, 2, 2))

## 被铲子威胁结束
func be_shovel_look_end():
	if Global.config_service.plant_be_shovel_front:
		z_index -= 10
	body.set_other_color(BodyCharacter.E_ChangeColors.BeShovelLookColor, Color(1, 1, 1))

## 被铲子铲除,禁止亡语
func be_shovel_kill():
	is_can_death_language = false
	hp_component.Hp_loss_death()

## 手持紫卡植物可以种植在该植物上
func preplant_purple_body_light_and_dark():
	if Global.config_service.plant_be_shovel_front:
		z_index += 10
	body.body_light_and_dark()

## 手持紫卡植物可以种植在该植物上结束
func preplant_purple_body_light_and_dark_end():
	if Global.config_service.plant_be_shovel_front:
		z_index -= 10
	body.body_light_and_dark_end()

## 坚果包扎术：被补种的新坚果顶掉，血量与外观一起复原到满血
## 原版：把新的同种坚果直接种在受伤的坚果上（不用先挖掉旧的），见 ConstShop.WALL_NUT_FIRST_AID_PRICE
## 返回是否真的修了（已满血 / 没有分段外观的恒为 false，调用方据此决定要不要扣卡）
func be_first_aid_heal() -> bool:
	if not is_instance_valid(hp_component_plant):
		return false
	if hp_component_plant.curr_hp >= hp_component_plant.max_hp:
		return false
	hp_component_plant.curr_hp = hp_component_plant.max_hp
	## 血量阶段组件由坚果 / 高坚果 / 南瓜头各自声明(名字同名但类型一致),
	## 基类里不重复声明成员,直接按节点名取,避免与子类的成员冲突
	var stage_component := get_node_or_null(^"HpStageChangeComponent") as HpStageChangeComponent
	if is_instance_valid(stage_component):
		stage_component.reset_hp_stage()
	return true

#endregion
## 睡眠植物被咖啡豆唤醒
func coffee_bean_awake_up():
	var tween:Tween = create_tween()
	tween.tween_property(body, ^"scale:y", 0.8, 0.5)
	tween.tween_property(body, ^"scale:y", 1.2, 0.5)
	tween.tween_property(body, ^"scale:y", 1, 0.5)
	tween.tween_callback(sleep_component.end_sleep)


#region 花园植物
## 满足当前需求
func satisfy_need(item: GardenManager.E_NeedItem):
	garden_component.satisfy_need(item)

## 获取当前花园植物数据
func get_curr_plant_data():
	return garden_component.get_curr_plant_data()
#endregion

## 获取植物存档数据
func gat_save_game_data_plant()->Dictionary:
	var save_game_data_plant:Dictionary = {}
	save_game_data_plant["is_sleeping"] = is_sleeping
	save_game_data_plant["plant_type"] = plant_type
	save_game_data_plant["curr_hp"] = hp_component.curr_hp
	save_game_data_plant["is_imitater_material"] = imitater_material_component.is_imitater_material
	return save_game_data_plant

## 读档植物数据
func load_game_data_plant(save_game_data_plant:Dictionary):
	## 原本是睡觉，存档不睡觉
	if is_sleeping and not save_game_data_plant.get("is_sleeping", true):
		sleep_component.end_sleep()

	hp_component.curr_hp = save_game_data_plant["curr_hp"]
	hp_component.signal_hp_loss.emit(hp_component.curr_hp, true)
