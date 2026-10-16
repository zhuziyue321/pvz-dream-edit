extends Node2D
class_name Character000Base

#region 子节点
@onready var body: BodyCharacter = %Body
## 角色必备组件(受击盒子组件、血量组件)
@onready var hurt_box_component:HurtBoxComponent = %HurtBoxComponent

@onready var hp_component: HpComponent = %HpComponent
@onready var anim_component: AnimComponentBase = %AnimComponent

@onready var shadow: Sprite2D = %Shadow

## 计时器种类
enum E_TimerType{
	IceDecelerate,	## 冰冻减速
	IceFreeze,		## 冰冻停滞
	Butter,			## 黄油
	Slow,			## 通用减速（伤害系统的 `EFFECT_SLOW` 效果）
}
## 减速相关计时器(第一次使用时创建)
var all_timer:Dictionary[E_TimerType, Timer] = {
	E_TimerType.IceDecelerate:null,
	E_TimerType.IceFreeze:null,
	E_TimerType.Butter:null,
	E_TimerType.Slow:null,
}
#endregion

#region 基础属性

## 角色实际方向改变时,body方向为角色实际方向基础的body方向
@export_group("角色方向")
## 角色实际方向(1为默认方向,-1为反方向)被魅惑时改变方向
@export var direction_x_root := 1
## 不改变方向的节点(睡眠组件\血条显示),当角色实际方向改变时,将该组件方向修改回来
@export var node_no_change_direction:Array[Node2D]
## body方向(1为默认方向,-1为反方向)[舞王\花园使用]
@export var direction_x_body := 1
## 跟随body方向的节点(body\影子\灰烬)
@export var node_follow_body_direction:Array[Node2D]
## 是否为我是僵尸模式
var is_zombie_mode:=false

@export_group("角色速度")
## 角色速度随机范围
@export var random_speed_range :Vector2 = Vector2(0.9, 1.1)
## 角色所在行
var lane:int = -1
## 速度改变量
var influence_speed_factors :Dictionary[E_Influence_Speed_Factor, float]= {
}
enum E_Influence_Speed_Factor{
	InitRandomSpeed,
	IceDecelerateSpeed,
	IceFreezeSpeed,
	Slow,			## 通用减速（伤害系统的 `EFFECT_SLOW` 效果，与冰冻减速分开计）
	HammerZombieSpeed,	## 锤僵尸模式修改速度
	ZamboniHp,		## 冰车僵尸血量变化时
	Butter,			## 黄油
	EatGarlic,		## 啃食大蒜后短时间停止
	BungiCarry,		## 被蹦极僵尸吊在绳子上（下落过程中整体静止，落地才恢复）
	LevelSpeed,		## 关卡全场加速（资源字段 ResourceLevelData.speed_factor_*，见「僵尸快跑」关）
}
## 网络实体 id（**稳定标识**，0 = 未分配）
##
## 为什么要有：`get_instance_id()` 是进程内的，换个进程就对不上，也没法写进网络包。
## 联机 / 回放要说清"哪一只僵尸"时，必须有两端一致的编号。
## 出战角色在 `_ready()` 里自动领一个（自增）；客户端由主机下发的创建消息指定，
## 调用 `assign_entity_id()` 在入树前塞进去，`_ready()` 看到非 0 就不再分配。
## 编号只是标识，**不参与任何玩法判定**，单机与联机的行为完全一致。
var entity_id:int = 0
## 下一个待分配的实体 id（静态：分配器全场一份，与具体角色无关）
static var _next_entity_id:int = 1

## 是否被魅惑
var is_hypno:bool = false
## 该角色是否被设定为隐形（通用外观项，由僵尸初始化参数 E_ZInitAttr.IsInvisible 下发）
## 只表示「设定」：当前是否真的隐形看 BodyCharacter.is_invisible
var is_invisible := false
## 影子在隐形前的透明度，现形时还原
var shadow_alpha_before_invisible := 1.0
## 冰冻结束后减速时间（每次被冰冻时赋值）
var time_ice_end_decelerate := 5.0
## 冰冻特效
var ice_effect:IceEffect

## 是否可以触发亡语(爆炸\大嘴花\铲子不可以触发)
var is_can_death_language:=true

## 速度改变信号 speed_factor_product: 速度系数乘积
signal signal_update_speed(speed_factor_product:float)

@export_group("动画状态")
@export var is_death:=false
@export var is_idle := true
## 是否为展示\花园状态
@export var is_show := false

