extends Node2D
class_name ZombiquariumPet
## 僵尸水族馆的「宠物」潜水僵尸
##
## 原版本关的僵尸不是敌人：它们在水缸里游、饿了要喂脑子、喂饱了定时产阳光，
## 饿了不吃就痛苦地死掉（见 ConstZombiquarium.PET_HUNGRY_TIME）。
##
## 角色本体复用潜水僵尸场景（Z012Snorkle），但按**展示态**初始化
## （Character000Base.E_CharacterInitType.IsShow）：受击框 / 攻击 / 移动 / 血量条全部不参与，
## 只借用它的动画资源（animation/character/zombie/zombie_snorkle/zombie_snorkle_aquarium_*），
## 位置与状态由本脚本自己管（水缸里没有行、没有格子，也用不上移动组件）。
##
## 组件只通过信号与宿主通信（硬约束 §1-2）：本脚本不读组件内部字段，只发信号给管理器。

## 动画名（见 zombie_snorkle.tscn 的 AnimationPlayer 动画库）
const ANIM_SWIM := &"Zombie_snorkle_aquarium_swim"
const ANIM_BITE := &"Zombie_snorkle_aquarium_bite"
const ANIM_DEATH := &"Zombie_snorkle_aquarium_death"

## 游动速度（像素/秒）：慢悠悠地漂才像在水里
const SWIM_SPEED := 34.0
## 看见脑子后追过去的速度倍率（饿了要赶紧吃到，比闲逛快）
const CHASE_SPEED_SCALE := 1.8
## 离脑子这么近就开吃（像素）
const EAT_DISTANCE := 26.0
## 咬一口的时长（秒），与 ANIM_BITE 的 length 一致
const EAT_TIME := 1.16667
## 死亡动画时长（秒），与 ANIM_DEATH 的 length 一致
const DEATH_TIME := 3.0
## 死亡动画播完后淡出的时长（秒）
const DEATH_FADE_TIME := 0.6
## 闲逛时换一个落脚点的间隔范围（秒）
const WANDER_CD_RANGE := Vector2(1.5, 3.5)
## 产阳光时僵尸身体发光的位置偏移（相对本节点，往上一点）
const SUN_OFFSET := Vector2(0, -34.0)
## 饿了时的身体颜色（原版「身体发绿黄色」）
const HUNGRY_COLOR := Color(0.62, 1.0, 0.42, 1.0)

## 宠物状态
enum E_PetState {
	Swim,	## 闲逛
	Chase,	## 追脑子
	Eat,	## 正在吃脑子
	Death,	## 已饿死，正在播死亡动画
}

## 僵尸死透了（死亡动画播完，管理器据此判负）
signal signal_pet_death(pet: ZombiquariumPet)
## 该产一颗阳光了（阳光由管理器统一生成，本脚本不碰阳光经济）
signal signal_produce_sun(pet: ZombiquariumPet, global_pos: Vector2)

## 宠物能游动的水域（相对水族馆节点的矩形）
var move_range := Rect2()
## 当前状态
var state: E_PetState = E_PetState.Swim
## 已经饿了多久（秒），吃到脑子就清零，到 PET_HUNGRY_TIME 就饿死
var hunger_time := 0.0

var _zombie: Zombie012Snorkle
var _anim_player: AnimationPlayer
var _target_brain: ZombiquariumBrain
var _wander_target := Vector2.ZERO
var _wander_time_left := 0.0
var _eat_time_left := 0.0
var _death_time_left := 0.0
var _sun_time_left := 0.0


#region 初始化
## 初始化宠物：造出展示态的潜水僵尸（必须在 add_child 到场景树之前调用）
func init_pet(curr_move_range: Rect2) -> void:
	move_range = curr_move_range
	_create_zombie()
	_reset_sun_timer(true)
	_pick_wander_target()


