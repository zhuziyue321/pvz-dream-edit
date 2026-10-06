extends Bullet000NormBase
class_name Bullet000ParabolaBase

@onready var movement_component: BulletMovementParabola = $MovementComponent

## 抛物线(贝塞尔曲线)子弹需要根据敌人位置每帧更新(_ready之前,即init 赋值)
## 僵王是正式角色（ZB000Base 继承 Character000Base），与普通僵尸走同一个字段
var target_enemy: Character000Base
## 敌人位置(init赋值),若子弹创建时，敌人已经死亡，使用该位置作为终点位置
var target_enemy_glo_pos_init: Vector2
## 是否被弹开
var is_bounce:=false

#region 影子相关
## 当前场景是否有斜坡,有斜坡的场景每帧检测斜面位置
var is_have_slope:=false
## 影子全局位置y,
## 该值默认为当前行僵尸出现位置y
## 有斜面时更新该值,更新影子对应位置
var global_pos_y_shadow:float
#endregion

func _ready() -> void:
	super()

	## 子弹实例化后，目标未消失，初始化目标位置,否则使用 target_enemy_glo_pos_init
	if is_instance_valid(target_enemy) and is_instance_valid(target_enemy.hurt_box_component):
		movement_component.parabola_movement_ready(target_enemy.hurt_box_component.global_position)
	else:
		movement_component.parabola_movement_ready(target_enemy_glo_pos_init)

	## 是否有斜坡
	is_have_slope = is_instance_valid(Global.main_game.main_game_slope)
	global_pos_y_shadow = Global.main_game.get_row_base_global_y(lane)

	update_shadow_global_pos()


## 抛物线初始化子弹属性
## [Enemy: Character000Base]: 敌人
## [EnemyGloPos:Vector2]:敌人位置,发射单位赋值,若发射时敌人死亡,使用该位置
## 签名与基类保持一致（基类是无类型 Dictionary）：
## 写成类型化字典会让「用字面量构造参数」的调用方直接报参数类型错误，
## 而直线 / 追踪基类都不要求类型化，这里没必要更严格
func init_bullet(bullet_paras:Dictionary):
	super(bullet_paras)

	## 抛物线子弹初始化
	target_enemy = bullet_paras.get(E_InitParasAttr.Enemy, null)
	## 敌人当前帧的位置，这个必须要的， 如果敌人消失，无法确定其位置，使用该位置确定贝塞尔曲线
	## 用 get() 兜底：不传该键（例如手动构造参数）时直接用原点，不要下标越界
	target_enemy_glo_pos_init = bullet_paras.get(E_InitParasAttr.EnemyGloPos, Vector2.ZERO)


func _physics_process(delta: float) -> void:
	## 未被弹开 若敌人存在且敌人还未死亡,更新其位置
	if not is_bounce and is_instance_valid(target_enemy) and not target_enemy.is_death:
		movement_component.set_enemy_last_global_pos(target_enemy)

	## 移动子弹，若移动失败，说明到最终点，攻击null销毁子弹
	if not movement_component.physics_process_bullet_move(delta):
		## 没有被弹开，有攻击特效
		if not is_bounce:
			attack_once(null)
		else:
			queue_free()

	update_shadow_global_pos()

	## 移动超过最大距离后销毁，部分子弹有限制
	if global_position.distance_to(start_pos) > max_distance:
		queue_free()

## 攻击一次
func attack_once(enemy:Character000Base):
	## 攻击植物时,若周围有叶子保护伞
	if enemy is Plant000Base:
		var all_umbrella_surrounding:Array[Plant000Base] = enemy.plant_cell.get_plant_surrounding(CharacterRegistry.PlantType.P038UmbrellaLeaf)
		if not all_umbrella_surrounding.is_empty():
			for p:Plant038UmbrellaLeaf in all_umbrella_surrounding:
				p.activete_umbrella()
			be_umbrella_bounce()
			return
	super(enemy)


## 控制影子位置
func update_shadow_global_pos():
	if is_have_slope:
		update_global_pos_y_shadow_on_have_slope()

	bullet_shadow.global_position.y = global_pos_y_shadow

## 场景有斜坡时更新默认影子y值
func update_global_pos_y_shadow_on_have_slope():
	## 获取相对斜坡的位置
	var slope_y = Global.main_game.main_game_slope.get_all_slope_y(global_position.x)
	global_pos_y_shadow = Global.main_game.get_row_base_global_y(lane) + slope_y


## 抛物线子弹先对Norm进行攻击
func get_first_be_hit_plant_in_cell(plant:Plant000Base)->Plant000Base:
	## shell
	var norm_plant := plant.plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm)
	if is_instance_valid(norm_plant):
		return norm_plant
	var shell_plant := plant.plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Shell)
	if is_instance_valid(shell_plant):
		return shell_plant
	var down_plant := plant.plant_cell.get_plant(CharacterRegistry.PlacePlantInCell.Down)
	if is_instance_valid(down_plant):
		return down_plant
	Log.error("当前植物格子没有检测到可以攻击的植物")
	return null

## 被保护伞弹开,更新移动贝塞尔曲线
func be_umbrella_bounce():
	if not is_bounce:
		z_index = 4000
		is_bounce = true
		## 被弹开之后,删除子弹碰撞器
		area_2d_attack.queue_free()

		movement_component.reset_parabola_movement_be_umbrella_bounce()
