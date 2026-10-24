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

@export var plant_type: StringName
## 行和列
var row_col:Vector2i = Vector2i(-1, -1)
## 植物所在格子
var plant_cell:PlantCell
#endregion


#region 叠层植物
## 同格最多能叠几层（1 = 普通植物，不可叠）
##
## ★ 给「同格再种一次本植物 = 叠一层」这类玩法留的口子（先例：PVZ2 豌豆荚，最多 5 层）。
##   判定与落位由 `ResourcePlantCondition.judge_is_can_plant()` / `PlantCell.create_plant()`
##   走下面这两个方法，本体不需要认识任何具体植物。
@export var max_stack_layers: int = 1

## 当前叠了几层（普通植物恒为 1）
var stack_layers: int = 1


## 还能不能再叠一层：默认不能，叠层植物自己重写
func can_stack_up() -> bool:
	return false


## 叠一层（同格再种一次本植物时由 `PlantCell.create_plant()` 调）
## [return] 叠上了返回 true —— 调用方据此**不再新建一株**
func try_stack_up() -> bool:
	return false
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

## 出战时的初始动画状态（空 = 用 `*_idle`）
##
## ★ 各植物 `.tscn` 里 `Start → *` 的边已从「表达式推导」改成手动 travel，
##   初始状态统一由 `_apply_initial_anim_state()` 选：
##   睡眠 → `norm_anim_state` → `*_idle`；展示态看 `show_anim_state` → `*_idle_only` → `*_idle`。
##   典型用处：樱桃 / 辣椒 / 咖啡豆 / 三叶草 / 墓碑吞噬者 / 模仿者 / 毁灭菇 —— 出战即播一次性动画。
@export var norm_anim_state: StringName = &""
## 展示时的初始动画状态（空 = `*_idle_only` → `*_idle`）
##
## 典型用处：阳光菇展示体是"成长后"形态、土豆雷展示体是"已升起"形态。
@export var show_anim_state: StringName = &""


## **显式请求动画状态**（单人时由植物代码控制；联机客户端由包分发控制，这里自动忽略）
##
## ★ 与"改 `is_xxx` 字段、让动画树的 `advance_expression` 自己推导"是同一件事的两种写法：
##   本方法把"播哪条"从场景里的表达式搬回代码，读代码就能知道动画什么时候变。
##
## ⚠️ 用之前必须先清掉目标状态那条转换的 `advance_expression`，否则状态机的自动推进
##   会在下一帧把状态切回去（见 `AnimComponentNorm.request_state()` 的注释）。
## ⚠️ 状态名是 `AnimationNodeStateMachine` 里的状态名（见该植物 `.tscn` 的动画树），
##   写错会打一条 WARN 而不是静默不动。
func request_anim_state(state: StringName) -> void:
	if is_instance_valid(anim_component):
		anim_component.request_state(state)


## **显式播一次动画**（OneShot）：发射一发、咬一口这类"一次性动作"
##
## `param` 是动画树里的 OneShot 请求参数路径，默认与攻击组件一致。
func request_anim_one_shot(param: StringName = &"parameters/OneShot/request") -> void:
	if is_instance_valid(anim_component):
		anim_component.request_one_shot(param)


## 睡眠开始：切到该植物的睡眠动画（状态名 `*_sleep` 按后缀在状态机里找）
##
## ★ 这条对**所有植物**通用（蘑菇类 10 株），所以写在基类而不是逐株硬编码状态名。
func _on_anim_sleep_start() -> void:
	_request_state_by_suffix(&"_sleep", true)


## 睡眠结束：切回待机（状态名 `*_idle`）
##
## ⚠️ 冰菇有一对"展示待机"（`IceShroom_idle_only`）与"出战待机"（`IceShroom_idle`），
##    所以展示状态优先找 `_idle_only`，找不到再退回 `_idle`。
func _on_anim_sleep_end() -> void:
	_after_anim_wake()


## 睡醒之后播什么（默认回待机；"醒来就炸"的毁灭菇覆盖它）
func _after_anim_wake() -> void:
	## ⚠️ 冰菇有一对"展示待机"（`IceShroom_idle_only`）与"出战待机"（`IceShroom_idle`）
	if is_show and _request_state_by_suffix(&"_idle_only"):
		return
	_request_state_by_suffix(&"_idle")


## 初始动画状态（各植物 `.tscn` 里 `Start → *` 的边已改成手动 travel，初始状态由这里选）
##
## 顺序：睡眠 → 展示态 → 花园态 → 出战态
func _apply_initial_anim_state() -> void:
	## 1) 真睡着了就睡，别管展示 / 花园 / 出场动画
	if is_sleeping and _request_state_by_suffix(&"_sleep"):
		return
	## 2) 展示态
	if is_show:
		if show_anim_state != &"":
			request_anim_state(show_anim_state)
			return
		if _request_state_by_suffix(&"_idle_only"):
			return
		_request_state_by_suffix(&"_idle")
		return
	## 3) 花园态（水族馆背景）
	if character_init_type == E_CharacterInitType.IsGarden:
		if is_garden_aquarium and _request_state_by_suffix(&"_idle_aquarium"):
			return
		_request_state_by_suffix(&"_idle")
		return
	## 4) 出战态（一次性出场动画由场景配 `norm_anim_state`）
	if norm_anim_state != &"":
		request_anim_state(norm_anim_state)
		return
	_request_state_by_suffix(&"_idle")


