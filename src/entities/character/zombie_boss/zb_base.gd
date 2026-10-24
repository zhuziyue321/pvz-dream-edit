## 僵王共用逻辑死亡、控制效果清理和奖杯请求；具体死亡动画由各自状态机负责。[br]
## 僵王是**正式僵尸**（继承 Zombie000Base），但刻意不走普通僵尸那套「移动 / 啃食 / 掉落 / 灰烬」：
## 相关组件在 [method ready_norm] 里永久禁用，行为全部由各自的状态机逐段编排。[br]
## [signal signal_status_update] 由父类提供（[member curr_be_attack_status] 的 setter 自动发出），
## 这里不再重复声明 —— 状态机切一次收击窗口就自然广播一次，检测组件订阅它重新索敌。
extends Zombie000Base
class_name ZB000Base

## 由死亡动画或直接消失接口请求奖励，是否允许生成由关卡管理器判断。
signal signal_trophy_requested(global_pos: Vector2)

## 僵王出场坐标固定，任何关卡、任何召唤方式（自动出场、卡牌召唤、读档恢复）都落在同一处，
## 关卡不再配置出生点；创建方传入的出生点一律被此常量覆盖。[br]
## -80 是 800x600 下的标定值：博士是从 1066x600 版本整体移植的，BodyCorrect=(100,0)、
## 部件局部 x 高达 900~1050，机身整体偏在根节点右侧约 733~1075px；
## 沿用 1066 时代的 1030 会让机身落在屏幕 x 1758~2093（视口只有 800）→ 完全看不见。
const FIXED_SPAWN_POSITION := Vector2(-80, 0)

## 请求奖杯时使用的世界位置标记；缺失时回退到角色根节点位置。
@onready var trophy_spawn_point: Marker2D = get_node_or_null("%TrophySpawnPoint") as Marker2D
## 是否已经启动死亡淡出，防止重复创建补间或重复安排释放。
var _is_fading := false


## 按关卡配置改写僵王的初始血量上限；必须在角色加入场景树之前调用。[br]
## 血量组件入树时才按新上限初始化当前血量，因此这里只改上限，不重复写当前血量。[br]
## 机甲破损阈值按「新上限 / 场景上限」同比例缩放，使各关的破损观感一致
## （场景阈值 20000 / 10000 对应默认 40000 血的 50% / 25%）。[br]
## [param hp] 正数初始血量；非正数、已入树、血量组件缺失或与场景上限相同时不修改任何配置。
func set_boss_hp(hp: int) -> void:
	if hp <= 0 or is_inside_tree():
		return
	var hp_comp: HpComponent = get_node_or_null("%HpComponent") as HpComponent
	if hp_comp == null or hp_comp.max_hp <= 0 or hp == hp_comp.max_hp:
		return
	# 缩放必须在改写上限之前计算；阈值本身按场景上限配置，末位 0 缩放后仍为 0。
	var ratio: float = float(hp) / float(hp_comp.max_hp)
	var stage_component: HpStageChangeComponent = get_node_or_null("%HpStageChangeComponent") as HpStageChangeComponent
	if stage_component != null:
		for index: int in stage_component.boundary_value_hp.size():
			stage_component.boundary_value_hp[index] = roundi(stage_component.boundary_value_hp[index] * ratio)
	hp_comp.max_hp = hp


## 切换低头受击窗口；由状态机的动画方法轨道（hurt_enable / hurt_disable）统一调用。[br]
## 这里同时驱动两套开关，两者必须一起移动，否则会出现「判定说能打但物理层进不来」：[br]
## - [member curr_be_attack_status]：走僵尸标准口径 —— 低头为 [code]IsNorm[/code]、
##   抬头为 [code]IsBossInvulnerable[/code]；它的 setter 会广播父类的
##   [signal signal_status_update]，[code]component_detect[/code] 订阅后重新索敌。
## - [member hurt_box_component].is_enabling：物理检测层的开关，沿用原有的 Character 因素。[br]
## 判定侧只看 [member curr_be_attack_status] 那一位（[code]CanAttackStatusComponent[/code]），
## 不受各植物「组合掩码」的影响。[br]
## [param enabled] true 表示低头期开始（可被攻击），false 表示抬头期（免疫）。
func set_hurt_window(enabled: bool) -> void:
	curr_be_attack_status = E_BeAttackStatusZombie.IsNorm if enabled else E_BeAttackStatusZombie.IsBossInvulnerable
	if not is_instance_valid(hurt_box_component):
		return
	if enabled:
		hurt_box_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)
	else:
		hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)


