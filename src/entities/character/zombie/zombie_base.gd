extends Character000Base
class_name Zombie000Base


@onready var attack_component: AttackComponentBase = %AttackComponent
@onready var hp_stage_change_component: HpStageChangeComponent = %HpStageChangeComponent
@onready var charred_component: CharredComponent = %CharredComponent
@onready var move_component: MoveComponent = %MoveComponent
@onready var swim_box_component: SwimBoxComponent = %SwimBoxComponent
@onready var drop_item_component: DropItemComponent = %DropItemComponent
## 临界值组件（可选组件：只有挂载了的角色才有，删掉不影响角色运行）
@onready var critical_value_component: CriticalValueComponent = get_node_or_null(^"CriticalValueComponent")

## 本体血量是否低于临界值（由临界值组件拥有）
## 只读转发，角色里不再存一份，避免两边状态各自演化（K-01）
var is_below_critical_value: bool:
	get:
		return is_instance_valid(critical_value_component) and critical_value_component.is_below_critical()

#region 僵尸类基础属性
@export var zombie_type:CharacterRegistry.ZombieType
## 僵尸基础属性参数，_ready初始化
@export_group("僵尸基础属性")
## 是否忽略梯子,即可以攻击梯子下的植物
@export var is_ignore_ladder:=false
## 是否为小僵尸大麻烦的小僵尸(速度翻倍,大小,血量减半)
var is_mini_zombie:= false
## 是否为罐子创建的僵尸
var is_pot_zombie:=false
## 是否正在从地下出现
var is_body_up_from_ground := false
## 是否参与自然出怪的提前刷新判定；技能召唤与衍生僵尸为 false，子僵尸继承来源
var participates_natural_refresh: bool = true

@export_subgroup("僵尸铁器")
## 铁器种类
enum IronType{
	Null,		## 没有铁器
	IronArmor1,	## 一类铁器防具
	IronArmor2,	## 二类铁器防具
	IronItem,	## 铁器道具
}

## 僵尸铁器类型
@export var iron_type:IronType = IronType.Null
## 僵尸铁器节点
@export var iron_node:IronNode
@export_subgroup("僵尸初始化状态")
## 僵尸初始化状态（从1[is_norm] 开始，被攻击时是否能被攻击到的属性）
@export var init_be_attack_status :E_BeAttackStatusZombie = E_BeAttackStatusZombie.IsNorm
## 僵尸出生波次
var curr_wave:=-1
## 僵尸当前状态
var curr_be_attack_status:E_BeAttackStatusZombie=E_BeAttackStatusZombie.IsNorm:
	set(value):
		curr_be_attack_status = value
		signal_status_update.emit()

## 当前僵尸所在行，陆地、水池
var curr_zombie_row_type:CharacterRegistry.ZombieRowType=CharacterRegistry.ZombieRowType.Land
## 水路两栖僵尸当前行为水路时body变化
@export var body_change_on_pool:ResourceBodyChange

## 是否可以触发倭瓜位置判定，默认都为否，可以跳跃的僵尸跳跃组件跳跃后修改为否
@export var is_trigger_squash_pos_judge := false
## 是否可以高建国强行停止跳跃判定，默认都为否，可以跳跃的僵尸跳跃组件跳跃后修改为否
@export var is_trigger_tall_nut_stop_jump := false

## 状态更新信号
signal signal_status_update
## 行更新信号
## 发射不在本类里（啃大蒜换行由 ZombieGarlicLaneUtil.update_lane() 发），故屏蔽 UNUSED_SIGNAL
@warning_ignore("unused_signal")
signal signal_lane_update

## 僵尸掉血信号（只有僵尸使用）,参数为损失的血量值
signal signal_zombie_hp_loss(all_loss_hp:int, wave:int)

#endregion

#region 角色枚举
## 检测攻击时，根据状态判断是否可以攻击
enum E_BeAttackStatusZombie{
	IsNorm = 1,		## 正常
	IsJump = 2,		## 跳跃
	IsDownPool = 4,		## 水下
	IsSky = 8,			## 空中
	IsDownGround = 16,	## 地下
	IsJumpInPool = 32,	## 跳入泳池,该状态无法被高建国拦截
}

