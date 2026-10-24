extends AttackComponentBase
## 发射子弹攻击行为基础组件
class_name AttackComponentBulletBase

@onready var animation_tree: AnimationTree = $"../AnimationTree"
## 冷却时间计时器
@onready var bullet_attack_cd_timer: Timer = $BulletAttackCdTimer

## 可攻击敌人状态掩码组件（仙人掌等会在自身挂载该组件动态修改子弹掩码）
@onready var can_attack_status_component: CanAttackStatusComponent = get_node_or_null(^"CanAttackStatusComponent")
## 是否使用行属性进行攻击判断
var is_lane:=true

## 攻击参数,动画攻击一次的参数
@export var attack_para:StringName= &"parameters/OneShot/request"
## 子弹伤害覆盖值：> 0 时用它给生成的子弹赋值，覆盖子弹场景自身的 attack_value；
## 默认 -1（不覆盖，用子弹自己的伤害）。用于「同一张攻击组件发射不同伤害的子弹」，
## 例如寒冰射手与豌豆射手共用攻击组件但伤害不同、或僵尸方子弹伤害由关卡倍率决定。
## 优先级：本字段 > 宿主角色的 `attack_value` > 子弹场景自己的 `attack_value`
## （见下面 `get_shoot_attack_value()`）
@export var attack_value_bullet:int = -1
@export var attack_cd:float = 1.5
## 一次攻击**连发几颗**（默认 1 = 一颗，原版植物的口径）
##
## ★ 连发能力放在基类：机枪射手（植物）与机枪僵尸（僵尸）都要用，
##   默认 1 时行为与改造前**完全一致**（一次攻击 = 一次 `_shoot_bullet_once()`）。
@export var burst_num: int = 1
## 连发的间隔（秒）
@export var burst_interval: float = 0.12
## 动画之外**再补发几颗**（默认 0 = 只发动画里那些）
##
## 为什么要有第二个连发数：原版机枪射手的「4 连发」是**写在动画里**的
## （`gatling_pea_shooting.tres` 有 4 个 `_shoot_bullet` 方法轨道），动画是原版资源不能改，
## 想让一次攻击打出比动画轨道更多的子弹（如 6 发），只能在动画那几次之外再补几颗。
## 默认 0 时本字段完全不参与，行为与改造前一致。
@export var burst_extra_num: int = 0
## 攻击子弹类型
@export var attack_bullet_type: StringName = BulletIds.PEA
## 子弹生产位置
@export var markers_2d_bullet: Array[Marker2D]
@export_group("发射子弹音效")
## 攻击音效名字（发射子弹）
@export var attack_sfx:StringName = &"Throw"

## 发射一次子弹信号
signal signal_shoot_bullet

## 主游戏场景子弹父节点
var bullets: Node2D
func component_ready() -> void:
	## 必须调 super：基类只分派一次 component_ready()（不会逐级级联），
	## 不调的话 AttackComponentBase 里的 detect_component_init() 不执行，
	## 攻击状态永远收不到「有敌人」，表现为植物/僵尸站着不攻击且无报错
	super()
	bullet_attack_cd_timer.wait_time = attack_cd
	if is_instance_valid(get_main_game()):
		bullets = get_main_game().bullets
	## 是否使用行属性进行攻击判断
	is_lane = detect_component.is_lane


## 角色速度修改
func owner_update_speed(speed_product:float):
	if speed_product == 0:
		## 冰冻停滞：暂停并保留剩余时间（原来只在计时器跑着时才暂停）
		bullet_attack_cd_timer.paused = true
		return
	bullet_attack_cd_timer.paused = false
	## 剩余时间按新倍率折算；计时器没跑（还没开始攻击）时不用管
	if not bullet_attack_cd_timer.is_stopped():
		bullet_attack_cd_timer.start(bullet_attack_cd_timer.time_left / speed_product)
	## wait_time 无条件更新：关卡倍率（speed_factor_plant）是在植物刚进场、
	## 还没开始攻击时下发的，原来只在「计时器跑着」时才改 wait_time，会把这次倍率漏掉
	bullet_attack_cd_timer.wait_time = attack_cd / speed_product

## 开始攻击
func attack_start():
	super()
	## 先随机等待一段时间调用一次攻击
	await get_tree().create_timer(randf_range(0, bullet_attack_cd_timer.wait_time/3)).timeout
	if is_attack_res:
		## 首次攻击还未使用计时器循环攻击
		if bullet_attack_cd_timer.is_stopped():
			_on_bullet_attack_cd_timer_timeout()
			bullet_attack_cd_timer.start()
	## 等待一段时间后可能为非攻击状态
	else:
		attack_end()

## 结束攻击
func attack_end():
	super()
	bullet_attack_cd_timer.stop()
	set_cancel_attack()


## 攻击间隔后触发执行攻击
func _on_bullet_attack_cd_timer_timeout() -> void:
	# 在这里调用实际攻击逻辑
	request_one_shot(attack_para)


## 请角色播一次"开火"动画（★ 统一入口）
##
## 本地驱动时就是 AnimationTree 的 OneShot 请求；客户端被包分发接管后，
## 动画由主机下发的快照决定，这里的请求会在组件里被忽略 —— 判定与表现从此只有一个入口。
func request_one_shot(param: StringName) -> void:
	var character := owner_character
	if character == null or not is_instance_valid(character.anim_component):
		return
	character.anim_component.request_one_shot(param)