## 角色死亡信号
signal signal_character_death()
## 角色被魅惑信号
signal signal_character_be_hypno()
## 角色方向更新信号，被魅惑时发出，血条、睡觉显示方向修改
signal signal_direction_x_root_update(direction_x:int)
## body方向更新信号
signal signal_direction_x_body_update(direction_x:int)
#region 更新角色方向
## 更新角色本体方向
func update_direction_x_root(direction_x:int):
	direction_x_root = direction_x
	scale.x = abs(scale.x) * sign(direction_x)
	signal_direction_x_root_update.emit(direction_x_root)

## 更新角色body方向
func update_direction_x_body(direction_x:int):
	direction_x_body = direction_x
	signal_direction_x_body_update.emit(direction_x_body)
#endregion

#region 展示show角色相关
@export_group("初始化类型相关")
enum E_CharacterInitType{
	IsNorm,		## 普通出战
	IsShow,		## 展示状态（关卡前展示、图鉴）
	IsGarden,	## 花园状态
}

## 角色初始化类型
@export var character_init_type :E_CharacterInitType = E_CharacterInitType.IsNorm
@export_group("斜面(屋顶)相关")
## 斜面移动的检测层面的组件(受击框,检测组件或非检测组件下的检测框)
@export var node2d_detect_in_slope:Array[Node2D]
#endregion

#endregion
func _ready() -> void:
	## 出战角色领一个实体 id（展示 / 花园态不领：它们不参与联机，不消耗编号）
	if entity_id == 0 and character_init_type == E_CharacterInitType.IsNorm:
		entity_id = take_next_entity_id()
	## 与初始化类型**无关**的角色初始化写在 character_ready() 里，由本处统一调用（硬约束 1-3）
	character_ready()
	match character_init_type:
		E_CharacterInitType.IsNorm:
			ready_norm()
		E_CharacterInitType.IsShow:
			ready_show()
		E_CharacterInitType.IsGarden:
			ready_garden()


#region 网络实体 id
## 领下一个实体 id（自增）
static func take_next_entity_id() -> int:
	var new_id := _next_entity_id
	_next_entity_id += 1
	return new_id


## 重置分配器（新的一局 / 新的一次回放开始时调，让两端从同一个编号开始）
static func reset_entity_id_allocator(start_id: int = 1) -> void:
	_next_entity_id = start_id


## 指定实体 id：客户端收到主机的创建消息后、入树之前调用（`_ready()` 会跳过自动分配）
func assign_entity_id(new_id: int) -> void:
	entity_id = new_id


## 是否已分配到实体 id
func has_entity_id() -> bool:
	return entity_id != 0
#endregion


## **角色的初始化入口之一**：与 `character_init_type` 无关的那部分初始化
##
## 子类的初始化分两种，按「要不要区分出战 / 展示 / 花园」选一个写：
##   · 不区分 → 重写本方法（三条分支都会跑到）
##   · 要区分 → 重写 `ready_norm()` / `ready_show()` / `ready_garden()`
## **都不要重写 `_ready()`**（硬约束 1-3）：生命周期分派在基类这里，
## 子类一重写就有可能漏掉 `super()`，整条「按 init_type 分发」的链路悄悄失效，
## 症状是「这个植物既不攻击也不产阳光」，但没有任何报错。
func character_ready() -> void:
	pass

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	## 角色根改变方向（修改为同样的值,方向不变）
	for node2d:Node2D in node_no_change_direction:
		signal_direction_x_root_update.connect(func(dir_x:int): node2d.scale.x = abs(node2d.scale.x) * sign(dir_x))

	## 角色body改变方向（修改为同样的值,保持和body方向一致）
	for node2d:Node2D in node_follow_body_direction:
		signal_direction_x_body_update.connect(func(dir_x:int): node2d.scale.x = abs(node2d.scale.x) * sign(dir_x))

	## 速度修改信号连接动画速度
	signal_update_speed.connect(anim_component.owner_update_speed)

	## 血量组件发射死亡信号
	hp_component.signal_hp_component_death.connect(character_death)

	## 被魅惑
	signal_character_be_hypno.connect(body.owner_be_hypno)

## 初始化正常出战角色
func ready_norm():
	ready_norm_signal_connect()
	is_show = false
	is_idle = false
	## 我是僵尸模式，随机速度变量为1
	if is_zombie_mode:
		random_speed_range = Vector2(1,1)
	## 舞王重写该方法，要在帧末尾调用，不然会保存
	call_deferred("init_random_speed")