#endregion

#region 僵尸动画状态参数
@export_group("动画状态")
## 默认为移动状态,is_walk由多种状态控制
@export var is_walk := true
@export var is_attack := false:
	set(value):
		is_attack = value
		_judge_is_walk()
@export var is_swimming := false
##是否为珊瑚僵尸
var is_seaweed:=false
## 父类通用
#var is_death := false

## 被炸死
var is_bomb_death := false:
	set(value):
		is_bomb_death = value
		_judge_is_walk()

## is_walk由is_attack 和 is_bomb_death控制
func _judge_is_walk():
	is_walk = not is_attack and not is_bomb_death

#endregion

@export_group("入场音效")
@export var sfx_enter_name:StringName
## 入场音效
var sfx_enter:AudioStreamPlayer
var is_sfxing:=false
## 停止入场音效(死亡\失去小丑盒子)
func _stop_sfx_enter():
	if is_sfxing:
		sfx_enter.stop()

@export_group("其他")
@export_subgroup("黄油")
## 头的节点（黄油糊脸用，路径候选表在 ZombieButterUtil）
var head_node:Node2D
## 黄油节点,
var butter_splat:Node2D

## 僵尸初始化属性
enum E_ZInitAttr{
	CharacterInitType,	## 角色初始化类型（正常、展示）
	Lane,				## 僵尸行
	CurrZombieRowType,	## 僵尸所在行属性（水、陆地）
	CurrWave,			## 僵尸波次
	IsMiniZombie,		## 是否为小僵尸大麻烦的小僵尸
	IsPotZombie,		## 是否为罐子生成的僵尸，小丑瞬爆
	IsZombieMode,		## 是否为我是僵尸模式的僵尸，气球落地,撑杆食脑
	IsInvisible,		## 本体是否隐形（通用外观项：本体与影子透明，被冰冻 / 黄油时才现形）
	## 是否参与自然出怪提前刷新，子僵尸继承来源；默认 true 保留原有生成方式的行为
	ParticipatesNaturalRefresh,
}

## 修改初始化状态，在添加到场景树之前调用
func init_zombie(zombie_init_para:Dictionary):
	self.character_init_type = zombie_init_para.get(E_ZInitAttr.CharacterInitType, E_CharacterInitType.IsNorm)
	self.is_mini_zombie = zombie_init_para.get(E_ZInitAttr.IsMiniZombie, false)
	self.is_invisible = zombie_init_para.get(E_ZInitAttr.IsInvisible, false)
	self.participates_natural_refresh = zombie_init_para.get(E_ZInitAttr.ParticipatesNaturalRefresh, true)
	match self.character_init_type:
		E_CharacterInitType.IsNorm:
			self.is_pot_zombie = zombie_init_para.get(E_ZInitAttr.IsPotZombie, false)
			self.is_zombie_mode = zombie_init_para.get(E_ZInitAttr.IsZombieMode, false)
			self.lane = zombie_init_para.get(E_ZInitAttr.Lane, -1)
			## 负下标在 GDScript 里会静默取到最后一行，这里兜底成 0 并报错提示
			if self.lane < 0:
				Log.error("init_zombie 缺少 Lane 参数，行号已兜底为 0，请检查创建方")
				self.lane = 0
			if zombie_init_para.has(E_ZInitAttr.CurrZombieRowType):
				self.curr_zombie_row_type = zombie_init_para[E_ZInitAttr.CurrZombieRowType]
			else:
				self.curr_zombie_row_type = Global.main_game.zombie_manager.all_zombie_rows[lane].zombie_row_type
			self.curr_wave = zombie_init_para.get(E_ZInitAttr.CurrWave, -1)