## 初始化正常出战僵王：先走父类僵尸那一套，再关掉不适用于僵王的普通行为链。[br]
## 父类会按地图坡度修正入场 y（[method move_y_zombie]），但那套修正面向「站在某一行草坪上」的
## 普通僵尸；僵王始终停在草坪外的 [constant FIXED_SPAWN_POSITION]，不该被坡面挪动位置。
## 这里量出父类实际加了多少并原样撤销（连同 [member node2d_detect_in_slope] 里的检测节点）。
func ready_norm() -> void:
	var y_before_ready := position.y
	super.ready_norm()
	# 撤销父类的入场坡面修正：move_y_zombie 会同步处理检测节点，反向调用即可复原。
	var slope_offset := position.y - y_before_ready
	if not is_zero_approx(slope_offset):
		move_y_zombie(-slope_offset)
	# 僵王不用普通僵尸的行为链：移动、啃食、掉落、灰烬、残血流失一律停用，
	# 行为交由状态机逐段编排。用 Default 因素表示「该角色不使用此组件」，
	# 避免与死亡 / 阶段等临时禁用因素冲突。
	# 其中 CriticalValueComponent 必须停：它默认会按 death_hp 自动持续掉血（原版"掉头后残血流逝"），
	# 而博士的破损只换贴图，留着会让它自己慢慢掉血。
	for disabled_component in [move_component, attack_component, drop_item_component, charred_component,
			critical_value_component]:
		if is_instance_valid(disabled_component):
			disabled_component.disable_component(ComponentNormBase.E_IsEnableFactor.Default)
	# 博士不显示自己的血条：僵王关的关卡进度条会切换成「僵王血量百分比」口径
	# （见 ZombossProgressProvider）。底座自带的 UI 是从普通僵尸继承来的，这里收起来。
	if is_instance_valid(hp_component):
		hp_component.visible = false
	# 出场时处于抬头状态（不可被攻击），低头由 hurt_enable 动画关键帧打开。
	set_hurt_window(false)


## 僵王免疫小推车 / 屋顶清洁车：车体从它脚下开过去不做任何结算。[br]
## 普通僵尸走 [code]ZombieMowerRunUtil[/code] 的碾压流程（扣血 + 倒地 + 删除），
## 僵王体型过大且始终站在草坪外的 [constant FIXED_SPAWN_POSITION]，
## 既不会被车体检测到，也不应被一次触发带走 —— 这里直接忽略（不做任何结算）。
func be_mowered_run(_lawn_mover: LawnMover) -> void:
	pass


## 只读检查普通伤害、冰冻和辣椒共用的受击资格，不扣血、不修改状态或发出信号。[br]
## 存活的正常出战实例仍在树中、未排队删除且受击组件有效并启用时返回 true，否则返回 false。[br]
## 保留拒绝条件的短路顺序，确认 [member hurt_box_component] 有效后才读取其启用状态。
func _can_receive_damage() -> bool:
	if is_death or character_init_type != E_CharacterInitType.IsNorm \
		or not is_inside_tree() or is_queued_for_deletion() \
		or not is_instance_valid(hurt_box_component) or not hurt_box_component.is_enabling:
		return false
	return true


## 所有普通与特殊植物伤害共用的最后检查，防止动画关键帧或旧碰撞结果绕过受击窗口。[br]
## [param damage] 本次伤害；[param bullet_mode] 伤害类型。[br]
## [param is_drop] 是否允许掉落表现；[param trigger_be_attack_SFX] 是否播放受击音效。
## 致死伤害仅通过血量组件启动僵王死亡状态机，不套用普通僵尸的直接删除逻辑。
func be_attacked_bullet(damage: int, bullet_mode: ConstDamage.E_DamageMode = ConstDamage.E_DamageMode.Norm, is_drop: bool = true, trigger_be_attack_SFX := true, source_node: Node = null, attacker_node: Node = null) -> DamageResult:
	## 受击窗口没开时整次伤害丢弃（含伤害事件），与"打到但被免疫"区分开：这里连管线都不进
	if not _can_receive_damage():
		return null
	return super.be_attacked_bullet(damage, bullet_mode, is_drop, trigger_be_attack_SFX, source_node, attacker_node)


## 先发出原有死亡信号供管理器扣数，再关闭受击；重复调用不重复触发亡语或计数。
func character_death() -> void:
	if is_death:
		return
	super.character_death()
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)
	prepare_death_animation()


## 正常出战实例扣尽生命并登记击杀，不等待死亡演出；已死亡实例不重复扣血或计数。[br]
## 释放前通过 [method request_trophy] 请求奖励，关卡仍检查胜利条件、全部僵王死亡及重复请求。
## 死亡演出中的实例也可调用此接口，立即请求结算并移除；已排队释放时不再处理。
func character_death_disappear() -> void:
	if is_queued_for_deletion():
		return
	if not is_death:
		hp_component.hp_loss_to_death(false)
	# 请求必须先于 queue_free，角色进入待删除状态后奖杯入口会拒绝请求。
	request_trophy()
	queue_free()


