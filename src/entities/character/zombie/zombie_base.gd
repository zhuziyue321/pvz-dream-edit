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

## 是否免疫减速（寒冰豌豆 / 冰冻）。**哪件防具免疫由防具组件自己回答**
## （`ArmorComponent.is_immune_slow()`），这里只做转发，角色不存一份（K-01）
var is_slow_immune: bool:
	get:
		var zombie_hp := hp_component as HpComponentZombie
		return zombie_hp != null and zombie_hp.is_immune_slow()

## 是否免疫黄油定身（同上，由防具组件自己回答）
var is_butter_immune: bool:
	get:
		var zombie_hp := hp_component as HpComponentZombie
		return zombie_hp != null and zombie_hp.is_immune_butter()

#region 僵尸类基础属性
@export var zombie_type: StringName
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
##
## ⚠️ 原先的「一类 / 二类铁器**防具**」两个值已并入 `ArmorComponent`（防具自带 `iron_node`，
## 磁力菇走 `HpComponentZombie.get_magnet_armor()` 找它），这里只剩**不是防具**的铁器道具
## （跳跳棒 / 小丑盒 / 矿工镐）。`IronItem` 显式写成 3 是为了让存量 `.tscn` 里存的数字继续有效。
enum IronType{
	Null,		## 没有铁器
	IronItem = 3,	## 铁器道具（跳跳棒 / 小丑盒 / 矿工镐）
}

## 僵尸铁器类型
@export var iron_type:IronType = IronType.Null
## 僵尸铁器节点（铁器**道具**用；防具的铁器节点挂在 `ArmorComponent` 上）
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
	## 僵王抬头（受击窗口关闭）期间的免疫态：高于所有 @export_flags 已登记的组合位，
	## 任何不显式勾选它的攻击掩码都按位与之相交为 0，天然打不到。
	## 低头 / 抬头由 ZB000Base.set_hurt_window() 统一切换，详情见 docs/参考存档/特殊关卡.md
	IsBossInvulnerable = 64,
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
				self.curr_zombie_row_type = get_main_game().zombie_manager.all_zombie_rows[lane].zombie_row_type
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
	## （关卡之外创建的僵尸 —— 图鉴预览、探针 —— 没有主游戏，这里要挡一下）
	var main_game := get_main_game()
	if main_game != null and is_instance_valid(main_game.main_game_slope):
		## 获取对应位置的斜面y相对位置
		var slope_y_first = main_game.main_game_slope.get_all_slope_y(global_position.x)
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

	## 运行期热注册的僵尸在这一步把自己的防具挂上来（见 build_runtime_parts），
	## 挂完立刻走装备钩子，与场景里本来就带着防具的内置僵尸完全一致
	build_runtime_parts()
	## 防具存在时的特殊效果（浮空、免疫…）**由防具组件自己定义**，这里只负责在
	## 所有子节点都 ready 之后触发一次装备钩子（见 ArmorComponent.on_armor_equip）
	activate_armor_effects()

#region 运行期热注册（防具装配）
## 【热注册】装配钩子：本体已就位、组件都已就绪、防具的装备效果还没触发时调用一次。
## 运行期热注册的僵尸（见 `CharacterRegistry.register_runtime_zombie`）在**自己的脚本**里
## 重写它，用 `add_armor()` 想挂几层挂几层 —— 防具这条路由脚本自己说了算，
## 热注册的入口只认「本体 + 脚本」两样（防具的特殊效果照旧由防具组件自己定义）。
## 内置僵尸不用重写：它们的防具本来就写在 `.tscn` 里。
func build_runtime_parts() -> void:
	pass


