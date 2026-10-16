extends ComponentNormBase
class_name MagnetComponent

## 当前持有铁器容器
@export var curr_iron_container: Node2D
@onready var attack_cd_timer: Timer = $AttackCdTimer
@onready var area_2d: Area2D = $Area2D

## 攻击cd(笑话铁器时间)
@export var attack_cd:float = 30

## ★ 最多同时持有几件铁器（原版磁力菇 = 1：吸一件就进入消化 cd，消化完才能吸下一件）
##
## 改成 > 1 时：没吸满就可以继续吸，cd 到点**消化最老的一件**、剩下的接着排队消化。
## 默认 1 与改造前**逐帧等价**（吸一件 → cd → 消化 → 才能再吸）。
@export var max_iron: int = 1

## 当前持有铁器
var curr_iron : Node2D
## 当前持有的全部铁器（按吸进来的先后排队消化）
var curr_irons: Array[Node2D] = []
## 是否已攻击
var is_attack_cd:=false

## 开始攻击
signal signal_attack_start
## 攻击完毕(冷却完成)
signal signal_attack_cd_end

func component_ready() -> void:
	attack_cd_timer.wait_time = attack_cd

## 启用组件
func enable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)
	if is_enabling:
		for area in area_2d.get_overlapping_areas():
			_on_area_2d_area_entered(area)

## 磁力菇吸铁
func attack_once(iron_node:IronNode):
	SoundManager.play_character_SFX("magnetshroom")

	iron_node.preprocessing_be_magnet()

	## 创建一个新铁器，避免原始铁器动画控制
	var ori_iron_global_position = iron_node.global_position
	var new_iron_node = iron_node.duplicate()
	curr_iron_container.add_child(new_iron_node)
	new_iron_node.global_position = ori_iron_global_position

	new_iron_node.visible = true
	curr_iron = new_iron_node
	curr_irons.append(new_iron_node)
	## 已经在消化了就不用再起一次 cd 计时器（消化完一件会自己接着排下一件）
	if not is_attack_cd:
		is_attack_cd = true
		signal_attack_start.emit()
		attack_cd_timer.start()

## 消化掉一件铁器（cd 到点）；容器里还排着队就接着消化下一件
func _on_attack_cd_timer_timeout() -> void:
	if not curr_irons.is_empty():
		var iron: Node2D = curr_irons.pop_front()
		if is_instance_valid(iron):
			iron.queue_free()
	if curr_irons.is_empty():
		signal_attack_cd_end.emit()
		is_attack_cd = false
	else:
		attack_cd_timer.start()
	for area in area_2d.get_overlapping_areas():
		_on_area_2d_area_entered(area)

## 有僵尸进入到吸铁范围内
func _on_area_2d_area_entered(area: Area2D) -> void:
	## 禁用组件\已经吸满了（原版只吸 1 件：吸一件就满了，等价改造前的冷却锁）
	if not is_enabling or curr_irons.size() >= max_iron:
		return
	var area_owner = area.owner
	if area_owner is Zombie000Base:
		## 敌我不再由碰撞层区分：魅惑僵尸归属植物方，磁力菇不吸它的铁器（与原行为一致）
		if not BulletCampConfig.is_enemy(BulletCampConfig.get_owner_camp(owner), area_owner):
			return
		## 先找铁器**防具**（一层 ArmorComponent，见 ArmorComponent.iron_node）；
		## 一个僵尸可以戴多件铁器防具，这里吸最外面那件还没被吸走的
		var iron_armor: ArmorComponent = area_owner.get_magnet_armor()
		if iron_armor != null:
			var armor_iron_node := iron_armor.get_iron_node()
			armor_iron_node.is_be_magnet = true
			attack_once(armor_iron_node)
			area_owner.break_armor(iron_armor, false)
			return
		## 没有铁器防具时再看铁器道具（跳跳棒 / 小丑盒 / 矿工镐）
		if area_owner.iron_type == Zombie000Base.IronType.Null:
			return
		else:
			## 僵尸身上的铁器节点
			var iron_node:IronNode = area_owner.iron_node
			if iron_node.is_be_magnet:
				return
			else:
				iron_node.is_be_magnet = true
				attack_once(iron_node)
				## 僵尸调用被删除铁器函数
				area_owner.be_magnet_iron()

	elif area_owner is Ladder:
		## 梯子身上的铁器节点
		var iron_node:IronNode = area_owner.iron_node
		if iron_node.is_be_magnet:
			return
		else:
			iron_node.is_be_magnet = true
		attack_once(iron_node)
		area_owner.ladder_death()


## 角色速度修改
func owner_update_speed(speed_product:float):
	if not attack_cd_timer.is_stopped():
		if speed_product == 0:
			attack_cd_timer.paused = true
		else:
			attack_cd_timer.paused = false

			attack_cd_timer.start(attack_cd_timer.time_left / speed_product)
			## 必须放在 speed_product != 0 的分支里，否则 attack_cd / 0 会把 wait_time 写成 INF
			attack_cd_timer.wait_time = attack_cd / speed_product