## 初始化正常出战角色
func ready_norm():
	## 小僵尸大麻烦：先改速度和体型，再走基类初始化（随机速度要用改过的 random_speed_range）
	if is_mini_zombie:
		update_mini_zombie()
	super()
	## 本体隐形（预览 / 图鉴的展示僵尸走 ready_show，不受影响）
	if is_invisible:
		update_invisible_show(true)
	##INFO: 检测是否有头节点（黄油糊脸用）
	head_node = ZombieButterUtil.find_head_node(self)
	curr_be_attack_status = init_be_attack_status
	## 若生成位置在斜面中,生成时修正斜面位置
	if is_instance_valid(Global.main_game.main_game_slope):
		## 获取对应位置的斜面y相对位置
		var slope_y_first = Global.main_game.main_game_slope.get_all_slope_y(global_position.x)
		move_y_zombie(slope_y_first)
	## 僵尸普通攻击组件连接信号
	#if attack_component is AttackComponentZombieNorm:
		### 攻击组件是否攻击梯子下僵尸
		#attack_component.init_attack_component(is_ignore_ladder)
	## 攻击的检测组件更新是否可以攻击梯子下的植物，是否忽略梯子
	attack_component.detect_component.is_attack_ladder_plant = is_ignore_ladder
	## 两栖类僵尸在水路时变化
	if Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType) == CharacterRegistry.ZombieRowType.Both:
		if body_change_on_pool != null:
			zombie_row_type_both_body_update()


## 两栖类僵尸body变化
func zombie_row_type_both_body_update():
	## 水路时body变化
	if curr_zombie_row_type == CharacterRegistry.ZombieRowType.Pool:
		for sprite_path in body_change_on_pool.sprite_appear:
			var sprite = get_node(sprite_path)
			sprite.visible = true

		for sprite_path in body_change_on_pool.sprite_disappear:
			var sprite = get_node(sprite_path)
			sprite.visible = false
	else:

		for sprite_path in body_change_on_pool.sprite_appear:
			var sprite = get_node(sprite_path)
			sprite.visible = false

		for sprite_path in body_change_on_pool.sprite_disappear:
			var sprite = get_node(sprite_path)
			sprite.visible = true

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	## 入场音效相关
	if not sfx_enter_name.is_empty():
		## 入场音效
		sfx_enter = SoundManager.play_character_SFX(sfx_enter_name)
		## 同一帧多次播放同一音效时不播放新音效
		if sfx_enter:
			is_sfxing = true
			sfx_enter.finished.connect(func():is_sfxing = false)
			hp_component.signal_hp_component_death.connect(_stop_sfx_enter)

	hp_component.signal_zombie_hp_loss.connect(func(hp_loss:int): signal_zombie_hp_loss.emit(hp_loss, curr_wave))
	## 角色死亡时禁用攻击组件
	hp_component.signal_hp_component_death.connect(attack_component.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Death))
	## 角色死亡时禁用临界值组件（死亡后的持续掉血交给血量组件处理）
	if is_instance_valid(critical_value_component):
		hp_component.signal_hp_component_death.connect(critical_value_component.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Death))
		## 血量变化时同步临界值状态（保证"进入临界值"的事件先于死亡禁用发出）
		hp_component.signal_hp_loss.connect(critical_value_component.on_hp_loss)
	## 攻击组件
	attack_component.signal_change_is_attack.connect(move_component.update_move_factor.bind(move_component.E_MoveFactor.IsAttack))
	attack_component.signal_change_is_attack.connect(change_is_attack)

	## 死亡时取消黄油
	hp_component.signal_hp_component_death.connect(death_stop_butter)

	## 血量状态变化组件
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)
	## 防具血量状态变化组件
	hp_component.signal_hp_armor1_loss.connect(hp_stage_change_component.judge_body_change_armor.bind(true))
	hp_component.signal_hp_armor2_loss.connect(hp_stage_change_component.judge_body_change_armor.bind(false))

	## 当前动画结束时，移动组件改变移动状态
	anim_component.signal_animation_finished.connect(move_component._on_animation_finished)

	## 被魅惑信号
	signal_character_be_hypno.connect(attack_component.owner_be_hypno)
	signal_character_be_hypno.connect(move_component._walking_start)

	## 游泳信号
	swim_box_component.signal_change_is_swimming.connect(change_is_swimming)

	## 铁器防具
	match iron_type:
		IronType.IronArmor1:
			hp_component.signal_armor1_death.connect(func():iron_type=IronType.Null)
		IronType.IronArmor2:
			hp_component.signal_armor2_death.connect(func():iron_type=IronType.Null)

	## 掉落战利品
	hp_component.signal_hp_component_death.connect(drop_item_component.drop_coin)
	hp_component.signal_hp_component_death.connect(drop_item_component.drop_garden_plant)
	hp_component.signal_hp_component_death.connect(drop_item_component.drop_chocolate)

	## 移动僵尸本体y位置,修改对应检测层面节点位置
	move_component.signal_move_body_y.connect(move_y_zombie)

	## 对移动速度影响,只对速度移动模式生效
	signal_update_speed.connect(move_component.owner_update_speed)
	## 对攻击影响,
	signal_update_speed.connect(attack_component.owner_update_speed)