## 撤掉正在播的开火动画（淡出）；用途见各子类的 `set_cancel_attack()`
func cancel_one_shot(param: StringName) -> void:
	var character := owner_character
	if character == null or not is_instance_valid(character.anim_component):
		return
	character.anim_component.cancel_one_shot(param)

func set_cancel_attack():
	#animation_tree.set(attack_para, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	pass

## 发射子弹（**动画事件**调用）
##
## 动画资源里不再点名本方法：方法轨调 `AnimComponent.on_anim_event("shoot")`，
## 由 `AttackComponentBase._on_anim_event()` 转调到这里（见该组件类注释）。
func _shoot_bullet():
	shoot_burst()


## 一次攻击的连发：连发几颗由 `burst_num` 决定（默认 1 = 只发一颗）
##
## ★ 抽成独立入口是因为「谁触发发射」有两条路：
##   · 植物 —— 攻击**动画**的 `on_anim_event("shoot")` 事件经
##     `AttackComponentBase._on_anim_event()` 转调到 `_shoot_bullet()`；
##   · 动画里没有轨道的组件（部分僵尸 / 特殊植物）走 `_on_bullet_attack_cd_timer_timeout()` 直接调本方法；
##   两条路都统一到本方法，连发只在这里循环一次，避免「连发里再套连发」。
func shoot_burst() -> void:
	for i in range(maxi(burst_num, 1)):
		if not is_instance_valid(self) or not is_attack_res:
			return
		_shoot_bullet_once()
		if i < burst_num - 1:
			await get_tree().create_timer(burst_interval).timeout


## 发射**一颗**（一次攻击里的单次发射）：所有发射位置各出一颗
func _shoot_bullet_once():
	signal_shoot_bullet.emit()
	for i in range(markers_2d_bullet.size()):
		var bullet:Bullet000Base = Global.bullet_registry.create_bullet(attack_bullet_type)
		## 闸门被占住时（联机客户端）造不出来：那一颗由主机随快照下发，本地不该再造一份
		if bullet == null:
			return
		var bullet_paras = get_bullet_paras(get_shoot_global_position(i), detect_component.ray_area_direction[i])
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		play_throw_sfx()


## 第 [param index] 个发射点的世界坐标：默认就是场景里 `markers_2d_bullet[index]` 的位置
##
## 抽成可覆写入口，是为了让「发射点不是静态点」的组件接管 —— 植物僵尸里的直线弹
## （机枪 / 寒冰）按原版实时取头顶植物头的轨道位置，见
## `AttackComponentZomBotany.get_shoot_global_position()`。
func get_shoot_global_position(index: int) -> Vector2:
	if index < 0 or index >= markers_2d_bullet.size():
		return global_position
	var marker: Marker2D = markers_2d_bullet[index]
	return marker.global_position if is_instance_valid(marker) else global_position


## 子弹掩码来源：攻击组件自带掩码组件时用自身的（仙人掌），否则用检测组件的
func get_can_attack_status_component() -> CanAttackStatusComponent:
	if is_instance_valid(can_attack_status_component):
		return can_attack_status_component
	return detect_component.can_attack_status_component


## 本次发射写进子弹的伤害值（`E_InitParasAttr.AttackValue` 的值），三级优先：
##   1. 攻击组件的 `attack_value_bullet` > 0 —— 组件级覆盖，最具体；
##   2. 宿主角色的 `attack_value` > 0 —— 角色自己的攻击力（植物 / 僵尸通用）；
##   3. 都不设 —— 返回 -1，子弹沿用自己场景里的 `attack_value`。
func get_shoot_attack_value() -> int:
	if attack_value_bullet > 0:
		return attack_value_bullet
	if owner_character != null and owner_character.attack_value > 0:
		return owner_character.attack_value
	return -1


func get_bullet_paras(marker_2d_bullet_glo_pos:Vector2, ray_direction:Vector2) -> Dictionary[Bullet000NormBase.E_InitParasAttr,Variant]:
	return {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane : is_lane,
		Bullet000NormBase.E_InitParasAttr.BulletLane : owner.lane,
		Bullet000NormBase.E_InitParasAttr.Position : bullets.to_local(marker_2d_bullet_glo_pos),
		Bullet000NormBase.E_InitParasAttr.Direction : ray_direction,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState : get_can_attack_status_component().can_attack_plant_status,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState : get_can_attack_status_component().can_attack_zombie_status,
		Bullet000NormBase.E_InitParasAttr.BulletCamp : get_bullet_camp(),
		Bullet000NormBase.E_InitParasAttr.AttackValue : get_shoot_attack_value(),
	}

## 发射方的阵营：僵尸持有本组件时（投石车僵尸、植物僵尸）子弹归僵尸方，打玩家的植物
## 这样同一份子弹场景（豌豆 / 卷心菜 / 西瓜 …）双方都能复用，不必复制一套僵尸版场景
func get_bullet_camp() -> CharacterRegistry.CharacterType:
	var camp := BulletCampConfig.get_owner_camp(owner)
	## owner 不是角色（编辑器预览、异常挂载）时按植物方处理，避免阵营为 Null 导致子弹打不到任何人
	if camp == CharacterRegistry.CharacterType.Null:
		return CharacterRegistry.CharacterType.Plant
	return camp


func play_throw_sfx():
	## 播放音效
	SoundManager.play_character_SFX(attack_sfx)
