extends AttackComponentZombieNorm
class_name AttackComponentZomBotanyPea
## 豌豆僵尸的攻击组件：普通僵尸的啃咬 + 头顶豌豆射手「持续」朝左发射豌豆
##
## 原版口径（PVZ Wiki《Peashooter Zombie》）：
##   「Stat-wise, it is identical to a normal Zombie, but additionally fires peas
##    constantly down its lane which damage plants」
##   「they fire the peas before they come on the screen」
## 也就是两件事，缺一个都不对：
##   1. 它**照常走、照常啃植物** —— 啃咬的开关仍然是 is_attack_res（走到植物跟前才停下啃）；
##   2. 豌豆是**恒定**发射的 —— 不要求检测区里有植物，进场（甚至还没进屏）就开始射。
##
## 为什么不用 component_attack_zom_botany.gd：
##   那个组件把发射挂在 is_attack_res 上，而 is_attack_res 一旦为真就会
##   `signal_change_is_attack(true)` → 移动组件的 IsAttack 因素置位 → 僵尸**停住**；
##   为了「够得着」又把啃咬检测区撑到 760 像素宽，于是僵尸在离植物老远的地方
##   定住播啃咬动画 —— 既不走也不啃，和原版完全是两种东西。
##
## 为什么继承 AttackComponentZombieNorm 而不是 AttackComponentBulletBase：
##   豌豆僵尸的本体就是普通僵尸（啃咬才是它的「攻击」，发射只是附加项）；
##   反过来继承发射组件的话，啃咬的持续掉血 / attack_once() / 攻击力因子要整段抄回来。
##   GDScript 没有多继承，这里只抄一份「发射一颗子弹」的最小实现。
##
## 冰冻 / 黄油不影响发射频率（wiki：被寒冰射手、冰瓜减速时它依旧按原频率开火），
## 所以不重写 owner_update_speed —— 它只改啃咬速度，发射计时器不受影响。
##
## 发射表现（2026-10-19）：头顶植物的头有 `Head_Attack` 动画时，计时器只负责**起播**，
## 豌豆由动画里「吐出」那一帧的方法轨回调本组件的 `_shoot_bullet()` 打出去（同玩家豌豆射手）；
## 静态头兜底时才退回「直接发射 + Tween 后坐」。

## 发射间隔（与玩家的豌豆射手一致）
@export var attack_cd: float = 1.5
## 发射的子弹类型
@export var attack_bullet_type: StringName = BulletIds.PEA
## 子弹发射点（场景里存的是 NodePath，节点头必须写 node_paths=PackedStringArray("markers_2d_bullet")）
@export var markers_2d_bullet: Array[Marker2D]
@export_group("发射子弹音效")
## 发射音效
@export var attack_sfx: StringName = &"Throw"

## 子弹方向：僵尸朝房子走，豌豆朝左飞。
## 不能沿用 detect_component.ray_area_direction —— 那是按检测区 rotation 算的，
## 僵尸的啃咬检测区 rotation 是 0（等于朝右），拿来用豌豆会往僵尸身后飞
const C_BULLET_DIRECTION := Vector2.LEFT
## 发射点不在本组件里算：原版口径的「头轨道 + 偏移」统一放在 `ZombiePlantComponent`
## （`get_head_shoot_global_position()`，偏量常量与原版出处也在那边），
## 机枪 / 寒冰僵尸和本组件共用同一份，避免两处各写一遍常量。

@onready var bullet_attack_cd_timer: Timer = $BulletAttackCdTimer

## 主游戏场景的子弹父节点
var bullets: Node2D
## 头顶植物是否还在（打掉之后就不再发射）
var is_head_plant_alive := true


func component_ready() -> void:
	super()
	bullet_attack_cd_timer.wait_time = attack_cd
	if is_instance_valid(get_main_game()):
		bullets = get_main_game().bullets
	## owner 的 @onready（hp_component）在本组件之后才赋值（Godot 先跑子节点 _ready 再跑父节点），
	## 所以「头顶植物被打掉」的信号必须等 owner ready 完再连
	if owner.is_node_ready():
		_connect_head_plant_broken()
	else:
		owner.ready.connect(_connect_head_plant_broken)
	bullet_attack_cd_timer.start()


## 连「头顶植物被打掉」的信号
## 头顶植物是挂在僵尸身上的 `ArmorComponentPlantHead`（一类防具），按类型取它
func _connect_head_plant_broken() -> void:
	var zombie := owner as Zombie000Base
	if zombie == null:
		return
	var head_armor := zombie.get_armor(ConstArmor.E_ArmorType.PlantHead)
	if head_armor == null:
		Log.error("豌豆僵尸缺少 PlantHead 防具组件，头顶植物被打掉后不会停止发射")
		return
	if head_armor.signal_armor_death.is_connected(_on_head_plant_broken):
		return
	head_armor.signal_armor_death.connect(_on_head_plant_broken)


## 头顶植物被打掉：僵尸变回普通僵尸，不再发射
func _on_head_plant_broken() -> void:
	is_head_plant_alive = false
	bullet_attack_cd_timer.stop()


func enable_component(is_enable_factor: E_IsEnableFactor) -> void:
	super(is_enable_factor)
	if is_enabling and is_head_plant_alive:
		bullet_attack_cd_timer.start()