## 初始化展示角色
func ready_show():
	is_show = true
	is_idle = true
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
	## 禁用生产阳光组件
	var create_sun_component: CreateSunComponent = get_node_or_null("CreateSunComponent")
	if is_instance_valid(create_sun_component):
		create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
	## 禁用攻击组件
	var attack_component: AttackComponentBase = get_node_or_null("AttackComponent")
	if is_instance_valid(attack_component):
		attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)


## 初始化花园角色
func ready_garden():
	is_show = true
	is_idle = true
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)

## 随机初始化角色速度
func init_random_speed():
	## 初始化角色速度
	update_speed_factor(randf_range(random_speed_range.x, random_speed_range.y), E_Influence_Speed_Factor.InitRandomSpeed)

## 修改速度，发射信号
func update_speed_factor(value: float, influent_speed_factor:E_Influence_Speed_Factor) -> void:
	influence_speed_factors[influent_speed_factor] = value
	signal_update_speed.emit(GlobalUtils.get_dic_product(influence_speed_factors))

#region 死亡、受击相关
## 亡语
func death_language():
	pass

## 角色死亡,子类继承重写
func character_death():
	is_death = true
	signal_character_death.emit()
	#call_deferred("emit_signal", "signal_character_death")
	if is_can_death_language:
		death_language()

## 【伤害系统】**统一的伤害入口**：本角色要对谁造成伤害，一律走这里。
##
## 为什么不再是各语义入口自己调 `hp_component.hp_loss()`：
## 那条路会绕过 `DamageSystem` 的修饰器链与伤害事件 —— 将来加护盾、反伤、联机对齐
## 都要**每一处**补一遍，漏一处就是一个静默的"这个技能打人没伤害"。
## 语义入口（`be_attacked_bullet` / `be_zombie_eat` / `be_bomb` …）现在只负责
## **组装 DamageInfo**，真正的派发只有这一个函数。
##
## [param info] 伤害描述（见 `DamageInfo`，`target` 一般是别人，`attacker` 是自己）
## [return] 结算结果（见 `DamageResult`）
func apply_damage(info: DamageInfo) -> DamageResult:
	return DamageSystem.apply(info)


## 【伤害系统】**② 受击方加工包**：系统应用之前，给目标一次**改写这个包**的机会。
##
## 这是「特殊效果」的落点。包里系统**不认**的那些效果（`ConstDamage.EFFECT_CALTROP` 一类）
## 是一张发起方写给受击方的便条，**只有受击方看得懂**，由它在这里翻译成具体后果：
##
## [codeblock]
## ## 洗冰车：地刺扎我 = 秒杀（原版行为）
## func process_damage(info: DamageInfo) -> bool:
##     if info.has_effect(ConstDamage.EFFECT_CALTROP):
##         info.is_instant_kill = true                  ## 秒杀：直接清空，不看伤害值
##     return true
##
## ## 巨人：地刺扎我 = 无视
## func process_damage(info: DamageInfo) -> bool:
##     info.remove_effect(ConstDamage.EFFECT_CALTROP)
##     return true
##
## ## 免疫爆炸：整个包都不要
## func process_damage(info: DamageInfo) -> bool:
##     if info.cause == ConstDamage.E_DamageCause.Bomb:
##         return false
##     return true
## [/codeblock]
##
## 与 `DamageModifierComponent` 的分工：
##   · 本方法是**角色自己的规则**，写在角色脚本里，天然跟着角色走（K-01 的例外：
##     它改的是"这一次的包"而不是持有状态，且规则本身就属于这个角色）；
##   · 修饰器组件是**可插拔的通用规则**，谁挂谁生效，不用改角色脚本。
## 两者都在 ② 阶段跑，本方法先跑，修饰器后跑。
##
## 三条纪律：
##   · **不要在这里触发新的伤害**（嵌套 `apply()`）。要加伤害就改 `info.amount`，让系统去施加；
##   · **不要在这里改 `hp_component`** —— 那是 ③ 系统应用阶段的事，这里只改包；
##   · 重写时**应该** `return super(info)`，除非你要显式否决这次伤害。
##
## [param info] 效果包，**可以直接改它的 `effects` / `amount` / `mode`**
## [return] true = 继续结算；false = 取消整个包（一滴血都不掉、控制也不上）
func process_damage(_info: DamageInfo) -> bool:
	return true