## 造一只展示态的潜水僵尸挂在本节点下
func _create_zombie() -> void:
	## 展示态：受击框 / 攻击 / 移动组件都不启用（见 character_base.ready_show / zombie_base.ready_show）
	_zombie = CharacterShowFactory.create_show_zombie(
		ConstZombiquarium.get_pet_zombie_type(), self) as Zombie012Snorkle
	if _zombie == null:
		return
	## 水里的僵尸没有影子
	_zombie.shadow.visible = false
	## 动画树在展示态会一直播 idle，交给动画播放器直接播水族馆那三条动画
	_zombie.anim_component.stop_anim()
	_anim_player = _zombie.get_node("AnimationPlayer")
	_play_anim(ANIM_SWIM)
#endregion


#region 每帧
func _process(delta: float) -> void:
	if _zombie == null:
		return
	match state:
		E_PetState.Swim:
			_update_hunger(delta)
			_update_sun_timer(delta)
			_update_swim(delta)
		E_PetState.Chase:
			_update_hunger(delta)
			_update_sun_timer(delta)
			_update_chase(delta)
		E_PetState.Eat:
			_update_eat(delta)
		E_PetState.Death:
			_update_death(delta)


## 累计饥饿：到点就饿死（原版 20 秒没吃到脑子就 "痛苦地死去"）
func _update_hunger(delta: float) -> void:
	hunger_time += delta
	_refresh_hunger_tint()
	if hunger_time >= ConstZombiquarium.PET_HUNGRY_TIME:
		die()


## 饿了就把身体染成绿黄色报警（原版表现）
func _refresh_hunger_tint() -> void:
	if not is_instance_valid(_zombie):
		return
	var left_time: float = ConstZombiquarium.PET_HUNGRY_TIME - hunger_time
	if left_time <= ConstZombiquarium.PET_HUNGRY_WARN_TIME:
		_zombie.body.modulate = HUNGRY_COLOR
	else:
		_zombie.body.modulate = Color.WHITE


## 产阳光倒计时
func _update_sun_timer(delta: float) -> void:
	_sun_time_left -= delta
	if _sun_time_left > 0.0:
		return
	_reset_sun_timer(false)
	signal_produce_sun.emit(self, global_position + SUN_OFFSET)


## 重排下一次产阳光的时间
func _reset_sun_timer(is_first: bool) -> void:
	var interval: float = randf_range(
		ConstZombiquarium.PET_SUN_INTERVAL_RANGE.x,
		ConstZombiquarium.PET_SUN_INTERVAL_RANGE.y
	)
	if is_first:
		interval *= ConstZombiquarium.PET_SUN_FIRST_SCALE
	_sun_time_left = interval


## 没有脑子时在水里随便漂
func _update_swim(delta: float) -> void:
	_wander_time_left -= delta
	if _wander_time_left <= 0.0 or position.distance_to(_wander_target) < 8.0:
		_pick_wander_target()
	_move_toward(_wander_target, SWIM_SPEED, delta)


## 有脑子就游过去吃
func _update_chase(delta: float) -> void:
	if not is_instance_valid(_target_brain):
		state = E_PetState.Swim
		return
	_move_toward(_target_brain.position, SWIM_SPEED * CHASE_SPEED_SCALE, delta)
	if position.distance_to(_target_brain.position) <= EAT_DISTANCE:
		_start_eat()


func _update_eat(delta: float) -> void:
	_eat_time_left -= delta
	if _eat_time_left > 0.0:
		return
	## 吃完回到闲逛：饥饿清零、脑子由管理器回收
	_play_anim(ANIM_SWIM)
	state = E_PetState.Swim
	_pick_wander_target()


## 死亡动画播完 -> 淡出 -> 通知管理器
func _update_death(delta: float) -> void:
	_death_time_left -= delta
	if _death_time_left > 0.0:
		return
	if is_instance_valid(_zombie):
		var tween := create_tween()
		tween.tween_property(_zombie, "modulate:a", 0.0, DEATH_FADE_TIME)
		await tween.finished
	set_process(false)
	signal_pet_death.emit(self)
	queue_free()