## 初始化展示角色
func ready_show():
	super()
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)

## 改变攻击状态攻击
func change_is_attack(value:bool):
	is_attack = value

## 更新移动方向修正(斜面时使用)
func update_move_dir_y_correct(move_dir_y_correct_slope:Vector2):
	#Log.debug(str("更新移动方向:") + str(move_dir))
	move_component.move_dir_y_correct_slope = move_dir_y_correct_slope


## 角色移动y值(本体移动,同时修改检测层面的节点)
func move_y_zombie(move_y:float):
	position.y += move_y
	for n in node2d_detect_in_slope:
		n.position.y -= move_y

## 改变游泳状态,切换动画时0.2秒过度时间停止移动
func change_is_swimming(value:bool):
	is_swimming = value
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsSwimingChange)
	await get_tree().create_timer(0.2).timeout
	move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsSwimingChange)
	shadow.visible = not value

#region 僵尸受伤、死亡、
## 角色死亡
func character_death():
	super()
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)
	swim_box_component._on_owner_is_death()
	#attack_component.queue_free()

## 僵尸死亡后逐渐透明，最后删除节点
func _fade_and_remove():
	var tween = create_tween()  # 自动创建并绑定Tween节点
	tween.tween_property(self, "modulate:a", 0.0, 1.0)  # 1秒内透明度降为0
	tween.tween_callback(queue_free)  # 动画完成后删除僵尸

## 死亡不消失(海草\TODO:小推车)
func character_death_not_disappear():
	hp_component.Hp_loss_death(false)

## 死亡直接消失
func character_death_disappear():
	is_death = true
	is_can_death_language = false
	hp_component.Hp_loss_death(false)
	queue_free()

## 被小推车碾压（表现编排见 ZombieMowerRunUtil）
func be_mowered_run(lawn_mover:LawnMover):
	ZombieMowerRunUtil.run(self, lawn_mover)

## 角色在泳池中死亡,泳池死亡动画调用
func in_water_death_start():
	var tween = create_tween()
	# 仅移动y轴，在1.5秒内下移200像素
	tween.tween_property(body, "position:y", body.position.y + 80, 2)
	#swim_box_component.in_water_death_start()

## 被水草缠住,
func be_grap_in_pool():
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)
	anim_component.stop_anim()
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsDeath)

## 被炸弹炸
## 灰烬动画从角色本体摘出来,本体节点free,灰烬动画播放玩后删除
## is_cherry_bomb:bool = false ：是否灰烬炸弹(非土豆雷)
func be_bomb(attack_value:int, is_cherry_bomb:bool = false):
	is_can_death_language = false
	hp_component.Hp_loss(attack_value,BulletRegistry.AttackMode.Penetration, false, false)
	## 如果角色死亡
	if is_death:
		## 在在灰烬动画条件下
		## 注意 GDScript 里 not 的优先级低于 !=，原来的 not x != y 等价于 (x == y)，
		## 这里显式写成"既不在水里也不在地下才播灰烬"
		if is_cherry_bomb and not (is_swimming or curr_be_attack_status == E_BeAttackStatusZombie.IsDownGround):
			charred_component.play_charred_anim()
		queue_free()
	#await get_tree().process_frame
	set_deferred("is_can_death_language", true)

