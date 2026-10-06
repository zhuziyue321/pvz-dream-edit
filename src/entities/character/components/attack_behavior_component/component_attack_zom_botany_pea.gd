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

## 发射间隔（与玩家的豌豆射手一致）
@export var attack_cd: float = 1.5
## 发射的子弹类型
@export var attack_bullet_type: BulletRegistry.BulletType = BulletRegistry.BulletType.Bullet001Pea
## 子弹发射点（场景里存的是 NodePath，节点头必须写 node_paths=PackedStringArray("markers_2d_bullet")）
@export var markers_2d_bullet: Array[Marker2D]
@export_group("发射子弹音效")
## 发射音效
@export var attack_sfx: StringName = &"Throw"

## 子弹方向：僵尸朝房子走，豌豆朝左飞。
## 不能沿用 detect_component.ray_area_direction —— 那是按检测区 rotation 算的，
## 僵尸的啃咬检测区 rotation 是 0（等于朝右），拿来用豌豆会往僵尸身后飞
const C_BULLET_DIRECTION := Vector2.LEFT

@onready var bullet_attack_cd_timer: Timer = $BulletAttackCdTimer

## 主游戏场景的子弹父节点
var bullets: Node2D
## 头顶植物是否还在（打掉之后就不再发射）
var is_head_plant_alive := true


func _ready() -> void:
	super()
	bullet_attack_cd_timer.wait_time = attack_cd
	if is_instance_valid(Global.main_game):
		bullets = Global.main_game.bullets
	## owner 的 @onready（hp_component）在本组件之后才赋值（Godot 先跑子节点 _ready 再跑父节点），
	## 所以「头顶植物被打掉」的信号必须等 owner ready 完再连
	if owner.is_node_ready():
		_connect_head_plant_broken()
	else:
		owner.ready.connect(_connect_head_plant_broken)
	bullet_attack_cd_timer.start()


## 连「头顶植物被打掉」的信号（一类防具血量归零）
func _connect_head_plant_broken() -> void:
	var zombie := owner as Zombie000Base
	if zombie == null:
		return
	var hp_component := zombie.hp_component as HpComponent
	if not is_instance_valid(hp_component):
		Log.error("豌豆僵尸拿不到 HpComponent，头顶植物被打掉后不会停止发射")
		return
	if hp_component.signal_armor1_death.is_connected(_on_head_plant_broken):
		return
	hp_component.signal_armor1_death.connect(_on_head_plant_broken)


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
func _on_bullet_attack_cd_timer_timeout() -> void:
	if not is_enabling or not is_head_plant_alive:
		return
	_shoot_bullet()


## 发射一颗豌豆
func _shoot_bullet() -> void:
	if not is_instance_valid(bullets):
		return
	for marker in markers_2d_bullet:
		if not is_instance_valid(marker):
			continue
		var bullet: Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
		bullet.init_bullet(_get_bullet_paras(marker.global_position))
		bullets.add_child(bullet)
	_play_head_shoot_anim()
	SoundManager.play_character_SFX(attack_sfx)


## 子弹初始化参数：与 AttackComponentBulletBase.get_bullet_paras() 一致，
## 只有 Direction 固定朝左（见 C_BULLET_DIRECTION），投手那两个键直线子弹不读
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
	}


## 头顶植物的「发射」表现：向后一顿再弹回，代替没有的发射动画
func _play_head_shoot_anim() -> void:
	var plant_component := owner.get_node_or_null(^"ZombiePlantComponent") as ZombiePlantComponent
	if plant_component == null:
		return
	var head := plant_component.plant_head
	if not is_instance_valid(head):
		return
	var base_pos: Vector2 = head.position
	var tween := head.create_tween()
	tween.tween_property(head, "position", base_pos + Vector2(4, 0), 0.06)
	tween.tween_property(head, "position", base_pos, 0.1)