## 【伤害系统】**管线末端**：由 `DamageSystem` 在 ② 加工完之后调用，把伤害交给血量组件结算。
##
## 子类一般**不需要**重写：结算规则在血量组件里（`HpComponent` / `HpComponentZombie`）。
## 只有当"这个角色挨打时还要额外做点什么"才重写，且**必须** `return super(info)`。
## [param info] 本次伤害（`amount` 已过加工阶段，`final_amount` 已回填）
## [return] 结算后的本体血量
func take_damage(info: DamageInfo) -> int:
	return hp_component.hp_loss(info)


## 被攻击至死亡(大保龄球)
##
## 走秒杀（`is_instant_kill`）而不是"打一个等于总血量的伤害"：后者仍要过一遍防具的
## 吸收规则，碰上减伤 / 固定吸收的防具就打不死；秒杀是"必死"，与防具表怎么配无关。
## 伤害值留着只是让 `DamageResult` / 统计上的数字好看，真正致死靠的是那个字段。
func be_attack_to_death(trigger_be_attack_SFX:=true):
	var info := DamageInfo.create(self, hp_component.get_all_hp(),
		ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Bullet)
	info.is_instant_kill = true
	info.trigger_sfx = trigger_be_attack_SFX
	apply_damage(info)

## 死亡不消失(海草\被碾压)
func character_death_not_disappear():
	pass

## 死亡直接消失
func character_death_disappear():
	hp_component.hp_loss_to_death(false)
	queue_free()

## 被子弹攻击
## 语义入口：只组装 DamageInfo，派发交给 `apply_damage()`
##
## [param source_node] 伤害载体（那一发子弹）。可选，但**建议传**：
## 有了它，"哪一发打的"才能进 `DamageInfo`，将来做反伤 / 命中统计 / 联机对账才有依据。
## [param attacker_node] 发起者（射手）。可选：子弹一般不记录射手，留空即可。
func be_attacked_bullet(attack_value:int, bullet_mode:ConstDamage.E_DamageMode=ConstDamage.E_DamageMode.Norm, is_drop:bool=true, trigger_be_attack_SFX:=true, source_node:Node=null, attacker_node:Node=null) -> DamageResult:
	var info := DamageInfo.create(self, attack_value, bullet_mode, ConstDamage.E_DamageCause.Bullet)
	info.is_drop_on_death = is_drop
	info.trigger_sfx = trigger_be_attack_SFX
	info.source = source_node
	info.attacker = attacker_node
	var result := apply_damage(info)
	be_hit_light()
	return result


## 受击发光一次：被打中时 body 闪一下白光（纯表现，不参与任何结算）。
##
## 单独开一个方法是为了让**不走 `be_attacked_bullet()` 的发起方**（地刺自己写包那一条路）
## 也能复用这份表现，而不用去碰别人的 `body` 节点（K-03）。
func be_hit_light() -> void:
	body.body_light()

## 被锤子攻击(伤害值不生效)
func be_attacked_hammer(attack_value:int) -> bool:
	var info := DamageInfo.create(self, attack_value,
		ConstDamage.E_DamageMode.Hammer, ConstDamage.E_DamageCause.Hammer)
	apply_damage(info)
	body.body_light()
	return is_death


## 被僵尸啃食
## attack_value:伤害
## attack_zombie:攻击的僵尸
func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	var info := DamageInfo.create(self, attack_value,
		ConstDamage.E_DamageMode.Penetration, ConstDamage.E_DamageCause.Eat)
	## 啃食不吃受击音效（音效在攻击组件的 attack_once() 里播），但要记下是谁啃的
	info.trigger_sfx = false
	info.attacker = attack_zombie
	apply_damage(info)

## 被僵尸啃食一次发光
func be_zombie_eat_once(_attack_zombie:Zombie000Base):
	body.body_light()

## 被魅惑
func be_hypno():
	is_hypno = true
	signal_character_be_hypno.emit()
	## 广播给场上所有检测组件：敌我关系变了，下一帧重新判定目标
	## （魅惑不再切换受击层，光靠信号只有被魅惑者自己的组件会重判）
	EventBus.push_event(ConstEventName.CHARACTER_BE_HYPNO, [self])
	update_direction_x_root(-1)

	#hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Hypno)
	#hurt_box_component.enable_component(ComponentNormBase.E_IsEnableFactor.Hypno)

## 被压扁
## [character:Character000Base] 发动攻击的角色
func be_flattened_from_enemy(_character:Character000Base):
	be_flattened()

## 植物被压扁，无敌人(罐子压扁)
func be_flattened():
	body.be_flattened_body()
	## 角色死亡消失
	character_death_disappear()

#endregion