#endregion


#region 行为接口（管理器调用）
## 指派一个脑子给本宠物（管理器每帧按最近的脑子指派，可能被多只宠物同时盯上，先到的先吃）
func set_target_brain(brain: ZombiquariumBrain) -> void:
	if state != E_PetState.Swim and state != E_PetState.Chase:
		return
	_target_brain = brain
	state = E_PetState.Chase


## 当前追的脑子没了（被别的僵尸吃掉 / 沉到缸底）
func clear_target_brain(brain: ZombiquariumBrain) -> void:
	if _target_brain != brain:
		return
	_target_brain = null
	if state == E_PetState.Chase:
		state = E_PetState.Swim
		_pick_wander_target()


## 当前在播的动画名（调试 / 探针用，用来确认水族馆那三条动画真的播上了）
func get_curr_anim_name() -> StringName:
	if not is_instance_valid(_anim_player):
		return &""
	return _anim_player.current_animation


## 当前正在吃的脑子（供管理器回收该脑子）
func get_eating_brain() -> ZombiquariumBrain:
	if state != E_PetState.Eat:
		return null
	return _target_brain


## 饿死：播死亡动画（不再产阳光、不再进食）
func die() -> void:
	if state == E_PetState.Death:
		return
	state = E_PetState.Death
	_target_brain = null
	_death_time_left = DEATH_TIME
	_play_anim(ANIM_DEATH)
	## 原版是本关专属的「僵尸溺死」音效（wiki: Zombaquarium die.ogg），仓库里没有这个素材，
	## 先用僵尸入水的水花音效顶上（音效缺素材不影响玩法）
	SoundManager.play_other_SFX("zombie_entering_water")
	Log.debug("僵尸水族馆：一只潜水僵尸饿死了")
#endregion


#region 内部
## 开吃：播咬的动画，饥饿清零
func _start_eat() -> void:
	state = E_PetState.Eat
	_eat_time_left = EAT_TIME
	hunger_time = 0.0
	_refresh_hunger_tint()
	_play_anim(ANIM_BITE)


## 朝目标点游过去，并按水平方向翻转身体（水族馆的僵尸面朝左，往右游就翻过来）
func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	var to_target := target - position
	if to_target.length() < 1.0:
		return
	var step := to_target.normalized() * speed * delta
	if step.length() > to_target.length():
		step = to_target
	position += step
	position = _clamp_in_range(position)
	_face_to(sign(step.x) if step.x != 0.0 else 0)


func _face_to(direction_x: int) -> void:
	if direction_x == 0 or not is_instance_valid(_zombie):
		return
	_zombie.update_direction_x_root(direction_x)


## 把点夹回水域内（留一点边距，免得僵尸半个身子贴着缸壁）
func _clamp_in_range(point: Vector2) -> Vector2:
	if move_range.size == Vector2.ZERO:
		return point
	return Vector2(
		clampf(point.x, move_range.position.x, move_range.end.x),
		clampf(point.y, move_range.position.y, move_range.end.y)
	)


## 在游动范围里随机挑一个落脚点
func _pick_wander_target() -> void:
	if move_range.size == Vector2.ZERO:
		return
	_wander_target = Vector2(
		randf_range(move_range.position.x, move_range.end.x),
		randf_range(move_range.position.y, move_range.end.y)
	)
	_wander_time_left = randf_range(WANDER_CD_RANGE.x, WANDER_CD_RANGE.y)


func _play_anim(anim_name: StringName) -> void:
	if not is_instance_valid(_anim_player) or not _anim_player.has_animation(anim_name):
		Log.error("僵尸水族馆：动画不存在 " + str(anim_name))
		return
	_anim_player.play(anim_name)
#endregion
