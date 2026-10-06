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
### TODO:子弹攻击伤害(为正数时可以给子弹赋值,默认为子弹攻击力)
#@export var attack_value_bullet:int = -1
@export var attack_cd:float = 1.5
## 攻击子弹类型
@export var attack_bullet_type:BulletRegistry.BulletType = BulletRegistry.BulletType.Bullet001Pea
## 子弹生产位置
@export var markers_2d_bullet: Array[Marker2D]
@export_group("发射子弹音效")
## 攻击音效名字（发射子弹）
@export var attack_sfx:StringName = &"Throw"

## 发射一次子弹信号
signal signal_shoot_bullet

## 主游戏场景子弹父节点
var bullets: Node2D
func _ready() -> void:
	super()
	bullet_attack_cd_timer.wait_time = attack_cd
	if is_instance_valid(Global.main_game):
		bullets = Global.main_game.bullets
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
	animation_tree.set(attack_para, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func set_cancel_attack():
	#animation_tree.set(attack_para, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	pass

## 发射子弹（动画调用）
func _shoot_bullet():
	signal_shoot_bullet.emit()
	for i in range(markers_2d_bullet.size()):
		var bullet:Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
		var bullet_paras = get_bullet_paras(markers_2d_bullet[i].global_position, detect_component.ray_area_direction[i])
		#Log.debug(bullet_paras)
		bullet.init_bullet(bullet_paras)
		bullets.add_child(bullet)
		play_throw_sfx()


## 子弹掩码来源：攻击组件自带掩码组件时用自身的（仙人掌），否则用检测组件的
func get_can_attack_status_component() -> CanAttackStatusComponent:
	if is_instance_valid(can_attack_status_component):
		return can_attack_status_component
	return detect_component.can_attack_status_component


func get_bullet_paras(marker_2d_bullet_glo_pos:Vector2, ray_direction:Vector2) -> Dictionary[Bullet000NormBase.E_InitParasAttr,Variant]:
	return {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane : is_lane,
		Bullet000NormBase.E_InitParasAttr.BulletLane : owner.lane,
		Bullet000NormBase.E_InitParasAttr.Position : bullets.to_local(marker_2d_bullet_glo_pos),
		Bullet000NormBase.E_InitParasAttr.Direction : ray_direction,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState : get_can_attack_status_component().can_attack_plant_status,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState : get_can_attack_status_component().can_attack_zombie_status,
		Bullet000NormBase.E_InitParasAttr.BulletCamp : get_bullet_camp(),
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