#region 隐形（隐形战争）
## 切换隐形渲染：true = 隐形，false = 现形
## 只对「本关设定为隐形」的角色生效，其它关卡调用直接返回，不会误改普通僵尸的颜色
func update_invisible_show(is_invisible_show: bool) -> void:
	if not is_invisible:
		return
	if is_invisible_show:
		shadow_alpha_before_invisible = shadow.modulate.a
	body.set_invisible(is_invisible_show)
	shadow.modulate.a = 0.0 if is_invisible_show else shadow_alpha_before_invisible
#endregion

#region 速度修改相关
## 【通用效果】被减速：伤害系统 `EFFECT_SLOW` 的落点（`DamageSystem._apply_effect_slow()` 调它）。
##
## 与 `be_ice_decelerate()` 的区别：那是**冰冻减速**（固定 0.5 系数 + 冰蓝色，带寒冰语义），
## 本方法是**通用减速**（系数由发起方给，不染色），给寒冰豌豆以外的减速来源用。
## 两者各用一个速度因子槽、各用一个计时器，互不覆盖。
## [param time] 持续秒数；已经在减速中时取「更长的那个」（与冰冻减速一致）
## [param factor] 速度系数（0.5 = 半速）
func be_slow(time:float, factor:float = 0.5):
	if is_death:
		return
	update_speed_factor(factor, E_Influence_Speed_Factor.Slow)
	if not is_instance_valid(all_timer[E_TimerType.Slow]):
		all_timer[E_TimerType.Slow] = GlobalUtils.create_new_timer_once(self, _on_slow_timer_timeout)
	if all_timer[E_TimerType.Slow].time_left < time:
		all_timer[E_TimerType.Slow].start(time)

## 通用减速计时器结束
func _on_slow_timer_timeout() -> void:
	update_speed_factor(1.0, E_Influence_Speed_Factor.Slow)

## 被冰冻减速
func be_ice_decelerate(time:float):
	update_speed_factor(0.5, E_Influence_Speed_Factor.IceDecelerateSpeed)
	body.set_other_color(BodyCharacter.E_ChangeColors.IceColor, Color(0.5, 1, 1))
	if not is_instance_valid(all_timer[E_TimerType.IceDecelerate]):
		all_timer[E_TimerType.IceDecelerate] = GlobalUtils.create_new_timer_once(self, _on_ice_decelerate_timer_timeout)
	if all_timer[E_TimerType.IceDecelerate].time_left < time:
		all_timer[E_TimerType.IceDecelerate].start(time)

## 冰冻减速计时器结束
func _on_ice_decelerate_timer_timeout() -> void:
	update_speed_factor(1.0, E_Influence_Speed_Factor.IceDecelerateSpeed)
	body.set_other_color(BodyCharacter.E_ChangeColors.IceColor, Color(1, 1, 1))

## 被冰冻控制：先结算本次伤害，冰冻只是附加在伤害上的控制效果（寒冰菇 = 伤害 + 冰冻）。[br]
## [param damage] 本次伤害，由发动方给出（寒冰菇炸弹组件的 `bomb_value`）；<=0 表示只冻不打。
func be_ice_freeze(time:float, new_time_ice_end_decelerate:float, damage:int = 20):
	if damage > 0:
		var info := DamageInfo.create(self, damage,
			ConstDamage.E_DamageMode.Real, ConstDamage.E_DamageCause.Freeze)
		info.trigger_sfx = false
		apply_damage(info)

	self.time_ice_end_decelerate = new_time_ice_end_decelerate
	update_speed_factor(0.0, E_Influence_Speed_Factor.IceFreezeSpeed)
	body.set_other_color(BodyCharacter.E_ChangeColors.IceColor, Color(0.5, 1, 1))
	## 隐形战争：被冰冻时现形（寒冰菇是玩家主动让僵尸现形的手段之一）
	update_invisible_show(false)
	if not is_instance_valid(all_timer[E_TimerType.IceFreeze]):
		all_timer[E_TimerType.IceFreeze] = GlobalUtils.create_new_timer_once(self, _on_ice_freeze_timer_timeout)

	if all_timer[E_TimerType.IceFreeze].time_left < time:
		all_timer[E_TimerType.IceFreeze].start(time)

	## 冰冻特效
	if is_instance_valid(ice_effect):
		ice_effect.queue_free()
	## 冰冻效果
	ice_effect = SceneRegistry.ICE_EFFECT.instantiate()
	add_child(ice_effect)
	# 冰块对齐影子：角色根节点未必是可见躯干的位置（僵王的部件整体偏在根节点右侧，
	# 直接用根节点会把冰块放到屏幕外）。
	if is_instance_valid(shadow):
		ice_effect.global_position = shadow.global_position
	ice_effect.start_ice_effect(time)