## 【热注册】给本体挂一层防具，返回这一层（还要改更多字段就在返回值上接着改）
##
## ```gdscript
## ## 热注册僵尸脚本里
## func build_runtime_parts() -> void:
## 	super()
## 	add_armor(ConstArmor.E_ArmorType.Cone, 370)                ## 一类（头顶）
## 	add_armor(ConstArmor.E_ArmorType.ScreenDoor, 1100,
## 		ConstArmor.E_ArmorClass.Armor2)                        ## 二类（举在身前，先挨打）
## ```
##
## [param armor_type] 防具类型（只做标识与查找，见 `ConstArmor.E_ArmorType`）
## [param max_hp] 本层血量（0 = 这不是一件防具）
## [param armor_class] 防具类别，二类在外、先挨打
## [param armor_script] 防具脚本；留空用基类 `ArmorComponent`，
##                      要"防具存在 / 破损时的特殊效果"就传它的子类（如 `ArmorComponentBalloon`）
## [param absorb_priority] 同类防具之间的挨打顺序，数值越大越外层
## [return] 挂上去的那层防具；本体没有血量组件等异常情况下返回 null
func add_armor(
	armor_type: ConstArmor.E_ArmorType,
	max_hp: int,
	armor_class: ConstArmor.E_ArmorClass = ConstArmor.E_ArmorClass.Armor1,
	armor_script: Script = null,
	absorb_priority: int = 0
) -> ArmorComponent:
	var armor: ArmorComponent
	if armor_script == null:
		armor = ArmorComponent.new()
	else:
		armor = armor_script.new() as ArmorComponent
	if armor == null:
		Log.error("%s：add_armor 无法用脚本 %s 创建防具，已跳过这一层" % [name, armor_script])
		return null
	## 名字按"已有几层防具"编号，保证多层防具不会重名
	var armor_index := 0
	for child in get_children():
		if child is ArmorComponent:
			armor_index += 1
	armor.name = "ArmorComponentRuntime%d" % armor_index
	armor.armor_type = armor_type
	armor.armor_class = armor_class
	armor.absorb_priority = absorb_priority
	armor.max_hp = max_hp
	add_child(armor)
	## 防具表是血量组件在 `component_ready()` 里一次性收集的，而组件比宿主先 ready
	## —— 运行期才挂上来的这一层不在那张表里，挂完要让它重新收一遍
	var zombie_hp := hp_component as HpComponentZombie
	if zombie_hp != null:
		zombie_hp.collect_armors()
	return armor
#endregion

## 让每件还在的防具触发一次装备效果钩子
func activate_armor_effects():
	var zombie_hp := hp_component as HpComponentZombie
	if zombie_hp == null:
		return
	for armor in zombie_hp.get_all_armors():
		if armor.is_alive():
			armor.on_armor_equip()


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

	## 血量状态变化组件（只管本体；防具的破损外观由 `ArmorComponent` 自己管）
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)

	## 当前动画结束时，移动组件改变移动状态
	anim_component.signal_animation_finished.connect(move_component._on_animation_finished)

	## 被魅惑信号
	signal_character_be_hypno.connect(attack_component.owner_be_hypno)
	signal_character_be_hypno.connect(move_component._walking_start)

	## 游泳信号
	swim_box_component.signal_change_is_swimming.connect(change_is_swimming)

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
	## 展示态（图鉴 / 开局预览）也要装配：热注册的僵尸在图鉴里得戴着它的防具
	build_runtime_parts()
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)

## 改变攻击状态攻击
func change_is_attack(value:bool):
	is_attack = value

## 更新移动方向修正(斜面时使用)
func update_move_dir_y_correct(move_dir_y_correct_slope:Vector2):
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
	hp_component.hp_loss_to_death(false)

## 死亡直接消失
func character_death_disappear():
	is_death = true
	is_can_death_language = false
	hp_component.hp_loss_to_death(false)
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
	_apply_penetration_damage(attack_value, ConstDamage.E_DamageCause.Bomb, false)
	## 如果角色死亡
	if is_death:
		## 在在灰烬动画条件下
		## 注意 GDScript 里 not 的优先级低于 !=，原来的 not x != y 等价于 (x == y)，
		## 这里显式写成"既不在水里也不在地下才播灰烬"
		if is_cherry_bomb and not (is_swimming or curr_be_attack_status == E_BeAttackStatusZombie.IsDownGround):
			charred_component.play_charred_anim()
		queue_free()
		# L-14：必杀类伤害后恢复「可触发亡语」开关。用显式判断替代 set_deferred——
		# 原写法依赖"MessageQueue flush 早于删除队列"才不对已 queue_free 的对象写属性，属脆弱依赖。
		# 若本次已致死（is_death）僵尸将删除、无需恢复；否则恢复以便后续正常死亡触发亡语。
		if not is_death:
			is_can_death_language = true

## 被大嘴花吃
## [param attack_value] 本次伤害（吞噬传 0：秒杀不看伤害值）
## [param is_instant_kill] 是否秒杀（大嘴花吞下小体型僵尸：防具与本体一起清空，免疫仍可拦）
func be_chomper_eat(attack_value:int, is_instant_kill:bool = false):
	is_can_death_language = false
	_apply_penetration_damage(attack_value, ConstDamage.E_DamageCause.Eat, false, is_instant_kill)
	if is_death:
		queue_free()
	if not is_death:
		is_can_death_language = true

## 被钉耙击中
## 与 be_squash 的区别:钉耙是"把手翘起来砸一下",砸完僵尸走正常的死亡表现(掉头 + 倒下),
## 不像倭瓜那样直接 queue_free,所以这里不删节点,留给 hp_component 的死亡流程处理
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Garden_Rake) —— 原版 1800 伤害
func be_rake_attack(attack_value:int=ConstShop.RAKE_ATTACK_VALUE):
	is_can_death_language = false
	_apply_penetration_damage(attack_value, ConstDamage.E_DamageCause.Crush, false)
	if not is_death:
		is_can_death_language = true