## 死亡演出只保留初始随机速度，解除停滞并停止旧计时器，防止结束回调覆盖演出速度。
## 可在 Dying 再调用一次，处理致死伤害调用返回后才生成的控制特效。
func prepare_death_animation() -> void:
	# 当前控制效果计时器；可能尚未创建，死亡清理时只停止有效实例。
	for timer: Timer in all_timer.values():
		if is_instance_valid(timer):
			timer.stop()
	if is_instance_valid(ice_effect):
		ice_effect.queue_free()
		ice_effect = null
	body.set_other_color(BodyCharacter.E_ChangeColors.IceColor, Color.WHITE)
	# 死亡演出保留的初始随机速度倍率；无配置时使用 1，非法值会回退为 1。
	var death_speed: float = influence_speed_factors.get(E_Influence_Speed_Factor.InitRandomSpeed, 1.0)
	# 编辑器误设零速度时仍允许死亡演出完成，不改全局时间倍率。
	if not is_finite(death_speed) or death_speed <= 0:
		death_speed = 1.0
	influence_speed_factors.clear()
	influence_speed_factors[E_Influence_Speed_Factor.InitRandomSpeed] = death_speed
	signal_update_speed.emit(death_speed)


## 死亡后延迟的随机初始化或控制效果不能重新改变死亡动画速度。
## [param value] 当前影响因素的新速度倍率；1 不改变速度，0 使动作停滞。
## [param factor] 本次更新的速度影响因素，用于覆盖该因素而保留其他倍率。
func update_speed_factor(value: float, factor: E_Influence_Speed_Factor) -> void:
	if not is_death:
		super.update_speed_factor(value, factor)


## 已死亡角色不再创建减速计时器或重新染上冰冻颜色。
## [param time] 本次冰冻减速持续时间，单位为秒。
func be_ice_decelerate(time: float) -> void:
	if not is_death:
		super.be_ice_decelerate(time)


## 仅在正常出战且受击窗口开启时接受冰冻；全场事件也不能绕过状态控制的受击开关。[br]
## 父类先结算伤害再附加冰冻效果；致死时在父类返回后补做清理，避免死后残留冰块。
## [param time] 本次完全冰冻持续时间，单位为秒。
## [param new_time_ice_end_decelerate] 冰冻解除后继续减速的时长，单位为秒。
## [param damage] 本次伤害（寒冰菇自己的角色攻击力 `attack_value`）；窗口没开时伤害与冰冻一起被挡掉。
func be_ice_freeze(time: float, new_time_ice_end_decelerate: float, damage: int = 0) -> void:
	if not _can_receive_damage():
		return
	super.be_ice_freeze(time, new_time_ice_end_decelerate, damage)
	if is_death:
		prepare_death_animation()


## 任意行的火爆辣椒均可命中；受击窗口在此检查，通过后先解除冰冻和减速，再扣血。[br]
## [param damage] 本次辣椒伤害；致死时由血量组件触发僵王死亡流程，不直接删除或播放普通僵尸灰烬。
func be_jalapeno(damage: int) -> void:
	if not _can_receive_damage():
		return
	# 先解除控制再结算伤害，避免解冻回调覆盖随后启动的死亡演出速度。
	cancel_ice()
	## 辣椒是「灼烧」语义：走伤害管线而不是直接调血量组件，
	## 这样修饰器与伤害统计对僵王同样生效（见 docs/参考存档/伤害系统.md）
	var info := DamageInfo.create(self, damage,
		ConstDamage.E_DamageMode.Penetration, ConstDamage.E_DamageCause.Burn)
	info.is_drop_on_death = false
	info.trigger_sfx = false
	apply_damage(info)


## 死亡动画和直接消失共用请求入口，不直接创建奖杯；存活、展示和正在卸载的角色不能请求奖励。
func request_trophy() -> void:
	if not is_death or character_init_type != E_CharacterInitType.IsNorm \
		or not is_inside_tree() or is_queued_for_deletion():
		return
	# 本次奖杯请求使用的全局坐标，优先取奖杯生成标记的位置。
	var spawn_position := trophy_spawn_point.global_position if is_instance_valid(trophy_spawn_point) else global_position
	signal_trophy_requested.emit(spawn_position)


## 正常死亡状态完成后沿用一秒淡出；直接消失使用 [method character_death_disappear]。
func _fade_and_remove() -> void:
	if _is_fading or not is_inside_tree() or is_queued_for_deletion():
		return
	_is_fading = true
	# 本次死亡淡出补间，在一秒内降低角色透明度，然后释放角色节点。
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)