func disable_component(is_enable_factor: E_IsEnableFactor) -> void:
	super(is_enable_factor)
	bullet_attack_cd_timer.stop()


## 发射间隔到点：不等检测区、不等啃咬，到点就射（原版「constantly」）
##
## 有动画头时**不在这里直接发**：先播 `Head_Attack`，真正的发射由动画里「吐出豌豆」那一帧的
## 方法轨回调 `_shoot_bullet()`（和玩家种下的豌豆射手同一条链路）。
## 没有动画头（静态贴图）时退回「直接发射 + Tween 后坐」。
func _on_bullet_attack_cd_timer_timeout() -> void:
	if not is_enabling or not is_head_plant_alive:
		return
	var plant_component := _get_plant_component()
	if plant_component != null and plant_component.play_head_attack_anim():
		return
	_shoot_bullet()
	_play_head_shoot_anim()


## 发射一颗豌豆
## ⚠️ 本方法**也会被头顶植物的攻击动画方法轨调用**（`Head_Attack` 的 `_shoot_bullet` 轨）
func _shoot_bullet() -> void:
	## 动画途中植物头被打掉 / 组件被禁用时，已经排好的方法轨还会回调到这里 —— 补一道闸
	if not is_enabling or not is_head_plant_alive:
		return
	if not is_instance_valid(bullets):
		return
	for marker in markers_2d_bullet:
		if not is_instance_valid(marker):
			continue
		var bullet: Bullet000Base = Global.bullet_registry.create_bullet(attack_bullet_type)
		## 闸门被占住时（联机客户端）造不出来：那一颗由主机随快照下发
		if bullet == null:
			return
		bullet.init_bullet(_get_bullet_paras(_get_shoot_global_position(marker)))
		bullets.add_child(bullet)
	SoundManager.play_character_SFX(attack_sfx)


## 发射点的世界坐标：转调头顶植物组件的原版公式（`ZombiePlantComponent.get_head_shoot_global_position`）
##
## 为什么不能直接用 `markers_2d_bullet` 里 Marker2D 的静态坐标：
##   原版每帧读 `anim_head1` 轨道的当前变换，豌豆始终贴着晃动中的头；
##   静态点写死之后，头在走路 / 啃咬时晃 ±10 像素，静态点还比头高 40 多像素 ——
##   表现就是「子弹从僵尸头顶上方飞出去」，与嘴对不上。
## 没有植物组件（错配到普通僵尸上）时退回 Marker2D 的静态坐标。
func _get_shoot_global_position(marker: Node2D) -> Vector2:
	var plant_component := _get_plant_component()
	if plant_component == null:
		return marker.global_position
	return plant_component.get_head_shoot_global_position(marker.global_position)


## 写进子弹的伤害值：宿主角色的 `attack_value` > 0 时覆盖子弹场景自身的值，否则 -1
##（沿用子弹自己的伤害）。与 `AttackComponentBulletBase.get_shoot_attack_value()` 同语义，
## 但本组件继承自啃咬组件、没有组件级 `attack_value_bullet`，只有角色这一级
func _get_shoot_attack_value() -> int:
	if owner_character != null and owner_character.attack_value > 0:
		return owner_character.attack_value
	return -1


## 子弹初始化参数：与 AttackComponentBulletBase.get_bullet_paras() 一致，
## 只有 Direction 固定朝左（见 C_BULLET_DIRECTION），投手那两个键直线子弹不读。
## AttackValue 同样走「宿主角色 attack_value > 子弹场景值」的优先
func _get_bullet_paras(marker_glo_pos: Vector2) -> Dictionary:
	var can_attack_status := detect_component.can_attack_status_component
	var zombie := owner as Zombie000Base
	return {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: detect_component.is_lane,
		Bullet000NormBase.E_InitParasAttr.BulletLane: (zombie.lane if zombie != null else -1),
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(marker_glo_pos),
		Bullet000NormBase.E_InitParasAttr.Direction: C_BULLET_DIRECTION,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState: can_attack_status.can_attack_plant_status,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState: can_attack_status.can_attack_zombie_status,
		Bullet000NormBase.E_InitParasAttr.BulletCamp: BulletCampConfig.get_owner_camp(owner),
		Bullet000NormBase.E_InitParasAttr.AttackValue: _get_shoot_attack_value(),
	}


## 头顶植物的「发射」表现（**只在静态头兜底时用**）：向后一顿再弹回
## 有动画头时由 `Head_Attack` 自己演，这里不叠 Tween，否则两套动作打架
func _play_head_shoot_anim() -> void:
	var plant_component := _get_plant_component()
	if plant_component == null:
		return
	var head := plant_component.plant_head
	if not is_instance_valid(head):
		return
	var base_pos: Vector2 = head.position
	var tween := head.create_tween()
	tween.tween_property(head, "position", base_pos + Vector2(4, 0), 0.06)
	tween.tween_property(head, "position", base_pos, 0.1)


## 取头顶植物组件（没有时返回 null，只是少了表现，不影响发射）
func _get_plant_component() -> ZombiePlantComponent:
	return owner.get_node_or_null(^"ZombiePlantComponent") as ZombiePlantComponent
