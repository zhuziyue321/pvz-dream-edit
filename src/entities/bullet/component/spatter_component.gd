extends Node2D
class_name SpatterComponent
## 子弹溅射伤害组件

@onready var area_2d_spatter: Area2D = $Area2DSpatter

## 总溅射伤害
@export var sum_attack_value:int=40
## 溅射伤害范围
@export var range_attack_value:Vector2i=Vector2i(1, 13)
## 溅射到的上下行,默认为-1,无关行属性
@export var spatter_lane_up_down := -1
## 可以攻击的敌人状态掩码组件（未在场景中配置时按溅射组件默认值创建）
@onready var can_attack_status_component: CanAttackStatusComponent = get_node_or_null(^"CanAttackStatusComponent")

## 所属子弹的阵营（决定溅射框检测哪些受击层：植物方打僵尸，僵尸方打植物）
var bullet_camp:CharacterRegistry.CharacterType = CharacterRegistry.CharacterType.Plant

func _ready() -> void:
	_ensure_can_attack_status_component()
	_sync_owner_bullet_camp()


## 同步所属子弹的阵营
## 子弹的 init_bullet 在入树之前就跑完了（阵营信号早已发过），所以这里要主动读一次，
## 再连上信号以便后续阵营变化（目前只有初始化时会变，留信号是为了与子弹保持一致）
func _sync_owner_bullet_camp() -> void:
	if not (owner is Bullet000Base):
		return
	var bullet: Bullet000Base = owner
	if not bullet.signal_bullet_camp_changed.is_connected(_on_bullet_camp_changed):
		bullet.signal_bullet_camp_changed.connect(_on_bullet_camp_changed)
	_on_bullet_camp_changed(bullet.bullet_camp)


## 阵营变化：把阵营对应的碰撞层写进溅射框
func _on_bullet_camp_changed(camp:CharacterRegistry.CharacterType) -> void:
	bullet_camp = camp
	BulletCampConfig.apply_camp_collision(area_2d_spatter, camp)


## 确保存在可攻击状态掩码组件（未在场景中配置时按溅射组件默认掩码创建）
func _ensure_can_attack_status_component() -> void:
	if is_instance_valid(can_attack_status_component):
		return
	can_attack_status_component = CanAttackStatusComponent.new()
	can_attack_status_component.name = "CanAttackStatusComponent"
	can_attack_status_component.can_attack_plant_status = 9
	can_attack_status_component.can_attack_zombie_status = 1
	add_child(can_attack_status_component)


## 溅射伤害（对敌对阵营的所有目标，植物方溅射僵尸、僵尸方溅射植物）
func spatter_all_area_enemy(direct_hit_enemy:Character000Base, lane:int=-1):
	var areas = area_2d_spatter.get_overlapping_areas()
	var all_splatter_enemy:Array[Character000Base] = []
	## 僵王是正式角色（ZB000Base），与普通僵尸走同一条阵营 / 状态判定
	for area in areas:
		var enemy = area.owner
		## 直接命中的目标不再重复结算（它的伤害由子弹本体结算）
		if direct_hit_enemy == enemy:
			continue
		## 只溅射敌对阵营（同阵营由碰撞层先过滤，这里再判一次）
		if not BulletCampConfig.is_enemy(bullet_camp, enemy):
			continue
		## 如果不是可攻击状态敌人
		if not can_attack_status_component.can_attack(enemy):
			continue

		all_splatter_enemy.append(enemy)
	var target_count := all_splatter_enemy.size()
	if target_count == 0:
		return
	var damage_per_enemy: int = clampi(int(float(sum_attack_value) / target_count), range_attack_value.x, range_attack_value.y)
	for enemy:Character000Base in all_splatter_enemy:

		if spatter_lane_up_down==-1 or lane==-1 or (lane+spatter_lane_up_down>=enemy.lane and lane-spatter_lane_up_down <=enemy.lane):
			attack_enemy(enemy, damage_per_enemy)


## 溅射伤害（旧名，保留兼容）→ 统一走 spatter_all_area_enemy
func spatter_all_area_zombie(direct_hit_enemy:Character000Base, lane:int=-1):
	spatter_all_area_enemy(direct_hit_enemy, lane)


func attack_enemy(enemy:Character000Base, damage_per_enemy:int):
	enemy.be_attacked_bullet(damage_per_enemy,BulletRegistry.AttackMode.Penetration, true, false)
