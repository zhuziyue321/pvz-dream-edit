extends Node2D
## 跟随鼠标的真锤子（「锤子」模组：拿到手上时显示并跟鼠标，挥锤时播动画并圈出命中名单）
## 属于「锤子」模组：由 `HeadHammerMod` 运行时挂进 `CanvasLayerTemp`，本体场景里没有这个节点。
## 美术与挥锤动画复用迷你游戏锤子的资源（`src/items/mini_game/hammer.tscn` 同款贴图与动画），
## 但行为是本模组自己的：挥锤命中名单交给 `HandComponentHammerMod` 结算伤害。
##
## 命中判定与迷你游戏锤子同一套路：Area2D 监测僵尸受击框（layer 3 ZombieHurtBoxDetection，
## 与 `hammer.tscn` 同一个 mask），锤子每帧跟着鼠标走，挥锤那一刻 `get_overlapping_areas()`
## 的重叠数据就是新鲜的（安卓等触摸设备下可能滞后一两个物理帧，本项目目标平台是桌面，不做适配）。

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var area_2d: Area2D = $Area2D
@onready var pow_effect: Sprite2D = $Pow
## 命中范围：圆的半径由组件按设置在挥锤前改写（子资源随场景缓存，每挥都重设一次即可）
@onready var attack_shape: CircleShape2D = $Area2D/CollisionShape2D.shape as CircleShape2D

var is_using := false


func _process(_delta: float) -> void:
	if is_using:
		global_position = get_global_mouse_position()


## 拿在手上 / 从手上放下：只由 HandComponentHammerMod 调
func change_is_using(value: bool) -> void:
	is_using = value
	visible = value
	## monitoring 只在手持时开：不在手上时锤子停在卡槽位置，不该监测任何东西；
	## 碰撞开关要延到物理帧末，避免在物理回调里直接改
	area_2d.set_deferred("monitoring", value)
	if not value and animation_player.is_playing():
		animation_player.stop()


## 挥一锤：按传入半径调整命中范围，播挥锤动画，返回本锤命中的僵尸名单
## （去重 + 只留玩家方的敌人：魅惑僵尸是自己人，不挨锤）
func swing(attack_radius: float) -> Array[Zombie000Base]:
	if is_instance_valid(attack_shape):
		attack_shape.radius = maxf(attack_radius, 10.0)
	animation_player.stop()
	animation_player.play("Hammer_whack_zombie")
	SoundManager.play_other_SFX("swing")
	var zombies := _get_zombies_in_range()
	if not zombies.is_empty():
		SoundManager.play_other_SFX("bonk")
		_show_pow()
	return zombies


## 圈出本锤命中的僵尸：锤子身上的 Area2D 重叠到的区域，owner 是僵尸才算
func _get_zombies_in_range() -> Array[Zombie000Base]:
	var zombies: Array[Zombie000Base] = []
	for area in area_2d.get_overlapping_areas():
		## owner 不是僵尸的直接跳过（斜坡 / 道具 Area2D 也会重叠进来）
		var zombie := area.owner as Zombie000Base
		if zombie == null:
			continue
		## 一只僵尸可能带多个受击框，去重
		if zombies.has(zombie):
			continue
		## 只打玩家方的敌人（锤子是玩家的工具，按植物方算；魅惑僵尸是自己人）
		if not BulletCampConfig.is_enemy(CharacterRegistry.CharacterType.Plant, zombie):
			continue
		zombies.append(zombie)
	return zombies


## 挥中特效：Pow 星星在锤子落点炸一下（与迷你游戏锤子同款）
func _show_pow() -> void:
	var new_pow: Sprite2D = pow_effect.duplicate()
	new_pow.visible = true
	new_pow.global_position = global_position
	new_pow.z_as_relative = false
	new_pow.z_index = 951
	get_parent().add_child(new_pow)
	await get_tree().create_timer(0.5).timeout
	new_pow.queue_free()