## 按状态名后缀找状态并请求切换（本地驱动；客户端被接管时自动忽略）
##
## 返回是否找到了状态 —— 调用方可以据此回退到别的后缀（如 `_idle_only` → `_idle`）。
func _request_state_by_suffix(suffix: StringName, is_warn: bool = false) -> bool:
	if not is_instance_valid(anim_component):
		return false
	var state := anim_component.find_state_by_suffix(suffix)
	if state == &"":
		if is_warn:
			Log.warn("[Plant000Base] 状态机里没有以 %s 结尾的状态（植物 %s）"
					% [suffix, plant_type])
		return false
	anim_component.request_state(state)
	return true


#region 花园植物
## 花园初始化数据
var garden_date_init:Dictionary
#endregion


#region 初始化相关
func character_ready() -> void:
	## 空 id 而不是 0：植物类型是 StringName（见 `PlantIds`），没有"第 0 号"这回事
	if plant_type == PlantIds.NULL:
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
	## ★ 睡眠切换动画状态：原来靠动画树的 `is_sleeping` 表达式自己推导，
	##   现在由本回调点名（状态名按 `*_sleep` / `*_idle` 后缀在状态机里找，全植物通用）
	sleep_component.signal_is_sleep.connect(_on_anim_sleep_start)
	sleep_component.signal_not_is_sleep.connect(_on_anim_sleep_end)

## 初始化正常出战角色
func ready_norm():
	super()

	garden_component.queue_free()
	be_attack_status_component.init_status()
	## 睡眠组件内部判断是否白天睡觉
	sleep_component.judge_is_sleeping()

	GlobalUtils.update_plant_cell_slope_y_array(plant_cell, node2d_detect_in_slope)
	## ★ 初始动画状态（`Start → *` 边已改成手动 travel）
	_apply_initial_anim_state()

## 初始化展示角色
func ready_show():
	super()
	garden_component.queue_free()
	## ★ 展示态的初始动画状态（冰菇走 `*_idle_only`，阳光菇走成长形态等）
	_apply_initial_anim_state()



## 初始化花园角色
func ready_garden():
	super()
	garden_component.init_garden_component(garden_date_init)
	sleep_component.signal_is_sleep.connect(garden_component.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Sleep))
	sleep_component.signal_not_is_sleep.connect(garden_component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Sleep))
	## 花园里的蘑菇同样会睡 / 醒（与 normal 同一条动画切换）
	sleep_component.signal_is_sleep.connect(_on_anim_sleep_start)
	sleep_component.signal_not_is_sleep.connect(_on_anim_sleep_end)
	## 睡眠组件内部判断是否白天睡觉
	sleep_component.judge_is_sleeping()
	anim_component.apply_visual({&"kind": AnimComponentBase.VISUAL_SHADOW_VISIBLE, &"visible": false})
	## ★ 花园态的初始动画状态（水族馆背景走 `*_idle_aquarium`）
	_apply_initial_anim_state()

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

## 被僵尸啃食：走基类 `Character000Base.be_zombie_eat()`（穿透伤害 + 不播受击音效），
## 植物侧没有特殊分支，不再重写 —— 重写却和基类一模一样，将来改基类就会漏掉这里。
## 需要"被啃时做点什么"的子类改重写 `be_zombie_eat_once()`（大蒜 / 魅惑 / 我是僵尸走这条）。

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
	hp_component.hp_loss_to_death()

#endregion

#region 与铲子\种植交互
## 被铲子威胁
func be_shovel_look():
	if Global.config_service.plant_be_shovel_front:
		## 层级走表现接口（`VISUAL_Z` 记的是增量，与旧的 `z_index += 10` 等价）
		anim_component.apply_visual({&"kind": AnimComponentBase.VISUAL_Z, &"offset": 10})
		body.set_other_color(BodyCharacter.E_ChangeColors.BeShovelLookColor, Color(2, 2, 2))

## 被铲子威胁结束
func be_shovel_look_end():
	if Global.config_service.plant_be_shovel_front:
		anim_component.apply_visual({&"kind": AnimComponentBase.VISUAL_Z, &"offset": 0})
		body.set_other_color(BodyCharacter.E_ChangeColors.BeShovelLookColor, Color(1, 1, 1))

## 被铲子铲除,禁止亡语
func be_shovel_kill():
	is_can_death_language = false
	hp_component.hp_loss_to_death()

## 手持紫卡植物可以种植在该植物上
func preplant_purple_body_light_and_dark():
	if Global.config_service.plant_be_shovel_front:
		anim_component.apply_visual({&"kind": AnimComponentBase.VISUAL_Z, &"offset": 10})
	body.body_light_and_dark()

## 手持紫卡植物可以种植在该植物上结束
func preplant_purple_body_light_and_dark_end():
	if Global.config_service.plant_be_shovel_front:
		anim_component.apply_visual({&"kind": AnimComponentBase.VISUAL_Z, &"offset": 0})
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

## 喂巧克力（原版 FeedChocolateToPlant：植物进入"嗨"状态、产币加速）
## 返回是否喂成功：不满足原版 PlantCanHaveChocolate（满级 + 今天已照顾 + 当前不嗨）时返回 false
func feed_chocolate() -> bool:
	return garden_component.feed_chocolate()

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