## 被倭瓜压
## [param attack_value] 伤害值，由倭瓜给出（它自己的角色攻击力 `attack_value`）
func be_squash(attack_value:int):
	is_can_death_language = false
	_apply_penetration_damage(attack_value, ConstDamage.E_DamageCause.Crush, false)
	if is_death:
		queue_free()
	if not is_death:
		is_can_death_language = true

## 【伤害系统】穿透伤害的便捷入口：僵尸这边的"必杀类"伤害（爆炸 / 吞噬 / 碾压）都是同一套参数，
## 差别只在语义标记 `cause`，收成一个私有函数免得每个入口各抄一遍 DamageInfo 组装。
## [param attack_value] 伤害值
## [param cause] 伤害来源语义（见 `ConstDamage.E_DamageCause`）
## [param is_drop_on_death] 死亡时是否掉落
## [param is_instant_kill] 是否秒杀（不看伤害值，防具与本体一起清空）
func _apply_penetration_damage(attack_value:int, cause:ConstDamage.E_DamageCause, is_drop_on_death:bool, is_instant_kill:bool = false) -> DamageResult:
	var info := DamageInfo.create(self, attack_value, ConstDamage.E_DamageMode.Penetration, cause)
	info.is_drop_on_death = is_drop_on_death
	info.trigger_sfx = false
	info.is_instant_kill = is_instant_kill
	return apply_damage(info)

#endregion
## 铁器被吸走（磁力菇）
##
## 铁器**防具**走 `HpComponentZombie.get_magnet_armor()` → `break_armor()`，由磁力菇组件自己挑；
## 这里只处理不是防具的铁器道具（跳跳棒 / 小丑盒 / 矿工镐），具体表现由子类重写 `loss_iron_item()`。
func be_magnet_iron():
	if iron_type == IronType.IronItem:
		loss_iron_item()

## 打掉指定的一层防具（走伤害管线，破损信号 / 外观 / 掉落都会按正常流程触发）
##
## 磁力菇吸铁器、气球被门框挤破、梯子搭到植物上都是这一条路。
## [param armor] 要打掉的那一层（用 `get_armor()` 按类型取）
## [param is_drop_on_death] 死亡时是否掉落（磁力菇吸走铁器不掉落）
## [param is_drop_2] 掉落的额外条件（两个条件都满足才掉）
## [param is_trigger_sfx] 是否播受击音效（气球被挤破算"受击"，磁力菇吸走铁器不算）
func break_armor(armor:ArmorComponent, is_drop_on_death:bool = true,
		is_drop_2:bool = true, is_trigger_sfx:bool = false) -> void:
	var zombie_hp := hp_component as HpComponentZombie
	if zombie_hp == null:
		return
	zombie_hp.break_armor(armor, is_drop_on_death, is_drop_2, is_trigger_sfx)

## 按类型取本角色身上的一件防具（没有返回 null）
func get_armor(armor_type:ConstArmor.E_ArmorType) -> ArmorComponent:
	var zombie_hp := hp_component as HpComponentZombie
	if zombie_hp == null:
		return null
	return zombie_hp.get_armor_by_type(armor_type)

## 取一件还没被吸走的铁器防具（磁力菇用）；没有返回 null
func get_magnet_armor() -> ArmorComponent:
	var zombie_hp := hp_component as HpComponentZombie
	if zombie_hp == null:
		return null
	return zombie_hp.get_magnet_armor()

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


## 僵尸体型：吞噬类玩法（大嘴花）按它判定能吞到哪一档
enum E_BodySize {
	Small,	## 小体型：迷你规则的小僵尸（冒险 3-5 / 小游戏 10）与天生的小鬼僵尸
	Medium,	## 中体型：绝大多数僵尸
	Large,	## 大体型：巨人僵尸（吞不下）
}

## 当前体型。⚠️ 新增大体型 / 小体型僵尸改这一处，别在业务代码里再抄一份类型判断
func get_body_size() -> E_BodySize:
	if is_mini_zombie or zombie_type == ZombieIds.IMP:
		return E_BodySize.Small
	if zombie_type == ZombieIds.GARGANTUAR:
		return E_BodySize.Large
	return E_BodySize.Medium

## 是否小 / 中体型（大嘴花整只吞得下的范围）：只有大体型吞不下
func is_small_or_medium_body() -> bool:
	return get_body_size() != E_BodySize.Large

#endregion