## 被大嘴花吃
func be_chomper_eat(attack_value:int):
	is_can_death_language = false
	hp_component.Hp_loss(attack_value,BulletRegistry.AttackMode.Penetration, false, false)
	if is_death:
		queue_free()
	#await get_tree().process_frame
	set_deferred("is_can_death_language", true)

## 被钉耙击中
## 与 be_squash 的区别:钉耙是"把手翘起来砸一下",砸完僵尸走正常的死亡表现(掉头 + 倒下),
## 不像倭瓜那样直接 queue_free,所以这里不删节点,留给 hp_component 的死亡流程处理
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Garden_Rake) —— 原版 1800 伤害
func be_rake_attack(attack_value:int=ConstShop.RAKE_ATTACK_VALUE):
	is_can_death_language = false
	hp_component.Hp_loss(attack_value,BulletRegistry.AttackMode.Penetration, false, false)
	set_deferred("is_can_death_language", true)

## 被倭瓜压
func be_squash(attack_value:int=1800):
	is_can_death_language = false
	hp_component.Hp_loss(attack_value,BulletRegistry.AttackMode.Penetration, false, false)
	if is_death:
		queue_free()
	#await get_tree().process_frame
	set_deferred("is_can_death_language", true)

#endregion
## 铁器被吸走
## 非一类防具和非二类防具需重写该函数
func be_magnet_iron():
	match iron_type:
		IronType.IronArmor1:
			hp_component.Hp_loss(hp_component.curr_hp_armor1,BulletRegistry.AttackMode.Norm, false, false)
		IronType.IronArmor2:
			hp_component.Hp_loss(hp_component.curr_hp_armor2,BulletRegistry.AttackMode.Norm, false, false)
		IronType.IronItem:
			loss_iron_item()

## 失去铁器道具的影响,对应子类继承重写
func loss_iron_item():
	iron_node.visible = false
	iron_type = IronType.Null

## 被吹走,在空中的僵尸被三叶草吹时调用
func be_blow_away():
	pass


## 僵尸从墓碑出现
func zombie_up_from_tombstone(anim_multiply:float):
	update_speed_factor(0.0, Character000Base.E_Influence_Speed_Factor.HammerZombieSpeed)
	await zombie_up_from_ground(1/anim_multiply)
	## 从地下出来后恢复动画
	update_speed_factor(anim_multiply, Character000Base.E_Influence_Speed_Factor.HammerZombieSpeed)

## 从地下出来
func zombie_up_from_ground(up_time:float = 1.0):
	is_body_up_from_ground = true
	await body.zombie_body_up_from_ground(up_time)
	is_body_up_from_ground = false

## 跳跃被高坚果停止
func jump_be_stop(_plant:Plant000Base):
	pass


#region 黄油
## 黄油糊脸（贴脸 / 定身 / 到点恢复的实现见 ZombieButterUtil）
##[butter_time:float]:黄油糊脸时间
func be_butter(butter_time:float=4):
	ZombieButterUtil.be_butter(self, butter_time)

## 死亡时停止黄油
func death_stop_butter():
	ZombieButterUtil.stop_butter(self)
#endregion

#region 僵尸吃大蒜换行
## 啃到大蒜（换行流程见 ZombieGarlicLaneUtil）
func update_lane_on_eat_garlic():
	ZombieGarlicLaneUtil.on_eat_garlic(self)

## 换行
func update_lane():
	ZombieGarlicLaneUtil.update_lane(self)
#endregion


#region 梯子
## 梯子检测到僵尸时,僵尸爬过梯子
func start_climbing_ladder():
	move_component.start_ladder()

#endregion

#region 特殊场景状态
## 小僵尸大麻烦
func update_mini_zombie():
	random_speed_range *= 2
	## 舞王僵尸会改变符号,所有这么写
	scale = Vector2(
		0.5 * sign(scale.x),
		0.5 * sign(scale.y)
	)
	hp_component = hp_component as HpComponentZombie
	hp_component.update_mini_zombie_hp()
	hp_stage_change_component.update_mini_zombie_hp_stage_change()
	hurt_box_component.scale *= 2

#endregion
