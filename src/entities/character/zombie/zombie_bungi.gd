extends Zombie000Base
class_name Zombie021Bungi

## 成功偷取或确定放弃目标时只发出一次，不等待上升离场；死亡由角色死亡信号通知。
## 召唤方（如博士的蹦极技能）靠它判断本批是否结束，改名 / 删除必须同步改调用方。
signal signal_steal_finished()

## 偷盗的植物的容器节点
@onready var bungi_container: Node2D = $Body/BodyCorrect/BungiContainer

@onready var body_correct: Node2D = $Body/BodyCorrect
## 绳子节点修改父节点,起飞时使用不同的body
@onready var bungee_cords: Node2D = $Body/BodyCorrect/Zombie_bungi_body/BungeeCords
@onready var zombie_bungi_body_2: Sprite2D = $Body/BodyCorrect/Zombie_bungi_body2
## 靶子,偷盗植物时隐藏
@onready var bungee_target: Sprite2D = $BungeeTarget

@export_group("动画状态")
@export var is_drop_end := false
@export var is_grab := false
## 被保护伞摊开
@export var is_umbrella_raise := false
## 蹦极僵尸所在PlantCell
var plant_cell:PlantCell
## 本次偷取是否已经通知过召唤方；信号绝不重复发送。
var _steal_finished := false

@export_group("降落节奏")
## 进场后隔多久开始降落（普通蹦极是等靶子先落地，空投没有靶子，这段就是纯前摇）
@export var drop_start_delay := 2.0
## 降落本身要多久
@export var drop_duration := 2.0
## 落地后隔多久才伸手（普通蹦极是抓取，空投是释放）
@export var grab_start_delay := 2.0
## 降落终点比「本体落地」还要高多少：负值代表本体降到半空就停住
## （空投要用它把绳子末端抬到正好落在地面，怀里僵尸的落脚点才接得上，见 Z026BungiDrop）
@export var landing_offset_y := 0.0

func ready_norm():
	super()
	## 如果没有plant_cell,报错
	if not is_instance_valid(plant_cell):
		Log.error("当前蹦极僵尸没有plant_cell")
	## 蹦极僵尸初始化时先禁用受击组件
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)

	bungee_target.position.y -= 600
	var tween_bungee_target = create_tween()
	tween_bungee_target.tween_property(bungee_target, "position:y", bungee_target.position.y+600, 0.5)

	body_correct.position.y -= 600
	## 前摇：普通蹦极要等靶子先落地，空投没有靶子，这段是 0（进场就开始降落）
	if drop_start_delay > 0.0:
		await get_tree().create_timer(drop_start_delay, false).timeout
	var tween = create_tween()
	tween.set_parallel()
	tween.tween_callback(func():is_drop_end = true).set_delay(drop_duration * 0.9)
	tween.tween_callback(enable_hurt_box_on_drop).set_delay(drop_duration * 0.65)
	## 高度要像绝对值函数：匀速降到最低点、再匀速升回去，V 形到底
	## （原来用 TRANS_BACK 会冲过落点再回弹，是「弹一下」不是「触底即起」）
	tween.tween_property(body_correct, "position:y", body_correct.position.y+600+landing_offset_y, drop_duration)
	await tween.finished
	## 后摇：落地后停顿多久才伸手，空投是 0（落地就释放）
	if grab_start_delay > 0.0:
		await get_tree().create_timer(grab_start_delay, false).timeout
	is_grab = true
	body.z_index -= 50

func ready_show():
	super()
	bungee_target.visible = false
	shadow.visible = false

## 偷盗植物,开始起飞
func raise_start():
	## 如果没有被摊开,偷盗植物
	if not is_umbrella_raise:
		bungi_plant_cell(plant_cell)
	bungee_target.visible = false
	## 禁用受击组件
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	## 偷取（或放弃偷取）已经确定，先通知召唤方，不等待这一秒上升结束
	_finish_steal()
	var tween = create_tween()
	tween.tween_property(body_correct, "position:y", body_correct.position.y-600, 1.0)
	tween.set_parallel()
	tween.tween_property(shadow, ^"scale", Vector2.ZERO, 0.5)

	await tween.finished
	character_death_disappear()

## 偷盗植物
func bungi_plant_cell(p_c:PlantCell):
	if is_instance_valid(p_c):
		var plant_body_copy :Node2D= p_c.be_bungi()
		if plant_body_copy != null:
			#GlobalUtils.child_node_change_parent(plant_body_copy, bungi_container)
			plant_body_copy.reparent(bungi_container)

## 降落途中挂上受击框：挂上后才会被植物的索敌检测到
## （空投蹦极只是投放动画，重写成空实现就全程不会被索敌）
func enable_hurt_box_on_drop() -> void:
	hurt_box_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)


## 修改绳子父节点
func update_bungee_cords_parent():
	#GlobalUtils.child_node_change_parent(bungee_cords, zombie_bungi_body_2)
	bungee_cords.reparent(zombie_bungi_body_2)


## 角色死亡
func character_death():
	super()
	queue_free()

## 标记本次偷取已结束；空手和被保护伞弹开同样属于结束，信号绝不重复发送。
func _finish_steal() -> void:
	if _steal_finished:
		return
	_steal_finished = true
	signal_steal_finished.emit()


## 被保护伞摊开
func be_umbrella_leaf():
	is_umbrella_raise = true
	## 本次偷取作废，召唤方不必再等这一只
	_finish_steal()