## 冰冻控制计时器结束
func _on_ice_freeze_timer_timeout() -> void:
	update_speed_factor(1.0, E_Influence_Speed_Factor.IceFreezeSpeed)
	## 隐形战争：解冻后立刻重新隐形（冰冻期间是玩家唯一能看清僵尸的窗口）
	## 还在黄油定身里就先不隐形——黄油同样会让僵尸现形，等黄油结束再隐形
	if not (is_instance_valid(all_timer[E_TimerType.Butter]) and all_timer[E_TimerType.Butter].time_left > 0):
		update_invisible_show(true)
	be_ice_decelerate(time_ice_end_decelerate)

## 取消冰冻减速(火焰豌豆\辣椒)
func cancel_ice():
	if is_instance_valid(all_timer[E_TimerType.IceFreeze]) and all_timer[E_TimerType.IceFreeze].time_left != 0:
		all_timer[E_TimerType.IceFreeze].stop()
		_on_ice_freeze_timer_timeout()
		if is_instance_valid(ice_effect):
			ice_effect.queue_free()
	if is_instance_valid(all_timer[E_TimerType.IceDecelerate]) and all_timer[E_TimerType.IceDecelerate].time_left != 0:
		all_timer[E_TimerType.IceDecelerate].stop()
		_on_ice_decelerate_timer_timeout()

#endregion


## 宿主所在的「同层容器」：水花、尸块、掉落物这类不属于本角色子树、
## 但必须站在同一层共享坐标系的节点挂到这里。
##
## 组件不要用 owner.get_parent() 去猜宿主的父节点 —— 那等于组件知道了宿主被挂在谁下面，
## 宿主一旦换容器（被临时挂到别的 Helper 节点下）就会挂错地方、坐标也全偏。
## 想要「宿主那一层」就问宿主，由宿主决定它自己属于哪一层（硬约束 1-2）。
func get_sibling_layer() -> Node:
	return get_parent()


## 主场景访问器：角色需要的主场景能力一律走这里，**不要**在实体里直接取 GameContext.curr_main_game（旧称 Global.main_game，已删除）。
##
## 为什么：直接取全局单例等于让角色（僵尸 / 植物 / 僵王）隐式依赖「当前一定有一局主游戏」，
## 而展示态（图鉴、卡片静态预览、花园）没有主场景，那些分支只能靠调用点散落的
## is_instance_valid() 各兜各的（历史上 seed_packet 就因此接过已释放实例）。
## 收进本方法之后：实体代码里不再出现全局单例名，将来主场景改成注入式上下文只改这一处。
## 「当前这一局」的真相源在 GameContext（见 global.gd 里那段「当前局上下文不在 Global 里」的说明）。
##
## 组件请用 ComponentNormBase 提供的同名访问器（它内部转问 owner，即本角色）。
func get_main_game() -> MainGameManager:
	return GameContext.curr_main_game


## **组件取「宿主身上某个节点」的统一入口**（替代在组件里拼 `$"../XXX"`）
##
## 为什么不让组件写相对路径：`../AnimationTree` 这类写法等于让组件同时假设了三件事 ——
## 「宿主是我的父节点」「目标节点在宿主的第几层」「它没有挪进 Body 之类的子容器」。
## 宿主结构一改（多包一层、某个孩子挪位置），组件会**静默取到 null** 而不报错，
## 症状是「这个角色不动了 / 不播动画了」，排查成本很高。
##
## 走本函数后，这些假设被收进「宿主」一个对象：组件只说「我要宿主身上的 X」，
## 由宿主回答自己的结构。将来宿主结构调整，组件侧一行都不用动。
##
## 用法（组件里的 @onready，写法与原来的 `$"../X"` 一一对应）：
##[codeblock]
##	@onready var animation_tree: AnimationTree = Character000Base.host_node_of(owner, ^"AnimationTree")
##[/codeblock]
##
## owner 为空时返回 null（运行时裸 new 出来、还没挂进宿主场景的节点会走这条分支），
## 调用方照旧判空即可 —— 与原来 `$"../X"` 在节点缺失时的行为一致。
static func host_node_of(character_owner: Node, host_path: NodePath) -> Node:
	var host := character_owner as Character000Base
	if host == null:
		return null
	return host.get_node_or_null(host_path)
