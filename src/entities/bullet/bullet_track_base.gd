extends Bullet000NormBase
class_name Bullet000TrackBase

@onready var movement_component: BulletMovementTrack = $MovementComponent

## 重新索敌的节流间隔（秒）
##
## 为什么需要：无目标时的索敌是 `get_all_enemy_can_be_attacked()`，**会对每个射线区
## 跑一遍 get_overlapping_areas() 的全量扫描**。追踪子弹（香蒲的刺）常在场且僵尸稀疏，
## 于是这份全量扫描就变成了每物理帧一次的空转。
## 而**有没有可打的敌人这件事，10 Hz 就已经足够跟得上**（僵尸不会在 16 ms 内凭空出现），
## 所以这里按时间节流：代价是最多延迟 RETARGET_INTERVAL 才锁定新目标，看不出来。
##
## 有目标时不累积计时（见 _physics_process），因此「目标刚死、要换下一个」是零延迟的。
const RETARGET_INTERVAL := 0.1

## 敌人
var target_enemy:Character000Base = null
## 全局检测组件
var detect_component_global:DetectComponent
## 距离下次允许全量索敌还剩多少秒
var _retarget_timer := 0.0

func _ready() -> void:
	super()
	if not is_instance_valid(target_enemy):
		target_enemy = detect_component_global.update_enemy_track_bullet(bullet_camp)

## 追踪子弹初始化子弹属性
## [Enemy: Character000Base]: 敌人
func init_bullet(bullet_paras:Dictionary[E_InitParasAttr,Variant]):
	super(bullet_paras)
	z_index = 4000
	detect_component_global = get_main_game().detect_component_global

	target_enemy = bullet_paras.get(E_InitParasAttr.Enemy, null)


func _physics_process(delta: float) -> void:
	## 如果敌人存在并且没有死亡
	if is_instance_valid(target_enemy) and not target_enemy.is_death:
		movement_component.reset_track_movement(true, false, target_enemy.hurt_box_component.global_position)
		## 计时器清零：目标死掉的下一帧立刻重新索敌，换目标不引入额外延迟
		_retarget_timer = 0.0
	## 无限穿透（max_attack_num == -1）时已经结算过的敌人
##
## 为什么需要：无限穿透的子弹不会被消耗，而追踪子弹会一直贴着目标飞，
## 一旦目标在受击盒边缘反复进出就会不停触发 area_entered，对同一个敌人连续造成伤害。
## 这里按「同一个敌人只结算一次」去重，语义上也正是「穿透」——穿过谁就打谁一次。
var _attacked_enemies_on_infinite: Array[Character000Base] = []

## 敌人不存在 全局寻找敌人
	else:
		## 全量索敌按时间节流（见 RETARGET_INTERVAL），没到点就沿用上一帧的结果
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			_retarget_timer = RETARGET_INTERVAL
			_acquire_target()
		## 这一帧仍然没有目标：保持无目标的移动参数
		if not is_instance_valid(target_enemy):
			movement_component.reset_track_movement(false)

	movement_component.physics_process_bullet_move(delta)

	## 移动超过最大距离后销毁，部分子弹有限制,大部分子弹超过默认2000后删除
	if global_position.distance_to(start_pos) > max_distance:
		queue_free()

## 重新索敌一次（**调用方负责节流**，见 RETARGET_INTERVAL）
##
## 顺序：先用全局检测组件缓存的敌人（它在自己的脏标记里维护，几乎免费），
## 缓存不可用时才走 update_enemy_track_bullet() 的全量扫描。
func _acquire_target() -> void:
	if is_instance_valid(detect_component_global.enemy_can_be_attacked) \
			and not detect_component_global.enemy_can_be_attacked.is_death:
		target_enemy = detect_component_global.enemy_can_be_attacked
	else:
		## 按子弹阵营索敌：植物方打僵尸，僵尸方（植物僵尸）打植物
		target_enemy = detect_component_global.update_enemy_track_bullet(bullet_camp)
	if not is_instance_valid(target_enemy):
		return
	movement_component.reset_track_movement(true, true, target_enemy.hurt_box_component.global_position)
	## 已在目标受击盒内时不会再次触发 area_entered（例如刚切换目标时子弹已在箱内），用重叠补判
	_try_attack_target_if_already_overlapping()


## 切换目标时，尝试攻击是否已经碰撞
func _try_attack_target_if_already_overlapping() -> void:
	if not is_instance_valid(target_enemy) or target_enemy.is_death:
		return
	## 无限穿透仍依赖多次 area_entered；若在此每帧补判会连续造成伤害
	## （同一敌人的重复结算由 _on_area_2d_attack_area_entered 里的去重挡住）
	if max_attack_num == -1:
		return
	if curr_attack_num >= max_attack_num:
		return
	for a: Area2D in area_2d_attack.get_overlapping_areas():
		if a.owner == target_enemy:
			attack_once(target_enemy)
			return


## 子弹与敌人碰撞
func _on_area_2d_attack_area_entered(area: Area2D) -> void:
	if area.owner != target_enemy:
		return
	## 有限穿透：还剩攻击次数就结算，次数用完后由 attack_once() 自行销毁
	if max_attack_num != -1:
		if curr_attack_num < max_attack_num:
			attack_once(target_enemy)
		return
	## 无限穿透：子弹不销毁，会一直贴着目标飞（可能反复进出受击框），
	## 因此按「同一个敌人只结算一次」去重，避免对同一目标连续造成伤害
	if _attacked_enemies_on_infinite.has(target_enemy):
		return
	_attacked_enemies_on_infinite.append(target_enemy)
	attack_once(target_enemy)
